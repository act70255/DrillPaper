# RC 08：退出觀測逾時，停止未提交

2026-10-30，分支 `feature/rc-08-delivery-finalization`；起始及停止 HEAD 均為 `676bb473efeca65614fddb40d98e3c88c302494b`。本票維持 in-progress，沒有 commit、push、合併或公開發布。依使用者「前提不成立時停止、不 commit」及多輪全部通過才移除入口繞行的決策停止；不是完成的交付候選包。

## 停止點與缺陷 08-D1

用新建置套件、非 Temp 使用者繁中／空白路徑、全新隔離 LOCALAPPDATA、Node 直接啟動 `DrillPaper.exe --management`，沒有 `--preview` 或 `--no-smart-sleep`。計畫三輪，每輪首次主螢幕桌布、取消草稿、保存 Preview、正式退出、同入口條件重啟 Preview及 Dashboard 握手。

- 第 1 輪首次桌布 PASS：唯一宿主、主螢幕實體矩形 `(0,0)-(1920,1080)`、ReadyEpoch=1、智慧休眠勾選=1、網路=0；取消網路草稿、保存 Preview／單一目標成功。正式退出 0，當下持有的 6 個 WebView2 子程序 handle 全部退出。
- 第 1 輪重啟 Preview PASS：parent=0、ReadyEpoch=1、智慧休眠=1、網路=0、設定 hash 未被啟動改寫；Dashboard 握手通過。正式退出 0，另 6 個已觀察子程序退出。
- 第 2 輪首次桌布完成相同幾何、握手、取消與保存檢查，但後續正式退出 **超過工具既有 15 秒觀測期限**，結果 `CLEANUP_FAILED`，整體 `FAIL`。第 2 輪 Preview 及第 3 輪 NOT RUN，原因是停止規則。
- 已開待釐清缺陷 **08-D1：保存 Preview 後正式退出超過觀測期限**。本次未留獨立命令送出時間或逾時當下堆疊，不能精確推算退出耗時，也不能判定產品根因。Node 的退出證據顯示此 app 於 `14:25:35.608+08:00` 自行以 **0** 退出；工具已於 `14:25:28.865+08:00` 保存失敗。因此不是持續卡死的證據，也不能把後來退出改寫為該輪 PASS。後續須先補可重現的退出時間線／失敗回歸，再決定產品或工具修正；不能單純放寬期限抹除本輪。

結果見 [原始摘要](default-rounds-result.json)、[日誌](default-rounds.log)、[退出原始檔](launch-evidence/round-2-desktop-launch-63e8118180fb4f4299c2bf6acff5ba60.json.exit.json)。第 1 輪與第 2 輪啟動／精確身分／退出原始 JSON 均在 `launch-evidence/`。03 的歷史啟動未握手 FAIL 未由本輪重現，也未解除；本次開的是退出觀測缺陷，不推測是智慧休眠或防毒造成。

`--no-smart-sleep` 仍保留在試用入口。未改產品 C++、休眠預設或現有 trial.1～4；未產出最終 trial.5、未跑最終入口。探針解壓副本的 PS 檢查器後來只為缺資產測試換入未提交版本，故該解壓目錄不再逐檔等於原 ZIP；本輪產品測試直接啟動 EXE，EXE 未替換，封存 ZIP 未修改。

## 來源、套件與已完成檢查

固定 commit 由 `git archive` 匯出後，獨立 CMake MSVC x64 Release／BUILD_TESTING=OFF 建置。來源祖先包含 04 `2a69ed1`、05 `c244682`、07 `f295106`。最新 SDK／MockHost 宣告、固定 TypeScript 作者範本與 lockfile、schema／文件／作者打包工具納入白名單；作者 compiler／node_modules、個人設定、profile、日誌及開發暫存不入包。沿用 03 授權檔與再散布邊界；完整 Evergreen、系統 CRT、NVML 不隨包提供。

| 項目 | 本輪證據 |
| --- | --- |
| 產品來源 | `676bb473efeca65614fddb40d98e3c88c302494b` |
| 探針版本 | `0.1.0-trial.5.probe`，僅調查用，不是完成交付或 RC |
| ZIP | `artifacts/DrillPaper-0.1.0-trial.5.probe-win-x64-unsigned.zip`，471313 bytes |
| ZIP SHA-256 | `EB6A3ABF5FBDB913A336BD8B215F32350918422E1FBBA16E446F96DE759F89FC` |
| EXE SHA-256 | `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA` |
| 封裝來源 | 產品／SDK為固定 commit；打包工具／啟動說明為本票當時工作樹，逐檔 tooling hash 見 sidecar，不冒稱全部屬於來源 commit |
| 清單／逐檔 hash | PASS，55 檔白名單＋package-manifest，見 [metadata](probe-package-metadata.json)／[驗證](probe-inventory.log) |
| 建置 | PASS，[完整日誌](build-probe.log)／[工具鏈與最低 CRT](build-provenance.json) |
| 相關 CTest | PASS 18/18，[建置](related-build.log)／[結果](related-ctest.log)，不代表人工／乾淨環境 |

這次建置與 05 的 EXE hash 不同，不宣稱 EXE 或 ZIP 位元可重現。新增 CI 驗證步驟可驗相同白名單結構、來源及逐檔 hash；遠端 CI NOT RUN，不能把草稿當已驗收。ZIP／EXE／來源的關係可追溯；本票工具 hash 後續有變更時必須重包，不能沿用探針為最終證據。

公開封裝 seam 的 TDD：原白名單缺少 `sdk/javascript/mock-host.d.ts` 等最新作者資產，測試先 [Red](package-red.log)；補白名單後 [Green](package-green.log)，且既有缺 EXE／SDK、空檔、junction、私有設定排除、拒絕覆寫與 hash 檢查通過。

必要主題入口缺失的 CheckOnly 測試先 [Red](resources-red.log)。已補繁中提前拒絕草稿，但第一次 [綠測嘗試](resources-green.log) 因舊 fixture 未帶 resources，先觸發新增資源檢查而非 minimumVcRuntime 分支，整個測試仍 FAIL。fixture 已補 resources，**重跑 NOT RUN**（此時多輪整合已失敗，依停止規則不繼續）。不能聲稱此 slice 完成或整票綠燈。沒有執行全套測試；完整套件按指示留 09。

## 環境、防毒與清理

Windows 11 專業版 build 26200，WebView2 156.0.4314.50，SDK 1.0.2478.35；MSVC 版本／CRT最低值見 provenance。Intel Graphics。本機有來源樹、建置工具與 Apex One，不是乾淨一般使用者機器。測試目錄 `%USERPROFILE%/DrillPaperTests/交付收尾 含空白/`，各輪使用自己的 `appdata`。`security-process.ps1` 經 Node 直接 spawn EXE，PowerShell只觀測與控制 Node，未透過 PowerShell直接啟動產品 EXE。

[前](environment-before.json)／[後](environment-after.json) Apex One可讀行為日誌均 8332 bytes、最後修改 `2026-10-30T09:22:30.9964599+08:00`、SHA `0B6BE9A504AAC9279EB2E3852B84CF8371DCFC5031142CB76635FE0FD1C59A2E`。本次僅取得程序檔案 ProductVersion `14.0`，非完整產品 build；未觀察新增攔截，**不是完整防毒觀測**。沒有已證實受攔截項目，退出逾時不冒稱防毒 BLOCKED；若後續取得攔截，逐次記錄產品／版本、規則、時間與影響項目，改列 BLOCKED，不修改防毒設定。

收尾查詢只剩原持續桌布 PID 83428，path、精確 UtcTicks `639288432499803524`、hash與前相同；未關閉／替換、未重啟 Explorer。測試 app 已自行退出；當下依隔離 profile 路徑查詢無剩餘 WebView2，不宣稱已取得所有短命子程序或完整歷史 handle。第二輪退出逾時後未強制終止程序。

## 前票盤點與交接

| 票 | 承接結果與保留 gate |
| --- | --- |
| 01／02 | 多目標／800×600設定已實作；本輪只驗單一主屏及取消／保存。其他 DPI／解析度／拔插與完整人工版面 NOT RUN |
| 03 | trial.1～4及原FAIL原樣保留；本輪多輪條件尚未全過，不移除繞行 |
| 04 | 新包含SmartScreen設定修正；完整DNS／其他Runtime／TURN／proxy／外部handler／真實舊callback競態仍PARTIAL／NOT RUN。WPAD／Edge ECS背景流量限制不隱藏，不能宣稱整個程序零外連或第三方主題已沙箱化 |
| 05 | 新包含有界JS無回應復原；真正Explorer／桌面互動／OS電源等人工清單保留。本次不判定原啟動缺陷重現；新增08-D1待釐清 |
| 06 | A05／A13 PARTIAL：三筆資源缺失，長測記憶體仍上升；有限門檻通過不保證無洩漏。NVIDIA／真正電源／其他網路與更長soak仍NOT RUN |
| 07 | SDK資產已納入；A10仍PARTIAL，GUI匯入／確認移除／重匯入及完整視覺、乾淨無Node機器／獨立瀏覽器仍NOT RUN |
| 08／09 | 最終入口／交付README（含未簽章防毒處理）、匯入／移除、完整目標與網路保存、停止後移除套件／資料保留、更新替換回復、真正乾淨機器均未完成；完整套件／遠端CI／最終重包／code-review／commit-msg／commit／push均NOT RUN，原因是本輪前提未達且依指示停止 |

交付說明的必要待補內容：**未簽章 EXE 可能被企業防毒攔截或警告，核對可信來源及來源 hash，向 IT 申請例外，不自行停用防毒、不宣稱已簽章。** 本次探針README仍為舊試用說明，不能作為完成的交付文件。沒有安裝器，後續只能驗證ZIP移除流程，不宣稱安裝／解除安裝通過。人工逐項步驟見 [MANUAL_CHECKLIST](MANUAL_CHECKLIST.md)。

## 命令與接續

```powershell
pwsh -NoProfile -File scripts/test-trial-package.ps1
pwsh -NoProfile -File scripts/build-trial.ps1 -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b -Version 0.1.0-trial.5.probe
pwsh -NoProfile -File scripts/verify-trial-archive.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.5.probe-win-x64-unsigned.zip -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b
cmake --build --preset windows-msvc-release --target DrillPaperTests DrillPaperSettingsTests DrillPaperThemeTests --parallel 8
ctest --preset windows-msvc-release -V -R '^(Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause|Protocol v1 |Power state|Sampling scheduler|DrillPaperThemeTests$)'
pwsh -NoProfile -File scripts/test-delivery.ps1 -PackageDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/probe-package" -EvidenceDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/default-rounds"
pwsh -NoProfile -File scripts/test-trial-launcher.ps1 -PackageDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/probe-package"
```

證據目錄不可覆寫；接續請用新名稱，完整profile留本機不提交。先釐清08-D1並取得可重現回歸，未獲續作決策前不改產品或放寬判準、不移除繞行。產品若變動須新版本重建並重測受影響部分；最終仍只一次commit＋push，不合併main、不公開發布。

記憶查證：Nowledge MCP thread_search，query=`DrillPaper RC-08 交付 2026-10-30 繞行`，mode由server回傳`full`、結果0；另memory_search query=`RC-08 delivery finalization 退出觀測 15秒 trial.5.probe`、scope default／strict、limit3、無額外filters，結果0且server回報search_index_rebuild_pending，語意搜尋暫停／文字比對可能不完整。本輪以票內全部確認決策及03～07交接文件為準，沒有記憶結果需呈現圖。
