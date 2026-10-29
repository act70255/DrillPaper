[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
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
$session = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ("../artifacts/acceptance/multi-monitor-" + [Guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $session -Force | Out-Null
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
            ready=[DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64()}
    })
    $evidence.Add(@{phase=$Phase; surfaces=$records})
    $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $session 'phases.json') -Encoding UTF8
    Write-Output "已記錄：$Phase"
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
            if ($child) { $null = $child.Handle; $child }
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
}
run().catch(error => console.error(error));
'@
    $probeTemplate.Replace('__ENABLED__','false').Replace('__BASE__',"http://127.0.0.1:$port") | Set-Content -LiteralPath (Join-Path $source 'main.js') -Encoding UTF8
    $import = Start-Process -FilePath $application -ArgumentList '--import-theme',('"' + $source + '"') -WindowStyle Hidden -PassThru
    $null = $import.Handle
    if (-not $import.WaitForExit(15000) -or $import.ExitCode -ne 0) { throw '多宿主探針主題匯入失敗。' }
    $import.Dispose()
    $app = Start-Process -FilePath $application -ArgumentList '--management','--preview','--no-smart-sleep' -WindowStyle Hidden -PassThru
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
    [void][DrillPaperMonitorProbe]::SendMessage([DrillPaperMonitorProbe]::GetDlgItem($manager,20101),0x186,[UIntPtr]::Zero,[IntPtr]::Zero)
    Send-Command 20010; Wait-Ready $allSurfaceCount
    $restartHash = (Get-FileHash -LiteralPath $settingsFile).Hash
    $children = Stop-TestApplication; $app.Dispose()
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $app = Start-Process -FilePath $application -ArgumentList '--management','--no-smart-sleep' -WindowStyle Hidden -PassThru
    $null = $app.Handle; $env:LOCALAPPDATA = $previousLocal
    Wait-Condition { @([DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')).Count -eq 1 } '雙屏重啟沒有通知入口。'
    $notification = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperShellNotifications')[0]
    Wait-Ready $allSurfaceCount; Assert-AllAreas
    if ((Get-FileHash -LiteralPath $settingsFile).Hash -ne $restartHash) { throw '雙屏重啟改寫了原保存偏好。' }
    $manager = [DrillPaperMonitorProbe]::Find($app.Id,'DrillPaperManagementWindow')[0]
    $list = [DrillPaperMonitorProbe]::GetDlgItem($manager,20108)
    Record-Surfaces 'all-selected-restart'
    $fixturePath = Join-Path ([IO.Path]::GetDirectoryName($application)) 'DrillPaperParentFixture.exe'
    if (-not (Test-Path -LiteralPath $fixturePath)) { throw '尚未建置跨程序父視窗 fixture。' }
    $fixtureReady = Join-Path $session 'parent-ready.txt'
    $fixture = Start-Process -FilePath $fixturePath -ArgumentList ('"' + $fixtureReady + '"') -WindowStyle Hidden -PassThru
    $null = $fixture.Handle
    try {
        Wait-Condition { Test-Path -LiteralPath $fixtureReady } 'fixture 未建立父視窗。'
        $parent = [IntPtr]::new([long][IO.File]::ReadAllText($fixtureReady))
        $previousReady = @((Get-Surfaces) | ForEach-Object { [DrillPaperMonitorProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() } | Measure-Object -Maximum).Maximum
        foreach ($window in @(Get-Surfaces)) { [DrillPaperMonitorProbe]::AttachFixture($window,$app.Id,$parent,$fixture.Id) }
        $fixture.Kill(); [void]$fixture.WaitForExit(10000)
        Wait-Ready $allSurfaceCount; Assert-AllAreas
        foreach ($window in @(Get-Surfaces)) {
            if ([DrillPaperMonitorProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64() -le $previousReady) { throw '跨程序父視窗銷毀後未重建所有目標。' }
        }
        Record-Surfaces 'all-targets-parent-crash-recovery'
    } finally { if (-not $fixture.HasExited) { $fixture.Kill(); [void]$fixture.WaitForExit(10000) }; $fixture.Dispose() }
    if ($count -gt 1) {
        for ($index=1; $index -lt $count; $index++) { [DrillPaperMonitorProbe]::Check($app.Id,$list,$index,$false) }
        Send-Command 20010; Wait-Ready 1
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
    $app = Start-Process -FilePath $application -ArgumentList '--management','--no-smart-sleep' -WindowStyle Hidden -PassThru
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
} finally {
    $env:LOCALAPPDATA = $previousLocal
    if ($app) {
        if (-not $app.HasExited) { if ($notification -ne [IntPtr]::Zero) { Send-Command 20006 }; if (-not $app.WaitForExit(10000)) { $app.Kill() } }
        $app.Dispose()
    }
    [void][DrillPaperMonitorProbe]::SetThreadDpiAwarenessContext($previousDpi)
    if ($server) { if (-not $server.HasExited) { $server.Kill(); [void]$server.WaitForExit(5000) }; $server.Dispose() }
}
