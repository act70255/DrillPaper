[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug')

$ErrorActionPreference = 'Stop'
$preset = "windows-msvc-$($Configuration.ToLowerInvariant())"
if (-not (Get-Command ctest -ErrorAction SilentlyContinue)) {
    throw 'CTest was not found on PATH. Install CMake before running native tests.'
}
ctest --preset $preset --output-on-failure
exit $LASTEXITCODE
