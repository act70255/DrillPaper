[CmdletBinding()]
param(
    [ValidatePattern('^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$')][string]$Version = '1.0.0-rc3',
    [string]$OutputFile = (Join-Path $PSScriptRoot "../artifacts/DrillPaper-Theme-SDK-$Version.zip")
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js is required to verify the Theme SDK package.' }

Push-Location $repoRoot
try {
    node --test tests/sdk/*.test.mjs
    if ($LASTEXITCODE -ne 0) { throw "SDK tests failed with exit code $LASTEXITCODE." }
}
finally { Pop-Location }

$outputPath = [IO.Path]::GetFullPath($OutputFile)
if ([IO.Path]::GetExtension($outputPath) -cne '.zip') { throw 'OutputFile must use the .zip extension.' }
if (Test-Path -LiteralPath $outputPath) { throw "OutputFile already exists: $outputPath" }
$outputDirectory = [IO.Path]::GetDirectoryName($outputPath)
[void][IO.Directory]::CreateDirectory($outputDirectory)
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("DrillPaperSdkBuild-" + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)
$packageRoot = Join-Path $tempRoot "DrillPaper-Theme-SDK-$Version"
[void][IO.Directory]::CreateDirectory($packageRoot)

try {
    # 明確列出作者來源，避免把本機 node_modules、dist 與 configure 產物放入 SDK ZIP。
    foreach ($directory in @('sdk/javascript', 'sdk/examples', 'tests/sdk',
        'sdk/author-starter/contracts', 'sdk/author-starter/static')) {
        $destination = Join-Path $packageRoot $directory
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        Copy-Item -LiteralPath (Join-Path $repoRoot $directory) -Destination $destination -Recurse
    }
    foreach ($file in @('sdk/theme.schema.json', 'sdk/protocol-v1.schema.json',
        'sdk/author-starter/package.json', 'sdk/author-starter/package-lock.json',
        'sdk/author-starter/tsconfig.json', 'sdk/author-starter/configure.mjs',
        'sdk/author-starter/check-types.mjs', 'sdk/author-starter/build.mjs',
        'sdk/author-starter/README.md', 'sdk/author-starter/src/main.ts')) {
        $destination = Join-Path $packageRoot $file
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $destination
    }
    $docsDirectory = Join-Path $packageRoot 'docs'
    [void][IO.Directory]::CreateDirectory($docsDirectory)
    foreach ($file in @('theme-sdk.md', 'protocol-v1.md', 'theme-security.md')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot "docs/$file") -Destination $docsDirectory
    }
    foreach ($file in @('package.json', 'CHANGELOG.md', 'LICENSE', 'LICENSE_DECISION.md', 'THIRD_PARTY_NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $packageRoot
    }
    @'
# DrillPaper Theme SDK

This local evaluation bundle contains the static JavaScript SDK, TypeScript declarations, MockHost, manifest/protocol schemas, two examples and two validated `.dmt` sample packages. It does not include DrillPaper.exe.

First-party SDK files are licensed under Apache-2.0; see `LICENSE` and `LICENSE_DECISION.md`. Third-party materials keep their own licenses. The DrillPaper name and logo are not licensed for use as branding by derivative projects. This candidate is for local evaluation and is not a public DrillPaper application release.

Start with `docs/theme-sdk.md`. Run `npm run test:sdk` to test the SDK. The root `scripts/` directory contains the `.dmt` packager and validator.

## TypeScript 作者流程

將 `sdk/author-starter` 複製到自己的工作目錄，依該目錄 README 安裝固定 TypeScript 5.9.3、準備 SDK 宣告、執行正負型別檢查與建置。只打包 `dist`；作者工具不是 app runtime 依賴。功能、匯入及安全限制見 `docs/theme-sdk.md`。

'@ | Set-Content -LiteralPath (Join-Path $packageRoot 'README.md') -Encoding utf8
    $scriptsDirectory = Join-Path $packageRoot 'scripts'
    [void][IO.Directory]::CreateDirectory($scriptsDirectory)
    foreach ($script in @('package-theme.ps1', 'validate-theme-package.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $script) -Destination $scriptsDirectory
    }
    $themeOutputDirectory = Join-Path $packageRoot 'themes'
    [void][IO.Directory]::CreateDirectory($themeOutputDirectory)
    foreach ($theme in @('minimal', 'dashboard')) {
        $themePackage = Join-Path $themeOutputDirectory "$theme.dmt"
        & (Join-Path $PSScriptRoot 'package-theme.ps1') `
            -ThemeDirectory (Join-Path $repoRoot "sdk/examples/$theme") `
            -OutputFile $themePackage | Out-Null
        & (Join-Path $PSScriptRoot 'validate-theme-package.ps1') -Path $themePackage | Out-Null
    }

    @'
DrillPaper Theme SDK __VERSION__ local evaluation candidate

This bundle contains the static JavaScript SDK, declarations, protocol and manifest schemas,
MockHost, examples, package validation tools, and two validated .dmt sample archives.
It is not a DrillPaper application release and does not include a Windows executable.
First-party SDK files are licensed under Apache-2.0. The DrillPaper name and logo are not
licensed for use as branding by derivative projects. Keep this candidate for local evaluation;
it is not a public application release.

Verification: run `npm run test:sdk`; the .dmt samples were created with scripts/package-theme.ps1.
The JavaScript tests were executed against the extracted package before it was delivered.
'@.Replace('__VERSION__', $Version) | Set-Content -LiteralPath (Join-Path $packageRoot 'THEME_SDK_RELEASE_STATUS.txt') -Encoding utf8

    $archive = [System.IO.Compression.ZipFile]::Open($outputPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $fixedTime = [DateTimeOffset]::new(2020, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        foreach ($file in Get-ChildItem -LiteralPath $packageRoot -File -Recurse | Sort-Object FullName) {
            $relative = $file.FullName.Substring($packageRoot.Length + 1).Replace('\', '/')
            $entry = $archive.CreateEntry($relative, [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTime
            $sourceStream = [IO.File]::OpenRead($file.FullName)
            $entryStream = $entry.Open()
            try { $sourceStream.CopyTo($entryStream) }
            finally { $entryStream.Dispose(); $sourceStream.Dispose() }
        }
    }
    finally { $archive.Dispose() }
    [pscustomobject]@{
        Path = $outputPath
        Version = $Version
        Bytes = (Get-Item -LiteralPath $outputPath).Length
        SHA256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
    }
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTemp.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperSdkBuild-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
