[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath,
    [string]$EvidenceDirectory,
    [switch]$DesktopPowerRecovery,
    [switch]$EmptySelectionNotice,
    [string]$ParentFixturePath)
#requires -Version 7.0
$ErrorActionPreference = 'Stop'
try {
. (Join-Path $PSScriptRoot 'security-process.ps1')
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
if ($EmptySelectionNotice) {
    if ($DesktopPowerRecovery) { throw '空選擇回歸與電源復原回歸必須分開循序執行。' }
    if (-not $env:USERPROFILE -or -not $EvidenceDirectory) { throw '空選擇回歸需要 USERPROFILE 及明確的全新證據目錄。' }
    $profileRoot = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') + '\'
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    foreach ($path in @($application,[IO.Path]::GetFullPath($EvidenceDirectory))) {
        if (-not $path.StartsWith($profileRoot,[StringComparison]::OrdinalIgnoreCase) -or
            $path.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)) { throw '空選擇回歸的 EXE 及證據必須位於非 Temp 使用者目錄。' }
    }
}
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class DrillPaperMonitorProbe {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left, top, right, bottom; }
    private delegate bool Callback(IntPtr window, IntPtr data);
    private delegate bool MonitorCallback(IntPtr monitor, IntPtr dc, ref Rect rect, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, MonitorCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback cb, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, Callback cb, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder name, int count);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr window);
    [DllImport("user32.dll", SetLastError=true)] private static extern IntPtr SetParent(IntPtr window, IntPtr parent);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string name);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")] public static extern IntPtr ReadText(IntPtr window, uint message, UIntPtr size, StringBuilder text);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("kernel32.dll", SetLastError=true)] private static extern IntPtr OpenProcess(uint access, bool inherit, uint process);
    [DllImport("kernel32.dll", SetLastError=true)] private static extern IntPtr VirtualAllocEx(IntPtr process, IntPtr address, UIntPtr size, uint allocation, uint protection);
    [DllImport("kernel32.dll")] private static extern bool VirtualFreeEx(IntPtr process, IntPtr address, UIntPtr size, uint type);
    [DllImport("kernel32.dll")] private static extern bool WriteProcessMemory(IntPtr process, IntPtr address, byte[] bytes, UIntPtr size, out UIntPtr written);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
    /** 找出本次受測程序的原生宿主，不操作其他程序。
     * Args:
     *     process: 受測程序識別。
     *     name: Windows 類別名稱。
     * Returns:
     *     去重後的視窗清單。
     */
    public static IntPtr[] Find(uint process, string name) {
        var found = new HashSet<IntPtr>();
        Callback check = (window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            var label = new StringBuilder(256); GetClassName(window, label, label.Capacity);
            if (owner == process && label.ToString() == name) found.Add(window);
            return true;
        };
        EnumWindows((window, data) => { check(window, data); EnumChildWindows(window, check, data); return true; }, IntPtr.Zero);
        var result = new IntPtr[found.Count]; found.CopyTo(result); return result;
    }
    /** 直接列舉 Windows 邏輯桌面矩形，作為宿主定位的獨立 oracle。
     * Returns:
     *     包含負座標的實體矩形，鏡像共用同一區域。
     */
    public static Rect[] DesktopRects() {
        var result = new List<Rect>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr monitor, IntPtr dc, ref Rect rect, IntPtr data) => { result.Add(rect); return true; }, IntPtr.Zero);
        return result.ToArray();
    }
    /** 只將本次宿主移到已驗證的 fixture 父視窗。
     * Args:
     *     window: 受測宿主。
     *     process: 受測程序識別。
     *     parent: fixture HWND。
     *     fixture: fixture 程序識別。
     */
    public static void AttachFixture(IntPtr window, uint process, IntPtr parent, uint fixture) {
        uint owner, parentOwner; GetWindowThreadProcessId(window, out owner); GetWindowThreadProcessId(parent, out parentOwner);
        if (owner != process || parentOwner != fixture) throw new InvalidOperationException("fixture 所有權不符。");
        SetParent(window, parent);
        if (GetParent(window) != parent) throw new InvalidOperationException("無法移動受測宿主。");
    }
    /** 透過標準 ListView 契約改變本次程序的勾選草稿。
     * Args:
     *     process: 受測程序識別。
     *     list: 該程序的螢幕清單。
     *     index: 目標列。
     *     enabled: 是否勾選。
     */
    public static void Check(uint process, IntPtr list, int index, bool enabled) {
        uint owner; GetWindowThreadProcessId(list, out owner);
        if (owner != process) throw new InvalidOperationException("清單不屬於受測程序。");
        var handle = OpenProcess(0x28, false, process);
        if (handle == IntPtr.Zero) throw new InvalidOperationException("無法存取受測清單。");
        var remote = IntPtr.Zero;
        try {
            var bytes = new byte[88];
            Array.Copy(BitConverter.GetBytes((uint)(enabled ? 0x2000 : 0x1000)), 0, bytes, 12, 4);
            Array.Copy(BitConverter.GetBytes((uint)0xF000), 0, bytes, 16, 4);
            remote = VirtualAllocEx(handle, IntPtr.Zero, new UIntPtr((uint)bytes.Length), 0x3000, 4);
            UIntPtr written;
            if (remote == IntPtr.Zero || !WriteProcessMemory(handle, remote, bytes, new UIntPtr((uint)bytes.Length), out written))
                throw new InvalidOperationException("無法設定受測清單草稿。");
            SendMessage(list, 0x102B, new UIntPtr((uint)index), remote);
        } finally {
            if (remote != IntPtr.Zero) VirtualFreeEx(handle, remote, UIntPtr.Zero, 0x8000);
            CloseHandle(handle);
        }
    }
}
'@
$session = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) }
    else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ("../artifacts/acceptance/multi-monitor-" + [Guid]::NewGuid().ToString('N')))) }
New-Item -ItemType Directory -Path $session -ErrorAction Stop | Out-Null
$previousLocal = $env:LOCALAPPDATA
$app = $null
$server = $null
$notification = [IntPtr]::Zero
$evidence = [Collections.Generic.List[object]]::new()
$previousDpi = [DrillPaperMonitorProbe]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))

function Wait-Condition([scriptblock]$Condition, [string]$Failure) {
    <# 等待本次程序的可觀察結果。
    Args:
        Condition: 成功條件。
        Failure: 逾時錯誤。
    #>
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($app.HasExited) { throw "受測程序提早退出：$($app.ExitCode)" }
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ($timer.Elapsed.TotalSeconds -lt 35)
    Record-Surfaces 'condition-timeout'
    throw $Failure
}
function Send-Command([int]$Command) {
    <# 對本次受測程序執行可信原生命令。
    Args:
        Command: 命令識別。
    #>
    [void][DrillPaperMonitorProbe]::SendMessage($notification, 0x111, [UIntPtr]::new([uint32]$Command), [IntPtr]::Zero)
}
function Get-Surfaces {
    <# 取得目前程序所有桌布與預覽宿主。
    Returns:
        目前有效的 HWND。
    #>
    [DrillPaperMonitorProbe]::Find($app.Id, 'DrillPaperPreviewWindow')
}
function Wait-Ready([int]$Count) {
    <# 等待所有目前宿主完成握手。
    Args:
        Count: 預期宿主數量，零表示只要求至少一個。
    #>
    Write-Output "等待 $Count 個目標握手（0 表示依目前有效區域）。"
    Wait-Condition {
        $windows = @(Get-Surfaces)
        $windows.Count -gt 0 -and ($Count -eq 0 -or $windows.Count -eq $Count) -and
            @($windows | Where-Object { [DrillPaperMonitorProbe]::GetProp($_, 'DrillPaper.ReadyEpoch').ToInt64() -le 0 }).Count -eq 0
    } '目標數量或 WebView2 握手不符。'
}
function Record-Surfaces([string]$Phase) {
    <# 保存各宿主原生矩形、附掛、DPI 及握手證據。
    Args:
        Phase: 目前操作階段。
    #>
    $records = @(foreach ($window in @(Get-Surfaces)) {
        $rect = [DrillPaperMonitorProbe+Rect]::new()
        [void][DrillPaperMonitorProbe]::GetWindowRect($window, [ref]$rect)
        @{hwnd=$window.ToInt64(); parent=[DrillPaperMonitorProbe]::GetParent($window).ToInt64();
            left=$rect.left; top=$rect.top; right=$rect.right; bottom=$rect.bottom;
            dpi=[DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.TargetDpi').ToInt64();
            attached=[DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.DesktopEpoch').ToInt64();
            load=[DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.LoadEpoch').ToInt64();
            ready=[DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64();
            tick=[DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64();
            health=[DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.HealthTick').ToInt64();
            caption=(Get-SurfaceCaption $window)}
    })
    $evidence.Add(@{phase=$Phase; timestamp=(Get-Date -Format o); surfaces=$records})
    $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $session 'phases.json') -Encoding UTF8
    Write-Output "已記錄：$Phase"
}
function Get-SurfaceCaption([IntPtr]$Window) {
    <# 讀取目前宿主的原生狀態，不能單獨證明像素存活。
    Args:
        Window: 本次受測宿主。
    Returns:
        原生標題文字。
    #>
    $text = [Text.StringBuilder]::new(1024)
    [void][DrillPaperMonitorProbe]::ReadText($Window,0xD,[UIntPtr]::new(1024),$text)
    return $text.ToString()
}
function Get-TargetSignature {
    <# 讀取公開宿主身分、幾何及載入世代，排除持續更新的時間戳。
    Returns:
        可比對的有效目標 JSON。
    #>
    @(foreach ($window in @(Get-Surfaces | Sort-Object { $_.ToInt64() })) {
        $rect = [DrillPaperMonitorProbe+Rect]::new()
        [void][DrillPaperMonitorProbe]::GetWindowRect($window,[ref]$rect)
        @($window.ToInt64(),[DrillPaperMonitorProbe]::GetParent($window).ToInt64(),
            [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.LoadEpoch').ToInt64(),
            $rect.left,$rect.top,$rect.right,$rect.bottom)
    }) | ConvertTo-Json -Compress -Depth 4
}
function Assert-CommandNotice([int]$Command, [string]$Expected) {
    <# 觀察正式原生命令的訊息框及管理狀態，並確認拒絕後沒有變更。
    Args:
        Command: 可信管理命令。
        Expected: 規格要求的完整提示。
    #>
    $managers = @([DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperManagementWindow'))
    if ($managers.Count -ne 1) { throw '沒有唯一的目前程序管理視窗。' }
    $manager = $managers[0]
    $hash = (Get-FileHash -LiteralPath $settingsFile).Hash
    $targets = Get-TargetSignature
    if (-not [DrillPaperMonitorProbe]::PostMessage($notification,0x111,[UIntPtr]::new([uint32]$Command),[IntPtr]::Zero)) { throw '無法送出管理命令。' }
    Wait-Condition {
        @([DrillPaperMonitorProbe]::Find($app.Id,'#32770') | Where-Object {
            [DrillPaperMonitorProbe]::IsWindowVisible($_) -and [DrillPaperMonitorProbe]::GetDlgItem($_,65535) -ne [IntPtr]::Zero
        }).Count -eq 1
    } '沒有唯一可見且文字已建立的訊息框。'
    $dialog = @([DrillPaperMonitorProbe]::Find($app.Id,'#32770') | Where-Object {
        [DrillPaperMonitorProbe]::IsWindowVisible($_) -and [DrillPaperMonitorProbe]::GetDlgItem($_,65535) -ne [IntPtr]::Zero
    })[0]
    $text = Get-SurfaceCaption ([DrillPaperMonitorProbe]::GetDlgItem($dialog,65535))
    $evidence.Add(@{phase="dialog-$Command"; hwnd=$dialog.ToInt64(); text=$text; timestamp=(Get-Date -Format o)})
    Record-Surfaces "dialog-$Command"
    # 先關閉本次程序訊息框，再做斷言，避免失敗後留下模態視窗。
    [void][DrillPaperMonitorProbe]::PostMessage($dialog,0x10,[UIntPtr]::Zero,[IntPtr]::Zero)
    Wait-Condition { -not [DrillPaperMonitorProbe]::IsWindowVisible($dialog) } '訊息框未關閉。'
    Wait-Condition {
        (Get-SurfaceCaption ([DrillPaperMonitorProbe]::GetDlgItem($manager,20100))).Contains($Expected)
    } '管理狀態未顯示指定原因。'
    $status = Get-SurfaceCaption ([DrillPaperMonitorProbe]::GetDlgItem($manager,20100))
    $evidence.Add(@{phase="notice-$Command"; manager=$manager.ToInt64(); expected=$Expected; dialog=$text; status=$status; timestamp=(Get-Date -Format o)})
    Record-Surfaces "notice-$Command"
    if ($text -ne $Expected -or -not $status.Contains($Expected)) { throw "提示不符，訊息框：$text；管理狀態：$status" }
    if ((Get-FileHash -LiteralPath $settingsFile).Hash -ne $hash -or (Get-TargetSignature) -ne $targets) { throw '拒絕操作改寫設定或目前有效宿主。' }
}
function Test-EmptySelectionNotice {
    <# 驗證桌布拒絕、Preview 空選擇及非預期錯誤；只操作本次隔離資料。 #>
    $specific = '桌布模式至少需選擇一個目標螢幕。'
    for ($index=0; $index -lt $count; $index++) { [DrillPaperMonitorProbe]::Check($app.Id,$list,$index,$false) }
    Assert-CommandNotice 20010 $specific
    Assert-CommandNotice 20013 $specific
    # 主題預覽不保存；草稿仍為桌布模式，但命令本身要求 Preview。
    $savedHash = (Get-FileHash -LiteralPath $settingsFile).Hash
    Send-Command 20012
    Wait-Ready 1
    if ([DrillPaperMonitorProbe]::GetParent(@(Get-Surfaces)[0]) -ne [IntPtr]::Zero -or
        (Get-FileHash -LiteralPath $settingsFile).Hash -ne $savedHash) { throw '空選擇主題預覽未生效或改寫保存設定。' }
    [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20102),0x14E,[UIntPtr]::new(1),[IntPtr]::Zero)
    [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20106),0xF1,[UIntPtr]::new(1),[IntPtr]::Zero)
    Send-Command 20010
    Wait-Ready 1
    $allSurfaceCount = 1
    Assert-FreshMetrics
    $preview = Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsFile | ConvertFrom-Json
    if ($preview.displayMode -ne 'preview' -or @($preview.monitorTargets).Count -ne 0 -or -not $preview.allowNetwork) { throw 'Preview 空選擇及相關設定沒有保存。' }
    Record-Surfaces 'empty-preview-saved'
    Assert-CommandNotice 20003 $specific
    # 同一空選擇 Preview 可再次保存；再以隔離安裝主題損毀觸發非預期錯誤。
    Send-Command 20010
    Wait-Ready 1
    $manifest = Join-Path $session 'appdata/DrillPaper/themes/multi-probe@1.0.0/theme.json'
    $original = [IO.File]::ReadAllBytes($manifest)
    try {
        [IO.File]::WriteAllText($manifest,'{broken')
        [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20101),0x186,[UIntPtr]::new(2),[IntPtr]::Zero)
        Assert-CommandNotice 20010 '無法完成管理操作，請查看日誌後重試。'
    } finally { [IO.File]::WriteAllBytes($manifest,$original) }
    $log = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $session 'appdata/DrillPaper/logs/management.log')
    if (-not $log.Contains($specific) -or -not $log.Contains('所選或已保存的主題版本不存在或損毀')) { throw '預期驗證錯誤或主題詳細錯誤未寫入日誌。' }
    Send-Command 20011
    $restartHash = (Get-FileHash -LiteralPath $settingsFile).Hash
    $children = Stop-TestApplication
    $app.Dispose()
    $script:app = $null
    $script:notification = [IntPtr]::Zero
    # 已保存的空 Preview 透過 CLI 強制桌布，也必須在建立宿主前友善拒絕。
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $script:app = Start-SecurityProcess -FilePath $application -ArgumentList '--experimental-desktop','--no-smart-sleep' -EvidenceDirectory $session
    $null = $app.Handle
    $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperMonitorProbe]::Find($app.Id,'#32770') | Where-Object { [DrillPaperMonitorProbe]::IsWindowVisible($_) }).Count -eq 1 } 'CLI 桌布覆寫沒有友善拒絕空選擇。'
    $dialog = @([DrillPaperMonitorProbe]::Find($app.Id,'#32770') | Where-Object { [DrillPaperMonitorProbe]::IsWindowVisible($_) })[0]
    $text = Get-SurfaceCaption ([DrillPaperMonitorProbe]::GetDlgItem($dialog,65535))
    $evidence.Add(@{phase='empty-preview-cli-desktop'; text=$text; timestamp=(Get-Date -Format o)})
    Record-Surfaces 'empty-preview-cli-desktop'
    [void][DrillPaperMonitorProbe]::PostMessage($dialog,0x10,[UIntPtr]::Zero,[IntPtr]::Zero)
    if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 1 -or $text -ne $specific -or
        (Get-FileHash -LiteralPath $settingsFile).Hash -ne $restartHash) { throw 'CLI 空選擇拒絕的提示、退出碼或原設定不符。' }
    $app.Dispose()
    $script:app = $null
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $script:app = Start-SecurityProcess -FilePath $application -ArgumentList '--management','--no-smart-sleep' -EvidenceDirectory $session
    $null = $app.Handle
    $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')).Count -eq 1 } 'Preview 重啟沒有通知入口。'
    $script:notification = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')[0]
    $script:manager = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperManagementWindow')[0]
    $script:list = [DrillPaperMonitorProbe]::GetDlgItem($manager,20108)
    Wait-Ready 1
    Assert-FreshMetrics
    if ([DrillPaperMonitorProbe]::GetParent(@(Get-Surfaces)[0]) -ne [IntPtr]::Zero -or
        (Get-FileHash -LiteralPath $settingsFile).Hash -ne $restartHash) { throw 'Preview 空選擇重啟未保留。' }
    Assert-CommandNotice 20003 $specific
    # 選回有效目標後才允許切回桌布。
    [DrillPaperMonitorProbe]::Check($app.Id,$list,0,$true)
    Send-Command 20013
    Wait-Ready 1
    if ([DrillPaperMonitorProbe]::GetParent(@(Get-Surfaces)[0]) -eq [IntPtr]::Zero) { throw '選回目標後仍無法套用桌布。' }
    Record-Surfaces 'desktop-restored-with-selection'
    $children += Stop-TestApplication
    $app.Dispose()
    $script:app = $null
    @{result='PASS'; application=$application; hash=(Get-FileHash -LiteralPath $application).Hash;
        observedExitedChildren=$children; evidence=@($evidence); manualVisual='NOT RUN'; timestamp=(Get-Date -Format o)} |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8
}
function Assert-FreshMetrics {
    <# 確認所有已握手宿主繼續推送新資料；不宣稱 DOM 或畫面已更新。 #>
    $windows = @(Get-Surfaces)
    if ($windows.Count -ne $allSurfaceCount) { throw '持續資料驗證的宿主數量不符。' }
    foreach ($window in $windows) {
        $tick = [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64()
        Wait-Condition { [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64() -gt $tick } '宿主沒有繼續推送新的指標。'
        if ($DesktopPowerRecovery) {
            $health = [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.HealthTick').ToInt64()
            Wait-Condition { [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.HealthTick').ToInt64() -gt $health } '頁面沒有回應新的 JS 探針。'
        }
    }
}
function Set-ControlledLock([bool]$Locked) {
    <# 僅送受控通知到隔離程序，不鎖定真正工作階段。
    Args:
        Locked: 是否模擬工作階段鎖定通知。
    #>
    $power = @([DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperPowerEvents'))
    if ($power.Count -ne 1) { throw '沒有唯一的受測電源事件入口。' }
    $event = if ($Locked) { 7 } else { 8 }
    [void][DrillPaperMonitorProbe]::SendMessage($power[0],0x2B1,[UIntPtr]::new([uint32]$event),[IntPtr]::Zero)
}
function Stop-OwnedWebView([string]$Kind) {
    <# 持有精確程序實體後才注入故障，拒絕 PID 重用或 profile 不符。
    Args:
        Kind: browser 或 renderer。
    #>
    $webviewProfile = Join-Path $session 'appdata/DrillPaper/WebView2'
    $browser = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($app.Id) AND Name='msedgewebview2.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '--type=' -and $_.CommandLine.IndexOf($webviewProfile,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if ($browser.Count -ne 1) { throw '無法驗證唯一的隔離 browser，未終止程序。' }
    $browserProcess = Get-Process -Id $browser[0].ProcessId -ErrorAction Stop
    try {
    $null = $browserProcess.Handle
    if ($browserProcess.Path -ne $browser[0].ExecutablePath -or
        [Math]::Abs(($browserProcess.StartTime.ToUniversalTime() - $browser[0].CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1 -or
        $browserProcess.StartTime -lt $app.StartTime) { throw 'browser 實體身分不符，未終止程序。' }
    $targets = if ($Kind -eq 'browser') { $browser } else {
        @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($browser[0].ProcessId) AND Name='msedgewebview2.exe'" |
            Where-Object { $_.CommandLine -match '--type=renderer(?:\s|$)' })
    }
    if (@($targets).Count -eq 0) { throw '沒有可驗證的 WebView2 故障目標。' }
    $victims = @()
    foreach ($entry in $targets) {
        if ($browserProcess.HasExited) { throw '列舉期間 browser 已退出，拒絕沿用其 PID。' }
        $victim = Get-Process -Id $entry.ProcessId -ErrorAction Stop
        try {
            $null = $victim.Handle
            if ([Math]::Abs(($victim.StartTime.ToUniversalTime() - $entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1 -or
                $victim.StartTime -lt $app.StartTime -or $victim.Path -ne $entry.ExecutablePath) { throw '故障目標的精確身分不符，未終止。' }
            $victims += @{id=$victim.Id; start=$victim.StartTime.ToString('o'); path=$victim.Path}
            $victim.Kill()
            if (-not $victim.WaitForExit(5000)) { throw '故障目標未在期限內退出。' }
        } finally { $victim.Dispose() }
    }
    $evidence.Add(@{phase="injected-$Kind"; victims=$victims; timestamp=(Get-Date -Format o)})
    } finally { $browserProcess.Dispose() }
}
function Test-DesktopPowerRecovery {
    <# 在目前全部目標上驗證受控政策、真實程序故障及 JS 無回應的有界復原。 #>
    # 由可信設定介面開啟智慧休眠；不改產品預設，也不操控其他桌布。
    [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20103),0xF1,[UIntPtr]::new(1),[IntPtr]::Zero)
    Send-Command 20010
    Wait-Ready $allSurfaceCount
    if (-not (Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsFile | ConvertFrom-Json).smartSleep) { throw '智慧休眠沒有透過設定生效。' }
    Assert-FreshMetrics
    Record-Surfaces 'smart-sleep-enabled'
    Send-Command 20002
    Wait-Condition { $windows=@(Get-Surfaces); $windows.Count -eq $allSurfaceCount -and @($windows | Where-Object { (Get-SurfaceCaption $_) -notlike '*display-off*已暫停' }).Count -eq 0 } '並非所有目標均完成手動暫停。'
    Set-ControlledLock $true
    Set-ControlledLock $false
    # 超過健康探針期限仍暫停，確認不把省電時間誤判為 renderer 卡死。
    $pauseEpochs = @((Get-Surfaces) | ForEach-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.LoadEpoch').ToInt64() })
    Start-Sleep -Seconds 17
    $afterPauseEpochs = @((Get-Surfaces) | ForEach-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.LoadEpoch').ToInt64() })
    if (@(Compare-Object $pauseEpochs $afterPauseEpochs).Count) { throw '手動暫停期間錯誤觸發了渲染重建。' }
    if (@(Get-Surfaces | Where-Object { [DrillPaperMonitorProbe]::IsWindowVisible($_) }).Count) { throw '受控電源往返取消了手動暫停。' }
    Record-Surfaces 'manual-pause-survives-controlled-lock'
    Send-Command 20002
    Assert-FreshMetrics
    foreach ($kind in @('renderer','browser')) {
        Send-Command 10002
        Wait-Ready $allSurfaceCount
        $oldReady = @((Get-Surfaces) | ForEach-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() } | Measure-Object -Maximum).Maximum
        Set-ControlledLock $true
        Wait-Condition { $windows=@(Get-Surfaces); $windows.Count -eq $allSurfaceCount -and @($windows | Where-Object { (Get-SurfaceCaption $_) -notlike '*locked*已暫停' }).Count -eq 0 } '受控鎖定未暫停全部目標。'
        Record-Surfaces "$kind-before-fault-controlled-lock"
        Stop-OwnedWebView $kind
        Set-ControlledLock $false
        Wait-Condition { $windows = @(Get-Surfaces); $windows.Count -eq $allSurfaceCount -and @($windows | Where-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() -le $oldReady }).Count -eq 0 } '故障與受控電源交錯後未全部重新握手。'
        Assert-FreshMetrics
        Record-Surfaces "$kind-recovered-after-controlled-unlock"
    }
    # 連續 renderer 故障涵蓋原主題 3 次重建、Minimal 與 Minimal 的 3 次重建後停止。
    Send-Command 10002
    Wait-Ready $allSurfaceCount
    for ($round=1; $round -le 8; $round++) {
        $oldReady = @((Get-Surfaces) | ForEach-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() } | Measure-Object -Maximum).Maximum
        Stop-OwnedWebView 'renderer'
        if ($round -eq 8) {
            Wait-Condition { $windows=@(Get-Surfaces); $windows.Count -eq $allSurfaceCount -and @($windows | Where-Object { (Get-SurfaceCaption $_) -notlike '*渲染已停止*' -or [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() -ne 0 }).Count -eq 0 } '超過額度後未全部友善停止渲染。'
        } else {
            Wait-Condition { $windows=@(Get-Surfaces); $windows.Count -eq $allSurfaceCount -and @($windows | Where-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() -le $oldReady }).Count -eq 0 } '連續故障後沒有新的握手。'
            Assert-FreshMetrics
        }
        Record-Surfaces "bounded-renderer-$round"
    }
    # 新選題重設額度；以真正 JS 無限迴圈觸發 Runtime 的 unresponsive 通知。
    $loopScript = @'
import { DrillPaperClient } from './desktop-monitor-sdk.js';
const client = new DrillPaperClient(chrome.webview);
await client.ready();
await client.getSnapshot();
await client.subscribe({metrics:['cpu'],intervalMs:1000});
setTimeout(async () => { await client.subscribe({metrics:['cpu'],intervalMs:1000}); while (true) {} }, 3000);
'@
    $loopScript | Set-Content -LiteralPath (Join-Path $session 'appdata/DrillPaper/themes/multi-probe@1.0.0/main.js') -Encoding UTF8
    Send-Command 11000
    Wait-Ready $allSurfaceCount
    $loopStart = @(Get-Surfaces | ForEach-Object {
        if ((Get-SurfaceCaption $_) -notlike '*多宿主驗證*') { throw '無限迴圈探針未載入，不得以 Minimal 冒充成功。' }
        @{window=$_; load=[DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.LoadEpoch').ToInt64(); ready=[DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64()}
    })
    Record-Surfaces 'infinite-loop-initial-handshake'
    Wait-Condition {
        @($loopStart | Where-Object { [DrillPaperMonitorProbe]::GetProp($_.window,'DrillPaper.LoadEpoch').ToInt64() -ne $_.load -or
            [DrillPaperMonitorProbe]::GetProp($_.window,'DrillPaper.ReadyEpoch').ToInt64() -le $_.ready }).Count -eq 0
    } '尚未觀察到原探針進入無限迴圈前的第二次訂閱。'
    Record-Surfaces 'infinite-loop-entered'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        Record-Surfaces 'infinite-loop-observation'
        if ($app.HasExited) { throw 'JS 無回應導致原生程序退出。' }
        $windows = @(Get-Surfaces)
        $recovered = $windows.Count -eq $allSurfaceCount -and @($windows | Where-Object {
            (Get-SurfaceCaption $_) -notlike '*Minimal Monitor*Live metrics' -or
            [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() -le 0
        }).Count -eq 0
        if ($recovered) { break }
        Start-Sleep -Seconds 2
    } while ($clock.Elapsed.TotalSeconds -lt 180)
    if (-not $recovered) { throw 'JS 無限迴圈未在 180 秒內有界退回可信 Minimal。' }
    Assert-FreshMetrics
    Record-Surfaces 'infinite-loop-bounded-minimal'
    $evidence.Add(@{phase='infinite-loop-duration'; seconds=$clock.Elapsed.TotalSeconds})
    Send-Command 10001
    Wait-Ready $allSurfaceCount
}
function Assert-AllAreas {
    <# 以獨立 Windows 列舉結果斷言完整螢幕幾何與宿主數量。 #>
    $expected = @([DrillPaperMonitorProbe]::DesktopRects())
    $windows = @(Get-Surfaces)
    if ($windows.Count -ne $expected.Count) { throw '選取全部目標後宿主數量與 Windows 桌面區域數不符。' }
    foreach ($area in $expected) {
        $matches = @($windows | Where-Object {
            $rect = [DrillPaperMonitorProbe+Rect]::new(); [void][DrillPaperMonitorProbe]::GetWindowRect($_,[ref]$rect)
            $rect.left -eq $area.left -and $rect.top -eq $area.top -and $rect.right -eq $area.right -and $rect.bottom -eq $area.bottom
        })
        if ($matches.Count -ne 1) { throw '有效桌面區域沒有唯一且完整的宿主矩形。' }
    }
}
function Assert-StaleNotifications([object[]]$Previous) {
    <# 驗證排隊的舊世代／其他宿主通知無法改動目前宿主或偏好。
    Args:
        Previous: 切換或重建前的宿主與世代。
    #>
    $hash = (Get-FileHash -LiteralPath $settingsFile).Hash
    foreach ($window in @(Get-Surfaces)) {
        $epoch = [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.LoadEpoch').ToInt64()
        $ready = [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64()
        foreach ($old in $Previous) {
            if ($old.epoch -eq $epoch) { throw '測試前提錯誤：舊世代仍是目前世代。' }
            foreach ($message in @(0x8042,0x8038)) {
                [void][DrillPaperMonitorProbe]::SendMessage($window,$message,[UIntPtr]::new([uint64]$old.epoch),[IntPtr]::Zero)
            }
            [void][DrillPaperMonitorProbe]::SendMessage($window,0x8041,[UIntPtr]::Zero,[IntPtr]::new($old.epoch))
        }
        if ([DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.LoadEpoch').ToInt64() -ne $epoch -or
            [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64() -ne $ready) { throw '舊世代通知更新了目前宿主。' }
        $tick = [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64()
        Wait-Condition { [DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64() -gt $tick } '拒絕舊訊息後目前頁面沒有繼續接收指標。'
    }
    if ((Get-FileHash -LiteralPath $settingsFile).Hash -ne $hash) { throw '舊世代通知改變了保存偏好。' }
}
function Stop-TestApplication {
    <# 正式退出並等待當下可觀察到的 WebView2 子程序。
    Returns:
        已觀察的子程序數量。
    #>
    $tree = @(Get-CimInstance Win32_Process)
    $ids = [Collections.Generic.HashSet[int]]::new(); [void]$ids.Add($app.Id)
    do {
        $added = $false
        foreach ($item in $tree) {
            if ($ids.Contains([int]$item.ParentProcessId) -and $ids.Add([int]$item.ProcessId)) { $added = $true }
        }
    } while ($added)
    $children = @(foreach ($childId in $ids) {
        if ($childId -ne $app.Id) {
            $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
            if ($child) {
                $null = $child.Handle
                $entry = $tree | Where-Object { $_.ProcessId -eq $childId }
                if ([Math]::Abs(($child.StartTime.ToUniversalTime() - $entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1 -or $child.StartTime -lt $app.StartTime) {
                    $child.Dispose(); throw '子程序身分已改變，拒絕以重用 PID 判定退出。'
                }
                $child
            }
        }
    })
    if ($children.Count -eq 0) { throw '未觀察到子程序，無法驗證清理。' }
    Send-Command 20006
    if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 0) { throw '受測程序未正常退出。' }
    foreach ($child in $children) { if (-not $child.WaitForExit(15000)) { throw "子程序未退出：$($child.Id)" }; $child.Dispose() }
    return $children.Count
}
try {
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $server = Start-Process -FilePath (Get-Command node).Source -ArgumentList ('"' + (Join-Path $PSScriptRoot '../tests/fixtures/security-server.mjs') + '"'),('"' + $session + '"') -WindowStyle Hidden -PassThru
    $serverClock = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath (Join-Path $session 'server.json'))) {
        if ($server.HasExited -or $serverClock.Elapsed.TotalSeconds -gt 10) { throw '無法啟動網路回歸接收端。' }
        Start-Sleep -Milliseconds 100
    }
    $port = (Get-Content -Raw -LiteralPath (Join-Path $session 'server.json') | ConvertFrom-Json).port
    $source = Join-Path $session 'source'
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    '{"id":"multi-probe","name":"多宿主驗證","version":"1.0.0","apiVersion":"1","entry":"index.html","author":"DrillPaper","description":"","capabilities":["cpu"],"permissions":[]}' | Set-Content -LiteralPath (Join-Path $source 'theme.json') -Encoding UTF8
    '<!doctype html><meta charset="UTF-8"><script type="module" src="./main.js"></script>' | Set-Content -LiteralPath (Join-Path $source 'index.html') -Encoding UTF8
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../sdk/javascript/desktop-monitor-sdk.js') -Destination $source
    $probeTemplate = @'
import { DrillPaperClient } from './desktop-monitor-sdk.js';
/** 只在安全與幾何探針符合預期時訂閱，禁止 fallback 冒充成功。 */
async function run() {
  const allowed = __ENABLED__;
  if (localStorage.getItem('other-monitor') !== null || document.cookie.includes('other-monitor')) throw Error('來源沿用舊宿主資料');
  localStorage.setItem('other-monitor', location.origin);
  document.cookie = 'other-monitor=1; SameSite=Strict';
  const url = '__BASE__/multi?origin=' + encodeURIComponent(location.origin) + '&w=' + innerWidth + '&h=' + innerHeight + '&dpr=' + devicePixelRatio;
  const reached = await fetch(url).then(response => response.text(), () => 'blocked');
  if ((reached === 'fixture-ok') !== allowed) throw Error('全域網路政策錯誤');
  const client = new DrillPaperClient(chrome.webview);
  await client.ready();
  await client.getSnapshot();
  await client.subscribe({ metrics: ['cpu'], intervalMs: 1000 });
  // 留下已排程的舊頁面工作，在切換、停用及退出時與 controller 清理競爭。
  setInterval(() => {
    for (const type of ['metrics.unsubscribe', 'settings.apply', 'theme.remove', 'app.exit']) {
      chrome.webview.postMessage({ apiVersion: '1', type, requestId: null, timestamp: new Date().toISOString(), payload: {} });
    }
  }, 200);
}
run().catch(error => console.error(error));
'@
    $probeTemplate.Replace('__ENABLED__','false').Replace('__BASE__',"http://127.0.0.1:$port") | Set-Content -LiteralPath (Join-Path $source 'main.js') -Encoding UTF8
    $import = Start-SecurityProcess -FilePath $application -ArgumentList '--import-theme',$source -EvidenceDirectory $session -CommandOnly
    $null = $import.Handle
    if (-not $import.WaitForExit(15000) -or $import.ExitCode -ne 0) { throw '多宿主探針主題匯入失敗。' }
    $import.Dispose()
    $app = Start-SecurityProcess -FilePath $application -ArgumentList '--management','--preview','--no-smart-sleep' -EvidenceDirectory $session
    $null = $app.Handle
    $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperManagementWindow')).Count -eq 1 } '管理介面未建立。'
    $notification = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')[0]
    $manager = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperManagementWindow')[0]
    $list = [DrillPaperMonitorProbe]::GetDlgItem($manager,20108)
    $count = [DrillPaperMonitorProbe]::SendMessage($list,0x1004,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32()
    if ($count -lt 1) { throw '沒有可選螢幕。' }
    Wait-Ready 1
    $checked = @(for ($index=0; $index -lt $count; $index++) {
        if ([DrillPaperMonitorProbe]::SendMessage($list,0x102C,[UIntPtr]::new([uint32]$index),[IntPtr]::new(0xF000)).ToInt32() -eq 0x2000) { $index }
    })
    if ($checked.Count -ne 1) { throw '首次預設未只選一個主螢幕目標。' }
    # 所有目前連接目標由原生 UI 明確勾選，不改系統顯示設定。
    for ($index=0; $index -lt $count; $index++) { [DrillPaperMonitorProbe]::Check($app.Id,$list,$index,$true) }
    [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20102),0x14E,[UIntPtr]::Zero,[IntPtr]::Zero)
    [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20103),0xF1,[UIntPtr]::Zero,[IntPtr]::Zero)
    Send-Command 20010
    Wait-Ready 0
    Wait-Condition { @(@(Get-Surfaces) | Where-Object { [DrillPaperMonitorProbe]::GetParent($_) -eq [IntPtr]::Zero }).Count -eq 0 } '桌布目標未全部附掛。'
    $settingsFile = Join-Path $session 'appdata/DrillPaper/settings.json'
    $settings = Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsFile | ConvertFrom-Json
    if ($settings.schemaVersion -ne 2 -or @($settings.monitorTargets).Count -ne $count) { throw '目標未完整保存。' }
    Assert-AllAreas
    $allSurfaceCount = @([DrillPaperMonitorProbe]::DesktopRects()).Count
    Record-Surfaces 'all-selected-minimal'
    if ($EmptySelectionNotice) { Test-EmptySelectionNotice; Write-Output "PASS：空選擇提示及 Preview 範圍；$session"; return }
    Send-Command 10002
    Wait-Ready $allSurfaceCount
    Record-Surfaces 'all-selected-dashboard'
    $before = @(Get-Surfaces | ForEach-Object { @{window=$_; epoch=[DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.LoadEpoch').ToInt64()} })
    # 向其他宿主注入不屬於它的世代，單屏則注入無效世代。
    foreach ($item in $before) {
        $foreign = @($before | Where-Object { $_.window -ne $item.window } | Select-Object -First 1)
        $epoch = if ($foreign.Count) { $foreign[0].epoch } else { $item.epoch + 10000 }
        [void][DrillPaperMonitorProbe]::SendMessage($item.window,0x8042,[UIntPtr]::new([uint64]$epoch),[IntPtr]::Zero)
        [void][DrillPaperMonitorProbe]::SendMessage($item.window,0x8038,[UIntPtr]::new([uint64]$epoch),[IntPtr]::Zero)
        [void][DrillPaperMonitorProbe]::SendMessage($item.window,0x8041,[UIntPtr]::Zero,[IntPtr]::new($epoch))
        if ([DrillPaperMonitorProbe]::GetProp($item.window,'DrillPaper.LoadEpoch').ToInt64() -ne $item.epoch) { throw '跨宿主世代改變了目標主題。' }
    }
    $failedTarget = $before[0]
    [void][DrillPaperMonitorProbe]::SendMessage($failedTarget.window,0x8042,[UIntPtr]::new([uint64]$failedTarget.epoch),[IntPtr]::Zero)
    Wait-Ready $allSurfaceCount
    if ([DrillPaperMonitorProbe]::GetProp($failedTarget.window,'DrillPaper.LoadEpoch').ToInt64() -le $failedTarget.epoch) { throw '有效的單目標故障通知未啟動復原。' }
    foreach ($item in @($before | Where-Object { $_.window -ne $failedTarget.window })) {
        if ([DrillPaperMonitorProbe]::GetProp($item.window,'DrillPaper.LoadEpoch').ToInt64() -ne $item.epoch) { throw '單目標故障影響了其他宿主。' }
    }
    Record-Surfaces 'one-target-fallback'
    Send-Command 20002
    if (@(Get-Surfaces | Where-Object { [DrillPaperMonitorProbe]::IsWindowVisible($_) }).Count) { throw '暫停未隱藏所有宿主。' }
    Send-Command 20002
    Wait-Ready $allSurfaceCount
    # 取消勾選草稿，再由取消恢復，設定檔應完全不變。
    $savedHash = (Get-FileHash -LiteralPath $settingsFile).Hash
    [DrillPaperMonitorProbe]::Check($app.Id,$list,0,$false)
    Send-Command 20011
    if ((Get-FileHash -LiteralPath $settingsFile).Hash -ne $savedHash -or
        [DrillPaperMonitorProbe]::SendMessage($list,0x102C,[UIntPtr]::Zero,[IntPtr]::new(0xF000)).ToInt32() -ne 0x2000) { throw '取消未恢復螢幕草稿。' }
    foreach ($enabled in @($false,$true,$false)) {
        $installedScript = Join-Path $session 'appdata/DrillPaper/themes/multi-probe@1.0.0/main.js'
        $probeTemplate.Replace('__ENABLED__', $(if ($enabled) { 'true' } else { 'false' })).Replace('__BASE__',"http://127.0.0.1:$port") |
            Set-Content -LiteralPath $installedScript -Encoding UTF8
        $requestsFile = Join-Path $session 'requests.jsonl'
        $beforeCount = if (Test-Path -LiteralPath $requestsFile) { @(Get-Content -LiteralPath $requestsFile).Count } else { 0 }
        [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20101),0x186,[UIntPtr]::new(2),[IntPtr]::Zero)
        [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20106),0xF1,[UIntPtr]::new([uint32]$enabled),[IntPtr]::Zero)
        Send-Command 20010; Wait-Ready $allSurfaceCount; Assert-AllAreas
        foreach ($window in @(Get-Surfaces)) {
            $caption = [Text.StringBuilder]::new(512)
            [void][DrillPaperMonitorProbe]::ReadText($window,0xD,[UIntPtr]::new(512),$caption)
            if (-not $caption.ToString().Contains('多宿主驗證')) { throw '主題探針沒有完成，不能用安全 fallback 宣稱成功。' }
        }
        $received = if (Test-Path -LiteralPath $requestsFile) { @(Get-Content -LiteralPath $requestsFile | Select-Object -Skip $beforeCount | ForEach-Object { $_ | ConvertFrom-Json }) } else { @() }
        if (($enabled -and $received.Count -ne $allSurfaceCount) -or (-not $enabled -and $received.Count -ne 0)) { throw '多宿主 HTTP off/on/off 實收數量錯誤。' }
        if ($enabled) {
            $origins = @($received | ForEach-Object { [Uri]::UnescapeDataString(((($_.url -split 'origin=')[1]) -split '&')[0]) })
            if (@($origins | Select-Object -Unique).Count -ne $allSurfaceCount) { throw '不同宿主沒有獨立來源。' }
            $viewports = @($received | ForEach-Object {
                $values = @{}; foreach ($pair in (($_.url -split '\?')[1] -split '&')) { $key,$value = $pair -split '=',2; $values[$key] = [Uri]::UnescapeDataString($value) }
                @{width=[double]$values.w * [double]$values.dpr; height=[double]$values.h * [double]$values.dpr; scale=[double]$values.dpr}
            })
            foreach ($area in @([DrillPaperMonitorProbe]::DesktopRects())) {
                if (@($viewports | Where-Object { [Math]::Abs($_.width - ($area.right - $area.left)) -le 2 -and [Math]::Abs($_.height - ($area.bottom - $area.top)) -le 2 }).Count -eq 0) { throw '主題 viewport 不是完整螢幕尺寸。' }
            }
            $viewports | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'viewports.json') -Encoding UTF8
        }
        Record-Surfaces "network-$enabled"
    }
    # 保存回 Minimal，先以未改動的全部螢幕設定重啟一次。
    $stale = @(Get-Surfaces | ForEach-Object { @{window=$_; epoch=[DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.LoadEpoch').ToInt64()} })
    for ($iteration=0; $iteration -lt 20; $iteration++) { Send-Command $(if ($iteration % 2) { 10001 } else { 10002 }) }
    Wait-Ready $allSurfaceCount
    Assert-StaleNotifications $stale
    Record-Surfaces 'rapid-switch-stale-notifications'
    [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20101),0x186,[UIntPtr]::Zero,[IntPtr]::Zero)
    Send-Command 20010; Wait-Ready $allSurfaceCount
    $restartHash = (Get-FileHash -LiteralPath $settingsFile).Hash
    $children = Stop-TestApplication; $app.Dispose()
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $app = Start-SecurityProcess -FilePath $application -ArgumentList '--management','--no-smart-sleep' -EvidenceDirectory $session
    $null = $app.Handle; $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')).Count -eq 1 } '雙屏重啟沒有通知入口。'
    $notification = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')[0]
    Wait-Ready $allSurfaceCount; Assert-AllAreas
    if ((Get-FileHash -LiteralPath $settingsFile).Hash -ne $restartHash) { throw '雙屏重啟改寫了原保存偏好。' }
    $manager = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperManagementWindow')[0]
    $list = [DrillPaperMonitorProbe]::GetDlgItem($manager,20108)
    Record-Surfaces 'all-selected-restart'
    if ($DesktopPowerRecovery) { Test-DesktopPowerRecovery }
    # 候選 ZIP 不含測試工具，允許明確指定同次來源建置的外部 fixture。
    $fixturePath = if ($ParentFixturePath) { [IO.Path]::GetFullPath($ParentFixturePath) }
        else { Join-Path ([IO.Path]::GetDirectoryName($application)) 'DrillPaperParentFixture.exe' }
    if (-not (Test-Path -LiteralPath $fixturePath)) { throw '尚未建置跨程序父視窗 fixture。' }
    $fixtureReady = Join-Path $session 'parent-ready.txt'
    $fixture = Start-SecurityProcess -FilePath $fixturePath -ArgumentList $fixtureReady -EvidenceDirectory $session
    $null = $fixture.Handle
    try {
        Wait-Condition { Test-Path -LiteralPath $fixtureReady } 'fixture 未建立父視窗。'
        $parent = [IntPtr]::new([long][IO.File]::ReadAllText($fixtureReady))
        $previousReady = @((Get-Surfaces) | ForEach-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() } | Measure-Object -Maximum).Maximum
        if ($DesktopPowerRecovery) { Set-ControlledLock $true; Send-Command 20002 }
        foreach ($window in @(Get-Surfaces)) { [DrillPaperMonitorProbe]::AttachFixture($window,$app.Id,$parent,$fixture.Id) }
        if ($DesktopPowerRecovery) { Stop-OwnedWebView 'browser' }
        $fixture.Kill(); [void]$fixture.WaitForExit(10000)
        if ($DesktopPowerRecovery) { Set-ControlledLock $false; Send-Command 20002 }
        Wait-Ready $allSurfaceCount; Assert-AllAreas
        foreach ($window in @(Get-Surfaces)) {
            if ([DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64() -le $previousReady) { throw '跨程序父視窗銷毀後未重建所有目標。' }
        }
        Record-Surfaces 'all-targets-parent-crash-recovery'
        if ($DesktopPowerRecovery) { Assert-FreshMetrics }
    } finally { if (-not $fixture.HasExited) { $fixture.Kill(); [void]$fixture.WaitForExit(10000) }; $fixture.Dispose() }
    if ($count -gt 1) {
        $stale = @(Get-Surfaces | ForEach-Object { @{window=$_; epoch=[DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.LoadEpoch').ToInt64()} })
        for ($index=1; $index -lt $count; $index++) { [DrillPaperMonitorProbe]::Check($app.Id,$list,$index,$false) }
        Send-Command 20010; Wait-Ready 1
        # 重新選題建立新世代後再投遞舊宿主通知，避免把仍有效的世代誤當過期。
        Send-Command 10002; Wait-Ready 1
        Assert-StaleNotifications $stale
        Record-Surfaces 'single-selected'
        if (@((Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsFile | ConvertFrom-Json).monitorTargets).Count -ne 1) { throw '取消其中目標後未保存單選。' }
    }
    Send-Command 20004; Wait-Ready 1
    if ([DrillPaperMonitorProbe]::GetParent(@(Get-Surfaces)[0]) -ne [IntPtr]::Zero) { throw 'Preview 仍附掛桌面。' }
    Send-Command 20003; Wait-Ready 1
    Record-Surfaces 'mode-roundtrip'
    $children += Stop-TestApplication
    $app.Dispose()
    # 離線 ID 保存不變，全部斷線才暫用主螢幕。
    $settings = Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsFile | ConvertFrom-Json
    $settings.monitorTargets = @('disconnected-test-target')
    $settings | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $settingsFile -Encoding UTF8
    $offlineHash = (Get-FileHash -LiteralPath $settingsFile).Hash
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $app = Start-SecurityProcess -FilePath $application -ArgumentList '--management','--no-smart-sleep' -EvidenceDirectory $session
    $null = $app.Handle; $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')).Count -eq 1 } '重啟沒有通知視窗。'
    $notification = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')[0]
    Wait-Ready 1
    $manager = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperManagementWindow')[0]
    $status = [Text.StringBuilder]::new(4096)
    [void][DrillPaperMonitorProbe]::ReadText([DrillPaperMonitorProbe]::GetDlgItem($manager,20100),0xD,[UIntPtr]::new(4096),$status)
    if (-not $status.ToString().Contains('已選螢幕皆未連接，暫時顯示於主螢幕')) { throw '全斷線缺少明確暫用提示。' }
    if ((Get-FileHash -LiteralPath $settingsFile).Hash -ne $offlineHash) { throw 'fallback 改寫原目標。' }
    Record-Surfaces 'all-disconnected-primary-fallback'
    $children += Stop-TestApplication
    @{result='PASS'; application=$application; hash=(Get-FileHash -LiteralPath $application).Hash;
        connectedTargets=$count; distinctAreas=$allSurfaceCount; observedExitedChildren=$children;
        evidence=@($evidence); manualVisual='NOT RUN'; realExplorerRestart='NOT RUN'; physicalHotplug='NOT RUN';
        timestamp=(Get-Date -Format o)} | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8
    Write-Output "PASS：螢幕選擇／保存／取消、各宿主握手／世代隔離、暫停／模式、全斷線暫用與子程序清理；$session"
} catch {
    @{result='FAIL'; reason=$_.Exception.Message; timestamp=(Get-Date -Format o); evidence=@($evidence)} |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'failure.json') -Encoding UTF8
    throw
} finally {
    $env:LOCALAPPDATA = $previousLocal
    if ($app) {
        if (-not $app.HasExited) { if ($notification -ne [IntPtr]::Zero) { Send-Command 20006 }; if (-not $app.WaitForExit(10000)) { $app.Kill() } }
        $app.Dispose()
    }
    [void][DrillPaperMonitorProbe]::SetThreadDpiAwarenessContext($previousDpi)
    if ($server) { if (-not $server.HasExited) { $server.Kill(); [void]$server.WaitForExit(5000) }; $server.Dispose() }
}
} catch {
    $diagnostic = Join-Path $PSScriptRoot ('../artifacts/acceptance/rc05-tool-errors/' + [Guid]::NewGuid().ToString('N') + '.log')
    try { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null; $_ | Out-String | Set-Content -LiteralPath $diagnostic -Encoding UTF8 } catch {}
    [Console]::Error.WriteLine("錯誤：無法完成多目標整合觀測，請確認程式路徑、全新證據目錄與執行環境。診斷日誌：$diagnostic")
    exit 1
}
