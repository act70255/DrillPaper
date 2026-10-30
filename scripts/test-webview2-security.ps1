[CmdletBinding()]
param([Parameter(Mandatory)][string]$ApplicationPath, [string]$EvidenceDirectory)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'security-process.ps1')
$application = (Resolve-Path -LiteralPath $ApplicationPath).Path
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class SecurityProbe {
    private delegate bool Callback(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr GetProp(IntPtr window, string name);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr window, uint message, UIntPtr value, IntPtr data);
    /** 找到受測程序的指定頂層視窗。
     * Args:
     *     process: 本次啟動的程序。
     *     name: 原生視窗類別。
     * Returns:
     *     視窗控制代碼；未找到時為零。
     */
    public static IntPtr Find(uint process, string name) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            var text = new StringBuilder(256); GetClassName(window, text, text.Capacity);
            if (owner == process && text.ToString() == name) found = window;
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
'@
function Wait-Security([scriptblock]$Condition, [string]$Failure) {
    <# 等待真實 WebView2／原生管理狀態。
    Args:
        Condition: 成功條件。
        Failure: 逾時時的繁體中文訊息。
    #>
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        if ($app.HasExited) { throw "安全測試 app 提前退出（退出碼 $($app.ExitCode)）；等待項目：$Failure" }
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 100
    } while ($timer.Elapsed.TotalSeconds -lt 15)
    $caption = [Text.StringBuilder]::new(512)
    if ($wallpaper -ne [IntPtr]::Zero) { [void][SecurityProbe]::GetWindowText($wallpaper, $caption, $caption.Capacity) }
    throw "$Failure 目前宿主：$caption"
}
function Stop-SecurityApp {
    <# 正常關閉本測試程序並檢查已觀察的子程序。
    Returns:
        已觀察的子程序 ID 陣列。
    #>
    $processes = @(Get-CimInstance Win32_Process)
    $tree = [Collections.Generic.HashSet[int]]::new()
    $births = [Collections.Generic.Dictionary[int,DateTime]]::new()
    $births[$app.Id] = $app.StartTime.ToUniversalTime()
    [void]$tree.Add($app.Id)
    do {
        $added = $false
        foreach ($process in $processes) {
            $parentId = [int]$process.ParentProcessId
            $created = $process.CreationDate.ToUniversalTime()
            if ($tree.Contains($parentId) -and $created -ge $births[$parentId] -and $tree.Add([int]$process.ProcessId)) {
                $births[[int]$process.ProcessId] = $created
                $added = $true
            }
        }
    } while ($added)
    $children = @(
        foreach ($childId in $tree) {
            if ($childId -eq $app.Id) { continue }
            $child = Get-Process -Id $childId -ErrorAction SilentlyContinue
            if ($child) {
                try {
                    # 先保留真正程序的 handle，避免退出後 PID 被重用時等待另一個程序。
                    $childHandle = $child.Handle
                    if ([Math]::Abs(($child.StartTime.ToUniversalTime() - $births[$childId]).TotalMilliseconds) -lt 1) { $child }
                    else { $child.Dispose() }
                } catch { $child.Dispose() }
            }
        }
    )
    if ($children.Count -eq 0) { throw '沒有觀察到真正的 WebView2 子程序，不能宣稱清理通過。' }
    if ($manager -ne [IntPtr]::Zero) {
        [void][SecurityProbe]::PostMessage($notification, 0x111, [UIntPtr]::new([uint32]20006), [IntPtr]::Zero)
    } else { [void][SecurityProbe]::PostMessage($wallpaper, 0x10, [UIntPtr]::Zero, [IntPtr]::Zero) }
    if (-not $app.WaitForExit(15000) -or $app.ExitCode -ne 0) { throw '安全測試程序未正常退出 0。' }
    foreach ($child in $children) {
        if (-not $child.WaitForExit(15000)) { throw "安全測試的已觀察子程序未退出：$($child.Id)" }
    }
    $childIds = @($children | ForEach-Object { $_.Id })
    foreach ($child in $children) { $child.Dispose() }
    return $childIds
}
function Test-ProbeComplete([long]$PreviousEpoch) {
    <# 確認真正測試主題完成，避免內建 fallback 被誤算為成功。
    Args:
        PreviousEpoch: 開始這次載入前的訂閱世代。
    Returns:
        測試主題完成訂閱時為 true。
    #>
    $caption = [Text.StringBuilder]::new(512)
    [void][SecurityProbe]::GetWindowText($wallpaper, $caption, $caption.Capacity)
    return [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64() -gt $PreviousEpoch -and
        ($caption.ToString().Contains('安全驗證') -or $caption.ToString().Contains('security-probe'))
}
function Test-NavigationRecovery {
    <# 驗證拒絕外部導覽後，主題仍存活或已回復可信 Minimal。
    Returns:
        實際恢復後的原生宿主標題。
    #>
    $before = [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64()
    [void][SecurityProbe]::PostMessage($wallpaper, 0x111, [UIntPtr]::new([uint32]11001), [IntPtr]::Zero)
    Wait-Security {
        $caption = [Text.StringBuilder]::new(512)
        [void][SecurityProbe]::GetWindowText($wallpaper, $caption, $caption.Capacity)
        [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64() -ge ($before + 2) -and
            ($caption.ToString().Contains('導覽復原驗證') -or $caption.ToString().IndexOf('minimal', [StringComparison]::OrdinalIgnoreCase) -ge 0)
    } '外部導覽雖遭封鎖，但原頁面未繼續且沒有回復可信主題。'
}
$previousLocal = $env:LOCALAPPDATA
$app = $null
$server = $null
try {
    $session = if ($EvidenceDirectory) { [IO.Path]::GetFullPath($EvidenceDirectory) }
        else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('../artifacts/acceptance/security-' + [Guid]::NewGuid().ToString('N')))) }
    if (Test-Path -LiteralPath $session) { throw '證據目錄已存在，拒絕覆寫。' }
    $env:LOCALAPPDATA = Join-Path $session 'appdata'
    $source = Join-Path $session 'source'
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    $server = Start-Process -FilePath (Get-Command node).Source -ArgumentList ('"' + (Join-Path $PSScriptRoot '../tests/fixtures/security-server.mjs') + '"'),('"' + $session + '"') -WindowStyle Hidden -PassThru
    $serverClock = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath (Join-Path $session 'server.json'))) {
        if ($server.HasExited -or $serverClock.Elapsed.TotalSeconds -gt 10) { throw '無法啟動隔離的網路測試伺服器。' }
        Start-Sleep -Milliseconds 100
    }
    $serverConfig = Get-Content -Raw -LiteralPath (Join-Path $session 'server.json') | ConvertFrom-Json
    $port = $serverConfig.port
    $securePort = $serverConfig.securePort
    $udp = [Net.Sockets.UdpClient]::new()
    try {
        $packet = [Text.Encoding]::UTF8.GetBytes('drillpaper-udp-control')
        [void]$udp.Send($packet, $packet.Length, '127.0.0.1', $serverConfig.stunPort)
    } finally { $udp.Dispose() }
    $control = [Net.Sockets.TcpClient]::new('127.0.0.1', $securePort)
    $control.Dispose()
    $control = [Net.Sockets.TcpClient]::new('127.0.0.1', $serverConfig.preconnectPort)
    $control.Dispose()
    $control = [Net.Sockets.TcpClient]::new('127.0.0.1', $serverConfig.tlsPreconnectPort)
    $control.Dispose()
    Start-Sleep -Milliseconds 200
    $secureLog = Join-Path $session 'secure-connections.jsonl'
    if (@(Get-Content -LiteralPath $secureLog).Count -ne 1) { throw 'WSS 連線接收端的正向控制未通過。' }
    $preconnectLog = Join-Path $session 'preconnect-connections.jsonl'
    if (@(Get-Content -LiteralPath $preconnectLog).Count -ne 1) { throw 'Preconnect 接收端的正向控制未通過。' }
    $stunLog = Join-Path $session 'stun-packets.jsonl'
    if (@(Get-Content -LiteralPath $stunLog).Count -ne 1) { throw 'STUN UDP 接收端的正向控制未通過。' }
    $probe = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../tests/fixtures/security-probe.js')).Replace('__BASE__', "http://127.0.0.1:$port").Replace('__WSS__', "wss://127.0.0.1:$securePort/socket").Replace('__STUN__', "stun:127.0.0.1:$($serverConfig.stunPort)").Replace('__TURN__', "turn:127.0.0.1:$securePort`?transport=tcp")
    $probe = $probe.Replace('__PRECONNECT__', "http://127.0.0.1:$($serverConfig.preconnectPort)")
    $dnsHost = 'drillpaper-' + [Guid]::NewGuid().ToString('N') + '.example.com'
    $probe = $probe.Replace('__TLS_PRECONNECT__', "https://127.0.0.1:$($serverConfig.tlsPreconnectPort)").Replace('__DNS_HOST__', $dnsHost)
    $tlsLog = Join-Path $session 'tls-preconnect.jsonl'
    if (@(Get-Content -LiteralPath $tlsLog).Count -ne 1) { throw 'TLS preconnect 接收端正向控制失敗。' }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../sdk/javascript/desktop-monitor-sdk.js') -Destination $source
    '{"id":"security-probe","name":"安全驗證","version":"1.0.0","apiVersion":"1","entry":"index.html","author":"DrillPaper","description":"","capabilities":["cpu"],"permissions":[]}' | Set-Content -LiteralPath (Join-Path $source 'theme.json') -Encoding UTF8
    '<!doctype html><body><script type="module" src="main.js"></script>' | Set-Content -LiteralPath (Join-Path $source 'index.html') -Encoding UTF8
    '{"download":"必須拒絕"}' | Set-Content -LiteralPath (Join-Path $source 'download.json') -Encoding UTF8
    'globalThis.onconnect = event => event.ports[0].postMessage("executed"); if (typeof postMessage === "function") postMessage("executed");' | Set-Content -LiteralPath (Join-Path $source 'worker.js') -Encoding UTF8
    $probe.Replace('__ENABLED__', 'false') | Set-Content -LiteralPath (Join-Path $source 'main.js') -Encoding UTF8
    $import = Start-SecurityProcess -FilePath $application -ArgumentList '--import-theme',$source -EvidenceDirectory $session -CommandOnly
    $handle = $import.Handle
    if (-not $import.WaitForExit(15000) -or $import.ExitCode -ne 0) { throw '無法匯入安全測試主題。' }
    $import.Dispose()
    $navigationSource = Join-Path $session 'navigation-source'
    Copy-Item -LiteralPath $source -Destination $navigationSource -Recurse
    $manifest = [IO.File]::ReadAllText((Join-Path $source 'theme.json')).Replace('security-probe', 'security-z-navigation').Replace('安全驗證', '導覽復原驗證')
    [IO.File]::WriteAllText((Join-Path $navigationSource 'theme.json'), $manifest, [Text.UTF8Encoding]::new($false))
    $navigationProbe = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../tests/fixtures/security-navigation.js')).Replace('__BASE__', "http://127.0.0.1:$port")
    [IO.File]::WriteAllText((Join-Path $navigationSource 'main.js'), $navigationProbe, [Text.UTF8Encoding]::new($false))
    $import = Start-SecurityProcess -FilePath $application -ArgumentList '--import-theme',$navigationSource -EvidenceDirectory $session -CommandOnly
    $handle = $import.Handle
    if (-not $import.WaitForExit(15000) -or $import.ExitCode -ne 0) { throw '無法匯入導覽復原測試主題。' }
    $import.Dispose()
    $app = Start-SecurityProcess -FilePath $application -ArgumentList '--management','--preview','--mock-metrics','--no-smart-sleep' -EvidenceDirectory $session -CaptureNetwork
    $handle = $app.Handle
    $env:LOCALAPPDATA = $previousLocal
    Wait-Security { [SecurityProbe]::Find($app.Id, 'DrillPaperShellNotifications') -ne [IntPtr]::Zero } '缺少管理命令入口。'
    $notification = [SecurityProbe]::Find($app.Id, 'DrillPaperShellNotifications')
    $manager = [SecurityProbe]::Find($app.Id, 'DrillPaperManagementWindow')
    Wait-Security { [SecurityProbe]::Find($app.Id, 'DrillPaperPreviewWindow') -ne [IntPtr]::Zero } '缺少初始宿主。'
    $wallpaper = [SecurityProbe]::Find($app.Id, 'DrillPaperPreviewWindow')
    Wait-Security { [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64() -gt 0 } '初始主題未就緒。'
    # Minimal 的閒置時段作為同一瀏覽器程序的背景觀測對照。
    Start-Sleep -Seconds 3
    @{phase='minimal-baseline-ended'; timestamp=(Get-Date -Format o); dnsHost=$dnsHost} | ConvertTo-Json -Compress |
        Set-Content -LiteralPath (Join-Path $session 'network-phases.jsonl') -Encoding UTF8
    $ready = [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64()
    [void][SecurityProbe]::PostMessage($wallpaper, 0x111, [UIntPtr]::new([uint32]11000), [IntPtr]::Zero)
    Wait-Security { [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.NetworkPrompt').ToInt64() -eq 1 } '首次封鎖外連沒有出現設定提示。'
    Wait-Security { Test-ProbeComplete $ready } '預設封鎖的真實資源測試未通過。'
    Wait-Security { [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.DownloadBlocked').ToInt64() -eq 1 } '沒有觀察到真實下載拒絕事件。'
    if (Test-Path -LiteralPath (Join-Path $session 'requests.jsonl')) { throw '預設封鎖時測試伺服器仍收到請求。' }
    if (@(Get-Content -LiteralPath $preconnectLog).Count -ne 1) { throw '預設網路關閉時仍建立 preconnect TCP 連線。' }
    if (@(Get-Content -LiteralPath $tlsLog).Count -ne 1) { throw '預設網路關閉時仍建立 TLS preconnect 連線。' }
    if (@(Get-Content -LiteralPath $stunLog).Count -ne 1) { throw '預設網路關閉時 WebRTC 仍傳送 UDP／STUN 封包。' }
    Test-NavigationRecovery
    $networkCheck = [SecurityProbe]::GetDlgItem($manager, 20106)
    if ($networkCheck -eq [IntPtr]::Zero) { throw '管理介面缺少真正的主題網路開關。' }
    if ([SecurityProbe]::SendMessage($networkCheck, 0xF0, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64() -ne 0) { throw '首次提示自行開啟網路。' }
    [void][SecurityProbe]::SendMessage($networkCheck, 0xF1, [UIntPtr]::new([uint32]1), [IntPtr]::Zero)
    [void][SecurityProbe]::SendMessage($notification, 0x111, [UIntPtr]::new([uint32]20011), [IntPtr]::Zero)
    if ([SecurityProbe]::SendMessage($networkCheck, 0xF0, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64() -ne 0) { throw '取消未還原網路草稿。' }
    $themeList = [SecurityProbe]::GetDlgItem($manager, 20101)
    [void][SecurityProbe]::SendMessage($themeList, 0x186, [UIntPtr]::new([uint32]2), [IntPtr]::Zero)
    $installedScript = Join-Path $session 'appdata/DrillPaper/themes/security-probe@1.0.0/main.js'
    foreach ($enabled in @($true, $false)) {
        for ($attempt = 0; ; $attempt++) {
            try { [IO.File]::WriteAllText($installedScript, $probe.Replace('__ENABLED__', $enabled.ToString().ToLowerInvariant()), [Text.UTF8Encoding]::new($false)); break }
            catch { if ($attempt -ge 20) { throw }; Start-Sleep -Milliseconds 100 }
        }
        [void][SecurityProbe]::SendMessage($networkCheck, 0xF1, [UIntPtr]::new([uint32][int]$enabled), [IntPtr]::Zero)
        $ready = [SecurityProbe]::GetProp($wallpaper, 'DrillPaper.ReadyEpoch').ToInt64()
        $before = if (Test-Path -LiteralPath (Join-Path $session 'requests.jsonl')) { @(Get-Content -LiteralPath (Join-Path $session 'requests.jsonl')).Count } else { 0 }
        $preconnectBefore = @(Get-Content -LiteralPath $preconnectLog).Count
        $tlsBefore = @(Get-Content -LiteralPath $tlsLog).Count
        @{phase="apply-$enabled"; timestamp=(Get-Date -Format o)} | ConvertTo-Json -Compress |
            Add-Content -LiteralPath (Join-Path $session 'network-phases.jsonl') -Encoding UTF8
        [void][SecurityProbe]::PostMessage($notification, 0x111, [UIntPtr]::new([uint32]20010), [IntPtr]::Zero)
        Wait-Security { Test-ProbeComplete $ready } "實際網路切換測試未通過，allowNetwork=$enabled。"
        $after = if (Test-Path -LiteralPath (Join-Path $session 'requests.jsonl')) { @(Get-Content -LiteralPath (Join-Path $session 'requests.jsonl')).Count } else { 0 }
        if (($enabled -and $after -le $before) -or (-not $enabled -and $after -ne $before)) { throw '瀏覽器結果與伺服器實際請求不一致。' }
        if (-not $enabled -and @(Get-Content -LiteralPath $preconnectLog).Count -ne $preconnectBefore) { throw '關閉網路後仍建立 preconnect TCP 連線。' }
        if (-not $enabled -and @(Get-Content -LiteralPath $tlsLog).Count -ne $tlsBefore) { throw '關閉網路後仍建立 TLS preconnect 連線。' }
        if ($enabled) {
            Wait-Security { @(Get-Content -LiteralPath $preconnectLog).Count -gt $preconnectBefore } '開啟網路時沒有觀察到瀏覽器 preconnect 正向控制。'
            Wait-Security { @(Get-Content -LiteralPath $tlsLog | Select-Object -Skip $tlsBefore | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.clientHello }).Count -gt 0 } '開啟網路時沒有觀察到 TLS ClientHello 正向控制。'
        }
        $settings = Get-Content -Raw -LiteralPath (Join-Path $session 'appdata/DrillPaper/settings.json') | ConvertFrom-Json
        if ($settings.allowNetwork -ne $enabled) { throw '網路設定未正確保存。' }
        if (Test-Path -LiteralPath (Join-Path $session 'requests.jsonl')) {
            foreach ($line in Get-Content -LiteralPath (Join-Path $session 'requests.jsonl')) {
                $request = $line | ConvertFrom-Json
                if ($request.url -match '^/(socket|iframe|popup|navigate)') { throw "網路開關繞過安全邊界：$($request.url)" }
            }
        }
        Test-NavigationRecovery
        if ($enabled) {
          foreach ($mode in @('standalone', 'managed')) {
            $children = @(Stop-SecurityApp)
            $app.Dispose()
            $env:LOCALAPPDATA = Join-Path $session 'appdata'
            $arguments = @('--mock-metrics','--no-smart-sleep')
            if ($mode -eq 'managed') { $arguments += '--management' } else { $arguments += '--preview' }
            $requestBeforeRestart = @(Get-Content -LiteralPath (Join-Path $session 'requests.jsonl')).Count
            $app = Start-SecurityProcess -FilePath $application -ArgumentList $arguments -EvidenceDirectory $session -CaptureNetwork
            $handle = $app.Handle
            $env:LOCALAPPDATA = $previousLocal
            Wait-Security { [SecurityProbe]::Find($app.Id, 'DrillPaperShellNotifications') -ne [IntPtr]::Zero } '重啟後沒有管理入口。'
            $notification = [SecurityProbe]::Find($app.Id, 'DrillPaperShellNotifications')
            $manager = [SecurityProbe]::Find($app.Id, 'DrillPaperManagementWindow')
            Wait-Security { [SecurityProbe]::Find($app.Id, 'DrillPaperPreviewWindow') -ne [IntPtr]::Zero } '重啟後缺少宿主。'
            $wallpaper = [SecurityProbe]::Find($app.Id, 'DrillPaperPreviewWindow')
            $networkCheck = [SecurityProbe]::GetDlgItem($manager, 20106)
            Wait-Security { Test-ProbeComplete 0 } '重啟沒有恢復已允許的網路政策。'
            if (@(Get-Content -LiteralPath (Join-Path $session 'requests.jsonl')).Count -le $requestBeforeRestart) { throw "重啟模式 $mode 略過已保存的主題或全域網路偏好。" }
            if ($mode -eq 'managed' -and [SecurityProbe]::SendMessage($networkCheck, 0xF0, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64() -ne 1) { throw '重啟沒有恢復已保存的網路開關。' }
          }
        }
    }
    $children = @(Stop-SecurityApp)
    & node (Join-Path $PSScriptRoot 'check-security-netlog.mjs') $session
    if ($LASTEXITCODE -ne 0) { throw 'SmartScreen 背景 POST 仍存在；停止，不可提交，詳見 smartscreen-result.json。' }
    if (@(Get-Content -LiteralPath $secureLog).Count -ne 1) { throw 'WSS 在設定切換或重啟期間仍嘗試 TCP／TLS 連線。' }
    $packets = @(Get-Content -LiteralPath $stunLog | ForEach-Object { $_ | ConvertFrom-Json })
    if ($packets.Count -ne 1 -or -not $packets[0].control) { throw 'WebRTC 在設定切換或重啟期間仍傳送 UDP／STUN 封包。' }
    @{result='PASS'; application=$application; hash=(Get-FileHash -LiteralPath $application).Hash;
      observedChildren=$children; http='PASS'; prompt='PASS'; switch='off-on-off'; https='PASS (example.com no-cors)';
      webrtc='PASS (UDP/STUN、TURN-TCP、WSS，原生控制各 1，主題連線 0)';
      preconnect='PASS (開啟時有瀏覽器正向控制，關閉時無新增 TCP 連線)';
      storage='PASS (local/session storage、Cookie、IndexedDB、Cache Storage)';
      workers='PASS (Dedicated、Shared、Service)'; permissions='PASS (通知、定位、camera/microphone 實際呼叫)';
      tlsPreconnect='PASS (關閉零新增連線、開啟 ClientHello)'; dnsHost=$dnsHost; managementMessages='PASS (三種拒絕回覆及 snapshot 正向控制)';
      navigation='PASS (原頁面繼續或可信 Minimal 回復)'; timestamp=(Get-Date -Format o)} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8
    Write-Output "PASS：首次封鎖提示，證據：$session"
} catch {
    $reason = $_.Exception.Message
    $details = $_ | Out-String
    $diagnostic = Join-Path $PSScriptRoot ('../artifacts/acceptance/rc09-security-errors/' + [Guid]::NewGuid().ToString('N') + '.log')
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
    try {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic))
        [IO.File]::WriteAllText($diagnostic, $details, [Text.UTF8Encoding]::new($false))
    } catch { [Console]::Error.WriteLine('錯誤：詳細安全日誌無法寫入，請確認工作區權限。') }
    [Console]::Error.WriteLine("錯誤：安全整合觀測失敗：$reason 詳細日誌：$diagnostic")
    exit 1
} finally {
    $env:LOCALAPPDATA = $previousLocal
    if ($app) {
        if (-not $app.HasExited) {
            $notification = [SecurityProbe]::Find($app.Id, 'DrillPaperShellNotifications')
            if ([SecurityProbe]::Find($app.Id, 'DrillPaperManagementWindow') -ne [IntPtr]::Zero) {
                [void][SecurityProbe]::PostMessage($notification, 0x111, [UIntPtr]::new([uint32]20006), [IntPtr]::Zero)
            } else { [void][SecurityProbe]::PostMessage([SecurityProbe]::Find($app.Id, 'DrillPaperPreviewWindow'), 0x10, [UIntPtr]::Zero, [IntPtr]::Zero) }
            if (-not $app.WaitForExit(10000)) { $app.Kill() }
        }
        $app.Dispose()
    }
    if ($server) { if (-not $server.HasExited) { $server.Kill(); [void]$server.WaitForExit(5000) }; $server.Dispose() }
}
