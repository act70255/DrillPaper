# RC 08：正式交付候選 trial.6，保留繞行與 RC gate

2026-10-30，分支 `feature/rc-08-delivery-finalization`，產品／SDK固定來源 `676bb473efeca65614fddb40d98e3c88c302494b`。依票內「決策（使用者確認，08 停止後）」停止追查08-D1，正式交付入口保留 `--no-smart-sleep`，缺陷與繞行移除交09。未改產品C++／智慧休眠預設，不合併main、不公開發布。implemented表示可執行交付工作及人工交接完成，**不是RC放行或所有驗收PASS**。

## 交付識別

| 項目 | 正式交付候選 |
| --- | --- |
| 版本 | **0.1.0-trial.6**；manifest kind=trial，EXE --version仍0.1.0-dev |
| ZIP | `artifacts/DrillPaper-0.1.0-trial.6-win-x64-unsigned.zip`，472421 bytes |
| ZIP SHA-256 | `FC08E190ACF481696F560CB7136478D9CF6E9DADF45E6EEF505CD62EB9EFF8A5` |
| EXE SHA-256 | `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA` |
| 產品／SDK來源 | `676bb473efeca65614fddb40d98e3c88c302494b`，包含04／05／07 |
| 清單／hash | PASS，55檔白名單＋package-manifest；[metadata](package-trial6-metadata.json)／[inventory](inventory-trial6.log) |
| 簽章 | **NotSigned**，SignerCertificate=null；[原始證據](signature.json)，不宣稱已簽章 |

沿用上一輪由git archive匯出的固定commit、MSVC19.44.35217.0 x64 Release／BUILD_TESTING=OFF建置；核實既有EXE hash後重封，未重做未變動的產品編譯。最低CRT14.44.35112.0，原建置見 `../delivery/build-probe.log`／`build-provenance.json`。產品／SDK來自固定commit，封裝工具／入口／交付README為本票工作樹，逐檔tooling hash在manifest／sidecar，不冒稱它們已包含於產品來源commit。本票唯一工具提交hash以Git記錄為準。沒有宣稱EXE／ZIP位元可重現；CI只可驗相同內容白名單與各檔hash，遠端CI NOT RUN留09。

trial.1～4、trial.5.probe與審查前候選trial.5全部保留，未覆寫。trial.5 ZIP SHA `9A917C07A4A4AD3A273429CF0A700AA7BD38577CEF25533940D9F054F6C5C590`、472371bytes；其完整原報告封存於 [REPORT-trial5-before-review](REPORT-trial5-before-review.md)。[差異清單](package-delta-trial5-to6.json)確認trial.5→6只有PS入口／CMD／README三檔改動，另52檔（包含EXE／主題／SDK）hash相同。ZIP不入Git，來源／metadata／證據與工具隨本票提交保存。

沿用03合法再散布邊界及授權：Apache-2.0、miniz、nlohmann-json、WebView2Loader授權與NOTICE；完整Evergreen／系統CRT／NVML不隨包再散布。納入07最新MockHost宣告、固定TypeScript作者範本／lockfile、schema與SDK文件／打包工具，排除Node runtime、compiler、node_modules、個人資料、profile、日誌及開發暫存。

## 入口、交付說明與 TDD

CMD先用Windows PowerShell5.1 `-CheckOnly`檢查必需EXE／loader／manifest／CMD、兩個內建主題必需資產、CRT及WebView2；成功後CMD `start`直接啟動 `DrillPaper.exe --management --no-smart-sleep`，沿用已保存模式、不強制Preview。PS入口正常啟動委派CMD。缺資產／依賴提供繁中錯誤與官方取得方式，預設雙擊失敗停留待按鍵後exit1，`-CheckOnly`非互動exit1；不下載／自動安裝／提升權限／修改防毒。

README包含安裝／功能／使用、支援目標與已測配置、外部依賴、資料與日誌、隔離、更新／替換／回復、ZIP移除與主動清除及前票限制。明列 **未簽章EXE可能被企業防毒攔截或警告**，核對可信來源ZIP／EXE hash、向IT申請例外、逐次記時間／產品版本／規則／hash／受影響步驟並列BLOCKED，不停用防毒。不宣稱主題沙箱、全程序零外連或省電驗收通過。

公開封裝與入口seam的Red→Green：

- 沿用原 `../delivery/package-red.log`→green及白名單擴充；本輪 `package-green-final.log`驗缺EXE、最新SDK、恰好白名單／私有資料排除、空檔／缺SDK／junction、拒覆寫與hash，PASS。
- 未完成的缺主題資產slice沿用 `../delivery/resources-red.log`，本輪 `resources-green-child.log`完成Green，最終 `launcher-trial6.log`再驗缺入口／CMD／loader／minimumVcRuntime及過舊CRT。第一次外層誤讀預期負面案例遺留LASTEXITCODE=1，日誌本身PASS；獨立pwsh整體exit0，未改判準。
- code-review發現PS依賴CMD卻未提前驗缺檔：`missing-cmd-red.log`→加入必要檔→`missing-cmd-green.log`。發現雙擊CMD錯誤立即消失：`cmd-message-red2.log`→失敗停留→`cmd-message-green.log`／`cmd-message-trial6.log`，真實CMD驗繁中可讀錯誤、預設待輸入及CheckOnly exit1。`cmd-message-red.log`是測試器誤用UTF8解碼OEM，非產品Red，原樣保留。
- 整合工具結果寫入增加EVIDENCE_FAILED、完整原結果／錯誤的備援日誌及繁中stderr；未對現用磁碟製造磁碟滿／ACL故障，該故障注入NOT RUN。CMD測試器逾時不讀未完成Task.Result，保留有界等待。

相關原生targets建置與 **CTest18/18 PASS**（SettingsStore／目標、protocol／runtime、ThemeManager安裝移除同版重裝、路徑／junction／禁止資產），見 `related-build-native.log`／`related-ctest-native.log`。PATH的CMake是指向已不存在Python的啟動器，`related-build.log`在編譯前失敗；改用已安裝套件的原生data/bin/cmake.exe、ctest.exe重新configure及建置成功，未重裝Python、不推定防毒根因。PS parser與差異檢查見syntax日誌；**完整套件與遠端CI依指示NOT RUN，留09**。

## 最終包 Windows 整合與保留失敗

本機Windows11 Pro25H2 build26200、Runtime156.0.4314.50、Intel Graphics、雙1920×1080／DPI144與96，有來源樹／建置工具／Apex One，**不是真正乾淨一般使用者機器**。解壓於 `C:/Users/James/DrillPaperTests/交付收尾 含空白/final-trial-6`，各情境隔離LOCALAPPDATA。產品實測循序執行，不與其他產品測試並行；原持續桌布保持運行，不當獨占效能環境。

- 審查前trial.5的真正CMD入口兩輪PASS，原結果 `final-entry-1-result.json`；不能冒稱該ZIP已包含之後修正。
- trial.6最初兩次 `final-entry-trial6-1-result.json`／`final-entry-trial6-2-result.json` **均FAIL／CLEANUP_FAILED**：首次主屏桌布／握手／取消／保存Preview資料完成，App均正式exit0，已取得handle的子程序退出；但CIM列舉後、取得handle前PID51672／496已無法取得，觀測不足。不能證實它們必屬舊宿主、不判定防毒根因、不改寫PASS；後續重啟／剩餘輪次因工具退出失敗NOT RUN。這不是08-D1的15秒退出逾時。
- 工具原本保存後立即枚舉子程序，未等待新Preview有效。新增更完整的保存驗證：總宿主數必須=1、同一HWND parent=0、ReadyEpoch>0及HealthTick>0（JS真正回應）才開始原有退出觀測。沒有放寬30秒等待／15秒退出期限或忽略未知程序；**「保存後待新Preview就緒再退出」與原立即退出是不同情境**，不是把前兩份FAIL改綠或解除08-D1。
- `final-entry-trial6-after-ready-result.json`新情境兩輪PASS；最後再採審查建議要求總數=1並記錄同一HWND，最終結果見 `final-entry-trial6-unique-ready-result.json`。最終驗證首次唯一主屏桌布實體矩形(0,0)-(1920,1080)、ReadyEpoch=1、有效休眠0／網路0、取消網路草稿、保存Preview／單目標／網路1與JS回應、同CMD重啟parent0／網路1／設定hash不改寫及Dashboard握手。這只驗保留繞行的交付情境，不是產品預設休眠回歸；精確退出與當下已核實子程序數以原result為準，不宣稱捕捉全部短命程序。
- 作者匯入移除見 `theme-final-result.json`：同EXE／主題／SDK hash，Node直接啟動、另一新資料。07可信DMT hash `82BF38D3743A3F6ADCBFCC31D754B5E776D3A3B815DFB7F49A47F83C7CEE8546`，正式CLI匯入／同版拒絕、作者↔Minimal切換、非保存命令不改設定、原生移除選「否」不變／選「是」回退Minimal與清單移除、同版重匯入／重新整理／載入PASS，exit0與6個當下核實子程序退出。檔案證據源於trial.5，其52檔相同的hash關係明列，不冒稱在trial.6重做了未受影響項。GUI選檔／真實滑鼠／人眼版面仍NOT RUN；MetricsTick只是推送，不當頁面回應證據。

原始JSON／命令列／建立及退出證據見launch-evidence；完整profile只留本機、不提交。原 `../delivery/`逐檔hash未變（prior-evidence-hashes與verify日誌），原產品預設第2輪FAIL／退出稍後exit0不改寫。08-D1與繞行移除交09；本輪沒有追查其根因或產品修正。

## 移除、資料、防毒與限制

trial.5移除前檢查PASS：本票app及profile對應WebView2退出，settings／themes／logs hash在 `data-before-removal.json`並核對不變。**實際刪除trial.5解壓目錄BLOCKED**，自動核准政策拒絕已檢查邊界及縮小到明確完整路徑的兩次刪除，只回報 `blocked by policy`；未繞過。trial.6實際刪除 **NOT RUN（同政策限制，未重複嘗試）**，主動清除資料複本／更新回復亦NOT RUN，附人工步驟。兩個ZIP／解壓目錄保留；沒有安裝器，不宣稱安裝器／解除安裝PASS。

可讀Apex One ProductVersion只取得14.0，非完整build。BM日誌在本輪早期前後27830bytes、修改14:30:45.732+08、SHA `A62A71B541E9A7617673AB177117CA76688DC4E426D3DAEAA6E3C117F57408FB`；最終收尾另見environment-final。未觀察新增攔截不等於完整觀測。UTF-16LE歷史記錄 `NON_POLICY_JUST_MEERKAT`屬前票Temp／PowerShell，不當本輪攔截；08-D1時段WinVerifyTrust失敗可能影響時序但未證實；14:32 python.exe攔截屬其他專案，不當本票產品根因。未更動防毒；任何有證據受攔截步驟須BLOCKED，與工具刪除政策分記。

前票及owner09的gate全保留：03歷史預設休眠啟動FAIL；04安全PARTIAL（完整DNS／其他Runtime／TURN／proxy／外部handler／真實舊callback競態），不保證零背景外連／沙箱；05真正Explorer／桌面互動／OS電源；06 A05／A13 PARTIAL、資源缺失／記憶體上升與不能排除洩漏、NVIDIA／更長soak；07 A10 PARTIAL、獨立作者／GUI與完整人眼版面。01／02其他DPI／解析度／拔插與離線恢復、真正乾淨無工具帳號、真實缺依賴機器、更新回復／主動清除仍NOT RUN，原因與步驟見 [MANUAL_CHECKLIST](MANUAL_CHECKLIST.md)。09需完整測試、乾淨Windows CI與對應工具提交／候選ZIP、A01～A16及RC判定；必要gate未過就拒絕放行。產品再變動須新版本重包並重測受影響部分。

## 本輪命令與交接

完整原建置／相關CTest等命令見封存trial.5報告及原delivery報告；本輪新增命令如下。所有證據與套件目的檔拒絕覆寫，重跑須新名稱，產品測試不可並行。

```powershell
pwsh -NoProfile -File scripts/package-trial.ps1 -ApplicationDirectory artifacts/trial-build-676bb473efec-4245f767154e4371a36edee9c78c218f/build/Release -SourceDirectory artifacts/trial-build-676bb473efec-4245f767154e4371a36edee9c78c218f/source -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b -Version 0.1.0-trial.6 -MinimumVcRuntime 14.44.35112.0
pwsh -NoProfile -File scripts/verify-trial-archive.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.6-win-x64-unsigned.zip -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b
pwsh -NoProfile -File scripts/test-trial-launcher.ps1 -PackageDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-trial-6"
pwsh -NoProfile -File scripts/test-trial-cmd.ps1 -PackageDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-trial-6"
pwsh -NoProfile -File scripts/test-delivery.ps1 -PackageDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-trial-6" -EvidenceDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-entry-trial6-unique-ready" -UseLauncher -Rounds 2
```

兩軸code-review見 [REVIEW](REVIEW.md)；本票唯一commit以Git為準，commit-msg依最終暫存差異產生繁中Conventional Commit後commit並push當前分支，不合併main、不公開發布。

記憶查證：Nowledge MCP thread_search query=`RC-08 08-D1 停止 交付`、limit3／無filters、server mode=full／scope default，rank1 thread096776b6-a100-48c1-825b-2c0c62b10ae0「票08：重新打包驗證與退出逾時停止點」，score34.080902099609375。另為去重memory_search同query、normal、default/strict、limit3／無filters：rank1 40df2b4e-dd9f-438b-9e38-7b4190c8327d「RC-08多輪交付驗證退出逾時，停止且未提交」score0.99；rank2 cdeed9d5-5b2b-48fe-b1dc-da1d323c9059「票08：防毒攔截測試與交付說明要求」0.5921528186212577；rank3 9e7ddaad-a7d1-4346-b707-ef69c426371e「票08：前提衝突時停止且不提交」0.546501617938136。server提示索引重建中、語意搜尋暫停、文字結果可能不完整；本輪以使用者最新確認決策為準。explore_graph工具不可用，亦無同owner/space瀏覽器身分證據，依技能略過圖，不影響查證。

最終防毒補記：environment-final顯示BM日誌45890bytes、修改14:51:46.783+08、SHA C1550D0520F87091EDB2A2BB76507B1C6B06174718843AD1C1EBD6B664DA7D88，與早期before／after不同。UTF-16LE核對新增事件 `antivirus-final-events.json`：14:51:36+08、Apex One可讀版本14.0、規則NON_POLICY_JUST_ADC，目標為另一AIPortal專案pytest／uv Python、來源為其result.xlsx，非DrillPaper目標；不能把這項當作本票產品攔截或試圖替它申請例外。該時間落在本票產品實測的間隔；本票未主動啟動其他產品實測，不能由此宣稱整台機器無背景活動。未取得完整防毒觀測，本票無已證實受防毒攔截的產品項；真正完整版本／防毒介入清單仍交人工。PATH CMake啟動器的缺Python早於此新事件，不能僅依同名目標認定其因果。

最終unique-ready結果為PASS：兩輪、四次exit0，每次核實6個WebView2 handle退出（合計24），保存後同一唯一Preview ReadyEpoch=2／HealthTick>0。原持續桌布path／UtcTicks／hash不變、本票無殘留，見environment-final。新增.gitattributes僅保留本票兩個證據目錄的原始換行位元組，避免Git autocrlf使已記錄SHA失效；不更改舊證據。
