[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath, [switch]$Desktop,
    [switch]$ObserveExplorerRestart, [ValidateRange(30, 900)][int]$ObservationSeconds = 120,
    [ValidateRange(0, 600)][int]$VisualObservationSeconds = 0)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DrillPaperManagementProbe {
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int left, top, right, bottom; }
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] private static extern bool PrintWindow(IntPtr window, IntPtr dc, uint flags);
    [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
    private delegate bool Callback(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback cb, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, Callback cb, IntPtr data);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] public static extern IntPtr GetShellWindow();
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int length);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string name);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr ReadText(IntPtr window, uint message, UIntPtr value, StringBuilder text);
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
    /** 擷取本次受測程序的原生管理視窗供版面檢查。
     * Args:
     *     process: 受測程序識別。
     *     window: 本程序擁有的管理視窗。
     *     path: 本次隔離觀測的 PNG 路徑。
     */
    public static void Capture(uint process, IntPtr window, string path) {
        uint owner; GetWindowThreadProcessId(window, out owner);
        if (owner != process) throw new InvalidOperationException("視窗不屬於受測程序。");
        var previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        try {
            Rect rect;
            if (!GetWindowRect(window, out rect)) throw new InvalidOperationException("無法取得管理視窗範圍。");
            using (var bitmap = new System.Drawing.Bitmap(rect.right-rect.left, rect.bottom-rect.top)) {
                using (var graphics = System.Drawing.Graphics.FromImage(bitmap)) {
                    var dc = graphics.GetHdc();
                    try { if (!PrintWindow(window, dc, 2)) throw new InvalidOperationException("無法擷取管理視窗。"); }
                    finally { graphics.ReleaseHdc(dc); }
                }
                bitmap.Save(path, System.Drawing.Imaging.ImageFormat.Png);
            }
        } finally { SetThreadDpiAwarenessContext(previous); }
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
        if ($app.HasExited) { throw "管理介面測試期間程序提前退出，退出碼：$($app.ExitCode)。" }
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ($timer.Elapsed.TotalSeconds -lt 30)
    $caption = [Text.StringBuilder]::new(1024)
    if ($wallpaper -ne [IntPtr]::Zero) { [void][DrillPaperManagementProbe]::GetWindowText($wallpaper, $caption, $caption.Capacity) }
    $status = [Text.StringBuilder]::new(2048)
    if ($manager -ne [IntPtr]::Zero) { [void][DrillPaperManagementProbe]::ReadText([DrillPaperManagementProbe]::GetDlgItem($manager, 20100), 0xD, [UIntPtr]::new([uint32]$status.Capacity), $status) }
    throw "$Message 目前宿主：$caption；管理狀態：$status"
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
    Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow')).Count -gt 0 } '缺少管理程序宿主視窗。'
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
        Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow') | Where-Object { [DrillPaperManagementProbe]::GetParent($_) -ne [IntPtr]::Zero }).Count -gt 0 } '桌布模式未完成附掛。'
        Send-Command 20004
        Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow') | Where-Object { [DrillPaperManagementProbe]::GetParent($_) -eq [IntPtr]::Zero }).Count -eq 1 } '預覽模式未建立唯一視窗。'
        $wallpaper = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow')[0]
        Write-Output 'PASS：原生命令完成桌布／預覽切換；畫面與桌面互動另行確認。'
    }
    $themeList = [DrillPaperManagementProbe]::GetDlgItem($manager, 20101)
    $modeList = [DrillPaperManagementProbe]::GetDlgItem($manager, 20102)
    $sleepCheck = [DrillPaperManagementProbe]::GetDlgItem($manager, 20103)
    [void][DrillPaperManagementProbe]::SendMessage($themeList, 0x186, [UIntPtr]::Zero, [IntPtr]::Zero)
    [void][DrillPaperManagementProbe]::SendMessage($modeList, 0x14E, [UIntPtr]::new([uint32]1), [IntPtr]::Zero)
    [void][DrillPaperManagementProbe]::SendMessage($sleepCheck, 0xF1, [UIntPtr]::Zero, [IntPtr]::Zero)
    $readyBefore = [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64()
    Send-Command 20010
    $settingsFile = Join-Path $session 'appdata/DrillPaper/settings.json'
    if (-not (Test-Path -LiteralPath $settingsFile)) { throw '套用後沒有保存設定。' }
    $settings = Get-Content -Raw -LiteralPath $settingsFile | ConvertFrom-Json
    if ($settings.theme -ne 'minimal' -or $settings.displayMode -ne 'preview' -or $settings.smartSleep) { throw '保存內容與使用者控制項不符。' }
    Wait-Condition { [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64() -gt $readyBefore } '套用主題後未完成新握手。'
    $savedHash = (Get-FileHash -LiteralPath $settingsFile).Hash
    [void][DrillPaperManagementProbe]::SendMessage($themeList, 0x186, [UIntPtr]::new([uint32]1), [IntPtr]::Zero)
    Send-Command 20011
    if ([DrillPaperManagementProbe]::SendMessage($themeList, 0x188, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64() -ne 0 -or
        (Get-FileHash -LiteralPath $settingsFile).Hash -ne $savedHash) { throw '取消未還原草稿或改寫了偏好。' }
    Write-Output 'PASS：可信設定控制項套用／保存、主題新握手與取消不改寫偏好。'
    [DrillPaperManagementProbe]::Capture($app.Id, $manager, [IO.Path]::GetFullPath((Join-Path $session 'management.png')))
    $actualExplorer = $null
    if ($ObserveExplorerRestart) {
        Send-Command 10002
        Send-Command 20003
        Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow')).Count -gt 0 } '桌布宿主未建立。'
        $wallpaper = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow')[0]
        Wait-Condition { [DrillPaperManagementProbe]::GetParent($wallpaper) -ne [IntPtr]::Zero } '真正重啟前沒有成功附掛桌布。'
        [uint32]$shellBefore = 0
        [void][DrillPaperManagementProbe]::GetWindowThreadProcessId([DrillPaperManagementProbe]::GetShellWindow(), [ref]$shellBefore)
        $readyBefore = [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64()
        $desktopBefore = [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.DesktopEpoch').ToInt64()
        @{appId=$app.Id; shellId=$shellBefore; wallpaper=$wallpaper.ToInt64(); ready=$readyBefore; desktop=$desktopBefore} |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'explorer-before.json') -Encoding UTF8
        Write-Output "新版管理桌布真正 Explorer 觀測已就緒：$session；PID=$($app.Id)，Shell=$shellBefore。"
        $deadline = [DateTime]::UtcNow.AddSeconds($ObservationSeconds)
        do {
            if ($app.HasExited) { throw '真正 Explorer 觀測期間 app 提前退出。' }
            [uint32]$shellAfter = 0
            [void][DrillPaperManagementProbe]::GetWindowThreadProcessId([DrillPaperManagementProbe]::GetShellWindow(), [ref]$shellAfter)
            $windows = @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow'))
            if ($shellAfter -ne 0 -and $shellAfter -ne $shellBefore -and $windows.Count -eq 1) {
                $candidate = $windows[0]
                [uint32]$parentOwner = 0
                [void][DrillPaperManagementProbe]::GetWindowThreadProcessId([DrillPaperManagementProbe]::GetParent($candidate), [ref]$parentOwner)
                if ($parentOwner -eq $shellAfter -and
                    [DrillPaperManagementProbe]::GetProp($candidate, 'DrillPaper.ReadyEpoch').ToInt64() -gt $readyBefore -and
                    [DrillPaperManagementProbe]::GetProp($candidate, 'DrillPaper.DesktopEpoch').ToInt64() -gt $desktopBefore -and
                    [DrillPaperManagementProbe]::GetProp($notification, 'DrillPaper.TrayRegistered').ToInt64() -eq 1) {
                    $wallpaper = $candidate
                    $tickBefore = [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.MetricsTick').ToInt64()
                    Wait-Condition { [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.MetricsTick').ToInt64() -gt $tickBefore } '真正重啟後沒有新的指標。'
                    $actualExplorer = @{appId=$app.Id; shellBefore=$shellBefore; shellAfter=$shellAfter; parentOwner=$parentOwner;
                        window=$wallpaper.ToInt64(); ready=[DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64();
                        desktop=[DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.DesktopEpoch').ToInt64();
                        metrics=[DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.MetricsTick').ToInt64();
                        trayRegistered=1; visual='NOT RUN'; actualTrayClick='NOT RUN'}
                    $actualExplorer | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'explorer-after.json') -Encoding UTF8
                    Write-Output 'PASS：真正 Shell PID 改變，新管理桌布完成新附掛／握手／指標，系統匣重新註冊。'
                    break
                }
            }
            Start-Sleep -Milliseconds 200
        } while ([DateTime]::UtcNow -lt $deadline)
        if (-not $actualExplorer) { throw '期限內沒有觀察到新版真正 Explorer 復原。' }
        if ($VisualObservationSeconds -gt 0) {
            Write-Output "真正復原後保留 $VisualObservationSeconds 秒供人工觀察；尚未將畫面標為通過。"
            $visualDeadline = [DateTime]::UtcNow.AddSeconds($VisualObservationSeconds)
            while ([DateTime]::UtcNow -lt $visualDeadline) {
                if ($app.HasExited) { throw '人工觀察期間受測程序提前退出。' }
                Start-Sleep -Milliseconds 250
            }
        }
    }
    $all = @(Get-CimInstance Win32_Process)
    $parents = [Collections.Generic.HashSet[int]]::new()
    $births = [Collections.Generic.Dictionary[int,DateTime]]::new()
    $births[$app.Id] = $app.StartTime.ToUniversalTime()
    [void]$parents.Add($app.Id)
    do {
        $added = $false
        foreach ($candidate in $all) {
            $parentId = [int]$candidate.ParentProcessId
            $created = $candidate.CreationDate.ToUniversalTime()
            if ($parents.Contains($parentId) -and $created -ge $births[$parentId] -and $parents.Add([int]$candidate.ProcessId)) {
                $births[[int]$candidate.ProcessId] = $created
                $added = $true
            }
        }
    } while ($added)
    $children = @(
        foreach ($childId in $parents) {
            if ($childId -eq $app.Id) { continue }
            $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
            if ($child) {
                try {
                    # 先持有真正程序的 handle，避免退出後將重用 PID 的其他程序列入。
                    $childHandle = $child.Handle
                    if ([Math]::Abs(($child.StartTime.ToUniversalTime() - $births[$childId]).TotalMilliseconds) -lt 1) {
                        [void]$observed.Add($child.Id)
                        $child
                    } else { $child.Dispose() }
                } catch { $child.Dispose() }
            }
        }
    )
    if ($children.Count -eq 0) { throw '沒有觀察到真正 WebView2 子程序，不能宣稱清理通過。' }
    Send-Command 20006
    if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 0) { throw '正式結束未正常退出 0。' }
    foreach ($child in $children) {
        if (-not $child.WaitForExit(15000)) { throw "已觀察子程序未退出：$($child.Id)" }
        $child.Dispose()
    }
    $app.Dispose()
    $env:LOCALAPPDATA = [IO.Path]::GetFullPath((Join-Path $session 'appdata'))
    $app = Start-Process -FilePath $application -ArgumentList '--management','--mock-metrics' -WindowStyle Normal -PassThru
    $appHandle = $app.Handle
    $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperShellNotifications')).Count -eq 1 } '重啟後沒有通知入口。'
    $notification = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperShellNotifications')[0]
    $manager = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperManagementWindow')[0]
    Wait-Condition { @([DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow')).Count -gt 0 } '重啟後沒有宿主視窗。'
    $wallpaper = [DrillPaperManagementProbe]::Find($app.Id, 'DrillPaperPreviewWindow')[0]
    Wait-Condition { [DrillPaperManagementProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64() -gt 0 } '重啟後未完成握手。'
    $themeList = [DrillPaperManagementProbe]::GetDlgItem($manager, 20101)
    $modeList = [DrillPaperManagementProbe]::GetDlgItem($manager, 20102)
    $sleepCheck = [DrillPaperManagementProbe]::GetDlgItem($manager, 20103)
    if ([DrillPaperManagementProbe]::SendMessage($themeList, 0x188, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64() -ne 0 -or
        [DrillPaperManagementProbe]::SendMessage($modeList, 0x147, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64() -ne 1 -or
        [DrillPaperManagementProbe]::SendMessage($sleepCheck, 0xF0, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64() -ne 0 -or
        (Get-FileHash -LiteralPath $settingsFile).Hash -ne $savedHash) { throw '重啟未恢復已保存偏好，或啟動時自行改寫設定。' }
    Send-Command 20006
    if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 0) { throw '重啟驗證程序無法正常退出。' }
    Write-Output 'PASS：重啟恢復主題／模式／智慧休眠，未自動改寫設定。'
    @{ result='PASS'; application=$application; hash=(Get-FileHash -LiteralPath $application).Hash; appId=$app.Id; manager=$manager.ToInt64();
        observedChildren=@($observed); realExplorerRestart=$(if ($actualExplorer) { $actualExplorer } else { 'NOT RUN' }); visibleTrayClick='NOT RUN'; timestamp=(Get-Date -Format o) } |
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
