#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [ValidateSet('MinimalSingle','DashboardSingle','MinimalMulti','DashboardMulti','DashboardPaused')][string]$Scenario,
    [ValidateRange(1,86400)][int]$DurationSeconds,
    [ValidateRange(0,600)][int]$WarmupSeconds = 60
)
$ErrorActionPreference = 'Stop'
$app = $null
$owned = @{}
$previousLocal = $env:LOCALAPPDATA
$createdSession = $false
$result = [ordered]@{result='FAILED'; started=(Get-Date -Format o); scenario=$Scenario; duration=$DurationSeconds; warmup=$WarmupSeconds; samples=0}
try {
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    . (Join-Path $PSScriptRoot 'security-process.ps1')
    Add-Type -Path (Join-Path $PSScriptRoot 'performance-native.cs')
    $application = (Resolve-Path -LiteralPath $ApplicationPath).Path
    $session = [IO.Path]::GetFullPath($EvidenceDirectory)
    if (Test-Path -LiteralPath $session) { throw '證據目錄已存在，拒絕覆寫。' }
    if (-not $Scenario -or -not $DurationSeconds) { throw '必須指定情境及量測秒數。' }
    $userPrefix = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') + '\'
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $application.StartsWith($userPrefix,[StringComparison]::OrdinalIgnoreCase) -or
        $application.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -or
        -not $session.StartsWith($userPrefix,[StringComparison]::OrdinalIgnoreCase) -or
        $session.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase)) { throw '程式及證據必須位於非 Temp 的使用者目錄。' }
    New-Item -ItemType Directory -Path $session | Out-Null
    $createdSession = $true
    $result.application = $application
    $result.sha256 = (Get-FileHash -LiteralPath $application).Hash
    $result.logicalProcessors = [PerformanceProbe]::GetActiveProcessorCount([ushort]::MaxValue)
    if ($result.logicalProcessors -lt 1) { throw '邏輯處理器數量無效。' }
    $result.policy = 'smartSleep=false；正式手動暫停命令；沒有電源保持或喚醒呼叫。'
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $app = Start-SecurityProcess -FilePath $application -ArgumentList '--management','--preview','--no-smart-sleep' -EvidenceDirectory $session
    $env:LOCALAPPDATA = $previousLocal
    $result.process = @{id=$app.Id; start=$app.StartTime.ToUniversalTime().ToString('o'); path=$app.Path}
    $readyClock = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($app.HasExited) { throw '程式在設定前提前退出。' }
        $managers = @([PerformanceProbe]::Find($app.Id,'DrillPaperManagementWindow'))
        $notifications = @([PerformanceProbe]::Find($app.Id,'DrillPaperShellNotifications'))
        if ($managers.Count -eq 1 -and $notifications.Count -eq 1) { break }
        Start-Sleep -Milliseconds 100
    } while ($readyClock.Elapsed.TotalSeconds -lt 30)
    if ($managers.Count -ne 1 -or $notifications.Count -ne 1) { throw '沒有唯一的管理與通知視窗。' }
    $manager = $managers[0]; $notification = $notifications[0]
    $list = [PerformanceProbe]::GetDlgItem($manager,20108)
    $count = [PerformanceProbe]::SendMessage($list,0x1004,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32()
    $targetCount = if ($Scenario -match 'Single$') { 1 } else { 2 }
    if ($count -lt $targetCount) { throw "可用螢幕不足 $targetCount 個，需記錄 NOT RUN。" }
    for ($index=0; $index -lt $count; $index++) { [PerformanceProbe]::Check($app.Id,$list,$index,($index -lt $targetCount)) }
    # 原生設定選擇桌布模式並保存，僅變更隔離 LOCALAPPDATA。
    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20102),0x14E,[UIntPtr]::Zero,[IntPtr]::Zero)
    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20103),0xF1,[UIntPtr]::Zero,[IntPtr]::Zero)
    [void][PerformanceProbe]::SendMessage($notification,0x111,[UIntPtr]::new(20010),[IntPtr]::Zero)
    $themeCommand = if ($Scenario.StartsWith('Minimal')) { 10001 } else { 10002 }
    [void][PerformanceProbe]::SendMessage($notification,0x111,[UIntPtr]::new($themeCommand),[IntPtr]::Zero)
    $readyClock.Restart()
    do {
        $surfaces = @([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
        $notReady = @($surfaces | Where-Object { [PerformanceProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() -le 0 -or [PerformanceProbe]::GetParent($_) -eq [IntPtr]::Zero })
        if ($surfaces.Count -eq $targetCount -and $notReady.Count -eq 0) { break }
        Start-Sleep -Milliseconds 100
    } while ($readyClock.Elapsed.TotalSeconds -lt 35)
    if ($surfaces.Count -ne $targetCount -or $notReady.Count) { throw '桌布宿主數量、附掛或握手不符。' }
    $result.settings = Get-Content -Raw -LiteralPath (Join-Path $session 'appdata/DrillPaper/settings.json') | ConvertFrom-Json
    if ($result.settings.smartSleep -or $result.settings.displayMode -ne 'desktop' -or $result.settings.monitorTargets.Count -ne $targetCount) { throw '有效設定與量測前提不符。' }
    $paused = $Scenario -eq 'DashboardPaused'
    $expectedTheme = if ($Scenario.StartsWith('Minimal')) { 'Minimal Monitor' } else { 'Dashboard' }
    $result.expectedTheme = $expectedTheme
    if ($paused) { [void][PerformanceProbe]::SendMessage($notification,0x111,[UIntPtr]::new(20002),[IntPtr]::Zero) }
    $result.gpuOpenStatus = [PerformanceProbe]::OpenGpu()
    $warmClock = [Diagnostics.Stopwatch]::StartNew()
    while ($warmClock.Elapsed.TotalSeconds -lt $WarmupSeconds) {
        if ($app.HasExited) { throw '程式在暖機期間提前退出。' }
        Start-Sleep -Milliseconds 200
    }
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $nextSample = 0.0
    $firstSample = $null
    $lastProperties = @{}
    $changes = @{}
    $initialEpochs = @{}
    $gpuError = $null
    $rawPath = Join-Path $session 'samples.jsonl'
    $writer = [IO.StreamWriter]::new($rawPath,$false,[Text.UTF8Encoding]::new($false))
    try {
    while ($true) {
        $app.Refresh()
        if ($app.HasExited) { throw '量測根程序提前退出。' }
        $surfaces = @([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
        if ($surfaces.Count -ne $targetCount) { throw '量測期間宿主數量改變。' }
        $surfaceRows = @(foreach ($window in $surfaces) {
            $key = $window.ToInt64().ToString()
            $load = [PerformanceProbe]::GetProp($window,'DrillPaper.LoadEpoch').ToInt64()
            $ready = [PerformanceProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64()
            if (-not $initialEpochs.ContainsKey($key)) { $initialEpochs[$key] = "$load/$ready" }
            if ($initialEpochs[$key] -ne "$load/$ready" -or $ready -le 0) { throw '量測期間主題重載或失去握手。' }
            $caption = [PerformanceProbe]::Caption($window)
            $visible = [PerformanceProbe]::IsWindowVisible($window)
            if (-not $caption.Contains($expectedTheme) -or
                ($paused -and ($visible -or -not $caption.EndsWith('已暫停'))) -or
                (-not $paused -and (-not $visible -or -not $caption.EndsWith('Live metrics')))) { throw '有效主題或播放狀態與量測情境不符。' }
            foreach ($name in @('MetricsTick','HealthTick')) {
                $propertyKey = "$key/$name"
                $value = [PerformanceProbe]::GetProp($window,"DrillPaper.$name").ToInt64()
                if (-not $changes.ContainsKey($propertyKey)) { $changes[$propertyKey] = 0 }
                if ($lastProperties.ContainsKey($propertyKey) -and $lastProperties[$propertyKey] -ne $value) { $changes[$propertyKey]++ }
                $lastProperties[$propertyKey] = $value
            }
            @{hwnd=$key; load=$load; ready=$ready; caption=$caption; visible=$visible;
                metrics=$lastProperties["$key/MetricsTick"]; health=$lastProperties["$key/HealthTick"]; metricsChanges=$changes["$key/MetricsTick"]; healthChanges=$changes["$key/HealthTick"]}
        })
        if ($clock.Elapsed.TotalSeconds -ge $nextSample) {
            # CIM 提供 parent／精確建立時間；保留已核實的實體 handle，不憑 PID 追蹤或清理。
            $entries = @(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe' OR ProcessId=$($app.Id)")
            $byId = @{}
            foreach ($entry in $entries) { $byId[[int]$entry.ProcessId] = $entry }
            $selected = [Collections.Generic.HashSet[int]]::new()
            [void]$selected.Add($app.Id)
            do {
                $added = $false
                foreach ($entry in $entries) {
                    $parent = $byId[[int]$entry.ParentProcessId]
                    if ($parent -and $entry.CreationDate -ge $parent.CreationDate -and $selected.Contains([int]$entry.ParentProcessId) -and $selected.Add([int]$entry.ProcessId)) { $added=$true }
                }
            } while ($added)
            $skipped = [Collections.Generic.List[object]]::new()
            $processRows = @(foreach ($entry in $entries) {
                if (-not $selected.Contains([int]$entry.ProcessId)) { continue }
                try {
                $identity = "$($entry.ProcessId)/$($entry.CreationDate.ToUniversalTime().Ticks)"
                if (-not $owned.ContainsKey($identity)) {
                    $process = Get-Process -Id $entry.ProcessId -ErrorAction Stop
                    $null = $process.Handle
                    if ($process.Path -ne $entry.ExecutablePath -or $process.StartTime -lt $app.StartTime -or
                        [Math]::Abs(($process.StartTime.ToUniversalTime()-$entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1) { $process.Dispose(); throw '子程序身分不符。' }
                    $owned[$identity] = $process
                }
                $process = $owned[$identity]; $process.Refresh()
                if ($process.HasExited) { throw '採樣期間程序退出。' }
                @{id=$process.Id; identity=$identity; parent=$entry.ParentProcessId; start=$process.StartTime.ToUniversalTime().ToString('o'); path=$process.Path;
                    role=if ($process.Id -eq $app.Id) {'app'} elseif ($entry.CommandLine -match '--type=([^ ]+)') {$Matches[1]} else {'browser'};
                    cpu=$process.TotalProcessorTime.TotalSeconds; private=$process.PrivateMemorySize64; working=$process.WorkingSet64; handles=$process.HandleCount; threads=$process.Threads.Count}
                } catch {
                    if ($entry.ProcessId -eq $app.Id) { throw '無法完整讀取根程序資源，量測停止。' }
                    $skipped.Add(@{id=$entry.ProcessId; start=$entry.CreationDate.ToUniversalTime().ToString('o'); reason='程序在列舉與讀取間消失或身分無法核實。'; details=$_.Exception.Message})
                }
            })
            $complete = $skipped.Count -eq 0 -and @($processRows | Where-Object role -eq 'browser').Count -eq 1 -and @($processRows | Where-Object role -eq 'renderer').Count -ge $targetCount
            $gpuRows = @{}
            if ($result.gpuOpenStatus -eq 0) {
                try {
                    $gpuValues = [PerformanceProbe]::Gpu()
                    $verifiedIds = [Collections.Generic.HashSet[int]]::new()
                    foreach ($rowProcess in $processRows) { if (-not $owned[$rowProcess.identity].HasExited) { [void]$verifiedIds.Add($rowProcess.id) } }
                    foreach ($pair in $gpuValues.GetEnumerator()) {
                        if ($pair.Key -match '^pid_(\d+)_' -and $verifiedIds.Contains([int]$Matches[1])) { $gpuRows[$pair.Key]=$pair.Value }
                    }
                    $gpuError = if ($gpuRows.Count -eq 0) { '沒有可歸屬的有效 GPU engine 實例，不補零。' } else { $null }
                } catch { $gpuError=$_.Exception.Message }
            } else { $gpuError="GPU counter 建立失敗：$($result.gpuOpenStatus)" }
            $elapsed = $clock.Elapsed.TotalSeconds
            if ($null -eq $firstSample) { $firstSample=$elapsed }
            $row = @{utc=[DateTime]::UtcNow.ToString('o'); seconds=$elapsed; processes=$processRows; surfaces=$surfaceRows; gpu=$gpuRows; gpuError=$gpuError; complete=$complete; skipped=@($skipped.ToArray())}
            $writer.WriteLine(($row | ConvertTo-Json -Depth 8 -Compress)); $writer.Flush()
            $result.samples++
            $result.span=$elapsed-$firstSample
            if ($result.samples % 10 -eq 0) { Write-Output "$Scenario：$($result.samples) 筆，已觀測 $([int]$result.span)／$DurationSeconds 秒。" }
            if ($result.span -ge $DurationSeconds) { break }
            $nextSample=$elapsed+5
        }
        # 原生屬性是最後更新時間戳；以 100 ms 觀察變化次數，而非把時間差當樣本數。
        Start-Sleep -Milliseconds 100
    }
    } finally { $writer.Dispose() }
    $result.result='COMPLETED'
} catch {
    $result.reason='效能觀測的輸入、程序身分或讀取未完成；完整原因見 details。'
    $result.details=$_ | Out-String
    $diagnostic=Join-Path $PSScriptRoot ('../artifacts/acceptance/rc06-tool-errors/'+[Guid]::NewGuid().ToString('N')+'.log')
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null
    $result.details | Set-Content -LiteralPath $diagnostic -Encoding UTF8
    [Console]::Error.WriteLine("錯誤：效能觀測未完成，請確認輸入路徑、程序身分及觀測資料。診斷日誌：$diagnostic")
} finally {
    $env:LOCALAPPDATA=$previousLocal
    try {
    if ('PerformanceProbe' -as [type]) { [PerformanceProbe]::CloseGpu() }
    if ($app) {
        $result.children=@($owned.Values | Where-Object Id -ne $app.Id | ForEach-Object { @{id=$_.Id; start=$_.StartTime.ToUniversalTime().ToString('o'); path=$_.Path} })
        if (-not $app.HasExited) {
            $notifications=@([PerformanceProbe]::Find($app.Id,'DrillPaperShellNotifications'))
            if ($notifications.Count -eq 1) { [void][PerformanceProbe]::PostMessage($notifications[0],0x111,[UIntPtr]::new(20006),[IntPtr]::Zero) }
            if (-not $app.WaitForExit(15000)) { $result.shutdown='BLOCKED：正式退出逾時，未強制終止。' }
        }
        if ($app.HasExited) { $result.exitCode=$app.ExitCode }
        $result.survivors=@($owned.Values | Where-Object Id -ne $app.Id | Where-Object { -not $_.WaitForExit(15000) } | ForEach-Object Id)
        foreach ($process in $owned.Values) { $process.Dispose() }
        $app.Dispose()
    }
    } catch {
        $result.result='CLEANUP_FAILED'
        $result.cleanupDetails=$_ | Out-String
        [Console]::Error.WriteLine('錯誤：正式退出或已觀察程序清理未完成，請查看結果；未強制終止程序。')
    }
    $result.ended=Get-Date -Format o
    if ($createdSession) {
        try { $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8 }
        catch {
            $result.result='EVIDENCE_FAILED'
            $diagnostic=Join-Path $PSScriptRoot ('../artifacts/acceptance/rc06-tool-errors/'+[Guid]::NewGuid().ToString('N')+'.log')
            try { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null; ($_ | Out-String) + ($result | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $diagnostic -Encoding UTF8 } catch {}
            [Console]::Error.WriteLine("錯誤：無法保存效能觀測結果，不能判定完成。備援日誌：$diagnostic")
        }
    }
}
if ($result.result -ne 'COMPLETED' -or $result.shutdown -or $result.exitCode -ne 0 -or $result.survivors.Count -gt 0) { exit 1 }
Write-Output "完成 $Scenario：$($result.samples) 筆、跨度 $($result.span) 秒；此處僅表示量測完成，門檻另由報告判定。"
