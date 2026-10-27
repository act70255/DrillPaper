[CmdletBinding()]
param([switch]$RequireNativeBuildTools)

$ErrorActionPreference = 'Stop'
$missing = [System.Collections.Generic.List[string]]::new()

function Write-Check([string]$Label, [string]$Value, [bool]$Available) {
    $state = if ($Available) { 'FOUND' } else { 'MISSING' }
    '{0,-20} {1,-7} {2}' -f $Label, $state, $Value
}

$os = Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion' -ErrorAction SilentlyContinue
$osName = if ($os.ProductName) { $os.ProductName } else { 'Windows' }
$osBuild = if ($os.CurrentBuildNumber) { $os.CurrentBuildNumber } else { 'unknown build' }
$osArch = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
Write-Check 'OS' "$osName $([Environment]::OSVersion.Version) build $osBuild $osArch" $true

foreach ($tool in @('git', 'cmake', 'node', 'dotnet')) {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    if ($command) {
        $version = switch ($tool) {
            'git' { (& git --version) -join ' ' }
            'cmake' { (& cmake --version | Select-Object -First 1) -join ' ' }
            'node' { (& node --version) -join ' ' }
            'dotnet' { (& dotnet --version) -join ' ' }
        }
        Write-Check $tool "$($command.Source) ($version)" $true
    } else {
        Write-Check $tool 'not on PATH' $false
        if ($tool -eq 'git' -or $tool -eq 'cmake') { $missing.Add($tool) }
    }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsPath = $null
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -products '*' -property installationPath
}
$clPath = $null
if ($vsPath) {
    $clPath = Get-ChildItem (Join-Path $vsPath 'VC/Tools/MSVC') -Filter cl.exe -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[/\\]bin[/\\]Hostx64[/\\]x64[/\\]cl\.exe$' } |
        Select-Object -First 1 -ExpandProperty FullName
}
if ($clPath) {
    $clVersion = (& $clPath /Bv 2>&1 | Select-String 'Optimizing Compiler' | Select-Object -First 1).Line.Trim()
    Write-Check 'MSVC compiler' "$clPath ($clVersion)" $true
} else {
    Write-Check 'MSVC compiler' 'no x64 compiler found by vswhere' $false
    $missing.Add('MSVC x64 compiler')
}

$windowsSdkRoot = $null
$sdkRegistry = Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows Kits/Installed Roots' -ErrorAction SilentlyContinue
if ($sdkRegistry.KitsRoot10 -and (Test-Path (Join-Path $sdkRegistry.KitsRoot10 'Include'))) {
    $windowsSdkRoot = $sdkRegistry.KitsRoot10
}
$hasSdkHeaders = $false
if ($windowsSdkRoot) {
    $hasSdkHeaders = [bool](Get-ChildItem (Join-Path $windowsSdkRoot 'Include') -Directory -ErrorAction SilentlyContinue | Select-Object -First 1)
}
Write-Check 'Windows SDK' $(if ($hasSdkHeaders) { $windowsSdkRoot } else { 'Windows Kits headers/libraries not detected' }) $hasSdkHeaders
if (-not $hasSdkHeaders) { $missing.Add('Windows SDK') }

$webViewRuntime = @('HKLM:/SOFTWARE/Microsoft/EdgeUpdate/Clients', 'HKLM:/SOFTWARE/WOW6432Node/Microsoft/EdgeUpdate/Clients') |
    Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem $_ -ErrorAction SilentlyContinue } |
    ForEach-Object { Get-ItemProperty $_.PSPath } |
    Where-Object { $_.name -like '*WebView2*' -and $_.pv } |
    Select-Object -First 1
Write-Check 'WebView2 Runtime' $(if ($webViewRuntime) { $webViewRuntime.pv } else { 'not found in Edge Update registry' }) ([bool]$webViewRuntime)
$webViewSdk = Join-Path $env:USERPROFILE '.nuget/packages/microsoft.web.webview2'
$webViewHeader = if (Test-Path $webViewSdk) {
    Get-ChildItem $webViewSdk -Filter WebView2.h -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
Write-Check 'WebView2 SDK' $(if ($webViewHeader) { $webViewHeader } else { 'WebView2.h not found in NuGet cache' }) ([bool]$webViewHeader)

$gpu = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
Write-Check 'Display adapters' ($gpu -join '; ') ([bool]$gpu)
$nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($nvidiaSmi) {
    $gpuQuery = (& nvidia-smi --query-gpu=name,utilization.gpu --format=csv,noheader 2>&1 | Select-Object -First 1) -join ''
    Write-Check 'NVIDIA telemetry' "$($nvidiaSmi.Source) ($gpuQuery)" ($LASTEXITCODE -eq 0)
} else {
    Write-Check 'NVIDIA telemetry' 'nvidia-smi not found (optional)' $false
}

Write-Host ''
if ($missing.Count -gt 0) {
    Write-Host "Native build prerequisites missing: $($missing -join ', ')"
    if ($RequireNativeBuildTools) { exit 1 }
    exit 0
}
Write-Host 'Required base tools were found. CMake configure/build is still the definitive validation.'
