[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationDirectory,
    [Parameter(Mandatory)][string]$SourceDirectory,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+-trial\.[0-9A-Za-z.]+$')][string]$Version,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts'),
    [Parameter(Mandatory)][ValidatePattern('^14\.\d+\.\d+\.\d+$')][string]$MinimumVcRuntime
)
$ErrorActionPreference = 'Stop'
$stage = $null
try {
    $roots = @{ app=[IO.Path]::GetFullPath($ApplicationDirectory); source=[IO.Path]::GetFullPath($SourceDirectory);
        tooling=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
    $entries = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'trial-files.json') | ConvertFrom-Json
    $inputs = @()
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $entries) {
        $destination = if ($entry.destination) { $entry.destination } else { $entry.path }
        foreach ($relative in @($entry.path,$destination)) {
            if ($relative -notmatch '^[a-zA-Z0-9_./-]+$' -or $relative -match '(^/|(^|/)\.\.(/|$)|//)') {
                throw "清單含不安全的相對路徑：$relative"
            }
        }
        if (-not $roots.ContainsKey($entry.root) -or -not $names.Add($destination)) { throw '清單來源或目的地重複／無效。' }
        $root = $roots[$entry.root]
        $file = Join-Path $root $entry.path
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "缺少必要檔案：$($entry.path)" }
        $item = Get-Item -LiteralPath $file
        if ($item.Length -eq 0) { throw "必要檔案為空：$($entry.path)" }
        # 逐層拒絕 junction／symlink，不讓白名單穿越連結帶入其他內容。
        $cursor = $item
        while ($cursor -and $cursor.FullName.Length -ge $root.Length) {
            if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "必要檔案路徑含連結：$($entry.path)" }
            if ($cursor -is [IO.FileInfo]) { $cursor = $cursor.Directory } else { $cursor = $cursor.Parent }
        }
        $inputs += @{ source=$file; path=$destination }
    }
    $output = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    $name = "DrillPaper-$Version-win-x64-unsigned"
    $zip = Join-Path $output "$name.zip"
    $sidecar = Join-Path $output "$name.json"
    if ((Test-Path -LiteralPath $zip) -or (Test-Path -LiteralPath $sidecar)) { throw '試用包目的檔已存在，拒絕覆寫。' }
    $stage = Join-Path $output ('.DrillPaperTrial-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    $records = @(foreach ($inputFile in $inputs) {
        $target = Join-Path $stage $inputFile.path
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
        Copy-Item -LiteralPath $inputFile.source -Destination $target
        @{ path=$inputFile.path; sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash }
    })
    $tooling = @(foreach ($file in @('scripts/build-trial.ps1','scripts/package-trial.ps1','scripts/trial-files.json')) {
        @{path=$file; sha256=(Get-FileHash -LiteralPath (Join-Path $roots.tooling $file) -Algorithm SHA256).Hash}
    })
    $metadata = [ordered]@{ kind='trial'; version=$Version; sourceCommit=$SourceCommit; configuration='Release'; architecture='x64';
        minimumVcRuntime=$MinimumVcRuntime; webView2Sdk='1.0.2478.35'; webView2Runtime='Evergreen (external)';
        executableSha256=($records | Where-Object path -eq 'DrillPaper.exe').sha256; tooling=$tooling; files=$records }
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $stage 'package-manifest.json') -Encoding UTF8
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # 壓縮暫存放在 stage 外，避免 ZIP 將自身帶入。
    $temporaryZip = "$stage.zip"
    try {
        [IO.Compression.ZipFile]::CreateFromDirectory($stage,$temporaryZip)
        $metadata['archiveSha256'] = (Get-FileHash -LiteralPath $temporaryZip -Algorithm SHA256).Hash
        $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $stage 'sidecar.tmp') -Encoding UTF8
        [IO.File]::Move($temporaryZip,$zip)
        [IO.File]::Move((Join-Path $stage 'sidecar.tmp'),$sidecar)
    } finally { if (Test-Path -LiteralPath $temporaryZip) { Remove-Item -LiteralPath $temporaryZip -Force } }
    Write-Output "試用包：$zip"
    Write-Output "SHA-256：$($metadata.archiveSha256)"
} catch {
    throw "試用封裝失敗：$($_.Exception.Message)"
} finally {
    if ($stage -and (Test-Path -LiteralPath $stage)) {
        $resolved = [IO.Path]::GetFullPath($stage)
        if ([IO.Path]::GetDirectoryName($resolved) -eq $output -and [IO.Path]::GetFileName($resolved).StartsWith('.DrillPaperTrial-')) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
