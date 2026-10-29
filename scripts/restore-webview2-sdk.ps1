[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Destination,
    [string]$ArchivePath
)
$ErrorActionPreference = 'Stop'
$version = '1.0.2478.35'
$expectedHash = 'B1DF2D7FE955A3378603735F910B126647E43033213B5CC071B8D6F0168A3B96'
$source = "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$version/microsoft.web.webview2.$version.nupkg"
$target = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $target) { throw "SDK 目的地已存在，拒絕覆寫：$target" }
$parent = [IO.Path]::GetDirectoryName($target)
if ([string]::IsNullOrEmpty($parent)) { throw 'SDK 目的地必須是具有父目錄的完整路徑。' }
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaperWebView2-' + [Guid]::NewGuid().ToString('N'))
$staging = Join-Path $parent ('.DrillPaperWebView2-staging-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temporary | Out-Null
    $archive = Join-Path $temporary 'sdk.zip'
    if ($ArchivePath) { Copy-Item -LiteralPath (Resolve-Path -LiteralPath $ArchivePath).Path -Destination $archive }
    else { Invoke-WebRequest -Uri $source -OutFile $archive -UseBasicParsing }
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) { throw "WebView2 SDK SHA-256 不符，拒絕解壓。預期 $expectedHash，實際 $actualHash。" }
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $staging
    foreach ($required in @('build/native/include/WebView2.h','build/native/x64/WebView2Loader.dll.lib','build/native/x64/WebView2Loader.dll')) {
        $file = Join-Path $staging $required
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-Item -LiteralPath $file).Length -eq 0) {
            throw "WebView2 SDK 缺少必要的非空檔案：$required"
        }
    }
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($staging)) -ne $parent -or
        [IO.Path]::GetFullPath($target) -ne [IO.Path]::GetFullPath($Destination)) {
        throw 'SDK 移動路徑超出指定目的地，已停止。'
    }
    [IO.Directory]::Move($staging,$target)
    Write-Output "WebView2 SDK $version 已通過 SHA-256 驗證並還原：$target"
} finally {
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedTemp = [IO.Path]::GetFullPath($temporary)
    if ($resolvedTemp.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedTemp).StartsWith('DrillPaperWebView2-',[StringComparison]::Ordinal) -and
        (Test-Path -LiteralPath $resolvedTemp)) { Remove-Item -LiteralPath $resolvedTemp -Recurse -Force }
    if ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($staging)) -eq $parent -and
        [IO.Path]::GetFileName($staging).StartsWith('.DrillPaperWebView2-staging-',[StringComparison]::Ordinal) -and
        (Test-Path -LiteralPath $staging)) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
