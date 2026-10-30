[CmdletBinding()]
param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
try {
    if (-not [Environment]::Is64BitProcess) { throw '請使用 Windows x64 的 64 位元 PowerShell 啟動試用包。' }
    foreach ($file in @('DrillPaper.exe','WebView2Loader.dll','package-manifest.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) { throw "試用包缺少 $file，請重新完整解壓 ZIP。" }
    }
    $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'package-manifest.json') | ConvertFrom-Json
    [version]$minimum = $null
    if ([string]$manifest.minimumVcRuntime -notmatch '^14\.\d+\.\d+\.\d+$' -or
        -not [version]::TryParse([string]$manifest.minimumVcRuntime,[ref]$minimum)) {
        throw '套件 manifest 缺少或無效的 minimumVcRuntime，請重新完整解壓官方提供的試用 ZIP。'
    }
    foreach ($dll in @('msvcp140.dll','vcruntime140.dll','vcruntime140_1.dll')) {
        $path = Join-Path ([Environment]::SystemDirectory) $dll
        if (-not (Test-Path -LiteralPath $path) -or [version](Get-Item -LiteralPath $path).VersionInfo.FileVersion -lt $minimum) {
            throw "缺少或過舊的 Microsoft Visual C++ v14 x64 Runtime（需要 $minimum 或更新版）。請由 https://aka.ms/vc14/vc_redist.x64.exe 取得；本程式不會安裝或提升權限。"
        }
    }
    $loader = (Join-Path $PSScriptRoot 'WebView2Loader.dll').Replace('"','""')
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class DrillPaperTrialRuntime {
    /** 查詢系統可用的 WebView2 瀏覽器版本。
     * Args:
     *     folder: null 表示 Evergreen。
     *     version: COM 配置的版本字串。
     * Returns:
     *     HRESULT。
     */
    [DllImport(@"$loader", CharSet=CharSet.Unicode)]
    public static extern int GetAvailableCoreWebView2BrowserVersionString(string folder, out IntPtr version);
}
"@
    $pointer = [IntPtr]::Zero
    try {
        $result = [DrillPaperTrialRuntime]::GetAvailableCoreWebView2BrowserVersionString($null,[ref]$pointer)
        if ($result -lt 0 -or $pointer -eq [IntPtr]::Zero) {
            throw '缺少可用的 WebView2 Evergreen Runtime。請由 https://developer.microsoft.com/microsoft-edge/webview2/ 取得 Evergreen Runtime，可由一般使用者安裝；本程式不會下載、安裝或改系統。'
        }
        $runtime = [Runtime.InteropServices.Marshal]::PtrToStringUni($pointer)
    } finally { if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::FreeCoTaskMem($pointer) } }
    Write-Output "DrillPaper $($manifest.version) 試用版；產品 commit $($manifest.sourceCommit)；WebView2 $runtime"
    if (-not $CheckOnly) {
        Start-Process -FilePath (Join-Path $PSScriptRoot 'DrillPaper.exe') -ArgumentList '--management','--no-smart-sleep' -WorkingDirectory $PSScriptRoot | Out-Null
    }
} catch {
    [Console]::Error.WriteLine("無法啟動 DrillPaper 試用版：$($_.Exception.Message)")
    exit 1
}
