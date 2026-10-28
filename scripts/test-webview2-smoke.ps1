[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [ValidateRange(1, 60)][int]$TimeoutSeconds = 15,
    [ValidateSet('minimal', 'dashboard')][string]$Theme = 'minimal',
    [switch]$MockMetrics
)

$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
if ([IO.Path]::GetFileName($application) -cne 'DrillPaper.exe') {
    throw 'ApplicationPath must point to DrillPaper.exe.'
}

$process = $null
try {
    $arguments = @("--theme=$Theme")
    if ($MockMetrics) { $arguments += '--mock-metrics' }
    $process = Start-Process -FilePath $application -ArgumentList $arguments `
        -WorkingDirectory (Split-Path -Parent $application) -PassThru
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $expectedTitle = "DrillPaper Preview — $Theme — Live metrics"
    do {
        Start-Sleep -Milliseconds 250
        $process.Refresh()
        if ($process.HasExited) {
            throw "DrillPaper exited before the WebView2 protocol became ready (exit code $($process.ExitCode))."
        }
        if ($process.MainWindowTitle -ceq $expectedTitle) { break }
    } while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds)

    if ($process.MainWindowTitle -cne $expectedTitle) {
        throw "WebView2 preview did not complete SDK handshake, snapshot request, and subscription within $TimeoutSeconds seconds. Last title: '$($process.MainWindowTitle)'"
    }
    Write-Output "PASS WebView2 smoke: app window '$($process.MainWindowTitle)' (PID $($process.Id))."
}
finally {
    if ($process -and -not $process.HasExited) {
        if (-not $process.CloseMainWindow()) {
            throw 'DrillPaper did not accept a normal close request.'
        }
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            throw 'DrillPaper did not exit after a normal close request.'
        }
    }
}
