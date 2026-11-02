[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+-trial\.[0-9A-Za-z.]+$')][string]$Version,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts')
)
$ErrorActionPreference = 'Stop'
try {
    $repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $resolved = & git -C $repo rev-parse --verify "$SourceCommit^{commit}"
    if ($LASTEXITCODE -ne 0 -or $resolved -cne $SourceCommit) { throw '找不到指定的完整 commit。' }
    $output = [IO.Path]::GetFullPath($OutputDirectory)
    $work = Join-Path $output ('trial-build-' + $SourceCommit.Substring(0,12) + '-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $archive = Join-Path $work 'source.zip'
    & git -C $repo archive --format=zip "--output=$archive" $SourceCommit
    if ($LASTEXITCODE -ne 0) { throw '匯出指定 commit 失敗。' }
    $source = Join-Path $work 'source'
    Expand-Archive -LiteralPath $archive -DestinationPath $source
    $build = Join-Path $work 'build'
    & cmake -S $source -B $build -G 'Visual Studio 17 2022' -A x64 -DBUILD_TESTING=OFF
    if ($LASTEXITCODE -ne 0) { throw 'Release 建置設定失敗，請檢查工具鏈與 WebView2 SDK。' }
    & cmake --build $build --config Release --target DrillPaper --parallel 8
    if ($LASTEXITCODE -ne 0) { throw 'Release app 編譯失敗。' }
    $compilerFile = Get-ChildItem (Join-Path $build 'CMakeFiles') -Filter CMakeCXXCompiler.cmake -Recurse | Select-Object -First 1
    $compiler = [regex]::Match((Get-Content -Raw $compilerFile.FullName),'set\(CMAKE_CXX_COMPILER_VERSION "([^"]+)"\)').Groups[1].Value
    if ($compiler -notmatch '^19\.(\d+)\.') { throw '無法識別 MSVC 版本，停止封裝。' }
    # 靜態連結 CRT：建置結果不得依賴 VC++／UCRT DLL，否則停止封裝（票 17）。
    & node (Join-Path $PSScriptRoot 'check-pe-imports.mjs') (Join-Path $build 'Release/DrillPaper.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Release app 仍依賴 VC++ 執行環境，停止封裝。' }
    @{sourceCommit=$SourceCommit; compiler=$compiler; crt='static'; command='MSVC x64 Release; BUILD_TESTING=OFF';
        executableSha256=(Get-FileHash (Join-Path $build 'Release/DrillPaper.exe')).Hash} |
        ConvertTo-Json | Set-Content (Join-Path $work 'build-provenance.json') -Encoding UTF8
    & (Join-Path $PSScriptRoot 'package-trial.ps1') -ApplicationDirectory (Join-Path $build 'Release') -SourceDirectory $source `
        -SourceCommit $SourceCommit -Version $Version -OutputDirectory $output
    Write-Output "乾淨來源與建置證據：$work"
} catch { throw "試用建置失敗：$($_.Exception.Message)" }
