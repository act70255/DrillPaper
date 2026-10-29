# 使用者指南（開發 Preview）

目前 DrillPaper 沒有安裝器或可發布 app RC。以下命令適用於已有 Visual Studio、Windows SDK、CMake 與 WebView2 Runtime 的開發電腦，不代表一般使用者安裝流程已驗收。

## 建置與測試

在 repository 根目錄開 PowerShell：

```powershell
cmake --preset windows-msvc-release
cmake --build --preset windows-msvc-release --parallel 8
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1 -Configuration Release
```

本機 Windows 11 已準備標準 MSVC／Windows SDK／CMake；`-LocalToolchain` 是先前環境的 wrapper，目前不需要。測試涵蓋 native CTest、Node SDK、環境、採樣與主題封裝檢查。

## 執行 Preview

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --mock-metrics --theme=dashboard
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --theme=minimal
.\build\windows-msvc-release\Release\DrillPaper.exe --version
.\build\windows-msvc-release\Release\DrillPaper.exe --diagnostics
```

`--mock-metrics` 使用測試資料；省略該旗標時採集器讀取本機 Windows metrics。`--theme` 僅能選擇內建 `minimal` 或 `dashboard`，每次啟動選一個。關閉 Preview 視窗可退出。WebView2 Evergreen Runtime 是執行需求，本機測試機已安裝；不會由此開發流程自動安裝。

此視窗不是桌布附掛；目前沒有系統 tray、一般使用者安裝或解除安裝功能。`--experimental-desktop` 不在已支援的使用方式內。

## 原生主題安裝與切換

本機 Windows 11 標準建置的 EXE 位於 `build/windows-msvc-release/Release`；先前的 `local-msvc-release` 路徑僅適用舊電腦工具鏈。

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --import-theme "C:\Themes\example.dmt"
.\build\windows-msvc-release\Release\DrillPaper.exe --list-themes
```

只匯入信任的內容；主題尚未沙箱化。套件會限額驗證、暫存安裝到 `%LOCALAPPDATA%\DrillPaper\themes\<id>@<version>`，同版本不覆蓋。啟動 Preview 後，以「主題」功能表選擇內建及已安裝版本；執行中 CLI 匯入新版本後，按「重新整理已安裝主題」。切換不重啟宿主；握手逾時會嘗試回復 Minimal。目前沒有圖形化匯入或移除介面。

## Theme 作者檢查

```powershell
npm run test:sdk
.\scripts\package-theme.ps1 -ThemeDirectory sdk/examples/minimal `
  -OutputFile artifacts/theme-sdk/minimal.dmt
.\scripts\validate-theme-package.ps1 -Path artifacts/theme-sdk/minimal.dmt
```

`.dmt` 可由開發工具建立並驗證，再透過原生 CLI 安裝。SDK 使用說明見 [`theme-sdk.md`](theme-sdk.md)。

## 限制

第三方 theme 未沙箱化。網路提示／開關尚未接線，policy 源碼不足以證明封鎖。背景採樣、WebView2 暫停／恢復已接入；本機真實鎖定／解鎖 5 次由使用者確認恢復正常。真實 display-off／待機、桌布、Explorer recovery、安全負面與完整長時間效能仍待驗收。`--no-smart-sleep` 可停用節能政策供除錯，不是硬體支援聲明。

## 桌布與 Explorer 實機驗收

從任意 PowerShell 目錄都可使用完整路徑啟動，不需要系統管理員權限：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\WorkSpace\-James\DrillPaper\scripts\test-desktop-host.ps1" -ApplicationPath "C:\WorkSpace\-James\DrillPaper\build\windows-msvc-release\Release\DrillPaper.exe" -RecoveryCycles 1 -ObserveExplorerRestart -ObservationSeconds 900
```

等待「桌面實機觀測已就緒」，顯示桌面並確認數值更新、圖示及工作列操作正常。接著按 Ctrl+Shift+Esc 開啟工作管理員，在「處理程序」找到「Windows 檔案總管」，按右鍵選「重新啟動」。這是重新啟動桌面 Shell；關閉資料夾視窗無法完成這項測試。

桌面與工作列會短暫消失後恢復。腳本確認不同 Shell PID 與成功重掛後，保留 30 秒供人工觀察，再正常關閉並輸出 `artifacts/acceptance/desktop-*/summary.json` 位置。15 分鐘內未觀察到重啟不算通過。測試會關閉自己啟動的 app，不會終止 Explorer；此情境停用 Smart Sleep 以隔離政策，不能同時計為休眠驗收。
