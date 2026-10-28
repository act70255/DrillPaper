[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$source = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class DesktopMonitorShellProbe
{
    private delegate bool EnumWindowsCallback(IntPtr hwnd, IntPtr state);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EnumWindows(EnumWindowsCallback callback, IntPtr state);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool EnumChildWindows(IntPtr parent, EnumWindowsCallback callback, IntPtr state);

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int GetClassName(IntPtr hwnd, StringBuilder className, int maxCount);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool IsWindowVisible(IntPtr hwnd);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hwnd, out RECT rectangle);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left, Top, Right, Bottom; }

    public static string[] ReadTopLevelWindows()
    {
        var rows = new List<string>();
        EnumWindows((hwnd, state) => {
            var className = new StringBuilder(256);
            GetClassName(hwnd, className, className.Capacity);
            if (className.ToString() == "Progman" || className.ToString() == "WorkerW")
            {
                rows.Add(Describe(hwnd, "TopLevel"));
                EnumChildWindows(hwnd, (child, childState) => {
                    rows.Add(Describe(child, "ChildOf=" + className));
                    return true;
                }, IntPtr.Zero);
            }
            return true;
        }, IntPtr.Zero);
        return rows.ToArray();
    }

    private static string Describe(IntPtr hwnd, string relationship)
    {
        var className = new StringBuilder(256);
        GetClassName(hwnd, className, className.Capacity);
        uint processId;
        GetWindowThreadProcessId(hwnd, out processId);
        RECT rect;
        GetWindowRect(hwnd, out rect);
        return String.Format("{0} HWND=0x{1:X} PID={2} Visible={3} Class={4} Rect={5},{6},{7},{8}",
            relationship, hwnd.ToInt64(), processId, IsWindowVisible(hwnd), className,
            rect.Left, rect.Top, rect.Right, rect.Bottom);
    }
}
'@

Add-Type -TypeDefinition $source -Language CSharp
$rows = [DesktopMonitorShellProbe]::ReadTopLevelWindows()
$shellRows = $rows | Where-Object { $_ -match 'Class=(Progman|WorkerW|SHELLDLL_DefView)' }
if (-not $shellRows) {
    Write-Output "Enumerated $($rows.Count) top-level windows; no Progman or WorkerW shell host was found in this session."
    $rows | Select-Object -First 20
    exit 2
}
Write-Output "Enumerated $($rows.Count) top-level windows. The following rows identify candidate shell windows; this is inventory evidence only."
$shellRows
