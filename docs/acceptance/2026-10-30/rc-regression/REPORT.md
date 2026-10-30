# RC 09 整合回歸與放行判定

2026-10-30，沿用 `feature/rc-09-regression`，base `d60816aff6e99ad1a3624075a74016909f76fa4d`。**拒絕 RC 放行**：09-D2 受控解除暫停回歸 FAIL，且必要 CI／安全／實機／乾淨使用者證據不足。09 resolved 僅表示完成可自動執行的收尾、結果與人工交接；沒有合併 main、公開發布、release 或 tag。後續 [票10](../../../../.scratch/rc-delivery/issues/10-controlled-resume-regression.md)承接新缺陷、[票11](../../../../.scratch/rc-delivery/issues/11-rc-gate-evidence.md)承接剩餘必要 gate，完整 owner／下一步見 [GATES](GATES.md)。

## 執行依據與版本

已讀票 09 最新確認決策、01～08 的 Status／Comments、spec 防毒決策、handoff／架構與 STATUS、08 delivery-final 及原 delivery 報告。既有票 09 的使用者決策修改保留。需求／方案先記於 [REQUEST](REQUEST.md)，沿用已確認 CLI／ThemeManager、SDK／protocol、Settings／runtime 及 Windows 整合 seam，不需重新要求已給的批准。

| 來源／產物 | 身分與本輪用途 |
| --- | --- |
| 產品／SDK | 固定 `676bb473efeca65614fddb40d98e3c88c302494b`；本票 src／include／sdk 沒有差異，不做推測性產品修正 |
| 最終本機 Release | 工作樹 CMake／測試修正，MSVC19.44.35217，EXE SHA `25316B5067076749295B62DB557748B6DC2D88C4069CFBBE4C48E93269F6D26D`；完整 CTest 使用此建置 |
| 08 候選 trial.6 | 原 ZIP 472421bytes，SHA `FC08E190ACF481696F560CB7136478D9CF6E9DADF45E6EEF505CD62EB9EFF8A5`，不覆寫；工具提交 d60816a，產品／SDK來源另記，入口仍帶繞行 |
| 候選整合 EXE | trial.6／trial.7 均 SHA `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`；沿08獨立 git archive Release 位元，與本機建置不冒稱同一 hash |
| 09 後續 trial.7 | `artifacts/DrillPaper-0.1.0-trial.7-win-x64-unsigned.zip`，472507bytes，SHA `87FE10E27EB016D144F8C775BEEA4C81C724BD513BDDE61DE9F866465FDBC29D`；53檔與trial.6相同，僅 CMD／README 及 manifest 變更；仍是試用，不是 RC |

[candidate.json](candidate.json)、[trial7 metadata](trial7-metadata.json)、[逐檔差異](trial6-to7-delta.json)及 inventory 日誌保存來源與 hash。最終可執行來源／工具以本票唯一 Git 提交及 source-fingerprints.json 識別，未提交時不冒稱已有提交 hash；產品／SDK 與工具來源分記。兩個 ZIP 均 NotSigned，不宣稱簽章或 EXE／ZIP 位元可重現。新包沿用08固定來源的未變動產品位元，本票已另完成最終來源 configure／build，沒有把重封稱為重新編譯。

本機 Windows11 Pro25H2 build26200.8737、WebView2 Runtime156.0.4314.50／SDK1.0.2478.35、Intel Graphics、雙1920×1080（DPI144／96）、一般使用者與 Apex One；有來源與建置工具，不是真正乾淨機器。非 Temp 使用者繁中空白目錄、全新隔離 LOCALAPPDATA、Node／CMD 直接啟動 EXE，產品實測循序執行。環境、持續桌布與防毒指紋見 environment-before／after。最終完整鏈的SDK重封SHA為 `E44D5CC58EEB8FC3B6C1C6C37B9942119F55FA9988C5BD241B20FD1EFE98ED19`；原15:50基線為30FD2F…E427，安全文件更新使輸入不同，兩者均各自重封一致，不混稱相同套件。

## 測試鏈修正與等價性

完整 scripts/test.ps1 將 TEMP／TMP 設為新建 USERPROFILE/DrillPaperTests/回歸 含空白/full-suite-GUID，finally 還原；其封裝、oracle 及採樣器的 GetTempPath 均繼承此路徑。獨立 CTest 經 CMake TEST_INCLUDE_FILES 載入 ctest-workspace.cmake，亦將 TEMP／TMP 指向使用者繁中空白目錄，涵蓋原生 settings／theme fixture 的 std::filesystem::temp_directory_path；不需修改產品 C++。USERPROFILE 缺失 fail-fast，不靜默退回本機 Temp。

主題 CLI 使用 JSON 請求／UTF-8 結果檔，由 Node spawnSync（shell=false）直接啟動 EXE；Windows PowerShell5.1 只協調，不重新 shell 解析路徑或參數。每次原15秒期限、CTest原60秒期限均不變。以下六項原斷言全部保留，僅移除給 shell 的外層路徑引號：

1. 含空白／繁中路徑的 .dmt 匯入 exit0 且輸出 cli-test@1.0.0。
2. 列舉 exit0 且包含該版本。
3. 相同版本重複匯入須非零，不可覆蓋。
4. 缺少 LOCALAPPDATA 須非零，不可靜默回退。
5. 缺少匯入來源參數須非零。
6. junction 安裝路徑須拒絕，且 outside 目錄不可被日誌寫入。

TDD：launcher-red.log（未實作公開啟動器）→ launcher-green.log；workspace-red.log（未實作非Temp工作目錄）→ workspace-green.log。額外既有保護不虛構 Red：原始參數／父 Node／UTF-8 stdout及stderr／非零退出、缺設定隔離及真正15秒 timeout 初輪共4/4；審查補CLI缺USERPROFILE的友善錯誤／詳細日誌及安全證據拒覆寫回歸後，最終共6/6。CLI 於最終本機與候選 EXE 均通過，相關 CTest5/5，完整43/43。沒有降低斷言或把未知防毒影響吞掉當 PASS。審查入口Red→Green見cli-entry-red-script／green與security-entry-red／green；cli-entry-red.log僅PowerShell宿主因啟動時缺USERPROFILE失敗，未到腳本，不作入口Red。兩組trial.6預設資料取自加入ExpectedLauncherSmartSleep欄位之前的工具；此參數僅影響UseLauncher，直接啟動固定預期休眠1的判準不變，原JSON不改寫。

## 最終來源完整自動檢查

PATH 的 CMake Python 啟動器已失效，依08已知方式直接使用既有 `C:/Users/James/AppData/Roaming/uv/tools/cmake/Lib/site-packages/cmake/data/bin` 原生工具；未重裝 Python 或變更系統依賴。

| 命令／範圍 | 實際結果與數量 | 證據 |
| --- | --- | --- |
| scripts/build.ps1 -Configuration Release | PASS：Release configure＋所有 targets build | release-build.log |
| scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1，實際呼叫 build.ps1／完整 test.ps1 | 全部測試完成後在正式 gate 預期 exit1；目的地未建立、無正式 RC ZIP | final-full-suite-command.json、final-full-suite-and-gate.log／result.json（原 full-suite-* 保留基線） |
| 完整 CTest | **43/43 PASS**，38.96秒；包含 Windows API／管理 fixture，不是人眼或真正 OS 驗收 | final-full-suite-and-gate.log；ctest-inventory.log |
| SDK | **18/18 PASS**；完整封裝鏈共四次18/18，即72次執行，並非72個獨立案例 | 同上，含 SDK ZIP 兩次重封與解壓回歸 |
| 新啟動／隔離工具 | **6/6 PASS**，含兩項審查入口回歸，真15秒 timeout 未放寬 | launcher-contracts.log、完整套件 |
| 其他既有工具 | **17/17 PASS**，desktop-power／security-netlog／metrics分析 | remaining-tool-tests.log |
| 其餘完整腳本 | CIM拒絕仍完成環境檢查；採樣完整／提前退出／未知PID；主題8個validator輸入＋範例封裝重驗；隔離路徑檢查變異oracle；SDK ZIP重封hash相同、解壓後18測試及兩個.dmt驗證均PASS | 完整套件及所指 oracle 證據 |
| 試用封裝與入口負面 | 白名單55＋manifest、逐檔／sidecar、缺EXE／SDK／空檔／junction／拒覆寫；真PS5.1 CheckOnly依賴與繁中失敗提示、CMD停留／CheckOnly exit1 PASS | package-contracts.log、launcher-boundaries.log、cmd-boundaries.log |
| 包內作者工具 | 固定TypeScript5.9.3：正確SDK／MockHost編譯、四種預期錯誤均拒絕、dist建置、包內packager產6檔7178bytes .dmt PASS；新DMT hash另記，不沿用07舊DMT hash | author-restore／configure／types／build／package.log、author-artifact.json |

完整套件已執行，不沿用歷史33／18作預設計數。相關5個CTest及工具測試在開發階段先跑，15:50完整輪保留為開發期基線；審查指出其後安全文件會進SDK ZIP，故修正收斂並凍結封裝輸入後，再執行一次最終完整鏈，不能用舊基線冒稱最終內容。候選Windows整合、封裝與作者另逐項記錄。語法／程式及文件空白檢查（排除保留原始位元的dated evidence；其CRLF／原輸出空白不重寫）及最終工作樹位元指紋於審查收尾保存，不把單元結果代替產品實機。

## trial.6、多輪預設、08-D1 與繞行移除

08 Comments／delivery-final 的來源、繞行與08-D1交接已核對。原03預設啟動 FAIL、08產品預設第2輪15秒退出FAIL、trial.6兩次子程序觀測FAIL全部保留，不改寫或猜測根因。

- **trial.6產品預設，不等待新Preview就緒即走退出觀測**：3輪／6次啟動與exit0 PASS；每次核實子程序2／6／2／6／4／6個均退出。退出命令後等待5.742～11.363秒。保存返回後仍須枚舉及持有子程序 handle，精確間隔由JSON時間戳計算，不能宣稱無觀察開銷或捕捉全部短命程序。08-D1本輪未重現，不等於根因修復。見 default-immediate/。
- **trial.6產品預設，保存後待唯一新Preview握手及HealthTick再退出**：另3輪／6次exit0 PASS，每次6個核實子程序；等待0.083～10.182秒。首次主螢幕1920×1080原生矩形、有效休眠1／網路0、取消草稿、保存Preview／單目標、相同設定hash重啟與Dashboard握手通過。這與上一項分開，不用新情境替換原FAIL。見 default-after-ready/。
- 上述達到票08確認的本機多輪移除前提後，對「真正入口應沿用產品預設」留 **Red**：trial.6實際入口強制休眠0而預期1，明確FAIL；app正式exit0與核實子程序退出。再只移除來源CMD的 `--no-smart-sleep`，依08固定產品／SDK重封獨立trial.7。原trial.6未覆寫。見 launcher-default-red/及trial6-to7-delta.json。
- **trial.7真正CMD入口Green**：3輪／6次exit0，全部有效休眠1；首次唯一主屏桌布、取消／保存Preview／目標／網路1、唯一新Preview握手／JS回應、相同設定hash重啟及Dashboard通過；每次6個核實子程序退出，等待0.237～8.067秒。原30秒等待／15秒退出、唯一宿主／設定／子程序判準不變，另以 ExpectedLauncherSmartSleep明確區分trial.6和trial.7的入口契約。見 launcher-default-green/。

未改產品預設或設定遷移；既有保存為關閉的智慧休眠仍保持關閉。後續擴充回歸發現09-D2，與啟動／保存／退出情境分開保留；不宣稱智慧休眠完整PASS或RC。包內說明指向本輪最終限制，不能以新入口通過解除其他gate。

## 候選安全、作者與多目標整合

同一trial.7 ZIP解壓EXE及資產，不從來源樹補產品檔案；唯一外部原生測試工具為明確指定的本票Release ParentFixture（hash見parent-fixture.json），沒有放進候選包。新增 EvidenceDirectory／ParentFixturePath 只配置測試位置，原有斷言不變。

- **安全PASS（指定範圍）**：網路off→on→off、管理／獨立重啟、指定HTTP／HTTPS與接收端、來源／儲存／框架／權限／WebRTC／preconnect／管理命令／可信導覽回復等原矩陣通過。三份NetLog SmartScreen POST嘗試0、HTTP/2送出0bytes。摘要／接收紀錄與啟動退出證據見 security/，原始NetLog只留使用者本機；不保存完整profile或宣稱全程序零外連。完整DNS／其他TURN／proxy／handler／Runtime及舊COM真競態仍不足。
- **作者PASS（原生流程範圍）**：本輪新DMT正式CLI匯入、同版拒絕、作者↔Minimal、設定hash不變、原生移除選否／是、回退／移除清單／同版重匯入載入及exit0；當下核實子程序退出。見 author-flow/。這不是人手選檔、像素完整或新DOM訂閱測試；07舊DOM結果保留其原hash，不套到新DMT。
- **基本多目標PASS**：另獨立新資料跑原基本矩陣，單／雙目標保存取消、完整幾何／viewport、各宿主握手／世代隔離、網路off→on→off、跨程序測試父視窗故障回復、手動暫停／模式往返及全斷線暫主屏、不改保存目標與正常退出／當下核實子程序清理。見 multi-monitor-basic/，不當真正Explorer／拔插／人眼證據。
- **擴充多目標FAIL（09-D2，必要gate）**：同包另新資料、休眠透過設定開啟，smart-sleep-enabled已觀察雙目標新MetricsTick／HealthTick；手動暫停與受控WTS鎖定／解鎖後維持暫停17秒，世代不變；再傳20002解除手動暫停，原Wait-Condition期限內沒有新指標，16:09:44.853+08記FAIL。兩目標仍display-off／已暫停，MetricsTick1580423640、HealthTick1580423843。沒有同步實際OS電源／有效手動狀態證據，根因未定，不把標題當根因、不做推測性C++修正。見 multi-monitor/failure.json、phases.json及tool-error.log。該次後續renderer／browser故障交錯、8輪有界退化、JS無限迴圈與後段fixture未到達，**NOT RUN（前段FAIL中止該測試）**；基本矩陣另外PASS不覆蓋它。

## CI 與 01～08 交接核對

gh可讀遠端既有結果。最新run [40849189915](https://github.com/act70255/DrillPaper/actions/runs/40849189915) 為main `b4616ec690787cb5202426c633782cacf146b82e`：依賴還原、configure／build、CTest33／SDK18及範例封裝PASS；release-candidate為 **skipped**，artifact只有drillpaper-theme-sdk-examples（14081bytes），不是app。完整metadata／jobs／artifact與原log保存ci-*，不把skipped或舊SHA當本票PASS。

**最終來源／trial.6產品來源相符的乾淨Windows CI與app artifact：NOT RUN／缺證**。本輪查核既有遠端，不將尚未推送的工作樹偽裝已跑CI；未提前推舊分支或合併main以製造相符結果。一次提交／push後由票11對feature觸發既有Windows／trial workflow；本機正式package gate已實證拒絕，遠端gate工作未執行，兩者分記。沒有觸發正式發布。

| 票 | Status核對／未結問題與gate |
| --- | --- |
| 01／02 | implemented；多宿主／固定800×600程式及原生範圍完成，其他DPI／解析度／clone／拔插／人工及新版真正Explorer仍NOT RUN；候選基本原生流程另驗 |
| 03 | implemented僅試用交付；原智慧休眠啟動與舊SmartScreen上傳FAIL永久保留，不當目前全組態PASS |
| 04 | resolved僅可執行安全矩陣；候選重驗指定矩陣及零POST，完整安全仍PARTIAL，owner及下一步見09-G3 |
| 05 | resolved僅可執行復原；真正OS／GUI仍缺證，本輪新增09-D2 FAIL交票10，不用較早PASS覆蓋 |
| 06 | resolved僅有限矩陣；664筆含3筆資源缺失／6個CPU區間排除、1805.80秒長測仍上升，不能排除洩漏；NVIDIA／真實節能／更長soak等NOT RUN |
| 07 | implemented／A10仍PARTIAL；候選包內作者compiler及CLI流程重驗，GUI／獨立作者／像素完整仍缺證；SDK ZIP與app分記 |
| 08 | implemented僅交付及人工交接；trial.6、08-D1及原FAIL保留，09依確認條件移除新入口繞行另包trial.7；原移除政策BLOCKED／乾淨機器NOT RUN不自動解除 |

A01～A16最新表見 [FINAL_HANDOFF](../../../FINAL_HANDOFF.md)；必要FAIL或缺證均拒絕放行，所有未完成項有[GATES](GATES.md)與[人工清單](MANUAL_CHECKLIST.md)，不以文件取代實機。

## 防毒、清理與未執行

原持續桌布PID83428以完整路徑 `artifacts/acceptance/persistent-readiness-20261029-120049/binary/DrillPaper.exe`、UtcTicks639288432499803524、SHA `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 核對。沒有關閉／替換、沒有重啟Explorer；清理只對已取得handle／核實身分的本次程序。各退出情境的已觀察子程序數按原JSON，不宣稱觀測全部短命程序；擴充FAIL的退出與最終殘留另外檢查，不冒稱該測試全部PASS。

可讀Apex One產品版本14.0，完整build未知；AEGIS_BM.log從before至本輪中段均45890bytes／修改14:51:46.783+08／SHA `C1550D0520F87091EDB2A2BB76507B1C6B06174718843AD1C1EBD6B664DA7D88`。最終指紋另見after。沒有本輪已證實受攔截的產品步驟，不代表完整觀測或可斷言沒有防毒介入；不修改防毒。未把未知原因的09-D2自動改為BLOCKED。

**BLOCKED（工具清理，與防毒分開）**：複製證據的初版篩選只排除根層appdata，漏掉round-n/appdata，誤複製本次隔離profile的部分JSON／log。自動核准審查拒絕刪除這些已核對在本證據目錄內的資料，只回報 `blocked by policy`；沒有換方法刪除。資料保留本機，精確Git ignore規則排除所有本證據樹下appdata，提交前檢查不含profile。這不是產品退出FAIL或防毒攔截，也不宣稱實際移除已通過。

兩次工具呼叫失誤保留：第一次verify-trial-archive用PS5.1讀無BOM UTF-8腳本，在解析階段失敗，並未檢查ZIP；改用原PS7流程後55檔／hash通過（candidate-inventory*.log）。作者npm初次因外層日誌路徑變數為空，命令未執行；修正絕對日誌位置後還原／正負compiler／build／package通過。不將這些當產品FAIL、候選不符或防毒因果。新PS5.1使用的測試腳本存UTF-8 BOM。

真正人工畫面／GUI、真實OS事件、NVIDIA、完整安全與長測、乾淨使用者／缺依賴／更新回復／實際移除等 **NOT RUN**：缺相應設備、人工或環境，詳列可執行步驟，不中斷本票。09-D2後未到達的擴充情境也NOT RUN，不把前票證據充作本輪新結果。

## 重現命令

使用 candidate.json／trial7.json 中的非Temp使用者路徑；每次 EvidenceDirectory 必須新建、拒絕覆寫，產品測試不要並行。

```powershell
scripts/build.ps1 -Configuration Release
pwsh -NoProfile -File scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1 -OutputDirectory <本次非Temp目的地>
ctest --preset windows-msvc-release -N
node --test tests/desktop-power-tools.test.mjs tests/security-netlog.test.mjs tests/metrics-performance-analysis.test.mjs
pwsh -File scripts/verify-trial-archive.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.6-win-x64-unsigned.zip -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b
pwsh -File scripts/test-delivery.ps1 -PackageDirectory <trial.6解壓> -EvidenceDirectory <新目錄> -Rounds 3 -ImmediateExitAfterSave
pwsh -File scripts/test-delivery.ps1 -PackageDirectory <trial.6解壓> -EvidenceDirectory <另一新目錄> -Rounds 3
pwsh -File scripts/package-trial.ps1 -ApplicationDirectory <已核實trial.6解壓> -SourceDirectory artifacts/trial-build-676bb473efec-4245f767154e4371a36edee9c78c218f/source -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b -Version 0.1.0-trial.7 -MinimumVcRuntime 14.44.35112.0
pwsh -File scripts/test-delivery.ps1 -PackageDirectory <trial.7解壓> -EvidenceDirectory <新目錄> -Rounds 3 -UseLauncher -ExpectedLauncherSmartSleep 1
pwsh -File scripts/test-webview2-security.ps1 -ApplicationPath <trial.7EXE> -EvidenceDirectory <新目錄>
pwsh -File scripts/test-multi-monitor.ps1 -ApplicationPath <trial.7EXE> -EvidenceDirectory <新目錄> -ParentFixturePath <本票Release外部fixture> -DesktopPowerRecovery
pwsh -File scripts/test-multi-monitor.ps1 -ApplicationPath <trial.7EXE> -EvidenceDirectory <另一新目錄> -ParentFixturePath <同fixture>
pwsh -File scripts/test-theme-author-flow.ps1 -ApplicationPath <trial.7EXE> -PackagePath <本輪author-theme.dmt> -EvidenceDirectory <新目錄> -VerifyRemoval
```

其餘CheckOnly／CMD／CLI、npm configure／check／build與package命令對應各具名日誌；固定TS／作者路徑見author-artifact.json。審查修正後另以最終CLI在候選EXE重驗六項斷言、以新證據目錄重跑安全正常矩陣（security-after-review/及final-candidate-*.log），均PASS；新三份NetLog仍零POST／送出bytes，與原安全輪分開保留。最終審查見 REVIEW.md；本票完成後用commit-msg產生繁中Conventional Commit，唯一commit並push目前分支，hash以Git記錄為準。

記憶查證：Nowledge MCP thread_search query=`RC-09 測試鏈 PowerShell Temp 決策`、limit3、無filters、server mode=full、ambient default／strict；total_found=0，沒有rank／score可列。以本票最新使用者確認決策為準；未作無結果的graph擴展。

收尾記憶去重查證：MCP memory_search query=`DrillPaper RC09 09-D2 trial7 受控解除暫停`，mode=normal、scope=default/strict、limit3、無filters。rank1 `8e1076c6-75a2-4854-afee-912985649d5d`「RC 整合回歸因 09-D2 FAIL 拒絕放行」score0.9897146389948361；rank2 `134ba711-6753-4dc9-a393-201290ecc4bf`「票 09 多目標擴充回歸未通過」0.5833579379898444；rank3 `ddfa54df-d9b1-4384-b27f-aa3ad67da68d`「票 09 最終放行判定為拒絕」0.4463651917609727。這些為本輪進度的自動來源記錄，不作獨立實機證據；server表示索引重建中、語意暫停／文字結果可能不完整。explore_graph MCP不可用；CLI status健康，但沒有同owner／space的可信瀏覽器工作階段證據，依explore-graph技能略過圖，不開未驗證URL。
