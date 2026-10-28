[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaperThemeCli-' + [Guid]::NewGuid().ToString('N'))
$source = Join-Path $testRoot 'source'
New-Item -ItemType Directory -Path $source -Force | Out-Null

function Invoke-ThemeCli([string[]]$Arguments, [bool]$MissingConfig = $false, [bool]$LinkedConfig = $false) {
    <#
    執行本次測試的 CLI 並取得輸出。
    Args:
        Arguments: 傳入 DrillPaper 的參數，路徑須已加引號。
        MissingConfig: 是否刻意移除必要環境設定。
        LinkedConfig: 是否使用 junction 測試路徑。
    Returns:
        ExitCode 與 UTF-8 Output。
    #>
    $capture = Join-Path $testRoot ([Guid]::NewGuid().ToString('N') + '.txt')
    $previousAppData = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = if ($MissingConfig) { '' } elseif ($LinkedConfig) { Join-Path $testRoot 'linked-appdata' } else { Join-Path $testRoot 'appdata' }
        $process = Start-Process -FilePath $application -ArgumentList $Arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $capture
        # Windows PowerShell 5.1 必須先保留 Handle，否則短命程序的 ExitCode 可能為空。
        $processHandle = $process.Handle
    } finally { $env:LOCALAPPDATA = $previousAppData }
    try {
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            $process.WaitForExit()
            throw '主題 CLI 未於 15 秒內結束，可能錯誤啟動 GUI。'
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = [IO.File]::ReadAllText($capture, [Text.Encoding]::UTF8) }
    } finally { $process.Dispose() }
}

try {
    Set-Content -LiteralPath (Join-Path $source 'index.html') -Value '<!doctype html><title>測試</title>' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $source 'theme.json') -Encoding utf8 -Value '{"id":"cli-test","name":"測試","version":"1.0.0","apiVersion":"1","entry":"index.html","author":"測試","description":"","capabilities":["cpu"],"permissions":[]}'
    $package = Join-Path $testRoot 'theme with spaces.dmt'
    [IO.Compression.ZipFile]::CreateFromDirectory($source, $package)
    $import = Invoke-ThemeCli @('--import-theme', ('"' + $package + '"'))
    if ($import.ExitCode -ne 0 -or $import.Output -notmatch 'cli-test@1\.0\.0') { throw "主題匯入 CLI 驗證失敗：退出碼=$($import.ExitCode)，輸出=$($import.Output)" }
    $list = Invoke-ThemeCli @('--list-themes')
    if ($list.ExitCode -ne 0 -or $list.Output -notmatch 'cli-test@1\.0\.0') { throw '主題列舉 CLI 驗證失敗。' }
    $duplicate = Invoke-ThemeCli @('--import-theme', ('"' + $package + '"'))
    if ($duplicate.ExitCode -eq 0) { throw '主題匯入不應覆蓋相同版本。' }
    $missing = Invoke-ThemeCli -Arguments @('--list-themes') -MissingConfig $true
    if ($missing.ExitCode -eq 0) { throw '缺少 LOCALAPPDATA 時不應靜默使用預設目錄。' }
    $malformed = Invoke-ThemeCli @('--import-theme')
    if ($malformed.ExitCode -eq 0) { throw '缺少主題來源時不應繼續執行。' }
    $outside = Join-Path $testRoot 'outside'
    New-Item -ItemType Directory -Path $outside -Force | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $testRoot 'linked-appdata') -Target $outside | Out-Null
    $linked = Invoke-ThemeCli -Arguments @('--import-theme', ('"' + $package + '"')) -LinkedConfig $true
    if ($linked.ExitCode -eq 0 -or @(Get-ChildItem -LiteralPath $outside -Force).Count -ne 0) {
        throw 'junction 安裝路徑必須被拒絕，且不可透過錯誤日誌向外寫入。'
    }
    Write-Output 'PASS：原生主題 CLI 可匯入含空白路徑、列舉，並拒絕覆蓋同版本、缺少設定與缺少參數。'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith('DrillPaperThemeCli-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
