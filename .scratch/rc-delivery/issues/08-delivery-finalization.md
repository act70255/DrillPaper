# 7B：交付收尾與重新打包

Status: implemented
Type: task
原討論編號：7B
Blocked by: 07

## Scope

沿用 03 的打包腳本，納入 04～07 修正並完成乾淨一般使用者交付。檢視 01～07 的未結項，製作提供 09 驗證的候選套件，不因已有 ZIP 自動標記 RC。

## Acceptance

- 盤點前票 FAIL／PARTIAL／NOT RUN、缺陷及限制；必要安全或產品缺口未解決時明列 gate，不能只改狀態或移除檢查。
- 打包明確來源 commit 的 Release，檢查資產／合法再散布依賴／授權／版本／hash，排除個資與開發暫存；CI 可重現生成或驗證相同內容清單。
- 在無來源樹與建置工具的乾淨一般使用者環境，驗證解壓／使用說明、依賴可用與缺失、啟動、內建主題、匯入／移除、保存／取消／重啟、目標與網路偏好、系統匣及退出。
- 說明支援的 Windows／Runtime／顯示配置、資料與日誌位置、更新／替換／回復方式及剩餘限制。缺依賴與必填資源 fail-fast 並顯示友善錯誤。
- 驗證停止 app 後可移除套件檔案；使用者設定／主題／日誌的保留與主動清除方式明確，不自動刪除其他資料。若交付形式含安裝器，另驗證安裝／解除安裝；未提供則明示 ZIP 移除流程，不宣稱安裝器已通過。
- 保存乾淨環境證據、來源 commit／EXE／ZIP SHA-256 與封裝清單，交給 09；產品再變動必須重建套件並重測受影響部分。
- 7A 試用包保留自己的版本與結果，不覆蓋成最終版證據；本票不包含自動公開發布或簽章完成聲明。

## Comments

- 2026-10-30 接續交付完成（依08停止後確認決策）：沿用feature/rc-08-delivery-finalization／base676bb473efeca65614fddb40d98e3c88c302494b、原未提交工具與乾淨Release建置；未改產品C++。新正式交付候選0.1.0-trial.6，ZIP472421bytes／SHAFC08E190ACF481696F560CB7136478D9CF6E9DADF45E6EEF505CD62EB9EFF8A5，EXE993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA，55檔白名單＋manifest／hash PASS；trial.1～4／trial.5.probe與原delivery證據未覆寫。保留入口--no-smart-sleep，由CMD檢查後直接啟動；交付README補未簽章EXE防毒警告、核對hash／IT例外與資料／更新回復／移除。缺主題資產fail-fast Red→Green補完，封裝負面及最終入口檢查PASS；相關CTest18/18、兩輪最終CMD入口（取消／保存Preview／網路／目標／重啟／雙主題、保存後唯一新Preview握手／JS回應、四次exit0及各6個核實子程序退出）、CLI匯入／同版拒絕、原生取消與確認移除／Minimal回退／同版重匯入及exit0 PASS。PATH CMake缺Python啟動器的失敗保留，使用既有原生CMake建置／測試通過，未安裝Python或變更防毒。原第2輪FAIL不變、08-D1及繞行移除交09，本票不追根因／不放行RC。實際刪除trial.5解壓目錄被自動核准政策兩次拒絕，BLOCKED；trial.6同政策限制未再嘗試，NOT RUN；移除前程序已退出／資料hash不變，主動清除／更新回復／真正乾淨機器及GUI人眼項NOT RUN附人工清單。Apex One早期可讀BM fingerprint不變；最終新增14:51:36另一AIPortal專案pytest／Python的NON_POLICY_JUST_ADC攔截已獨立記錄，未觀察本票產品攔截但非完整觀測；原持續桌布精確身分／hash不變，未重啟Explorer。Status implemented表示可執行交付與人工交接完成，不等於必要gate全部PASS。新證據docs/acceptance/2026-10-30/delivery-final/REPORT.md及MANUAL_CHECKLIST.md；完整套件／乾淨Windows CI／A01～A16與RC放行留09，不合併main／公開發布。code-review結果與本票唯一commit／push以STATUS及REVIEW／Git紀錄為準。 審查Standards初2項加複查1項、Spec1項均修正，兩軸未解決0；缺CMD與雙擊錯誤停留補Red→Green，包內資產改動另產trial.6，審查前trial.5原包與metadata／報告保留，差異僅入口PS／CMD／README三檔。trial.6先前兩次在CIM後無法取得短命子程序handle，工具FAIL／CLEANUP_FAILED保留（App均exit0，非08-D1）；工具補上保存後唯一新Preview完成握手及JS回應的情境，再兩輪PASS，不與立即退出情境混同，不放寬期限／忽略未知程序。

- 2026-10-30 停止／未提交：新固定來源 `676bb473efeca65614fddb40d98e3c88c302494b` 的 Release／最新SDK探針 `0.1.0-trial.5.probe` 已建置，ZIP SHA `EB6A3ABF5FBDB913A336BD8B215F32350918422E1FBBA16E446F96DE759F89FC`、EXE `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`；不是最終交付或RC。相關CTest18/18、白名單55檔與hash、封裝負面Red→Green PASS。產品預設隔離多輪第1輪首次主屏桌布／Preview重啟／Dashboard／正式退出PASS，第2輪首次桌布及保存Preview後正式退出超過工具15秒期限，CLEANUP_FAILED；Node稍後記錄14:25:35.608+08:00自行exit0，原因未定，不能把後來退出改寫成整輪PASS。開啟08-D1「保存Preview後退出觀測逾時」待釐清，未證實原03啟動未握手重現，不判定防毒根因。多輪全通過前提未達，依使用者停止規則維持in-progress、不commit／push、保留入口`--no-smart-sleep`，未改產品C++或覆寫trial.1～4。其餘第2輪重啟／第3輪、最終入口／重包／交付說明、匯入移除／套件移除、code-review等NOT RUN；缺主題資產fail-fast測試slice尚未完成，工作樹草稿保留。完整限制、命令、退出時間線與原始證據見 `docs/acceptance/2026-10-30/delivery/REPORT.md`，人工清單見同目錄MANUAL_CHECKLIST。可讀Apex One日誌fingerprint前後相同，未觀察新增攔截，非完整觀測；收尾原持續桌布path／精確建立時間／hash不變，無本票app／profile對應WebView2殘留，未重啟Explorer。09須承接既有gate及08-D1，完整套件留09。

- 2026-10-30 執行需求／方案：base `676bb47`，從目前 HEAD 建 `feature/rc-08-delivery-finalization`。沿用 03 明確來源 Release／白名單，補最新 SDK 作者資產與清單驗證；產品來源固定為本票起始完整 commit，交付工具／說明另記逐檔 hash，未提交來源不冒稱已在 base。先用新套件於非 Temp 使用者繁中空白目錄、全新隔離 LOCALAPPDATA、Node 直接啟動 EXE，三輪各驗首次主螢幕桌布／預設智慧休眠握手、保存 Preview／重啟；全部通過才移除入口繞行並驗最終入口。沿用公開封裝／SDK、SettingsStore 及 Win32 整合 seam，新增封裝行為先 Red→Green；不改產品 C++、不虛構既有保護的 Red。交付說明補未簽章防毒、資料／更新／回復／移除與前票 gate；CI 可驗同內容清單，不宣稱位元可重現。真正乾淨機器／人工項 NOT RUN 附清單，攔截項 BLOCKED；完整套件留 09。完成後 code-review 兩軸、更新票／STATUS、commit-msg 後唯一 commit＋push；衝突或前提不成立停止不提交。

- 2026-10-30 07傳遞：固定TypeScript作者範本、SDK宣告／MockHost limits修正及SDK ZIP／正式包內工具、Preview／雙目標DOM與指定協定／HTTP驗證完成；07 implemented，A10仍PARTIAL。獨立SDK ZIP不是app交付，需納入最新SDK資產後重建本票app包；GUI匯入／確認移除重匯入、完整版面與乾淨帳號／無Node機器等NOT RUN，見 `docs/acceptance/2026-10-30/theme-author-flow/REPORT.md`／`MANUAL_CHECKLIST.md`。原03／04／05／06gate保留，不由作者驗證移除入口繞行或放行RC。

- 2026-10-30 06傳遞：新版c244682／EXE25316B…6D26D完成五組固定狀態效能矩陣（含1805.80秒長測）與三負載各30同期硬體窗口；觀測門檻達標，但3筆資源缺失已排除、Private Bytes仍上升，A05／A13整體仍PARTIAL。真正OS／NVIDIA／高流量等NOT RUN與逐項清單見 `docs/acceptance/2026-10-30/metrics-performance/REPORT.md`／`MANUAL_CHECKLIST.md`。06未改產品程式或重包，不能把本機有限觀測當乾淨環境／無洩漏／RC通過；本票須承接缺口及05／03的產品預設握手前提，不據此移除繞行。

- 2026-10-30 03 傳遞：7A 試用入口暫帶 `--no-smart-sleep`、沿用保存模式；app 本身智慧休眠預設不變。「預設智慧休眠啟動」仍為 **FAIL**，由 05 診斷／修正。本票須核對 05 結果、移除入口繞行，回到產品預設行為重新打包並驗證首次桌布主螢幕與保存 Preview 重啟；不能用關閉智慧休眠的 7A PASS 解除 FAIL。沿用 03 的白名單／腳本，保留 trial.1～4 的獨立版本證據，見 `docs/acceptance/2026-10-29/trial-package/REPORT.md`。
- 2026-10-29：使用者指定驗證後再做一次交付打包，與 03 共用流程。乾淨環境／套件驗收 NOT RUN，RC gate 保留。
- 2026-10-30 決策（使用者確認，08 停止後）：不再追 08-D1。正式交付包保留入口 `--no-smart-sleep` 繞行並列為已知限制，完成本票其餘交付範圍（最終重包、交付說明含未簽章防毒處理、匯入／移除、保存／取消／重啟、套件移除與資料保留、清單／hash 等）後 commit。08-D1「保存 Preview 後正式退出超過 15 秒觀測期限」與繞行移除一併交給 09；第 2 輪結果照實保留為 FAIL，不改寫。補記：08-D1 時段（14:23:49～14:25:28）Apex One 即時掃描正對多個未簽章 DrillPaper.exe／WebView2Loader.dll 記錄 WinVerifyTrust 失敗，並與本票其他封裝測試並行，可能影響退出時序，但未證實。使用者於 14:32 看到的 Apex One 攔截是另一專案的 python.exe（規則 `NON_POLICY_JUST_ADC`，未授權檔案加密），與本票無關。
- 2026-10-30 決策（使用者確認）：本機不是乾淨環境（有來源樹、建置工具與 Apex One），不等真正乾淨機器才處理繞行。以本票重建的套件在本機非 Temp 使用者目錄（含空白與繁中）、全新隔離 LOCALAPPDATA、不經 PowerShell 啟動，用產品預設（智慧休眠開啟、無 `--no-smart-sleep`）多輪驗證啟動握手、首次桌布主螢幕與保存 Preview 重啟皆通過後，即移除試用／交付入口的 `--no-smart-sleep` 繞行，取代 05 決策中「乾淨環境通過後才移除」的前提。若任一輪失敗則保留繞行、重開缺陷並依 TDD 處理。真正乾淨一般使用者機器的驗證標 NOT RUN，附人工清單交給 09。
- 2026-10-30 決策（使用者確認）：03 驗證時 Trend Micro Apex One 行為監控曾攔截未簽章 DrillPaper.exe（使用者按允許）。交付說明須列明「未簽章 EXE 可能被企業防毒攔截或警告」及處理方式（向 IT 申請例外、確認來源 hash），不宣稱簽章完成；乾淨環境驗證時記錄防毒產品／版本與每次攔截。
