[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [ValidateRange(1,20)][int]$RecoveryCycles = 5,
    [ValidateRange(10,60)][int]$TimeoutSeconds = 30
)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
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
    public struct Geometry { public bool Valid; public Rect Child, Parent; }

    /** 在一致的實體像素座標下取得子視窗與父用戶區尺寸。
     * Args:
     *     window: 受測 app 視窗。
     *     parent: Shell 桌布層。
     * Returns:
     *     有效旗標與兩組矩形，呼叫前的 DPI context 一律還原。
     */
    public static Geometry ReadGeometry(IntPtr window, IntPtr parent) {
        var previous = SetThreadDpiAwarenessContext(new IntPtr(-4));
        var geometry = new Geometry();
        try {
            geometry.Valid = previous != IntPtr.Zero && GetWindowRect(window, out geometry.Child) && GetClientRect(parent, out geometry.Parent);
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
    if ($width -le 0 -or $height -le 0 -or $width -ne $parentRect.Right-$parentRect.Left -or $height -ne $parentRect.Bottom-$parentRect.Top) {
        throw "桌布未填滿其父視窗的用戶區：child=$width,$height；parent=$($parentRect.Right-$parentRect.Left),$($parentRect.Bottom-$parentRect.Top)。"
    }
    return [ordered]@{ AppPid=$owner; Window=$Window.ToInt64(); Parent=$parent.ToInt64(); ShellPid=$shellOwner; Width=$width; Height=$height; Style=$style; ExtendedStyle=$extended; ReadyEpoch=[DrillPaperDesktopProbe]::GetPropW($Window,'DrillPaper.ReadyEpoch').ToInt64(); DesktopEpoch=[DrillPaperDesktopProbe]::GetPropW($Window,'DrillPaper.DesktopEpoch').ToInt64() }
}

$summary = [ordered]@{ Result='RUNNING'; StartedUtc=[DateTime]::UtcNow.ToString('o'); ApplicationSha256=(Get-FileHash $application -Algorithm SHA256).Hash; RecoveryKind='TARGETED_TASKBAR_CREATED_AFTER_OWN_WINDOW_DETACH'; ActualExplorerRestart=$false; Recoveries=@(); Shutdown='NOT_RUN'; ChildrenExited=$false }
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
    if ($summary.Initial.DesktopEpoch -le 0) { throw '找不到初次附掛成功的診斷世代。' }
    $listeners = @([DrillPaperDesktopProbe]::FindOwned($app.Id,'DrillPaperShellNotifications'))
    if ($listeners.Count -ne 1) { throw '找不到本次 app 唯一的 Shell 通知視窗。' }
    $message = [DrillPaperDesktopProbe]::RegisterWindowMessage('TaskbarCreated')
    if ($message -eq 0) { throw '無法註冊 TaskbarCreated 訊息。' }
    for ($cycle=1; $cycle -le $RecoveryCycles; $cycle++) {
        if (-not [DrillPaperDesktopProbe]::DetachOwned($window,$app.Id)) { throw '無法安全解除受測程序自己的附掛。' }
        $reply = [UIntPtr]::Zero
        if ([DrillPaperDesktopProbe]::SendMessageTimeout($listeners[0],$message,[UIntPtr]::Zero,[IntPtr]::Zero,2,5000,[ref]$reply) -eq [IntPtr]::Zero) { throw '受測 Shell 通知處理逾時。' }
        $recovered = Get-Attachment $window
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
Write-Output "PASS：實際 app 附掛、$RecoveryCycles 次受控通知重掛、正常退出與 WebView2 子程序清理。"
