$ErrorActionPreference = 'Stop'
$tempRoot = $null
$failed = $false
try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not $env:USERPROFILE) { throw '缺少 USERPROFILE，無法建立非 Temp 的 SDK 測試目錄。' }
    $testPrefix = Join-Path $env:USERPROFILE 'DrillPaperTests'
    $tempRoot = [IO.Path]::GetFullPath((Join-Path $testPrefix ("DrillPaperSdkPackageTest-" + [Guid]::NewGuid().ToString('N'))))
    [void][IO.Directory]::CreateDirectory($tempRoot)
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
            'sdk/javascript/mock-host.d.ts',
            'sdk/javascript/mock-host.js',
            'sdk/theme.schema.json',
            'themes/minimal.dmt',
            'themes/dashboard.dmt',
            'LICENSE',
            'docs/theme-sdk.md',
            'docs/protocol-v1.md'
            'sdk/author-starter/package-lock.json',
            'sdk/author-starter/src/main.ts',
            'sdk/author-starter/contracts/valid.ts',
            'sdk/author-starter/contracts/invalid.ts'
        )) {
            if (-not $names.Contains($required)) { throw "Theme SDK package is missing '$required'." }
        }
        foreach ($name in $names) {
            if ($name -match '(^|/)(node_modules|dist)/' -or $name -match '^sdk/author-starter/src/.*\.d\.ts$') {
                throw "SDK ZIP 含本機建置產物：$name"
            }
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
catch {
    $failed = $true
    $diagnostic = Join-Path $PSScriptRoot ('../artifacts/acceptance/rc07-sdk-errors/' + [Guid]::NewGuid().ToString('N') + '.log')
    try {
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null
        ($_ | Out-String) | Set-Content -LiteralPath $diagnostic -Encoding UTF8
    } catch {}
    [Console]::Error.WriteLine("錯誤：SDK ZIP 驗證未完成，請確認使用者目錄、工具與權限。詳細日誌：$diagnostic")
}
finally {
    try {
        if ($tempRoot) {
            $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
            $tempPrefix = [IO.Path]::GetFullPath($testPrefix).TrimEnd('\') + '\'
            if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
                [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperSdkPackageTest-', [StringComparison]::Ordinal)) {
                Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
            }
        }
    } catch {
        $failed = $true
        [Console]::Error.WriteLine("錯誤：SDK 測試暫存資料未能清理，請核對目錄與權限：$tempRoot")
    }
}
if ($failed) { exit 1 }
