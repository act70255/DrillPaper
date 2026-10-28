param([Parameter(Mandatory)][string]$Directory)
$ErrorActionPreference='Stop'
$culture=[Globalization.CultureInfo]::InvariantCulture
$metadata=Get-Content (Join-Path $Directory 'samples.metadata.json') -Raw | ConvertFrom-Json
$run=Get-Content (Join-Path $Directory 'run.json') -Raw | ConvertFrom-Json
if($metadata.RunStatus -cne 'COMPLETED' -or $run.Result -cne 'COMPLETED' -or $metadata.LogicalProcessorCount -lt 1){throw '觀測未完成或缺少必要 CPU 容量，拒絕以預設值分析。'}
function Get-State([string]$Title){
    <#
    解讀原生宿主的狀態標題。
    Args:
        Title: 原生視窗標題。
    Returns:
        狀態名稱，無法辨認時為 other。
    #>
    if($Title -like '*Live metrics'){return 'active'}
    if($Title -match '\u2014 locked \u2014'){return 'locked'}
    if($Title -match '\u2014 obscured \u2014'){return 'obscured'}
    if($Title -match '\u2014 display-off \u2014'){return 'display-off'}
    return 'other'
}
function Get-CpuStats($Intervals){
    <#
    計算時間加權平均及區間 p95。
    Args:
        Intervals: 有效區間的 Seconds、CpuDelta、Percent。
    Returns:
        統計資料；沒有區間時為空，不當作 0%。
    #>
    $Intervals=@($Intervals|Where-Object {$null -ne $_})
    if($Intervals.Count -eq 0){return $null}
    $sorted=@($Intervals.Percent | Sort-Object)
    $seconds=($Intervals.Seconds | Measure-Object -Sum).Sum
    return [ordered]@{Intervals=$Intervals.Count; Seconds=$seconds; MeanMachinePercent=($Intervals.CpuDelta|Measure-Object -Sum).Sum/$seconds/$metadata.LogicalProcessorCount*100; P95MachinePercent=$sorted[[int][Math]::Ceiling($sorted.Count*0.95)-1]; MaximumMachinePercent=$sorted[-1]}
}
function Get-Slope($Samples,[string]$Field){
    <#
    計算時間序列的線性趨勢。
    Args:
        Samples: 含 Elapsed 的樣本。
        Field: 欲分析的數值欄位。
    Returns:
        每分鐘斜率；樣本不足時為空。
    #>
    if($Samples.Count -lt 2){return $null}
    $meanTime=($Samples.Elapsed|Measure-Object -Average).Average
    $meanValue=($Samples|ForEach-Object {$_.$Field}|Measure-Object -Average).Average
    $cov=0.0;$variance=0.0
    foreach($sample in $Samples){$cov+=($sample.Elapsed-$meanTime)*($sample.$Field-$meanValue);$variance+=[Math]::Pow($sample.Elapsed-$meanTime,2)}
    if($variance -eq 0){return $null}
    return $cov/$variance*60
}
$rows=@(Import-Csv (Join-Path $Directory 'samples.csv') | ForEach-Object {
    [pscustomobject]@{Elapsed=[double]::Parse($_.ElapsedSeconds,$culture);Cpu=[double]::Parse($_.CpuTimeSeconds,$culture);PrivateMiB=[long]$_.PrivateBytes/1MB;WorkingMiB=[long]$_.WorkingSetBytes/1MB;TotalHandles=[long]$_.TotalHandles;RootHandles=[long]$_.RootHandles;Ids=$_.ProcessIds;Names=$_.ProcessNames;Root=$_.RootProcessId;Count=[int]$_.ProcessCount;SelectedCount=[int]$_.SelectedProcessCount;State=(Get-State $_.RootWindowTitle)}
})
if($rows.Count -lt 2 -or [decimal]$metadata.ObservedSpanSeconds -lt $metadata.DurationSeconds){throw '實際觀測跨度不足。'}
$intervals=@();$excluded=@();$stateIntervals=@{}
$maxGap=[Math]::Max(15,3*$metadata.IntervalSeconds)
for($index=1;$index -lt $rows.Count;$index++){
    $seconds=$rows[$index].Elapsed-$rows[$index-1].Elapsed
    $cpu=$rows[$index].Cpu-$rows[$index-1].Cpu
    if($seconds -le 0 -or $seconds -gt $maxGap -or $cpu -lt 0 -or $rows[$index].Ids -cne $rows[$index-1].Ids){$excluded+=$index;continue}
    $interval=[pscustomobject]@{Seconds=$seconds;CpuDelta=$cpu;Percent=$cpu/$seconds/$metadata.LogicalProcessorCount*100}
    $intervals+=$interval
    if($rows[$index].State -ceq $rows[$index-1].State){
        $state=$rows[$index].State
        if(-not $stateIntervals.ContainsKey($state)){$stateIntervals[$state]=@()}
        $stateIntervals[$state]+=$interval
    }
}
$states=[ordered]@{}
foreach($state in @('active','locked','obscured','display-off','other')){
    $samples=@($rows|Where-Object State -eq $state)
    if($samples.Count -eq 0){continue}
    $states[$state]=[ordered]@{Samples=$samples.Count;Cpu=(Get-CpuStats @($stateIntervals[$state]));PrivateMeanMiB=($samples.PrivateMiB|Measure-Object -Average).Average;WorkingMeanMiB=($samples.WorkingMiB|Measure-Object -Average).Average;PrivateSlopeMiBPerMinute=(Get-Slope $samples 'PrivateMiB')}
}
$metrics=[ordered]@{}
foreach($field in @('PrivateMiB','WorkingMiB','TotalHandles','RootHandles')){
    $values=@($rows|ForEach-Object {$_.$field});$stats=$values|Measure-Object -Minimum -Maximum -Average
    $metrics[$field]=[ordered]@{Start=$values[0];End=$values[-1];Minimum=$stats.Minimum;Maximum=$stats.Maximum;Mean=$stats.Average;EndMinusStart=$values[-1]-$values[0]}
}
$summary=[ordered]@{SourceSha256=$run.SourceSha256;SampleCount=$rows.Count;ObservedSpanSeconds=$metadata.ObservedSpanSeconds;LogicalProcessors=$metadata.LogicalProcessorCount;MissingRootSamples=@($rows|Where-Object {$_.Ids.Split(';') -notcontains [string]$metadata.RootProcessId}).Count;MissingWebViewSamples=@($rows|Where-Object {$_.Names.Split(';') -notcontains 'msedgewebview2'}).Count;IncompleteSubtreeSamples=@($rows|Where-Object {$_.Count -ne $_.SelectedCount}).Count;UniqueProcessSets=@($rows.Ids|Sort-Object -Unique).Count;ProcessCounts=@($rows.Count|Sort-Object -Unique);ExcludedCpuIntervals=$excluded;Cpu=(Get-CpuStats $intervals);States=$states;Metrics=$metrics;PrivateSlopeMiBPerMinute=(Get-Slope $rows 'PrivateMiB');Shutdown=$run.Shutdown;ExitCode=$run.ExitCode;SurvivingObservedChildIds=$run.SurvivingObservedChildIds;PowerRequestRestored=$run.PowerRequestRestored}
$summary.ProcessCounts=@($rows|ForEach-Object {$_.Count}|Sort-Object -Unique)
$summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $Directory 'analysis.json') -Encoding utf8
$summary|ConvertTo-Json -Depth 8
