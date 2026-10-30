#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PackageDirectory)
$ErrorActionPreference='Stop'
try {
    if (-not $env:USERPROFILE) { throw '缺少 USERPROFILE，無法建立非 Temp 測試目錄。' }
    $package=(Resolve-Path -LiteralPath $PackageDirectory).Path
    $session=Join-Path $env:USERPROFILE ('DrillPaperTests/cmd-failure-' + [Guid]::NewGuid().ToString('N'))
    Copy-Item -LiteralPath $package -Destination $session -Recurse
    Remove-Item -LiteralPath (Join-Path $session 'resources/themes/minimal/index.html')
    foreach ($checkOnly in @($false,$true)) {
        $process=[Diagnostics.Process]::new()
        try {
            $process.StartInfo.FileName=$env:ComSpec
            $suffix=if ($checkOnly) { ' -CheckOnly' } else { '' }
            $process.StartInfo.Arguments='/d /c ""'+(Join-Path $session 'Start-DrillPaper.cmd')+'"'+$suffix+'"'
            $process.StartInfo.UseShellExecute=$false
            $process.StartInfo.CreateNoWindow=$true
            $process.StartInfo.RedirectStandardInput=$true
            $process.StartInfo.RedirectStandardOutput=$true
            $process.StartInfo.RedirectStandardError=$true
            $process.StartInfo.StandardErrorEncoding=[Text.Encoding]::GetEncoding((Get-Culture).TextInfo.OEMCodePage)
            if (-not $process.Start()) { throw '無法啟動受測 CMD。' }
            $message=$process.StandardError.ReadLineAsync()
            if (-not $message.Wait(15000)) { throw '15 秒內未收到 CMD 錯誤輸出。' }
            if (-not $message.Result.Contains('缺少必要主題資產')) { throw "CMD 未傳達繁中資產錯誤：$($message.Result)" }
            if ($checkOnly) {
                if (-not $process.WaitForExit(5000) -or $process.ExitCode -ne 1) { throw 'CMD -CheckOnly 應非互動回傳1。' }
            } else {
                if ($process.WaitForExit(1000)) { throw '雙擊入口失敗後過早關閉，使用者無法閱讀錯誤。' }
                $process.StandardInput.WriteLine('')
                if (-not $process.WaitForExit(5000) -or $process.ExitCode -ne 1) { throw '讀取錯誤後確認離開，應回傳1。' }
            }
            Write-Output "PASS：CMD CheckOnly=$checkOnly，繁中錯誤可讀，退出碼1。"
        } finally {
            if ($process.StartInfo.RedirectStandardInput -and -not $process.HasExited) {
                $process.StandardInput.WriteLine('')
                if (-not $process.WaitForExit(5000)) { [Console]::Error.WriteLine('錯誤：受測CMD尚未退出，未強制終止。') }
            }
            $process.Dispose()
        }
    }
} catch {
    [Console]::Error.WriteLine("錯誤：CMD入口測試失敗：$($_.Exception.Message)")
    exit 1
}
