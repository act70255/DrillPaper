[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [ValidateRange(1, 300)][int]$Cycles = 2,
    [switch]$IncludeInstalled,
    [switch]$BrokenInstalled,
    [ValidateRange(0, 300)][int]$SettlingSeconds = 0,
    [switch]$LiveMetrics,
    [switch]$ExpectGpuUnavailable
)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
if ($ExpectGpuUnavailable -and (-not $LiveMetrics -or $BrokenInstalled)) { throw 'GPU 退化驗證必須使用實機模式，且不可同時注入損壞主題。' }
if ($ExpectGpuUnavailable) { $IncludeInstalled = $true }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DrillPaperThemeSwitchTest {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool PostMessage(IntPtr window, uint message, UIntPtr command, IntPtr data);
}
'@

function Wait-ThemeReady([Diagnostics.Process]$Process, [string]$Theme, [int]$TimeoutSeconds = 20) {
    <#
    等待本機宿主完成特定主題的握手與訂閱。
    Args:
        Process: 本次測試啟動的程序。
        Theme: 預期主題名稱。
        TimeoutSeconds: 宿主握手等待上限。
    #>
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 200
        $Process.Refresh()
        if ($Process.HasExited) { throw '主題切換期間 app 提前退出。' }
        if ($Process.MainWindowTitle -ceq "DrillPaper Preview — $Theme — Live metrics") { return }
    } while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    throw "主題 $Theme 未完成通訊流程；目前標題：$($Process.MainWindowTitle)"
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaperThemeSwitch-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$evidence = Join-Path $PSScriptRoot ('../artifacts/acceptance/theme-switch-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$summary = [ordered]@{ Cycles = $Cycles; InstalledTheme = [bool]$IncludeInstalled; BrokenInstalled = [bool]$BrokenInstalled; SettlingSeconds = $SettlingSeconds; LiveMetrics = [bool]$LiveMetrics; ExpectGpuUnavailable = [bool]$ExpectGpuUnavailable; SmartSleepEnabled = $false; Result = 'RUNNING' }
$previousAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = Join-Path $testRoot 'appdata'
    if ($IncludeInstalled) {
        $package = Join-Path $testRoot 'minimal.dmt'
        & (Join-Path $PSScriptRoot 'package-theme.ps1') -ThemeDirectory (Join-Path $PSScriptRoot '../sdk/examples/minimal') -OutputFile $package | Out-Null
        $import = Start-Process -FilePath $application -ArgumentList '--import-theme', ('"' + $package + '"') -WindowStyle Hidden -PassThru
        $importHandle = $import.Handle
        if (-not $import.WaitForExit(15000)) { $import.Kill(); throw '測試主題匯入逾時。' }
        if ($import.ExitCode -ne 0) { throw '無法匯入切換測試主題。' }
        $import.Dispose()
        if ($BrokenInstalled) {
            Set-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'DrillPaper/themes/minimal-monitor@1.0.0/main.js') -Value 'throw new Error("故障注入");' -Encoding utf8
        }
        if ($ExpectGpuUnavailable) {
            $probe = @'
import { DrillPaperClient } from './desktop-monitor-sdk.js';
const client = new DrillPaperClient(window.chrome.webview);
await client.ready();
let valid = false;
for (let attempt = 0; attempt < 180; attempt++) {
  const snapshot = await client.getSnapshot();
  const cpu = snapshot.cpu?.usage;
  const gpu = snapshot.gpu?.usage;
  const memory = snapshot.memory;
  if (cpu?.quality === 'available' && cpu.value >= 0 && cpu.value <= 100 &&
      memory?.totalBytes > 0 && memory.usedBytes > 0 && memory.usedBytes <= memory.totalBytes &&
      gpu?.quality === 'unavailable' && gpu.value === null && gpu.unit === 'percent') {
    valid = true;
    break;
  }
  await new Promise((resolve) => setTimeout(resolve, 250));
}
if (!valid) throw new Error('實機讀值或 GPU unavailable 未符合預期。');
// 只有在原生快照符合實機條件後才訂閱，宿主標題因此成為可觀察的整合結果。
await client.subscribe({ metrics: ['cpu', 'gpu', 'memory'], intervalMs: 1000 });
'@
            Set-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'DrillPaper/themes/minimal-monitor@1.0.0/main.js') -Value $probe -Encoding utf8
        }
    }
    $arguments = @('--preview','--theme=minimal','--no-smart-sleep')
    if (-not $LiveMetrics) { $arguments += '--mock-metrics' }
    $app = Start-Process -FilePath $application -ArgumentList $arguments -WindowStyle Normal -PassThru
    $appHandle = $app.Handle
} finally { $env:LOCALAPPDATA = $previousAppData }
try {
    Wait-ThemeReady $app 'minimal'
    $summary.RootProcessId = $app.Id
    $summary.StartedUtc = [DateTime]::UtcNow.ToString('o')
    $summary.HandlesBefore = $app.HandleCount
    & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId $app.Id -DurationSeconds 1 -IntervalSeconds 1 -OutputFile (Join-Path $evidence 'before.csv') | Out-Null
    for ($index = 0; $index -lt $Cycles; $index++) {
        $dashboard = $index % 2 -eq 0
        $command = if ($dashboard) { 10002 } else { 10001 }
        $name = if ($dashboard) { 'dashboard' } else { 'minimal' }
        if (-not [DrillPaperThemeSwitchTest]::PostMessage($app.MainWindowHandle, 0x111, [UIntPtr]::new([uint32]$command), [IntPtr]::Zero)) {
            throw '無法送出原生主題功能表命令。'
        }
        Wait-ThemeReady $app $name
        if (($index + 1) % 100 -eq 0) {
            & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId $app.Id -DurationSeconds 1 -IntervalSeconds 1 -OutputFile (Join-Path $evidence ("batch-$($index+1).csv")) | Out-Null
            Write-Output "已完成 $($index+1) 次切換。"
        }
    }
    if ($IncludeInstalled) {
        if (-not [DrillPaperThemeSwitchTest]::PostMessage($app.MainWindowHandle, 0x111, [UIntPtr]::new([uint32]11000), [IntPtr]::Zero)) {
            throw '無法送出已安裝主題命令。'
        }
        if ($BrokenInstalled) {
            $loadingClock = [Diagnostics.Stopwatch]::StartNew()
            do {
                Start-Sleep -Milliseconds 100
                $app.Refresh()
            } while ($app.MainWindowTitle -notlike '*minimal-monitor*' -and $loadingClock.Elapsed.TotalSeconds -lt 10)
            if ($app.MainWindowTitle -notlike '*minimal-monitor*') { throw '沒有觀察到損壞主題的實際載入嘗試。' }
            Wait-ThemeReady $app 'minimal' 45
        }
        else { Wait-ThemeReady $app 'minimal-monitor' 50 }
    }
    & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId $app.Id -DurationSeconds 1 -IntervalSeconds 1 -OutputFile (Join-Path $evidence 'after.csv') | Out-Null
    if ($SettlingSeconds -gt 0) {
        & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId $app.Id -DurationSeconds $SettlingSeconds -IntervalSeconds 5 -OutputFile (Join-Path $evidence 'settled.csv') | Out-Null
    }
    $app.Refresh()
    $summary.HandlesAfter = $app.HandleCount
    $summary.CompletedUtc = [DateTime]::UtcNow.ToString('o')
    $summary.Result = 'PASS_PROTOCOL'
    if ($ExpectGpuUnavailable) { Write-Output 'PASS：實機 CPU 與 RAM 已取得可用資料，SDK GPU 為 unavailable/null，沒有回報假 0。' }
    Write-Output "PASS：同一原生宿主完成 $Cycles 次主題切換與協定握手（不等於畫面或洩漏驗收）。"
} finally {
    $app.Refresh()
    if (-not $app.HasExited) {
        if (-not $app.CloseMainWindow() -or -not $app.WaitForExit(15000)) {
            $summary.Shutdown = 'FAILED'
            $app.Kill()
            throw '主題切換測試無法正常關閉 app。'
        }
    }
    $summary.ExitCode = $app.ExitCode
    $summary.Shutdown = 'NORMAL_CLOSE'
    $summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'summary.json') -Encoding utf8
    Write-Output "切換測試證據：$evidence"
    $app.Dispose()
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith('DrillPaperThemeSwitch-', [StringComparison]::Ordinal)) {
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            try { Remove-Item -LiteralPath $resolved -Recurse -Force; break }
            catch { if ($attempt -eq 19) { throw }; Start-Sleep -Milliseconds 500 }
        }
    }
}
