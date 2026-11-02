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
    # INSERT_RESOURCE
    $totals=$null
    if($complete){$totals=@{private=($processRows | Measure-Object private -Sum).Sum;handles=($processRows | Measure-Object handles -Sum).Sum;threads=($processRows | Measure-Object threads -Sum).Sum}}
    @{utc=[DateTime]::UtcNow.ToString('o');processes=@($processRows);complete=$complete;skipped=@($skipped.ToArray());totals=$totals}
}
try {
    [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
    . (Join-Path $Repository 'scripts/security-process.ps1')
    Add-Type -Path (Join-Path $Repository 'scripts/performance-native.cs')
    # INSERT_SETUP
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
                        if(-not $prior -or $surface.load -eq $prior.load -or $surface.ready -ne $surface.load -or $surface.ready -le 0 -or $surface.health -le $prior.health -or $surface.metrics -le 0 -or -not $surface.visible -or -not $surface.parent -or -not $surface.caption.Contains($cycle.theme) -or -not $surface.caption.EndsWith('Live metrics')){$valid=$false}
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
# INSERT_CLEANUP
