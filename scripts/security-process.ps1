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
    $record = Get-Content -Raw -Encoding UTF8 -LiteralPath ($requestPath + '.started.json') | ConvertFrom-Json
    $launchTime = [DateTimeOffset]$record.started
    try {
        $identityClock = [Diagnostics.Stopwatch]::StartNew()
        $observations = @()
        do {
            $process = Get-Process -Id $record.pid -ErrorAction SilentlyContinue
            if ($process) {
                try {
                    $null = $process.Handle
                    $entry = Get-CimInstance Win32_Process -Filter "ProcessId=$($record.pid)"
                    $observations += @{id=$process.Id; path=$process.Path; start=$process.StartTime.ToString('o'); launch=$launchTime.ToString('o'); parent=$entry.ParentProcessId}
                    $observations | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ($requestPath + '.identity.json') -Encoding UTF8
                    if ($entry -and $process.Path -eq $FilePath -and $entry.ParentProcessId -eq $record.parent -and
                        [Math]::Abs(($process.StartTime.ToUniversalTime() - $entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -lt 1 -and
                        $process.StartTime.ToUniversalTime() -ge $launchTime.UtcDateTime.AddSeconds(-1) -and
                        $process.StartTime.ToUniversalTime() -le $launchTime.UtcDateTime.AddSeconds(15)) { return $process }
                } catch { $process.Dispose(); throw }
                $process.Dispose()
            }
            Start-Sleep -Milliseconds 50
        } while ($identityClock.Elapsed.TotalSeconds -lt 5)
        throw "隔離 EXE 程序身分不符；未終止未知程序，請查看啟動與身分紀錄：$requestPath"
    } finally { $launcher.Dispose() }
}
