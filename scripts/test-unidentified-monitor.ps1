[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory)
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$sessionOwned = $false
try {
    . (Join-Path $PSScriptRoot 'security-process.ps1')
    if (-not $env:USERPROFILE) { throw '缺少 USERPROFILE，無法建立非 Temp 測試目錄。' }
    $source = (Resolve-Path -LiteralPath $ApplicationPath).Path
    $session = [IO.Path]::GetFullPath($EvidenceDirectory)
    $profileRoot = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') + '\'
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $session.StartsWith($profileRoot, [StringComparison]::OrdinalIgnoreCase) -or
        $session.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw '證據目錄必須位於非 Temp 的使用者目錄。' }
    New-Item -ItemType Directory -Path $session -ErrorAction Stop | Out-Null
    $sessionOwned = $true
    $binary = Join-Path $session 'binary'
    New-Item -ItemType Directory -Path $binary | Out-Null
    $application = Join-Path $binary ([IO.Path]::GetFileName($source))
    Copy-Item -LiteralPath $source -Destination $application
    Copy-Item -LiteralPath (Join-Path ([IO.Path]::GetDirectoryName($source)) 'WebView2Loader.dll') -Destination $binary
    Copy-Item -LiteralPath (Join-Path ([IO.Path]::GetDirectoryName($source)) 'resources') -Destination $binary -Recurse
    $previousLocal = $env:LOCALAPPDATA
    $previousCase = $env:DRILLPAPER_MONITOR_CASE
    $results = @()
    try {
        foreach ($scenario in @('degrade', 'initial-failure', 'preview')) {
            $caseRoot = Join-Path $session $scenario
            New-Item -ItemType Directory -Path $caseRoot | Out-Null
            $env:LOCALAPPDATA = Join-Path $caseRoot 'appdata'
            $env:DRILLPAPER_MONITOR_CASE = $scenario
            $app = $null
            $children = @{}
            try {
                $app = Start-SecurityProcess -FilePath $application -ArgumentList @() -EvidenceDirectory $caseRoot
                $identity = @{id=$app.Id; path=$app.Path; utcTicks=$app.StartTime.ToUniversalTime().Ticks}
                $timer = [Diagnostics.Stopwatch]::StartNew()
                while (-not $app.WaitForExit(200)) {
                    if ($timer.Elapsed.TotalSeconds -gt 110) { throw '隔離整合測試逾時，請查看 fixture 日誌。' }
                    foreach ($entry in @(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" |
                        Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($caseRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0 })) {
                        if ($children.ContainsKey($entry.ProcessId)) { continue }
                        $child = Get-Process -Id $entry.ProcessId -ErrorAction SilentlyContinue
                        if (-not $child) { continue }
                        try {
                            $null = $child.Handle
                            if ($child.HasExited) { $child.Dispose(); continue }
                            # CIM 建立時間有微秒量化，沿用既有身分檢查的小於 1ms 容差。
                            @{id=$child.Id; path=$child.Path; utcTicks=$child.StartTime.ToUniversalTime().Ticks;
                                cimPath=$entry.ExecutablePath; cimUtcTicks=$entry.CreationDate.ToUniversalTime().Ticks} |
                                ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $caseRoot 'children.jsonl') -Encoding utf8
                            if (-not $entry.ExecutablePath) {
                                'CIM 未提供 ExecutablePath，此次觀測不計入已核實退出程序。' |
                                    Add-Content -LiteralPath (Join-Path $caseRoot 'observation-gaps.log') -Encoding utf8
                                $child.Dispose()
                                continue
                            }
                            if ($child.Path -ne $entry.ExecutablePath -or
                                [Math]::Abs(($child.StartTime.ToUniversalTime() - $entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1) {
                                throw 'WebView2 程序身分不符，未操作該程序。'
                            }
                            $children[$child.Id] = $child
                        } catch { $child.Dispose(); throw }
                    }
                }
                $exitCode = $app.ExitCode
                foreach ($child in $children.Values) {
                    if (-not $child.WaitForExit(5000)) { throw '已核實的測試 WebView2 尚未退出。' }
                }
                $remaining = @(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" |
                    Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($caseRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
                if ($remaining.Count) { throw '隔離 profile 仍有 WebView2 殘留。' }
                $results += @{scenario=$scenario; exitCode=$exitCode; identity=$identity; observedExitedChildren=$children.Count;
                    timestamp=(Get-Date -Format o)}
                $results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding utf8
                if ($exitCode -ne 0) { throw "情境 $scenario 未通過，請查看 appdata/DrillPaper/rc12-fixture.log。" }
                Write-Output "PASS：$scenario，exit 0，已觀察退出的 WebView2：$($children.Count)"
            } finally {
                if ($app) {
                    if (-not $app.HasExited) { $app.Kill(); [void]$app.WaitForExit(5000) }
                    $app.Dispose()
                }
                foreach ($child in $children.Values) { $child.Dispose() }
            }
        }
    } finally { $env:LOCALAPPDATA = $previousLocal; $env:DRILLPAPER_MONITOR_CASE = $previousCase }
    @{source=$source; sha256=(Get-FileHash -LiteralPath $application).Hash; timestamp=(Get-Date -Format o)} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'binary.json') -Encoding utf8
} catch {
    if ($sessionOwned) {
        $_ | Out-String | Set-Content -LiteralPath (Join-Path $session 'failure.log') -Encoding utf8
    }
    [Console]::Error.WriteLine('錯誤：無法完成螢幕退化整合測試，請查看證據目錄內的 failure.log 與 fixture 日誌，並核對防毒攔截。')
    exit 1
}
