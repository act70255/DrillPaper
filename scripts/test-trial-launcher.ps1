[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$shell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $package 'Start-DrillPaper.ps1') -CheckOnly
if ($LASTEXITCODE -ne 0) { throw '完整套件依賴檢查失敗。' }
$missingTheme = Join-Path $PSScriptRoot ('../artifacts/trial-resource-test-' + [Guid]::NewGuid().ToString('N'))
Copy-Item -LiteralPath $package -Destination $missingTheme -Recurse
Remove-Item -LiteralPath (Join-Path $missingTheme 'resources/themes/minimal/index.html')
$previousPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $resourceResult = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $missingTheme 'Start-DrillPaper.ps1') -CheckOnly 2>&1
} finally { $ErrorActionPreference = $previousPreference }
if ($LASTEXITCODE -eq 0 -or "$resourceResult" -notlike '*缺少必要主題資產*重新完整解壓*') { throw '缺少必要主題入口時，應在啟動前以繁中提示完整解壓。' }
$session = Join-Path $PSScriptRoot ('../artifacts/trial-launcher-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $session | Out-Null
Copy-Item -LiteralPath (Join-Path $package 'resources') -Destination (Join-Path $session 'resources') -Recurse
foreach ($file in @('Start-DrillPaper.ps1','Start-DrillPaper.cmd','DrillPaper.exe','package-manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $package $file) -Destination $session
}
$previousError = $ErrorActionPreference
try {
    # Windows PowerShell 會將預期 stderr 包成 NativeCommandError，先完整接收再判斷退出碼。
    $ErrorActionPreference = 'Continue'
    $result = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $session 'Start-DrillPaper.ps1') -CheckOnly 2>&1
} finally { $ErrorActionPreference = $previousError }
if ($LASTEXITCODE -eq 0 -or "$result" -notlike '*套件缺少 WebView2Loader.dll*') { throw '缺 loader 應顯示繁中重新解壓提示。' }
Copy-Item -LiteralPath (Join-Path $package 'WebView2Loader.dll') -Destination $session
$manifestPath = Join-Path $session 'package-manifest.json'
$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
# 靜態連結 CRT 後不再需要 VC++ runtime；manifest 即使帶有過高的舊欄位也不得阻擋啟動檢查。
$manifest.PSObject.Properties.Remove('minimumVcRuntime')
$manifest | Add-Member -NotePropertyName minimumVcRuntime -NotePropertyValue '14.999.0.0'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
try {
    $ErrorActionPreference = 'Continue'
    $result = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $session 'Start-DrillPaper.ps1') -CheckOnly 2>&1
} finally { $ErrorActionPreference = $previousError }
if ($LASTEXITCODE -ne 0 -or "$result" -like '*Visual C++*') { throw "入口不應再檢查 VC++ runtime：$result" }
# 入口現在委派 CMD；同樣必須在啟動之前檢查此必要檔案。
Copy-Item -LiteralPath (Join-Path $package 'package-manifest.json') -Destination $session -Force
Remove-Item -LiteralPath (Join-Path $session 'Start-DrillPaper.cmd')
try {
    $ErrorActionPreference = 'Continue'
    $result = & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $session 'Start-DrillPaper.ps1') -CheckOnly 2>&1
} finally { $ErrorActionPreference = $previousError }
if ($LASTEXITCODE -eq 0 -or "$result" -notlike '*套件缺少 Start-DrillPaper.cmd*') { throw '缺 CMD 應提前拒絕並顯示繁中完整解壓提示。' }
Write-Output 'PASS：Windows PowerShell 5.1 真實依賴檢查、缺主題入口／CMD／loader 友善提示；靜態 CRT 不再要求 VC++ runtime；未修改／安裝系統 runtime。'
