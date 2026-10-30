# DrillPaper 試用版（未簽章）

這是本機評估用 app ZIP，含 Release EXE、兩個內建主題與 SDK 執行資產，不是 RC 或公開發行。版本／來源 commit／各檔案與 EXE SHA-256 見 package-manifest.json；ZIP SHA-256 見 ZIP 旁同名 JSON。EXE 的 --version 仍顯示 0.1.0-dev，以 manifest 識別試用版本。

## 安裝與依賴

完整解壓至可讀取的 Windows x64 目錄後，雙擊 Start-DrillPaper.cmd。請以一般使用者操作；此入口檢查依賴，開啟管理視窗並沿用使用者保存的顯示模式。全新資料首次啟動為 Minimal 桌布、目標為主螢幕；保存 Preview 後再次由此入口啟動仍為 Preview。試用入口預設關閉智慧休眠，原因見下方已知限制。也可執行 `powershell -NoProfile -ExecutionPolicy Bypass -File ./Start-DrillPaper.ps1 -CheckOnly` 只檢查。

- 系統：Windows 10／11 x64。不同 Windows、DPI、Shell、硬體仍須實測；本包沒有安裝器或自動更新。
- WebView2Loader.dll 1.0.2478.35 隨包提供，BSD-3-Clause 授權與 NOTICE 在 resources/licenses。完整 WebView2 Evergreen 瀏覽器不隨包提供；請從 https://developer.microsoft.com/microsoft-edge/webview2/ 取得。一般使用者安裝方式見 https://learn.microsoft.com/microsoft-edge/webview2/concepts/distribution 。
- MSVC /MD 依賴 Microsoft Visual C++ v14 x64 Runtime，最低工具鏈版本見 manifest；需使用不早於建置工具鏈的版本。未隨包複製系統 CRT DLL；取得 https://aka.ms/vc14/vc_redist.x64.exe ，說明 https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist 。缺少時停止並提示，若安裝需管理員，請交由管理人員準備後再以一般使用者執行 app。
- 不要求 Node、Python、Visual Studio、原始碼或開發者路徑。NVML 僅選配，使用既有驅動 DLL，不隨包再散布；GPU 不可用時不應顯示假 0。

本包不自動下載、不安裝依賴、不提升權限、不變更系統或執行原則設定。直接啟動 EXE 會略過上述檢查；缺少 DLL 時可能先看到 Windows loader 訊息。缺檔請完整重新解壓，不要只取單一 EXE。

## 使用

管理視窗可選 Minimal／Dashboard、勾選目標螢幕、設定預覽或桌布、智慧休眠與網路，按「套用並儲存設定」生效。「取消設定變更」還原草稿；關閉管理視窗只隱藏。系統匣可重開唯一管理視窗、暫停／繼續，使用「結束 DrillPaper」正式退出。固定用戶區為 800×600 DIP，長清單／訊息可捲動，Tab／Shift+Tab 移動焦點。

每個選中螢幕顯示完整同一主題，未選螢幕保留 Windows 桌布。多螢幕保存以裝置識別恢復，全部斷線才提示並暫用主螢幕。桌布使用未公開保證的 Shell 附掛方式，失敗會退回 Preview；不要同時用試用包替換你原本運行的持續桌布。

主題網路在全新資料中預設關閉，首次封鎖只提示；既有設定若已允許連網會沿用。開啟僅放行 HTTP／HTTPS 資源，外部導覽、框架、WebSocket、權限、下載與彈窗仍受限制。沒有遙測；WebView2 會有多個子程序與瀏覽器本身的資源成本。

## 免安裝 ZIP 與資料

這是免安裝程式檔案，不是完全隨身資料模式。設定在 `%LOCALAPPDATA%\DrillPaper\settings.json`，已匯入主題在其 `themes`，日誌在其 `logs`；WebView2 profile 也在 `%LOCALAPPDATA%\DrillPaper` 下。啟動會讀取既有偏好／主題，不會自動隔離、重設或清除。試用入口只覆寫本次智慧休眠為關閉，不因啟動自動寫回設定；若按「套用並儲存設定」，目前草稿的關閉值也會保存。直接無參數 EXE 恢復保存模式及智慧休眠偏好，全新資料的產品預設仍為智慧休眠開啟。

安全試用方式：在新的 PowerShell 行程將 `$env:LOCALAPPDATA` 設為你建立的全新完整目錄，再執行 Start-DrillPaper.cmd；隔離僅作用於該子行程，不永久改環境。不要在原持續桌布資料上測試。若需要既有資料，先正常退出其 app、備份整個資料目錄，測後退出試用 app 再還原並核對檔案 hash；本輪不做此操作。

移除時先正式退出，再刪除解壓目錄。使用者資料不會隨之刪除；只有確認無需保留且沒有其他 DrillPaper 使用它時，才另外刪除你指定的資料目錄。不要誤刪原桌布資料。

## 未驗收與限制

- **已知啟動缺陷：預設智慧休眠啟動仍為 FAIL。** 全新隔離資料、智慧休眠開啟時，曾觀察到 30 秒未完成主題握手，根因待 05 診斷。本試用入口帶 `--no-smart-sleep` 暫時關閉智慧休眠；app 本身的預設不變。手動重新開啟可能重現缺陷，且本入口每次啟動仍關閉它；關閉期間不宣稱具備智慧休眠的省電效果。05 修正後，08 重新打包須移除此繞行、回到產品預設行為重驗，09 持續追蹤 FAIL，不能以本試用包的啟動通過解除。
- 04／原 3：完整 DNS／推測連線、其他 Runtime、舊頁面競態與權限／scheme 安全矩陣；未宣稱第三方主題已沙箱化，只匯入可信內容。
- 05／原 4：其他 Windows、真實 Explorer／桌面互動、拔插、鎖定／待機／喚醒／顯示器電源與 DPI 完整矩陣。
- 06／原 5：GPU/NVML／NVIDIA、硬體精度、10～30 分鐘 CPU／GPU／記憶體與休眠效能對照。
- 07／原 6：完全獨立第三方作者依文件開發／打包／匯入／移除的完整流程。
- 08／09：乾淨一般使用者安裝／移除、缺 runtime 實機、完整回歸與正式 RC 放行。人工外觀、真正系統匣點擊與桌面互動未由自動握手測試證明。

本包實測／NOT RUN 清單由交付時的 trial-package REPORT 與 STATUS 記錄；以上缺口不因產生 ZIP 而解除。第一方 Apache-2.0 與第三方授權見 LICENSE、THIRD_PARTY_NOTICES.md、resources/licenses。
