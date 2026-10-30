[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$session = Join-Path $repo ('artifacts/trial-package-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $session | Out-Null
$failed = $false
try {
    & (Join-Path $PSScriptRoot 'package-trial.ps1') -ApplicationDirectory $session -SourceDirectory $repo `
        -MinimumVcRuntime '14.44.35112.0' -SourceCommit ('a' * 40) -Version '0.1.0-trial.test' -OutputDirectory (Join-Path $session 'out')
} catch {
    if ($_.Exception.Message -notlike '*缺少必要檔案：DrillPaper.exe*') { throw }
    $failed = $true
}
if (-not $failed -or (Test-Path (Join-Path $session 'out/*.zip'))) { throw '缺少 EXE 時應友善拒絕，且不可留下 ZIP。' }
Write-Output 'PASS：缺少必要 EXE 時拒絕封裝並提供繁中錯誤。'
$entries = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'trial-files.json') | ConvertFrom-Json
foreach ($entry in @($entries | Where-Object root -eq 'app')) {
    $file = Join-Path $session $entry.path
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($file)) -Force | Out-Null
    Set-Content -LiteralPath $file -Value '公開 CLI 測試資料，非可執行產品' -Encoding UTF8
}
Set-Content (Join-Path $session 'settings.json') '{"private":"不得封裝"}'
& (Join-Path $PSScriptRoot 'package-trial.ps1') -ApplicationDirectory $session -SourceDirectory $repo `
    -MinimumVcRuntime '14.44.35112.0' -SourceCommit ('a' * 40) -Version '0.1.0-trial.test' -OutputDirectory (Join-Path $session 'out')
$zip = Get-ChildItem (Join-Path $session 'out') -Filter '*.zip'
if (@($zip).Count -ne 1) { throw '有效輸入應產出唯一試用 ZIP。' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zip.FullName)
try {
    $expected = @($entries | ForEach-Object { if ($_.destination) { $_.destination } else { $_.path } }) + 'package-manifest.json'
    $actual = @($archive.Entries | ForEach-Object FullName)
    if (@(Compare-Object $expected $actual).Count -ne 0) { throw 'ZIP 必須恰好只有白名單與 manifest，不能帶入額外資料。' }
    $reader = [IO.StreamReader]::new($archive.GetEntry('package-manifest.json').Open())
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($manifest.sourceCommit -cne ('a' * 40) -or $manifest.kind -cne 'trial') { throw 'manifest 來源或試用標示錯誤。' }
    foreach ($record in $manifest.files) {
        $stream = $archive.GetEntry($record.path).Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -cne $record.sha256) { throw "ZIP 內容 hash 不符：$($record.path)" }
    }
} finally { $archive.Dispose() }
$sidecar = Get-Content -Raw ($zip.FullName -replace '\.zip$','.json') | ConvertFrom-Json
if ($sidecar.archiveSha256 -cne (Get-FileHash $zip.FullName).Hash -or
    $sidecar.executableSha256 -cne (Get-FileHash (Join-Path $session 'DrillPaper.exe')).Hash) { throw '套件／EXE sidecar hash 錯誤。' }
Write-Output 'PASS：白名單恰好相符、私有設定排除、逐檔／ZIP／EXE hash 及 trial 來源識別。'
try {
    & (Join-Path $PSScriptRoot 'package-trial.ps1') -ApplicationDirectory $session -SourceDirectory $repo `
        -MinimumVcRuntime '14.44.35112.0' -SourceCommit ('a' * 40) -Version '0.1.0-trial.test' -OutputDirectory (Join-Path $session 'out')
    throw '不應覆寫既有套件。'
} catch { if ($_.Exception.Message -notlike '*目的檔已存在*') { throw } }
foreach ($case in @('missing','empty','junction')) {
    $theme = Join-Path $session 'resources/themes/minimal'
    $file = Join-Path $theme 'javascript/desktop-monitor-sdk.js'
    if ($case -eq 'missing') { Remove-Item -LiteralPath $file }
    if ($case -eq 'empty') { [IO.File]::WriteAllText($file,'') }
    if ($case -eq 'junction') {
        Rename-Item -LiteralPath $theme -NewName 'minimal-original'
        New-Item -ItemType Junction -Path $theme -Target (Join-Path $session 'resources/themes/minimal-original') | Out-Null
    }
    try {
        & (Join-Path $PSScriptRoot 'package-trial.ps1') -ApplicationDirectory $session -SourceDirectory $repo `
            -MinimumVcRuntime '14.44.35112.0' -SourceCommit ('a' * 40) -Version "0.1.0-trial.$case" -OutputDirectory (Join-Path $session $case)
        throw "未拒絕 $case 案例。"
    } catch {
        $expectedError = switch ($case) { missing { '缺少必要檔案' }; empty { '必要檔案為空' }; junction { '路徑含連結' } }
        if ($_.Exception.Message -notlike "*$expectedError*") { throw }
    }
    if (Test-Path (Join-Path $session "$case/*.zip")) { throw '失敗不得留下 ZIP。' }
    if ($case -ne 'junction') { Set-Content -LiteralPath $file -Value '恢復測試輸入' -Encoding UTF8 }
}
Write-Output 'PASS：覆寫、SDK 缺檔、空檔及 junction 均拒絕，失敗不留下 ZIP。'
Write-Output "測試證據：$session"
