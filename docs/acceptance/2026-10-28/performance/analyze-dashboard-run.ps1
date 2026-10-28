param([Parameter(Mandatory)][string]$Csv)
$ErrorActionPreference = 'Stop'
$culture = [Globalization.CultureInfo]::InvariantCulture
$rawRows = @(Import-Csv -LiteralPath $Csv)
if ($rawRows.Count -lt 2) { throw '量測樣本不足。' }
$rows = @($rawRows | ForEach-Object {
    [pscustomobject]@{
        Elapsed = [double]::Parse($_.ElapsedSeconds, $culture)
        Cpu = [double]::Parse($_.CpuTimeSeconds, $culture)
        Private = [long]$_.PrivateBytes
        Working = [long]$_.WorkingSetBytes
        Count = [int]$_.ProcessCount
        Ids = $_.ProcessIds
        Root = $_.RootProcessId
        Names = $_.ProcessNames
    }
})
$runPath = [IO.Path]::ChangeExtension($Csv, '.run.json')
$run = Get-Content -LiteralPath $runPath -Raw | ConvertFrom-Json
$logicalProcessors = [int]$run.LogicalProcessors
if ($logicalProcessors -lt 1) { throw '缺少有效的邏輯處理器數量。' }
$cpuIntervals = @()
$excludedIntervals = 0
for ($index = 1; $index -lt $rows.Count; $index++) {
    $seconds = $rows[$index].Elapsed - $rows[$index - 1].Elapsed
    $cpuDelta = $rows[$index].Cpu - $rows[$index - 1].Cpu
    # 子程序集合改變時，不以不同程序的累積 CPU 時間相減。
    if ($seconds -le 0 -or $cpuDelta -lt 0 -or $rows[$index].Ids -cne $rows[$index - 1].Ids) {
        $excludedIntervals++
        continue
    }
    $cpuIntervals += [pscustomobject]@{ Seconds = $seconds; CpuDelta = $cpuDelta; Percent = $cpuDelta / $seconds / $logicalProcessors * 100 }
}
$cpuSorted = @($cpuIntervals.Percent | Sort-Object)
$cpuMean = $null
$cpuP95 = $null
$cpuMaximum = $null
if ($cpuIntervals.Count -gt 0) {
    $cpuMean = ($cpuIntervals.CpuDelta | Measure-Object -Sum).Sum / ($cpuIntervals.Seconds | Measure-Object -Sum).Sum / $logicalProcessors * 100
    $cpuP95 = $cpuSorted[[Math]::Max(0, [int][Math]::Ceiling($cpuSorted.Count * 0.95) - 1)]
    $cpuMaximum = $cpuSorted[-1]
}
$metrics = [ordered]@{}
foreach ($metric in @('Private', 'Working')) {
    $values = @($rows | ForEach-Object { $_.$metric / 1MB })
    $stats = $values | Measure-Object -Minimum -Maximum -Average
    $metrics[$metric + 'MiB'] = [ordered]@{ Start = $values[0]; End = $values[-1]; Minimum = $stats.Minimum; Maximum = $stats.Maximum; Mean = $stats.Average; EndMinusStart = $values[-1] - $values[0] }
}
$stable = @($rows | Where-Object { $_.Elapsed -ge 60 })
$privateSlope = $null
if ($stable.Count -gt 1) {
    $meanTime = ($stable.Elapsed | Measure-Object -Average).Average
    $meanPrivate = ($stable.Private | Measure-Object -Average).Average
    $covariance = 0.0
    $variance = 0.0
    foreach ($row in $stable) {
        $covariance += ($row.Elapsed - $meanTime) * ($row.Private - $meanPrivate)
        $variance += [Math]::Pow($row.Elapsed - $meanTime, 2)
    }
    if ($variance -gt 0) { $privateSlope = $covariance / $variance / 1MB * 60 }
}
$missingRoot = @($rows | Where-Object { $_.Ids.Split(';') -notcontains $_.Root }).Count
$missingWebView = @($rows | Where-Object { $_.Names.Split(';') -notcontains 'msedgewebview2' }).Count
$summary = [ordered]@{
    Csv = [IO.Path]::GetFullPath($Csv)
    SampleCount = $rows.Count
    FirstElapsedSeconds = $rows[0].Elapsed
    LastElapsedSeconds = $rows[-1].Elapsed
    ObservedSpanSeconds = $rows[-1].Elapsed - $rows[0].Elapsed
    LogicalProcessors = $logicalProcessors
    MissingRootSamples = $missingRoot
    MissingWebViewSamples = $missingWebView
    ProcessCountMinimum = ($rows | ForEach-Object { $_.Count } | Measure-Object -Minimum).Minimum
    ProcessCounts = @($rows | ForEach-Object { $_.Count } | Sort-Object -Unique)
    UniqueProcessSets = @($rows.Ids | Sort-Object -Unique).Count
    CpuValidIntervals = $cpuIntervals.Count
    CpuExcludedIntervals = $excludedIntervals
    CpuMachinePercentMean = $cpuMean
    CpuMachinePercentP95 = $cpuP95
    CpuMachinePercentMaximum = $cpuMaximum
    PrivateMiB = $metrics.PrivateMiB
    WorkingMiB = $metrics.WorkingMiB
    PrivateMiBPerMinuteAfterFirstMinute = $privateSlope
    Shutdown = $run.Shutdown
    ExitCode = $run.ExitCode
    SurvivingObservedChildIds = @($run.SurvivingObservedChildIds)
}
$summaryPath = [IO.Path]::ChangeExtension($Csv, '.summary.json')
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8
$summary | ConvertTo-Json -Depth 5
