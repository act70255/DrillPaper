[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Debug',
    [switch]$SkipNative,
    [switch]$LocalToolchain
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
Push-Location $repoRoot
try {
    . (Join-Path $PSScriptRoot 'test-workspace.ps1')
    $workspace = New-DrillPaperTestWorkspace -Name full-suite
    $env:TEMP = $workspace
    $env:TMP = $workspace
    Write-Output "完整測試資料目錄：$workspace"
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw 'Node.js is required for SDK contract tests.'
    }
    node --test tests/sdk/*.test.mjs
    if ($LASTEXITCODE -ne 0) { throw "SDK tests failed with exit code $LASTEXITCODE." }
    node --test tests/theme-cli-launcher.test.mjs tests/test-workspace.test.mjs
    if ($LASTEXITCODE -ne 0) { throw '測試啟動與隔離目錄契約未通過。' }

    & (Join-Path $PSScriptRoot 'test-environment-check.ps1')
    & (Join-Path $PSScriptRoot 'test-performance-sampler.ps1')
    & (Join-Path $PSScriptRoot 'test-theme-package.ps1')
    & (Join-Path $PSScriptRoot 'test-theme-negative-oracle.ps1')
    & (Join-Path $PSScriptRoot 'test-sdk-package.ps1')

    if (-not $SkipNative) {
        $preset = "windows-msvc-$($Configuration.ToLowerInvariant())"
        if ($LocalToolchain) {
            $buildDirectory = Join-Path $repoRoot "build/local-msvc-$($Configuration.ToLowerInvariant())"
            $ctest = Join-Path $repoRoot '.toolchain/cmake/cmake-4.3.5-windows-x86_64/bin/ctest.exe'
            if (-not (Test-Path -LiteralPath $buildDirectory -PathType Container) -or
                -not (Test-Path -LiteralPath $ctest -PathType Leaf)) {
                throw 'The local CMake build or CTest executable is missing; run scripts/build.ps1 -LocalToolchain first.'
            }
            & $ctest --test-dir $buildDirectory --output-on-failure
            if ($LASTEXITCODE -ne 0) { throw "CTest failed with exit code $LASTEXITCODE." }
            return
        }
        if (-not (Get-Command ctest -ErrorAction SilentlyContinue)) {
            throw 'CTest was not found on PATH. SDK and theme-package checks passed; native tests were not run. Install CMake.'
        }
        ctest --preset $preset --output-on-failure
        if ($LASTEXITCODE -ne 0) { throw "CTest failed with exit code $LASTEXITCODE." }
    }
}
finally {
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    Pop-Location
}
