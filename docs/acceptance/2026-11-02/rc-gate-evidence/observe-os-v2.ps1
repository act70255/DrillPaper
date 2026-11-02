param([Parameter(Mandatory)][string]$Root)
$ErrorActionPreference = 'Stop'
try {
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class Rc10ReadOnly {
    [UnmanagedFunctionPointer(CallingConvention.Winapi)] private delegate uint Notify(IntPtr context, uint type, IntPtr setting);
    [StructLayout(LayoutKind.Sequential)] private struct Subscription { public IntPtr callback, context; }
    private delegate bool EnumCallback(IntPtr hwnd, IntPtr data);
    [DllImport("powrprof.dll")] private static extern uint PowerSettingRegisterNotification(ref Guid guid, uint flags, ref Subscription sub, out IntPtr registration);
    [DllImport("powrprof.dll")] private static extern uint PowerSettingUnregisterNotification(IntPtr registration);
    [DllImport("wtsapi32.dll", EntryPoint="WTSQuerySessionInformationW", SetLastError=true)] private static extern bool Query(IntPtr server, uint session, int info, out IntPtr data, out int bytes);
    [DllImport("wtsapi32.dll")] private static extern void WTSFreeMemory(IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, EnumCallback callback, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder value, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder value, int count);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern IntPtr GetProp(IntPtr hwnd, string name);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    private static readonly object gate = new object();
    private static readonly Guid displayGuid = new Guid("6fe69556-704a-47a0-8f24-c28d936fda47");
    private static Notify callback = OnPower;
    private static IntPtr registration;
    private static int display = -1;
    private static string displayAt;
    private static long sequence;
    /** 保存 OS 回呼的 console display 值，不送出任何電源訊息。
     * Args:
     *     context: 訂閱內容。
     *     type: 通知類型。
     *     setting: POWERBROADCAST_SETTING。
     * Returns:
     *     Windows 成功代碼。
     */
    private static uint OnPower(IntPtr context, uint type, IntPtr setting) {
        if (type == 0x8013 && setting != IntPtr.Zero && Marshal.PtrToStructure<Guid>(setting) == displayGuid && Marshal.ReadInt32(setting,16) == 4) {
            lock(gate) { display = Marshal.ReadInt32(setting,20); displayAt = DateTimeOffset.Now.ToString("o"); sequence++; }
        }
        return 0;
    }
    /** 訂閱目前及後續電源狀態。
     * Returns:
     *     Windows 註冊結果。
     */
    public static uint Start() {
        Guid guid = displayGuid;
        var sub = new Subscription { callback=Marshal.GetFunctionPointerForDelegate(callback), context=IntPtr.Zero };
        return PowerSettingRegisterNotification(ref guid, 2, ref sub, out registration);
    }
    /** 解除本觀測器的訂閱。 */
    public static void Stop() { if (registration != IntPtr.Zero) PowerSettingUnregisterNotification(registration); }
    /** 同步查詢目前工作階段及隔離宿主的公開狀態。
     * Args:
     *     root: 允許觀察的 EXE 路徑前綴。
     * Returns:
     *     含原始數值、時間及宿主清單的觀測。
     */
    public static Dictionary<string,object> Snapshot(string root) {
        var result = new Dictionary<string,object>();
        result["timestamp"] = DateTimeOffset.Now.ToString("o"); result["tick64"] = Environment.TickCount64;
        lock(gate) { result["consoleDisplay"]=display; result["displayNotificationAt"]=displayAt; result["displaySequence"]=sequence; }
        IntPtr data; int bytes;
        if (!Query(IntPtr.Zero, UInt32.MaxValue, 25, out data, out bytes)) throw new InvalidOperationException("無法查詢 WTS 工作階段："+Marshal.GetLastWin32Error());
        try {
            if (bytes < 20 || Marshal.ReadInt32(data,0) != 1) throw new InvalidOperationException("WTS 擴充資料格式不符。");
            result["sessionBytes"]=bytes; result["sessionId"]=Marshal.ReadInt32(data,8);
            result["sessionConnectState"]=Marshal.ReadInt32(data,12); result["sessionFlags"]=Marshal.ReadInt32(data,16);
        } finally { WTSFreeMemory(data); }
        var hosts = new List<object>(); var seen = new HashSet<IntPtr>();
        EnumCallback check = (hwnd, ignored) => {
            if (!seen.Add(hwnd)) return true;
            var name = new StringBuilder(256); GetClassName(hwnd,name,name.Capacity);
            if (name.ToString() != "DrillPaperPreviewWindow") return true;
            uint pid; GetWindowThreadProcessId(hwnd,out pid);
            string path;
            try { using(var process=Process.GetProcessById((int)pid)) { path=process.MainModule.FileName; } } catch { return true; }
            if (!path.StartsWith(root+"\\",StringComparison.OrdinalIgnoreCase)) return true;
            var title = new StringBuilder(1024); GetWindowText(hwnd,title,title.Capacity);
            var host = new Dictionary<string,object> { ["pid"]=pid,["hwnd"]=hwnd.ToInt64(),["path"]=path,["title"]=title.ToString(),["visible"]=IsWindowVisible(hwnd) };
            foreach(var prop in new[]{"LoadEpoch","ReadyEpoch","MetricsTick","HealthTick","TargetDpi"}) host[prop]=GetProp(hwnd,"DrillPaper."+prop).ToInt64();
            hosts.Add(host); return true;
        };
        EnumWindows((hwnd, ignored)=> { check(hwnd,ignored); EnumChildWindows(hwnd,check,IntPtr.Zero); return true; },IntPtr.Zero);
        result["hosts"]=hosts; result["completedAt"]=DateTimeOffset.Now.ToString("o");
        return result;
    }
}
'@
    $code = [Rc10ReadOnly]::Start()
    if ($code -ne 0) { throw "無法訂閱 console display state：$code" }
    $log = Join-Path $Root 'os-state.jsonl'
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        $sample = [Rc10ReadOnly]::Snapshot($Root)
        if ($sample.consoleDisplay -ge 0) { break }
        Start-Sleep -Milliseconds 50
    } while ($clock.Elapsed.TotalSeconds -lt 5)
    if ($sample.consoleDisplay -lt 0 -or $sample.sessionFlags -notin @(0,1)) { throw '未取得有效的初始 OS 電源／鎖定狀態，禁止啟動實測。' }
    $sample['phase']='before-all'
    $sample | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath $log -Encoding utf8
    $sample | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root 'observer-ready.json') -Encoding utf8
    $failures = [Collections.Generic.HashSet[string]]::new()
    while (-not (Test-Path -LiteralPath (Join-Path $Root 'stop-observer'))) {
        $sample = [Rc10ReadOnly]::Snapshot($Root)
        $sample['phase']='periodic'
        foreach ($label in @('trial7-original','head-original')) {
            $failure = Join-Path $Root "$label/failure.json"
            if ((Test-Path -LiteralPath $failure) -and $failures.Add($label)) {
                $sample['phase']='failure-observed'
                $sample['failurePath']=$failure
                $sample['failureFileModifiedAt']=(Get-Item -LiteralPath $failure).LastWriteTime.ToString('o')
                $sample | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $Root "$label-os-at-failure.json") -Encoding utf8
            }
        }
        $sample | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath $log -Encoding utf8
        Start-Sleep -Milliseconds 100
    }
    $sample = [Rc10ReadOnly]::Snapshot($Root); $sample['phase']='after-all'
    $sample | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath $log -Encoding utf8
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $Root 'observer-error.log') -Encoding utf8
    [Console]::Error.WriteLine('錯誤：只讀 OS 觀測失敗，請查看 observer-error.log。')
    exit 1
} finally { if ('Rc10ReadOnly' -as [type]) { [Rc10ReadOnly]::Stop() } }
