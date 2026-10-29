$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("DrillPaperSdkPackageTest-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)
$tempRoot = [IO.Path]::GetFullPath($tempRoot)
try {
    $archivePath = Join-Path $tempRoot 'sdk-test.zip'
    $reproducibilityPath = Join-Path $tempRoot 'sdk-test-second.zip'
    & (Join-Path $PSScriptRoot 'package-sdk.ps1') -OutputFile $archivePath
    if (-not (Test-Path -LiteralPath $archivePath)) { throw 'Theme SDK package ZIP was not created.' }
    & (Join-Path $PSScriptRoot 'package-sdk.ps1') -OutputFile $reproducibilityPath
    $firstHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
    $secondHash = (Get-FileHash -LiteralPath $reproducibilityPath -Algorithm SHA256).Hash
    if ($firstHash -cne $secondHash) { throw 'Repeated Theme SDK packaging did not produce identical SHA-256 hashes.' }

    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $archive.Entries) { [void]$names.Add($entry.FullName) }
        foreach ($required in @(
            'sdk/javascript/desktop-monitor-sdk.js',
            'sdk/javascript/desktop-monitor-sdk.d.ts',
            'sdk/javascript/mock-host.js',
            'sdk/theme.schema.json',
            'themes/minimal.dmt',
            'themes/dashboard.dmt',
            'LICENSE',
            'docs/theme-sdk.md',
            'docs/protocol-v1.md'
        )) {
            if (-not $names.Contains($required)) { throw "Theme SDK package is missing '$required'." }
        }
        $licenseEntry = $archive.GetEntry('LICENSE')
        $reader = [IO.StreamReader]::new($licenseEntry.Open())
        try { $licenseText = $reader.ReadToEnd() }
        finally { $reader.Dispose() }
        if ($licenseText -notmatch 'Apache License, Version 2\.0' -or
            $licenseText -notmatch 'Copyright 2026 DrillPaper Project') {
            throw 'Theme SDK package LICENSE does not contain the selected Apache-2.0 grant and copyright notice.'
        }
    }
    finally { $archive.Dispose() }

    $extractRoot = Join-Path $tempRoot 'extracted'
    [System.IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $extractRoot)
    $packageReadme = Get-Content -LiteralPath (Join-Path $extractRoot 'README.md') -Raw
    if ($packageReadme -notmatch 'licensed under Apache-2\.0' -or
        $packageReadme -match 'Project licensing has not been selected') {
        throw 'Extracted Theme SDK README does not reflect the selected Apache-2.0 project license.'
    }
    Push-Location $extractRoot
    try {
        node --test tests/sdk/*.test.mjs
        if ($LASTEXITCODE -ne 0) { throw "Tests from the extracted SDK package failed with exit code $LASTEXITCODE." }
        & (Join-Path $PSScriptRoot 'validate-theme-package.ps1') -Path (Join-Path $extractRoot 'themes/minimal.dmt') | Out-Null
        & (Join-Path $PSScriptRoot 'validate-theme-package.ps1') -Path (Join-Path $extractRoot 'themes/dashboard.dmt') | Out-Null
    }
    finally { Pop-Location }
    Write-Output "PASS extracted Theme SDK package: required files present; tests and both .dmt validators passed; reproducible SHA-256 $firstHash."
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperSdkPackageTest-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
