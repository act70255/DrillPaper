$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$validator = Join-Path $PSScriptRoot 'validate-theme-package.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("DrillPaperThemeTests-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)
$tempRoot = [IO.Path]::GetFullPath($tempRoot)

function New-TestPackage([string]$Name, [System.Collections.IDictionary]$Files) {
    $path = Join-Path $tempRoot $Name
    $archive = [System.IO.Compression.ZipFile]::Open($path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $Files.GetEnumerator()) {
            $entry = $archive.CreateEntry([string]$file.Key)
            $stream = $entry.Open()
            try {
                $bytes = [Text.Encoding]::UTF8.GetBytes([string]$file.Value)
                $stream.Write($bytes, 0, $bytes.Length)
            }
            finally { $stream.Dispose() }
        }
    }
    finally { $archive.Dispose() }
    return $path
}

function New-ValidFiles {
    return [ordered]@{
        'theme.json' = '{"id":"test-theme","name":"Test Theme","version":"1.0.0","apiVersion":"1","entry":"index.html","author":"Test","description":"Test theme","capabilities":["cpu"],"permissions":[]}'
        'index.html' = '<!doctype html><title>Test</title>'
        'style.css' = 'body { color: white; }'
    }
}

function Assert-Validation([string]$Name, [System.Collections.IDictionary]$Files, [bool]$ShouldPass) {
    <#
    依封包預期結果驗證公開 validator，預期拒絕卻被接受時不可吞掉斷言。
    Args:
        Name: 測試封包檔名。
        Files: 封包內容。
        ShouldPass: 是否預期合法且通過。
    #>
    $packagePath = New-TestPackage $Name $Files
    try {
        $result = & $validator -Path $packagePath
    }
    catch {
        if ($ShouldPass) { throw }
        Write-Output "PASS rejected: $Name — $($_.Exception.Message)"
        return
    }
    if (-not $ShouldPass) { throw "預期拒絕的主題封包被接受：$Name" }
    if (-not $result.Valid) { throw "主題封包 $Name 未回傳 Valid=true。" }
    Write-Output "PASS accepted: $Name ($($result.FileCount) files)"
}

try {
    Assert-Validation 'valid.dmt' (New-ValidFiles) $true

    $traversal = New-ValidFiles
    $traversal['../escape.js'] = 'alert(1)'
    Assert-Validation 'traversal.dmt' $traversal $false

    $duplicate = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    foreach ($item in (New-ValidFiles).GetEnumerator()) { $duplicate.Add([string]$item.Key, [string]$item.Value) }
    $duplicate.Add('INDEX.HTML', '<p>duplicate</p>')
    Assert-Validation 'duplicate-case.dmt' $duplicate $false

    $unsupported = New-ValidFiles
    $unsupported['payload.exe'] = 'MZ'
    Assert-Validation 'unsupported-extension.dmt' $unsupported $false

    foreach ($sourceName in @('main.ts', 'desktop-monitor-sdk.d.ts')) {
        $withSource = New-ValidFiles
        $withSource[$sourceName] = 'export {}'
        Assert-Validation ($sourceName + '.dmt') $withSource $false
    }

    $wrongApi = New-ValidFiles
    $wrongApi['theme.json'] = $wrongApi['theme.json'].Replace('"apiVersion":"1"', '"apiVersion":"2"')
    Assert-Validation 'wrong-api.dmt' $wrongApi $false

    $oversized = New-ValidFiles
    $oversized['large.js'] = 'x' * (10MB + 1)
    Assert-Validation 'oversized-file.dmt' $oversized $false

    $preparedPath = Join-Path $tempRoot 'minimal-example.dmt'
    & (Join-Path $PSScriptRoot 'package-theme.ps1') -ThemeDirectory (Join-Path $PSScriptRoot '../sdk/examples/minimal') -OutputFile $preparedPath
    $prepared = & $validator -Path $preparedPath
    if (-not $prepared.Valid -or $prepared.Id -ne 'minimal-monitor') {
        throw 'Packaged minimal example did not pass validation with its manifest id.'
    }
    $preparedArchive = [System.IO.Compression.ZipFile]::OpenRead($preparedPath)
    try {
        $packedNames = @($preparedArchive.Entries | ForEach-Object FullName)
        if ($packedNames -notcontains 'desktop-monitor-sdk.js' -or $packedNames -notcontains 'mock-host.js') {
            throw 'Packaged example is missing the local SDK or mock host modules.'
        }
        $main = $preparedArchive.GetEntry('main.js')
        $mainReader = [IO.StreamReader]::new($main.Open())
        try { $mainText = $mainReader.ReadToEnd() } finally { $mainReader.Dispose() }
        if (-not $mainText.Contains("'./desktop-monitor-sdk.js'") -or -not $mainText.Contains("'./mock-host.js'")) {
            throw 'Packaged example imports were not rewritten to local SDK modules.'
        }
    }
    finally { $preparedArchive.Dispose() }
    Write-Output "PASS packaged and revalidated example: $($prepared.Id)"
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperThemeTests-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
