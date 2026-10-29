[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath, [ValidateRange(0,5)][int]$Cycles = 5, [switch]$Rapid, [switch]$CloseWhileSuspending,
    [ValidateRange(3,30)][int]$StateTimeoutSeconds = 25, [ValidateRange(1,50)][int]$RapidIterations = 50)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
if (-not ('DrillPaperPowerTest' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DrillPaperPowerTest {
    private delegate bool EnumCallback(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder name, int size);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    public static IntPtr FindPowerWindow(uint process) {
        var found = new List<IntPtr>();
        EnumWindows((window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            var name = new StringBuilder(256); GetClassName(window, name, name.Capacity);
            if (owner == process && name.ToString() == "DrillPaperPowerEvents") found.Add(window);
            return true;
        }, IntPtr.Zero);
        return found.Count == 1 ? found[0] : IntPtr.Zero;
    }
}
'@
}
function Wait-RuntimeCaption([Diagnostics.Process]$Process, [string]$Pattern) {
    <#
    等待宿主的原生狀態回報。
    Args:
        Process: 本次測試的程序。
        Pattern: 預期標題模式。
    #>
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 100
        $Process.Refresh()
        if ($Process.HasExited) { throw '生命週期測試期間 app 提前退出。' }
        if ($Process.MainWindowTitle -like $Pattern) { return }
    } while ($clock.Elapsed.TotalSeconds -lt $StateTimeoutSeconds)
    throw "未觀察到狀態 $Pattern；目前為 $($Process.MainWindowTitle)"
}
$app = Start-Process -FilePath $application -ArgumentList '--preview','--mock-metrics','--theme=minimal' -WindowStyle Normal -PassThru
$appHandle = $app.Handle
$completed = $false
try {
    Wait-RuntimeCaption $app '*Live metrics'
    $powerWindow = [DrillPaperPowerTest]::FindPowerWindow($app.Id)
    if ($powerWindow -eq [IntPtr]::Zero) { throw '沒有唯一的 Windows 電源／工作階段事件宿主。' }
    for ($index=0; $index -lt $Cycles; $index++) {
        if (-not [DrillPaperPowerTest]::PostMessage($powerWindow, 0x2B1, [UIntPtr]::new([uint32]7), [IntPtr]::Zero)) { throw '無法送出受控 locked 訊息。' }
        Wait-RuntimeCaption $app '*locked*已暫停'
        Start-Sleep -Milliseconds 500
        if (-not [DrillPaperPowerTest]::PostMessage($powerWindow, 0x2B1, [UIntPtr]::new([uint32]8), [IntPtr]::Zero)) { throw '無法送出受控 unlocked 訊息。' }
        Wait-RuntimeCaption $app '*Live metrics'
    }
    if ($Rapid) {
        for ($index=0; $index -lt $RapidIterations; $index++) {
            if (-not [DrillPaperPowerTest]::PostMessage($powerWindow, 0x2B1, [UIntPtr]::new([uint32]7), [IntPtr]::Zero) -or
                -not [DrillPaperPowerTest]::PostMessage($powerWindow, 0x2B1, [UIntPtr]::new([uint32]8), [IntPtr]::Zero)) { throw '快速狀態往返訊息失敗。' }
        }
        [void][DrillPaperPowerTest]::PostMessage($powerWindow, 0x2B1, [UIntPtr]::new([uint32]7), [IntPtr]::Zero)
        Wait-RuntimeCaption $app '*locked*已暫停'
        [void][DrillPaperPowerTest]::PostMessage($powerWindow, 0x2B1, [UIntPtr]::new([uint32]8), [IntPtr]::Zero)
        Wait-RuntimeCaption $app '*Live metrics'
        Write-Output "PASS：$RapidIterations 次快速受控往返後仍可暫停／恢復，未卡在非同步 TrySuspend。"
    }
    if ($Cycles -gt 0) { Write-Output "PASS：$Cycles 次受控工作階段訊息完成 TrySuspend 成功回報、Resume 與新快照；未鎖定真實桌面。" }
    if ($CloseWhileSuspending) {
        [void][DrillPaperPowerTest]::PostMessage($powerWindow, 0x2B1, [UIntPtr]::new([uint32]7), [IntPtr]::Zero)
        Start-Sleep -Milliseconds 10
    }
    $completed = $true
} finally {
    $app.Refresh()
    if (-not $app.HasExited -and (-not $app.CloseMainWindow() -or -not $app.WaitForExit(15000))) {
        $app.Kill()
        throw '生命週期測試無法正常關閉 app。'
    }
    if ($app.ExitCode -ne 0) { throw "生命週期測試退出碼異常：$($app.ExitCode)" }
    if ($CloseWhileSuspending -and $completed) { Write-Output 'PASS：暫停請求期間正常關閉，退出碼 0。' }
    $app.Dispose()
}
