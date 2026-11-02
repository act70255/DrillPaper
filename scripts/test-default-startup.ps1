[CmdletBinding()]
#requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [switch]$NoSmartSleep
)
$ErrorActionPreference = 'Stop'
try {
. (Join-Path $PSScriptRoot 'security-process.ps1')
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
$evidence = [IO.Path]::GetFullPath($EvidenceDirectory)
New-Item -ItemType Directory -Path $evidence -ErrorAction Stop | Out-Null
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class StartupProbe {
    private delegate bool Callback(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string name);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    /** 列舉受測程序的原生頂層視窗。
     * Args:
     *     process: 本次隔離程序識別。
     *     name: 原生視窗類別。
     * Returns:
     *     符合條件的視窗。
     */
    public static IntPtr[] Find(uint process, string name) {
        var found = new List<IntPtr>();
        EnumWindows((window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            var text = new StringBuilder(256); GetClassName(window, text, text.Capacity);
            if (owner == process && text.ToString() == name) found.Add(window);
            return true;
        }, IntPtr.Zero);
        return found.ToArray();
    }
}
'@
function Get-AntivirusObservation {
    <# 記錄可讀的 Apex One 行為日誌；不推論完整防毒觀測。
    Returns:
        日誌身分、時間及雜湊。
    #>
    $log = 'C:/Program Files (x86)/Trend Micro/Security Agent/Misc/AEGIS_BM.log'
    if (Test-Path -LiteralPath $log) {
        $item = Get-Item -LiteralPath $log
        return @{path=$log; modified=$item.LastWriteTime.ToString('o'); length=$item.Length; hash=(Get-FileHash -LiteralPath $log).Hash}
    }
    return @{note='無法讀取行為日誌，防毒攔截狀態未知。'}
}
$previousLocal = $env:LOCALAPPDATA
$app = $null
$children = @()
$summary = [ordered]@{
    started=(Get-Date -Format o); file=$application; sha256=(Get-FileHash -LiteralPath $application).Hash
    smartSleep=(-not [bool]$NoSmartSleep); result='RUNNING'; samples=@(); antivirusBefore=(Get-AntivirusObservation)
}
try {
    $env:LOCALAPPDATA = Join-Path $evidence 'appdata'
    $arguments = @('--management','--preview')
    if ($NoSmartSleep) { $arguments += '--no-smart-sleep' }
    $app = Start-SecurityProcess -FilePath $application -ArgumentList $arguments -EvidenceDirectory $evidence
    $summary.process = @{id=$app.Id; start=$app.StartTime.ToString('o'); path=$app.Path}
    $env:LOCALAPPDATA = $previousLocal
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($app.HasExited) { throw "啟動期間程序提前退出：$($app.ExitCode)" }
        $hosts = @([StartupProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
        $sample = @{seconds=$clock.Elapsed.TotalSeconds; hosts=$hosts.Count; epoch=0; caption=''}
        if ($hosts.Count -eq 1) {
            $sample.epoch = [StartupProbe]::GetProp($hosts[0],'DrillPaper.ReadyEpoch').ToInt64()
            $caption = [Text.StringBuilder]::new(1024)
            [void][StartupProbe]::GetWindowText($hosts[0],$caption,$caption.Capacity)
            $sample.caption = $caption.ToString()
        }
        $summary.samples += $sample
        Start-Sleep -Milliseconds 250
    } while ($clock.Elapsed.TotalSeconds -lt 30)
    if ($sample.epoch -le 0) { throw '全新隔離資料在 30 秒內未完成 SDK 握手（ReadyEpoch=0）。' }
    $managers = @([StartupProbe]::Find($app.Id,'DrillPaperManagementWindow'))
    if ($managers.Count -ne 1) { throw '沒有唯一的原生管理視窗。' }
    $summary.effectiveSmartSleep = [StartupProbe]::SendMessage([StartupProbe]::GetDlgItem($managers[0],20103),0xF0,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt64()
    if ($summary.effectiveSmartSleep -ne [int](-not [bool]$NoSmartSleep)) { throw '有效智慧休眠設定與本次測試條件不符。' }
    $summary.result = 'PASS_HANDSHAKE'
} catch {
    $summary.result = 'FAIL'
    $summary.reason = $_.Exception.Message
} finally {
    $env:LOCALAPPDATA = $previousLocal
    if ($app) {
        # 先持有觀察到的子程序 handle，後續只等待該實體，避免 PID 重用。
        $summary.unverifiedChildren = @()
        $tree = [Collections.Generic.HashSet[int]]::new()
        [void]$tree.Add($app.Id)
        $processes = @(Get-CimInstance Win32_Process)
        do {
            $added = $false
            foreach ($entry in $processes) {
                if ($tree.Contains([int]$entry.ParentProcessId) -and $tree.Add([int]$entry.ProcessId)) { $added = $true }
            }
        } while ($added)
        foreach ($childId in $tree) {
            if ($childId -eq $app.Id) { continue }
            $entry = $processes | Where-Object { $_.ProcessId -eq $childId }
            $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
            if ($child) {
                try {
                    $null = $child.Handle
                    if ([Math]::Abs(($child.StartTime.ToUniversalTime() - $entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -lt 1 -and $child.StartTime -ge $app.StartTime) { $children += $child }
                    else { $summary.unverifiedChildren += @{id=$childId; reason='建立時間不符。'}; $child.Dispose() }
                } catch { $summary.unverifiedChildren += @{id=$childId; reason=$_.Exception.Message}; $child.Dispose() }
            } else { $summary.unverifiedChildren += @{id=$childId; reason='觀測後已找不到程序，沒有持有實體 handle。'} }
        }
        $summary.children = @($children | ForEach-Object { @{id=$_.Id; start=$_.StartTime.ToString('o')} })
        if ($children.Count -eq 0) { $summary.childObservation='未能驗證任何子程序，不能宣稱清理通過。' }
        if (-not $app.HasExited) {
            $notifications = @([StartupProbe]::Find($app.Id,'DrillPaperShellNotifications'))
            if ($notifications.Count -eq 1) { [void][StartupProbe]::PostMessage($notifications[0],0x111,[UIntPtr]::new(20006),[IntPtr]::Zero) }
            else { [void]$app.CloseMainWindow() }
            if (-not $app.WaitForExit(15000)) { $summary.shutdown='逾時'; $app.Kill(); $app.WaitForExit() }
        }
        $summary.exitCode = $app.ExitCode
        $summary.childrenExited = @($children | ForEach-Object { $_.WaitForExit(15000) })
        foreach ($child in $children) { $child.Dispose() }
        $app.Dispose()
    }
    $summary.antivirusAfter = Get-AntivirusObservation
    $summary.ended = Get-Date -Format o
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'result.json') -Encoding UTF8
}
if ($summary.result -ne 'PASS_HANDSHAKE') { [Console]::Error.WriteLine($summary.reason); exit 1 }
if ($summary.exitCode -ne 0 -or $summary.shutdown -or $summary.childObservation -or $summary.unverifiedChildren.Count -gt 0 -or $summary.childrenExited -contains $false) { [Console]::Error.WriteLine('啟動回歸的正常退出／子程序清理未通過，含無法確認的程序請查閱結果。'); exit 1 }
Write-Output "PASS：預設啟動握手、正式退出及已觀察子程序清理。智慧休眠=$($summary.smartSleep)；證據=$evidence"
} catch {
    $diagnostic = Join-Path $PSScriptRoot ('../artifacts/acceptance/rc05-tool-errors/' + [Guid]::NewGuid().ToString('N') + '.log')
    try { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null; $_ | Out-String | Set-Content -LiteralPath $diagnostic -Encoding UTF8 } catch {}
    [Console]::Error.WriteLine("錯誤：無法完成預設啟動觀測，請確認程式路徑、全新證據目錄與執行環境。診斷日誌：$diagnostic")
    exit 1
}
