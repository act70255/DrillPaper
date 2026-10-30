[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$shell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package 'Start-DrillPaper.ps1') -CheckOnly
if ($LASTEXITCODE -ne 0) { throw '完整試用包依賴檢查失敗。' }
$session = Join-Path $PSScriptRoot ('../artifacts/trial-launcher-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $session | Out-Null
foreach ($file in @('Start-DrillPaper.ps1','DrillPaper.exe','package-manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $package $file) -Destination $session
}
$previousError = $ErrorActionPreference
try {
    # Windows PowerShell 會將預期 stderr 包成 NativeCommandError，先完整接收再判斷退出碼。
    $ErrorActionPreference = 'Continue'
    $result = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $session 'Start-DrillPaper.ps1') -CheckOnly 2>&1
} finally { $ErrorActionPreference = $previousError }
if ($LASTEXITCODE -eq 0 -or "$result" -notlike '*試用包缺少 WebView2Loader.dll*') { throw '缺 loader 應顯示繁中重新解壓提示。' }
Copy-Item -LiteralPath (Join-Path $package 'WebView2Loader.dll') -Destination $session
$manifestPath = Join-Path $session 'package-manifest.json'
$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
$manifest.PSObject.Properties.Remove('minimumVcRuntime')
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
try {
    $ErrorActionPreference = 'Continue'
    $result = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $session 'Start-DrillPaper.ps1') -CheckOnly 2>&1
} finally { $ErrorActionPreference = $previousError }
if ($LASTEXITCODE -eq 0 -or "$result" -notlike '*缺少或無效的 minimumVcRuntime*') { throw '缺少最低 runtime 設定必須明確停止。' }
# 將最低版本提高以測試過舊 runtime 的拒絕分支，不變更系統 runtime。
$manifest | Add-Member -NotePropertyName minimumVcRuntime -NotePropertyValue '14.999.0.0'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
try {
    $ErrorActionPreference = 'Continue'
    $result = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $session 'Start-DrillPaper.ps1') -CheckOnly 2>&1
} finally { $ErrorActionPreference = $previousError }
if ($LASTEXITCODE -eq 0 -or "$result" -notlike '*缺少或過舊*https://aka.ms/vc14/vc_redist.x64.exe*') {
    throw '過舊 VC++ 應停止並顯示官方取得網址。'
}
Write-Output 'PASS：Windows PowerShell 5.1 真實依賴檢查、缺 loader 友善提示與 VC++ 過舊拒絕；未修改／安裝系統 runtime。'
