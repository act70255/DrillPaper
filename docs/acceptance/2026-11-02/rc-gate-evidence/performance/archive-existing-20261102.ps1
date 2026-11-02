# 僅壓縮既有證據並逐檔核對 SHA-256；不啟動產品或操作系統狀態。
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourceRoot, [Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
try {
    $root = (Resolve-Path -LiteralPath $SourceRoot).Path
    $output = (Resolve-Path -LiteralPath $OutputDirectory).Path
    $archivePath = Join-Path $output 'raw-evidence-20261102-final.zip'
    $manifestPath = Join-Path $output 'raw-evidence-20261102-final.manifest.json'
    if ((Test-Path -LiteralPath $archivePath) -or (Test-Path -LiteralPath $manifestPath)) { throw '拒絕覆寫既有封存證據。' }
    $files = @(
        Get-ChildItem -LiteralPath $root -File
        foreach ($folder in @('switches', 'switches-formal', 'soak')) {
            Get-ChildItem -LiteralPath (Join-Path $root $folder) -File -Recurse |
                Where-Object { [IO.Path]::GetRelativePath($root, $_.FullName) -notmatch '(?i)(^|[\\/])(appdata|[^\\/]*profile[^\\/]*)([\\/]|$)' }
        }
    ) | Sort-Object FullName
    $manifest = @($files | ForEach-Object {
        [ordered]@{ entry = [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\','/'); bytes = $_.Length;
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; source = $_.FullName }
    })
    $zip = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $manifest) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.source, $file.entry, [IO.Compression.CompressionLevel]::Optimal) }
    } finally { $zip.Dispose() }
    $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        if ($zip.Entries.Count -ne $manifest.Count) { throw '壓縮檔項目數不符。' }
        foreach ($file in $manifest) {
            $entry = $zip.GetEntry($file.entry)
            if (-not $entry -or $entry.Length -ne $file.bytes) { throw "壓縮檔項目長度不符：$($file.entry)" }
            $stream = $entry.Open()
            try { $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) } finally { $stream.Dispose() }
            if ($hash -ne $file.sha256 -or (Get-FileHash -LiteralPath $file.source).Hash -ne $file.sha256) { throw "原始或封存資料雜湊不符：$($file.entry)" }
        }
    } finally { $zip.Dispose() }
    $existing = Get-Content -Raw -LiteralPath (Join-Path $output 'existing-evidence-hashes-20261102.json') | ConvertFrom-Json
    foreach ($file in $existing) {
        if ((Get-FileHash -LiteralPath $file.Path).Hash -ne $file.Hash) { throw "既有工作樹證據已改變：$($file.Path)" }
    }
    $result = [ordered]@{
        archive = [IO.Path]::GetFileName($archivePath); archiveBytes = (Get-Item -LiteralPath $archivePath).Length
        archiveSha256 = (Get-FileHash -LiteralPath $archivePath).Hash; entries = $manifest.Count
        exclusions = @('appdata／WebView2 profile：不封存使用者資料', 'candidate：已驗證的產品二進位，非本次原始量測資料', 'scratch：暫存與編譯產物，非量測證據')
        files = $manifest; verified = '全部來源與 ZIP entry 逐檔長度／SHA-256 一致；既有工作樹證據雜湊不變。'
    }
    $stream = [IO.File]::Open($manifestPath, [IO.FileMode]::CreateNew)
    $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
    try { $writer.WriteLine(($result | ConvertTo-Json -Depth 8)) } finally { $writer.Dispose() }
    [pscustomobject]$result | Select-Object archive, archiveBytes, archiveSha256, entries, verified | ConvertTo-Json
} catch {
    $details = $_ | Out-String
    $diagnostic = Join-Path $PWD.Path ('rc11-archive-error-' + [Guid]::NewGuid().ToString('N') + '.log')
    try {
        $stream = [IO.File]::Open($diagnostic, [IO.FileMode]::CreateNew)
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try { $writer.WriteLine($details) } finally { $writer.Dispose() }
        [Console]::Error.WriteLine("錯誤：既有證據封存未完成，請確認路徑、權限及檔案完整性。詳細日誌：$diagnostic")
    } catch {
        [Console]::Error.WriteLine('錯誤：既有證據封存未完成，且無法保存詳細日誌；請確認目前目錄的寫入權限。')
    }
    exit 1
}
