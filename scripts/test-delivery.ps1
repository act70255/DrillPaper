#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageDirectory,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [ValidateRange(2,5)][int]$Rounds = 3,
    [switch]$UseLauncher,
    [ValidateRange(0,1)][int]$ExpectedLauncherSmartSleep = 0,
    [switch]$ImmediateExitAfterSave
)
$ErrorActionPreference='Stop'
$app=$null
$previousLocal=$env:LOCALAPPDATA
$created=$false
$result=[ordered]@{result='FAIL'; started=(Get-Date -Format o); phases=@(); shutdowns=@()}
try {
    . (Join-Path $PSScriptRoot 'security-process.ps1')
    Add-Type -Path (Join-Path $PSScriptRoot 'performance-native.cs')
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DeliveryGeometry {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left, top, right, bottom; }
    /** 讀取受測視窗的實體矩形。
     * Args:
     *     window: 已核實的受測視窗。
     *     rect: 接收視窗矩形。
     * Returns:
     *     Win32 呼叫是否成功。
     */
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    /** 暫時切換觀測執行緒的 DPI 座標模式。
     * Args:
     *     context: 要套用的 DPI 模式。
     * Returns:
     *     原有模式，供呼叫端還原。
     */
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
}
'@
    $package=(Resolve-Path -LiteralPath $PackageDirectory).Path
    $application=Join-Path $package 'DrillPaper.exe'
    $session=[IO.Path]::GetFullPath($EvidenceDirectory)
    if (-not $env:USERPROFILE) { throw '缺少 USERPROFILE。' }
    $prefix=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')+'\'
    $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
    foreach ($path in @($package,$session)) {
        if (-not $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)) { throw '套件與證據必須在非 Temp 使用者目錄。' }
    }
    if (Test-Path -LiteralPath $session) { throw '證據目錄已存在，拒絕覆寫。' }
    New-Item -ItemType Directory -Path $session | Out-Null
    $created=$true
    $result.application=@{path=$application; sha256=(Get-FileHash -LiteralPath $application).Hash}
    $result.launcher=[bool]$UseLauncher
    $result.immediateExitAfterSave=[bool]$ImmediateExitAfterSave
    $result.expectedLauncherSmartSleep=$ExpectedLauncherSmartSleep

    function Wait-Delivery([scriptblock]$Condition,[string]$Message) {
        <# 等待本次已核實程序的原生整合條件。
        Args:
            Condition: 必須成立的條件。
            Message: 逾時時保存的繁中原因。
        #>
        $clock=[Diagnostics.Stopwatch]::StartNew()
        do {
            if ($app.HasExited) { throw '受測程序提前退出。' }
            if (& $Condition) { return }
            Start-Sleep -Milliseconds 100
        } while ($clock.Elapsed.TotalSeconds -lt 30)
        throw $Message
    }
    function Command-Delivery([int]$Id) {
        <# 向本次程序的可信通知入口傳送管理命令。
        Args:
            Id: 產品管理命令識別。
        #>
        $windows=@([PerformanceProbe]::Find($app.Id,'DrillPaperShellNotifications'))
        if ($windows.Count -ne 1) { throw '沒有唯一的管理通知入口。' }
        [void][PerformanceProbe]::SendMessage($windows[0],0x111,[UIntPtr]::new([uint32]$Id),[IntPtr]::Zero)
    }
    function Stop-Delivery {
        <# 正式退出隔離 app，持有已核實子程序 handle 並等待；不強制終止未知程序。
        Returns:
            正式退出與當下可觀察子程序證據。
        #>
        $children=[Collections.Generic.List[Diagnostics.Process]]::new()
        $record=@{children=@(); observationError=$null; childObservationStartedUtc=[DateTime]::UtcNow.ToString('o')}
        try {
            try {
                $entries=@(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains((Join-Path $data 'DrillPaper/WebView2')) })
                foreach ($entry in $entries) {
                    $child=$null
                    try {
                        $child=Get-Process -Id $entry.ProcessId -ErrorAction Stop
                        $null=$child.Handle
                        if ($child.Path -ne $entry.ExecutablePath -or $child.StartTime -lt $app.StartTime -or [Math]::Abs(($child.StartTime.ToUniversalTime()-$entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1) { throw '子程序精確身分不符。' }
                        $record.children+=@{id=$child.Id; path=$child.Path; start=$child.StartTime.ToUniversalTime().ToString('o')}
                        $children.Add($child); $child=$null
                    } finally { if ($child) { $child.Dispose() } }
                }
            } catch { $record.observationError=$_ | Out-String }
            if (-not $app.HasExited) {
                $notifications=@([PerformanceProbe]::Find($app.Id,'DrillPaperShellNotifications'))
                $record.exitCommandUtc=[DateTime]::UtcNow.ToString('o')
                $exitClock=[Diagnostics.Stopwatch]::StartNew()
                if ($notifications.Count -eq 1) { [void][PerformanceProbe]::PostMessage($notifications[0],0x111,[UIntPtr]::new(20006),[IntPtr]::Zero) }
                $exited=$app.WaitForExit(15000)
                $record.exitWaitMilliseconds=$exitClock.Elapsed.TotalMilliseconds
                $record.exitObservationUtc=[DateTime]::UtcNow.ToString('o')
                if (-not $exited) { throw '正式退出逾時，未強制終止。' }
            }
            $record.exitCode=$app.ExitCode
            $record.childrenExited=@($children | ForEach-Object { $_.WaitForExit(15000) })
            if ($record.observationError -or $children.Count -eq 0 -or $record.exitCode -ne 0 -or $record.childrenExited -contains $false) { throw '正常退出或子程序觀測不足。' }
            $record.result='PASS'
        } catch { $record.result='CLEANUP_FAILED'; $record.details=$_ | Out-String }
        finally { foreach ($child in $children) { $child.Dispose() } }
        return $record
    }
    foreach ($round in 1..$Rounds) {
        $data=Join-Path $session "round-$round/appdata"
        foreach ($mode in @('desktop','preview')) {
            $launch=Join-Path $session "round-$round/$mode"
            New-Item -ItemType Directory -Path $launch -Force | Out-Null
            $env:LOCALAPPDATA=$data
            if ($UseLauncher) {
                $started=[DateTime]::UtcNow
                $cmd=Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /c ""'+(Join-Path $package 'Start-DrillPaper.cmd')+'""') -WorkingDirectory $package -WindowStyle Hidden -PassThru
                try { if (-not $cmd.WaitForExit(30000) -or $cmd.ExitCode -ne 0) { throw '交付入口未完成依賴檢查／啟動。' } } finally { $cmd.Dispose() }
                $candidates=@(Get-Process DrillPaper -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $application -and $_.StartTime.ToUniversalTime() -ge $started })
                if ($candidates.Count -ne 1) { throw '無法確認入口建立的唯一隔離 app。' }
                $app=$candidates[0]; $null=$app.Handle
                $entry=Get-CimInstance Win32_Process -Filter "ProcessId=$($app.Id)"
                if (-not $entry -or [Math]::Abs(($entry.CreationDate.ToUniversalTime()-$app.StartTime.ToUniversalTime()).TotalMilliseconds) -ge 1) { throw '入口程序建立時間不符。' }
                @{id=$app.Id; path=$app.Path; start=$app.StartTime.ToUniversalTime().ToString('o'); parent=$entry.ParentProcessId; commandLine=$entry.CommandLine} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $launch 'entry-process.json') -Encoding UTF8
            } else {
                $app=Start-SecurityProcess -FilePath $application -ArgumentList '--management' -EvidenceDirectory $launch
            }
            $env:LOCALAPPDATA=$previousLocal
            try {
                Wait-Delivery { @([PerformanceProbe]::Find($app.Id,'DrillPaperManagementWindow')).Count -eq 1 -and @([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow')).Count -eq 1 } '管理／唯一宿主未建立。'
                $manager=[PerformanceProbe]::Find($app.Id,'DrillPaperManagementWindow')[0]
                Wait-Delivery {
                    $hosts=@([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
                    $hosts.Count -eq 1 -and [PerformanceProbe]::GetProp($hosts[0],'DrillPaper.ReadyEpoch').ToInt64() -gt 0
                } '產品預設在 30 秒內未完成握手。'
                $hostWindow=[PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow')[0]
                $sleep=[PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20103),0xF0,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32()
                $network=[PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20106),0xF0,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32()
                $selectedMode=[PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20102),0x147,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32()
                $expectedSleep=if ($UseLauncher) { $ExpectedLauncherSmartSleep } else { 1 }
                $expectedNetwork=[int]($UseLauncher -and $mode -eq 'preview')
                if ($sleep -ne $expectedSleep -or $network -ne $expectedNetwork -or $selectedMode -ne [int]($mode -eq 'preview')) { throw '有效智慧休眠／網路／模式不符。' }
                $phase=@{round=$round; mode=$mode; smartSleep=$sleep; network=$network; id=$app.Id; start=$app.StartTime.ToUniversalTime().ToString('o'); ready=[PerformanceProbe]::GetProp($hostWindow,'DrillPaper.ReadyEpoch').ToInt64(); caption=[PerformanceProbe]::Caption($hostWindow); parent=[PerformanceProbe]::GetParent($hostWindow).ToInt64()}
                if ($mode -eq 'desktop') {
                    if ($phase.parent -eq 0 -or [PerformanceProbe]::GetProp($hostWindow,'DrillPaper.DesktopEpoch').ToInt64() -le 0) { throw '首次啟動未完成真正桌布附掛。' }
                    $dpi=[DeliveryGeometry]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))
                    try {
                        $rect=[DeliveryGeometry+Rect]::new(); $bounds=[Windows.Forms.Screen]::PrimaryScreen.Bounds
                        if (-not [DeliveryGeometry]::GetWindowRect($hostWindow,[ref]$rect) -or $rect.left -ne $bounds.Left -or $rect.top -ne $bounds.Top -or $rect.right -ne $bounds.Right -or $rect.bottom -ne $bounds.Bottom) { throw '首次桌布未完整覆蓋主螢幕。' }
                        $phase.primary=@{left=$rect.left; top=$rect.top; right=$rect.right; bottom=$rect.bottom}
                    } finally { [void][DeliveryGeometry]::SetThreadDpiAwarenessContext($dpi) }
                    # 先取消草稿，再保存 Preview，驗證入口沿用偏好。
                    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20106),0xF1,[UIntPtr]::new(1),[IntPtr]::Zero)
                    Command-Delivery 20011
                    if ([PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20106),0xF0,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32() -ne 0) { throw '取消未恢復網路草稿。' }
                    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20102),0x14E,[UIntPtr]::new(1),[IntPtr]::Zero)
                    if ($UseLauncher) { [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20106),0xF1,[UIntPtr]::new(1),[IntPtr]::Zero) }
                    $phase.saveCommandUtc=[DateTime]::UtcNow.ToString('o')
                    Command-Delivery 20010
                    $phase.saveReturnedUtc=[DateTime]::UtcNow.ToString('o')
                    $settings=Join-Path $data 'DrillPaper/settings.json'
                    $saved=Get-Content -Raw -LiteralPath $settings | ConvertFrom-Json
                    if ($saved.displayMode -ne 'preview' -or $saved.smartSleep -ne [bool]$expectedSleep -or $saved.allowNetwork -ne [bool]$UseLauncher -or @($saved.monitorTargets).Count -ne 1) { throw '保存 Preview／入口偏好失敗。' }
                    $phase.saved=$saved
                    $savedHash=(Get-FileHash -LiteralPath $settings).Hash
                    # 分開驗原始立即退出情境與保存後待新 Preview 就緒的情境；原判準及期限不變。
                    if (-not $ImmediateExitAfterSave) {
                        $observedPreview=@{}
                        Wait-Delivery {
                            $hosts=@([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
                            if ($hosts.Count -eq 1 -and [PerformanceProbe]::GetParent($hosts[0]) -eq [IntPtr]::Zero -and
                                [PerformanceProbe]::GetProp($hosts[0],'DrillPaper.ReadyEpoch').ToInt64() -gt 0 -and
                                [PerformanceProbe]::GetProp($hosts[0],'DrillPaper.HealthTick').ToInt64() -gt 0) {
                                $observedPreview.window=$hosts[0]
                                return $true
                            }
                            return $false
                        } '保存後的新 Preview 未完成握手與 JS 回應。'
                        $preview=$observedPreview.window
                        $phase.savedPreview=@{hwnd=$preview.ToInt64(); parent=[PerformanceProbe]::GetParent($preview).ToInt64(); ready=[PerformanceProbe]::GetProp($preview,'DrillPaper.ReadyEpoch').ToInt64(); health=[PerformanceProbe]::GetProp($preview,'DrillPaper.HealthTick').ToInt64()}
                    } else {
                        $phase.savedPreviewObservation='NOT RUN：本情境於保存後立即要求退出，不等待新 Preview。'
                    }
                } else {
                    $reloaded=Get-Content -Raw -LiteralPath $settings | ConvertFrom-Json
                    if ($phase.parent -ne 0 -or (Get-FileHash -LiteralPath $settings).Hash -ne $savedHash -or (@($reloaded.monitorTargets) -join ',') -cne (@($saved.monitorTargets) -join ',')) { throw '重啟未沿用 Preview／目標或自行改寫偏好。' }
                    $phase.settingsSha256=$savedHash
                    Command-Delivery 10002
                    Wait-Delivery { @([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow') | Where-Object { [PerformanceProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() -gt 0 -and [PerformanceProbe]::Caption($_).Contains('Dashboard') }).Count -eq 1 } '套件 Dashboard 未握手。'
                    $phase.dashboard='PASS'
                }
                $result.phases+=$phase
            } finally {
                $shutdown=Stop-Delivery
                $result.shutdowns+=$shutdown
                $app.Dispose(); $app=$null
                if ($shutdown.result -ne 'PASS') { throw '退出觀測未通過，請查看 shutdowns。' }
            }
        }
    }
    $result.result='PASS'
} catch {
    $result.details=$_ | Out-String
    [Console]::Error.WriteLine('錯誤：交付整合未完成，請查 result.json；有防毒證據時另標 BLOCKED。')
} finally {
    $env:LOCALAPPDATA=$previousLocal
    if ($app) { $result.shutdowns+=Stop-Delivery; $app.Dispose() }
    $result.ended=(Get-Date -Format o)
    if ($created) {
        try { $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8 }
        catch {
            $result.result='EVIDENCE_FAILED'
            $result.evidenceError=$_ | Out-String
            $diagnostic=Join-Path $PSScriptRoot ('../artifacts/acceptance/rc08-tool-errors/' + [Guid]::NewGuid().ToString('N') + '.log')
            try {
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null
                $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $diagnostic -Encoding UTF8
            } catch {}
            [Console]::Error.WriteLine("錯誤：無法保存交付驗證證據，不能判定通過。備援日誌：$diagnostic")
        }
    }
    else { $result | ConvertTo-Json -Depth 10 | Write-Output }
}
if ($result.result -ne 'PASS') { exit 1 }
Write-Output "PASS：$Rounds 輪首次主螢幕桌布、入口有效休眠／網路、取消／保存 Preview／目標／重啟與雙主題；人工畫面另驗。"
