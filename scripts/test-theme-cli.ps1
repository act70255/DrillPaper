[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath)
$ErrorActionPreference = 'Stop'
$testRoot = $null
$failures = [Collections.Generic.List[string]]::new()

function Invoke-ThemeCli([string[]]$Arguments, [bool]$MissingConfig = $false, [bool]$LinkedConfig = $false) {
    <#
    執行本次測試的 CLI 並取得輸出。
    Args:
        Arguments: 傳入 DrillPaper 的原始參數，不加 shell 引號。
        MissingConfig: 是否刻意移除必要環境設定。
        LinkedConfig: 是否使用 junction 測試路徑。
    Returns:
        ExitCode 與 UTF-8 Output。
    #>
    $requestPath = Join-Path $testRoot ([Guid]::NewGuid().ToString('N') + '.json')
    $local = if ($MissingConfig) { '' } elseif ($LinkedConfig) { Join-Path $testRoot 'linked-appdata' } else { Join-Path $testRoot 'appdata' }
    @{application=$application; args=@($Arguments); localAppData=$local} | ConvertTo-Json | Set-Content -LiteralPath $requestPath -Encoding UTF8
    & node (Join-Path $PSScriptRoot '../tests/fixtures/theme-cli-launcher.mjs') $requestPath
    if ($LASTEXITCODE -ne 0) { throw "主題 CLI 啟動器失敗，請核對防毒及請求：$requestPath" }
    return ([IO.File]::ReadAllText($requestPath + '.result.json', [Text.Encoding]::UTF8) | ConvertFrom-Json)
}

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $application = (Resolve-Path -LiteralPath $ApplicationPath).Path
    . (Join-Path $PSScriptRoot 'test-workspace.ps1')
    $testRoot = New-DrillPaperTestWorkspace -Name DrillPaperThemeCli
    $source = Join-Path $testRoot 'source'
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    Write-Output "主題 CLI 測試資料目錄：$testRoot（Node 直接啟動；每次期限 15 秒）"
    Set-Content -LiteralPath (Join-Path $source 'index.html') -Value '<!doctype html><title>測試</title>' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $source 'theme.json') -Encoding utf8 -Value '{"id":"cli-test","name":"測試","version":"1.0.0","apiVersion":"1","entry":"index.html","author":"測試","description":"","capabilities":["cpu"],"permissions":[]}'
    $package = Join-Path $testRoot 'theme with spaces.dmt'
    [IO.Compression.ZipFile]::CreateFromDirectory($source, $package)
    $import = Invoke-ThemeCli @('--import-theme', $package)
    if ($import.ExitCode -ne 0 -or $import.Output -notmatch 'cli-test@1\.0\.0') { throw "主題匯入 CLI 驗證失敗：退出碼=$($import.ExitCode)，輸出=$($import.Output)" }
    $list = Invoke-ThemeCli @('--list-themes')
    if ($list.ExitCode -ne 0 -or $list.Output -notmatch 'cli-test@1\.0\.0') { throw '主題列舉 CLI 驗證失敗。' }
    $duplicate = Invoke-ThemeCli @('--import-theme', $package)
    if ($duplicate.ExitCode -eq 0) { throw '主題匯入不應覆蓋相同版本。' }
    $missing = Invoke-ThemeCli -Arguments @('--list-themes') -MissingConfig $true
    if ($missing.ExitCode -eq 0) { throw '缺少 LOCALAPPDATA 時不應靜默使用預設目錄。' }
    $malformed = Invoke-ThemeCli @('--import-theme')
    if ($malformed.ExitCode -eq 0) { throw '缺少主題來源時不應繼續執行。' }
    $outside = Join-Path $testRoot 'outside'
    New-Item -ItemType Directory -Path $outside -Force | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $testRoot 'linked-appdata') -Target $outside | Out-Null
    $linked = Invoke-ThemeCli -Arguments @('--import-theme', $package) -LinkedConfig $true
    if ($linked.ExitCode -eq 0 -or @(Get-ChildItem -LiteralPath $outside -Force).Count -ne 0) {
        throw 'junction 安裝路徑必須被拒絕，且不可透過錯誤日誌向外寫入。'
    }
    Write-Output 'PASS：原生主題 CLI 可匯入含空白路徑、列舉，並拒絕覆蓋同版本、缺少設定與缺少參數。'
} catch {
    $failures.Add(($_ | Out-String))
} finally {
    if ($testRoot) {
        try {
            $resolved = [IO.Path]::GetFullPath($testRoot)
            $prefix = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'DrillPaperTests')).TrimEnd('\') + '\'
            if ($resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
                [IO.Path]::GetFileName($resolved).StartsWith('DrillPaperThemeCli-', [StringComparison]::Ordinal)) {
                Remove-Item -LiteralPath $resolved -Recurse -Force
            }
        } catch { $failures.Add(($_ | Out-String)) }
    }
}
if ($failures.Count -gt 0) {
    $diagnostic = Join-Path $PSScriptRoot ('../artifacts/acceptance/rc09-cli-errors/' + [Guid]::NewGuid().ToString('N') + '.log')
    try {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic))
        [IO.File]::WriteAllText($diagnostic, ($failures -join [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
    } catch { [Console]::Error.WriteLine('錯誤：詳細日誌無法寫入，請確認工作區權限。') }
    [Console]::Error.WriteLine("錯誤：無法完成主題 CLI 驗證，請核對設定、路徑、權限與防毒。詳細日誌：$diagnostic")
    exit 1
}
