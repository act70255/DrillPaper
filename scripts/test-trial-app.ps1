[CmdletBinding()]
param([Parameter(Mandatory)][string]$ArchivePath)
$ErrorActionPreference = 'Stop'
$session = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaper 試用 路徑 ' + [Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath (Resolve-Path -LiteralPath $ArchivePath).Path -DestinationPath $session
$manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $session 'package-manifest.json') | ConvertFrom-Json
$actual = @(Get-ChildItem -LiteralPath $session -Recurse -File)
if ($actual.Count -ne $manifest.files.Count + 1) { throw '解壓清單與 manifest 不符。' }
foreach ($record in $manifest.files) {
    if ((Get-FileHash -LiteralPath (Join-Path $session $record.path)).Hash -cne $record.sha256) { throw "解壓內容 hash 不符：$($record.path)" }
}
& (Join-Path $PSScriptRoot 'test-trial-launcher.ps1') -PackageDirectory $session
$application = Join-Path $session 'DrillPaper.exe'
& (Join-Path $PSScriptRoot 'test-management-shell.ps1') -ApplicationPath $application
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DrillPaperTrialDesktopProbe {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int left, top, right, bottom; }
    /** 取得宿主的實體矩形，與 Windows 主螢幕範圍比較。
     * Args:
     *     window: 本次受測宿主。
     *     rect: 實體座標。
     * Returns:
     *     是否成功。
     */
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    /** 設定觀測執行緒的 DPI 感知，避免座標虛擬化。
     * Args:
     *     context: DPI 感知識別。
     * Returns:
     *     原先的 DPI 感知識別。
     */
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
}
'@
$previousLocal = $env:LOCALAPPDATA
$app = $null
try {
    foreach ($mode in @('desktop','preview')) {
        $env:LOCALAPPDATA = Join-Path $session 'isolated-launcher'
        $started = Get-Date
        # 在同一 PowerShell 行程呼叫，避免原生 stdout 管線等候 GUI 子程序持有的 handle。
        & (Join-Path $session 'Start-DrillPaper.ps1')
        $env:LOCALAPPDATA = $previousLocal
        $timer = [Diagnostics.Stopwatch]::StartNew()
        do {
            $candidates = @(Get-Process DrillPaper -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $application -and $_.StartTime -ge $started })
            if ($candidates.Count -eq 1) { $app = $candidates[0]; $null = $app.Handle; break }
            Start-Sleep -Milliseconds 100
        } while ($timer.Elapsed.TotalSeconds -lt 20)
        if (-not $app) { throw '啟動入口沒有建立本次套件 app。' }
        do {
            if ($app.HasExited) { throw '啟動入口 app 提早退出。' }
            $notifications = @([DrillPaperManagementProbe]::Find($app.Id,'DrillPaperShellNotifications'))
            $managers = @([DrillPaperManagementProbe]::Find($app.Id,'DrillPaperManagementWindow'))
            $windows = @([DrillPaperManagementProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
            if ($notifications.Count -eq 1 -and $managers.Count -eq 1 -and $windows.Count -eq 1 -and
                [DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.ReadyEpoch').ToInt64() -gt 0 -and
                ($mode -ne 'desktop' -or [DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.DesktopEpoch').ToInt64() -gt 0)) { break }
            Start-Sleep -Milliseconds 100
        } while ($timer.Elapsed.TotalSeconds -lt 30)
        if ($notifications.Count -ne 1 -or $managers.Count -ne 1 -or $windows.Count -ne 1 -or
            ($mode -eq 'desktop' -and [DrillPaperManagementProbe]::GetParent($windows[0]) -eq [IntPtr]::Zero) -or
            ($mode -eq 'preview' -and [DrillPaperManagementProbe]::GetParent($windows[0]) -ne [IntPtr]::Zero) -or
            [DrillPaperManagementProbe]::SendMessage([DrillPaperManagementProbe]::GetDlgItem($managers[0],20102),0x147,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt64() -ne $(if ($mode -eq 'desktop') { 0 } else { 1 }) -or
            [DrillPaperManagementProbe]::SendMessage([DrillPaperManagementProbe]::GetDlgItem($managers[0],20103),0xF0,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt64() -ne 0 -or
            [DrillPaperManagementProbe]::SendMessage([DrillPaperManagementProbe]::GetDlgItem($managers[0],20106),0xF0,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt64() -ne 0) {
            throw "試用入口應沿用 $mode 模式、關閉智慧休眠且網路預設關閉。通知=$($notifications.Count)，管理=$($managers.Count)，宿主=$($windows.Count)，就緒=$([DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.ReadyEpoch'))，父視窗=$([DrillPaperManagementProbe]::GetParent($windows[0]))"
        }
        $status = [Text.StringBuilder]::new(4096)
        [void][DrillPaperManagementProbe]::ReadText([DrillPaperManagementProbe]::GetDlgItem($managers[0],20100),0xD,[UIntPtr]::new(4096),$status)
        Write-Output "試用入口初始狀態：$status"
        $timer.Restart()
        while ([DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.ReadyEpoch').ToInt64() -le 0 -and $timer.Elapsed.TotalSeconds -lt 30) {
            if ($app.HasExited) { throw '試用入口在握手前退出。' }
            Start-Sleep -Milliseconds 100
        }
        if ([DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.ReadyEpoch').ToInt64() -le 0) { throw '預設啟動入口未在 30 秒內完成主題握手。' }
        @{mode=$mode; parent=[DrillPaperManagementProbe]::GetParent($windows[0]).ToInt64();
            ready=[DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.ReadyEpoch').ToInt64();
            smartSleep=$false; network=$false; status=$status.ToString()} |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session "launcher-$mode.json") -Encoding UTF8
        if ($mode -eq 'desktop') {
            if ([DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.DesktopEpoch').ToInt64() -le 0) { throw '首次入口未完成桌布附掛。' }
            $previousDpi = [DrillPaperTrialDesktopProbe]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))
            try {
                $bounds = [Windows.Forms.Screen]::PrimaryScreen.Bounds
                $rect = [DrillPaperTrialDesktopProbe+Rect]::new()
                if (-not [DrillPaperTrialDesktopProbe]::GetWindowRect($windows[0],[ref]$rect) -or
                    $rect.left -ne $bounds.Left -or $rect.top -ne $bounds.Top -or $rect.right -ne $bounds.Right -or $rect.bottom -ne $bounds.Bottom) {
                    throw '首次入口的唯一桌布宿主未完整覆蓋 Windows 主螢幕。'
                }
                @{left=$rect.left; top=$rect.top; right=$rect.right; bottom=$rect.bottom; primary=$bounds.ToString()} |
                    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'launcher-primary.json') -Encoding UTF8
            } finally { [void][DrillPaperTrialDesktopProbe]::SetThreadDpiAwarenessContext($previousDpi) }
            # 由原生管理介面保存 Preview，下一次必須仍經相同入口恢復。
            [void][DrillPaperManagementProbe]::SendMessage([DrillPaperManagementProbe]::GetDlgItem($managers[0],20102),0x14E,[UIntPtr]::new(1),[IntPtr]::Zero)
            [void][DrillPaperManagementProbe]::SendMessage($notifications[0],0x111,[UIntPtr]::new(20010),[IntPtr]::Zero)
            $settingsFile = Join-Path $session 'isolated-launcher/DrillPaper/settings.json'
            $saved = Get-Content -Raw -Encoding UTF8 $settingsFile | ConvertFrom-Json
            if ($saved.displayMode -ne 'preview' -or $saved.smartSleep -or @($saved.monitorTargets).Count -ne 1) { throw 'Preview／單一目標保存結果不符。' }
            $savedHash = (Get-FileHash -LiteralPath $settingsFile).Hash
        } elseif ((Get-FileHash -LiteralPath $settingsFile).Hash -ne $savedHash) { throw '入口重啟不應自動改寫保存偏好。' }
        [void][DrillPaperManagementProbe]::SendMessage($notifications[0],0x111,[UIntPtr]::new(20006),[IntPtr]::Zero)
        if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 0) { throw '試用入口 app 未正常退出。' }
        $app.Dispose(); $app = $null
        Write-Output "PASS：實際入口沿用 $mode 模式、關閉智慧休眠、網路關閉，完成握手並正式退出。"
    }
    foreach ($theme in @('minimal','dashboard')) {
        $env:LOCALAPPDATA = Join-Path $session "isolated-$theme"
        # 此命令建立使用者需檢視的預覽視窗；不操作其他桌布程序。
        $app = Start-Process -FilePath $application -ArgumentList '--preview','--no-smart-sleep',"--theme=$theme" -WorkingDirectory ([IO.Path]::GetTempPath()) -WindowStyle Normal -PassThru
        $null = $app.Handle
        $env:LOCALAPPDATA = $previousLocal
        $timer = [Diagnostics.Stopwatch]::StartNew()
        do {
            if ($app.HasExited) { throw "試用主題 $theme 提早退出。" }
            $windows = @([DrillPaperManagementProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
            if ($windows.Count -eq 1 -and [DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.ReadyEpoch').ToInt64() -gt 0) { break }
            Start-Sleep -Milliseconds 100
        } while ($timer.Elapsed.TotalSeconds -lt 30)
        if ($windows.Count -ne 1 -or [DrillPaperManagementProbe]::GetProp($windows[0],'DrillPaper.ReadyEpoch').ToInt64() -le 0) { throw "$theme 未完成 SDK 握手。" }
        $title = [Text.StringBuilder]::new(1024)
        [void][DrillPaperManagementProbe]::GetWindowText($windows[0],$title,$title.Capacity)
        $name = if ($theme -eq 'minimal') { 'Minimal Monitor' } else { 'Dashboard' }
        if (-not $title.ToString().Contains($name)) { throw '實際載入主題不符，不可以 Minimal fallback 代替成功。' }
        [void][DrillPaperManagementProbe]::SendMessage($windows[0],0x10,[UIntPtr]::Zero,[IntPtr]::Zero)
        if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 0) { throw '主題預覽未正常退出。' }
        $app.Dispose(); $app = $null
        Write-Output "PASS：套件內建 $theme 在另一工作目錄握手並正常退出。"
    }
} finally {
    $env:LOCALAPPDATA = $previousLocal
    if ($app) {
        if (-not $app.HasExited) { [void]$app.CloseMainWindow(); if (-not $app.WaitForExit(10000)) { $app.Kill() } }
        $app.Dispose()
    }
}
# 原生多目標腳本額外需要父視窗 fixture；此為測試工具，不屬於 app 套件依賴。
$fixture = Join-Path $PSScriptRoot '../build/windows-msvc-release/Release/DrillPaperParentFixture.exe'
$fixtureTarget = Join-Path $session 'DrillPaperParentFixture.exe'
try {
    Copy-Item -LiteralPath $fixture -Destination $fixtureTarget
    & (Join-Path $PSScriptRoot 'test-multi-monitor.ps1') -ApplicationPath $application
} finally { if (Test-Path -LiteralPath $fixtureTarget) { Remove-Item -LiteralPath $fixtureTarget } }
@{result='PASS'; directory=$session; sourceCommit=$manifest.sourceCommit; executableSha256=$manifest.executableSha256;
    manualVisual='NOT RUN'; physicalHotplug='NOT RUN'; realTrayClick='NOT RUN'; cleanUser='NOT RUN'; timestamp=(Get-Date -Format o)} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'trial-test-result.json') -Encoding UTF8
Write-Output "PASS：套件解壓／基本管理／雙主題／多目標驗證；隔離目錄：$session"
