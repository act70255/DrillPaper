# 使用者指南（開發 Preview）

目前 DrillPaper 沒有安裝器或可發布 app RC。以下命令適用於已有 Visual Studio、Windows SDK、CMake 與 WebView2 Runtime 的開發電腦，不代表一般使用者安裝流程已驗收。

一般試用請依核實 ZIP 內 README，由 CMD 執行 Start-DrillPaper.cmd；trial.6 仍帶關閉智慧休眠繞行，trial.7 已依已確認多輪條件移除，新資料沿用產品預設、既有偏好不改寫。09 有受控雙目標解除暫停未恢復推送的 FAIL，**拒絕 RC 放行**；完整限制、hash 與人工項見 [最終交接](FINAL_HANDOFF.md)。避免從 Temp 或由 PowerShell 直接啟動 EXE，PowerShell 可協調 CMD／Node。

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
cmd /d /c ".\build\windows-msvc-release\Release\DrillPaper.exe --preview --mock-metrics --theme=dashboard"
cmd /d /c ".\build\windows-msvc-release\Release\DrillPaper.exe --preview --theme=minimal"
cmd /d /c ".\build\windows-msvc-release\Release\DrillPaper.exe --version"
cmd /d /c ".\build\windows-msvc-release\Release\DrillPaper.exe --diagnostics"
```

`--mock-metrics` 使用測試資料；省略該旗標時採集器讀取本機 Windows metrics。`--theme` 僅能選擇內建 `minimal` 或 `dashboard`，每次啟動選一個。關閉 Preview 視窗可退出。WebView2 Evergreen Runtime 是執行需求，本機測試機已安裝；不會由此開發流程自動安裝。

此視窗不是桌布附掛；一般使用者安裝或解除安裝仍未交付。`--experimental-desktop` 的支援範圍依 STATUS 所列實機證據。

## 系統匣管理模式

以 `DrillPaper.exe --management --preview --theme=dashboard` 開啟管理視窗與系統匣。單擊／雙擊圖示開啟同一管理視窗，右鍵提供快捷操作；圖示可能在 Windows 隱藏圖示區。可暫停／繼續、切換桌布／預覽或內建主題，以及開啟日誌。

關閉管理視窗會隱藏；關閉管理模式的 Preview 則暫停並隱藏桌布，程式繼續留在系統匣。請用管理介面或系統匣的「結束 DrillPaper」正式退出。圖示註冊失敗時管理視窗保持可用。

從主題清單選擇後，可暫時預覽或套用為桌布，並以檔案選擇器匯入 `.dmt`。移除只允許使用者主題且需確認；使用中的版本會先切換至 Minimal 並關閉舊 controller。「套用並儲存設定」保存所選主題、顯示模式與智慧休眠；「取消設定變更」只還原未套用草稿，不撤銷已執行的主題預覽或匯入／移除。

設定檔位於 `%LOCALAPPDATA%\DrillPaper\settings.json`。無參數啟動恢復偏好，首次預設 Minimal 桌布與啟用智慧休眠。CLI 的 `--preview`、`--theme`、`--no-smart-sleep` 為暫時覆寫，不自動保存；明確按保存才寫入。設定損毀時程式顯示友善錯誤並保留原檔，請先備份修正。網路開關已接入 host，取消不套用，保存沿用；只放行指定 HTTP／HTTPS 資源，並非完整沙箱或 WebView2 零背景流量。

## 原生主題安裝與切換

本機 Windows 11 標準建置的 EXE 位於 `build/windows-msvc-release/Release`；先前的 `local-msvc-release` 路徑僅適用舊電腦工具鏈。

```powershell
cmd /d /c ".\build\windows-msvc-release\Release\DrillPaper.exe --import-theme "C:\Themes\example.dmt""
cmd /d /c ".\build\windows-msvc-release\Release\DrillPaper.exe --list-themes"
```

只匯入信任的內容；主題尚未沙箱化。套件會限額驗證、暫存安裝到 `%LOCALAPPDATA%\DrillPaper\themes\<id>@<version>`，同版本不覆蓋。啟動 Preview 後，以「主題」功能表選擇內建及已安裝版本；執行中 CLI 匯入新版本後，按「重新整理已安裝主題」。切換不重啟採集工作者；握手逾時會嘗試回復 Minimal。圖形化匯入與移除位於管理視窗。

## Theme 作者檢查

```powershell
npm run test:sdk
.\scripts\package-theme.ps1 -ThemeDirectory sdk/examples/minimal `
  -OutputFile artifacts/theme-sdk/minimal.dmt
.\scripts\validate-theme-package.ps1 -Path artifacts/theme-sdk/minimal.dmt
```

`.dmt` 可由開發工具建立並驗證，再透過原生 CLI 安裝。SDK 使用說明見 [`theme-sdk.md`](theme-sdk.md)。

## 限制

第三方 theme 未證實完整沙箱。網路提示／開關、背景採樣與 WebView2 暫停／恢復已接入，但僅有版本化的指定驗證；歷史真實鎖定／Explorer 結果不套到候選。09-D2 受控解除暫停 FAIL 及真正 OS／安全／效能剩餘矩陣見最終交接。`--no-smart-sleep` 可供除錯，不是節能或硬體支援聲明。

## 桌布與 Explorer 實機驗收

持續試用使用核實 ZIP 的 CMD 入口與獨立資料，不用試用包替換原持續桌布。真正新版 Explorer 重啟、人眼桌面互動及電源／拔插仍需要獨立驗證，依 [RC 09 人工清單](acceptance/2026-10-30/rc-regression/MANUAL_CHECKLIST.md)安排；本輪不執行這些操作。Explorer 操作須另行授權，原持續桌布只核對路徑／精確建立時間／hash，不關閉或替換。

原生屬性、fixture、受控通知或 API／CI 通過不等於真正 Shell／像素／電源驗收；歷史 a241856／62f01ab 的使用者回報僅適用原版本。09-D2 及其他 gate 未補證前拒絕 RC。
