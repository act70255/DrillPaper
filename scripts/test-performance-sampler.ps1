$ErrorActionPreference = 'Stop'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("DrillPaperPerfSmoke-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
$shortProcess = $null
try {
    $csv = Join-Path $tempRoot 'smoke.csv'
    & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId $PID -DurationSeconds 2 -IntervalSeconds 1 -OutputFile $csv
    if (-not (Test-Path -LiteralPath $csv) -or -not (Test-Path -LiteralPath (Join-Path $tempRoot 'smoke.metadata.json'))) {
        throw 'Process-tree sampler did not create its CSV and metadata files.'
    }
    $rows = @(Import-Csv -LiteralPath $csv)
    if ($rows.Count -lt 2 -or $rows[0].RootProcessId -ne $PID -or $rows[0].ProcessCount -lt 1) {
        throw 'Process-tree sampler output does not contain the requested root process samples.'
    }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $span = [decimal]::Parse($rows[-1].ElapsedSeconds, $culture) - [decimal]::Parse($rows[0].ElapsedSeconds, $culture)
    if ($span -lt 2) { throw "取樣實際跨度僅 $span 秒，未涵蓋要求的 2 秒。" }
    $metadata = Get-Content -LiteralPath (Join-Path $tempRoot 'smoke.metadata.json') -Raw | ConvertFrom-Json
    if ([decimal]$metadata.ObservedSpanSeconds -ne $span) { throw 'metadata 的實際跨度與 CSV 不一致。' }
    if ($metadata.LogicalProcessorCount -lt 1 -or [string]::IsNullOrWhiteSpace($metadata.RootProcessStartedUtc) -or
        $rows[0].PSObject.Properties.Name -notcontains 'RootWindowTitle' -or [long]$rows[0].TotalHandles -lt 1) {
        throw '量測缺少程序身分、狀態或 handles，無法追溯生命週期與資源。'
    }
    if ($metadata.RunStatus -cne 'COMPLETED') { throw '完整量測沒有標記為 COMPLETED。' }
    $shortProcess = Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 3' -WindowStyle Hidden -PassThru
    $shortHandle = $shortProcess.Handle
    $partialCsv = Join-Path $tempRoot 'partial.csv'
    $failed = $false
    try {
        & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId $shortProcess.Id -DurationSeconds 6 -IntervalSeconds 1 -OutputFile $partialCsv
    } catch { $failed = $true }
    if (-not $failed) { throw '根程序提前退出時不應判定量測成功。' }
    $partialMetadata = Get-Content -LiteralPath (Join-Path $tempRoot 'partial.metadata.json') -Raw | ConvertFrom-Json
    $partialRows = @(Import-Csv -LiteralPath $partialCsv)
    if ($partialMetadata.RunStatus -cne 'FAILED' -or $partialMetadata.SampleCount -lt 1 -or
        $partialMetadata.ObservedSpanSeconds -ge 6 -or [string]::IsNullOrWhiteSpace($partialMetadata.FailureReason) -or
        $partialRows[-1].ProcessIds.Split(';') -notcontains $shortProcess.Id.ToString()) {
        throw '根程序退出時未保留可追溯的部分資料，或誤留下零程序樣本。'
    }
    $unknownCsv = Join-Path $tempRoot 'unknown.csv'
    $unknownFailed = $false
    try {
        & (Join-Path $PSScriptRoot 'measure-process-tree.ps1') -ProcessId 2147483647 -DurationSeconds 2 -IntervalSeconds 1 -OutputFile $unknownCsv
    } catch { $unknownFailed = $true }
    $unknownMetadata = Get-Content -LiteralPath (Join-Path $tempRoot 'unknown.metadata.json') -Raw | ConvertFrom-Json
    if (-not $unknownFailed -or $unknownMetadata.RunStatus -cne 'FAILED' -or $unknownMetadata.SampleCount -ne 0) {
        throw '不存在的 PID 必須 fail-fast，不可退回量測本機其他程序。'
    }
    Write-Output "PASS：$($rows.Count) 筆完整樣本，實際跨度 $span 秒；metadata／狀態／handles 完整，提前退出會標記失敗並保留部分資料。此為工具驗證，非產品效能通過。"
}
finally {
    if ($shortProcess) {
        if (-not $shortProcess.HasExited) { $shortProcess.Kill(); $shortProcess.WaitForExit() }
        $shortProcess.Dispose()
    }
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperPerfSmoke-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
