# RC 整合回歸與放行判定

Status: resolved
Type: task
原討論編號：8
Blocked by: 01, 02, 03, 04, 05, 06, 07, 08

## Scope

對 08 提供的實際候選套件完成整體回歸與 A01～A16 判定；核對來源、CI、套件及各實機證據的版本一致性。判定可放行與實際公開發布分開，本票不授權自動發布或合併 main。

## Acceptance

- 核對 01～08 的 Status／Comments、遺留缺陷與不可測環境；未結問題有 owner／下一步與 gate 影響，不將 implemented／resolved 當作所有組態 PASS。
- 最終來源執行 Release configure／build、完整 scripts/test.ps1、CTest／SDK／封裝相關檢查；檢查測試確實被執行，記錄實際數量，不預設永遠是 33／18。
- 核對對應提交的乾淨 Windows CI，包含依賴還原、建置、測試及 app artifact；檢查 gate 失敗能阻止正式 RC，不能把 skipped 當 PASS。
- 對 08 的解壓套件執行整合冒煙與必要原生／人工回歸；03～08 的結果若產品版本不同，明示差異並重測受影響範圍。
- 更新 A01～A16、STATUS、FINAL_HANDOFF、相容性／安全與已知限制文件，將 PASS／FAIL／PARTIAL／NOT RUN／BLOCKED 對應到版本／環境／命令／證據。
- 必要功能與 gate 有 FAIL 或尚缺必要證據時明確拒絕放行並建立追蹤；先前試用包仍只能按限制試用，不以文件或 CI 綠燈取代實機證據。
- 所有必要 gate 通過時才記錄 RC 可交付判定、候選 commit／ZIP hash、限制與後續發布步驟。程序清理只針對已確認的測試實例，原持續桌布保持不動。

## Comments
- 2026-10-30 收尾判定：**拒絕 RC 放行**；resolved 只表示本票可自動執行回歸、判定與人工交接完成。沿用 feature/rc-09-regression／base d60816a，保留本票既有確認決策；沒有產品 C++／SDK 修正、沒有合併 main、公開發布或 release／tag。完整證據見 `docs/acceptance/2026-10-30/rc-regression/REPORT.md`。
- 測試鏈：主題 CLI 改 Node 直接啟動／JSON傳參與UTF-8結果，六項原斷言及15秒期限不變；完整 test.ps1 與獨立 CTest 的 TEMP／TMP導向非Temp使用者繁中空白目錄。新工具 Red→Green、相關CTest5/5；最終來源Release configure／build與完整公開封裝入口實際呼叫 test.ps1，CTest43/43、SDK18/18（封裝鏈共四組18，非72獨立案例）、新工具6/6、另既有工具17/17及SDK／主題／封裝正負檢查通過。正式package gate預期exit1且無RC ZIP。
- trial.6 ZIP SHA FC08E190…9EFF8A5不變；同EXE產品預設三輪不等待新Preview就緒的退出及三輪待就緒／JS回應均PASS，08-D1未重現但原FAIL不改寫、未宣稱根因修復。依08已確認的本機多輪條件，入口契約Red後移除新CMD的--no-smart-sleep、另包trial.7（472507bytes、ZIP SHA87FE10E27EB016D144F8C775BEEA4C81C724BD513BDDE61DE9F866465FDBC29D）；53檔及EXE／SDK／主題與trial.6相同，只改CMD／README與manifest。真正CMD入口再三輪／六次exit0與當下核實子程序退出PASS，既有保存偏好不改寫。03／08原FAIL永久保留。
- 候選安全三份NetLog零SmartScreen POST／零送出bytes、基本多目標原生矩陣／fixture、固定TypeScript5.9.3正負compiler／作者建置與包內打包、正式CLI／原生移除及重匯入PASS（非人眼／真實OS證據）。**09-D2 FAIL**：擴充雙目標受控鎖定往返後解除手動暫停，兩宿主沒有在原期限恢復新MetricsTick，原因未定；票10（owner James／原生runtime與測試維護）承接實際電源／有效狀態／通知時間線、可重現Red與最小修正，不放寬判準。該次未到達的擴充故障／無限迴圈等NOT RUN，基本矩陣另PASS不覆蓋FAIL。
- CI只查核既有遠端：最新40849189915為舊main b4616ec，CTest33／SDK18、依賴還原／建置PASS，RC job skipped、artifact只有SDK範例；不當本票來源或app CI。必要相符來源CI／app artifact、真正OS／人工／安全剩餘／NVIDIA／長測／乾淨使用者／更新回復／實際移除等缺證，票11（owner James／發行維護者）依GATES與人工清單補證；必要FAIL或缺證任一存在就拒絕放行。06資源缺失／記憶體仍升、07A10 PARTIAL及08移除政策BLOCKED保留。
- 防毒／清理：可讀Apex One BM前後45890bytes／hashC1550D…A7D88未變，未觀察新增事件但非完整觀測，未知原因不自動標防毒BLOCKED。原持續桌布83428路徑／精確UtcTicks／hash前後相同，沒有本票app／profile對應WebView2殘留，未重啟Explorer。證據複製漏篩round-n/appdata的本次隔離profile；自動核准審查拒絕刪除，只回報blocked by policy，工具清理BLOCKED，保留本機並以精確gitignore排除，不改方法刪除或提交profile。人工清單、A01～A16與版本限制文件已更新；依implement做兩軸code-review後，commit-msg產生繁中訊息、本票唯一commit並push此分支，hash以Git記錄為準。

- 2026-10-30 決策（使用者確認）：完整測試鏈中 CTest `DrillPaperThemeCli`（`CMakeLists.txt` 經 powershell.exe 執行 `scripts/test-theme-cli.ps1`，以 Start-Process 啟動 EXE、資料放 %TEMP%）與 spec 2026-10-30 防毒決策衝突。本票先修改測試再跑完整回歸：把 `DrillPaperThemeCli` 及完整測試鏈（`scripts/test.ps1`／CTest）中其他經 PowerShell 啟動 DrillPaper.exe 或把 EXE／測試資料放 Temp 的同類測試，改為非 Temp 使用者目錄（例如 `%USERPROFILE%\DrillPaperTests\<含空白與繁中的子目錄>`）並以 cmd 或 Node 直接啟動 EXE。測試的判準與覆蓋不得放寬；修改前後同一測試的斷言應等價，並以相關測試證明。完成後再跑完整回歸，仍有攔截則記錄並標 BLOCKED。

- 2026-10-30 07傳遞：SDK固定TypeScript5.9.3正負編譯／獨立ZIP作者建置、正式包內工具封裝、Preview／雙目標SDK與DOM／指定HTTP及HTML管理拒絕已有版本化證據；A10仍PARTIAL，人工GUI／完整版面／乾淨使用者與其他OS／完整安全邊界NOT RUN，見 `docs/acceptance/2026-10-30/theme-author-flow/REPORT.md`／`MANUAL_CHECKLIST.md`。SDK ZIP與app08交付分記；本票需完整回歸，保留03歷史FAIL及既有RC gate。

- 2026-10-30 06傳遞：06 resolved只代表可執行矩陣與報告完成，非A05／A13全部PASS。五組664筆（3筆資源／6個CPU區間排除），長測1805.80秒、暫停相對同主題雙目標CPU下降86.82%；硬體三負載各30同期窗口達容差。NVIDIA、真正Locked／DisplayOff／睡眠／全螢幕、高流量／介面消失、逐次collector頻率、其他環境、更長soak／100次切題與探針因果增量仍NOT RUN，見 `docs/acceptance/2026-10-30/metrics-performance/REPORT.md` 與人工清單。只跑相關CTest18＋1及工具12；完整套件／CI／候選包仍由本票收尾。保留3筆缺失、記憶體上升及03歷史FAIL，不因06結案放行。

- 2026-10-30 03 傳遞：**預設智慧休眠啟動＝FAIL**，根因未定，05 負責失敗回歸／診斷／最小修正；08 必須移除 7A 的 `--no-smart-sleep` 繞行並以產品預設重包重驗。03 關閉智慧休眠的入口驗收只適用試用包，不代表產品預設或 RC gate 通過。核對 05／08 對應版本及新證據前持續列 gate，原失敗見 `docs/acceptance/2026-10-29/trial-package/REPORT.md`。
- 2026-10-29：首次打包不代表本票完成；完整回歸／CI／最終套件與放行判定 NOT RUN。
