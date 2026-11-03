[CmdletBinding()]
param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
try {
    if (-not [Environment]::Is64BitProcess) { throw '請使用 Windows x64 的 64 位元 PowerShell 啟動試用包。' }
    foreach ($file in @('DrillPaper.exe','WebView2Loader.dll','package-manifest.json','Start-DrillPaper.cmd')) {
        if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf)) { throw "試用包缺少 $file，請重新完整解壓 ZIP。" }
    }
    foreach ($theme in @('minimal','dashboard')) {
        foreach ($asset in @('index.html','main.js','style.css','theme.json','javascript/desktop-monitor-sdk.js')) {
            $file = "resources/themes/$theme/$asset"
            if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $file) -PathType Leaf) -or
                (Get-Item -LiteralPath (Join-Path $PSScriptRoot $file)).Length -eq 0) {
                throw "缺少必要主題資產 $file，請重新完整解壓 ZIP。"
            }
        }
    }
    # app 已靜態連結 CRT，不需要 VC++ 可轉散發套件；只剩 WebView2 Evergreen Runtime 為外部依賴。
    $manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'package-manifest.json') | ConvertFrom-Json
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
        Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /c ""' + (Join-Path $PSScriptRoot 'Start-DrillPaper.cmd') + '""') -WorkingDirectory $PSScriptRoot -WindowStyle Hidden | Out-Null
    }
} catch {
    [Console]::Error.WriteLine("無法啟動 DrillPaper 試用版：$($_.Exception.Message)")
    exit 1
}
