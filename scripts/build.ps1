[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [switch]$Clean,
    [switch]$LocalToolchain
)

$ErrorActionPreference = 'Stop'
$preset = "windows-msvc-$($Configuration.ToLowerInvariant())"
if ($LocalToolchain) {
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $wrapper = Join-Path $repoRoot '.toolchain/with-winsdk.cmd'
    if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf)) {
        throw 'Local toolchain wrapper was not found at .toolchain/with-winsdk.cmd.'
    }
    $buildRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'build'))
    $buildDirectory = [IO.Path]::GetFullPath((Join-Path $buildRoot "local-msvc-$($Configuration.ToLowerInvariant())"))
    if (-not $buildDirectory.StartsWith($buildRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to use a local build directory outside build/.'
    }
    if ($Clean -and (Test-Path -LiteralPath $buildDirectory)) {
        Remove-Item -LiteralPath $buildDirectory -Recurse -Force
    }
    $configureArguments = @(
        '-S', $repoRoot,
        '-B', $buildDirectory,
        '-G', 'NMake Makefiles',
        '-DBUILD_TESTING=ON',
        "-DCMAKE_BUILD_TYPE=$Configuration"
    )
    $cachedCatch2 = Join-Path $repoRoot 'build/workspace-msvc-release-tests/_deps/catch2-src'
    if (Test-Path -LiteralPath (Join-Path $cachedCatch2 'CMakeLists.txt') -PathType Leaf) {
        $configureArguments += "-DFETCHCONTENT_SOURCE_DIR_CATCH2=$cachedCatch2"
    }
    & $wrapper @configureArguments
    if ($LASTEXITCODE -ne 0) { throw "Local CMake configure failed with exit code $LASTEXITCODE." }
    & $wrapper --build $buildDirectory --config $Configuration
    if ($LASTEXITCODE -ne 0) { throw "Local CMake build failed with exit code $LASTEXITCODE." }
    return
}
if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
    throw 'CMake was not found on PATH. Run scripts/check-environment.ps1 and install CMake before building.'
}
if ($Clean) {
    $buildDir = Join-Path $PSScriptRoot "../build/$preset"
    if (Test-Path $buildDir) { Remove-Item -LiteralPath $buildDir -Recurse -Force }
}
cmake --preset $preset
if ($LASTEXITCODE -ne 0) { throw "CMake configure failed with exit code $LASTEXITCODE." }
cmake --build --preset $preset --config $Configuration
if ($LASTEXITCODE -ne 0) { throw "CMake build failed with exit code $LASTEXITCODE." }
