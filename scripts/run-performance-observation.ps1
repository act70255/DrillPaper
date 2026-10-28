[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [ValidateSet('minimal','dashboard')][string]$Theme = 'minimal',
    [ValidateRange(2,7200)][int]$DurationSeconds = 1800,
    [ValidateRange(0,120)][int]$WarmupSeconds = 60,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot ('../artifacts/acceptance/observation-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)))
)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
if ([IO.Path]::GetFileName($application) -cne 'DrillPaper.exe') { throw 'ApplicationPath 必須指向 DrillPaper.exe。' }
if (-not ('DrillPaperObservationNativeV1' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DrillPaperObservationNativeV1 {
    /** 設定呼叫執行緒的暫時電源需求。
     * Args:
     *     flags: EXECUTION_STATE 旗標。
     * Returns:
     *     先前需求；0 表示失敗。
     */
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint flags);
    [DllImport("wtsapi32.dll", EntryPoint="WTSQuerySessionInformationW", ExactSpelling=true)]
    private static extern bool Query(IntPtr server, uint session, int info, out IntPtr buffer, out int size);
    [DllImport("wtsapi32.dll")] private static extern void WTSFreeMemory(IntPtr buffer);
    /** 只查詢目前 session 的連線及鎖定旗標，不傳回帳號資料。
     * Returns:
     *     unlocked、locked、disconnected 或 unavailable。
     */
    public static string SessionState() {
        IntPtr buffer = IntPtr.Zero; int size;
        if (!Query(IntPtr.Zero, UInt32.MaxValue, 25, out buffer, out size)) return "unavailable";
        try {
            if (size < 20 || Marshal.ReadInt32(buffer, 0) != 1) return "unavailable";
            if (Marshal.ReadInt32(buffer, 12) != 0) return "disconnected";
            int flags = Marshal.ReadInt32(buffer, 16);
            return flags == 1 ? "unlocked" : flags == 0 ? "locked" : "unavailable";
        } finally { WTSFreeMemory(buffer); }
    }
}
'@
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$runPath = Join-Path $output 'run.json'
$csv = Join-Path $output 'samples.csv'
$run = [ordered]@{ Theme=$Theme; RequestedDurationSeconds=$DurationSeconds; WarmupSeconds=$WarmupSeconds; Result='STARTING'; SourceExecutable=$application; SourceSha256=(Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash; StartedUtc=[DateTime]::UtcNow.ToString('o'); InitialSession=[DrillPaperObservationNativeV1]::SessionState() }
$app = $null
$previousExecution = [uint32]0
try {
    if ($run.InitialSession -cne 'unlocked') { throw '長時間可見性觀測需要已解鎖且已連線的 Windows 工作階段；未啟動測試。' }
    # 暫時防止閒置休眠與螢幕逾時，不改電源計畫、不阻擋使用者主動休眠／鎖定。
    $previousExecution = [DrillPaperObservationNativeV1]::SetThreadExecutionState([uint32]2147483651)
    if ($previousExecution -eq 0) { throw '無法設定觀測期間的暫時電源需求。' }
    $copy = Join-Path $output 'app'
    New-Item -ItemType Directory -Path $copy -Force | Out-Null
    $source = Split-Path -Parent $application
    Copy-Item -LiteralPath $application,(Join-Path $source 'WebView2Loader.dll') -Destination $copy
    Copy-Item -LiteralPath (Join-Path $source 'resources') -Destination $copy -Recurse
    $previousAppData = $env:LOCALAPPDATA
    try {
        $env:LOCALAPPDATA = Join-Path $output 'profile'
        $app = Start-Process -FilePath (Join-Path $copy 'DrillPaper.exe') -ArgumentList '--preview',"--theme=$Theme" -WorkingDirectory $copy -WindowStyle Normal -PassThru
        $appHandle = $app.Handle
    } finally { $env:LOCALAPPDATA = $previousAppData }
    $run.RootProcessId = $app.Id
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 100
        $app.Refresh()
        if ($app.HasExited) { throw '觀測 app 在 ready 前已退出。' }
    } while ($app.MainWindowTitle -notlike '*Live metrics' -and $clock.Elapsed.TotalSeconds -lt 30)
    if ($app.MainWindowTitle -notlike '*Live metrics') { throw '觀測 app 尚未完成握手或處於非 active 狀態。' }
    $run.ReadyTitle = $app.MainWindowTitle
    $run.Result = 'WARMUP'
    $run | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $runPath -Encoding utf8
    Write-Output "觀測已啟動：PID=$($app.Id)，主題=$Theme，暖機=$WarmupSeconds 秒，之後記錄 $DurationSeconds 秒；資料=$output"
    for ($second=0; $second -lt $WarmupSeconds; $second++) {
        if ($app.HasExited) { throw '觀測 app 在暖機期間已退出。' }
        Start-Sleep -Seconds 1
    }
    $run.Result = 'SAMPLING'
    $run | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $runPath -Encoding utf8
    & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId $app.Id -DurationSeconds $DurationSeconds -IntervalSeconds 5 -OutputFile $csv
    $run.Result = 'COMPLETED'
    $run.CompletedUtc = [DateTime]::UtcNow.ToString('o')
} catch {
    $run.Result = 'FAILED'
    $run.FailureReason = $_.Exception.Message
    throw
} finally {
    try {
    if ($app) {
        $app.Refresh()
        $children = @()
        $unknownChildren = @()
        if ('DrillPaperProcessSnapshotNativeV2' -as [type]) {
            $entries = @([DrillPaperProcessSnapshotNativeV2]::GetProcesses())
            $selected = @{}
            $selected[[string]$app.Id] = $true
            $queue = [System.Collections.Generic.Queue[int]]::new()
            $queue.Enqueue($app.Id)
            while ($queue.Count -gt 0) {
                $parent = $queue.Dequeue()
                foreach ($entry in ($entries | Where-Object { $_.th32ParentProcessID -eq $parent })) {
                    $key = [string]$entry.th32ProcessID
                    if (-not $selected.ContainsKey($key)) { $selected[$key] = $true; $queue.Enqueue([int]$entry.th32ProcessID) }
                }
            }
            foreach ($childId in $selected.Keys) {
                if ([int]$childId -eq $app.Id) { continue }
                try {
                    $child = Get-Process -Id ([int]$childId) -ErrorAction Stop
                    $childHandle = $child.Handle
                    $children += $child
                } catch { $unknownChildren += [int]$childId }
            }
            $run.ChildCheck = 'OBSERVED_CURRENT_SUBTREE'
        } else { $run.ChildCheck = 'NOT_OBSERVED' }
        $run.ObservedChildIdsBeforeClose = @($children | ForEach-Object { $_.Id })
        $run.UnknownChildIds = @($unknownChildren)
        if (-not $app.HasExited) {
            if ($app.CloseMainWindow() -and $app.WaitForExit(15000)) { $run.Shutdown='NORMAL_CLOSE' }
            else { $run.Shutdown='FAILED_NORMAL_CLOSE'; $app.Kill(); $app.WaitForExit() }
        } else { $run.Shutdown='ALREADY_EXITED' }
        $run.ExitCode = $app.ExitCode
        $exitClock = [Diagnostics.Stopwatch]::StartNew()
        do {
            $survivors = @($children | Where-Object { -not $_.HasExited })
            if ($survivors.Count -eq 0) { break }
            Start-Sleep -Milliseconds 250
        } while ($exitClock.Elapsed.TotalSeconds -lt 15)
        $run.SurvivingObservedChildIds = @($survivors | ForEach-Object { $_.Id })
        foreach ($child in $children) { $child.Dispose() }
        $app.Dispose()
    }
    } catch {
        $run.Result = 'FAILED_CLEANUP'
        $run.CleanupFailure = $_.Exception.Message
        throw
    } finally {
    if ($previousExecution -ne 0) { $run.PowerRequestRestored = [DrillPaperObservationNativeV1]::SetThreadExecutionState($previousExecution) -ne 0 }
    $run | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $runPath -Encoding utf8
    Write-Output "觀測紀錄：$runPath"
    }
}
