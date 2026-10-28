$ErrorActionPreference = 'Stop'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("DrillPaperPerfSmoke-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
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
    Write-Output "PASS sampler smoke: $($rows.Count) samples; this validates the script only, not DrillPaper performance."
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperPerfSmoke-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
