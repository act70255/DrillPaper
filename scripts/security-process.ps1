function Start-SecurityProcess {
    <# 由 Node 直接啟動隔離 EXE，保存身分與退出證據。
    Args:
        FilePath: 完整 EXE 路徑。
        ArgumentList: 未經 shell 引號包裝的參數。
        EvidenceDirectory: 本次測試證據目錄。
        CommandOnly: 短命 CLI 回傳 launcher，退出碼與 EXE 相同。
        CaptureNetwork: 僅在本次子程序加入 NetLog 觀測參數。
    Returns:
        GUI 的真實 Process，或 CLI 的 launcher Process。
    #>
    param([string]$FilePath, [string[]]$ArgumentList, [string]$EvidenceDirectory, [switch]$CommandOnly, [switch]$CaptureNetwork)
    $requestPath = Join-Path $EvidenceDirectory ('launch-' + [Guid]::NewGuid().ToString('N') + '.json')
    @{file=$FilePath; args=@($ArgumentList); captureNetwork=[bool]$CaptureNetwork} | ConvertTo-Json | Set-Content -LiteralPath $requestPath -Encoding UTF8
    $previousArguments = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS
    try {
        if ($CaptureNetwork) { $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $previousArguments + ' --log-net-log="' + $requestPath + '.netlog.json" --net-log-capture-mode=Default' }
        $launcher = Start-Process -FilePath (Get-Command node).Source -ArgumentList ('"' + (Join-Path $PSScriptRoot '../tests/fixtures/security-launcher.mjs') + '"'),('"' + $requestPath + '"') -WindowStyle Hidden -PassThru
    } finally { $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $previousArguments }
    $null = $launcher.Handle
    if ($CommandOnly) { return $launcher }
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath ($requestPath + '.started.json'))) {
        if ($launcher.HasExited -or $timer.Elapsed.TotalSeconds -gt 15) {
            $launcher.Dispose()
            throw "隔離 EXE 未啟動；請核對防毒攔截與啟動證據：$requestPath"
        }
        Start-Sleep -Milliseconds 50
    }
    $record = Get-Content -Raw -LiteralPath ($requestPath + '.started.json') | ConvertFrom-Json
    try {
        $process = Get-Process -Id $record.pid -ErrorAction Stop
        $null = $process.Handle
        if ($process.Path -ne $FilePath -or $process.StartTime.ToUniversalTime() -lt [DateTime]::Parse($record.started).ToUniversalTime().AddSeconds(-1)) {
            throw '隔離 EXE 程序身分不符。'
        }
        return $process
    } finally { $launcher.Dispose() }
}
