[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$SourceCommit,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts'),
    [string]$IsccPath
)
# 由已通過 verify-trial-archive.ps1 驗證的試用 ZIP 產生 Inno Setup 使用者層級安裝檔。
# 安裝內容與 ZIP 完全相同（同一份白名單），不另外維護清單；安裝檔與 EXE 皆未簽章。見票 17。
$ErrorActionPreference = 'Stop'
$staging = $null
try {
    $archive = (Resolve-Path -LiteralPath $ArchivePath -ErrorAction SilentlyContinue).Path
    if (-not $archive) { throw "找不到試用包：$ArchivePath" }

    # 明確指定 -IsccPath 時只用它；否則依序找環境變數與常見安裝位置（略過未設定的環境變數）。
    $candidates = [Collections.Generic.List[string]]::new()
    if ($IsccPath) {
        $candidates.Add($IsccPath)
    } else {
        if ($env:ISCC_PATH) { $candidates.Add($env:ISCC_PATH) }
        foreach ($base in @($env:LOCALAPPDATA, ${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
            if (-not $base) { continue }
            $relative = if ($base -eq $env:LOCALAPPDATA) { 'Programs\Inno Setup 6\ISCC.exe' } else { 'Inno Setup 6\ISCC.exe' }
            $candidates.Add((Join-Path $base $relative))
        }
    }
    $compiler = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $compiler) {
        throw '找不到 Inno Setup 編譯器（ISCC.exe）。請安裝 Inno Setup 6（例如 winget install JRSoftware.InnoSetup --scope user），或以 -IsccPath 指定位置。'
    }

    $verifier = Join-Path $PSScriptRoot 'verify-trial-archive.ps1'
    $verification = & pwsh -NoProfile -File $verifier -ArchivePath $archive -SourceCommit $SourceCommit 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "試用包驗證失敗，未產生安裝檔：$($verification.Trim())" }

    $output = [IO.Path]::GetFullPath($OutputDirectory)
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    # 解壓到輸出目錄下的暫存資料夾（非 %TEMP%），完成後刪除。
    $staging = Join-Path $output ('installer-staging-' + [Guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $archive -DestinationPath $staging
    $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $staging 'package-manifest.json') | ConvertFrom-Json
    $version = [string]$manifest.version
    # 完整 trial 版號格式已由 package-trial.ps1 與 verify-trial-archive.ps1 把關，這裡只取數字部分給檔案版本資訊。
    if ($version -notmatch '^(\d+)\.(\d+)\.(\d+)-') { throw "試用包版本格式無效：$version" }
    $numeric = "$($Matches[1]).$($Matches[2]).$($Matches[3]).0"

    $baseName = "DrillPaper-$version-Setup-unsigned"
    $setup = Join-Path $output "$baseName.exe"
    $sidecar = Join-Path $output "$baseName.json"
    if ((Test-Path -LiteralPath $setup) -or (Test-Path -LiteralPath $sidecar)) {
        throw "安裝檔已存在，不覆寫既有版本：$setup。請改用新的試用版號重新打包。"
    }

    $script = Join-Path $PSScriptRoot '../installer/DrillPaper.iss'
    $log = & $compiler /Qp "/DAppVersion=$version" "/DNumericVersion=$numeric" "/DSourceDir=$staging" `
        "/DOutputDir=$output" "/DOutputBaseFilename=$baseName" $script 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $setup)) {
        if (Test-Path -LiteralPath $setup) { Remove-Item -LiteralPath $setup -Force }
        throw "Inno Setup 編譯失敗（結束碼 $LASTEXITCODE）：$($log.Trim())"
    }

    try {
        [ordered]@{
            kind = 'installer'; tool = 'Inno Setup 6'; version = $version; sourceCommit = $SourceCommit; signed = $false
            scope = 'per-user (%LOCALAPPDATA%\Programs\DrillPaper)'; file = "$baseName.exe"
            sha256 = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
            archive = [IO.Path]::GetFileName($archive); archiveSha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
            executableSha256 = $manifest.executableSha256
        } | ConvertTo-Json | Set-Content -LiteralPath $sidecar -Encoding UTF8
    } catch {
        # 沒有 metadata 的安裝檔無法驗證來源，且會擋住重跑；一併移除。
        Remove-Item -LiteralPath $setup, $sidecar -Force -ErrorAction SilentlyContinue
        throw "無法寫入安裝檔 metadata，已移除未完成的安裝檔：$($_.Exception.Message)"
    }
    Write-Output "安裝檔：$setup"
    Write-Output "SHA-256：$((Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash)"
    exit 0
} catch {
    [Console]::Error.WriteLine("錯誤：安裝檔打包失敗：$($_.Exception.Message)")
    exit 1
} finally {
    if ($staging -and (Test-Path -LiteralPath $staging)) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
