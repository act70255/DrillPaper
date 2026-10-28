[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$ProcessId,
    [ValidateRange(1, 86400)][int]$DurationSeconds = 60,
    [ValidateRange(1, 60)][int]$IntervalSeconds = 1,
    [Parameter(Mandatory)][string]$OutputFile
)

$ErrorActionPreference = 'Stop'
$nativeSnapshotType = 'DrillPaperProcessSnapshotNative' -as [type]
if (-not $nativeSnapshotType) {
    $nativeSource = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class DrillPaperProcessSnapshotNative
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

$processes = @([DrillPaperProcessSnapshotNative]::GetProcesses() | ForEach-Object {
    [pscustomobject]@{
        ProcessId = [int]$_.th32ProcessID
        ParentProcessId = [int]$_.th32ParentProcessID
        Name = $_.szExeFile
    }
})
$rootProcess = $processes | Where-Object { $_.ProcessId -eq $ProcessId } | Select-Object -First 1
if (-not $rootProcess) { throw "Process $ProcessId was not found." }
$outputPath = [IO.Path]::GetFullPath($OutputFile)
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputPath))
$metadataPath = [IO.Path]::ChangeExtension($outputPath, '.metadata.json')
$rows = [System.Collections.Generic.List[object]]::new()
$clock = [Diagnostics.Stopwatch]::StartNew()
$culture = [Globalization.CultureInfo]::InvariantCulture

while ($clock.Elapsed.TotalSeconds -le $DurationSeconds) {
    $processes = @([DrillPaperProcessSnapshotNative]::GetProcesses() | ForEach-Object {
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
    $names = [System.Collections.Generic.List[string]]::new()
    $measuredIds = [System.Collections.Generic.List[string]]::new()
    foreach ($id in $selected.Keys) {
        try {
            $process = Get-Process -Id ([int]$id) -ErrorAction Stop
            $cpuSeconds += $process.TotalProcessorTime.TotalSeconds
            $workingSetBytes += $process.WorkingSet64
            $privateBytes += $process.PrivateMemorySize64
            $names.Add($process.ProcessName)
            $measuredIds.Add($id)
        }
        catch { } # A short-lived renderer may exit between the CIM and Get-Process snapshots.
    }
    $rows.Add([pscustomobject]@{
        TimestampUtc = [DateTime]::UtcNow.ToString('o')
        ElapsedSeconds = $clock.Elapsed.TotalSeconds.ToString('0.###', $culture)
        RootProcessId = $ProcessId
        ProcessCount = $measuredIds.Count
        ProcessIds = ($measuredIds | Sort-Object) -join ';'
        ProcessNames = (($names | Sort-Object -Unique) -join ';')
        CpuTimeSeconds = $cpuSeconds.ToString('0.###', $culture)
        WorkingSetBytes = $workingSetBytes
        PrivateBytes = $privateBytes
    })
    if ($clock.Elapsed.TotalSeconds -ge $DurationSeconds) { break }
    Start-Sleep -Seconds $IntervalSeconds
}
$clock.Stop()
$rows | Export-Csv -LiteralPath $outputPath -NoTypeInformation -Encoding utf8
$os = Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion' -ErrorAction SilentlyContinue
[pscustomobject]@{
    RootProcessId = $ProcessId
    RootProcessName = $rootProcess.Name
    OsCaption = $os.Caption
    OsVersion = [Environment]::OSVersion.Version.ToString()
    OsBuild = $os.CurrentBuildNumber
    DurationSeconds = $DurationSeconds
    IntervalSeconds = $IntervalSeconds
    SampleCount = $rows.Count
    Csv = $outputPath
    IncludesDescendantProcesses = $true
} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $metadataPath -Encoding utf8
Write-Output "Samples: $($rows.Count); CSV: $outputPath; metadata: $metadataPath"
