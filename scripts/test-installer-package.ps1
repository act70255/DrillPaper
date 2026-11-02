[CmdletBinding()]
param([string]$IsccPath)
# 驗證 build-installer.ps1 的公開行為：缺編譯器、試用包驗證失敗、正常產出與拒絕覆寫。
# 安裝檔的實際安裝／解除安裝屬 Windows 整合驗證，另於實機執行，不在本測試宣稱。
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$session = Join-Path $repo ('artifacts/installer-package-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $session | Out-Null
$commit = 'b' * 40

# 以假程式內容建立一份通過白名單與 hash 驗證的試用 ZIP（不是可執行產品）。
$app = Join-Path $session 'app'
$entries = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'trial-files.json') | ConvertFrom-Json
foreach ($entry in @($entries | Where-Object root -eq 'app')) {
    $file = Join-Path $app $entry.path
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($file)) -Force | Out-Null
    Set-Content -LiteralPath $file -Value '安裝檔測試資料，非可執行產品' -Encoding UTF8
}
& (Join-Path $PSScriptRoot 'package-trial.ps1') -ApplicationDirectory $app -SourceDirectory $repo `
    -SourceCommit $commit -Version '0.1.0-trial.test' -OutputDirectory (Join-Path $session 'zip') | Out-Null
$zip = (Get-ChildItem (Join-Path $session 'zip') -Filter '*.zip').FullName
$builder = Join-Path $PSScriptRoot 'build-installer.ps1'

function Invoke-Builder([hashtable]$Arguments) {
    <#
    執行打包腳本並收集輸出與結束碼。
    Args:
        Arguments: 傳給 build-installer.ps1 的具名參數。
    Returns:
        含 Code（結束碼）與 Output（標準輸出與錯誤）的物件。
    #>
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & pwsh -NoProfile -File $builder @Arguments 2>&1 | Out-String
        return [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output }
    } finally { $ErrorActionPreference = $previous }
}

$missing = Invoke-Builder @{ ArchivePath = $zip; SourceCommit = $commit; OutputDirectory = (Join-Path $session 'out-missing'); IsccPath = (Join-Path $session 'no-iscc\ISCC.exe') }
if ($missing.Code -eq 0 -or $missing.Output -notlike '*找不到 Inno Setup 編譯器*') { throw "缺編譯器應以繁中錯誤停止：$($missing.Output)" }
if (Test-Path (Join-Path $session 'out-missing/*.exe')) { throw '缺編譯器時不得留下安裝檔。' }
Write-Output 'PASS：缺少 Inno Setup 編譯器時停止並提示取得方式。'

$compilerArguments = @{}
if ($IsccPath) { $compilerArguments.IsccPath = $IsccPath }
$mismatch = Invoke-Builder (@{ ArchivePath = $zip; SourceCommit = ('c' * 40); OutputDirectory = (Join-Path $session 'out-mismatch') } + $compilerArguments)
if ($mismatch.Code -eq 0 -or $mismatch.Output -notlike '*試用包驗證失敗*') { throw "來源不符的試用包應拒絕：$($mismatch.Output)" }
if (Test-Path (Join-Path $session 'out-mismatch/*.exe')) { throw '驗證失敗時不得留下安裝檔。' }
Write-Output 'PASS：試用包未通過白名單／來源驗證時拒絕產生安裝檔。'

$output = Join-Path $session 'out'
$built = Invoke-Builder (@{ ArchivePath = $zip; SourceCommit = $commit; OutputDirectory = $output } + $compilerArguments)
if ($built.Code -ne 0) { throw "有效試用包應產生安裝檔：$($built.Output)" }
$setup = Join-Path $output 'DrillPaper-0.1.0-trial.test-Setup-unsigned.exe'
$sidecar = Join-Path $output 'DrillPaper-0.1.0-trial.test-Setup-unsigned.json'
if (-not (Test-Path -LiteralPath $setup) -or -not (Test-Path -LiteralPath $sidecar)) { throw '應產生安裝檔與 metadata。' }
$metadata = Get-Content -Raw -Encoding UTF8 $sidecar | ConvertFrom-Json
if ($metadata.kind -cne 'installer' -or $metadata.version -cne '0.1.0-trial.test' -or $metadata.sourceCommit -cne $commit -or
    $metadata.signed -ne $false -or $metadata.sha256 -cne (Get-FileHash -LiteralPath $setup).Hash -or
    $metadata.archiveSha256 -cne (Get-FileHash -LiteralPath $zip).Hash) { throw 'metadata 必須記錄版本、來源、未簽章與兩個 SHA-256。' }
if (@(Get-ChildItem -LiteralPath $output -Directory).Count -ne 0) { throw '輸出目錄不得留下暫存解壓內容。' }
Write-Output 'PASS：由驗證過的試用包產生未簽章安裝檔與 SHA-256 metadata。'

$again = Invoke-Builder (@{ ArchivePath = $zip; SourceCommit = $commit; OutputDirectory = $output } + $compilerArguments)
if ($again.Code -eq 0 -or $again.Output -notlike '*已存在*') { throw "同版本安裝檔已存在時應拒絕覆寫：$($again.Output)" }
if ((Get-FileHash -LiteralPath $setup).Hash -cne $metadata.sha256) { throw '拒絕覆寫時不得改動既有安裝檔。' }
Write-Output 'PASS：同版本安裝檔已存在時拒絕覆寫。'
Write-Output "測試證據：$session"
# 最後一個案例預期打包腳本以 1 結束；明確回報成功，避免呼叫端沿用該 $LASTEXITCODE。
exit 0
