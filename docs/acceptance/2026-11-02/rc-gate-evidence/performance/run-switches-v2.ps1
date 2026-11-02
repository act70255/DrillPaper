#requires -Version 7.0
param([Parameter(Mandatory)][string]$ApplicationPath,[Parameter(Mandatory)][string]$EvidenceDirectory,[Parameter(Mandatory)][string]$Repository)
$ErrorActionPreference='Stop'
$app=$null; $owned=@{}; $previousLocal=$env:LOCALAPPDATA; $createdSession=$false
$result=[ordered]@{result='FAILED';started=(Get-Date -Format o);scenario='ThemeSwitchMulti';cycles=100;completed=0;failures=0;policy='smartSleep=false；不喚醒、不防睡'}
function Get-Surfaces {
    <# 讀取受測程序宿主的公開診斷屬性。
    Returns:
        身分、主題、世代與推送時間戳。
    #>
    @(foreach($window in @([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow'))) {
        @{hwnd=$window.ToInt64().ToString();load=[PerformanceProbe]::GetProp($window,'DrillPaper.LoadEpoch').ToInt64();ready=[PerformanceProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64();metrics=[PerformanceProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64();health=[PerformanceProbe]::GetProp($window,'DrillPaper.HealthTick').ToInt64();caption=[PerformanceProbe]::Caption($window);visible=[PerformanceProbe]::IsWindowVisible($window);parent=[PerformanceProbe]::GetParent($window).ToInt64();dpi=[PerformanceProbe]::GetProp($window,'DrillPaper.TargetDpi').ToInt64()}
    })
}
function Get-Resources {
    <# 沿用票 06 的完整程序樹及精確建立時間驗證。
    Returns:
        逐程序資源、缺失原因及完整樣本合計；缺失不補零。
    #>
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

    $totals=$null
    if($complete){$totals=@{private=($processRows | Measure-Object private -Sum).Sum;handles=($processRows | Measure-Object handles -Sum).Sum;threads=($processRows | Measure-Object threads -Sum).Sum}}
    @{utc=[DateTime]::UtcNow.ToString('o');processes=@($processRows);complete=$complete;skipped=@($skipped.ToArray());totals=$totals}
}
try {
    [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
    . (Join-Path $Repository 'scripts/security-process.ps1')
    Add-Type -Path (Join-Path $Repository 'scripts/performance-native.cs')
    $application = (Resolve-Path -LiteralPath $ApplicationPath).Path
    $session = [IO.Path]::GetFullPath($EvidenceDirectory)
    if (Test-Path -LiteralPath $session) { throw '證據目錄已存在，拒絕覆寫。' }

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
    $targetCount = if ($false) { 1 } else { 2 }
    if ($count -lt $targetCount) { throw "可用螢幕不足 $targetCount 個，需記錄 NOT RUN。" }
    for ($index=0; $index -lt $count; $index++) { [PerformanceProbe]::Check($app.Id,$list,$index,($index -lt $targetCount)) }
    # 原生設定選擇桌布模式並保存，僅變更隔離 LOCALAPPDATA。
    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20102),0x14E,[UIntPtr]::Zero,[IntPtr]::Zero)
    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20103),0xF1,[UIntPtr]::Zero,[IntPtr]::Zero)
    [void][PerformanceProbe]::SendMessage($notification,0x111,[UIntPtr]::new(20010),[IntPtr]::Zero)
    $themeCommand = 10001
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

    $warm=[Diagnostics.Stopwatch]::StartNew()
    while($warm.Elapsed.TotalSeconds -lt 60){if($app.HasExited){throw '暖機期間受測程序退出。'};Start-Sleep -Milliseconds 100}
    $result.initial=Get-Surfaces
    if(@($result.initial).Count -ne 2 -or @($result.initial | Where-Object {-not $_.caption.Contains('Minimal Monitor') -or -not $_.caption.EndsWith('Live metrics')}).Count){throw 'Minimal 雙目標起始狀態不符。'}
    $writer=[IO.StreamWriter]::new((Join-Path $session 'switches.jsonl'),$false,[Text.UTF8Encoding]::new($false))
    try {
        for($index=1;$index -le 100;$index++){
            $cycle=[ordered]@{index=$index;started=[DateTime]::UtcNow.ToString('o');result='FAILED'}
            try {
                $cycle.before=Get-Resources
                $old=@{};foreach($surface in @(Get-Surfaces)){$old[$surface.hwnd]=$surface}
                if($old.Count -ne 2){throw '切換前宿主數量不是二。'}
                $dashboard=$index % 2 -eq 1
                $cycle.theme=if($dashboard){'Dashboard'}else{'Minimal Monitor'}
                $command=if($dashboard){10002}else{10001}
                $timer=[Diagnostics.Stopwatch]::StartNew()
                if(-not [PerformanceProbe]::PostMessage($notification,0x111,[UIntPtr]::new($command),[IntPtr]::Zero)){throw '無法送出正式主題切換命令。'}
                $firstMetrics=@{}; $accepted=$false
                do {
                    if($app.HasExited){throw '切換期間受測程序退出。'}
                    $current=@(Get-Surfaces)
                    $valid=$current.Count -eq 2
                    foreach($surface in $current){
                        $prior=$old[$surface.hwnd]
                        if(-not $prior -or $surface.load -le $prior.load -or $surface.ready -le $prior.ready -or $surface.ready -le 0 -or $surface.health -le $prior.health -or $surface.metrics -le 0 -or -not $surface.visible -or -not $surface.parent -or -not $surface.caption.Contains($cycle.theme) -or -not $surface.caption.EndsWith('Live metrics')){$valid=$false}
                    }
                    if($valid){
                        foreach($surface in $current){if(-not $firstMetrics.ContainsKey($surface.hwnd)){$firstMetrics[$surface.hwnd]=$surface.metrics}}
                        if(@($current | Where-Object {$_.metrics -le $firstMetrics[$_.hwnd]}).Count -eq 0){$accepted=$true;break}
                    }
                    Start-Sleep -Milliseconds 100
                }while($timer.Elapsed.TotalSeconds -lt 20)
                $cycle.seconds=$timer.Elapsed.TotalSeconds
                $cycle.surfaces=$current
                $cycle.pushBaseline=$firstMetrics
                $cycle.after=Get-Resources
                if(-not $accepted){throw '20 秒內雙宿主未同時完成新握手、JS 回應及恢復推送。'}
                $cycle.result='PASS';$result.completed++
                Write-Output "切換 $index/100 完成：$([Math]::Round($cycle.seconds,3)) 秒。"
            }catch{$cycle.details=$_ | Out-String;$result.failures++;throw}
            finally{$cycle.ended=[DateTime]::UtcNow.ToString('o');$writer.WriteLine(($cycle | ConvertTo-Json -Depth 12 -Compress));$writer.Flush()}
        }
    }finally{$writer.Dispose()}
    $result.final=Get-Surfaces
    $result.result='COMPLETED'
} catch {
    $result.reason='效能觀測的輸入、程序身分或讀取未完成；完整原因見 details。'
    $result.details=$_ | Out-String
    $diagnostic=Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($EvidenceDirectory))) ('switch-error-'+[Guid]::NewGuid().ToString('N')+'.log')
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
            $diagnostic=Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($EvidenceDirectory))) ('switch-error-'+[Guid]::NewGuid().ToString('N')+'.log')
            try { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null; ($_ | Out-String) + ($result | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $diagnostic -Encoding UTF8 } catch {}
            [Console]::Error.WriteLine("錯誤：無法保存效能觀測結果，不能判定完成。備援日誌：$diagnostic")
        }
    }
}
if ($result.result -ne 'COMPLETED' -or $result.shutdown -or $result.exitCode -ne 0 -or $result.survivors.Count -gt 0) { exit 1 }
Write-Output "完成雙目標 100 次切換；資源結果另列。"
