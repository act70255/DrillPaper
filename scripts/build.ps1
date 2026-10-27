[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$preset = "windows-msvc-$($Configuration.ToLowerInvariant())"
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    throw 'CMake was not found on PATH. Run scripts/check-environment.ps1 and install CMake before building.'
}
if ($Clean) {
    $buildDir = Join-Path $PSScriptRoot "../build/$preset"
    if (Test-Path $buildDir) { Remove-Item -LiteralPath $buildDir -Recurse -Force }
}
cmake --preset $preset
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build --preset $preset --config $Configuration
exit $LASTEXITCODE
