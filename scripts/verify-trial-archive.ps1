[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit
)
$ErrorActionPreference='Stop'
$archive=$null
try {
    $path=(Resolve-Path -LiteralPath $ArchivePath).Path
    $sidecar=Get-Content -Raw -Encoding UTF8 -LiteralPath ([IO.Path]::ChangeExtension($path,'.json')) | ConvertFrom-Json
    if ($sidecar.archiveSha256 -cne (Get-FileHash -LiteralPath $path).Hash) { throw 'ZIP SHA-256 與 sidecar 不符。' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead($path)
    $reader=[IO.StreamReader]::new($archive.GetEntry('package-manifest.json').Open())
    try { $manifest=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    # kind 必須與版號一致：-trial.N 為 trial，正式版號 X.Y.Z 為 release（票 18）。
    $expectedKind = if ([string]$manifest.version -match '^\d+\.\d+\.\d+-trial\.[0-9A-Za-z.]+$') { 'trial' } elseif ([string]$manifest.version -match '^\d+\.\d+\.\d+$') { 'release' } else { $null }
    if ($manifest.sourceCommit -cne $SourceCommit -or -not $expectedKind -or $manifest.kind -cne $expectedKind -or $manifest.configuration -cne 'Release' -or $manifest.architecture -cne 'x64') { throw '來源／版號與版本類型／Release／x64 不符。' }
    $entries=Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'trial-files.json') | ConvertFrom-Json
    $expected=@($entries | ForEach-Object { if ($_.destination) { $_.destination } else { $_.path } })
    if (@(Compare-Object ($expected+'package-manifest.json') @($archive.Entries.FullName)).Count -ne 0 -or
        @($manifest.files).Count -ne $expected.Count -or @(Compare-Object $expected @($manifest.files.path)).Count -ne 0) { throw 'ZIP／manifest 必須恰好符合白名單。' }
    foreach ($record in $manifest.files) {
        $stream=$archive.GetEntry($record.path).Open()
        $sha=[Security.Cryptography.SHA256]::Create()
        try { $hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -cne $record.sha256) { throw "ZIP 檔案 SHA-256 不符：$($record.path)" }
    }
    if ($manifest.executableSha256 -cne ($manifest.files | Where-Object path -eq 'DrillPaper.exe').sha256 -or
        $manifest.executableSha256 -cne $sidecar.executableSha256 -or $manifest.version -cne $sidecar.version -or $sidecar.sourceCommit -cne $SourceCommit) { throw 'EXE／版本／來源 sidecar 不一致。' }
    Write-Output "PASS：Release x64 試用包來源、白名單 $($expected.Count) 檔與逐檔／EXE／ZIP hash 相符。"
    # 明確回報成功；未執行原生命令時 $LASTEXITCODE 為 null，呼叫端以 -ne 0 判斷會誤判失敗。
    exit 0
} catch {
    [Console]::Error.WriteLine("錯誤：套件清單驗證失敗：$($_.Exception.Message)")
    exit 1
} finally { if ($archive) { $archive.Dispose() } }
