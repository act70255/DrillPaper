[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('DrillPaperOracle-' + [Guid]::NewGuid().ToString('N'))
$evidence = Join-Path $repoRoot ('artifacts/acceptance/theme-oracle-' + (Get-Date -Format yyyyMMdd-HHmmss) + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Path $testRoot,$evidence | Out-Null
$summary = [ordered]@{ Result='RUNNING'; Mutation='Remove path validation only in isolated validator copy' }
try {
    $scripts = Join-Path $testRoot 'scripts'
    New-Item -ItemType Directory -Path $scripts | Out-Null
    foreach ($name in @('test-theme-package.ps1','validate-theme-package.ps1','package-theme.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $scripts
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'sdk') -Destination (Join-Path $testRoot 'sdk') -Recurse
    $validator = Join-Path $scripts 'validate-theme-package.ps1'
    $original = [IO.File]::ReadAllText($validator)
    $needle = '        Assert-Theme (Test-SafeThemePath $rawName) "unsafe archive path ''$rawName''"'
    if (-not $original.Contains($needle) -or $original.IndexOf($needle) -ne $original.LastIndexOf($needle)) { throw '找不到唯一的隔離測試變異位置，已停止。' }
    $summary.OriginalValidatorSha256 = (Get-FileHash $validator -Algorithm SHA256).Hash
    [IO.File]::WriteAllText($validator,$original.Replace($needle,'        # 僅在隔離副本刻意停用路徑檢查，測試必須抓到此缺陷。'),[Text.UTF8Encoding]::new($true))
    $summary.MutatedValidatorSha256 = (Get-FileHash $validator -Algorithm SHA256).Hash
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-Command powershell.exe -ErrorAction Stop).Source
    $start.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $scripts 'test-theme-package.ps1') + '"'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $child = [Diagnostics.Process]::Start($start)
    try {
        $stdoutTask = $child.StandardOutput.ReadToEndAsync()
        $stderrTask = $child.StandardError.ReadToEndAsync()
        if (-not $child.WaitForExit(60000)) { $child.Kill(); $child.WaitForExit(); throw '負面測試判斷驗證逾時。' }
        $summary.ChildExitCode = $child.ExitCode
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $evidence 'stdout.txt'),$stdout,[Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $evidence 'stderr.txt'),$stderr,[Text.UTF8Encoding]::new($false))
        if ($child.ExitCode -eq 0) { throw '負面測試未偵測到刻意放行的路徑穿越封包，不能採信其通過結果。' }
        if (-not $stderr.Contains('traversal.dmt') -or -not $stdout.Contains('PASS accepted: valid.dmt')) { throw '隔離副本因其他原因失敗，未證明負面測試判斷有效。' }
        $summary.Result = 'PASS'
        Write-Output 'PASS：隔離副本刻意停用路徑檢查後，主題負面測試正確失敗；正式 validator 未修改。'
    } finally { $child.Dispose() }
} catch {
    $summary.Result = 'FAILED'
    $summary.FailureReason = $_.Exception.Message
    throw
} finally {
    $summary | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'summary.json') -Encoding UTF8
    Write-Output "負面測試判斷驗證紀錄：$evidence"
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $prefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved).StartsWith('DrillPaperOracle-',[StringComparison]::Ordinal) -and
        (Test-Path -LiteralPath $resolved)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
