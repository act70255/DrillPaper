[CmdletBinding()]
param([string]$ArchivePath)
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaperSdkTest-' + [Guid]::NewGuid().ToString('N'))
$restore = Join-Path $PSScriptRoot 'restore-webview2-sdk.ps1'
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    if (-not $ArchivePath) {
        $ArchivePath = Join-Path $testRoot 'official.zip'
        Invoke-WebRequest -Uri 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.2478.35/microsoft.web.webview2.1.0.2478.35.nupkg' -OutFile $ArchivePath -UseBasicParsing
    }
    $invalid = Join-Path $testRoot 'invalid.zip'
    [IO.File]::WriteAllText($invalid,'invalid SDK archive')
    $rejectedTarget = Join-Path $testRoot 'rejected SDK'
    $rejected = $false
    try { & $restore -Destination $rejectedTarget -ArchivePath $invalid }
    catch { $rejected = $_.Exception.Message -like '*SHA-256*' }
    if (-not $rejected -or (Test-Path -LiteralPath $rejectedTarget)) { throw 'SHA-256 拒絕或拒絕後無安裝內容的邊界未通過。' }
    $existing = Join-Path $testRoot 'existing SDK'
    New-Item -ItemType Directory -Path $existing | Out-Null
    $sentinel = Join-Path $existing 'keep.txt'
    [IO.File]::WriteAllText($sentinel,'preserve existing files')
    $rejected = $false
    try { & $restore -Destination $existing -ArchivePath $ArchivePath }
    catch { $rejected = $_.Exception.Message -like '*目的地已存在*' }
    if (-not $rejected -or [IO.File]::ReadAllText($sentinel) -ne 'preserve existing files') { throw '既有 SDK 目錄保留檢查未通過。' }
    & $restore -Destination (Join-Path $testRoot 'verified SDK with spaces') -ArchivePath $ArchivePath
    if (@(Get-ChildItem -LiteralPath $testRoot -Directory -Force | Where-Object Name -like '.DrillPaperWebView2-staging-*').Count -ne 0) { throw 'SDK 安裝完成後仍殘留 staging。' }
    Write-Output 'PASS：官方 SDK 還原、含空白路徑、竄改封包拒絕、既有目錄保留及 staging 清理。'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith('DrillPaperSdkTest-',[StringComparison]::Ordinal) -and
        (Test-Path -LiteralPath $resolved)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
