[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [ValidateRange(1,8)][int]$Crashes = 3,
    [ValidateSet('renderer','browser')][string]$ProcessKind = 'renderer',
    [ValidateRange(5,45)][int]$TimeoutSeconds = 30,
    [switch]$ExpectBoundedFallback,
    [switch]$CustomEntry,
    [switch]$ReselectBeforeFinal
)
$ErrorActionPreference = 'Stop'
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
if ($ExpectBoundedFallback -and $Crashes -ne 8) { throw '有界退化驗證需注入 8 次故障，涵蓋 3 次重建、Minimal 回復與其後上限。' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaperRecovery-' + [Guid]::NewGuid().ToString('N'))
$profile = Join-Path $testRoot 'appdata/DrillPaper/WebView2'
$evidence = Join-Path $PSScriptRoot ('../artifacts/acceptance/recovery-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $testRoot,$evidence -Force | Out-Null
if (-not ('DrillPaperRecoveryProbe' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DrillPaperRecoveryProbe {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool PostMessage(IntPtr window, uint message, UIntPtr command, IntPtr data);
    /** 讀取原生宿主公開的握手世代診斷值。
     * Args:
     *     window: 本次 app 的視窗。
     *     name: 診斷屬性名稱。
     * Returns:
     *     屬性資料，未設定時為 0。
     */
    [DllImport("user32.dll", CharSet=CharSet.Unicode, ExactSpelling=true)]
    public static extern IntPtr GetPropW(IntPtr window, string name);
}
'@
}

function Get-OwnedBrowser([int]$RootId) {
    <#
    尋找且驗證本次隔離 profile 的唯一 browser。
    Args:
        RootId: 本次啟動的 app PID。
    Returns:
        唯一且已驗證的 browser 資訊，過渡期間找不到時為空。
    #>
    $candidates = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$RootId AND Name='msedgewebview2.exe'" |
        Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '--type=' -and $_.CommandLine.IndexOf($profile,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if ($candidates.Count -gt 1) { throw '發現多個 browser，拒絕猜測要終止的程序。' }
    if ($candidates.Count -eq 1) { return $candidates[0] }
    return $null
}

function Get-OwnedRenderers($Browser) {
    <#
    只列出已驗證 browser 的 renderer 子程序。
    Args:
        Browser: 經 profile 與父 PID 驗證的 browser。
    Returns:
        renderer 程序資訊陣列。
    #>
    return @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($Browser.ProcessId) AND Name='msedgewebview2.exe'" |
        Where-Object { $_.CommandLine -match '--type=renderer(?:\s|$)' })
}

$summary = [ordered]@{ ProcessKind=$ProcessKind; RequestedCrashes=$Crashes; ExpectBoundedFallback=[bool]$ExpectBoundedFallback; CustomEntry=[bool]$CustomEntry; SmartSleepEnabled=$false; SourceSha256=(Get-FileHash -LiteralPath $application -Algorithm SHA256).Hash; Result='RUNNING'; Rounds=@() }
$previousAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = Join-Path $testRoot 'appdata'
    if ($CustomEntry) {
        $customSource=Join-Path $testRoot 'source'
        New-Item -ItemType Directory -Path (Join-Path $customSource 'pages') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $customSource 'theme.json') -Encoding utf8 -Value '{"id":"recovery-entry","name":"復原測試","version":"1.0.0","apiVersion":"1","entry":"pages/view.html","author":"測試","description":"","capabilities":["cpu"],"permissions":[]}'
        Set-Content -LiteralPath (Join-Path $customSource 'pages/view.html') -Encoding utf8 -Value '<!doctype html><title>復原測試</title><script type="module" src="../main.js"></script>'
        Set-Content -LiteralPath (Join-Path $customSource 'main.js') -Encoding utf8 -Value "import { DrillPaperClient } from './desktop-monitor-sdk.js'; const client = new DrillPaperClient(window.chrome.webview); await client.ready(); await client.getSnapshot(); await client.subscribe({metrics:['cpu'],intervalMs:1000});"
        $package=Join-Path $testRoot 'custom.dmt'
        & (Join-Path $PSScriptRoot 'package-theme.ps1') -ThemeDirectory $customSource -OutputFile $package | Out-Null
        $import=Start-Process -FilePath $application -ArgumentList '--import-theme',('"'+$package+'"') -WindowStyle Hidden -PassThru
        $importHandle=$import.Handle
        if(-not $import.WaitForExit(15000)){ $import.Kill(); throw '自訂入口主題匯入逾時。' }
        if($import.ExitCode -ne 0){ throw '自訂入口主題匯入失敗。' }
        $import.Dispose()
    }
    $app = Start-Process -FilePath $application -ArgumentList '--preview','--mock-metrics','--theme=dashboard','--no-smart-sleep' -WindowStyle Normal -PassThru
    $appHandle = $app.Handle
} finally { $env:LOCALAPPDATA = $previousAppData }
try {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        Start-Sleep -Milliseconds 100
        $app.Refresh()
        if ($app.HasExited) { throw 'app 在初始握手前退出。' }
    } while (($app.MainWindowTitle -notlike '*Live metrics' -or [DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -le 0) -and $clock.Elapsed.TotalSeconds -lt 30)
    if ([DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -le 0) { throw "app 未完成初始通訊：$($app.MainWindowTitle)" }
    if ($CustomEntry) {
        $beforeCustomEpoch=[DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64()
        [void][DrillPaperRecoveryProbe]::PostMessage($app.MainWindowHandle,0x111,[UIntPtr]::new([uint32]11000),[IntPtr]::Zero)
        $clock.Restart()
        do { Start-Sleep -Milliseconds 100; $app.Refresh() } while(($app.MainWindowTitle -notlike '*recovery-entry*Live metrics' -or [DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -le $beforeCustomEpoch) -and $clock.Elapsed.TotalSeconds -lt 25)
        if([DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -le $beforeCustomEpoch){ throw '自訂 HTML 入口未完成初始握手。' }
    }
    $summary.RootProcessId = $app.Id
    for ($round=1; $round -le $Crashes; $round++) {
        if ($ReselectBeforeFinal -and $round -eq $Crashes) {
            $previousEpoch = [DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64()
            [void][DrillPaperRecoveryProbe]::PostMessage($app.MainWindowHandle,0x111,[UIntPtr]::new([uint32]10002),[IntPtr]::Zero)
            $clock.Restart()
            do { Start-Sleep -Milliseconds 100; $app.Refresh() } while ([DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -le $previousEpoch -and $clock.Elapsed.TotalSeconds -lt 25)
            if ([DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64() -le $previousEpoch) { throw '重新選擇主題未完成握手。' }
        }
        $browser = Get-OwnedBrowser $app.Id
        if (-not $browser) { throw '無法驗證隔離 browser，未終止任何程序。' }
        $targets = @(if ($ProcessKind -eq 'browser') { $browser } else { Get-OwnedRenderers $browser })
        if ($targets.Count -lt 1 -or $targets.Count -gt 5) { throw 'renderer 數量不符合隔離測試範圍，拒絕終止。' }
        $epoch = [DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64()
        $victimIds = @($targets | ForEach-Object { [int]$_.ProcessId })
        Write-Output "第 $round 次故障注入：$ProcessKind；已驗證目標 PID=$($victimIds -join ',')；握手世代=$epoch"
        foreach ($victimId in $victimIds) {
            $victim = Get-Process -Id $victimId -ErrorAction SilentlyContinue
            if ($victim) { $victim.Kill(); $victim.WaitForExit(5000) | Out-Null; $victim.Dispose() }
        }
        $clock.Restart()
        $nextEpoch = $epoch
        $expectStopped = $ExpectBoundedFallback -and $round -eq $Crashes
        do {
            Start-Sleep -Milliseconds 100
            $app.Refresh()
            if ($app.HasExited) { throw 'WebView2 故障使原生 app 提前退出。' }
            $nextEpoch = [DrillPaperRecoveryProbe]::GetPropW($app.MainWindowHandle,'DrillPaper.ReadyEpoch').ToInt64()
            if ($expectStopped -and $app.MainWindowTitle -like '*渲染已停止*' -and $nextEpoch -eq 0) { break }
            if ($nextEpoch -gt $epoch -and $app.MainWindowTitle -like '*Live metrics') { break }
        } while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds)
        if ($expectStopped) {
            if ($app.MainWindowTitle -notlike '*渲染已停止*' -or $nextEpoch -ne 0) { throw '超過復原上限後沒有退回可關閉的原生預覽。' }
            $summary.BoundedFallback = $true
            $summary.Rounds += [pscustomobject]@{ Round=$round; Victims=$victimIds; BeforeEpoch=$epoch; AfterEpoch=$nextEpoch; RootProcessId=$app.Id; Fallback='NATIVE_PREVIEW' }
            continue
        }
        if ($nextEpoch -le $epoch -or $app.MainWindowTitle -notlike '*Live metrics') { throw '故障後未觀察到新的 SDK 握手與即時資料，不能以舊標題判定恢復。' }
        if ($ReselectBeforeFinal -and $round -eq $Crashes -and $app.MainWindowTitle -notlike '*Dashboard*') { throw '重新選擇主題後未恢復額度，錯誤退化至 Minimal。' }
        $nextBrowser = Get-OwnedBrowser $app.Id
        if (-not $nextBrowser -or @(Get-OwnedRenderers $nextBrowser).Count -lt 1) { throw '沒有可驗證的恢復後 renderer。' }
        $summary.Rounds += [pscustomobject]@{ Round=$round; Victims=$victimIds; BeforeEpoch=$epoch; AfterEpoch=$nextEpoch; RecoverySeconds=$clock.Elapsed.TotalSeconds; RootProcessId=$app.Id }
    }
    $summary.Result = 'PASS_PROTOCOL_RECOVERY'
    if ($ExpectBoundedFallback) { Write-Output 'PASS：故障重建與 Minimal 回復達上限後，退回可關閉的原生預覽，沒有無限重試。' }
    else { Write-Output "PASS：$Crashes 次 $ProcessKind 故障後，同一 app 均重新完成 SDK 握手與即時資料。" }
} catch {
    $summary.Result = 'FAILED'
    $summary.FailureReason = $_.Exception.Message
    throw
} finally {
    $app.Refresh()
    if (-not $app.HasExited) {
        if ($app.CloseMainWindow() -and $app.WaitForExit(15000)) { $summary.Shutdown='NORMAL_CLOSE' }
        else { $summary.Shutdown='FAILED_NORMAL_CLOSE'; $app.Kill(); $app.WaitForExit() }
    }
    $summary.ExitCode = $app.ExitCode
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'summary.json') -Encoding utf8
    Write-Output "復原測試紀錄：$evidence"
    $app.Dispose()
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('DrillPaperRecovery-',[StringComparison]::Ordinal)) {
        for($attempt=0;$attempt -lt 20;$attempt++) {
            try { Remove-Item -LiteralPath $resolved -Recurse -Force; break }
            catch { if($attempt -eq 19){ throw }; Start-Sleep -Milliseconds 500 }
        }
    }
}
