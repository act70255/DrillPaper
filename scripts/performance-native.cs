using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

// 僅供實機驗收，不隨產品封裝；不發送電源或工作階段事件。
public static class PerformanceProbe {
    private delegate bool Callback(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent, Callback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int count);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string name);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr window);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int count);
    [DllImport("kernel32.dll")] public static extern uint GetActiveProcessorCount(ushort group);

    /** 找出指定程序的原生視窗。
     * Args:
     *     process: 已驗證的程序識別。
     *     name: 原生類別名稱。
     * Returns:
     *     去除重複的視窗陣列。
     */
    public static IntPtr[] Find(uint process, string name) {
        var found = new HashSet<IntPtr>();
        Callback visit = (window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            var label = new StringBuilder(256); GetClassName(window, label, label.Capacity);
            if (owner == process && label.ToString() == name) found.Add(window);
            return true;
        };
        EnumWindows((window, data) => { visit(window, data); EnumChildWindows(window, visit, data); return true; }, IntPtr.Zero);
        var result = new IntPtr[found.Count]; found.CopyTo(result); return result;
    }

    /** 取得原生宿主的狀態文字。
     * Args:
     *     window: 本次受測宿主。
     * Returns:
     *     UTF-16 狀態文字。
     */
    public static string Caption(IntPtr window) {
        var text = new StringBuilder(1024); GetWindowText(window, text, text.Capacity); return text.ToString();
    }

    [DllImport("kernel32.dll", SetLastError=true)] private static extern IntPtr OpenProcess(uint access, bool inherit, uint process);
    [DllImport("kernel32.dll", SetLastError=true)] private static extern IntPtr VirtualAllocEx(IntPtr process, IntPtr address, UIntPtr size, uint allocation, uint protection);
    [DllImport("kernel32.dll")] private static extern bool VirtualFreeEx(IntPtr process, IntPtr address, UIntPtr size, uint type);
    [DllImport("kernel32.dll")] private static extern bool WriteProcessMemory(IntPtr process, IntPtr address, byte[] bytes, UIntPtr size, out UIntPtr written);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);

    /** 勾選本次受測程序的螢幕清單，不變更系統顯示設定。
     * Args:
     *     process: 已驗證的受測程序。
     *     list: 螢幕清單 HWND。
     *     index: 目標列。
     *     enabled: 是否選取。
     */
    public static void Check(uint process, IntPtr list, int index, bool enabled) {
        uint owner; GetWindowThreadProcessId(list, out owner);
        if (owner != process) throw new InvalidOperationException("螢幕清單所有權不符。");
        IntPtr handle = OpenProcess(0x28, false, process), remote = IntPtr.Zero;
        if (handle == IntPtr.Zero) throw new InvalidOperationException("無法存取受測清單。");
        try {
            var bytes = new byte[88];
            Array.Copy(BitConverter.GetBytes((uint)(enabled ? 0x2000 : 0x1000)), 0, bytes, 12, 4);
            Array.Copy(BitConverter.GetBytes((uint)0xF000), 0, bytes, 16, 4);
            remote = VirtualAllocEx(handle, IntPtr.Zero, new UIntPtr((uint)bytes.Length), 0x3000, 4);
            UIntPtr written;
            if (remote == IntPtr.Zero || !WriteProcessMemory(handle, remote, bytes, new UIntPtr((uint)bytes.Length), out written) || written.ToUInt64() != (ulong)bytes.Length)
                throw new InvalidOperationException("無法寫入受測螢幕清單草稿。");
            SendMessage(list, 0x102B, new UIntPtr((uint)index), remote);
        } finally {
            if (remote != IntPtr.Zero) VirtualFreeEx(handle, remote, UIntPtr.Zero, 0x8000);
            CloseHandle(handle);
        }
    }

    [DllImport("pdh.dll", CharSet=CharSet.Unicode)] private static extern uint PdhOpenQuery(string source, UIntPtr data, out IntPtr query);
    [DllImport("pdh.dll", CharSet=CharSet.Unicode)] private static extern uint PdhAddEnglishCounter(IntPtr query, string path, UIntPtr data, out IntPtr counter);
    [DllImport("pdh.dll")] private static extern uint PdhCollectQueryData(IntPtr query);
    [DllImport("pdh.dll")] private static extern uint PdhCloseQuery(IntPtr query);
    [DllImport("pdh.dll", CharSet=CharSet.Unicode)] private static extern uint PdhGetFormattedCounterArray(IntPtr counter, uint format, ref uint bytes, ref uint count, IntPtr buffer);
    [StructLayout(LayoutKind.Explicit)] private struct Value {
        [FieldOffset(0)] public uint status;
        [FieldOffset(8)] public double value;
    }
    [StructLayout(LayoutKind.Sequential)] private struct Item { public IntPtr name; public Value value; }
    private static IntPtr gpuQuery, gpuCounter;

    /** 建立跨語系 GPU engine 查詢；失敗回傳原始狀態，不補零。
     * Returns:
     *     PDH 狀態碼。
     */
    public static uint OpenGpu() {
        uint status = PdhOpenQuery(null, UIntPtr.Zero, out gpuQuery);
        if (status == 0) status = PdhAddEnglishCounter(gpuQuery, @"\GPU Engine(*)\Utilization Percentage", UIntPtr.Zero, out gpuCounter);
        if (status == 0) status = PdhCollectQueryData(gpuQuery);
        return status;
    }

    /** 讀取所有 engine 原始實例，呼叫端再以已驗證 PID 篩選。
     * Returns:
     *     engine 名稱與百分比；查詢失敗拋出含狀態的錯誤。
     */
    public static Dictionary<string, double> Gpu() {
        uint status = PdhCollectQueryData(gpuQuery);
        if (status != 0) throw new InvalidOperationException("GPU 查詢失敗：" + status);
        uint bytes = 0, count = 0;
        status = PdhGetFormattedCounterArray(gpuCounter, 0x200 | 0x8000, ref bytes, ref count, IntPtr.Zero);
        if (status != 0x800007D2 || bytes == 0) throw new InvalidOperationException("GPU 實例不可用：" + status);
        IntPtr buffer = Marshal.AllocHGlobal((int)bytes);
        try {
            status = PdhGetFormattedCounterArray(gpuCounter, 0x200 | 0x8000, ref bytes, ref count, buffer);
            if (status != 0) throw new InvalidOperationException("GPU 讀值失敗：" + status);
            var result = new Dictionary<string, double>();
            int size = Marshal.SizeOf(typeof(Item));
            for (int index = 0; index < count; index++) {
                var item = (Item)Marshal.PtrToStructure(IntPtr.Add(buffer, index * size), typeof(Item));
                if (item.value.status == 0 || item.value.status == 1) result[Marshal.PtrToStringUni(item.name)] = item.value.value;
            }
            return result;
        } finally { Marshal.FreeHGlobal(buffer); }
    }

    /** 釋放本次觀測的 GPU 查詢。 */
    public static void CloseGpu() { if (gpuQuery != IntPtr.Zero) { PdhCloseQuery(gpuQuery); gpuQuery = IntPtr.Zero; } }
}
