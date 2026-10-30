# DrillPaper

DrillPaper 是 Windows x64 C++20/Win32 與 WebView2 的本機系統指標主題宿主原型。可載入兩個內建主題，以原生功能表／系統匣管理主題、模式與設定，並透過 CLI 安裝與列舉資料夾／`.dmt` 主題。目前**不是可安裝產品或 app Release Candidate**；完整桌布相容性、瀏覽器安全、省電整合與發行驗收仍未完成。

專案品牌為 DrillPaper；C++ namespace/include 與部分相容 API 沿用原始 DesktopMonitor 規格。JS SDK 主要入口為 `DrillPaper`，另保留 DesktopMonitor 相容別名。

## 狀態與限制

請先讀 [`docs/STATUS.md`](docs/STATUS.md) 與 [`docs/FINAL_HANDOFF.md`](docs/FINAL_HANDOFF.md)。原生建置、核心測試與 Node SDK 測試已有實測證據；原生 ZIP 匯入、安全負面案例、CLI 與主題切換也各有驗證。各次命令及驗收範圍以 STATUS 為準，不外推到硬體精度、桌布附掛或瀏覽器沙箱。

`scripts/package.ps1` 保留明確的發行阻擋；沒有 app RC ZIP 或安裝器。SDK `1.0.0-rc3` 是本機評估包，不含 app。主題尚未沙箱化，僅匯入你信任的內容；網路開關只對已驗證的瀏覽器通訊邊界提供控制，完整限制見安全文件。

首次 app **試用 ZIP** 使用獨立流程，包含 Release app／兩個主題／SDK 執行資產／WebView2 loader／授權與繁中說明，不解除 RC gate。完整解壓後執行 `Start-DrillPaper.cmd`，以一般使用者開啟管理視窗並沿用保存模式；首次為 Minimal 桌布與主螢幕目標，保存 Preview 後重啟仍為 Preview。需要既有 VC++ v14 x64 與 WebView2 Evergreen，缺失會提示官方取得方式，不自動安裝。免安裝程式檔案仍沿用 `%LOCALAPPDATA%\DrillPaper` 資料，不是完全隨身模式。請先讀包內 README.zh-TW.md；隔離試用與來源 commit、重現命令見 [試用包流程](docs/TRIAL_PACKAGE.md) 及[實測報告](docs/acceptance/2026-10-29/trial-package/REPORT.md)。

試用入口依已確認決策預設帶 `--no-smart-sleep`，暫時關閉智慧休眠；app 本身的預設不變。03 的「預設智慧休眠啟動」歷史 FAIL 保留，05 復測改記「未重現，疑似環境」，未做推測性修正；08 須在乾淨環境以產品預設驗證握手通過後才移除繞行並重新打包，09 持續追蹤。關閉期間不宣稱具備智慧休眠省電效果；人工畫面與其他未驗收矩陣見報告。

## 開發環境

- Windows 10/11 x64、Visual Studio 2022 C++ 工作負載、Windows SDK、CMake 3.25+、Git。
- WebView2 Evergreen Runtime；本機測試版本為 155.0.4283.62，SDK 1.0.2478.35。
- Node.js 22 僅供 Theme SDK/manifest 測試，不是預定產品 runtime。
- NVIDIA NVML 為選配；不支援時應回報 `unavailable`。目前沒有產品 GPU 精度驗證。

本機 Windows 11 環境的安裝版本與步驟見 [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md)。建置與測試：

```powershell
.\scripts\build.ps1 -Configuration Release
.\scripts\test.ps1 -Configuration Release
```

`-LocalToolchain` 僅供先前電腦的 `.toolchain/with-winsdk.cmd` wrapper，這台電腦不需要。原生 CTest：

```powershell
ctest --preset windows-msvc-release --output-on-failure
```

## 執行開發 Preview

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --mock-metrics --theme=dashboard
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --theme=minimal
```

`--version` 和 `--diagnostics` 顯示 build/runtime 資訊。`scripts/test-webview2-smoke.ps1` 會以視窗標題確認 hello、snapshot、subscribe 流程；它不是截圖或 visual QA。Preview 不代表 `--experimental-desktop` 桌面附掛獲得支援。

採集已在背景執行，Windows 工作階段與電源事件會調整採樣及 WebView2 暫停／恢復；`--no-smart-sleep` 可停用這項政策供除錯。鎖定／解鎖已有本機人工與受控事件證據，真實顯示器電源、待機及完整相容性仍待驗收，見 [`docs/runtime.md`](docs/runtime.md)。

桌面／電源整合觀測使用 PowerShell 7：`scripts/test-multi-monitor.ps1 -ApplicationPath <非 Temp 使用者目錄的隔離 EXE> -EvidenceDirectory <尚不存在的證據目錄> -DesktopPowerRecovery`。擴充模式驗證所有宿主的手動暫停、受控工作階段通知、renderer／browser 故障、有限退化與 JS 無限迴圈；EXE 由 Node 直接啟動。測試會建立隔離資料、短暫附掛自己的桌布及建立／銷毀 fixture 父視窗，不重啟 Explorer。真正 OS 事件與目視結果須依 [RC 05 人工清單](docs/acceptance/2026-10-30/desktop-power-recovery/MANUAL_CHECKLIST.md) 另驗，不以原生屬性／資料推送視為畫面通過。

效能及硬體精度觀測工具、事先定義的時長／容差、程序歸屬與未驗項目見 [RC 06 報告](docs/acceptance/2026-10-30/metrics-performance/REPORT.md)。工具需 PowerShell 7／Node，EXE 使用非 Temp 使用者副本；不透過測試喚醒螢幕，也不關閉原持續桌布。

## 系統匣與管理入口

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --management --preview --theme=dashboard
```

右下角系統匣圖示（可能在隱藏圖示區）可開啟同一個管理視窗，提供暫停／繼續、主題清單、預覽／套用、`.dmt` 匯入、使用者主題移除、智慧休眠與日誌入口。「套用並儲存設定」將主題、模式與智慧休眠保存至 `%LOCALAPPDATA%\DrillPaper\settings.json`；「取消設定變更」還原尚未套用的草稿，直接預覽則不保存。無參數啟動使用保存偏好，首次為 Minimal 桌布與啟用智慧休眠。

管理用戶區固定為 800×600 邏輯像素（100% 為 800×600，150% 為 1200×900，標題列與邊框另計），不提供自由縮放。主題／螢幕清單與長狀態文字可捲動，選取螢幕後可在詳細區閱讀及複製完整名稱與識別。Tab／Shift+Tab 移動焦點，空白鍵操作勾選或按鈕；停用操作會略過。工作區較小時可用 Alt+Space、M、方向鍵移動整個視窗，並用 Tab／Shift+Tab 到達主要操作；Enter 結束移動。實測範圍與人工清單見 [設定視窗需求](docs/FIXED_SETTINGS_WINDOW.md)。

管理視窗的「套用螢幕」可勾選一個或多個目標；各目標顯示完整的同一主題，未選螢幕保留 Windows 桌面。首次或舊設定遷移只選主螢幕；保存後依裝置 ID 恢復，未連接目標仍保留在清單。部分斷線只顯示仍連接目標；全部斷線時會明確提示並暫用主螢幕，不改寫原選擇，任一目標接回即恢復。鏡像群組共用一個桌面區域；Preview 維持單一視窗。細節、相關驗證命令與人工操作清單見 [多螢幕政策](docs/MULTI_MONITOR.md)，實測範圍以 STATUS 為準。

「允許主題連網」預設關閉；首次封鎖 HTTP／HTTPS 時只提示前往設定，不會自動允許。勾選後按「套用並儲存設定」才允許所有網域的 HTTP／HTTPS 資源，取消會還原草稿；重新啟動會恢復偏好。開關不放行外部導覽、框架、WebSocket、下載、權限或彈窗。設定套用會重新載入主題。

關閉管理視窗只隱藏；透過「結束 DrillPaper」退出。明確 `--preview` 且未加 `--management` 時，仍維持關閉 Preview 即退出的測試方式。新介面的實機圖示點擊、檔案選擇器、移除確認與 Explorer 重啟依 STATUS 另行驗收。

## Theme SDK

SDK JS、TypeScript declarations、MockHost、manifest schema、兩個範例與作者指南位於 `sdk/`。執行 `npm run test:sdk` 驗證 JS API。安裝與列舉主題：

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --import-theme "C:\Themes\example.dmt"
.\build\windows-msvc-release\Release\DrillPaper.exe --list-themes
```

主題安裝到 `%LOCALAPPDATA%\DrillPaper\themes\<id>@<version>`，同版本禁止覆蓋；失敗會清除本次暫存安裝。Preview 的「主題」功能表可選擇內建及已安裝版本；執行中從 CLI 匯入後，選「重新整理已安裝主題」即可列出。管理視窗另提供匯入與確認移除；內建主題不提供移除。主題未於 20 秒內完成握手時會嘗試回復 Minimal。原生採集程序不因切換而重啟。

詳見 [`docs/theme-sdk.md`](docs/theme-sdk.md)、[`docs/protocol-v1.md`](docs/protocol-v1.md) 和 [`docs/theme-security.md`](docs/theme-security.md)。第一方內容依 Apache-2.0 授權，見根目錄 [`LICENSE`](LICENSE)。
