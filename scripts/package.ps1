[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$')][string]$Version = '0.1.0-rc1',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts'),
    [switch]$LocalToolchain
)

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmake -and -not $LocalToolchain) { throw 'Release packaging requires CMake; scripts/build.ps1 was not run.' }
if ($LocalToolchain -and -not (Test-Path -LiteralPath (Join-Path $repoRoot '.toolchain/with-winsdk.cmd') -PathType Leaf)) {
    throw 'Release packaging requested the local toolchain, but .toolchain/with-winsdk.cmd is missing.'
}
Push-Location $repoRoot
try {
    & (Join-Path $PSScriptRoot 'build.ps1') -Configuration $Configuration -LocalToolchain:$LocalToolchain
    & (Join-Path $PSScriptRoot 'test.ps1') -Configuration $Configuration -LocalToolchain:$LocalToolchain
}
finally { Pop-Location }

$app = if ($LocalToolchain) {
    Join-Path $repoRoot "build/local-msvc-$($Configuration.ToLowerInvariant())/DrillPaper.exe"
} else {
    Join-Path $repoRoot "build/windows-msvc-$($Configuration.ToLowerInvariant())/$Configuration/DrillPaper.exe"
}
$blockers = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $app -PathType Leaf)) { $blockers.Add("Built application is missing: $app") }
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'LICENSE') -PathType Leaf)) {
    $blockers.Add('Project license is not selected; see LICENSE_DECISION.md.')
}
foreach ($requiredSource in @('src/web/webview2_host.cpp', 'src/themes/theme_manager.cpp')) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $requiredSource) -PathType Leaf)) {
        $blockers.Add("Release feature is not implemented: $requiredSource")
    }
}
foreach ($theme in @('minimal', 'dashboard')) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot "sdk/examples/$theme/theme.json") -PathType Leaf)) {
        $blockers.Add("Built-in theme source is missing: $theme")
    }
}

if ($blockers.Count -gt 0) {
    $lines = @('Release Candidate packaging is blocked:') + @($blockers | ForEach-Object { " - $_" })
    throw ($lines -join [Environment]::NewLine)
}

$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
[void][IO.Directory]::CreateDirectory($outputRoot)
$stage = Join-Path ([IO.Path]::GetTempPath()) ("DrillPaperRelease-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($stage)
$packageRoot = Join-Path $stage "DrillPaper-$Version"
[void][IO.Directory]::CreateDirectory($packageRoot)
$outputFile = Join-Path $outputRoot "DrillPaper-$Version-win-x64-unsigned.zip"
if (Test-Path -LiteralPath $outputFile) { throw "Release archive already exists: $outputFile" }

try {
    Copy-Item -LiteralPath $app -Destination (Join-Path $packageRoot 'DrillPaper.exe')
    foreach ($file in @('README.md', 'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md', 'LICENSE')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $packageRoot
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'sdk') -Destination $packageRoot -Recurse
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/theme-sdk.md') -Destination $packageRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/protocol-v1.md') -Destination $packageRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/theme-security.md') -Destination $packageRoot
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/compatibility-matrix.md') -Destination $packageRoot
    $themesRoot = Join-Path $packageRoot 'resources/themes'
    [void][IO.Directory]::CreateDirectory($themesRoot)
    foreach ($theme in @('minimal', 'dashboard')) {
        & (Join-Path $PSScriptRoot 'package-theme.ps1') `
            -ThemeDirectory (Join-Path $repoRoot "sdk/examples/$theme") `
            -OutputFile (Join-Path $themesRoot "$theme.dmt") | Out-Null
    }
    $readme = @'
DrillPaper Windows x64 release candidate

This unsigned archive requires the Microsoft Edge WebView2 Evergreen Runtime.
It does not include that browser runtime. The application and theme host must be run
as a standard user. The installed theme packages are local data; remove them only
after confirming you no longer need them.

The release owner must provide installation, theme import, switching, and uninstall
instructions validated against the exact executable before distributing this archive.
'@
    Set-Content -LiteralPath (Join-Path $packageRoot 'INSTALL.txt') -Value $readme -Encoding utf8
    [System.IO.Compression.ZipFile]::CreateFromDirectory($packageRoot, $outputFile)
    Get-FileHash -LiteralPath $outputFile -Algorithm SHA256 | Select-Object Algorithm, Hash, Path
}
finally {
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedStage.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedStage).StartsWith('DrillPaperRelease-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedStage -Recurse -Force
    }
}
