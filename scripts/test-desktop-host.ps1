[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [ValidateRange(1,20)][int]$RecoveryCycles = 5,
    [ValidateRange(10,60)][int]$TimeoutSeconds = 30,
    [switch]$DestroyParent,
    [ValidateSet('close','crash')][string]$ParentExit = 'close',
    [switch]$NoRecoveryNotification,
    [switch]$ObserveExplorerRestart,
    [ValidateRange(30,900)][int]$ObservationSeconds = 900
)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
$fixturePath = Join-Path ([IO.Path]::GetDirectoryName($application)) 'DrillPaperParentFixture.exe'
if ($DestroyParent -and -not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) { throw '跨程序父視窗 fixture 尚未建置。' }
if (-not $DestroyParent -and ($NoRecoveryNotification -or $ParentExit -ne 'close')) { throw '父程序結束模式與略過通知只能用於 DestroyParent 測試。' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaperDesktop-' + [Guid]::NewGuid().ToString('N'))
$evidence = Join-Path $PSScriptRoot ('../artifacts/acceptance/desktop-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $testRoot,$evidence -Force | Out-Null
if (-not ('DrillPaperDesktopProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class DrillPaperDesktopProbe {
    private delegate bool EnumCallback(IntPtr window, IntPtr state);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr state);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumCallback callback, IntPtr state);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassNameW(IntPtr window, StringBuilder name, int length);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr GetShellWindow();
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll")] private static extern IntPtr GetDesktopWindow();
    [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SetParent(IntPtr window, IntPtr parent);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rectangle);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr window, out Rect rectangle);
    [DllImport("user32.dll")] private static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr window, int index);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)] public static extern IntPtr GetPropW(IntPtr window, string name);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern uint RegisterWindowMessage(string name);
    [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr command, IntPtr data);
    [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr command, IntPtr data, uint flags, uint timeout, out UIntPtr result);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] private struct MonitorInfo { public uint size; public Rect monitor, work; public uint flags; }
    [DllImport("user32.dll")] private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    public struct Geometry { public bool Valid; public Rect Child, Parent, Monitor; }

    /** 在一致的實體像素座標下取得子視窗與父用戶區尺寸。
     * Args:
     *     window: 受測 app 視窗。
     *     parent: Shell 桌布層。
     * Returns:
     *     有效旗標、父子與目標螢幕矩形，呼叫前的 DPI context 一律還原。
     */
    public static Geometry ReadGeometry(IntPtr window, IntPtr parent) {
        var previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        var geometry = new Geometry();
        try {
            var monitor = new MonitorInfo(); monitor.size = (uint)Marshal.SizeOf(typeof(MonitorInfo));
            geometry.Valid = previous != IntPtr.Zero && GetWindowRect(window, out geometry.Child) && GetClientRect(parent, out geometry.Parent) && GetMonitorInfo(MonitorFromWindow(window, 2), ref monitor);
            geometry.Monitor = monitor.monitor;
            return geometry;
        } finally {
            if (previous != IntPtr.Zero) SetThreadDpiAwarenessContext(previous);
        }
    }

    /** 讀取視窗類別名稱。
     * Args:
     *     window: 待觀察視窗。
     * Returns:
     *     Win32 類別名稱。
     */
    public static string ClassName(IntPtr window) {
        var text = new StringBuilder(256);
        GetClassNameW(window, text, text.Capacity);
        return text.ToString();
    }
    /** 列出特定程序及類別的視窗，包含附掛於 Shell 的子視窗。
     * Args:
     *     process: 本次啟動的程序識別碼。
     *     className: 精確的原生視窗類別。
     * Returns:
     *     去除重複後的視窗控制代碼。
     */
    public static IntPtr[] FindOwned(int process, string className) {
        var found = new HashSet<IntPtr>();
        EnumCallback inspect = (window, state) => {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if (owner == process && ClassName(window) == className) found.Add(window);
            return true;
        };
        EnumWindows((window, state) => {
            inspect(window, state);
            EnumChildWindows(window, inspect, IntPtr.Zero);
            return true;
        }, IntPtr.Zero);
        var result = new IntPtr[found.Count];
        found.CopyTo(result);
        return result;
    }
    /** 只將已確認身分的受測程序視窗暫時解除附掛。
     * Args:
     *     window: 受測主視窗。
     *     process: 本次受測程序識別碼。
     * Returns:
     *     解除附掛後回到系統桌面根節點時為 true。
     */
    public static bool DetachOwned(IntPtr window, int process) {
        uint owner;
        GetWindowThreadProcessId(window, out owner);
        if (owner != process || ClassName(window) != "DrillPaperPreviewWindow") return false;
        var previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        if (previous == IntPtr.Zero) return false;
        try {
            SetParent(window, IntPtr.Zero);
            var parent = GetParent(window);
            return parent == IntPtr.Zero || parent == GetDesktopWindow();
        } finally { SetThreadDpiAwarenessContext(previous); }
    }
    /** 將受測視窗移至已驗證的測試父程序。
     * Args:
     *     window: 本次 app 視窗。
     *     process: app 程序識別碼。
     *     parent: 本次 fixture 的視窗。
     *     parentProcess: fixture 程序識別碼。
     * Returns:
     *     移動後父視窗符合時為 true。
     */
    public static bool ParentOwnedToFixture(IntPtr window, int process, IntPtr parent, int parentProcess) {
        uint owner, parentOwner;
        GetWindowThreadProcessId(window, out owner);
        GetWindowThreadProcessId(parent, out parentOwner);
        if (owner != process || parentOwner != parentProcess || ClassName(parent) != "DrillPaperParentFixture") return false;
        var previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        if (previous == IntPtr.Zero) return false;
        try { SetParent(window,parent); return GetParent(window) == parent; }
        finally { SetThreadDpiAwarenessContext(previous); }
    }
}
'@
}

function Get-Attachment([IntPtr]$Window) {
    <#
    觀察並驗證真實 app 的附掛身分、尺寸與樣式。
    Args:
        Window: 本次啟動程序的主視窗。
    Returns:
        可保存的原生附掛觀察資料；不符合契約時立即失敗。
    #>
    [uint32]$owner = 0
    [void][DrillPaperDesktopProbe]::GetWindowThreadProcessId($Window,[ref]$owner)
    if ($owner -ne $app.Id) { throw '受測視窗已失效或程序身分不符。' }
    $parent = [DrillPaperDesktopProbe]::GetParent($Window)
    [uint32]$parentOwner = 0
    [uint32]$shellOwner = 0
    [void][DrillPaperDesktopProbe]::GetWindowThreadProcessId($parent,[ref]$parentOwner)
    [void][DrillPaperDesktopProbe]::GetWindowThreadProcessId([DrillPaperDesktopProbe]::GetShellWindow(),[ref]$shellOwner)
    if ($shellOwner -eq 0 -or $parentOwner -ne $shellOwner -or [DrillPaperDesktopProbe]::ClassName($parent) -ne 'WorkerW') {
        throw "主視窗未附掛於目前 Shell 程序的 WorkerW；原生附掛錯誤代碼=$([DrillPaperDesktopProbe]::GetPropW($Window,'DrillPaper.DesktopFailure').ToInt64())。"
    }
    $style = [DrillPaperDesktopProbe]::GetWindowLongPtr($Window,-16).ToInt64()
    $extended = [DrillPaperDesktopProbe]::GetWindowLongPtr($Window,-20).ToInt64()
    if (($style -band 0x40000000) -eq 0 -or ($extended -band 0x08000080) -ne 0x08000080) {
        throw '桌布視窗的 child、不可啟用或工具視窗樣式不符。'
    }
    $geometry = [DrillPaperDesktopProbe]::ReadGeometry($Window,$parent)
    if (-not $geometry.Valid) { throw '無法在一致的 DPI 座標取得受測視窗尺寸。' }
    $childRect = $geometry.Child
    $parentRect = $geometry.Parent
    $width = $childRect.Right - $childRect.Left
    $height = $childRect.Bottom - $childRect.Top
    if ($width -le 0 -or $height -le 0 -or $childRect.Left -ne $geometry.Monitor.Left -or $childRect.Top -ne $geometry.Monitor.Top -or $childRect.Right -ne $geometry.Monitor.Right -or $childRect.Bottom -ne $geometry.Monitor.Bottom) {
        throw "桌布未精確覆蓋目標螢幕：child=$width,$height；parent=$($parentRect.Right-$parentRect.Left),$($parentRect.Bottom-$parentRect.Top)。"
    }
    return [ordered]@{ AppPid=$owner; Window=$Window.ToInt64(); Parent=$parent.ToInt64(); ShellPid=$shellOwner; Width=$width; Height=$height; Style=$style; ExtendedStyle=$extended; ReadyEpoch=[DrillPaperDesktopProbe]::GetPropW($Window,'DrillPaper.ReadyEpoch').ToInt64(); DesktopEpoch=[DrillPaperDesktopProbe]::GetPropW($Window,'DrillPaper.DesktopEpoch').ToInt64(); MetricsTick=[DrillPaperDesktopProbe]::GetPropW($Window,'DrillPaper.MetricsTick').ToInt64() }
}

function Wait-ForFreshMetrics([IntPtr]$Window,[long]$After) {
    <#
    等待背景採樣經 UI 成功送入 WebView2 bridge，避免只用握手判定資料恢復。
    Args:
        Window: 本次受測宿主視窗。
        After: 必須超過的單調遞增傳送時刻。
    Returns:
        新的傳送時刻；未更新或 app 退出時失敗。
    #>
    $deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if ($app.HasExited) { throw '等待新指標期間 app 已退出。' }
        $tick=[DrillPaperDesktopProbe]::GetPropW($Window,'DrillPaper.MetricsTick').ToInt64()
        if ($tick -gt $After) { return $tick }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    throw '宿主握手後沒有持續將新指標送入 WebView2 bridge。'
}

$summary = [ordered]@{ Result='RUNNING'; StartedUtc=[DateTime]::UtcNow.ToString('o'); ApplicationSha256=(Get-FileHash $application -Algorithm SHA256).Hash; RecoveryKind='TARGETED_TASKBAR_CREATED_AFTER_OWN_WINDOW_DETACH'; ActualExplorerRestart=$false; Recoveries=@(); Shutdown='NOT_RUN'; ChildrenExited=$false }
if ($DestroyParent) { $summary.RecoveryKind='CROSS_PROCESS_PARENT_DESTROYED'; $summary.ParentExit=$ParentExit; $summary.NotificationInjected=(-not $NoRecoveryNotification) }
$app = $null
$window = [IntPtr]::Zero
$children = @()
try {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $application
    $start.Arguments = '--experimental-desktop --theme=minimal --no-smart-sleep'
    $start.UseShellExecute = $false
    $start.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $testRoot 'appdata'
    $app = [Diagnostics.Process]::Start($start)
    [void]$app.Handle
    $summary.AppPid = $app.Id
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if ($app.HasExited) { throw '受測 app 在附掛或握手前已退出。' }
        $windows = @([DrillPaperDesktopProbe]::FindOwned($app.Id,'DrillPaperPreviewWindow'))
        if ($windows.Count -gt 1) { throw '主視窗不唯一，拒絕猜測受測視窗。' }
        if ($windows.Count -eq 1) { $window = $windows[0] }
        if ($window -ne [IntPtr]::Zero -and [DrillPaperDesktopProbe]::GetPropW($window,'DrillPaper.ReadyEpoch').ToInt64() -gt 0) { break }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)
    if ($window -eq [IntPtr]::Zero -or [DrillPaperDesktopProbe]::GetPropW($window,'DrillPaper.ReadyEpoch').ToInt64() -le 0) { throw '附掛後未在期限內完成 SDK 握手。' }
    $summary.Initial = Get-Attachment $window
    $summary.Initial.MetricsTick = Wait-ForFreshMetrics $window 0
    if ($summary.Initial.DesktopEpoch -le 0) { throw '找不到初次附掛成功的診斷世代。' }
    $listeners = @([DrillPaperDesktopProbe]::FindOwned($app.Id,'DrillPaperShellNotifications'))
    if ($listeners.Count -ne 1) { throw '找不到本次 app 唯一的 Shell 通知視窗。' }
    $message = [DrillPaperDesktopProbe]::RegisterWindowMessage('TaskbarCreated')
    if ($message -eq 0) { throw '無法註冊 TaskbarCreated 訊息。' }
    for ($cycle=1; $cycle -le $RecoveryCycles; $cycle++) {
        $oldReady = [DrillPaperDesktopProbe]::GetPropW($window,'DrillPaper.ReadyEpoch').ToInt64()
        $oldTick = [DrillPaperDesktopProbe]::GetPropW($window,'DrillPaper.MetricsTick').ToInt64()
        if ($DestroyParent) {
            $readyPath = Join-Path $testRoot "parent-$cycle.txt"
            $fixture = Start-Process -FilePath $fixturePath -ArgumentList ('"'+$readyPath+'"') -WindowStyle Hidden -PassThru
            [void]$fixture.Handle
            try {
                $fixtureDeadline = [DateTime]::UtcNow.AddSeconds(10)
                while (-not (Test-Path -LiteralPath $readyPath) -and [DateTime]::UtcNow -lt $fixtureDeadline -and -not $fixture.HasExited) { Start-Sleep -Milliseconds 50 }
                if (-not (Test-Path -LiteralPath $readyPath)) { throw '隔離父視窗未就緒。' }
                $parent = [IntPtr]([long]([IO.File]::ReadAllText($readyPath)))
                if (-not [DrillPaperDesktopProbe]::ParentOwnedToFixture($window,$app.Id,$parent,$fixture.Id)) { throw '無法移動本次受測視窗到隔離父視窗。' }
                if ($ParentExit -eq 'crash') { $fixture.Kill() }
                elseif (-not [DrillPaperDesktopProbe]::PostMessage($parent,0x0010,[UIntPtr]::Zero,[IntPtr]::Zero)) { throw '無法向隔離父視窗送出關閉請求。' }
                if (-not $fixture.WaitForExit(10000)) { throw '隔離父視窗程序未在期限內退出。' }
                $summary.OldWindowValidAfterParentExit = [DrillPaperDesktopProbe]::IsWindow($window)
                $summary.DestroyedWindow = $window.ToInt64()
            } finally { if (-not $fixture.HasExited) { $fixture.Kill(); $fixture.WaitForExit() }; $fixture.Dispose() }
        } elseif (-not [DrillPaperDesktopProbe]::DetachOwned($window,$app.Id)) { throw '無法安全解除受測程序自己的附掛。' }
        $reply = [UIntPtr]::Zero
        if ($app.HasExited) { throw '父視窗銷毀後 app 已退出，通知復原無法繼續。' }
        if (-not $NoRecoveryNotification -and [DrillPaperDesktopProbe]::SendMessageTimeout($listeners[0],$message,[UIntPtr]::Zero,[IntPtr]::Zero,2,5000,[ref]$reply) -eq [IntPtr]::Zero) { throw '受測 Shell 通知處理逾時。' }
        if ($DestroyParent) {
            $rebuildObserved = $false
            $rebuildDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
            do {
                if ($app.HasExited) { throw '父視窗銷毀後 app 提前退出。' }
                $candidates = @([DrillPaperDesktopProbe]::FindOwned($app.Id,'DrillPaperPreviewWindow'))
                if ($candidates.Count -gt 1) { throw '重建後出現多個主視窗。' }
                if ($candidates.Count -eq 1 -and [DrillPaperDesktopProbe]::GetPropW($candidates[0],'DrillPaper.ReadyEpoch').ToInt64() -gt $oldReady) { $window=$candidates[0]; $rebuildObserved=$true; break }
                Start-Sleep -Milliseconds 100
            } while ([DateTime]::UtcNow -lt $rebuildDeadline)
            if (-not $rebuildObserved) { throw '父視窗銷毀後未重建宿主及完成新的 SDK 握手。' }
        }
        $recovered = Get-Attachment $window
        $firstTick=Wait-ForFreshMetrics $window $oldTick
        $recovered.MetricsTick=Wait-ForFreshMetrics $window $firstTick
        $previousEpoch = if ($summary.Recoveries.Count -eq 0) { $summary.Initial.DesktopEpoch } else { $summary.Recoveries[-1].DesktopEpoch }
        if ($recovered.DesktopEpoch -le $previousEpoch) { throw '通知後未產生新的成功附掛世代。' }
        $summary.Recoveries += $recovered
    }
    $all = @(Get-CimInstance Win32_Process)
    $ids = @($app.Id)
    do {
        $next = @($all | Where-Object { $_.ParentProcessId -in $ids -and $_.ProcessId -notin $ids } | Select-Object -ExpandProperty ProcessId)
        $ids += $next
    } while ($next.Count -gt 0)
    $children = @($ids | Where-Object { $_ -ne $app.Id } | ForEach-Object { $child = Get-Process -Id $_ -ErrorAction SilentlyContinue; if ($child) { [void]$child.Handle; $child } })
    $summary.ObservedChildren = @($children | ForEach-Object { $_.Id })
    if ($children.Count -eq 0) { throw '未觀察到 WebView2 子程序，不能視為完整 app 整合通過。' }
    if ($ObserveExplorerRestart) {
        $summary.Observation = 'WAITING_FOR_USER_EXPLORER_RESTART'
        $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence 'ready.json') -Encoding UTF8
        Write-Output "桌面實機觀測已就緒：PID=$($app.Id)；請手動檢查桌面，並在 $ObservationSeconds 秒內重啟一次 Windows 檔案總管。"
        $observeDeadline = [DateTime]::UtcNow.AddSeconds($ObservationSeconds)
        while ([DateTime]::UtcNow -lt $observeDeadline) {
            if ($app.HasExited) { throw 'Explorer 觀測期間 app 提前退出，未完成實機復原。' }
            if (Test-Path -LiteralPath (Join-Path $evidence 'skip-observation')) {
                $summary.Observation = 'NOT_RUN_USER_SKIPPED'
                break
            }
            [uint32]$currentShell = 0
            [void][DrillPaperDesktopProbe]::GetWindowThreadProcessId([DrillPaperDesktopProbe]::GetShellWindow(),[ref]$currentShell)
            if ($currentShell -ne 0 -and $currentShell -ne $summary.Initial.ShellPid) {
                $currentWindows=@([DrillPaperDesktopProbe]::FindOwned($app.Id,'DrillPaperPreviewWindow'))
                if ($currentWindows.Count -ne 1) { Start-Sleep -Milliseconds 250; continue }
                $window=$currentWindows[0]
                try { $actual = Get-Attachment $window } catch { Start-Sleep -Milliseconds 250; continue }
                if ($actual.DesktopEpoch -gt $summary.Recoveries[-1].DesktopEpoch -and $actual.ReadyEpoch -gt $summary.Recoveries[-1].ReadyEpoch) {
                    $firstTick=Wait-ForFreshMetrics $window $summary.Recoveries[-1].MetricsTick
                    $actual.MetricsTick=Wait-ForFreshMetrics $window $firstTick
                    $summary.ActualExplorerRestart = $true
                    $summary.Observation = 'EXPLORER_PID_CHANGED_AND_REATTACHED'
                    $summary.ActualRecovery = $actual
                    break
                }
            }
            Start-Sleep -Milliseconds 250
        }
        if (-not $summary.ActualExplorerRestart -and $summary.Observation -ne 'NOT_RUN_USER_SKIPPED') {
            throw '期限內未觀察到不同 Shell PID 的成功重掛；真正 Explorer 復原未驗收。'
        }
        if ($summary.ActualExplorerRestart) {
            Write-Output '已確認新的 Explorer PID 與成功重掛；保留桌布 30 秒，請觀察數值是否持續更新。'
            $visualDeadline = [DateTime]::UtcNow.AddSeconds(30)
            while ([DateTime]::UtcNow -lt $visualDeadline) {
                if ($app.HasExited) { throw '重掛後的 30 秒觀測期間 app 提前退出。' }
                Start-Sleep -Milliseconds 250
            }
        }
    }
    if ($app.HasExited) { throw '受測 app 在正常關閉要求前已退出。' }
    $summary.Result = 'PASS'
} catch {
    $summary.Result = 'FAILED'
    $summary.FailureReason = $_.Exception.Message
    throw
} finally {
    if ($app) {
        if (-not $app.HasExited) {
            if ($window -ne [IntPtr]::Zero -and [DrillPaperDesktopProbe]::PostMessage($window,0x0010,[UIntPtr]::Zero,[IntPtr]::Zero) -and $app.WaitForExit(15000)) { $summary.Shutdown='NORMAL_CLOSE' }
            else { $summary.Shutdown='FAILED_NORMAL_CLOSE'; $summary.Result='FAILED'; $app.Kill(); $app.WaitForExit() }
        }
        $summary.ExitCode = $app.ExitCode
        if ($app.ExitCode -ne 0) { $summary.Result='FAILED' }
        $childDeadline = [DateTime]::UtcNow.AddSeconds(15)
        while (@($children | Where-Object { -not $_.HasExited }).Count -gt 0 -and [DateTime]::UtcNow -lt $childDeadline) { Start-Sleep -Milliseconds 200 }
        $summary.ChildrenExited = $children.Count -gt 0 -and @($children | Where-Object { -not $_.HasExited }).Count -eq 0
        if (-not $summary.ChildrenExited) { $summary.Result='FAILED' }
        foreach ($child in $children) { $child.Dispose() }
        $app.Dispose()
    }
    $summary.EndedUtc = [DateTime]::UtcNow.ToString('o')
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $evidence 'summary.json') -Encoding UTF8
    Write-Output "桌布整合測試紀錄：$evidence"
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('DrillPaperDesktop-',[StringComparison]::Ordinal)) {
        for ($attempt=0; $attempt -lt 20; $attempt++) {
            try { Remove-Item -LiteralPath $resolved -Recurse -Force; break }
            catch { if ($attempt -eq 19) { throw }; Start-Sleep -Milliseconds 500 }
        }
    }
}
if ($summary.Result -ne 'PASS') { throw '桌布整合、正常退出或子程序清理未通過，詳見紀錄。' }
$recoveryLabel=if($DestroyParent){'父視窗銷毀後重建與指標更新'}else{'受控通知重掛與指標更新'}
Write-Output "PASS：實際 app 附掛、$RecoveryCycles 次$recoveryLabel、正常退出與 WebView2 子程序清理。"
