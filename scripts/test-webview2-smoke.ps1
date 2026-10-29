[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [ValidateRange(1, 60)][int]$TimeoutSeconds = 15,
    [ValidateSet('minimal', 'dashboard')][string]$Theme = 'minimal',
    [switch]$MockMetrics
)

$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
if ([IO.Path]::GetFileName($application) -cne 'DrillPaper.exe') {
    throw 'ApplicationPath 必須指向 DrillPaper.exe。'
}
if (-not ('DrillPaperSmokeProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DrillPaperSmokeProbe {
    /** 讀取本次宿主公開的協定握手世代。
     * Args:
     *     window: 本次 app 的視窗。
     *     name: 原生診斷屬性名稱。
     * Returns:
     *     已完成訂閱的世代，未就緒時為 0。
     */
    [DllImport("user32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
    public static extern IntPtr GetPropW(IntPtr window, string name);
}
'@
}

$process = $null
try {
    # 此測試只驗證協定，隔離當前螢幕關閉／鎖定政策；省電另由生命週期測試驗證。
    $arguments = @('--preview','--no-smart-sleep',"--theme=$Theme")
    if ($MockMetrics) { $arguments += '--mock-metrics' }
    $process = Start-Process -FilePath $application -ArgumentList $arguments `
        -WorkingDirectory (Split-Path -Parent $application) -PassThru
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $expectedTitle = "DrillPaper Preview — $Theme — Live metrics"
    do {
        Start-Sleep -Milliseconds 250
        $process.Refresh()
        if ($process.HasExited) {
            throw "DrillPaper 在 WebView2 協定就緒前退出（退出碼 $($process.ExitCode)）。"
        }
        if ($process.MainWindowTitle -ceq $expectedTitle -and [DrillPaperSmokeProbe]::GetPropW($process.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -gt 0) { break }
    } while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds)

    if ($process.MainWindowTitle -cne $expectedTitle -or [DrillPaperSmokeProbe]::GetPropW($process.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -le 0) {
        throw "WebView2 預覽未在 $TimeoutSeconds 秒內完成 SDK 握手、快照與訂閱；目前標題：$($process.MainWindowTitle)"
    }
    Write-Output "PASS WebView2 smoke: app window '$($process.MainWindowTitle)' (PID $($process.Id))."
}
finally {
    if ($process -and -not $process.HasExited) {
        if (-not $process.CloseMainWindow()) {
            throw 'DrillPaper 未接受正常關閉請求。'
        }
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            throw 'DrillPaper 未在正常關閉請求後退出。'
        }
    }
}
