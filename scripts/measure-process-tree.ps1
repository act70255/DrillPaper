[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$ProcessId,
    [ValidateRange(1, 86400)][int]$DurationSeconds = 60,
    [ValidateRange(1, 60)][int]$IntervalSeconds = 1,
    [Parameter(Mandatory)][string]$OutputFile
)

$ErrorActionPreference = 'Stop'
$nativeSnapshotType = 'DrillPaperProcessSnapshotNativeV2' -as [type]
if (-not $nativeSnapshotType) {
    $nativeSource = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class DrillPaperProcessSnapshotNativeV2
{
    private const uint SnapshotProcesses = 0x00000002;
    private const int ErrorNoMoreFiles = 18;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public struct ProcessEntry
    {
        public uint dwSize;
        public uint cntUsage;
        public uint th32ProcessID;
        public IntPtr th32DefaultHeapID;
        public uint th32ModuleID;
        public uint cntThreads;
        public uint th32ParentProcessID;
        public int pcPriClassBase;
        public uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
        public string szExeFile;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint processId);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern bool Process32First(IntPtr snapshot, ref ProcessEntry entry);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    private static extern bool Process32Next(IntPtr snapshot, ref ProcessEntry entry);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    /** 讀取指定 processor group 的作用中邏輯處理器數量。
     * Args:
     *     groupNumber: 0xffff 表示所有 processor groups。
     * Returns:
     *     作用中的邏輯處理器數量。
     */
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint GetActiveProcessorCount(ushort groupNumber);

    public static ProcessEntry[] GetProcesses()
    {
        IntPtr snapshot = CreateToolhelp32Snapshot(SnapshotProcesses, 0);
        if (snapshot == new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error());
        try
        {
            var processes = new List<ProcessEntry>();
            var entry = new ProcessEntry { dwSize = (uint)Marshal.SizeOf(typeof(ProcessEntry)) };
            if (!Process32First(snapshot, ref entry)) throw new Win32Exception(Marshal.GetLastWin32Error());
            do
            {
                processes.Add(entry);
                entry.dwSize = (uint)Marshal.SizeOf(typeof(ProcessEntry));
            }
            while (Process32Next(snapshot, ref entry));

            int error = Marshal.GetLastWin32Error();
            if (error != ErrorNoMoreFiles) throw new Win32Exception(error);
            return processes.ToArray();
        }
        finally { CloseHandle(snapshot); }
    }
}
'@
    Add-Type -TypeDefinition $nativeSource -Language CSharp -ErrorAction Stop
}

$processes = @([DrillPaperProcessSnapshotNativeV2]::GetProcesses() | ForEach-Object {
    [pscustomobject]@{
        ProcessId = [int]$_.th32ProcessID
        ParentProcessId = [int]$_.th32ParentProcessID
        Name = $_.szExeFile
    }
})
$rootProcess = $processes | Where-Object { $_.ProcessId -eq $ProcessId } | Select-Object -First 1
$outputPath = [IO.Path]::GetFullPath($OutputFile)
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputPath))
$metadataPath = [IO.Path]::ChangeExtension($outputPath, '.metadata.json')
$rows = [System.Collections.Generic.List[object]]::new()
$clock = [Diagnostics.Stopwatch]::StartNew()
$culture = [Globalization.CultureInfo]::InvariantCulture
$firstSampleTime = $null
$observedSpan = [decimal]0
$rootRuntime = $null
$rootStartedUtc = $null
$logicalProcessors = $null
$runStatus = 'FAILED'
$failureReason = $null
$failureDetails = $null
$totalSkippedReads = 0

try {
if (-not $rootProcess) { throw "找不到量測根程序 $ProcessId。" }
try {
    $rootRuntime = Get-Process -Id $ProcessId -ErrorAction Stop
    # 保留原始程序 Handle；PID 被重新使用時也不會改成量測另一個程序。
    $rootHandle = $rootRuntime.Handle
    $rootStartedUtc = $rootRuntime.StartTime.ToUniversalTime().ToString('o')
} catch {
    $failureDetails = $_.Exception.Message
    throw "無法存取量測根程序 $ProcessId。"
}
$logicalProcessors = [DrillPaperProcessSnapshotNativeV2]::GetActiveProcessorCount([System.UInt16]::MaxValue)
if ($logicalProcessors -lt 1) { throw '無法取得有效的邏輯處理器數量。' }
while ($true) {
    $rootRuntime.Refresh()
    if ($rootRuntime.HasExited) { throw '量測根程序已提前退出，保留資料但不判定完整量測通過。' }
    $processes = @([DrillPaperProcessSnapshotNativeV2]::GetProcesses() | ForEach-Object {
        [pscustomobject]@{
            ProcessId = [int]$_.th32ProcessID
            ParentProcessId = [int]$_.th32ParentProcessID
            Name = $_.szExeFile
        }
    })
    $byParent = @{}
    foreach ($process in $processes) {
        $key = [string]$process.ParentProcessId
        if (-not $byParent.ContainsKey($key)) { $byParent[$key] = [System.Collections.Generic.List[object]]::new() }
        $byParent[$key].Add($process)
    }

    $selected = @{}
    $selected[[string]$ProcessId] = $true
    $frontier = [System.Collections.Generic.Queue[int]]::new()
    $frontier.Enqueue($ProcessId)
    while ($frontier.Count -gt 0) {
        $parentId = $frontier.Dequeue()
        foreach ($child in $byParent[[string]$parentId]) {
            $childId = [int]$child.ProcessId
            $childKey = [string]$childId
            if (-not $selected.ContainsKey($childKey)) {
                $selected[$childKey] = $true
                $frontier.Enqueue($childId)
            }
        }
    }

    $cpuSeconds = 0.0
    [long]$workingSetBytes = 0
    [long]$privateBytes = 0
    [long]$totalHandles = 0
    $names = [System.Collections.Generic.List[string]]::new()
    $measuredIds = [System.Collections.Generic.List[string]]::new()
    $skippedIds = [System.Collections.Generic.List[string]]::new()
    foreach ($id in $selected.Keys) {
        try {
            $process = if ([int]$id -eq $ProcessId) { $rootRuntime } else { Get-Process -Id ([int]$id) -ErrorAction Stop }
            $processCpu = $process.TotalProcessorTime.TotalSeconds
            $processWorking = $process.WorkingSet64
            $processPrivate = $process.PrivateMemorySize64
            $processHandles = $process.HandleCount
            $processName = $process.ProcessName
            # 完整取得單一程序讀值後才累加，避免只算進部分資料卻未列入 PID。
            $cpuSeconds += $processCpu
            $workingSetBytes += $processWorking
            $privateBytes += $processPrivate
            $totalHandles += $processHandles
            $names.Add($processName)
            $measuredIds.Add($id)
        }
        catch {
            if ([int]$id -eq $ProcessId) {
                $failureDetails = $_.Exception.Message
                throw '無法讀取根程序的資源資料。'
            }
            # 子程序可能在列舉與讀取之間退出，明確記錄略過的 PID。
            $skippedIds.Add($id)
            $totalSkippedReads++
        }
    }
    if ($rootRuntime.HasExited) { throw '量測根程序已提前退出，保留資料但不判定完整量測通過。' }
    $elapsedText = $clock.Elapsed.TotalSeconds.ToString('0.###', $culture)
    $elapsed = [decimal]::Parse($elapsedText, $culture)
    if ($null -eq $firstSampleTime) { $firstSampleTime = $elapsed }
    $observedSpan = $elapsed - $firstSampleTime
    $rows.Add([pscustomobject]@{
        TimestampUtc = [DateTime]::UtcNow.ToString('o')
        ElapsedSeconds = $elapsedText
        RootProcessId = $ProcessId
        ProcessCount = $measuredIds.Count
        SelectedProcessCount = $selected.Count
        ProcessIds = ($measuredIds | Sort-Object) -join ';'
        ProcessNames = (($names | Sort-Object -Unique) -join ';')
        CpuTimeSeconds = $cpuSeconds.ToString('0.###', $culture)
        WorkingSetBytes = $workingSetBytes
        PrivateBytes = $privateBytes
        TotalHandles = $totalHandles
        RootHandles = $rootRuntime.HandleCount
        RootWindowTitle = $rootRuntime.MainWindowTitle
        SkippedProcessIds = ($skippedIds | Sort-Object) -join ';'
    })
    if ($observedSpan -ge $DurationSeconds) { break }
    Start-Sleep -Seconds $IntervalSeconds
}
$runStatus = 'COMPLETED'
} catch {
    $failureReason = $_.Exception.Message
    throw
} finally {
$clock.Stop()
if ($rows.Count -gt 0) { $rows | Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding utf8 }
$os = Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion' -ErrorAction SilentlyContinue
[pscustomobject]@{
    RootProcessId = $ProcessId
    RootProcessName = $rootProcess.Name
    RootProcessStartedUtc = $rootStartedUtc
    LogicalProcessorCount = $logicalProcessors
    ObserverAvailableProcessorCount = [Environment]::ProcessorCount
    RunStatus = $runStatus
    FailureReason = $failureReason
    FailureDetails = $failureDetails
    TotalSkippedProcessReads = $totalSkippedReads
    OsCaption = $os.Caption
    OsVersion = [Environment]::OSVersion.Version.ToString()
    OsBuild = $os.CurrentBuildNumber
    DurationSeconds = $DurationSeconds
    ObservedSpanSeconds = $observedSpan
    IntervalSeconds = $IntervalSeconds
    SampleCount = $rows.Count
    Csv = $outputPath
    IncludesDescendantProcesses = $true
} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $metadataPath -Encoding utf8
if ($rootRuntime) { $rootRuntime.Dispose() }
Write-Output "Samples: $($rows.Count); CSV: $outputPath; metadata: $metadataPath"
}
