[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Theme([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Invalid DrillPaper theme package: $Message" }
}

function Read-ThemeManifest([System.IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    try {
        $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $reader = [System.IO.StreamReader]::new($stream, $utf8, $true)
        try { return $reader.ReadToEnd() }
        finally { $reader.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Test-SafeThemePath([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Contains('\') -or $Name.StartsWith('/') -or
        [System.IO.Path]::IsPathRooted($Name) -or $Name -match '^[A-Za-z]:' -or
        $Name -match '[\x00-\x1F\x7F<>:"|?*]') { return $false }
    foreach ($segment in $Name.TrimEnd('/').Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -in @('.', '..') -or
            $segment.EndsWith('.') -or $segment.EndsWith(' ') -or
            $segment -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$') { return $false }
    }
    return $true
}

function Test-ThemeManifest($Manifest, [System.Collections.Generic.HashSet[string]]$AssetNames) {
    Assert-Theme ($null -ne $Manifest -and $Manifest -isnot [array] -and $Manifest -is [pscustomobject]) 'theme.json must be a JSON object.'
    $required = @('id', 'name', 'version', 'apiVersion', 'entry', 'author', 'description', 'capabilities', 'permissions')
    $allowed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($key in $required) { [void]$allowed.Add($key) }
    foreach ($property in $Manifest.PSObject.Properties) {
        Assert-Theme $allowed.Contains($property.Name) "unknown manifest property '$($property.Name)'"
    }
    foreach ($key in $required) {
        Assert-Theme ($Manifest.PSObject.Properties.Name -contains $key) "missing manifest property '$key'"
    }

    Assert-Theme ($Manifest.id -is [string] -and $Manifest.id.Length -le 63 -and
        $Manifest.id -cmatch '^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$' -and
        $Manifest.id -notmatch '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') 'id must be a lowercase portable folder id.'
    Assert-Theme ($Manifest.name -is [string] -and $Manifest.name.Trim().Length -gt 0 -and $Manifest.name.Length -le 100) 'name must contain 1–100 characters.'
    Assert-Theme ($Manifest.version -is [string] -and $Manifest.version -cmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$') 'version must follow SemVer 2.0.0.'
    Assert-Theme ($Manifest.apiVersion -is [string] -and $Manifest.apiVersion -ceq '1') 'apiVersion must be the string "1".'
    Assert-Theme ($Manifest.entry -is [string] -and (Test-SafeThemePath $Manifest.entry) -and $Manifest.entry.EndsWith('.html', [StringComparison]::OrdinalIgnoreCase)) 'entry must be a safe relative .html path.'
    Assert-Theme ($AssetNames.Contains($Manifest.entry)) 'entry file is missing from the archive.'
    Assert-Theme ($Manifest.author -is [string] -and $Manifest.author.Trim().Length -gt 0 -and $Manifest.author.Length -le 200) 'author must contain 1–200 characters.'
    Assert-Theme ($Manifest.description -is [string] -and $Manifest.description.Length -le 1000) 'description must contain at most 1000 characters.'

    $supported = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($capability in @('cpu', 'gpu', 'memory', 'disk', 'network', 'clock')) { [void]$supported.Add($capability) }
    Assert-Theme ($Manifest.capabilities -is [array] -and $Manifest.capabilities.Length -le 6) 'capabilities must be an array of supported names.'
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($capability in $Manifest.capabilities) {
        Assert-Theme ($capability -is [string] -and $supported.Contains($capability) -and $seen.Add($capability)) 'capabilities must contain unique supported metric names.'
    }
    Assert-Theme ($Manifest.permissions -is [array] -and $Manifest.permissions.Length -eq 0) 'permissions must be an empty array in API v1.'
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
Assert-Theme ([IO.Path]::GetExtension($resolvedPath) -ceq '.dmt') 'file extension must be .dmt.'
Assert-Theme ((Get-Item -LiteralPath $resolvedPath).Length -le 50MB) 'compressed package exceeds 50 MiB.'
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
try {
    $allowedExtensions = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($extension in @('.html', '.css', '.js', '.json', '.png', '.jpg', '.jpeg', '.webp', '.ico', '.woff', '.woff2')) {
        [void]$allowedExtensions.Add($extension)
    }
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $assetNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $fileCount = 0
    [long]$totalBytes = 0
    $manifestEntry = $null

    foreach ($entry in $archive.Entries) {
        $rawName = $entry.FullName
        Assert-Theme (Test-SafeThemePath $rawName) "unsafe archive path '$rawName'"
        $name = $rawName.TrimEnd('/')
        Assert-Theme ($names.Add($name)) "duplicate path (case-insensitive): '$name'"
        $unixType = (([long]$entry.ExternalAttributes -band 0xFFFF0000) -shr 16) -band 0xF000
        Assert-Theme (($entry.ExternalAttributes -band 0x400) -eq 0 -and $unixType -ne 0xA000) "reparse point or symlink is not allowed: '$name'"
        if ($rawName.EndsWith('/')) { continue }

        $fileCount++
        Assert-Theme ($fileCount -le 256) 'archive contains more than 256 files.'
        Assert-Theme ($entry.Length -le 10MB) "file '$name' exceeds 10 MiB."
        $totalBytes += $entry.Length
        Assert-Theme ($totalBytes -le 50MB) 'uncompressed archive exceeds 50 MiB.'
        Assert-Theme ($allowedExtensions.Contains([IO.Path]::GetExtension($name))) "unsupported file type in '$name'."
        [void]$assetNames.Add($name)
        if ($name -ceq 'theme.json') {
            Assert-Theme ($null -eq $manifestEntry) 'archive contains more than one theme.json.'
            Assert-Theme ($entry.Length -le 256KB) 'theme.json exceeds 256 KiB.'
            $manifestEntry = $entry
        }

        # Drain every entry under the pre-checked quotas so invalid compressed data is detected before acceptance.
        $entryStream = $entry.Open()
        try {
            $buffer = [byte[]]::new(65536)
            [long]$readBytes = 0
            while (($read = $entryStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $readBytes += $read
                Assert-Theme ($readBytes -le 10MB) "expanded file '$name' exceeds 10 MiB."
            }
            Assert-Theme ($readBytes -eq $entry.Length) "archive size metadata mismatch for '$name'."
        }
        finally { $entryStream.Dispose() }
    }

    Assert-Theme ($fileCount -gt 0) 'archive is empty.'
    Assert-Theme ($null -ne $manifestEntry) 'root theme.json is required.'
    try { $manifestJson = Read-ThemeManifest $manifestEntry | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "Invalid DrillPaper theme package: theme.json is not valid UTF-8 JSON: $($_.Exception.Message)" }
    Test-ThemeManifest $manifestJson $assetNames

    [pscustomobject]@{
        Valid = $true
        Id = $manifestJson.id
        Version = $manifestJson.version
        Entry = $manifestJson.entry
        FileCount = $fileCount
        UncompressedBytes = $totalBytes
    }
}
finally { $archive.Dispose() }
