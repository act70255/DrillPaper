$ErrorActionPreference = 'Stop'
$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwsh) { throw 'PowerShell 7 is required for the environment-check regression test.' }

$checkScript = Join-Path $PSScriptRoot 'check-environment.ps1'
$quotedPath = "'" + $checkScript.Replace("'", "''") + "'"
$commandText = @"
function Get-CimInstance { throw [System.UnauthorizedAccessException]::new('Access denied') }
& $quotedPath
"@
$output = & $pwsh.Source -NoLogo -NoProfile -NonInteractive -Command $commandText 2>&1
$exitCode = $LASTEXITCODE
$outputText = $output -join [Environment]::NewLine

if ($exitCode -ne 0) {
    throw "Environment check should survive an inaccessible CIM provider. Exit $exitCode`n$outputText"
}
if ($outputText -notmatch '(?im)^Display adapters\s+(FOUND|MISSING)\s+') {
    throw "Environment check did not report display adapter inventory status.`n$outputText"
}
if ($outputText -notmatch '(?im)^WebView2 SDK\s+(FOUND|MISSING)\s+') {
    throw "Environment check stopped before reporting WebView2 SDK.`n$outputText"
}

Write-Output 'PASS environment check continues when CIM display inventory is denied.'
