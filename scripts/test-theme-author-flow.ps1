#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ApplicationPath,
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [string]$ExpectedName = '作者離線儀表板',
    [switch]$MockMetrics,
    [switch]$Desktop,
    [switch]$AllowNetwork
)
$ErrorActionPreference = 'Stop'
$app = $null
$previousLocal = $env:LOCALAPPDATA
$created = $false
$handles = [Collections.Generic.List[Diagnostics.Process]]::new()
$result = [ordered]@{result='FAIL'; started=(Get-Date -Format o); phases=@()}
try {
    . (Join-Path $PSScriptRoot 'security-process.ps1')
    Add-Type -Path (Join-Path $PSScriptRoot 'performance-native.cs')
    $application = (Resolve-Path -LiteralPath $ApplicationPath).Path
    $package = (Resolve-Path -LiteralPath $PackagePath).Path
    $session = [IO.Path]::GetFullPath($EvidenceDirectory)
    if (-not $env:USERPROFILE) { throw '缺少 USERPROFILE。' }
    $prefix = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') + '\'
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    foreach ($path in @($application,$package,$session)) {
        if (-not $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase)) {
            throw '程式、套件與證據必須在非 Temp 使用者目錄。'
        }
    }
    if (Test-Path -LiteralPath $session) { throw '證據目錄已存在，拒絕覆寫。' }
    New-Item -ItemType Directory -Path $session | Out-Null
    $created = $true
    $result.application=@{path=$application; sha256=(Get-FileHash -LiteralPath $application).Hash}
    $result.package=@{path=$package; sha256=(Get-FileHash -LiteralPath $package).Hash}
    $result.scenario=@{mock=[bool]$MockMetrics; desktop=[bool]$Desktop; allowNetwork=[bool]$AllowNetwork}
    $env:LOCALAPPDATA=Join-Path $session 'appdata'
    foreach ($expectedExit in @(0,1)) {
        $cli = Start-SecurityProcess -FilePath $application -ArgumentList '--import-theme',$package -EvidenceDirectory $session -CommandOnly
        try {
            if (-not $cli.WaitForExit(15000) -or $cli.ExitCode -ne $expectedExit) { throw '正式匯入／同版本拒絕結果不符，請核對啟動證據與防毒日誌。' }
        } finally { $cli.Dispose() }
    }
    $log = Join-Path $session 'appdata/DrillPaper/logs/theme-commands.log'
    if (-not (Test-Path -LiteralPath $log) -or -not (Get-Content -Raw -LiteralPath $log).Contains('此主題版本已安裝')) { throw '同版本拒絕未留下預期診斷。' }
    $arguments=@('--management','--preview','--no-smart-sleep')
    if ($MockMetrics) { $arguments+='--mock-metrics' }
    $app=Start-SecurityProcess -FilePath $application -ArgumentList $arguments -EvidenceDirectory $session
    $result.process=@{id=$app.Id; path=$app.Path; start=$app.StartTime.ToUniversalTime().ToString('o')}
    $env:LOCALAPPDATA=$previousLocal

    function Wait-Author([scriptblock]$Condition, [string]$Message) {
        <# 等待本次程序的可觀察結果。
        Args:
            Condition: 成功條件。
            Message: 逾時提示。
        #>
        $clock=[Diagnostics.Stopwatch]::StartNew()
        do {
            if ($app.HasExited) { throw '受測程序提前退出。' }
            if (& $Condition) { return }
            Start-Sleep -Milliseconds 100
        } while ($clock.Elapsed.TotalSeconds -lt 35)
        throw $Message
    }
    function Command-Author([int]$Id) {
        <# 由可信原生管理入口操作本次隔離程序。
        Args:
            Id: 正式管理命令識別。
        #>
        [void][PerformanceProbe]::SendMessage($notification,0x111,[UIntPtr]::new([uint32]$Id),[IntPtr]::Zero)
    }
    function Record-Author([string]$Phase, [string]$Name, [int]$Count) {
        <# 等待所有目標完成指定主題的 gated 訂閱，保存原生觀察。
        Args:
            Phase: 階段名稱。
            Name: 必須出現的主題名稱，防止 fallback 冒充。
            Count: 預期宿主數量。
        #>
        Wait-Author {
            $windows=@([PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow'))
            $windows.Count -eq $Count -and @($windows | Where-Object {
                [PerformanceProbe]::GetProp($_,'DrillPaper.ReadyEpoch').ToInt64() -le 0 -or
                -not [PerformanceProbe]::Caption($_).Contains($Name) -or
                -not [PerformanceProbe]::Caption($_).EndsWith('Live metrics')
            }).Count -eq 0
        } "主題未完成作者驗收：$Phase"
        $rows=@(foreach ($window in [PerformanceProbe]::Find($app.Id,'DrillPaperPreviewWindow')) {
            $tick=[PerformanceProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64()
            Wait-Author { [PerformanceProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64() -gt $tick } '宿主未繼續推送資料。'
            @{hwnd=$window.ToInt64(); parent=[PerformanceProbe]::GetParent($window).ToInt64(); caption=[PerformanceProbe]::Caption($window);
                load=[PerformanceProbe]::GetProp($window,'DrillPaper.LoadEpoch').ToInt64(); ready=[PerformanceProbe]::GetProp($window,'DrillPaper.ReadyEpoch').ToInt64();
                tick=[PerformanceProbe]::GetProp($window,'DrillPaper.MetricsTick').ToInt64()}
        })
        # 正向 HTTP 探針另驗兩次訂閱推送後回報 DOM；留時間給接收端完成寫入。
        if ($AllowNetwork -and $Name -eq $ExpectedName) { Start-Sleep -Seconds 2 }
        if ($Desktop -and $Phase -ne 'initial-preview' -and @($rows | Where-Object parent -eq 0).Count) { throw '選取桌面目標未附掛。' }
        $result.phases+=@{phase=$Phase; utc=(Get-Date -Format o); surfaces=$rows}
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8
    }
    Wait-Author { @([PerformanceProbe]::Find($app.Id,'DrillPaperManagementWindow')).Count -eq 1 } '缺少唯一管理視窗。'
    $manager=[PerformanceProbe]::Find($app.Id,'DrillPaperManagementWindow')[0]
    $notifications=@([PerformanceProbe]::Find($app.Id,'DrillPaperShellNotifications'))
    if ($notifications.Count -ne 1) { throw '缺少唯一通知視窗。' }
    $notification=$notifications[0]
    $targets=[PerformanceProbe]::GetDlgItem($manager,20108)
    $count=[PerformanceProbe]::SendMessage($targets,0x1004,[UIntPtr]::Zero,[IntPtr]::Zero).ToInt32()
    $expected=1
    if ($Desktop) {
        if ($count -lt 2) { throw '多目標前提不成立，需記 NOT RUN。' }
        for ($index=0; $index -lt $count; $index++) { [PerformanceProbe]::Check($app.Id,$targets,$index,$true) }
        $expected=$count
        [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20102),0x14E,[UIntPtr]::Zero,[IntPtr]::Zero)
    }
    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20101),0x186,[UIntPtr]::new(2),[IntPtr]::Zero)
    [void][PerformanceProbe]::SendMessage([PerformanceProbe]::GetDlgItem($manager,20106),0xF1,[UIntPtr]::new([uint32][bool]$AllowNetwork),[IntPtr]::Zero)
    Command-Author 20010
    Record-Author 'author-loaded' $ExpectedName $expected
    $settings=Join-Path $session 'appdata/DrillPaper/settings.json'
    $result.settings=Get-Content -Raw -LiteralPath $settings | ConvertFrom-Json
    $savedHash=(Get-FileHash -LiteralPath $settings).Hash
    Command-Author 10001
    Record-Author 'switch-minimal' 'Minimal Monitor' $expected
    Command-Author 11000
    Record-Author 'switch-author' $ExpectedName $expected
    if ((Get-FileHash -LiteralPath $settings).Hash -ne $savedHash) { throw '第三方命令或非保存切換改變設定。' }
    $result.result='PASS'
} catch {
    $result.details=$_ | Out-String
    [Console]::Error.WriteLine('錯誤：作者流程驗證未完成，請查看結果 details 與啟動紀錄；若有防毒攔截，該項須另標 BLOCKED。')
} finally {
    $env:LOCALAPPDATA=$previousLocal
    try {
        if ($app) {
            $result.observedChildren=@()
            try {
                $children=@(Get-CimInstance Win32_Process -Filter "Name='msedgewebview2.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains((Join-Path $session 'appdata/DrillPaper/WebView2')) })
                foreach ($entry in $children) {
                    $child=$null
                    try {
                        $child=Get-Process -Id $entry.ProcessId -ErrorAction Stop
                        $null=$child.Handle
                        if ($child.Path -ne $entry.ExecutablePath -or $child.StartTime -lt $app.StartTime -or
                            [Math]::Abs(($child.StartTime.ToUniversalTime()-$entry.CreationDate.ToUniversalTime()).TotalMilliseconds) -ge 1) { throw '退出觀察的程序身分不符。' }
                        $result.observedChildren+=@{id=$child.Id; path=$child.Path; start=$child.StartTime.ToUniversalTime().ToString('o')}
                        $handles.Add($child)
                        $child=$null
                    } finally { if ($child) { $child.Dispose() } }
                }
            } catch {
                # 子程序觀測失敗不能阻止正式退出，也不能宣稱完整觀測通過。
                $result.result='CLEANUP_FAILED'
                $result.observationDetails=$_ | Out-String
            }
            if (-not $app.HasExited) {
                $notifications=@([PerformanceProbe]::Find($app.Id,'DrillPaperShellNotifications'))
                if ($notifications.Count -eq 1) { [void][PerformanceProbe]::PostMessage($notifications[0],0x111,[UIntPtr]::new(20006),[IntPtr]::Zero) }
                if (-not $app.WaitForExit(15000)) { throw '正式退出逾時，未強制終止。' }
            }
            $result.exitCode=$app.ExitCode
            foreach ($child in $handles) {
                if (-not $child.WaitForExit(15000)) { throw '已觀察子程序未退出。' }
            }
            if ($handles.Count -eq 0 -or $app.ExitCode -ne 0) { throw '正常退出／子程序觀測證據不足。' }
        }
    } catch { $result.result='CLEANUP_FAILED'; $result.cleanupDetails=$_ | Out-String }
    finally {
        foreach ($child in $handles) { $child.Dispose() }
        if ($app) { $app.Dispose() }
    }
    $result.ended=Get-Date -Format o
    if ($created) {
        try { $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $session 'result.json') -Encoding UTF8 }
        catch {
            $result.result='EVIDENCE_FAILED'
            $diagnostic=Join-Path $PSScriptRoot ('../artifacts/acceptance/rc07-tool-errors/' + [Guid]::NewGuid().ToString('N') + '.log')
            try {
                [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($diagnostic)) | Out-Null
                ($_ | Out-String) + ($result | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $diagnostic -Encoding UTF8
            } catch {}
            [Console]::Error.WriteLine("錯誤：無法保存作者流程證據，不能判定通過。備援日誌：$diagnostic")
        }
    }
    else { $result | ConvertTo-Json -Depth 8 | Write-Output }
}
if ($result.result -eq 'CLEANUP_FAILED') { [Console]::Error.WriteLine("錯誤：子程序觀測或正式退出未完成，請查看結果：$session/result.json") }
if ($result.result -ne 'PASS') { exit 1 }
Write-Output 'PASS：正式匯入／同版拒絕、作者載入、切換、設定不變與正常退出；人工畫面另驗。'
