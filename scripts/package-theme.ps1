[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ThemeDirectory,
    [Parameter(Mandatory)][string]$OutputFile
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$themeRoot = (Resolve-Path -LiteralPath $ThemeDirectory).Path.TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $themeRoot -PathType Container)) { throw 'ThemeDirectory must name a directory.' }
$outputPath = [IO.Path]::GetFullPath($OutputFile)
if ([IO.Path]::GetExtension($outputPath) -cne '.dmt') { throw 'OutputFile must use the .dmt extension.' }
if (Test-Path -LiteralPath $outputPath) { throw 'OutputFile already exists; choose a new path.' }
$themePrefix = $themeRoot + [IO.Path]::DirectorySeparatorChar
if ($outputPath.StartsWith($themePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputFile cannot be inside the source theme directory.'
}

$sdkRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../sdk/javascript'))
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("DrillPaperThemeBuild-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)
$stage = Join-Path $tempRoot 'stage'
[void][IO.Directory]::CreateDirectory($stage)
$tempPackage = Join-Path $tempRoot ("candidate-" + [Guid]::NewGuid().ToString('N') + '.dmt')

try {
    $files = @(Get-ChildItem -LiteralPath $themeRoot -File -Recurse -Force | Sort-Object FullName)
    if ($files.Count -eq 0) { throw 'Theme source directory is empty.' }
    foreach ($file in $files) {
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Theme source contains a reparse point: $($file.FullName)"
        }
        $relative = $file.FullName.Substring($themePrefix.Length).Replace('\', '/')
        $destination = Join-Path $stage ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::Copy($file.FullName, $destination, $false)
    }

    foreach ($module in @('desktop-monitor-sdk.js', 'mock-host.js')) {
        $destination = Join-Path $stage $module
        if (Test-Path -LiteralPath $destination) { throw "Theme source already contains reserved SDK file '$module'." }
        [IO.File]::Copy((Join-Path $sdkRoot $module), $destination, $false)
    }

    # Repository examples use sibling source imports for easy editing; the package resolves these modules locally.
    foreach ($script in Get-ChildItem -LiteralPath $stage -Filter '*.js' -File -Recurse) {
        $source = [IO.File]::ReadAllText($script.FullName)
        $rewritten = $source.Replace('../../javascript/desktop-monitor-sdk.js', './desktop-monitor-sdk.js').
            Replace('../../javascript/mock-host.js', './mock-host.js')
        if ($rewritten -cne $source) {
            [IO.File]::WriteAllText($script.FullName, $rewritten, [Text.UTF8Encoding]::new($false))
        }
    }

    $archive = [System.IO.Compression.ZipFile]::Open($tempPackage, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $fixedTime = [DateTimeOffset]::new(2020, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        foreach ($file in Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName) {
            $relative = $file.FullName.Substring($stage.Length + 1).Replace('\', '/')
            $entry = $archive.CreateEntry($relative, [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTime
            $sourceStream = [IO.File]::OpenRead($file.FullName)
            $entryStream = $entry.Open()
            try { $sourceStream.CopyTo($entryStream) }
            finally { $entryStream.Dispose(); $sourceStream.Dispose() }
        }
    }
    finally { $archive.Dispose() }

    $validation = & (Join-Path $PSScriptRoot 'validate-theme-package.ps1') -Path $tempPackage
    if (-not $validation.Valid) { throw 'Generated .dmt did not pass package validation.' }
    $outputDirectory = [IO.Path]::GetDirectoryName($outputPath)
    if (-not (Test-Path -LiteralPath $outputDirectory)) { [void][IO.Directory]::CreateDirectory($outputDirectory) }
    [IO.File]::Move($tempPackage, $outputPath)
    [pscustomobject]@{
        Path = $outputPath
        Id = $validation.Id
        Version = $validation.Version
        FileCount = $validation.FileCount
        Bytes = (Get-Item -LiteralPath $outputPath).Length
    }
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperThemeBuild-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
