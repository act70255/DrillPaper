# DrillPaper 交付候選版（未簽章）

本票正式交付版本為 **0.1.0-trial.6**：供票 09 回歸的本機候選 ZIP，尚未通過 RC 放行，未公開發布。沿用 trial 封裝格式（manifest kind=trial），與 trial.1～4、trial.5.probe 及審查前候選 trial.5 分開保存。產品來源 commit、工具逐檔 hash、版本與 EXE SHA-256 見 package-manifest.json；ZIP hash 見 ZIP 旁同名 JSON。EXE 的 --version 仍是產品 0.1.0-dev，交付版本以 manifest 為準。

## 安裝與依賴

完整解壓至非 Temp 的使用者目錄（可含空白、繁中），雙擊 **Start-DrillPaper.cmd**。以一般使用者操作，入口先檢查資產及依賴，再由 CMD 直接啟動 EXE；不需要 Node、Python、Visual Studio 或來源樹。不自動安裝依賴、不提升權限、不修改防毒或系統執行原則。雙擊啟動檢查失敗時會停留，供閱讀繁中錯誤與取得方式，按鍵後以代碼 1 結束；也可用 `Start-DrillPaper.cmd -CheckOnly` 只檢查。

- 目標平台：Windows 10／11 x64。這次只在 Windows 11 Pro 25H2 build 26200／Intel Graphics／雙 1920×1080（DPI 144、96）本機測試；Windows 10、其他 Shell、混合配置尚待驗收，不保證所有版本相容。
- WebView2Loader.dll 1.0.2478.35 隨包提供，授權及 NOTICE 在 resources/licenses；WebView2 Evergreen Runtime 為外部必要依賴。本次 Runtime 156.0.4314.50，其他版本待測。由 https://developer.microsoft.com/microsoft-edge/webview2/ 取得；安裝部署方式見 https://learn.microsoft.com/microsoft-edge/webview2/concepts/distribution 。
- Microsoft Visual C++ v14 x64 Runtime 最低版本由 manifest 的 minimumVcRuntime 指定，需不早於建置工具鏈；本包未複製系統 CRT。由 https://aka.ms/vc14/vc_redist.x64.exe 取得；若安裝需管理員，交由 IT 準備後再以一般使用者執行 app。
- NVML 僅選配，使用既有 NVIDIA 驅動 DLL，不隨包再散布；無支援時 GPU 顯示 unavailable，不能當成 0。

**未簽章 EXE 可能被企業防毒攔截或警告。** 本包沒有 Authenticode 簽章。先核對可信來源提供的 ZIP／EXE SHA-256；向 IT 申請針對核實來源與 hash 的例外，不自行停用防毒、不忽略警告。記錄防毒產品／完整版本、每次攔截時間（含時區）、規則、目標 hash、啟動方式及受影響步驟；受攔截項目列 BLOCKED。03 曾有 Apex One 攔截；08-D1 時段另見 WinVerifyTrust 失敗，可能影響時序但未證實因果。缺少完整日誌只能記觀測不足，不能宣稱沒有攔截。避免從 Temp 或經 PowerShell 包裝直接啟動 EXE。

缺檔／空主題資產會提前拒絕並提示完整重新解壓；不要只複製單一 EXE。直接 EXE 會略過入口檢查，缺 CRT 可能出現 Windows loader 訊息。真實無依賴機器測試尚未執行。

## 使用與功能

入口開啟唯一管理視窗，沿用已保存的主題、模式、目標及網路偏好；全新資料首次為 Minimal／主螢幕桌布、網路關閉。Minimal／Dashboard 顯示 CPU、RAM、磁碟、網路、時間及可用 GPU，兩個內建主題與 SDK 作者資產隨包提供。只匯入可信 DMT，透過管理視窗選檔匯入／確認移除；第三方內容未宣稱已沙箱化。

選擇主題、桌布／Preview、目標與網路後，按「套用並儲存設定」生效；「取消設定變更」還原草稿，關閉管理視窗僅隱藏。系統匣可重開、暫停／繼續及「結束 DrillPaper」正式退出。設定用戶區 800×600 DIP，長清單可捲動、Tab／Shift+Tab 可移動焦點。人工外觀／系統匣點擊尚待驗收。

每個選取螢幕完整顯示相同主題，未選螢幕維持 Windows 桌布；離線目標保留設定，全部離線暫用主螢幕且不寫回，恢復後套回原選擇。Shell 附掛失敗回退 Preview。不要在測試中關閉／替換原持續桌布或重啟 Explorer。

主題網路全新預設關閉，首次封鎖只提示；保存允許後沿用，僅放行 HTTP／HTTPS 資源。外部導覽、框架、WebSocket、權限、下載與彈窗仍受限制。產品無遙測功能；WebView2 有多個子程序，其背景網路仍有未完成邊界驗證，**不宣稱整個程序零外連**。

## 資料、更新與回復

免安裝 ZIP 不是完全隨身資料模式。資料根目錄是 `%LOCALAPPDATA%\DrillPaper`：設定 settings.json、已匯入主題 themes、日誌 logs、WebView2 瀏覽器資料 WebView2。啟動會讀取現存資料，不自動隔離或清除。隔離試用可在新的命令提示字元執行 `set "LOCALAPPDATA=C:\Users\你的帳號\DrillPaperTests\專用資料"`，再由該視窗呼叫完整 CMD 路徑；只影響此命令視窗的子程序，路徑須自行建立且不可使用原持續桌布資料。

更新前以「結束 DrillPaper」正常退出使用該資料的舊版及 WebView2 子程序，備份整個資料根目錄及舊版 ZIP／hash；將新版完整解壓到新的非 Temp 目錄，核對 hash，再啟動新版 CMD。不要覆寫運行中的程式檔。回復時先退出新版，再啟動已保留且核實 hash 的舊版；若資料不相容，先備份新版資料再還原舊資料備份，不將兩版同時指向同一資料根目錄。跨版本更新／回復的真正乾淨機器操作仍待人工驗證。

## 移除與保留

先正式退出 app 並確認其 WebView2 子程序結束，再刪除該版解壓目錄即可移除程式檔；沒有安裝器，不宣稱安裝器／解除安裝通過。刪除 ZIP／程式目錄不會自動清除使用者設定、主題、日誌與 profile。只有使用者確認不再需要、已備份，且沒有其他 DrillPaper 使用該資料時，才主動刪除指定的 `%LOCALAPPDATA%\DrillPaper`（隔離測試則是自行指定根目錄下的 DrillPaper）。不可刪除其他帳號、原持續桌布或不相關資料。

## 已知限制與 RC 回歸

- **trial.7 入口移除 `--no-smart-sleep` 繞行**，全新資料沿用產品預設開啟智慧休眠；既有保存為關閉的設定仍保持關閉，不自動改寫。票 09 在本機非 Temp 使用者目錄、隔離資料以產品預設完成三輪立即退出及三輪待新 Preview 就緒的驗證後，依已確認條件移除；不代替真正鎖定／關屏／睡眠的省電驗收。原 trial.6 不變，仍帶繞行。03 歷史預設啟動 FAIL 保留，不宣稱根因已修復。
- **08-D1：保存 Preview 後正式退出超過工具 15 秒觀測期限**；原第 2 輪 FAIL 保留。09 三輪未等待新 Preview 就緒即要求退出時未重現，仍用 15 秒期限且記錄命令／退出時間；不能推定已修正所有時序或防毒影響，後續再現須保存證據並重開缺陷。
- 04 安全仍 PARTIAL：完整 DNS／其他 Runtime／TURN／proxy／外部 handler／真實舊 callback 競態未全部驗收；不保證第三方內容沙箱或 WebView2 零背景網路。
- 05 真正桌面互動、Explorer、鎖定／關屏／睡眠、多 DPI／拔插等仍有 NOT RUN；06 長測達有限門檻但記憶體仍上升，不能排除洩漏，NVIDIA／真實電源與更長 soak 未驗。
- 07／08 GUI 選檔／確認移除、完整版面、真正無來源與工具的一般使用者機器、真實缺 Runtime、更新／回復等仍須人工清單。09 完整自動測試不代替必要實機證據，本試用包不表示 RC 放行；以 repository 最終判定為準。

逐項結果、來源／hash／命令與人工清單見 repository 的 `docs/acceptance/2026-10-30/rc-regression/`；票 08 原始交付與失敗證據保留於 `delivery-final/` 及 `delivery/`。第一方 Apache-2.0 與第三方授權見 LICENSE、THIRD_PARTY_NOTICES.md、resources/licenses。
