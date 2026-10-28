[CmdletBinding()]
param([ValidatePattern('^[a-z0-9_-]+$')][string]$TestName = 'cpu_usage_test')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path $vswhere)) { throw 'vswhere.exe is required to locate the MSVC compiler.' }
$vsPath = & $vswhere -latest -products '*' -property installationPath
if (-not $vsPath) { throw 'Visual Studio was not found.' }
$toolset = Get-ChildItem (Join-Path $vsPath 'VC/Tools/MSVC') -Directory -ErrorAction Stop |
    Sort-Object Name -Descending | Select-Object -First 1
$compiler = Join-Path $toolset.FullName 'bin/Hostx64/x64/cl.exe'
$linker = Join-Path $toolset.FullName 'bin/Hostx64/x64/link.exe'
if (-not (Test-Path $compiler) -or -not (Test-Path $linker)) {
    throw 'The x64 MSVC compiler and linker are required.'
}

$outputDirectory = Join-Path $projectRoot 'build/bootstrap'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$objectPath = Join-Path $outputDirectory "$TestName.obj"
$executablePath = Join-Path $outputDirectory "$TestName.exe"

& $compiler /nologo /c /std:c++20 /EHs-c- /GS- /Zl "/I$(Join-Path $projectRoot 'include')" (Join-Path $projectRoot "tests/bootstrap/$TestName.cpp") "/Fo$objectPath"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $linker /nologo /SUBSYSTEM:CONSOLE /NODEFAULTLIB /MACHINE:X64 /ENTRY:TestEntry "/OUT:$executablePath" $objectPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $executablePath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "$TestName bootstrap tests: PASS"
