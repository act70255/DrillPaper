[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath, [switch]$Desktop)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DrillPaperManagementProbe {
    private delegate bool Callback(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback cb, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, Callback cb, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr window);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string name);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern uint RegisterWindowMessage(string name);
    public static IntPtr[] Find(uint process, string name) {
        var found = new HashSet<IntPtr>();
        Callback check = (window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            var text = new StringBuilder(256); GetClassName(window, text, text.Capacity);
            if (owner == process && text.ToString() == name) found.Add(window);
            return true;
        };
        EnumWindows((window, data) => { check(window, data); EnumChildWindows(window, check, data); return true; }, IntPtr.Zero);
        var result = new IntPtr[found.Count]; found.CopyTo(result); return result;
    }
}
'@
function Wait-Condition([scriptblock]$Condition, [string]$Message) {
    <# 等待本次程序的可觀察狀態。
    Args:
        Condition: 回傳布林值的條件。
        Message: 逾時錯誤。
    #>
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($app.HasExited) { throw '管理介面測試期間程序提前退出。' }
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ($timer.Elapsed.TotalSeconds -lt 30)
    throw $Message
}
function Send-Command([int]$Command) {
    <# 透過本程序唯一的可信原生入口執行公開命令。
    Args:
        Command: 原生管理命令 ID。
    #>
    [void][DrillPaperManagementProbe]::SendMessage($notification, 0x111, [UIntPtr]::new([uint32]$Command), [IntPtr]::Zero)
}
$session = Join-Path $PSScriptRoot ("../artifacts/acceptance/management-" + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $session -Force)
$previousLocal = $env:LOCALAPPDATA
$observed = [Collections.Generic.HashSet[int]]::new()
$app = $null
$notification = [IntPtr]::Zero
try {
    $env:LOCALAPPDATA = [IO.Path]::GetFullPath((Join-Path $session 'appdata'))
    $app = Start-Process -FilePath $application -ArgumentList '--management','--preview','--mock-metrics','--theme=dashboard','--no-smart-sleep' -WindowStyle Normal -PassThru
    $appHandle = $app.Handle
    $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperShellNotifications')).Count -eq 1 } '缺少唯一通知視窗。'
    $notification = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperShellNotifications')[0]
    Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperManagementWindow')).Count -eq 1 } '缺少唯一管理視窗。'
    $manager = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperManagementWindow')[0]
    $wallpaper = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow')[0]
    Wait-Condition { [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64() -gt 0 } 'WebView2 尚未完成握手。'
    Wait-Condition { [DrillPaperManagementProbe]::GetProp($notification, 'DrillPaper.TrayRegistered').ToInt64() -eq 1 } 'Shell 未接受系統匣圖示註冊。'
    for ($index=0; $index -lt 5; $index++) {
        [void][DrillPaperManagementProbe]::SendMessage($manager, 0x10, [UIntPtr]::Zero, [IntPtr]::Zero)
        if ([DrillPaperManagementProbe]::IsWindowVisible($manager)) { throw '關閉管理視窗後未隱藏。' }
        Send-Command 20001
        if (@([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperManagementWindow')).Count -ne 1 -or
            -not [DrillPaperManagementProbe]::IsWindowVisible($manager)) { throw '管理視窗未重用唯一實例。' }
    }
    Write-Output 'PASS：管理視窗關閉／開啟 5 次，程序繼續且重用同一視窗。'
    Send-Command 20002
    if ([DrillPaperManagementProbe]::IsWindowVisible($wallpaper)) { throw '手動暫停後桌布仍可見。' }
    Start-Sleep -Milliseconds 1000
    $pausedTick = [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.MetricsTick').ToInt64()
    Start-Sleep -Milliseconds 1500
    if ([DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.MetricsTick').ToInt64() -ne $pausedTick) { throw '手動暫停後仍推送指標。' }
    foreach ($child in @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($app.Id)")) { [void]$observed.Add([int]$child.ProcessId) }
    Send-Command 20002
    Wait-Condition { [DrillPaperManagementProbe]::IsWindowVisible($wallpaper) -and
        [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.MetricsTick').ToInt64() -gt $pausedTick } '繼續後未恢復新的指標。'
    Write-Output 'PASS：暫停時隱藏並停止指標推送，繼續後恢復新指標。'
    for ($index=0; $index -lt 3; $index++) {
        $shellMessage = [DrillPaperManagementProbe]::RegisterWindowMessage('TaskbarCreated')
        [void][DrillPaperManagementProbe]::SendMessage($notification, $shellMessage, [UIntPtr]::Zero, [IntPtr]::Zero)
        Wait-Condition { [DrillPaperManagementProbe]::GetProp($notification, 'DrillPaper.TrayRegistered').ToInt64() -eq 1 } '注入重建通知後圖示註冊未恢復。'
    }
    Write-Output 'PASS：3 次受控 TaskbarCreated 通知後 Shell 接受圖示重註冊；不代表真正 Explorer 重啟通過。'
    if ($Desktop) {
        Send-Command 20003
        Wait-Condition { [DrillPaperManagementProbe]::GetParent($wallpaper) -ne [IntPtr]::Zero } '桌布模式未完成附掛。'
        Send-Command 20004
        Wait-Condition { [DrillPaperManagementProbe]::GetParent($wallpaper) -eq [IntPtr]::Zero } '預覽模式未解除附掛。'
        Write-Output 'PASS：原生命令完成桌布／預覽切換；畫面與桌面互動另行確認。'
    }
    $all = @(Get-CimInstance Win32_Process)
    $parents = [Collections.Generic.HashSet[int]]::new()
    [void]$parents.Add($app.Id)
    do {
        $added = $false
        foreach ($candidate in $all) {
            if ($parents.Contains([int]$candidate.ParentProcessId) -and $parents.Add([int]$candidate.ProcessId)) {
                [void]$observed.Add([int]$candidate.ProcessId); $added = $true
            }
        }
    } while ($added)
    Send-Command 20006
    if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 0) { throw '正式結束未正常退出 0。' }
    foreach ($childId in $observed) {
        $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
        if ($child -and -not $child.WaitForExit(15000)) { throw "已觀察子程序未退出：$childId" }
    }
    @{ result='PASS'; application=$application; appId=$app.Id; manager=$manager.ToInt64();
        observedChildren=@($observed); realExplorerRestart='NOT RUN'; visibleTrayClick='NOT RUN'; timestamp=(Get-Date -Format o) } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8
    Write-Output "PASS：正式退出及已觀察子程序清理；紀錄：$session"
} finally {
    $env:LOCALAPPDATA = $previousLocal
    if ($app) {
        if (-not $app.HasExited) {
            if ($notification -ne [IntPtr]::Zero) { Send-Command 20006 }
            if (-not $app.WaitForExit(10000)) { $app.Kill() }
        }
        $app.Dispose()
    }
}
