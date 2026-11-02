# 7A：首次可攜式試用包

Status: implemented
Type: task
原討論編號：7A
Blocked by: 02

## Scope

在 01／02 完成後首次提供 app 試用 ZIP，建立可重複使用的打包流程供 08 沿用。封裝 Release app、內建主題／SDK 執行資產、可再散布的必要依賴、授權與繁中使用／限制說明；不把 SDK ZIP 或單獨 EXE 當作 app 套件。

## Acceptance

- 從明確 commit 建置並以檔案清單封裝，不依賴開發者絕對路徑；不帶個人設定、匯入內容、日誌、測試證據、憑證或建置暫存。
- 記錄 WebView2 Evergreen、VC++ 等實際依賴與缺失處理；缺依賴提供友善訊息與取得方式，不要求基本使用必須提升權限，不擅自安裝或改系統。
- 明確區分「免安裝 ZIP」與使用者資料位置，說明既有 LOCALAPPDATA 設定／日誌／已匯入主題行為；不默默改成完全隨身資料模式。
- 從含空白／繁中文字元的另一個路徑解壓，以一般使用者驗證啟動、兩個內建主題、目標套用、保存／取消／重啟、網路預設、系統匣及正式退出；不讀取來源樹資產才算套件自足。
- 隔離實測設定與原持續桌布，記錄隔離方法；若需使用者既有資料，先備份並有還原證據，不用試用包替換原桌布。
- 檔名／版本標示試用版，附 commit、套件／EXE SHA-256、Windows／Runtime、基本操作結果與未驗收清單。3～6 的缺口明列，不標示為 RC 或公開發行。
- 01／02 相關測試及封裝基本檢查通過；新增打包邏輯應驗證缺檔拒絕／錯誤回報等有意義案例。產物與重現命令列入 STATUS。
- 08 可沿用腳本與清單重新產包；若 CI 已有 RC gate，新增明確試用產物流程，不為產出 ZIP 而放寬正式 RC gate。

## Comments

- 2026-10-30 Codex 完成：沿用 `feature/rc-03-trial-package` 與既有 Release 位元／證據，不另開分支、不改產品程式。入口改 `--management --no-smart-sleep`，首次直接主螢幕桌布、保存 Preview 後從相同入口重啟仍 Preview；繁中說明明列智慧休眠繞行與保存語意。新 `0.1.0-trial.4` ZIP 未覆寫舊包，SHA-256 `C3ECF566EAB58D4A015D44D749E60F1E6872F5830F31AEB0F3B303ECC40C3287`，產品來源 `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53`、EXE hash 與上輪相同。相關編譯與 CTest 13/13、封裝負面／清單／hash、真實新 ZIP 依賴／首次桌布與主屏幾何／保存 Preview 重啟／雙主題／管理及多目標基本流程均 PASS；中間測試競態、編碼與一次啟動存取被拒另保留，不算產品 PASS。原持續桌布身分／hash 不變、測試程序已退出。「預設智慧休眠啟動」仍 **FAIL**，已傳遞 05／08／09；根因不在本票處理。人工、乾淨使用者／真正缺依賴、04～07 完整矩陣、CI 與完整套件 NOT RUN（後票／09），RC gate 未解除。Standards／Spec 審查與完整命令／證據見 `docs/acceptance/2026-10-29/trial-package/REPORT.md`。依 AGENTS 本票一次 commit 並 push 目前分支，記錄於 STATUS；implemented 僅代表已確認的試用範圍完成。
- 2026-10-29 Codex 停止：從起始 HEAD `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53` 建立 `feature/rc-03-trial-package`，新增乾淨來源 Release 建置、白名單封裝、依賴啟動入口／授權與繁中說明、獨立 trial CI 草稿。相關 CTest 13/13 與封裝負面通過，產出未驗收 trial.3；但全新隔離資料的預設入口 30 秒後通知／管理／Preview 各 1、parent=0、網路=0、ReadyEpoch=0，未達基本啟動前提。停用智慧休眠並重新套用後可握手的繞行不列預設啟動 PASS；根因未定，不擅自變更已確認預設。按使用者要求停止、不 commit、不 push，本票維持 in-progress。現有實測與重現、人工 NOT RUN 清單見 `docs/acceptance/2026-10-29/trial-package/REPORT.md`。此現象可能涉及 05 生命週期，先記本票 Comments，尚未擴張修改產品。完整套件及 CI NOT RUN。

- 2026-10-29：使用者要求完成 1、2 後先打包。此票完成即可提供試用包，完整安全／硬體矩陣留給後續票；打包與套件實測均 NOT RUN。
- 2026-10-29 調查備註（Claude，派工前）：既有 scripts/package.ps1 將內建主題封成 `resources/themes/<theme>.dmt`，但 app 的 ResolveTheme 讀取 `<exe 目錄>/resources/themes/<key>/index.html` 目錄；且該腳本帶有固定 RC blocker 會直接拒絕。試用包流程須以 app 實際讀取的佈局為準並讓解壓後自足，同時不放寬正式 RC gate。CMake 使用 /MD（動態 VC++ runtime），依賴處理須明確記錄。
- 2026-10-29 決策（使用者確認）：需要人工操作或看畫面的實機項目先完成可自動執行部分，其餘標 NOT RUN 並附人工操作清單，不中斷流程；不關閉／替換原持續桌布。
- 2026-10-30 決策（使用者確認）：預設智慧休眠下 30 秒未握手的啟動缺陷延到 05 診斷與修正，本票不改產品程式。7A 試用包的啟動入口改為預設關閉智慧休眠（例如帶 `--no-smart-sleep`），並在繁中說明與報告中列為已知限制，註明 app 本身的智慧休眠預設不變、根因待 05、08 重新打包時須回到預設行為重驗。關閉智慧休眠下的預設入口啟動與基本流程即可作為本票驗收；同時明列「預設智慧休眠啟動」仍為 FAIL，傳遞至 05／08／09。
- 2026-10-30 決策（使用者確認）：試用入口不得以 `--preview` 強制顯示模式，改用使用者保存的模式（首次啟動即產品預設：桌布模式、目標為主螢幕）。驗收須涵蓋首次啟動直接進入桌布模式，以及保存為 Preview 後重新從入口啟動仍為 Preview。實測時使用隔離資料，桌布測試只短暫附掛並正常退出，不關閉／替換原持續桌布。
- 2026-10-30 補記（Claude，03 commit 後）：trial.4 驗證期間 Trend Micro Apex One 即時掃描對解壓於 `%TEMP%\DrillPaper 試用 路徑 …` 的未簽章 DrillPaper.exe 記錄 WinVerifyTrust 失敗；09:22:30（+08:00）行為監控規則 `NON_POLICY_JUST_MEERKAT` 對 powershell.exe 啟動該 EXE 彈窗，使用者確認當時按「允許」，之後測試持續執行，本票結果仍有效但屬「防毒曾介入」的環境。昨日首次 30 秒未握手時段的行為監控紀錄已不存在，無法排除防毒干擾，05 診斷須列為變數。
