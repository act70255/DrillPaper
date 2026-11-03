## 2026-11-03 票 17 — Inno Setup 使用者層級安裝檔（implemented）

- Branch：`feature/rc-17-inno-setup-installer`（base main 45471d1）。
- Scope：
  - app 改為靜態 CRT，不再需要 VC++（[ADR 0006](adr/0006-static-crt.md)）。
  - 新增 `--exit-running`，正式結束同路徑實例（[ADR 0007](adr/0007-installer-graceful-exit.md)）。
  - Inno Setup 使用者層級安裝檔 `DrillPaper-<版本>-Setup-unsigned.exe`，內容與試用 ZIP 同一份白名單。
  - CI artifact `drillpaper-installer-unsigned`。
  - 文件：[安裝檔](INSTALLER.md)。
- Commands：
  - `./scripts/build.ps1 -Configuration Release`、`./scripts/test.ps1 -Configuration Release`。
  - `./scripts/test-installer-package.ps1`。
  - `./scripts/build-trial.ps1 -SourceCommit <sha> -Version 0.1.0-trial.11`。
  - `./scripts/build-installer.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.11-win-x64-unsigned.zip -SourceCommit <sha>`。
- Results：完整測試通過（CTest 數量見 REPORT）；安裝檔打包契約 5/5；CI trial run 41429684943 產出安裝檔；trial.9／10／11 實機與靜默安裝、覆蓋安裝、解除安裝驗證通過。trial.9 解除安裝誤刪真實資料一次，已還原並改為標示動作的按鈕。證據見 [REPORT](acceptance/2026-11-02/installer/REPORT.md)。
- NOT RUN／BLOCKED：
  - 乾淨機器與缺 WebView2 的安裝（票 16 BLOCKED）。
  - trial.11 GUI 精靈沒有重看。
  - 程式碼簽章不在範圍。
- 不合併 main、不建立 release／tag，產物仍標示 trial／unsigned。

## 2026-11-02 RC 11 結案 — 有條件放行（使用者決策）

- Branch：`feature/rc-11-gate-evidence`。候選 trial.8（來源 ae1c5e0，ZIP 63A98B5B…D53）。總結：[REPORT](acceptance/2026-11-02/rc-gate-evidence/REPORT.md)；互動實機：[INTERACTIVE](acceptance/2026-11-02/rc-gate-evidence/INTERACTIVE.md)；CI：[CI](acceptance/2026-11-02/rc-gate-evidence/CI.md)；效能：[performance](acceptance/2026-11-02/rc-gate-evidence/performance/REPORT.md)。
- Results：CI 精確 SHA CTest 53/53 PASS、gate 拒絕時無 RC 產物；trial.yml 修正 null 退出碼誤判（c6951cf）。互動實機：真實鎖定 5/5、實體拔插、Explorer 重啟 1 次、GUI 匯入流程、手動暫停與鎖定交錯皆 PASS；全螢幕全域暫停 PARTIAL（已知限制）；S4、S5、S12 依決策 NOT RUN。效能：100 次切換失敗 0、雙目標長測 52.5 分鐘 PASS。
- Decision：使用者以發行維護者身分決定 **有條件放行**，接受報告中的已知限制清單；不建立 tag／release、不簽章、不發布；package.ps1 的正式 RC blocker 未修改。剩餘 BLOCKED／NOT RUN 與改善建議由票 16 追蹤。票 01～10、12～15 已由使用者決定經 PR #1 合併至 main（62b89b8）。

## 2026-11-02 RC 11 — 效能既有證據收尾

- Branch／base／scope：沿用 `feature/rc-11-gate-evidence`，開始 HEAD `23ba5efce199136c5bbfc87efbb2d58b379bcfcb`；只完成 09-G4 既有資料分析、報告與封存。依票最新確認決策，長測門檻改 30 分鐘、約 51 分鐘時提早收尾；原 REQUEST／7200 秒計畫與既有證據原樣保留，新需求見 [REQUEST-analysis](acceptance/2026-11-02/rc-gate-evidence/performance/REQUEST-analysis-20261102.md)。未改產品、未啟動任何產品實測或觀察器，票 11 Status 維持 open，未重判 RC。
- Results：trial.8 雙目標 100 次切換失敗 0，平均 7.0157 秒／p95 7.6997 秒／最慢 8.3072 秒，200 筆資源完整；非穩態 Private Bytes 前後 +40.5781 MiB，不當作長測門檻結果。最終 soak 535 筆／3149.0732 秒（52 分 29 秒，晚於 521 筆中途值），`--management --preview --no-smart-sleep`、兩個 Minimal 宿主／兩個 renderer。依 30 分鐘與 06 容差，效能 PASS：Private Bytes 首末 300 秒中位數 +6.6328 MiB、OLS +0.126741 MiB/min、handles +2／threads -2、CPU 平均 0.297195%／p95 0.548208%。資料完整性 PARTIAL：1 筆短命程序漏讀，排除該筆資源及相鄰 2 個 CPU 區間；已核實 8 程序組成變化 0。每 10 分鐘中位數／06 對照／環境與限制見 [REPORT](acceptance/2026-11-02/rc-gate-evidence/performance/REPORT.md)，有限觀測不宣稱無洩漏。
- Exit／blockers：Claude 收尾 taskkill /T 連帶終止腳本、Node 與 PID 57672，是操作失誤而非產品崩潰；長測正式退出／正常子程序清理 NOT RUN，不以程序歸零當正常退出證據。兩小時長測 NOT RUN（使用者降門檻並提早收尾）；NVIDIA BLOCKED（無設備）、真實節能／其他硬體與 Runtime NOT RUN（無相應資料），其他 gate 不變。產品 build／完整 CTest、SDK、型別檢查、CI、TDD NOT RUN，因本輪僅分析且禁止新產品實測。
- Commands／validation：`node .../analyze-existing-20261102.mjs <原始根目錄> <performance>`、`pwsh -NoProfile -File .../archive-existing-20261102.ps1 -SourceRoot <原始根目錄> -OutputDirectory <performance>` exit 0；`node --test tests/metrics-performance-analysis.test.mjs` 12/12 PASS（離線與入口拒絕檢查，未啟動產品）、`node --check .../analyze-existing-20261102.mjs` PASS。同期 OS 23429 筆 unlocked/on、資源對齊無過期；既有防毒 226 筆指紋不變，非完整防毒觀測。原始 ZIP 22 entries／1009439 bytes，SHA `71B2E521875EB925CEA3E7B1E297BAFCA49B350892F853624B77BBAC96FB5D9D`；來源／ZIP 逐檔 hash 與既有工作樹證據 hash 核對一致，排除 appdata／WebView2 profile，沒有覆寫。
- Review／commit：依 implement 套用 code-review 的 Standards／Spec 兩軸唯讀審查，結果見 [REVIEW](acceptance/2026-11-02/rc-gate-evidence/performance/REVIEW-analysis-20261102.md)。Standards 初審 1 項錯誤輸出問題已修正，複查 0；Spec 0。暫存全檔空白檢查有兩個原始診斷日誌檔尾空行告警（歷史 diagnostic.log 與本輪離線錯誤路徑日誌），為保留證據不修改；文件／工具／JSON／CSV 篩選檢查 PASS。本節與票 Comments、全部效能證據同一次提交；commit-msg 依實際暫存差異產生繁中 Conventional Commit，提交及推送 hash 以本分支 Git 記錄為準。不合併 main、不建 tag／release。

## 2026-11-02 RC 10 結案 — 09-D2 未重現，疑似環境

- 依使用者確認決策結案：重試時 trial.7 與 HEAD Release 原命令皆 PASS、同步 OS 取樣全程螢幕開啟／未鎖定（見下方續作條目與 7107da8）；上午兩輪 display-off 前置失敗缺同步 OS 證據，疑似真實螢幕關閉。09-D2 與前置失敗證據原樣保留，無產品變更。票 10 resolved，不解除 A08 gate，RC 仍拒絕放行；真實關屏啟動握手與真正鎖定／關屏／待機往返交票 11。

# 開發狀態
## 2026-11-02 RC 10 續作 — 同步OS下兩版本未重現，停止未提交

- Branch／scope：沿用 `feature/rc-10-controlled-resume-regression`，開始／停止HEAD均 `40e007f54cc2f6920b02c604f24332cbb9efbe5c`；先讀票最新確認決策及handoff／架構／相關STATUS，方案記[REQUEST](acceptance/2026-11-02/controlled-resume-retry-093410/REQUEST.md)。新證據目錄，原09與上一輪不覆寫；沒有src／include／scripts／tests變更、無ADR或政策變更。
- Commands／結果：循序跑原 `pwsh -NoProfile -File scripts/test-multi-monitor.ps1 -ApplicationPath <隔離EXE> -EvidenceDirectory <新目錄> -ParentFixturePath <Release fixture> -DesktopPowerRecovery`：trial.7（09:37～09:43、EXE993FD4…97DA）與HEAD Release（09:44～09:50、EXE8E8953…214A）皆完整PASS／exit0。中間 `cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperParentFixture --parallel 8` PASS；完整路徑／來源／hash／log見[REPORT](acceptance/2026-11-02/controlled-resume-retry-093410/REPORT.md)。原35秒等待／17秒暫停／180秒無限迴圈及退出斷言不變。
- Windows相關範圍：兩輪均通過智慧休眠前置與原09-D2手動暫停／受控WTS7／8／解除後新MetricsTick與HealthTick；renderer／browser故障交錯、8輪有界退化、JS無限迴圈約91.09／92.04秒退Minimal、父fixture故障／模式／離線暫用及退出通過，各19個當下已觀察WebView2子程序退出。這是本輪on情境PASS，不能改寫歷史FAIL或宣稱根因已修。
- 只讀OS證據：09:36:47～09:50:20獨立console初始／後續通知及WTS查詢共5263筆，console全部on、session1全部active／unlocked，實際最大取樣起始間距578ms。每輪前留樣，phases與最近OS樣本逐項對照；本輪無failure.json，失敗當下擷取未觸發。手動暫停的DisplayOff為既有有效政策，解除後兩輪恢復；未得非手動暫停錯判／真實display-off下啟動未握手失敗，後者NOT RUN，不能由on情境排除。未強制喚醒、不改電源設定、不自行決定優先權。
- Stop／gate／commit：未取得可重現失敗，不滿足診斷／TDD修正前提，依使用者停止規則不commit／push；票10仍in-progress，09-D2原因未定、A08及RC gate保留。根因診斷／最小化、新TDD／產品修正、相關單元／SDK／型別檢查、新包／獨立預設交付矩陣、code-review／commit-msg均 **NOT RUN**（未取得失敗且停止）；全套／CI **NOT RUN**（留收尾）。不合併main、不公開發布。
- Safety／handoff：非Temp使用者繁中空白副本與隔離資料、Node直接啟動，產品實測循序。Windows11 26200／雙1920×1080 DPI144／96；實際browser Runtime156.0.4314.58，09為.50，未變更／歸因。可讀Apex One BM前中後41998bytes／11-01 09:42:36／SHA E39585…5F81不變，未觀察新增攔截非完整觀測。原桌布83428路徑／UTC ticks／SHA相同，收尾唯一app、隔離程序無殘留，未重啟Explorer或關閉／替換。原始ZIP217089bytes／SHA67E111…6C72、OS明細及未執行原因見REPORT；真正OS／畫面／原Runtime獨立環境 **NOT RUN**，附[人工清單](acceptance/2026-11-02/controlled-resume-retry-093410/MANUAL_CHECKLIST.md)。

## 2026-11-02 RC 10 — 原回歸前置條件未成立，停止未提交

- Branch／base：從乾淨指定HEAD `a3c183f5abe9d10f5184ad95aca8bb63bab0ed6f` 建立 `feature/rc-10-controlled-resume-regression`，停止時HEAD不變、票10 in-progress。已讀handoff／架構／spec／票及相關STATUS，需求先記[REQUEST](acceptance/2026-11-02/controlled-resume/REQUEST.md)。
- Scope／結果：先核實09 trial.7 ZIP87FE10…C29D／EXE993FD4…97DA，循序跑原 `test-multi-monitor.ps1 -DesktopPowerRecovery`；再成功建置HEAD Release（僅DrillPaper／ParentFixture）並以新隔離副本跑同命令，EXE8E8953…214A。trial.7在智慧休眠啟用後首次新指標斷言FAIL（09:14:34、雙Tick／Health0、display-off／已暫停）；HEAD在該段更早的握手等待FAIL（09:16:25、雙Ready／Tick／Health0、display-off／低頻模式）。皆未到擴充段手動暫停／WTS往返，沒有原09-D2等價失敗回歸，不能據此診斷原缺陷。HEAD初輪副本漏DLL／退出3221225781另保留準備失敗，補齊後用新目錄重跑。
- 停止點／commit：依使用者「前提不成立時停止、不commit」，沒有改src／include、測試／政策或期限，只更新票／本節／證據。原09-D2與必要A08 gate保留、拒絕RC；根因診斷／最小化／TDD／產品修正、相關單元／靜態檢查、後段renderer／browser故障／8輪退化／JS無限迴圈／fixture、新版重包與預設交付矩陣、code-review／commit-msg／commit／push全部 **NOT RUN**（前置失敗停止）；完整套件／CI **NOT RUN**（留收尾）。不合併main、不公開發布，ADR無。
- Evidence／環境：Windows11 26200、雙1920×1080／DPI144與96；已安裝Runtime156.0.4314.58，09為.50，未歸因此差異。非Temp使用者目錄、隔離LOCALAPPDATA／TEMP／TMP、Node直接啟動、產品測試循序。完整命令／來源hash／原始結果／退出與續作選項見[REPORT](acceptance/2026-11-02/controlled-resume/REPORT.md)，人工項 **NOT RUN**，有[人工清單](acceptance/2026-11-02/controlled-resume/MANUAL_CHECKLIST.md)。本輪無同步真正OS電源／工作階段證據，不把display-off標題當真正關屏、不推定產品或環境根因。
- Safety／next：Apex One可讀BM前中後41998bytes／11-01 09:42:36／SHA E39585…5F81不變，未觀察新增攔截非完整觀測，無已證實防毒BLOCKED。原桌布83428 path／UTC ticks／hash前後相同、收尾唯一app、本次隔離profile WebView2無殘留；未重啟Explorer、不關閉／替換。續作需確認先補目前Runtime下只讀同步電源／工作階段與有效政策觀測，或用具原Runtime的獨立環境重現；不改本機Runtime或自行決定暫停／恢復優先權。

## 2026-10-30 RC 15 — SDK 與交付文件通用路徑

- Branch／base：從乾淨 HEAD `746d66af9dbdb2e010f3dbc2eb3f8ba8a65fa482` 建立 `feature/rc-15-sdk-personal-path`，票14已implemented，票15前提成立、無決策衝突。已核對AGENTS／handoff／架構／spec與相關STATUS，實作前方案及結果見[REPORT](acceptance/2026-10-30/sdk-personal-path/REPORT.md)。
- Scope：作者README與theme-sdk以`$env:USERPROFILE`／Join-Path指定SDK根目錄及完整DMT輸出；試用README以`%USERPROFILE%`指定隔離資料，FINAL_HANDOFF改用`$env:APPDATA`，ENVIRONMENT移除個人工作區名稱。SDK、scripts/trial、交付來源及現行docs掃描0筆個人名稱／絕對使用者路徑；docs/acceptance與本檔歷史紀錄不改。純文件，不改產品／SDK API／封裝工具／白名單；無新測試、不虛構Red，ADR無。
- Related PASS：`pwsh -NoProfile -File scripts/test-sdk-package.ps1`最終exit0，來源兩組＋解壓一組SDK各18/18、清單／授權／本機產物排除／兩個DMT validator通過，兩次重封SHA一致。另`package-sdk.ps1 -OutputFile <使用者目錄>/final-sdk.zip`及來源SDK18/18 PASS；44 entries／64874bytes、SHA `663322E82D4AE5DE0A1AEC2CAD6C5399166BDFE0A73843B1F33746395CD2F94B`。兩包完整內容掃描無個人路徑，不手改歷史manifest。
- Author／hash PASS：最終SDK解壓至獨立繁中空白作者目錄，npm ci／configure／check／build及正式DMT封裝驗證全部通過，TypeScript5.9.3正用法與四個刻意錯誤診斷相符；DMT SHA `82BF38D3743A3F6ADCBFCC31D754B5E776D3A3B815DFB7F49A47F83C7CEE8546`。公開package-trial使用假程式fixture（不啟動）驗55檔白名單＋manifest、逐檔／工具／ZIP hash及內外manifest相符。不是app交付或實機驗收；原始log／來源hash與產物hash見REPORT同目錄。
- 初輪FAIL與修正：舊相對OutputFile經.NET工作目錄解析，DMT落在工作區父目錄，下一步驗證找不到；保留原結果，核對身分後將該單一輸出移回使用者測試目錄。票內文件改為從`$PWD.Path`建立完整路徑，兩步共用；最終來源重封及完整作者流程PASS。未改封裝器，該工具相對路徑行為留後續票，不推定產品／防毒根因。
- Environment／NOT RUN：Windows11、Node24.17.0／npm11.12.1／PowerShell7.6.3。非Temp使用者目錄，TEMP／TMP指向其staging；首次輸出偏移另記。未啟動產品EXE，未操作Explorer或關閉／替換原桌布83428。未觀察攔截，未讀防毒日誌，不宣稱完整觀測，無已證實防毒BLOCKED。完整套件／CTest／CI／正式app或RC重封 **NOT RUN**，依指示留收尾；獨立作者／GUI **NOT RUN**，報告附人工操作清單。既有RC gate不變。
- Review／commit：依implement要求使用code-review兩代理唯讀審查，Standards0／Spec0，原始結論見REPORT。最終暫存diff空白檢查PASS；原始log以ZIP完整保留。更新票與本節後使用commit-msg依實際暫存差異產生繁中Conventional Commit，本票僅commit一次並push功能分支，hash以Git記錄為準；不合併main、不公開發布。

## 2026-10-30 RC 14 — Win32 桌布宿主邊界純重構

- Branch／base：從乾淨 HEAD `e3c7bdae12ba85143be25d190fba14c0a4ee1e2b` 建立 `feature/rc-14-win32-host-boundary`，票13已implemented。已核對handoff／架構／票與spec／STATUS，前提成立、無決策衝突；需求先記[REQUEST](acceptance/2026-10-30/win32-host-boundary/REQUEST.md)。票14 implemented代表純重構、自動驗證與人工交接完成，非RC放行。
- Scope／files：Win32DesktopHost封裝原parent／Shell PID附掛與thread／process所有權判斷、成功／失敗診斷屬性寫入，app保留Surface身分、全程序成功世代及重試政策。DesktopEpoch／DesktopFailure／TargetDpi名稱、代碼、寬度與時序相容，命令／訊息不變；新增原生介面契約案例與live Shell斷言、架構及驗收文件。裸WM_APP、腳本helper與09-D2不在本票，ADR無。
- Related PASS：重構前CTest23/23；既有uv CMake套件原生data/bin工具執行`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperWindowsHostIntegrationTests DrillPaperManagementIntegrationTests DrillPaperMonitorIntegrationTests DrillPaperSettingsTests DrillPaperTests DrillPaperParentFixture --parallel 8`成功；相同篩選及新增原生案例最終**26/26 PASS**、4.09秒。純重構沿用保護、不虛構Red；新增所有權／附掛／診斷契約與超過32位元世代測試。完整CTest／SDK／其他工具／CI／封裝 **NOT RUN**，依指示留收尾。
- Windows自動整合PASS：非Temp使用者繁中空白副本／隔離資料，CTest原生或Node直接啟動EXE，產品測試循序。live Shell 1案例／17斷言；正式`test-multi-monitor.ps1`雙目標幾何／viewport／DPI144與96、握手與世代／網路／保存取消重啟／父fixture崩潰復原／模式往返及全斷線不改設定通過，三次GUI exit0、19個當下已觀察WebView2退出。首次cmd工具呼叫exit1、無案例結果，改既有Node工具後取得PASS，未放寬判準或推定防毒。未啟用09-D2電源擴充，不覆蓋其FAIL。
- Evidence／environment：Windows11專業版26200、SDK1.0.2478.35、兩個1920×1080；已安裝Runtime版本另記，未宣稱採集實際載入版本或跨Runtime通過。最終產品SHA `8E8953FA98842F37965C4FC0C8F3C3FD93E22FD7E1A161B8D9AED3180CE6214A`，來源base＋工作樹、逐檔hash、命令及原始log／JSON見[REPORT](acceptance/2026-10-30/win32-host-boundary/REPORT.md)。
- Safety／NOT RUN：原桌布83428 path／UTC ticks639288432499803524／SHA3C7AB5…15BCE前後不變，收尾唯一app、無RC14 profile WebView2殘留；未重啟Explorer、不關閉／替換原桌布。Apex One可讀BM log前後45890bytes／14:51:46／SHA C1550D…A7D88不變，未觀察新增攔截非完整觀測，無已證實防毒BLOCKED。人工畫面／真正Explorer／拔插／電源及其他Windows／Runtime **NOT RUN**，原因與操作見[人工清單](acceptance/2026-10-30/win32-host-boundary/MANUAL_CHECKLIST.md)，既有RC gate保留。
- Review／commit：依implement／code-review兩代理唯讀平行審查Standards0／Spec0，未執行測試，見[REVIEW](acceptance/2026-10-30/win32-host-boundary/REVIEW.md)。更新本節與票後依commit-msg實際暫存差異產生繁中Conventional Commit，只commit一次並push本票功能分支，hash以Git記錄為準。不合併main、不公開發布。

## 2026-10-30 RC 13 — 空選擇友善提示與 Preview 驗證範圍

- Branch／base：從乾淨 HEAD `c8b9b0a9329704c719aad67bfb2533833725830f` 建立 `feature/rc-13-empty-selection-notice`；票 12 已完成，票 13 implemented 表示程式、自動驗證及人工交接完成。已讀 handoff／架構／相關 STATUS／票與 spec，前提成立、無決策衝突；需求見 [REQUEST](acceptance/2026-10-30/empty-selection/REQUEST.md)。
- Scope／files：app 在副作用前共用桌布目標驗證，預期錯誤具體繁中提示及日誌，其他錯誤仍通用提示；SettingsStore 允許空／首次未解析 Preview 保存成 schema 2 空陣列，桌布保護保留。CLI 強制桌布覆寫同樣先驗證，空選擇 exit 1；原生管理僅轉送操作 BN_CLICKED，修正文字／焦點通知清掉提示的同票根因，標籤限「桌布至少一個」。新增設定／原生回歸、既有多螢幕 runner 的獨立空選擇模式及 README／政策／架構說明；未擴張票 14～15 或 09-D2，ADR 無。
- TDD／related PASS：Preview 空保存、首次未解析保存、原通用提示、CLI 零宿主與原生通知各有 Red→Green。最終原生 CMake `cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperManagementIntegrationTests --parallel 8` PASS，較早建置 Tests／SettingsTests；選取設定／目標／全部管理相關 CTest **16/16 PASS**、2.92 秒，包含固定 800×600、長訊息／鍵盤；PS7 parser／證據拒覆寫 PASS。完整套件／SDK／其他工具／CI／封裝 **NOT RUN**，依指示留收尾。
- Windows 自動整合 PASS：非 Temp 使用者繁中空白副本、隔離 LOCALAPPDATA、Node 直接啟動，產品測試循序。桌布空選擇保存／主題套用拒絕的訊息框及管理狀態具體原因、設定 hash 與有效 HWND／parent／幾何／世代不變；Preview 預覽／保存／新指標、非預期主題錯誤通用提示及詳細 log、CLI 空選擇覆寫 exit 1、重啟保留空 Preview／hash／提示、選回目標後恢復桌布均 PASS。兩次正式 exit 0、12 個當下已觀察 WebView2 退出；不當人眼／真實硬體或完整子程序捕捉證據。
- Evidence／environment：Windows 11 26200、既有 WebView2 SDK 1.0.2478.35／Runtime 156.0.4314.50，管理原生幾何實測 DPI144／96。最終 EXE SHA `D586024E37062325B39527A1E5B711E359AFC83343AFCCEA2A159928E5059721`，來源 base＋工作樹與逐檔 hash、命令、全部前輪工具／產品 FAIL 與最終 PASS 見 [REPORT](acceptance/2026-10-30/empty-selection/REPORT.md)。最初訊息框定位／關閉工具問題與重啟後提示消失分開；後者經等待及重新找 HWND 仍重現，原生 Red 確認通知誤轉命令後才修正，不改寫歷史 FAIL、不推定防毒根因。
- Safety／NOT RUN：原桌布 83428 path／UTC ticks639288432499803524／SHA3C7AB5…15BCE 前後不變、收尾唯一 app，無 RC13 profile WebView2 殘留；未重啟 Explorer、未關閉／替換原桌布。Apex One 可讀 BM log 前後45890bytes／14:51:46／SHA C1550D…A7D88 不變，未觀察新增攔截非完整觀測，無已證實防毒 BLOCKED。人工畫面可讀性、其他 DPI／OS／Runtime、真正拔插等 **NOT RUN**，原因及操作見 [人工清單](acceptance/2026-10-30/empty-selection/MANUAL_CHECKLIST.md)，既有 RC gate 保留。
- Review／commit：implement／code-review 兩代理唯讀平行審查，Standards 0／Spec 初1項 CLI 缺口修正後0；原生通知修正複查亦0／0，見 [REVIEW](acceptance/2026-10-30/empty-selection/REVIEW.md)。更新票與本節後使用 commit-msg 依實際暫存差異產生繁中 Conventional Commit，本票唯一 commit 並 push 功能分支，hash以 Git 記錄為準。不合併 main、不公開發布。

## 2026-10-30 RC 12 — 無法辨識螢幕暫時退化與列舉失敗復原

- Branch／base：從 HEAD `054c9017156098c36c33832c7740086e02aede97` 建立 `feature/rc-12-unidentified-monitor-degrade`，原工作樹乾淨。票 12 設為 implemented，表示程式及可自動驗證部分完成；已讀 handoff／架構／相關 STATUS／票與 spec，前提成立，沒有決策衝突。需求與方案見 [REQUEST](acceptance/2026-10-30/unidentified-monitor/REQUEST.md)。
- Scope／files：runtime 目標解析以空 ID 明確標記無法辨識，任一項即暫選所有區域、clone 去重，恢復回原政策；platform/windows 注入裝置名稱讀取邊界，保留無法辨識項目的矩形／DPI，MonitorInventory 保留成功快取、首次失敗獨立取得主屏退化；app 詳細記錄錯誤並繼續 reconcile／健康檢查，管理清單拒絕勾選與輸出空 ID，獨立 Preview 不列舉。首次目標只於主屏可辨識後在記憶體解析，沒有自動寫回退化目標。同步 README／多螢幕政策／架構，新增隔離 fixture／runner／報告；票 13～15 未擴張處理，ADR 無。
- TDD／related PASS：runtime、原生 target／source 失敗、首次／後續列舉快取、管理空 ID 顯示均保留 Red→Green。`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperSettingsTests DrillPaperMonitorIntegrationTests DrillPaperManagementIntegrationTests --parallel 8`，另建 DrillPaperMonitorDegradeFixture；既有 uv CMake 工具的原生 data/bin 路徑，未使用失效 Python launcher。最終 `ctest --preset windows-msvc-release --tests-from-file <絕對路徑/related-tests.txt> --output-on-failure -V` **17/17 PASS**（8.96秒），涵蓋目標／clone／設定／原生管理／列舉；PS7 parser、證據拒覆寫與 diff 空白檢查 PASS。完整套件／SDK／CI／重封裝 NOT RUN，依指示留收尾。
- Windows 自動整合 PASS：非 Temp 使用者繁中空白副本、獨立 LOCALAPPDATA，Node 直接 spawn，產品測試循序。相同產品入口的測試編譯目標驗未辨識全區域→整體列舉失敗快取及新 MetricsTick→恢復保存單屏；首次列舉失敗→主屏矩形／144 DPI／提示→辨識恢復；獨立 Preview 握手／推送且列舉呼叫 0。三次 exit0，核實 7／6／6 個已觀察 WebView2 退出。正式產品 `test-multi-monitor.ps1` 兩區域、握手／viewport、保存取消／重啟、世代／網路／父 fixture 恢復、模式往返、全斷線及19個已觀察子程序退出 PASS；不是人眼／真實不可辨識顯示器或完整程序捕捉證據，不覆蓋09-D2。
- Environment／evidence：Windows11 26200／Runtime156.0.4314.50／SDK1.0.2478.35，兩個1920×1080、DPI144／96。產品 EXE SHA `A19BBF0272450099BC08378B07F17F4F8E080E077C0163B7202BEF70D272C708`；fixture SHA `9013D5A3E6C8B8261DB81B6CF69E4820BF00E8B03054B120B3B7DB90422046F0`，分開追溯 base＋工作樹。完整命令／原始工具失敗／source與證據指紋見 [REPORT](acceptance/2026-10-30/unidentified-monitor/REPORT.md)；CIM時間量化及ExecutablePath缺失先使wrapper中止，原輪保留，後者不計入核實退出；未假定產品或防毒根因。曾於建置未完成跑到舊Red位元，等待完成後17項最終重驗通過，沒有降低判準。
- Safety／NOT RUN：原桌布83428 path／UTC ticks639288432499803524／SHA3C7AB5…15BCE前後一致且收尾唯一app，無RC12 profile WebView2殘留；未重啟Explorer、未關閉／替換原桌布。Apex One可讀BM日誌45890bytes／14:51:46／SHA C1550D…A7D88前後不變，未觀察新增攔截不等於完整觀測；沒有已證實防毒BLOCKED、不改防毒。真正不可辨識硬體、拔插／clone／其他DPI、真實OS列舉失敗、人眼及其他Windows／Runtime **NOT RUN**，原因與步驟見[人工清單](acceptance/2026-10-30/unidentified-monitor/MANUAL_CHECKLIST.md)。其他RC必要gate及09-D2仍保留，不宣稱放行／沙箱。
- Review／commit：依 implement／code-review 兩代理平行唯讀審查（未與產品實測並行執行測試），Standards初1項＋1建議修正後複查0，Spec0，見[REVIEW](acceptance/2026-10-30/unidentified-monitor/REVIEW.md)。本節與票據同本票唯一提交保存；依 commit-msg 實際暫存差異產生繁中 Conventional Commit 後 commit 一次並 push 功能分支，hash以Git記錄為準。不合併main、不公開發布。

## 2026-10-30 RC 09 — 完整回歸，拒絕 RC 放行

- Commit message：`fix(delivery): 移除入口繞行並記錄回歸阻擋`，由commit-msg技能依最終暫存差異產生；隨本票唯一提交保存，hash以本分支Git記錄為準。

- Branch／base：沿用 feature/rc-09-regression／d60816aff6e99ad1a3624075a74016909f76fa4d；最新確認決策授權先改測試，需求先寫REQUEST。保留既有票內決策，產品src／include／sdk與676bb47無差異，沒有推測性產品修正。09 resolved只代表可執行回歸及拒絕放行／人工交接完成，不代表RC通過。
- Scope／TDD：CLI由Node直接啟動、JSON原始argv與UTF-8結果檔，六項原斷言與15秒／CTest60秒期限不變；完整test.ps1及獨立CTest的TEMP／TMP移到非Temp使用者繁中空白目錄。啟動／隔離公開工具先Red→Green，新契約6/6；相關CTest5/5與候選CLI均PASS。GUI與實際OS／硬體結果不由單元測試推論。
- Commands／完整數量：原生CMake／CTest使用既有uv工具套件的data/bin（PATH Python launcher失效，沿08方式、不重裝）。scripts/build.ps1 -Configuration Release完成最終來源configure／build；scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1 -OutputDirectory <非Temp新目錄>再次建置並實際跑完整scripts/test.ps1：**CTest43/43**、SDK18/18（封裝鏈四組18，共72次執行而非72獨立案例）、新工具6/6，環境／取樣／主題／oracle／SDK ZIP重封／解壓均PASS；另既有工具17/17、封裝與入口正負及固定TS5.9.3正負／作者建置PASS。正式gate預期exit1，沒有RC ZIP。完整log、命令、來源／hash見[REPORT](acceptance/2026-10-30/rc-regression/REPORT.md)。
- Artifact／預設回歸：原trial.6 SHA FC08E190…9EFF8A5不變；候選EXE993FD4…97DA與最終本機建置25316B…6D26D來源相同但位元hash不同，不混稱。trial.6產品預設三輪不等待新Preview就緒及三輪待就緒／JS回應均PASS，各六次exit0；08-D1未重現、原FAIL不改寫、不宣稱根因修復。達08已確認的本機多輪前提後，入口預設契約Red→移除新CMD繞行→trial.7真CMD三輪Green（六次有效休眠1／exit0與各6個當下核實WebView2退出）。trial.7 ZIP472507bytes／SHA87FE10E27EB016D144F8C775BEEA4C81C724BD513BDDE61DE9F866465FDBC29D，53檔產品／SDK相同、僅CMD／README及manifest變；固定產品來源676bb47、工具逐檔hash另記，NotSigned、不宣稱位元可重現。原保存為關閉偏好不改寫。
- Windows整合：非Temp使用者繁中空白目錄／全新LOCALAPPDATA、Node／CMD直接啟動、循序執行。候選安全原指定矩陣三份NetLog零SmartScreen POST／送出bytes；基本多目標原生幾何／viewport／設定／世代／網路／fixture／模式／全斷線及退出、作者正式匯入／同版拒絕／切換／原生取消確認移除／同版重匯入PASS。不是人眼／真正Explorer／OS電源或完整沙箱證據。
- **必要FAIL／09-D2**：擴充雙目標smart-sleep-enabled及手動暫停受控WTS往返後，解除手動暫停未於原期限恢復新MetricsTick，兩宿主仍display-off／已暫停，16:09:44+08記FAIL；原因未定，沒有同步實際OS電源及有效狀態證據，不推定產品／工具／防毒根因。票10（owner James）收時間線、再現回歸及最小修正，不放寬判準；該次後續故障／無限迴圈等未到達NOT RUN。基本矩陣獨立PASS不覆蓋此FAIL。
- CI／NOT RUN：只查既有遠端，最新run40849189915對應舊main b4616ec、CTest33／SDK18及SDK範例artifact PASS，RC job skipped；不當最終來源／app CI。相符來源CI／app artifact、真正桌面／Explorer／電源／拔插／人眼、完整安全／其他Runtime、NVIDIA／更長soak／100次切題、乾淨無工具一般使用者／真實缺依賴／更新回復／實際移除及資料清除仍缺證，票11及[GATES](acceptance/2026-10-30/rc-regression/GATES.md)有owner／下一步，[人工清單](acceptance/2026-10-30/rc-regression/MANUAL_CHECKLIST.md)逐項列原因／操作。06缺失及記憶體仍升、07A10 PARTIAL、03／08歷史FAIL及08移除BLOCKED保留。**拒絕放行**，不以文件或CI綠燈代替實機。
- Safety／BLOCKED：原持續桌布83428 path／UtcTicks639288432499803524／SHA3C7AB5…15BCE前後相同；本票app及profile對應WebView2收尾無殘留、未重啟Explorer。Apex One可讀14.0（非完整build），BM日誌before／after均45890bytes／SHA C1550D…A7D88，未觀察新增事件不等於完整觀測；無已證實本票防毒BLOCKED，未知FAIL不改名。複製證據漏篩round-n/appdata，本次隔離profile誤複製；自動核准審查拒絕刪除，只回報blocked by policy。此工具清理BLOCKED，保留本機、精確gitignore排除、不繞過刪除限制，不作產品移除PASS。
- 最終補驗：審查指出15:50完整輪後安全文件進SDK包的輸入已變；原輪保留基線，初始化友善錯誤與安全證據拒覆寫兩項Red→Green後，凍結輸入再跑完整公開封裝鏈。最終Release configure／build、CTest43/43（38.96秒）、SDK四組18/18、新工具6/6及所有腳本通過，SDK重封SHA E44D5CC58EEB8FC3B6C1C6C37B9942119F55FA9988C5BD241B20FD1EFE98ED19；正式gate仍exit1且無RC ZIP，詳見final-full-suite-*。
- Review／commit：依implement與code-review做Standards／Spec兩軸，結果見REVIEW.md；最終語法／空白與來源指紋存同目錄。完成後依commit-msg實際暫存差異產生繁中Conventional Commit，本票唯一commit並push當前分支；本節隨該提交保存，hash以Git唯一提交記錄為準。沒有合併main、公開發布、release或tag；ADR無，未改產品架構或已確認預設。

## 2026-10-30 RC 08 — 接續完成交付候選包，保留繞行與人工 gate

- Commit message：`build(delivery): 完成交付候選封裝與驗證交接`，由commit-msg技能依實際暫存差異產生；本節隨本票唯一提交保存，commit hash以本分支Git記錄為準。

- Branch／source：沿用 `feature/rc-08-delivery-finalization`、base／產品來源 `676bb473efeca65614fddb40d98e3c88c302494b`。票08最新「停止後」確認決策取代先前多輪前提：不追08-D1、保留`--no-smart-sleep`；原第2輪FAIL與原證據逐檔hash不變。08 implemented只代表可執行交付／人工交接完成，不是RC放行；不改產品C++、智慧休眠預設或其他票狀態。
- Scope：沿用前輪未提交SDK白名單／hash驗證／CI與工具；補完缺必要主題資產fail-fast slice、正式交付README（未簽章防毒／IT例外、依賴、資料與更新回復／ZIP移除）、CMD檢查後直接啟動EXE。新測試擴充最終入口保存網路／目標、原生移除確認／取消及同版重匯入，未提供HTML原生旁路。
- Artifact：正式交付候選`0.1.0-trial.6`，ZIP472421bytes／SHA`FC08E190ACF481696F560CB7136478D9CF6E9DADF45E6EEF505CD62EB9EFF8A5`、EXE`993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`。沿用前輪固定commit乾淨MSVC19.44.35217.0 Release建置並核實EXEhash後重封，最新工具逐檔hash入manifest／sidecar；55檔白名單＋manifest／hash PASS。trial.1～4／trial.5.probe未覆寫。Authenticode NotSigned，不宣稱已簽章／位元可重現／RC。
- TDD／checks：原公開封裝Red→Green與缺資產Red沿用；本輪缺資產Green補完（獨立pwsh退出0），最終缺主題入口／loader／minimumVcRuntime及過舊CRT繁中fail-fast PASS。封裝正負／拒覆寫、相關targets建置、CTest18/18、8檔PS parser與diff空白PASS。PATH CMake的Python啟動器缺檔在編譯前失敗，原日誌保留；改呼叫既有套件原生data/bin/cmake.exe／ctest.exe configure／build及相關測試成功，未重裝Python、不推定防毒原因。
- Windows整合：非Temp使用者繁中空白目錄／獨立LOCALAPPDATA，Windows11 Pro25H2 26200／Runtime156.0.4314.50／Intel。最終CMD兩輪首次唯一主屏桌布實體矩形／握手、有效休眠0、取消網路草稿、保存Preview／單目標／網路1並重啟保持hash、Dashboard握手PASS；四次exit0及當下每次核實6個WebView2退出；保存後唯一新Preview握手與HealthTick的JS回應亦通過。另Node直接啟動同包EXE，正式CLI匯入／同版拒絕、作者切換、原生取消／確認移除與Minimal回退、同版重匯入載入PASS，exit0與6個核實子程序退出；不冒充人手GUI選檔／像素畫面或產品預設休眠回歸。產品測試循序執行。
- Blockers／NOT RUN：實際刪除trial.5解壓目錄被自動核准政策兩次拒絕（只回報blocked by policy），BLOCKED且未繞過；trial.6依相同政策限制未再嘗試，NOT RUN；已確認本票程序退出與資料hash不變。主動清除資料複本／更新回復／真正乾淨一般使用者、真實缺依賴、GUI人眼、其他OS／Runtime與真正OS／硬體項NOT RUN，附逐項人工清單。沒有安裝器，不宣稱解除安裝PASS。完整套件與遠端CI依指示留09；08-D1／繞行移除、03歷史FAIL、04安全PARTIAL、06記憶體上升／缺失、07 A10 PARTIAL等全部由09承接，必要gate不解除。
- Safety／evidence：原持續桌布83428的path／UtcTicks639288432499803524／hash前後不變；本票app與隔離profile對應WebView2無殘留，未重啟Explorer、未關閉／替換原桌布。Apex One早期可讀BM27830bytes／14:30:45修改時間／hash不變；最終45890bytes／14:51:46修改，新增14:51:36另一AIPortal專案pytest／Python的NON_POLICY_JUST_ADC攔截已另存antivirus-final-events.json，不當本票產品攔截或根因，觀測仍不完整；歷史Temp／PowerShell攔截分記、不改防毒。新[REPORT](acceptance/2026-10-30/delivery-final/REPORT.md)、[人工清單](acceptance/2026-10-30/delivery-final/MANUAL_CHECKLIST.md)與原始JSON／log保存完整命令、來源／hash及限制；舊delivery目錄完全保留；.gitattributes對本票兩個證據目錄關閉換行轉換以保留逐檔SHA位元組。ADR無，未改架構／產品決策。
- Review／commit：Standards初2項＋複查1項、Spec1項皆修正，未解決各0；缺CMD及CMD雙擊錯誤停留真Red→Green通過，結果見REVIEW.md。因入口資產修正保留審查前trial.5另包trial.6，52檔產品／SDK／主題hash相同，僅PS／CMD／README三檔異動。trial.6兩次CIM→handle間程序消失導致工具FAIL／CLEANUP_FAILED保留，App均exit0，不當08-D1；工具補上保存後唯一Preview握手／JS回應後退出的不同情境，原15秒退出／30秒等待及子程序身分檢查不變，最終兩輪／四次退出與24個已觀察子程序PASS，不把原立即退出FAIL改綠。完成審查後使用commit-msg依實際暫存差異產生繁中Conventional Commit，本票一次commit並push當前分支，hash以Git為準。不合併main、不公開發布。


## 2026-10-30 RC 08 — 退出觀測逾時，停止未提交

- Branch／base：由乾淨HEAD `676bb473efeca65614fddb40d98e3c88c302494b` 建 `feature/rc-08-delivery-finalization`，停止HEAD未變、08維持in-progress；已讀08全部確認決策、03～07交接、spec／handoff／架構。最新本機隔離多輪決策取代05乾淨機器前提，但本輪未全通過，不能移除入口繞行。
- Scope／草稿：沿03固定來源Release與白名單，補最新SDK／MockHost宣告／TypeScript作者範本／schema／作者工具；新增ZIP來源／清單／hash驗證及CI步驟、三輪原生觀測工具、缺必要主題資產提前拒絕草稿。未改src/include或智慧休眠預設，`--no-smart-sleep`保留，未覆寫trial.1～4。草稿尚未完成審查／驗收，不作最終交付。
- Build／package：固定commit獨立MSVC Release／BUILD_TESTING=OFF PASS，調查包 `artifacts/DrillPaper-0.1.0-trial.5.probe-win-x64-unsigned.zip` 471313bytes，ZIP SHA`EB6A3ABF5FBDB913A336BD8B215F32350918422E1FBBA16E446F96DE759F89FC`／EXE SHA`993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`。含04／05產品與07SDK，工具／說明為當時工作樹且另記hash；白名單55檔＋manifest／逐檔與sidecar PASS，不宣稱EXE／ZIP位元可重現或RC。遠端CI NOT RUN。
- Related／TDD：`cmake --build --preset windows-msvc-release --target DrillPaperTests DrillPaperSettingsTests DrillPaperThemeTests --parallel 8` PASS；`ctest --preset windows-msvc-release -V -R '^(Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause|Protocol v1 |Power state|Sampling scheduler|DrillPaperThemeTests$)'` 18/18 PASS。`test-trial-package.ps1` 最新SDK缺失Red→補白名單Green，既有負面／排除／hash PASS；`verify-trial-archive.ps1` PASS。缺主題入口CheckOnly Red→補檢查後綠測嘗試仍FAIL（舊fixture缺resources，遮住最低runtime分支）；已補fixture但重跑NOT RUN，因本輪已停止，不冒稱slice完成。新runner PS parser無錯；完整套件依指示留09。
- Windows整合／停止點：非Temp使用者繁中空白目錄、全新隔離LOCALAPPDATA、Node直接啟動新EXE `--management`，產品預設智慧休眠=1／網路=0。第1輪唯一主屏1920×1080桌布／握手／取消／保存Preview／重啟／Dashboard及兩次正式exit0、共12個當下核實子程序退出PASS。第2輪首次桌布／握手／保存成功，但退出等待超過工具15秒，CLEANUP_FAILED，第二輪Preview及第三輪未執行。Node退出紀錄顯示14:25:35.608+08:00稍後自行exit0，工具14:25:28.865已記FAIL；未取得精確退出命令時間或堆疊，原因待釐清，不能據此宣稱持續卡死或原啟動未握手重現。
- Defect／gate：開啟08-D1「保存Preview後退出觀測逾時」，後續先補可重現時間線／失敗回歸，不直接放寬期限；多輪皆通過前提尚未達。依使用者指示停止、不commit／push、不移除繞行。03歷史FAIL、04安全／05人工／06硬體效能／07作者流程PARTIAL／NOT RUN及RC gate保留。08剩餘最終入口／重包／README防毒說明／匯入移除／停止後移除／乾淨環境等NOT RUN，完整操作清單交09。
- Environment／cleanup：Windows11 build26200／Runtime156.0.4314.50／SDK1.0.2478.35／Intel Graphics；本機有來源樹、建置工具與Apex One，不是乾淨一般使用者環境。可讀BM日誌fingerprint前後相同，未觀察新增攔截，非完整觀測，沒有已證實的防毒BLOCKED；不修改防毒。收尾原持續桌布83428的path／UtcTicks639288432499803524／hash不變，無本票app或profile對應WebView2殘留；未強制終止、未重啟Explorer或替換原桌布。
- Evidence／commands／next：完整[REPORT](acceptance/2026-10-30/delivery/REPORT.md)、[原始結果](acceptance/2026-10-30/delivery/default-rounds-result.json)、[人工清單](acceptance/2026-10-30/delivery/MANUAL_CHECKLIST.md)保存建置／封裝／測試命令、tooling provenance、退出及防毒證據。真正乾淨使用者／人工／其他OS與Runtime／完整套件NOT RUN，原因及步驟均列出。ADR無，未變產品架構或已確認決策。code-review／commit-msg／唯一commit／push皆NOT RUN，因未達可提交完成狀態，依明示停止規則保持未提交；不合併main、不公開發布。

## 2026-10-30 RC 07 — 第三方 TypeScript 主題作者流程

- Commit message：`feat(sdk): 補齊 TypeScript 主題作者流程`，由commit-msg技能依實際暫存差異產生；本節隨本票唯一提交保存，hash以本分支Git記錄為準。

- Branch／base：從乾淨 HEAD `1636972a570431a0feaa9070978b2503441aa3b9` 建 `feature/rc-07-theme-author-flow`，06 resolved；07 implemented 表示可自動範圍完成，A10仍PARTIAL，人工項依spec附清單，不解除03歷史FAIL／RC gate。
- Scope／files：新增 `sdk/author-starter` 固定TypeScript5.9.3／lockfile／正負compiler案例／離線dist、MockHost型別宣告；修正SDK宣告與MockHost的ready.limits對齊既有原生history/messageBytes。SDK ZIP明列來源、排除本機產物，補作者原生觀測runner／瀏覽器fixture、TS／宣告禁止與移除再匯入測試，更新README／作者與協定／授權／A10交接。未改產品C++或app包，網路與副檔名邊界不變。
- TDD／unit：MockHost缺宣告TS7016→補宣告；native limits正確用法TS2339→修正宣告；MockHost ready欄位測試FAIL→對齊原生。SDK18/18、compiler正確用法＋四個預期錯誤、protocol七項＋ThemeManager入口CTest8/8及最終ThemeManager1/1、螢幕列舉1/1 PASS。既有封裝邊界正常，不虛構Red；正負validator含TS／宣告、APIv2、路徑／配額PASS。
- Commands：`npm ci --ignore-scripts --no-audit --no-fund`、`npm run configure -- <解壓SDK/javascript>`／`check`／`build`（乾淨使用者作者目錄）；包內 `package-theme.ps1`／`validate-theme-package.ps1`；`cmake --build --preset windows-msvc-release --target DrillPaperThemeTests DrillPaperTests --parallel 8`；`ctest ... -R '^(Protocol v1 |DrillPaperThemeTests$)'`，加負面案例後單獨重驗theme；`test-theme-package.ps1`、`test-sdk-package.ps1`、兩次 `package-sdk.ps1 -Version 1.0.0-rc3.author.1`；七個成功 `test-theme-author-flow.ps1` 情境及保留失敗，完整參數見[報告](acceptance/2026-10-30/theme-author-flow/REPORT.md)。PS parser四檔／Node syntax四檔與diff whitespace PASS。完整套件／CI NOT RUN，依指示留09。
- 作者產物：最終SDK ZIP64,412bytes／SHA`376906271C8FBF0E3EDAFC9E8662E4C32524AA7974685AD7ED05DE6FF623A0C8`，兩次重封相同；最終乾淨作者重新編譯打包DMT7,162bytes／SHA`82BF38D3743A3F6ADCBFCC31D754B5E776D3A3B815DFB7F49A47F83C7CEE8546`與原受測sample相同。只含六個離線靜態檔，沒有作者compiler／原始碼／宣告；SDK ZIP證據獨立，不代替08app交付／09RC。
- Windows整合PASS（明列範圍）：Windows11 Pro25H2 26200.8737／Runtime156.0.4314.50／Intel GPU，非Temp使用者繁中空白路徑、隔離LOCALAPPDATA、Node直接啟動EXE`25316B…6D26D`。原作者DMT Preview mock、派生探針Preview live與雙目標live、正式匯入／同版本拒絕／兩次作者載入／APIv2與三種HTML管理命令拒絕／設定hash不變／HTTP off零收件與on正向PASS。最終on共六份報告確認連續訂閱更新DOM；雙目標1280×720 DPR1.5及1920×1080 DPR1主內容寬度檢查PASS，不冒充像素完整／桌面圖示互動。七個成功情境正式退出0，當下已核實WebView2子程序退出；未宣稱涵蓋所有短命程序。
- 原始失敗／limits：保留工具將同版錯誤文字比錯、初版live探針固定1.4秒早於CPU warm-up及一開始npm工作目錄錯誤；修正工具／有界等待後通過，未改collector、不把不可用當0、不推測防毒或解除03FAIL。GUI匯入／確認移除與重匯入、完整人工版面、獨立瀏覽器MockHost、乾淨帳號／無Node的另一機器、其他OS／Runtime／NVIDIA／真實OS事件與完整安全NOT RUN，原因與步驟見[人工清單](acceptance/2026-10-30/theme-author-flow/MANUAL_CHECKLIST.md)。
- Cleanup／antivirus：原持續桌布只讀比對path／精確建立時間／hash；未重啟Explorer、未關閉／替換。Apex One可讀BM日誌前後fingerprint與收尾紀錄存before／after；未觀察新增攔截，不等於完整防毒觀測。若有攔截須記規則／時間／影響項BLOCKED，不改防毒。此處保留套件安全與瀏覽器網路限制，未宣稱沙箱。
- Review／commit：code-review兩軸審查工作樹相對本票base，Standards初審兩項入口錯誤處理／安全退出問題已修正，複查未解決0；Spec0。缺USERPROFILE友善exit1、SDK ZIP相關重驗與額外正常整合PASS；受控清理CIM觀測失敗時工具CLEANUP_FAILED而app正式exit0、真實收尾無殘留，不將觀測不足當PASS。結果見[REVIEW](acceptance/2026-10-30/theme-author-flow/REVIEW.md)。日誌尾空白正規化保留原始副本／hash。依本票覆蓋階段提交規則，本票完成後用commit-msg技能產生繁中Conventional Commit，一次commit＋push本分支；本節隨該唯一提交保存，hash以Git記錄為準。不合併main或公開發布。ADR無，架構／決策未改；08／09承接人工與既有gate。

## 2026-10-30 RC 06 — 硬體精度與多目標效能省電

- Commit message：`test(perf): 新增硬體精度與多目標效能驗證`，由commit-msg技能依實際暫存差異產生；本節隨唯一提交保存，hash以本分支Git記錄為準。

- Branch／base：從乾淨HEAD `c244682204bc3a85b50cd46e15bc50e066eea3b7` 建立 `feature/rc-06-metrics-performance`；05 resolved。06設resolved，表示可執行驗證／報告完成，A05／A13仍有PARTIAL／NOT RUN，不解除RC gate；完整套件依使用者指示留09。
- Scope／files：未改產品src/include或試用包；新增手動原生精度target `DrillPaperMetricsAccuracyProbe`、`test-metrics-performance.ps1`／Win32與PDH helper、分析／圖表與工具測試，更新README、metrics/performance文件、06及08／09交接。測試邊界為公開collector、runtime／bounded／latest-wins及Windows實機；沒有以單元測試宣稱GUI／真實OS事件通過。
- Unit／TDD：相關CTest18/18、原生螢幕列舉1/1、Node工具12/12 PASS。工具循序Red→Green覆蓋CPU正規化／PID重用、時長／斜率／缺失樣本、GPU歸屬、雙端點skew、原證據不可覆寫、有效主題與RAM total容差；純驗證沒有製造產品Red，沒有產品修正。PS7 parser、Node syntax、Python AST PASS，C++相關targets及最終probe W4建置PASS。
- Commands：`cmake --build --preset windows-msvc-release --target DrillPaperMetricsAccuracyProbe DrillPaperWindowsMetricsIntegrationTests DrillPaperTests --parallel 8`；`ctest ... -R '^(CPU sampling|A real zero|Snapshot units|Network rate|An idle network|Metrics history|Snapshot coalescing|Metric change|Sampling worker|Sampling scheduler|Manual pause|Windows metrics collector)'`；`ctest ... -R '^Connected monitors '`；`node --test tests/metrics-performance-analysis.test.mjs`；五組 `pwsh -NoProfile -File scripts/test-metrics-performance.ps1 ...`；Node直接啟動原生probe、`analyze-metrics-performance.mjs`、`uv run --no-project --with matplotlib==3.11.2 python scripts/plot-metrics-performance.py ...`。完整參數／原始log見報告。
- Windows／hardware：Windows11 Pro25H2 26200.8737／WebView2 156.0.4314.50／SDK1.0.2478.35，Core Ultra7 155U／14邏輯CPU、Intel Graphics、雙1920×1080 DPI144／96；中等權限、非Temp使用者繁中空白副本與隔離LOCALAPPDATA，EXE由Node直接啟動。產品EXE SHA `25316B5067076749295B62DB557748B6DC2D88C4069CFBBE4C48E93269F6D26D`（沿用05，來源c244682）；正式probe為本票工作樹，SHA `F3DAE15387A58BEA726E25CAA6B8A227C11204404974A5D6AF6AE79788DB3FF8`。
- Performance：每組先60秒暖機，Minimal單目標1805.80秒／282筆；Dashboard單目標603.49／95、Minimal雙目標602.01／92、Dashboard雙目標603.59／97、雙目標暫停603.81／98。Active CPU平均0.178～0.324%、p95<=0.528%達預定門檻；1800秒組Private Bytes首末窗口中位數+14.17MiB、OLS+0.569MiB/min、handles／threads增量-9／-4，達門檻但仍上升，不宣稱無洩漏。雙目標8對單目標7程序；Dashboard平均Private Bytes約250.62→301.96MiB。暫停CPU平均0.0372%，較同主題雙目標Active下降86.82%，兩宿主推送／JS變化0、98筆有效GPU engine皆0；非瓦數或真正鎖定／關屏驗收。
- Precision：基線／單執行緒CPU／64MiB RAM及本機寫入各30同期窗口，CPU、RAM、PDH disk counter、實體網路自然流量均達預定容差；最大雙端點skew23.99ms、正式collector最大15.06ms。CPU平均絕對差<=0.2391百分點，RAM used<=0.7623MiB／total差0，disk<=0.01232百分點，RX／TX<=391.59／24.98B/s。這是同機系統來源交叉核對，非獨立儀器。GPU90筆unavailable/null，不代表NVIDIA實讀通過。
- Evidence／known limits：完整[報告](acceptance/2026-10-30/metrics-performance/REPORT.md)、原始JSONL／CSV／摘要／版本／hash與[圖表](acceptance/2026-10-30/metrics-performance/summary.png)。三組各1筆缺失資源／相鄰共6個CPU區間排除，資料完整性PARTIAL；第一輪38.626秒因CIM程序消失的工具失敗保留，非產品FAIL。前段有開發背景活動、非獨占主機，初版runner與後續修正差異、100ms觀察空窗與實際collector呼叫未觀測均明列，不推論因果成本。
- Cleanup／antivirus：五次正式退出0，33個已觀察核實WebView2子程序退出；不宣稱取得所有短命程序。原持續桌布83428的path／精確建立時間／hash不變、收尾唯一app，未重啟Explorer或替換原桌布。收尾日期混型比較誤判由原始ISO字串／DateTimeOffset重核排除。Apex One14.0.0.21008可讀BM日誌fingerprint未變，未觀察新增攔截，非完整防毒觀測；未改防毒設定，沒有已證實受攔截項目。
- NOT RUN／next：真正Locked／DisplayOff／睡眠／全螢幕、NVIDIA實讀與故障、網路高流量／介面消失、產品逐次collector呼叫、其他OS／Runtime／硬體、100次熱切換／更長soak、探針獨立因果增量見[人工清單](acceptance/2026-10-30/metrics-performance/MANUAL_CHECKLIST.md)，傳遞08／09；原03歷史FAIL保留。CI／重新打包／乾淨帳號／完整套件NOT RUN，留後票。ADR：無，產品架構與決策未變；07可依序接續。
- Review／commit：code-review兩軸工具初審各3項均修正、複查各0；最終結果見[REVIEW.md](acceptance/2026-10-30/metrics-performance/REVIEW.md)。本節與本票全部工具／證據同一次提交；commit-msg依暫存差異產生繁中Conventional Commit後push `origin/feature/rc-06-metrics-performance`，hash以該分支Git記錄為準，不合併main／公開發布。

## 2026-10-30 RC 05 — 接續完成桌面／電源矩陣與無回應復原

- Branch／base：沿用 `feature/rc-05-desktop-power-recovery`、HEAD `2a69ed18a649770359c03b76b1503cfd51262a0c` 與前輪未提交調查、`test-default-startup.ps1`、版本化證據，不另開分支。依 ticket 最新使用者確認決策，原啟動缺陷改記「未重現，疑似環境」，不追 Red、不做推測性啟動修正；03 歷史 FAIL 與 08 的乾淨環境前提保留。05 設 resolved，只表示可執行驗證與報告完成。
- Scope／TDD：擴充既有多宿主原生整合，原 HEAD 在雙宿主握手後真正 JS 無限迴圈 180 秒不復原，MetricsTick 仍前進，取得票內無回應 Red。web adapter 新增每五秒一個、至多一個 pending 的 JS 回應探針，Active 十五秒未回應沿既有世代檢查與三次重建／Minimal／停止路徑；非 Active 不計時，Shutdown 撤銷舊 callback。HealthTick 僅在 JS 回呼成功更新，原生日誌記世代／故障類型；採集、權限、智慧休眠預設及試用入口不變。
- Green／實機：修正版完整 power4 PASS；兩宿主約 91.66 秒完成 JS 無限迴圈的有界 Minimal 回復及新 JS 回應。手動暫停十七秒不誤判、受控 lock／unlock、renderer／browser 故障交錯、八輪有界停止、browser＋受控鎖定／手動暫停＋fixture 父視窗銷毀後雙屏新握手／矩形／JS 回應通過；雙屏選擇／保存／viewport／模式及三次正式退出共 19 個當下可觀察子程序通過。原生 NOACTIVATE／TOOLWINDOW／HTTRANSPARENT／唯一管理 HWND 有證據，不視為人工互動 PASS。
- 預設啟動回歸：新 EXE 單次全新 LOCALAPPDATA 約 1.18 秒 ReadyEpoch=1，觀測約三十秒、原生智慧休眠勾選=1、正式退出 0、6 個已驗證子程序退出、未知身分數 0。沿用前輪原版本兩輪證據，沒有重做或改寫；本輪不是 08 乾淨環境驗收。
- Commands／checks：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperParentFixture --parallel 8`，加入 HealthTick 後再建 DrillPaper；相關 `ctest ... -R '^(Power state|Sampling scheduler|Sampling worker|Desktop recovery|Manual pause|Monitor selection|Clone targets|Connected monitors|Protocol v1)'` 18/18；`pwsh -NoProfile -File scripts/test-multi-monitor.ps1 ... -DesktopPowerRecovery`、`test-default-startup.ps1 ...` PASS。工具入口 Red 2/2→Green 2/2、PS parser 3/3、Node syntax PASS；完整套件留 09。
- 環境／證據：Windows 11 Pro 25H2 26200.8737／Runtime 156.0.4314.50／SDK 1.0.2478.35，雙 1920×1080、DPI 144／96。非 Temp 使用者繁中／空白副本與隔離資料、Node 直接 spawn EXE；新 EXE SHA-256 `25316B5067076749295B62DB557748B6DC2D88C4069CFBBE4C48E93269F6D26D`，來源為 base＋本票工作樹，非新交付包。完整命令、原始 Red／各輪結果、時序、父子建立／退出與 hash 見 [接續報告](acceptance/2026-10-30/desktop-power-recovery/resume/REPORT.md)。
- 工具與審查：保留第一次套用智慧休眠後等待逾時（缺狀態證據，原因未定），第三輪無限迴圈局部成功後的 fixture 身分工具失敗也不算全輪 PASS；漏接 fixture 經 path／精確建立時間／handle 核對單獨清理。shared helper 補 UTF-8／DateTimeOffset／parent／CIM 精確時間及五秒 metadata 等待；兩個入口捕捉必填路徑錯誤並保留詳細日誌、子程序空／未知身分不宣稱清理成功。code-review 的 Standards 1／Spec 3 項均修正，複查未解決各 0，見 resume/REVIEW.md。
- 防毒／原桌布：Apex One 可讀行為日誌 hash／09:22:30 修改時間前後不變，未觀察新增攔截；不是完整防毒觀測，未改防毒。原持續桌布 83428 的 path、精確建立時間與 hash 前後相同，收尾為唯一 app，沒有 fixture；未關閉／替換、未重啟 Explorer。
- NOT RUN／gate：真正 Explorer／系統匣點擊、桌面圖示／工作列／Alt+Tab／焦點／虛擬桌面、全螢幕／部分覆蓋、拔插及其他解析度／DPI、真正鎖定／關屏／待機與其故障交錯、其他 Windows／Runtime，均依已確認決策附 [人工清單](acceptance/2026-10-30/desktop-power-recovery/MANUAL_CHECKLIST.md)。舊特定 Explorer 人工 PASS 保留，不外推到新配置。06 量測健康探針成本；08 在乾淨環境以產品預設握手通過後才移除繞行，並重包本票／04；09 承接本票 NOT RUN、首次逾時、03 歷史 FAIL 與完整回歸。CI／重包／全套 NOT RUN，留後票，不解除 RC gate。
- Commit：`fix(web): 為無回應主題加入有界復原檢查`，由 commit-msg 技能依 staged diff 產生；本節與本票程式／工具／證據同一次提交並 push `origin/feature/rc-05-desktop-power-recovery`。提交 hash 以該分支 Git 記錄為準；不合併 main、不公開發行。

## 2026-10-30 RC 05 — 預設啟動失敗未重現，停止未提交

- Branch／base：從 `2a69ed18a649770359c03b76b1503cfd51262a0c` 建立 `feature/rc-05-desktop-power-recovery`，停止時 HEAD 不變，05 維持 in-progress。已讀本票 2026-10-30 決策、03 防毒補記、spec、handoff、架構與 04 結果；前置 04 resolved。
- Scope／停止點：新增未提交的 `test-default-startup.ps1` 草稿及 [版本化證據](acceptance/2026-10-30/desktop-power-recovery/REPORT.md)。原失敗 EXE 的兩輪隔離啟動均握手，尚無可重現 Red；依使用者「前提不成立時停止、不 commit」停於根因診斷前。沒有改產品程式、智慧休眠預設、03 ZIP 或入口，不宣稱修復。
- 環境：Windows 11 Pro 25H2 26200.8737／Runtime 156.0.4314.50／SDK 1.0.2478.35，雙 1920×1080、DPI 144／96；非 Temp 使用者繁中／空白解壓路徑、Node 直接啟動 EXE、全新 LOCALAPPDATA。Apex One 可讀 AEGIS_BM.log hash／時間前後相同，未觀察新增攔截；不是完整觀測，也不判定歷史防毒介入為根因。
- 啟動觀察：原產品來源 `e6aa20e`、EXE `B0FF9A…71781`（trial.3／trial.4 相同）兩輪分別約 2.49／2.55 秒 ReadyEpoch=1，觀測至約 30 秒，正式退出 0、已觀察子程序 handle 均退出；第二輪原生管理智慧休眠勾選=1。HEAD EXE `AA4196…51D8E` 首次約 1.74 秒握手，但草稿清理入口誤用類別導致退出 -1，不列正常退出 PASS；另一輪 Windows PowerShell 5.1 身分檢查失敗無握手樣本，不算產品 Red。完整工具失敗／清理與限制見 REPORT。
- Commands／相關檢查：`pwsh -NoProfile -File scripts/test-default-startup.ps1 -ApplicationPath <原版本隔離副本> -EvidenceDirectory artifacts/acceptance/rc05-startup-original1`／`original2` 均退出 0；`ctest --preset windows-msvc-release -V -R '^Connected monitors '` PASS 1/1、12 assertions，只驗列舉。沒有以舊 metrics 標題宣稱畫面持續存活。
- NOT RUN：產品 Red／根因／最小修正、後續多宿主桌布幾何／全螢幕／故障交錯／無回應 renderer／暫停繼續，因第一步尚未達成而停止。真正 Explorer／系統匣點擊、桌面互動／焦點／虛擬桌面、拔插、鎖定／電源／睡眠及其他 Windows／Runtime 的人工清單留 REPORT；完整套件留 09。產品重新建置／封裝與 code-review／commit-msg／commit／push NOT RUN，因未達可提交完成狀態。
- 後續／gate：03 原 FAIL 不因本輪未重現解除，08 不據此移除繞行，09 gate 保留。需要原失敗時的前景／電源／工作階段／載入時間線／防毒等重現條件，或確認環境／時序調查方向後續作。收尾只剩原持續桌布 83428，精確 path／StartTime／hash 不變，未操作替換、未重啟 Explorer。
- Commit：NOT RUN，依使用者停止規則保持未提交／未推送；本票尚未完成。

## 2026-10-30 RC 04 — 接續完成有界安全矩陣與 SmartScreen 修正

- Branch／base：沿用 `feature/rc-04-security-matrix` 與 HEAD `1c62cc41e54a642f5ae5ed0d723e9b0893cef542` 的未提交測試／證據，不另開分支。依票內確認決策續作；04 設 resolved，代表有界可執行驗證與報告完成，安全 PARTIAL／NOT RUN 不因此放行 RC。
- Scope：web adapter 每個 controller 導覽前以 Settings8 關閉信譽檢查；介面或設定失敗走既有 ReportFailure。保留原測試擴充，新增可重現的 NetLog POST 檢查及 ADR 0005／安全文件／接續證據；沒有改防毒、系統代理、全域 SmartScreen、採樣／休眠或正式 RC gate。
- TDD：先對原三份實機 NetLog 執行檢查取得 Red（19 次 SmartScreen POST 嘗試，HTTP/2 送出 57489 bytes，含原 telemetry 4510／4619），再最小修正並建置。新三份 NetLog Green：Minimal、HTTP／HTTPS off→on→off、管理／獨立重啟，SmartScreen POST 嘗試 0、送出 0 bytes；POST 嘗試即 FAIL，比只看實際傳輸更嚴格，僅聲明指定觀測時段。
- PASS／commands：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperSettingsTests DrillPaperThemeTests --parallel 8`；新 EXE 的 `test-webview2-security.ps1`、`test-multi-monitor.ps1`；相關 CTest 15/15（新建置後）；5 個 JS／3 個 PS parser。完整命令、原始 log、父子 PID／時間／退出碼及 hash 見 [接續報告](acceptance/2026-10-30/security-matrix/REPORT.md) 與 resume/。
- 環境：Windows 11 Pro 25H2 26200.8737／WebView2 156.0.4314.50／SDK 1.0.2478.35；兩個 1920×1080、DPI 144／96。新 EXE SHA-256 `AA41960045CBDDE7B6EDB585A84D7E92E235C215C202137EEA4A9AB023151D8E`，未提交工作樹來源；trial.4 解壓至非 Temp 使用者繁中／空白路徑並替換 EXE，非新交付 ZIP。03 原 ZIP／EXE 不變，08 必須重包。
- 背景／安全限制：SmartScreen 關閉有失去惡意網站／下載信譽保護的代價；仍觀察到 WPAD 與 Edge ECS GET，後者 query 含識別／版本資訊，衍生摘要已去除值。依確認決策逐項歸因，不宣稱整個 app 零外連／零背景資料傳送；未證實 ECS 可否由 app 關閉，不擅改額外政策。
- 防毒／清理：Trend Micro Apex One 可讀 AEGIS_BM.log 修改時間仍 09:22:30，未觀察本輪新增攔截；未改防毒設定。原持續桌布 PID 83428 path／StartTime／hash 前後相同且收尾為唯一剩餘 app，未關閉替換、未重啟 Explorer。
- PARTIAL／NOT RUN：DNS／prefetch、真正舊 controller COM 訊息送達、外部 URI handler／其他設備／TURN-UDP／TLS／其他介面／proxy／OS／Runtime／escape、人工畫面均保留報告限制與接續清單。雙目標此輪不擷取 NetLog，不外推背景流量。全套測試留 09、CI／重包／乾淨帳號留後票；05 智慧休眠缺陷未修，08／09 gate 保留。
- Review：依 implement 的 code-review 技能做 Standards／Spec 平行審查，工具入口錯誤與缺 capture 日誌兩項皆補 Red→Green；三項工具測試 3/3，完整原／新 NetLog 重播仍為 Red／Green。兩軸複查未解決各 0，詳見 resume/REVIEW.md；最終語法檢查含 6 個 JS／3 個 PS。
- 工具相容性：Windows PowerShell 5.1 parser 另重現新增 helper 缺 UTF-8 BOM，補標記後三個 PS 腳本通過；Red／Green log 保留，沒有變更產品 EXE 或重做實機證據。
- Commit：`fix(web): 關閉 SmartScreen 信譽檢查並補安全矩陣`，由 commit-msg 技能依實際 staged diff 產生；本票單次提交並 push `origin/feature/rc-04-security-matrix`，交付時核對遠端與本機相同。不合併 main、不公開發行。

## 2026-10-30 RC 04 — 無遙測決策衝突，停止未提交

- Branch／base：從乾淨 HEAD `1c62cc41e54a642f5ae5ed0d723e9b0893cef542` 建立 `feature/rc-04-security-matrix`；03 implemented。本票維持 in-progress／BLOCKED，依使用者「決策與現況衝突即停止、不 commit」規則，**未 commit、未 push**。
- Scope／files：先記有界矩陣；未提交測試草稿新增 Node 直接啟動與身分／退出紀錄、隔離 NetLog、camera／microphone 實際呼叫、HTML 管理命令拒絕、TLS preconnect／DNS hint／prefetch、雙目標快速切換與舊世代通知；新增本票報告／證據及 ticket Comments。沒有修改產品 src/include、沒有停用 SmartScreen、防毒或變更全域設定。
- **衝突／BLOCKED**：handoff §7.7 要求「無遙測、無背景上傳」；WebView2 在內建 Minimal、網路預設關閉時，仍 POST 4510 bytes 至 `telem-edge.smartscreen.microsoft.com/api/browser/edge/telemetry/3`（09:38:57.157+08:00），最後關閉階段另 POST 4619 bytes（09:39:36.485+08:00），均 HTTP 200。由同 HTTP/2 source／stream 的 SEND_HEADERS／SEND_DATA／RECV_HEADERS 確認，並非只有請求嘗試。這是瀏覽器自身流量，不等於證實上傳系統指標；不自行將無遙測範圍限縮為 C++。停止後只保存證據／狀態與核對程序，待要求釐清。
- 環境／版本：Windows 11 Pro 25H2 **26200.8737**、WebView2 **156.0.4314.50**、兩個 1920×1080／DPI 144／96；trial.4 ZIP SHA-256 `C3ECF566EAB58D4A015D44D749E60F1E6872F5830F31AEB0F3B303ECC40C3287`，EXE `B0FF9A734713AF939C6444092B6D008DEDEF9480A17932D1B4B9D92C0FE71781`。產品來源 e6aa20e，EXE 解壓於 `%USERPROFILE%/DrillPaperTests/安全矩陣 含空白/20261030-093658`，逐檔核對 manifest；測試工具為本票未提交工作樹，不冒稱相同來源 commit。
- PASS（已執行範圍）：相關 CTest **15/15**；相關 targets 建置／JS syntax／PS parser；既有與擴充安全、HTTP／HTTPS off→on→off、管理／獨立重啟、實際 getUserMedia／定位／通知拒絕、三種 HTML 管理命令拒絕與 snapshot 正向控制；HTTP／TLS preconnect 於關閉零新增、開啟收到 TLS ClientHello；雙目標來源／Cookie、20 次快速切換、目標停用、fixture crash 重建、舊／跨宿主原生通知無法改新世代／偏好且指標持續、正式退出與已觀察子程序清理。TDD：未重現票內產品缺陷，沒有偽造 Red 或修改產品。
- PARTIAL／NOT RUN：DNS hint 只有指定主機的 NetLog 正向／負面觀測，沒有受控 DNS／全介面接收端；prefetch 未建立獨立判準；舊頁面排程與原生通知不代表所有舊 COM callback race。外部 URI handler／其他設備、TURN-UDP／TLS、其他介面／proxy／Windows／Runtime、瀏覽器／OS escape、人工 GUI 均依報告原因維持未驗。完整套件留 09；CI／code-review／commit-msg／commit／push 因停止規則 NOT RUN；停止後未重新執行剛建置的 CTest binary 或最後 phase 格式微調的安全腳本。
- 防毒／清理：Trend Micro Apex One，PccNTMon 14.0.0.21008；本輪未觀察新增攔截，可讀行為日誌仍最後修改 09:22:30（03 的 Temp／PowerShell 舊事件）。未修改防毒；原持續桌布 83428 路徑／建立時間不變且為唯一剩餘 DrillPaper；未關閉／替換，未重啟 Explorer。
- Commands／results／next：完整矩陣、命令、hash、去除敏感標頭的背景上傳證據及 03 試用限制、08 重新打包／政策、09 gate 影響見 [RC 04 報告](acceptance/2026-10-30/security-matrix/REPORT.md)。無遙測適用範圍釐清前不續作、不完成 ticket、不解除 gate；沒有合併或發布。

## 2026-10-30 RC 03 — 接續完成首次試用包

- Branch／base：沿用 `feature/rc-03-trial-package` 既有未提交工作；開始 HEAD `fe292da667a94adfa0bf7c0de87dd14bca08a579` 僅比產品來源多決策文件。產品仍為上輪乾淨建置的 `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53`，不重建產品、不另開分支。ticket 設 implemented，代表已確認的試用範圍完成。
- Scope：依兩條 2026-10-30 決策，入口 `--management --no-smart-sleep` 沿用保存模式；繁中說明補智慧休眠限制與保存語意，測試補首次主屏桌布／保存 Preview 後同入口重啟及非同步等待。沿用白名單、建置／封裝腳本、授權與獨立 trial CI；未改 src/include／CMake／正式 RC gate。
- 新產物：`artifacts/DrillPaper-0.1.0-trial.4-win-x64-unsigned.zip`（434303 bytes），ZIP SHA-256 `C3ECF566EAB58D4A015D44D749E60F1E6872F5830F31AEB0F3B303ECC40C3287`；EXE SHA-256 `B0FF9A734713AF939C6444092B6D008DEDEF9480A17932D1B4B9D92C0FE71781`。trial.1～3 保留，trial.3 hash 不變；產品來源與未提交工具／模板分開記錄 hash，不冒稱同一來源。
- PASS／commands：`scripts/test-trial-package.ps1` 的白名單、私有設定排除、逐檔／EXE／ZIP hash、缺檔／空檔／junction／覆寫拒絕；相關 targets 編譯與 CTest **13/13**；`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-trial-app.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.4-win-x64-unsigned.zip` 完整通過。完整產包／build／CTest 命令及原始證據見 [REPORT](acceptance/2026-10-29/trial-package/REPORT.md)。
- 真實新 ZIP PASS：一般使用者、來源樹外含繁中／空白路徑、全新隔離資料，首次唯一 Minimal 桌布宿主附掛主屏 `(0,0)–(1920,1080)`、ReadyEpoch=1；保存 Preview 後同入口重啟 parent=0／ReadyEpoch=1 且設定 hash 不變；雙主題、管理保存／取消／重啟／退出、多目標與網路 off→on→off、已觀察子程序清理。WebView2 156.0.4314.50、Windows 11 26200.8737、VC++ 14.52.37025.0；原桌布 83428 路徑／建立時間／hash 相同，未關閉替換，未重啟 Explorer。
- TDD／工具：舊 trial.3 對新需求取得 Red，新入口以 trial.4 Green；中間宿主／附掛等待競態及 PowerShell 5.1 UTF-8 BOM 解析問題修正，另保留一次 Start-Process 存取被拒（原因未定，診斷與同 ZIP 最終重驗可正常執行），不把工具失敗當產品結論。code-review Standards／Spec 平行審查及最終文件複查未解決各 0。變更腳本解析／UTF-8 BOM、REPORT 本機連結通過；暫存後 whitespace 檢查排除保留原文空白的 WebView2 license 與原始 stderr log，其餘通過，完整指令見 REPORT。
- **FAIL 持續**：預設智慧休眠開啟的原啟動未握手缺陷未修，app 預設不變；已於 05／08／09 Comments 明列。05 診斷最小修正，08 移除繞行並回到產品預設重包重驗，09 持續 gate；本票關閉智慧休眠的 PASS 不解除 FAIL。
- NOT RUN／原因：人工畫面／真正系統匣點擊、乾淨一般使用者與真正缺 Runtime／備份還原、04～07 完整矩陣留後票；CI 與正式 RC gate 未執行；完整測試依指示留 09。人工操作清單見 REPORT，不宣稱完整沙箱／省電／RC，不合併 main、不公開發行。
- Commit：`build(trial): 新增可攜式試用包與驗證流程`，由 commit-msg skill 依 staged diff 產生；本票單次提交，隨即 push `origin/feature/rc-03-trial-package`，交付時核對遠端與本機指向相同 commit。

## 2026-10-29 RC 03 — 試用封裝前提不成立，停止未提交

- Branch／base：從 `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53` 建立 `feature/rc-03-trial-package`，起始乾淨；01／02 implemented。本票 ticket 維持 in-progress，**未 commit／push**，遵守使用者前提不成立即停止的指示。
- Scope／files：新增乾淨 commit archive 的 Release app 建置、JSON 白名單封裝、逐檔／EXE／ZIP hash、依賴啟動入口、授權與繁中使用說明、獨立 trial CI 草稿及相關測試。src/include／CMake／正式 package.ps1 與 windows.yml 沒有改動，RC gate 保留。
- PASS：缺 EXE Red→Green；封裝清單／排除私有設定／hash／覆寫拒絕／缺 SDK／空檔／junction；相關 targets 編譯與 CTest **13/13**。Standards 審查找到缺最低 runtime 版本未 fail-fast，補失敗案例後修正，複查未解決 0；Spec 0。只跑相關測試，命令與原始證據見 [REPORT](acceptance/2026-10-29/trial-package/REPORT.md)。
- **FAIL／阻擋**：來源樹外含繁中／空白路徑、一般使用者 token、全新隔離資料，預設入口 `--management --preview` 30 秒後 ReadyEpoch=0，通知／管理／Preview 各 1、parent=0、網路=0。trial.2／trial.3 皆觀察到；停用智慧休眠並重新套用後可握手，但同時有重新載入，根因未定，不視為預設啟動 PASS。已移除自動繞行測試，不擅改產品預設；可能涉及 05，記本票 Comments 待決策。
- 控制條件下 PASS：管理保存／取消／重啟／正式退出、兩內建主題握手、多目標／模式／網路 off→on→off／全斷線提示與已觀察子程序退出；這些均不解除預設啟動阻擋。WebView2 Runtime 156.0.4314.50、Windows 11 build 26200、VC++ 14.52.37025.0，非乾淨帳號或畫面驗收。
- 未驗收草稿：`artifacts/DrillPaper-0.1.0-trial.3-win-x64-unsigned.zip`；ZIP SHA-256 `4CA2300347C77BB37B18DA4B329A940B760564E60DD880504A3BA6B8359C6E69`，EXE `B0FF9A734713AF939C6444092B6D008DEDEF9480A17932D1B4B9D92C0FE71781`。產品來源為起始 HEAD，工具為本票未提交工作樹，另記 hash；不是已交付的試用包、RC 或公開發行。
- 隔離／收尾：乾淨來源／build 原位置移為 offline；解壓與 LOCALAPPDATA 使用本輪獨立路徑。原持續桌布 83428 的路徑、建立時間與 hash 前後一致，未關閉／替換，未重啟 Explorer；收尾只剩原桌布。
- NOT RUN：預設啟動根因及修正後重驗、人工畫面／真正系統匣點擊、乾淨使用者／缺 runtime、04～07 完整矩陣、CI 與正式 RC gate、09 完整測試。已附原因及人工清單；停止後未重跑最終移除繞行的測試包裝腳本。下一步先確認阻擋歸屬，再繼續本票；Commit：無（使用者停止規則）。

## 2026-10-29 RC 02 — 固定 800×600 設定視窗

- Date／branch／base：2026-10-29，從目前 HEAD `0c97d4fdda3881a3d11bc7f93d7fc12829749f56` 建立 `feature/rc-02-fixed-settings-window`，起始工作樹乾淨。前置 01 implemented；本票需求與 seam 先記於 FIXED_SETTINGS_WINDOW.md，未發現決策與現況衝突。
- Scope／files：platform/windows ManagementShell 固定 800×600 DIP、跨 DPI 精確換算、最大化／尺寸限制、主題／螢幕兩欄、長錯誤與完整識別捲動、無名稱路徑縮短、鍵盤導覽；新增 Windows 原生管理測試與 CMake target，更新票據、README／需求／交接與驗收報告。不改 composition 保存、主題或網路政策。
- TDD PASS：尺寸、最大化、長訊息、Tab 吞鍵與大小寫裝置標籤均先失敗後修正；原生管理最終 5 cases／776 assertions（含畫面證據）。Standards／Spec 平行審查及複查未解決項各 0；修正擷取測試失敗路徑的 RAII 清理。工具編譯／擷取及 oracle 中間失敗另記報告，不計 PASS。
- Build／typecheck／相關測試 PASS：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperManagementIntegrationTests DrillPaperSettingsTests DrillPaperTests --parallel 8`；相關 CTest `-R '^Management |Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause'` 13/13。命令與原始 red／green／build log 見 [報告](acceptance/2026-10-29/fixed-settings/REPORT.md)。未跑完整套件。
- Windows 原生／畫面：Windows 11 Pro 25H2 26200.8737、兩個 1920×1080、DPI 144／96；實測用戶區 1200×900／800×600，控制項在範圍內且不重疊。100%／150% fixture WM_PRINT（含長文字）及真實 app 150% PrintWindow PNG 已檢視，主要操作可見。WM_PRINT 非客戶區外觀不是實際 DWM 標題列或人工點擊證據。
- Management／monitor／security PASS：既有 `test-management-shell.ps1 -Desktop`、`test-multi-monitor.ps1`、`test-webview2-security.ps1`；包含唯一視窗重開、關閉隱藏、保存／取消／重啟、目標單／雙選、模式／暫停、HTTP off→on→off、首次提示與腳本所列安全邊界、已觀察子程序退出。最終 app SHA-256 `68CC8BDFDA3593046777D412298D6E1B7F5B92A77F6B93B161E74396F763CBD0`；本輪實際 Runtime **156.0.4314.50**（登錄及隔離 profile 核對），不沿用 01 的 155 結果，不宣稱完整沙箱。
- NOT RUN／blockers：真實鍵盤／系統匣點擊／匯入移除確認、小工作區實機、其他 DPI／Windows；Computer Use 原生管道 os error 2，按已確認決策附人工清單留後續，不中斷本票。真正 Explorer／實體拔插／電源／硬體／長測為後票；完整套件留 09，CI／打包 NOT RUN。本票不產 ZIP、不合併 main、不解除 RC gate。原持續桌布 83428 固定副本未關閉或替換，未重啟 Explorer。
- Ticket／next：02 設 implemented，表示程式與可自動驗證範圍完成，人工矩陣保留；03 首次試用打包尚未開始。
- Commit：`feat(settings): 新增固定尺寸與 DPI 適配的設定視窗`；依 commit-msg skill 檢視實際差異產生，本票一次 commit 並 push `origin/feature/rc-02-fixed-settings-window`。

## 2026-10-29 RC 01 — 多螢幕套用管理

- Date／branch／base：2026-10-29，從 HEAD `7806266` 建立 `feature/rc-01-multi-monitor`；工作樹原乾淨。票 `.scratch/rc-delivery/issues/01-multi-monitor.md` 設為 implemented，代表程式及可自動執行驗證完成，人工矩陣未宣稱通過。
- Scope：穩定 monitorDevicePath、source clone 群組、實體幾何／逐屏 DPI；schema 2 原子保存與主屏遷移；目標草稿／取消／未連接清單；部分斷線不補位、全斷線明確提示暫用主屏不改偏好；每區域獨立 HWND／controller／重試／逾時，Preview 唯一；全域主題／網路／快照／暫停／電源／退出廣播，世代與來源隔離。調查／測試 seam／人工清單先記錄於 MULTI_MONITOR.md，與已確認決策無衝突，沒有新 ADR 或逐屏權限。
- Files：app composition／SettingsStore、platform/windows monitor_info／desktop_host／management_shell、runtime monitor_targets、WebView2 載入／DPI／訊息隔離、CMake、相關 unit／原生 integration／PowerShell probes，及 ticket／需求／README／架構／交接與驗收文件。
- Build／typecheck PASS：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperSettingsTests DrillPaperMonitorIntegrationTests DrillPaperWindowsHostIntegrationTests --parallel 8`。精確相關 CTest `-R` 命令與 log 見 [報告](acceptance/2026-10-29/multi-monitor/REPORT.md)，25/25 PASS。Settings 5 cases／29 assertions、目標解析 2 cases／13 assertions；保存遺失、解析、clone、設定容量／空目標、主題重選復原均有 Red→Green，未捏造既有保護的 Red。
- Windows 原生 PASS：Windows 11 Pro 25H2 build 26200.8737、WebView2 155.0.4283.62；兩屏 `(0,0)–(1920,1080)` DPI 144 與 `(1920,0)–(3840,1080)` DPI 96。單／雙選、取消保存、原設定重啟、獨立 HWND／完整矩形、Minimal／Dashboard 握手、JS viewport×DPR 完整覆蓋、暫停／模式、19 個已觀察子程序退出、單目標故障／跨世代拒絕及 HTTP off→on→off 與來源隔離。各 HWND／附掛／世代／截圖見報告。
- Recovery PASS（受控）：雙屏跨程序 fixture 父視窗 crash 後全部重建；`test-desktop-host.ps1 -DestroyParent -ParentExit crash -NoRecoveryNotification -RecoveryCycles 2` 單屏無通知復原；`test-renderer-recovery.ps1 -Crashes 4 -ReselectBeforeFinal` 選題額度重設與新握手。不是 Explorer 重啟或人工畫面證據。
- Management／security PASS：`test-management-shell.ps1 -Desktop` 與 `test-webview2-security.ps1` 完成相關回歸；150% 管理 PNG 已檢視，底部按鈕可見。既有 HTTP／HTTPS／來源儲存／worker／導覽復原／WebRTC／preconnect 等僅聲明腳本所列範圍，不宣稱完整沙箱。受測 EXE hash `CE7223F45B2EE7BE94E4C1EDD0F71BF107D2290C4ABA9A7E30F69D5320028774`，最終結果 JSON hash 一致。
- Review：依 code-review skill 做 Standards／Spec 平行審查，修正管理視窗過高、重選主題額度、設定讀寫容量不一致及錯誤轉碼等；兩軸複查未解決 finding 0。開發中另校正測試的智慧休眠前提、宿主建立等待及主題顯示名稱 oracle，失敗不算 PASS。
- NOT RUN／blockers：真正新版 Explorer、人工桌面畫面與完整圖示／工作列／系統匣操作、實體拔插／接回、主屏變更、負座標／不同解析度／clone／其他 DPI／Windows；依使用者指示附人工清單後留待後續，未重啟 Explorer。真實電源／NVIDIA／乾淨環境／長時間效能及完整安全矩陣另票處理。完整測試套件留 09 收尾，CI／打包 NOT RUN；本票不產 ZIP、不合併 main、不解除 RC gate。
- Next：02 最終固定 800×600 設定版面；本票暫用 600×600，超長裝置路徑列截斷記入本票 Comments 供 02 處理。原持續桌布 83428 固定 a241856 副本未關閉／替換，測試程序已退出。
- Commit：`feat(monitors): 新增多螢幕目標管理與獨立桌布宿主`；本票完成後依 commit-msg skill 產生，僅 commit 一次並 push `origin/feature/rc-01-multi-monitor`。

## 2026-10-29 建立剩餘工作 9 張 tickets — 先試用打包再補驗收

- Scope：使用者指示「建立ticket」，依已確認順序 1 → 2 → 7A → 3～6 → 7B → 8 建立 .scratch/rc-delivery/spec.md 與 issues/01～09。每票列出範圍、前置依賴、驗收與 Comments，初始 open；保留多螢幕既有 spec 並連結唯一實作票。
- 明確化：設定用戶區固定 800×600 邏輯尺寸；7A 為完成多螢幕／設定後的首次試用 ZIP，7B 沿用流程納入修正並驗乾淨一般使用者交付，09 才判定 RC。打包與 CI 綠燈不代替安全／實機 gate。
- 基準：main b4616ec，工作樹原乾淨；新建 feature/rc-delivery-plan。已完成的舊功能分支先前已清理，不因多螢幕規劃誤稱有未完成程式分支；本輪不合併 main、不發行。
- PASS：核對 issue-tracker／triage 慣例、既有 spec／架構／交接與驗收缺口；git diff --check 通過。9 票數量／open 狀態／必要欄位及前置票順序均有效，20 個本機 Markdown 連結存在；無產品變更。
- NOT RUN：產品／GUI／多螢幕／安全／硬體／打包與完整測試（本輪僅文件與工作規格，無產品變更）；未啟動或操作桌布／Explorer／顯示配置。新票未完成，RC gate 保留。
- Commit：`docs(plan): 建立功能打包與驗收九張工作票`，依 commit-msg skill 檢視實際差異產生後立即 commit＋push origin feature/rc-delivery-plan。

## 2026-10-29 完成分支整合至 main — 使用者授權合併

- main 整合與交接提交 `0f548ae` 已推送 origin/main；實際 [CI 40848448010](https://github.com/act70255/DrillPaper/actions/runs/40848448010) PASS：乾淨 Windows configure／build、CTest 33/33（1.96 秒）、SDK 18/18、SDK 還原／封裝與 artifact，RC job skipped。證據為 acceptance/2026-10-29/main-integration/ci.json／log，完整原始 log 在 artifacts/acceptance/main-integration-ci.log。最後僅保存結果的文件提交不改產品，使用 commit-msg skill 產生 `docs(ci): 保存 main 分支整合驗證結果` 後推送。
- 使用者最新指示「把完成的分支合併到Main」，取代先前本輪不合併 main 的限制。先 fetch origin 並核對乾淨工作樹；main／origin/main 原為 5697bf7，feature/tray-management 為 bec20d4，落後 33 個提交且無分歧。
- 已以 `git switch main`、`git merge --ff-only origin/main`、`git merge --ff-only feature/tray-management` 完成本機快轉整合，保留原提交歷史。16 個現有功能／修正分支及所有遠端分支均為該來源分支的祖先，`git branch --no-merged main` 為空；分支與其他 worktree 保留。
- 產品程式與既有 62f01ab 實測版本相同；此前 6672610 的 CI 40840814142 通過 CTest 33/33、SDK 18/18。多螢幕只有 planned spec，完整安全／相容性等 NOT RUN 與 RC gate 保留，合併不代表產品已可發行。
- 本輪本機產品／GUI 測試 NOT RUN（純快轉整合及交接文件，沒有衝突或程式改動）；已核對原持續桌布 83428 固定副本路徑，未操作／替換。推送 main 後另確認主分支 CI，不由前版結果代替。
- 文件 Commit：`docs(status): 記錄完成分支整合至 main`，依 commit-msg skill 產生後 commit＋push origin main。

## 2026-10-29 多螢幕需求收斂 — 勾選目標、每屏完整桌布

- 使用者指定不做跨螢幕拼接，改為選擇哪些螢幕套用，每個目標各顯示一份完整桌布。新增 .scratch/multi-monitor/spec.md（planned），沿用同一全域主題，未選螢幕保留 Windows 桌布；保存目標與基本螢幕／Explorer 生命週期另於實作前具體化。
- 同步剩餘工作、總交接、相容性矩陣與原管理 spec，區分「選擇目標螢幕」和仍不納入的「逐螢幕不同主題」。不將需求整理寫成已實作。
- 驗證：文件差異與 `git diff --check`。產品／GUI／多螢幕測試 NOT RUN（僅整理需求，未改程式或顯示配置）；原持續桌布未操作，不合併 main。
- Commit：`docs(plan): 定義目標螢幕各自顯示完整桌布`，依 commit-msg skill 產生後 commit＋push。

## 2026-10-29 剩餘工作分類 — 多螢幕列為必要完整性功能

- 使用者明確要求「多螢幕情境也需要先列為必要的完整性功能」。新增 REMAINING_WORK.md，將必要多螢幕與 app 交付收尾、既有驗證缺口、補充功能分開；同步 FINAL_HANDOFF、相容性矩陣與管理 spec 的範圍界線。
- 多螢幕須調查／補齊實作與對應驗收，不只列為相容性待測，也不列為選配。呈現方式與逐螢幕操作細節於實作前具體化；本次沒有新增逐螢幕不同主題等未定義功能。
- 驗證：文件差異核對、`git diff --check`。產品／GUI／多螢幕測試 NOT RUN（本次僅調整需求分類，未改程式或顯示配置）。不操作原持續桌布，不合併 main，RC gate 保留。
- Commit：`docs(plan): 將多螢幕列為必要完整性功能`，依 commit-msg skill 產生後 commit＋push feature/tray-management。

## 2026-10-29 本輪驗收結案 — 最後新增測試 CI 通過

- 驗收／測試提交 `6672610` 的 [CI 40840814142](https://github.com/act70255/DrillPaper/actions/runs/40840814142) 完成且 PASS：Windows configure／build、CTest 33/33（1.95 秒）、SDK 18/18、固定 SDK bootstrap／封裝及 artifact。release-candidate job 預期 skipped，未發行、未合併 main。
- metadata／節錄：management/remaining-final-ci.json／log；完整原始 log：artifacts/acceptance/6672610-ci.log。產品程式仍為 62f01ab（hash 8AACD0…），後續測試與文件提交未改產品，所有原生／人工 hash 界線見 REMAINING.md。
- 本輪三項修正、指定擴充安全、真正新版 Explorer 人工結果與完整回歸均已各階段提交推送。完整 DPI／DNS／其他安全與 MVP 未驗矩陣照列 NOT RUN，A12／RC gate 保留，不宣稱完整沙箱。
- 收尾只留下原持續桌布 PID 83428，固定 a241856 程序路徑未變；測試 app 已正常退出。Nowledge Mem 無法連線，ADR 0002–0004 與驗收文件為本輪可接續紀錄。
- 本次僅保存 CI 結果及更新交接，產品測試 NOT RUN（沒有產品改動；已核對實際 CI）。Commit：`docs(acceptance): 記錄剩餘驗收 CI 通過`，依 commit-msg skill 產生後 commit＋push。

## 2026-10-29 剩餘驗收收尾 — 新版 Explorer 人工通過

- 使用者確認「新版畫面恢復且持續更新，圖示／工作列可用」。受測產品 62f01ab，EXE hash `8AACD05B50BEDF89E2F191B14986E3A1AB380A60B075C0CA5097DDAE539176D1`，Windows 11 Pro 25H2 build 26200.8737、Dashboard mock／no-smart-sleep。隔離資產僅 h1 增加「新版管理驗收 62f01ab」識別，hash 另存，沒有修改原桌布。
- 真正 Explorer：Shell 98068→93396，同一受測 app PID 85932，HWND 1376352→1054746，DesktopEpoch 2→3、ReadyEpoch 2→4、新 metrics 1493736796、TrayRegistered=1。人工結果補足畫面與圖示／工作列，不外推 Alt+Tab／虛擬桌面或其他 Windows。腳本原始 visual=NOT RUN 是自動腳本的範圍，人工結論另存 remaining-user-confirmation.json。
- PASS：最終管理生命週期／設定／重啟及已觀察子程序清理；新增 VisualObservationSeconds 供真正重啟後保留人工觀察時間，並以父子建立時間及預先持有 handle 排除 PID 重用。150% 管理 PNG 已檢視，控制項／文字未裁切；先前人工鍵盤／取消／唯一視窗的原始回報與 hash 一併保存。
- PASS：62f01ab 完整 Release build、`test.ps1 -Configuration Release`，CTest 33/33（26.08 秒）、SDK 18/18 及封裝／環境／採樣器／負面 oracle。原生受控 runtime 1 次＋50 次快速往返、custom-entry renderer crash 3 次、主題切換 100 次＋已安裝主題握手皆通過；不是新一輪真實鎖定／睡眠、像素切換或洩漏結論。
- PASS：62f01ab [CI 40839289477](https://github.com/act70255/DrillPaper/actions/runs/40839289477)，CTest 33/33、SDK 18/18、SDK 還原與封裝。metadata／節錄另存 62f01ab-ci.json／log；完整原始 log 位於 artifacts/acceptance/remaining-final-ci.log。
- 追加 preconnect 負面回歸：舊 F0238D… 在網路預設關閉仍多一筆 loopback TCP；現有 Connection-Allowlist 的同測試通過，開啟時另有瀏覽器正向控制、再次關閉時無新增 TCP。未再更改產品。安全 session security-afe8952ca34242c28adce0b05c1e2c0c，含既有 HTTP／HTTPS／WS／WSS／STUN／TURN-TCP、儲存／worker／導覽回復及兩種重啟，詳見 remaining-security-result.json。
- NOT RUN：完整 DPI（使用者回報固定視窗無法拖曳縮放，沒有做 Windows DPI 更動）、全部 DNS／推測連線／瀏覽器背景流量、TURN-UDP／TLS、其他 Runtime／權限設備 API／scheme／舊頁面競態，以及其他 MVP 硬體／電源／相容性與乾淨安裝 gate。A12 與 RC gate 保留，不宣稱完整沙箱。
- 原持續桌布 83428 路徑仍為固定 a241856 副本；真正重啟後 ReadyEpoch=4、parent=93396、兩秒 metrics 1493809578→1493811593。未關閉／替換，舊 A04 PASS 保留；新管理程序正常退出。證據、命令與限制見 REMAINING.md。
- Commit：`test(acceptance): 補齊新版管理與安全回歸證據`；依 commit-msg skill 產生後立即 commit＋push。新增測試檔的 CI 會在推送後另觸發，不把上述產品版本 CI 寫成尚未執行的提交。

## 2026-10-29 安全續驗 — 失敗導覽回復與擴充矩陣

- Scope／Red→Green：worker 遭拒後外部頂層導覽雖無流量，WebView2 卻提交 chrome-error 空白頁。獨立 security-z-navigation 先訂閱、導覽、再次訂閱，舊 DF658C… 固定副本精確 FAIL。改監聽失敗 NavigationCompleted 與實際 Source，以載入世代通知 app 切回可信 Minimal，不寫回保存偏好；Minimal 自身失敗則停止 renderer，保留管理與友善錯誤，避免迴圈。詳見 ADR 0004。
- PASS：Release app build；同一獨立導覽案例於網路 off→on→off 通過，原頁面繼續或可信 Minimal 完成新訂閱，navigate endpoint 無收件。hash `8AACD05B50BEDF89E2F191B14986E3A1AB380A60B075C0CA5097DDAE539176D1`，session security-ddad2d5848c94edfb672e3d87d1ff809。
- PASS（相同實機腳本）：IndexedDB／Cache Storage 各有當前來源讀寫正向控制且後續載入不重用；host-only Cookie／父網域 Cookie／localStorage／sessionStorage；Dedicated／Shared／ServiceWorker 明確拒絕；camera／microphone 查詢為 denied。STUN UDP 與 TURN-TCP／WSS 的接收端僅原生控制各一筆，無主題收件。HTTP／HTTPS、其他既有負面、管理／獨立重啟仍通過。不把權限狀態查詢推論為所有設備 API 已測。
- 診斷：先後排除只要求例外、頂層 await／worker 清理等測試假設；NavigationStarting 後額外 Stop 無效，已撤回。隔離 CDP 實際讀到 chrome-error Frame（暫態 Stop 嘗試 hash FB7418…）；未在原桌布開啟偵錯。原始過程在 artifacts/acceptance/expanded-*，navigation-error-frame.jsonl 與精確 Red／Green／封包及請求證據已保存。
- 測試判斷另核對實際探針主題，防止 Minimal fallback 冒充資源案例成功；資源與導覽分為兩個真實匯入主題，導覽允許原頁面存活或立即安全回復。
- NOT RUN：完整 DNS／preconnect／推測連線、TURN-UDP／TLS／其他 Runtime、舊頁面訊息競態、完整權限／scheme 與整體 RC。管理／Explorer、完整回歸與本版 CI 接續執行；d3a24dc 的 CI 40837047952 已成功，但不代替本次修正。原持續桌布 83428 路徑未變。
- Commit：`fix(web): 復原遭政策拒絕的頂層導覽`；依 commit-msg skill 產生後立即 commit＋push。

## 2026-10-29 剩餘安全驗收 — WebRTC/STUN 缺口修正

- Red→Green：新增真實 RTCPeerConnection data channel／ICE，舊 F0238D… 固定副本在網路關閉時收到三筆 STUN UDP（20 bytes、magic cookie 符合），精確失敗於「預設網路關閉時 WebRTC 仍傳送 UDP／STUN 封包」。不需音訊／視訊，也不由權限拒絕推論網路封鎖。
- 最小實作：所有宿主資產回應加 Connection-Allowlist；只允許自身來源，開關開啟才再允許 HTTP／HTTPS 任意網域與 port，固定 webrtc=block。保留 CSP 與原生導覽／資源／權限等限制。決策見 ADR 0003，支援範圍只聲明實測 Runtime 155.0.4283.62。
- PASS：Release app build；安全腳本 off→on→off、兩種重啟、HTTP／HTTPS 等原有負面與來源儲存隔離。session security-a51c31974b1046a0a4f0114a5c78db5b，hash `DF658C57DA4EFAE79CAF7F6CFB6A4E88EA97A1B9AAD2D3CE356799994D0FC7B1`。UDP 接收端有一筆 UdpClient 正向控制、主題封包 0；舊版三筆為瀏覽器正向證據。webrtc-{red,green}-packets.jsonl／結果與日誌已保存。
- 測試校正：初版錯把「一定拋 SecurityError」當作政策判定，曾在無 UDP 收件時仍失敗；實際允許建立物件後禁止 ICE。改由接收端收件判定，對舊／新產品重跑同一案例取得 Red→Green；先前誤判日誌保留，不稱每輪皆首次通過。
- NOT RUN：TURN／完整 DNS／推測連線、其他 Runtime 與完整安全矩陣；後續擴充。完整回歸與 CI 留待本輪實作收尾。原桌布 83428 未關閉或替換，A12／RC gate 保留。
- Commit：`fix(security): 阻止主題 WebRTC 外連`；依 commit-msg skill 產生後立即 commit＋push feature/tray-management。

## 2026-10-29 剩餘安全驗收 — 隔離父網域 Cookie

- Scope：承接使用者要求繼續剩餘工作，保持 feature/tray-management、不合併 main；續驗計畫見 management/REMAINING.md。
- Red→Green：新增真實 localStorage／sessionStorage／Cookie 載入隔離，舊來源在 allowNetwork=true 第二次載入 FAIL；共同 drillpaper.local 父網域 Cookie 會跨 GUID 子網域保留。改用每次載入不同可註冊網域 `drillpaper-theme-<GUID>.invalid`，保留來源判斷同時拒絕舊命名空間及非目前 .invalid。決策見 ADR 0002。
- PASS：Release app build；相同 `test-webview2-security.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe`，off→on→off、管理／獨立重啟與既有網路負面通過。session security-59a3f05723ca4f3abcc2080c1f1255a5，hash `8F3DB185176D5A2BCE9DDF445D63D8016DC281B260510AAF2C2A7B5D48BA4CAB`；storage-red.log／storage-result.json／storage-green.log 保存於 management。
- 人工：使用者對獨立固定副本 PID 90952（前版 F0238D…）回報「操作皆正常 但無法縮放因此未測試縮放」，對應 Tab／Shift+Tab、空白鍵、取消草稿、重複開啟唯一視窗；DPI 仍 NOT RUN。原持續桌布 83428 路徑未變，未關閉／替換。
- NOT RUN：IndexedDB／Cache Storage／舊頁面競態、WebRTC／推測連線及其他未覆蓋安全矩陣，後續補驗。完整回歸／本版 CI 留待本輪實作收尾，A12 與 RC gate 保留。
- Commit：`fix(security): 隔離主題父網域 Cookie`；依 commit-msg skill 產生後立即 commit＋push。

## 2026-10-29 管理三階段實作收尾 — 最終 CI 通過

- 最終產品程式提交 `63e86ff`，分支 feature/tray-management。實際 [CI 40832496506](https://github.com/act70255/DrillPaper/actions/runs/40832496506) PASS：乾淨 Windows runner configure／build、CTest 33/33（3.10 秒）、SDK 18/18、固定 SDK 還原／bootstrap 邊界及主題封裝 artifact。RC job 預期 skipped，沒有發行。
- 證據：management/final-ci.json、final-ci.log；完整原始 log 位於 artifacts/acceptance/63e86ff-ci.log。前版 bcb6d2c 的成功與本機／原生整合證據各自保留，不混用 hash。
- 第三階段票與 spec 設為 implemented，表示程式與所列驗證範圍完成；不表示整體 MVP／RC 或所有人工矩陣通過。使用者已確認系統匣可開、匯入正常、移除測試完成，隔離目錄結果吻合；原生重複開啟 5 次／真正 Explorer 程序重啟及 junction 負面亦已有各自證據。
- NOT RUN：新版 Explorer 像素人工結論、完整鍵盤／DPI、全部權限／scheme／WebRTC／DNS／跨主題 storage 等矩陣。原因及安全限制見 FOLLOWUP.md／theme-security.md；A12 與 RC gate 保留，沒有宣稱完整沙箱。
- 收尾核對：只有持續桌布 PID 83428，路徑仍為原固定 a241856 副本。測試與人工程序均已收尾，沒有關閉或替換原桌布，未合併 main。
- 本輪僅更新文件／票項／CI 證據，產品測試 NOT RUN（本輪無程式變更；已核對 63e86ff 的實際 CI）。Commit：`docs(acceptance): 記錄管理階段驗收與 CI 結案`，依 commit-msg skill 產生後 commit＋push。

## 2026-10-29 最後安全回歸 — 保留主機判斷與人工回報

- Scope／Red→Green：新增正常 URL 路徑含 `.drillpaper.local` 的真實 fetch，先在 allowNetwork=true 重現失敗；將保留命名空間判斷限制在 URI authority 的主機名稱，不再用整段 URL 子字串拒絕。
- PASS：Release app hash `F0238D6151CF4FC812F94483D99F40AE869D675DA2CF308C201D959B5D6EB757`；安全測試 session security-4e94d27238ce4faf82bf0b39b5b4e71f，含新路徑及 HTTP／HTTPS、WS／WSS、管理與獨立重啟。完整套件再次通過 CTest 33/33（28.19 秒）、SDK 18/18 與其他腳本檢查。
- 測試工具缺陷：清理觀測曾把建立於 14:39 的 MSBuild 29340 列入 14:53 測試 app 的子程序，因舊 ParentProcessId 被重用；未終止該 MSBuild。改為比較父子建立時間並在關閉前保留 process handle，且必須觀察到真正子程序，重測通過。另保留一次原因未定的提前退出與路徑 Red，不稱首次即成功。
- 人工回報：使用者確認系統匣可開啟、匯入操作看起來正常，接續回報移除測試已執行完畢且未述異常；隔離 minimal-monitor@1.0.0 目錄已不存在。取消／確認各步細節未另述，不擴大為完整矩陣。額外視窗來自隔離測試；核對後僅原桌布與人工程序，人工程序已正常退出 0。
- CI：bcb6d2c 的 [40831527263](https://github.com/act70255/DrillPaper/actions/runs/40831527263) 完整 PASS，CTest 33/33、SDK 18/18，RC job 預期 skipped。本次最後主機判斷修正將提交推送後另觸發，不沿用前版 PASS。
- NOT RUN：新版 Explorer 像素人工結論、完整鍵盤／DPI、完整 egress／WebRTC 等安全矩陣；理由及剩餘 gate 仍見 FOLLOWUP.md。原持續桌布 83428 保留，沒有合併 main。
- Commit：`fix(security): 依主機名稱判斷保留來源`，依 commit-msg skill 產生後立即 commit＋push feature/tray-management。

## 2026-10-29 管理續驗 — 獨立啟動全域偏好、junction 與真正 Explorer

- Scope：補足管理功能收尾，發現獨立 `--preview` 不讀保存偏好，先以真實 WebView2 重啟測試重現 FAIL，再讓全部 GUI 啟動先讀 SettingsStore、其後套 CLI 暫時覆寫，啟動不寫回。其他 ticket／發行功能未納入。
- PASS：最終 Release app 建置，hash `746878782C24CF798CA3B9A84F708607994B11FC5B06A87C57DA07A77F2C2A67`；安全整合 off→on→off、管理／獨立重啟、WS／WSS（含獨立 TCP 正向控制）及原有負面案例。最新 session security-d9c5ad6d554f44eba85bb5a87c1ae9f7。
- PASS：真正 NTFS junction 的移除拒絕：root／版本／巢狀資產，12 斷言且外部目標保留；ThemeManager 共 10 案例／87 斷言。產品既有防護通過，沒有虛構 Red。
- PASS（3871e72 的原生程序／bridge）：實際 Explorer 50496→98068；同一管理 app 56892，新 HWND、DesktopEpoch 2→3、ReadyEpoch 2→4、新指標及 TrayRegistered=1。正常退出及已觀察子程序清理通過。沒有把此結果外推至畫面或真正圖示點擊。
- 持續桌布：PID 83428 仍為原固定 a241856 路徑；新 parent 為 Shell 98068，ReadyEpoch=3，兩秒 metrics tick 1488842593→1488844625。未關閉或替換；舊 A04 人工 PASS 保留。
- PASS：最終 `test.ps1 -Configuration Release`，CTest 33/33（22.33 秒）、SDK 18/18，其他環境／採樣／封裝／負面 oracle 全通過。3871e72 另通過 1 次 runtime＋50 次快速往返、自訂入口 renderer crash 3 次、100 次主題切換與管理 150% PNG 檢視。最後 CLI 偏好修正不冒稱重跑這些舊 hash 情境。
- NOT RUN：真正圖示點擊、檔案選擇／移除確認、新版 Explorer 像素人工結論、完整鍵盤／DPI。Computer Use 原生 pipe 缺失（os error 2），已準備隔離固定副本 PID 100000 與 .dmt 並請使用者回報；尚無結果。完整 egress／WebRTC 等及 RC gate 照舊保留。
- CI：NOT RUN，須先推送本次程式與測試提交才能觸發對應版本，接續執行 workflow_dispatch。證據、命令、hash 界線見 [FOLLOWUP.md](acceptance/2026-10-29/management/FOLLOWUP.md)。
- Commit：`fix(settings): 讓獨立啟動沿用全域偏好`，完成本機檢查後立即 commit＋push feature/tray-management；不合併 main。

## 2026-10-29 管理介面階段 3 — 真實網路控制與安全負面整合

- Scope：全域 HTTP／HTTPS 草稿、套用／取消與保存／重啟接入 WebView2；首次封鎖只提醒前往原生設定。每次載入 GUID HTTPS 來源改由宿主回應強制 CSP，保留離線且不啟動 HTTP server；ADR 0001 記錄替代 folder mapping 的原因。外部導覽、框架、worker／WebSocket、下載、權限及彈窗各自拒絕。
- Red／Green：首次提示缺失、介面缺少開關、預設封鎖仍有 WebSocket 到達 loopback server，均先失敗後通過。新增離線 JSON 回歸再抓到 connect-src 過嚴，縮至目前主題來源後通過。
- PASS：Release app build；`test-webview2-security.ps1` 真實 HTTP off→on→off、HTTPS example.com no-cors、script／image／fetch／XHR／redirect、iframe／WebSocket／彈窗／導覽負面、通知／定位 denied、下載取消事件、保存／取消／重啟及已觀察子程序退出。最新 session `artifacts/acceptance/security-a804c15b069b4ad2bf9c79a44037a7be`，hash 與詳細界線見 [PHASE3.md](acceptance/2026-10-29/management/PHASE3.md)。
- PASS：`test-management-shell.ps1 ... -Desktop` 的既有管理生命週期／設定回歸，以及 Dashboard mock Preview smoke（PID 92592）。`git diff --check` 通過。完整套件與 CI 尚待下一階段收尾。
- NOT RUN：完整 egress／WebRTC／DNS／preconnect、跨來源 storage／舊頁面競態、全部權限及 scheme，因不在目前測試覆蓋內；不宣稱完整沙箱，A12 與 RC gate 保留。真正圖示點擊、檔案選擇／確認、新版真正 Explorer、移除 junction 與完整回歸／CI 接續補驗，尚未以舊版結果替代。
- 持續桌布：已核對 PID 83428 的固定 a241856 EXE 路徑，未關閉或替換。舊版 A04 人工 PASS 保留。
- Commit：`feat(security): 接入主題網路開關與強制安全政策`；依階段規則立即 commit＋push 至 feature/tray-management，不合併 main。

## 2026-10-29 管理介面階段 2 — 主題與設定；使用者要求交接暫停

- 實作：原生主題清單、預覽／套用、`.dmt` 檔案選擇器、確認移除、模式與智慧休眠設定、套用／取消；`SettingsStore` schema 驗證、同目錄暫存／flush／原子保存、損毀原檔保留，CLI 暫時覆寫不自動保存。ThemeManager 只允許移除安裝目錄中驗證吻合的版本；使用中的版本先換 Minimal 並關閉舊 controller。
- Red／Green：保存往返、移除所選版本、prerelease 主題名稱各先失敗再實作；新流程誤將內建 `.d.ts` 送入匯入限制的回歸亦由真實啟動抓到並修正，未放寬第三方政策。
- PASS：Release build；Settings 3 案例／15 斷言、ThemeManager 9 案例／75 斷言；管理生命週期、模式切換、保存／取消／重啟恢復；Dashboard mock Preview smoke。150% 管理視窗 PNG 已檢視，控制項未裁切。命令、版本 hash 與界線見 [PHASE2.md](acceptance/2026-10-29/management/PHASE2.md)。
- NOT RUN：檔案選擇器與移除確認的人工作業、真正圖示點擊、新介面的真正 Explorer 重啟、完整 DPI／鍵盤、移除 junction 負面案例；原因為尚需針對性原生互動驗證。完整套件與本版 CI 尚未重跑，留待剩餘實作收尾，不沿用舊版 PASS。
- 使用者因 console 過長要求告一段落停止，故本階段提交推送後暫停；第三階段尚未開始。`allowNetwork` 僅保存欄位，沒有可用開關或 host 接線。續作票：`.scratch/tray-management/issues/03-network-security.md`；01／02 為 implemented、仍有人工待驗。
- 現有持續桌布 PID 83428 仍使用固定 `a241856` EXE；先前 A04 人工 PASS 有效，新介面的實機驗收另計。不要關閉此程序、不要再用會逾時關閉的觀測 runner 作為持續桌布。
- Commit：`feat(management): 新增主題管理與設定原子保存`，分支 `feature/tray-management`，依既有規則 commit＋push。未合併 main，整體 MVP／RC 仍未通過。

## 2026-10-29 管理介面階段 1 — 系統匣與生命週期

- 使用者已明確確認完整三階段 spec；第一階段實作 `ManagementShell`，由穩定通知視窗持有圖示，獨立可信管理視窗可重複開啟／隱藏，提供主題、模式、暫停／繼續、日誌與退出。
- 公開 runtime `ManagedPlayback`：手動暫停優先於智慧休眠及暫停停採，恢復時重新採樣；Red 原政策仍為 Active，Green 1 案例／8 斷言。
- PASS：Release build；`test-management-shell.ps1 -Desktop` 的 5 次唯一視窗、暫停／新指標恢復、3 次受控圖示重註冊、模式 parent 切換、正式退出及子程序清理；既有 runtime 1 次與暫停中退出通過。命令與界線見 [management/REPORT.md](acceptance/2026-10-29/management/REPORT.md)。
- NOT RUN：新介面的真正圖示點擊與 Explorer 重啟／像素、完整 DPI／鍵盤；理由為尚需實機人工操作。圖示建立失敗保留可見管理入口，有界重試十次；沒有操作使用者工作列顯示設定。
- 介面以 `--management` 開啟；既有明確 `--preview`／`--experimental-desktop` 驗收仍可正常關閉。使用者現有持續桌布不受影響。
- Commit：`feat(management): 新增系統匣入口與管理生命週期`，分支 `feature/tray-management`。下一步：主題管理與設定保存；網路開關仍未交付。

## 2026-10-29 管理介面範圍確認整理

- 依使用者「協助我完成確認範圍」，在 `.scratch/tray-management/spec.md` 補上三階段功能與可觀察的完成判定，建議完整功能分階段交付。
- 明列本次不新增開機自動啟動、主題編輯器／線上商店、逐螢幕主題設定及雲端同步；保留原 handoff 的整體驗收要求，未將選配自動啟動改成必做。
- Approval 仍為待確認，尚未把協助整理範圍視為同意實作。驗證：核對 handoff、既有 spec 及 `git diff --check`；產品測試 NOT RUN，原因為僅變更需求文件。
- Commit：`docs(management): 明列管理介面範圍與驗收條件`；依既有階段提交規則 commit＋push 至 `feature/tray-management`。

## 2026-10-29 管理入口需求草案

- 使用者提出以工作列右下角的系統匣圖示作為管理入口。已核對目前只有原生主題選單與 CLI，沒有系統匣／完整設定視窗／設定保存。
- 需求已整理於 [.scratch/tray-management/spec.md](../.scratch/tray-management/spec.md)，狀態 needs-info，等待確認本版互動與範圍；原 handoff 中的 SystemTray 需求不等於這份 UI 細節已確認。
- 交付分為系統匣與管理生命週期、主題／設定保存、網路與安全整合三階段；測試 seam 與實機界線一併列出。此階段只寫需求，產品行為及測試 NOT RUN，原因為尚未實作。
- 規劃提交：`docs(management): 規劃系統匣入口與設定介面`，分支 `feature/tray-management`；後續依使用者確認再開始程式碼。

## 2026-10-29 A04 實機結案 — Explorer 重啟後桌布恢復並持續更新

- PASS（本機本次情境）：使用者確認「可以了 有恢復並持續更新」。受測 `a241856`，EXE SHA-256 `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE`，Windows 11 Pro 25H2 build 26200.8737、Dashboard、`--no-smart-sleep`。
- 原生比對：同一 app PID 83428；Shell PID 988→50496；HWND 688652446→1183238；新父視窗為 PID 50496 的 WorkerW；握手世代 1→2、附掛世代 1→3、失敗碼 0；3840×1080，兩秒間 metrics tick 1481971265→1481973328。人工確認補足 bridge 指標不能代表畫面的限制。
- 證據：`acceptance/2026-10-29/shell-readiness/actual-{session,before,after}.json` 與 `user-confirmation.json`。保留前兩版失敗及受控測試，不以這次成功改寫歷史。
- CI：同一 commit 的 [run 40815261057](https://github.com/act70255/DrillPaper/actions/runs/40815261057) 第 2 次完整通過，CTest 29/29、SDK 18/18；第 1 次在負面測試判斷腳本 60 秒逾時，原因未定，原 log 亦保留，不記為第一次即成功。
- 範圍：A04 在上述實機組態 PASS；Smart Sleep 與重建交錯、其他 Windows／顯示配置及 A03 完整圖示／焦點互動仍分開驗收。A12 安全與其他 RC 阻擋未解除，整體產品尚未驗收通過。桌布持續開啟，未擅自關閉。
- 結案 Commit：`docs(acceptance): 記錄 Explorer 實機復原通過`，依使用者規則提交並推送 `bugfix/explorer-shell-readiness`。

## 2026-10-29 真正重啟續驗 — 等待 Shell 就緒再重掛

- 實機證據：使用者回報已重啟；同一 app PID 70156 重新建立 HWND、握手 1→2，metrics tick 持續增加，但父視窗為空、760×480 預覽，DesktopFailure=1。原因為新 Shell 管理視窗尚未就緒，原復原只試一次即永久退化；此次不記為桌布重掛通過。
- Scope：新增純 runtime 重試政策，以單調毫秒每隔至少 1000 ms 再試，最多 10 次；成功後重設額度，超過上限才退回預覽。UI 在等待期間隱藏暫態視窗，以穩定通知計時器執行後續嘗試；不是無限迴圈，也不重啟採集工作者。
- Red／Green：公開 runtime 狀態契約先 FAIL 於首次失敗即不排重試；實作後 1 案例／28 斷言通過，涵蓋間隔、預算耗盡與成功後重設。真正單次退化的原生證據與新政策證據見 [shell-readiness/REPORT.md](acceptance/2026-10-29/shell-readiness/REPORT.md)。
- PASS：Release build；完整本機 CTest 29/29、SDK 18/18、其他封裝／採樣／測試判斷檢查；父程序崩潰且無注入通知 3 次，新握手／持續指標／正常退出與已觀察子程序清理皆通過。
- NOT RUN：加入等待政策後的真正 Explorer 重啟與畫面。單元測試只證明重試時序與上限，不能證明 Shell 附掛或畫面；仍須以新版本再做實機確認。
- Commit：`fix(desktop): 等待 Explorer 就緒再有界重掛`，分支 `bugfix/explorer-shell-readiness`，完成相關驗證後提交推送。

## 2026-10-29 Explorer 視窗銷毀復原 — 受控修正完成，真正重試待驗

- Scope：區分使用者 WM_CLOSE 與非預期 WM_DESTROY；以獨立通知視窗接收採樣／錯誤，原 HWND 消失後重建原生視窗、功能表、計時器與同一主題的 WebView2 controller。通知遺漏時由每秒一次的宿主檢查補救；重建失敗保留明確錯誤與停止路徑，不無限建立視窗。
- Red：公開 app／Win32 整合 seam 的跨程序父視窗 fixture，銷毀父視窗後舊版 app 提前退出；此前真正 Explorer 重啟則造成失效 HWND 與背景程序殘留。兩條生命週期失敗都列入修正，見 [explorer-recreation/REPORT.md](acceptance/2026-10-29/explorer-recreation/REPORT.md)。
- PASS：正常關閉父視窗 5 次；直接終止隔離父程序且不注入 TaskbarCreated 5 次；每次新握手世代及至少兩次新的 metrics.changed 成功送入 WebView2 bridge，正常退出 0，已觀察子程序全退出。此指標只證明 bridge 接受訊息，畫面仍需人工確認。
- PASS：既有重掛回歸、Dashboard mock Preview、內建及已匯入主題切換、自訂入口 renderer 故障 3 次；生命週期 5 次＋50 次快速往返及暫停期間關閉。完整本機 CTest 28/28（6.80 秒）、SDK 18/18 及其他腳本檢查通過。
- 測試工具修正：Windows PowerShell 5.1 使用明確 UIntPtr 建構式與外層陣列，避免把單一 CIM 物件的空 Count 誤判為沒有 renderer；renderer 初始／自訂入口皆要求新握手世代。Preview／主題協定測試以 no-smart-sleep 隔離當前 display-off，省電仍由獨立生命週期測試驗證。
- NOT RUN：修正版的真正 Explorer 重啟與像素畫面、重建與電源故障交錯、其他 Windows／顯示配置。不能用上述受控結果把舊版真正失敗改寫為通過；待使用者再做一次同情境驗收。
- Commit：`fix(desktop): 重建 Explorer 銷毀的宿主與資料通道`，分支 `bugfix/explorer-window-recreation`，完成相關驗證後提交推送。

### Explorer 修正遠端驗證

- `f2cff39` 已推送並核對 origin；[CI 40810412264](https://github.com/act70255/DrillPaper/actions/runs/40810412264) 全數通過，包含新增 parent fixture 編譯、CTest 28/28、SDK 18/18 與封裝／SDK 還原檢查。metadata 與節錄見 `explorer-recreation/ci.json`／`ci.log`。
- 已開啟固定副本的修正版實機觀測，仍待使用者真正重啟與畫面結果，不預先列 PASS。整體 RC gate 保持阻擋。

## 2026-10-29 人工 Explorer 驗收 — 失敗已重現

- 使用者已啟動桌布並回報「重啟檔案總管後才消失」。真實 Shell PID 31956→70652，受測 app PID 97976 繼續存活，但原 HWND 88151400 已無效，獨立通知視窗仍有效。這次是 A04 FAIL，取代先前待驗狀態；不是腳本 30 秒後自動關閉。
- 失敗點：`RecoverDesktopHost` 遇到無效 gWallpaperWindow 直接返回；初期受控重掛只改 parent、未銷毀 HWND，未涵蓋此行為。需補上跨程序父視窗銷毀回歸與真正的視窗／WebView2 重建，不把訊息注入通過外推。
- 證據：`acceptance/2026-10-29/explorer-failure/` 保存原生視窗診斷、使用者回報與 runner 結果。期限到達後 runner 找不到有效主視窗可正常關閉，終止自己啟動的受測 app（退出 -1）；沒有終止 Explorer。
- 本機完整回歸仍 PASS：CTest 28/28（17.14 秒）、SDK 18/18、環境／採樣／封裝及隔離變異檢查；commit 7902c02 的 [CI 40803087109](https://github.com/act70255/DrillPaper/actions/runs/40803087109) 亦全數通過。這些不推翻上述 Windows 整合失敗。
- 驗收工具已加實際 Shell PID／世代觀測、成功後 30 秒人工觀察；USER_GUIDE 改用標準 build 與完整路徑。FINAL_HANDOFF 已整合目前 A01–A16，不再沿用舊版功能缺漏表。
- Commit：`test(desktop): 保存 Explorer 實機失敗與驗收工具`，分支 `feature/shell-recovery-acceptance`，完成本輪證據整理後提交推送。下一步在獨立 bugfix 分支修正 A04。

## 2026-10-29 主題負面測試 — 修正例外判斷誤報

- Red：只在隔離副本移除 validator 的路徑檢查後，正式測試腳本仍退出 0，且將預期拒絕卻被接受的 traversal 封包印為 PASS。原生 validator／產品檔案未變更；此實驗驗證測試本身是否有辨識力。
- Fix：只捕捉 validator 的拒絕例外；「預期拒絕卻被接受」的斷言移至 catch 外。新增公開腳本入口的隔離變異回歸，納入本機 test.ps1 與 CI。
- Green：相同變異現在讓子程序在 traversal.dmt 正確退出 1；正式未變異 validator 仍通過合法封包並拒絕 5 類非法包。證據見 [theme-oracle/REPORT.md](acceptance/2026-10-29/theme-oracle/REPORT.md)。
- Commit：`fix(test): 防止主題負面案例被誤判為通過`，分支 `bugfix/theme-negative-oracle`。此修正不代表尚未執行的 WebView2 外連／下載／權限測試通過。

## 2026-10-29 封裝工具續作 — Windows PowerShell 5.1 壓縮組件

- Red：新程序直接執行 `test-theme-package.ps1` 時找不到 `System.IO.Compression.ZipArchiveMode`；完整回歸亦在同一位置停止。
- Scope：主題 validator／測試、SDK packager／測試各自明確載入 `System.IO.Compression`，不再依賴另一支腳本先間接載入。
- Green：5.1 的主題測試及 SDK ZIP 解壓重測皆成功，SDK 18/18，兩次 SDK 封裝 hash 一致。證據見 `acceptance/2026-10-29/powershell-zip/`。這只確認執行相容性與所列封裝檢查；不外推成瀏覽器安全驗收。
- Commit：`fix(scripts): 明確載入 Windows PowerShell 壓縮組件`，分支 `bugfix/powershell-zip-assembly`，相關驗證完成後提交推送。

## 2026-10-29 效能工具續作 — Windows PowerShell 5.1 相容性

- Scope：將 PowerShell 運算式中的 `[ushort]` 改為 `[System.UInt16]`；C# 原生宣告與 all-processor-groups 的 `MaxValue` 語意不變。
- Red：Windows PowerShell 5.1 執行 `scripts/test-performance-sampler.ps1`，無法辨識 ushort，退出碼 1；這也是當日本機完整回歸的中止原因。先前在 PowerShell 7 的通過結果不外推到 5.1。
- Green：相同命令於 5.1 通過，3 筆完整樣本、跨度 2.339 秒；提前退出與未知 PID 的失敗資料仍保留。原始輸出見 `acceptance/2026-10-29/powershell/`。完整套件待同步修正後再收尾重跑。
- Commit：`fix(perf): 相容 Windows PowerShell 的處理器群組型別`，分支 `bugfix/powershell-sampling`，完成相關驗證後提交推送。

## 2026-10-29 Phase 8 續作 — 乾淨 Windows CI 的 SDK 還原

- Scope：官方 NuGet WebView2 SDK 1.0.2478.35、固定 SHA-256、驗證後解壓、拒絕覆寫既有目錄、staging 清理；CI 及選配 RC job 都先還原 SDK 並設定 WEBVIEW2_SDK_ROOT，沒有移除 CMake 的必填檢查。
- Red（真正 GitHub runner）：[run 40801046281](https://github.com/act70255/DrillPaper/actions/runs/40801046281)，SDK／主題封裝通過，但 Configure 因 WebView2 headers 不存在失敗，證據見 `acceptance/2026-10-29/ci/before-fix.log`。
- PASS（本機腳本）：`powershell -NoProfile -File scripts/test-webview2-bootstrap.ps1 -ArchivePath C:/WorkSpace/-James/DrillPaper/.toolchain/webview2/sdk.zip`，官方包／空白路徑／竄改包拒絕／既有檔保留／staging 清理通過。
- 後續遠端驗證：先提交並推送 `bugfix/ci-webview2-bootstrap` 的具體修正，才可用 workflow_dispatch 執行該版本；新 runner build／CTest 結果尚待執行，不預先標為 PASS。真正 RC job 保持 opt-in，發行閘門未解除。
- Commit：`fix(ci): 還原固定雜湊的 WebView2 SDK`；來源包與版本固定方式見 `docs/ENVIRONMENT.md`。

### CI 遠端驗證結案

- Commit `9888aaf` 的 [run 40801528098](https://github.com/act70255/DrillPaper/actions/runs/40801528098) 已實際全數 PASS：乾淨 runner configure／build、CTest 28/28、Node 18/18、SDK 還原邊界及主題 artifact。取代上方執行前的待驗狀態。
- 證據見 [ci/REPORT.md](acceptance/2026-10-29/ci/REPORT.md)。此結果不證明 Windows 10／11 Shell GUI 或乾淨使用者安裝；RC job NOT RUN，未要求發行且發行條件尚未滿足。
- 結案 Commit：`docs(ci): 保存乾淨 Windows runner 驗收結果`，與修正一併推送 `bugfix/ci-webview2-bootstrap`。

## 2026-10-29 Phase 1 續作 — Windows 11 桌布附掛與受控重掛

- Scope：使用 `GetShellWindow` 錨定目前 Shell PID，排除其他程序的同名 WorkerW；支援新版 Progman 子 WorkerW，保留舊頂層搜尋與 Preview fallback。修正 SetParent 已回傳成功但殘留 LastError 導致誤判的重掛缺陷。附掛世代／最後失敗碼可由原生視窗屬性診斷。
- Red：實機公開 DesktopHost 整合測試先失敗（找不到桌布層）；改用新版建立訊息後仍失敗，inventory 顯示 WorkerW 已建立於 Progman 內。完整 app 的解除附掛／定向 TaskbarCreated 迴圈再重現錯誤碼 4；SetParent 回傳值判斷修正後轉綠。
- PASS（Windows 原生整合）：Release app 建置；原生視窗 2 案例／22 斷言；相關 CTest 1/1。完整 app 同一 PID／HWND，SDK 握手完成，3840×1080 填滿父用戶區，附掛世代 1→6，5 次受控重掛，退出碼 0，6 個 WebView2 子程序全退出。觀測已統一 Per-Monitor V2 DPI 座標。
- Commands：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperWindowsHostIntegrationTests --parallel 8`；測試 EXE `'[shell-live],[desktop]'`；`scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -RecoveryCycles 5`。證據與限制見 [shell/REPORT.md](acceptance/2026-10-29/shell/REPORT.md)。
- NOT RUN：本輪真正 Explorer 程序重啟、圖示／工作列／Alt+Tab 與像素畫面。Windows Computer Use 原生管道不存在，畫面需人工補驗；受控通知明確不算 Explorer 重啟。`[shell-live]` 會操作當前桌布層，故只手動明確呼叫，不納入無互動 CTest。
- Commit：`fix(desktop): 支援新版桌布層並修正重掛誤判`，分支 `bugfix/shell-attachment`，依階段規則提交推送。上一階段 Preview 回復提交 `edbb261` 已在 origin。

## 2026-10-28 Phase 1 續作 — Preview 回復樣式

- Scope：只修正 `Win32DesktopHost::RestorePreview`，解除父視窗後清除桌布專用的 `WS_EX_NOACTIVATE`／`WS_EX_TOOLWINDOW`，恢復一般預覽視窗。新增專屬 Win32 父子視窗整合測試，不操作 Explorer。
- Red：`DrillPaperWindowsHostIntegrationTests.exe '[desktop]'`，1 案例失敗／6 斷言中 5 通過；`WS_EX_NOACTIVATE` 仍為 `0x08000000`，重現樣式未回復。
- Green：Release 主程式及整合測試 target 建置成功；`ctest --test-dir build/windows-msvc-release -C Release -R 'Desktop fallback' --output-on-failure` 通過。最終測試輸出與二進位雜湊見 [desktop-preview/REPORT.md](acceptance/2026-10-28/desktop-preview/REPORT.md)。
- NOT RUN：真正桌布附掛、桌面圖示／工作列互動、Explorer 重啟及視覺驗收。此階段只證明本程序視窗的回復樣式，沒有操作使用者的 Shell；其餘項目仍須獨立整合驗證。完整套件留至整體收尾，這次只跑直接相關測試。
- Commit：`fix(desktop): 修正預覽回復時殘留桌布視窗樣式`；分支 `bugfix/desktop-preview-fallback`，依階段規則提交並推送至 origin。

## 2026-10-28 Phase 7 — 30 分鐘觀測與狀態分析

- Scope：Runtime 版本 Minimal 實機 Preview，60 秒暖機、1800 秒要求，獨立 EXE／profile，CPU／Private Bytes／Working Set／handles／原生狀態分組；不冒充最新 renderer 復原版本的效能。
- PASS（收集與分析）：343 筆，實際 1804.606 秒，固定 7 程序且全含 app＋WebView2，無略過或不完整資料。active CPU 平均 0.1159%、locked 0.00628%；此觀測差約 94.6%，非普遍功耗保證。
- PASS（清理）：正常退出 0、6 個已觀察子程序全退出、暫時電源需求還原。原始資料、圖表、版本、方法與限制見 [long-observation/REPORT.md](acceptance/2026-10-28/long-observation/REPORT.md)。
- PARTIAL（A13）：active 穩定區間僅 596.194 秒，未寫成 600 秒；還缺 Dashboard／GPU Engine／display-off／全螢幕等對照。Private Bytes 起訖 +9.39 MiB，長時間洩漏不能由有限觀測排除。Commit `6551113 test(perf): 保存混合狀態長測與資源分析`，已推送 `feature/performance-observation`。

## 2026-10-28 Phase 4／6 續作 — 程序退出型渲染復原

- Scope：ProcessFailed 通知、UI 迴圈重建 renderer／environment、來源與載入世代、callback lifetime、保留原生採集與快照、自訂入口保留、有界 Minimal／原生 Preview 退化。Files：WebView2 host/header、App event composition、`scripts/test-renderer-recovery.ps1` 與驗收紀錄。
- Red／Green：已辨認新握手世代後，renderer 故障未恢復的測試先 FAIL；修正後 renderer 3 次、browser 3 次、8 次故障達上限後原生退化、非 index 入口各 PASS，app 正常退出碼 0。見 [recovery/REPORT.md](acceptance/2026-10-28/recovery/REPORT.md)。
- Scope 限制：程序／協定整合，非每次像素畫面；測試以 `--no-smart-sleep` 隔離其他政策。unresponsive／無限迴圈、crash 與電源交錯、其他 process kinds、Explorer、安全與發行條件仍 NOT RUN，原因為對應情境或功能尚未完成。
- Commit `1a0bad1 feat(web): 新增有界程序故障復原與握手驗證`，已推送 `feature/renderer-recovery`。

## 2026-10-28 階段提交與遠端同步

- 使用者已指定每階段完成後直接 commit＋push；規則已加入 repository `AGENTS.md`，後續依此執行。
- 已推送並用 `git ls-remote --heads origin` 核對：`feature/theme-manager` → `66edcbb`、`feature/runtime-lifecycle` → `3bdca3f`、`bugfix/performance-sampling` → `a41261e`。`main` 維持 `5697bf7`，未合併開發分支。
- 渲染器復原尚在開發：目前只有故障注入腳本與新握手診斷；已觀察失敗，實際自動復原未完成。這些 WIP 尚未推送，未當作驗收通過。

## 2026-10-28 效能工具修正與長測啟動

- `bugfix/performance-sampling`：要求 2 秒只覆蓋 1.205 秒的 regression 先 FAIL，修正以 CSV 首末跨度判定結束後 PASS。新增身分／狀態／handles、原始 Handle 身分保留、根程序退出 FAILED 與部分資料保存，不記為成功的零資源樣本。
- PASS：`scripts/test-performance-sampler.ps1`，完整跨度 2.467 秒、缺身分欄位修正、提前退出及不存在 PID 皆驗證。觀測 runner 短測亦確認正常退出、已觀察子程序全退出及暫時電源需求還原。
- 17:50 啟動 Minimal 30 分鐘實機觀測，60 秒暖機，獨立 profile／EXE 副本；尚未預判結果。證據與命令見 [sampler/REPORT.md](acceptance/2026-10-28/sampler/REPORT.md)。
- Commit `a41261e fix(perf): 修正採樣跨度並保留失敗證據`，已推送。後續繼續 renderer 復原、安全及桌布整合。長測與其他開發工作可能同時執行，保留環境限制。

## 2026-10-28 Phase 3／6 續作 — 背景採樣與生命週期

- 分支 `feature/runtime-lifecycle`，承接 `66edcbb`；Commit `3bdca3f feat(runtime): 串接背景採樣與電源生命週期`。Files：SamplingWorker、Windows PowerNotifications、App composition、WebView2 host、runtime unit／原生整合腳本及驗收文件。
- Scope：採集移出 UI、條件等待／可停止工作者、latest-wins mailbox 與設定世代、恢復基準重設、WTS／顯示器通知、前景全螢幕防抖、WebView2 hide/TrySuspend/Resume、非同步 callback lifetime／狀態世代。
- Red／Green：背景樣本未送出、Windows 通知宿主缺失、快速狀態往返後未暫停皆有失敗證據再修正。Worker 4 案例／21 斷言；完整回歸初次 CTest 27/27、SDK 18/18、封裝檢查通過，最終紀錄見 [runtime/REPORT.md](acceptance/2026-10-28/runtime/REPORT.md)。
- PASS（受控原生整合）：5 次往返、50 次快速往返、暫停期間正常退出。實際查詢 IsSuspended，不以 callback 成功代替目前狀態。
- PASS（人工實機）：使用者回報 Windows 真實鎖定／解鎖 5 次均恢復更新、可正常關閉；受測 EXE hash 與 PID 退出紀錄保存在 manual-session.json。
- PASS（實機 GPU 退化）：非 mock SDK 探針確認 CPU／RAM 已可用，GPU unavailable/null，沒有假 0；非 Intel GPU 支援或讀值精度聲明。
- NOT RUN：真實 display-off／待機、完整全螢幕／多螢幕、renderer／Explorer 復原、安全、長時間與安裝／CI矩陣。下一步：補齊效能採樣邊界、復原與安全驗證；發行閘門不變。

## 2026-10-28 Phase 5 續作 — 原生匯入與熱切換

- Scope：原生 `.dmt`／目錄驗證與 staging/atomic install、CLI 匯入／列舉、Win32 主題功能表、已安裝版本熱切換、逾時回復 Minimal。隔離 GUID origin 避免沿用舊來源。新依賴授權納入建置。
- Files：`src/themes/theme_manager.cpp`、`src/app/{main,theme_commands}.cpp`、WebView2 host 與對應 headers、`tests/unit/theme_manager_test.cpp`、`scripts/test-theme-{cli,switch}.ps1`、CMake、第三方 notices/licenses、README 及架構／使用者／驗收文件。
- Red／Green：ZIP、CLI、內建切換、已安裝主題與 junction 日誌寫入邊界均先有失敗證據再修正。原生主題 8 案例／71 斷言 PASS；CLI CTest PASS。相關命令、檔案範圍及原始證據見 [主題平台驗收報告](acceptance/2026-10-28/theme-platform/REPORT.md)。
- Windows 整合 PASS（程序／協定）：100 次內建切換後載入已匯入主題，正常退出；損壞主題逾時回復 Minimal 並重新訂閱。非畫面截圖驗收。
- 資源 PARTIAL：100 次 Private Bytes 約 197→331 MiB；追加 300 次峰值約 404 MiB、閒置後約 331 MiB，handles 234→257。不得宣稱無洩漏，長時間矩陣保留。
- NOT RUN：瀏覽器完整安全負面、Shell GUI、電源實機與乾淨安裝／CI；未具備完整產品整合或證據。發行閘門維持阻擋。
- Commit：`66edcbb feat(themes): 新增原生主題匯入與熱切換驗證`。下一步：在 `feature/runtime-lifecycle` 實作背景 worker／生命週期，並持續補安全與效能驗證。

## 2026-10-28 14:05 Dashboard 初始效能基線

- 使用者授權由 agent 直接開啟 Dashboard 實機 Preview，執行 600 秒任務、每輪等待 5 秒，並正常關閉。未修改產品行為；未提交。
- **PASS（量測與退出）**：113 樣本皆包含 app 與 WebView2，共 7 程序；CPU 平均 0.116%、p95 0.422%（14 邏輯處理器整機容量）；Private Bytes 平均 240.54 MiB，首分鐘後趨勢 -0.018 MiB/min；正常退出碼 0，觀察到的 6 個子程序全退出。
- 原始 CSV 實際跨度 594.971 秒，不能宣稱 CSV 覆蓋至少 600 秒。原始資料、退出證據、方法與限制見 [performance/REPORT.md](acceptance/2026-10-28/performance/REPORT.md)。
- **PARTIAL（A13）**：只有初始 Preview 基線；30 分鐘、Minimal／休眠對照、GPU engine 及 100 次切換 NOT RUN，尚無相應證據及完整產品整合。不能由此宣稱沒有洩漏或產品效能驗收完成。

## 2026-10-28 續驗：原生主題負面案例

- 範圍：公開 ThemeManager manifest 與安裝行為；延續既有主題分支。Files：原生主題管理實作／header、主題測試及驗收紀錄。Commit：尚未提交。
- **FAIL → PASS**：新增 101 字元名稱案例，先重現原生驗證器錯誤接受（exit 1），再修正 UTF-8 字元長度判斷。名稱／作者／說明採 manifest 字元上限；不以放大的 bytes 限制代替字元數。
- **PASS**：主題測試 target 建置；`DrillPaperThemeTests.exe '[themes]'` 6 案例／16 斷言；`ctest --preset windows-msvc-release --output-on-failure` 22/22，14.53 秒。原始紀錄與命令見 `docs/acceptance/2026-10-28/REPORT.md`。SDK 未更動，未重跑。
- **PARTIAL（Dashboard 實機人工驗收）**：使用者後續回報持續更新、有 CPU 圖表且可正常關閉，此三項 PASS。GPU unavailable、個別版面／縮放、可追溯程序樹的長時間效能及退出後子程序清理仍未驗證；已提供 10 分鐘 Dashboard 程序樹採樣命令。
- 發行阻擋保留：Theme Manager 未接入 app、無原生 ZIP／熱切換、背景採樣／休眠與網路策略整合缺漏，以及桌布、安全、效能與安裝矩陣未驗收。下一步：取得程序樹 CSV 與 metadata 後分析；補齊產品整合後再驗收相應項目。

## 2026-10-28 13:05 Windows 11 驗收

- 範圍：目前工作樹的 Release 建置、完整自動回歸、產物存在檢查與 GUI 工具可用性；未修改產品行為。分支 `feature/theme-manager`，本次未提交。
- **PASS**：`cmake --build --preset windows-msvc-release --parallel 8`、`scripts/test.ps1 -Configuration Release`，均 exit 0。CTest 22/22（含 Windows collector 與主題管理入口），SDK 18/18、環境回歸、主題 ZIP 正負案例及 SDK ZIP 解壓／重封全通過。
- **PARTIAL（人工 Preview）**：2026-10-28 13:18 使用者回報 Dashboard mock 文字與數值皆符合預期。13:19 再回報 Minimal 實機數值及時間持續更新（CPU 83%、RAM 81%、RX 18 KB/s、Host active），此範圍 PASS。Dashboard 個別版面、硬體精度及實機 GPU unavailable 仍待確認；Minimal 縮放與正常關閉已獲後續確認。Computer Use 管道不可用（os error 2），沒有工具截圖。
- **NOT RUN**：桌布／Explorer 復原、硬體精度、WebView2 安全負面整合、Windows 休眠、長時間效能、CI、乾淨安裝；原因及未完成產品功能見[本次驗收報告](acceptance/2026-10-28/REPORT.md)。整體產品仍未驗收通過，app RC 阻擋保留。
- **PASS（本輪基本 Preview 操作結案）**：使用者接續回報「1.2 OK」，確認目前 Minimal 視窗縮放無重疊／裁切，正常關閉無卡住。連同 Dashboard mock 文字／數值與 Minimal 實機更新，完成此次基本操作驗收；不外推到 Dashboard 個別版面、GPU、硬體精度、退出後子程序清理或桌布整合。
- 原始原生測試 log 已保存至 `docs/acceptance/2026-10-28/ctest.log`。後續：補齊主題管理、背景採樣／休眠、網路策略等未接入功能及其整合驗證。

## 2026-10-28 本機環境與續作

- 目前工作樹在 `feature/theme-manager`；`5697bf7` 已提交先前原型，起始工作樹乾淨。下文「只有 be5cb92、工作樹未提交」是舊環境紀錄，已過期。
- 本機為 Windows 11 Pro 25H2 build 26200.8737、VS 2022 Professional 17.14.17、MSVC 19.44、Windows SDK 10.0.26100.0、Node 24.17.0、Intel GPU。已用 uv 安裝 CMake/CTest 3.31.6，並安裝 WebView2 SDK 1.0.2478.35 到使用者 NuGet 目錄；Runtime 155.0.4283.62 原已存在。詳細步驟見 `docs/ENVIRONMENT.md`。
- **PASS**：`cmake --preset windows-msvc-release` 設定完成；Release `DrillPaper.exe` 已編譯；`scripts/test.ps1 -SkipNative` 的 SDK 18/18、主題封裝及 SDK 封裝驗證成功。
- **進行中**：依 `docs/IMPLEMENTATION_PLAN.md` 補原生主題管理。已建立獨立的目錄驗證、staging 安裝及列舉雛型，尚未接入 app，也不支援 `.dmt`；不應認為 Phase 5 已完成。發行腳本明確維持阻擋。
- **Phase 5 測試**：主題安裝起始測試先以佔位實作執行，結果 FAIL（預期）；實作後 `ctest --test-dir build/windows-msvc-release -C Release -R '^DrillPaperThemeTests$' --output-on-failure` PASS（2 個案例：安裝列舉、自身子目錄拒絕）。後者是預先辨識的安全修正，未另外取得失敗測試紀錄。原生主題負面測試、安全審查及 ZIP 解壓均未完成，尚不能宣稱可安全安裝不可信主題。
- **建置修正**：Catch2 自動發現遇到中文測試名稱 JSON 編碼錯誤；改以 CTest 單一入口執行主題測試，重新編譯成功。Phase commit：尚未提交。
- **NOT RUN**：本機 GUI 桌面附掛、外連安全、Windows 休眠及硬體精度驗收；Shell inventory 只列舉視窗，不代表附掛成功。

本紀錄更新至 2026-10-28。`PASS` 僅表示所列命令或明確範圍已在本機執行成功，不外推到未測 GUI、硬體功能、發行流程或安全性。原始規格仍見根目錄 `DesktopMonitor_Codex_Handoff.md`。

## 已確認決策

- 專案名稱：DrillPaper；首版目標 Windows 10/11 x64，支援範圍仍須按實測矩陣逐版確認。
- 主題網路預設封鎖；首次外連遭封鎖時應提示使用者前往設定；單一全域開關開啟後允許 HTTP/HTTPS，其他 URI scheme 仍封鎖。DrillPaper 不送遙測。現有 WebView2 host 會阻擋非本機來源，但提示與全域開關尚未實作，網路封鎖亦未做流量測試。
- 首個 app RC 僅供本機評估，不公開發布。
- 使用者選定第一方內容 Apache-2.0（SPDX `Apache-2.0`），著作權 `Copyright 2026 DrillPaper Project`；第三方依賴與社群主題須各自遵守其授權；保留 DrillPaper 名稱及標誌。
- TDD seams：MetricsSnapshot/採集器、Runtime 狀態與有界佇列、Theme manifest/封裝、JSON protocol/SDK；Win32 Shell 與 WebView2 用原生整合/GUI 驗證。無法取得 GUI 證據的項目保持未驗收。

## 環境與目前工作樹

- Windows 10 Pro x64 build 19045；Visual Studio Enterprise 2022 17.11.2、MSVC 19.41.34120、Node.js 22.14.0。
- 在 repository 忽略目錄 `.toolchain/` 安裝並驗證 CMake 4.3.5、Windows SDK 10.0.26100.0 及 MSVC 缺少的 headers/CRT；WebView2 SDK 1.0.2478.35，已安裝 Evergreen Runtime 155.0.4283.62。未修改系統 PATH 或 ACL。`scripts/* -LocalToolchain` 使用此工作區工具鏈；乾淨環境需先準備等效 SDK 及 Catch2 FetchContent 原始碼快取。
- Release build 目錄：`build/local-msvc-release`；可執行檔：`build/local-msvc-release/DrillPaper.exe`。
- 這台電腦先前缺少 CMake/SDK，首次檢查確實失敗；安裝工作區工具鏈後，已實際完成 Release 編譯、CTest 與 app/WebView2 protocol smoke。原先失敗紀錄不再代表目前狀態。
- 使用者已明確授權 Git commits。2026-10-28 再次執行 `git -c safe.directory=C:/WorkSpace/DrillPaper add -A`，工具環境仍拒絕建立 `.git/index.lock`（Permission denied）；因此目前只有既有 commit `be5cb92`。沒有變更 ACL 或繞過寫入限制。此工作樹的程式與文件修改尚未提交。

## Phase 0 — Repository / Environment Audit

- **狀態：部分完成。** 完成 repository、AGENTS、TDD skill、原生環境與依賴 audit；固定 Catch2 3.8.1（BSL-1.0，僅測試），建立 CMake/PowerShell build-test-environment scripts。工作區安裝 CMake/Windows SDK/WebView2 開發依賴。
- **驗證：PASS** — MSVC x64 Release app 編譯；`DrillPaper.exe --version` 輸出 `DrillPaper 0.1.0-dev`；`--diagnostics` 回報 x64 及 WebView2 Runtime 155.0.4283.62。初期無工具鏈時的失敗已記錄在歷史執行脈絡，不是目前 blocker。
- **GUI：PARTIAL** — app 已建立視窗並能跑 WebView2 smoke；Computer Use 工具拒絕對 DrillPaper 進行可視操作，沒有截圖或人工視覺檢查，因此不宣稱 UI 視覺驗收。
- **Git：BLOCKED** — `.git` 唯讀，無法建立 Phase commit；使用者授權已給，不會再詢問。受限工具環境仍拒絕寫入。
- **下一步：**完成可行的原生功能與文件；不能解除的 Shell/Theme Manager/安全/效能 gate 均具體列入交接。

## Phase 1 — DesktopHost Feasibility Spike

- **狀態：未驗收；桌布附掛不支援宣稱。** 已有 `WorkerW`/`SetParent` opt-in 程式碼、Preview fallback 與 Explorer/display-change 重試。Shell inventory 在 Windows 10 Pro 19045 列舉 17 個相關 top-level windows；`Progman` 下見到 `SHELLDLL_DefView`，未觀察到可用的全螢幕 wallpaper layer。
- **測試：NOT RUN** — 沒有以 app 實際掛載桌面、檢查圖示/工作列/Alt+Tab/focus/z-order、重啟 Explorer 或測試解鎖/解析度變更的 GUI 證據。C++ app 編譯成功不等於 Shell POC 通過。
- **結果：**`--preview` 為可用的獨立視窗路徑；`--experimental-desktop` 保持 opt-in，不能列為已支援桌布。

## Phase 2 — Metrics Core + TDD

- **狀態：部分驗收。** 已實作 typed metric/unit/quality、CPU/network 差值、Windows CPU/RAM/disk/network collectors 與選配 NVML loader。
- **測試：PASS** — CTest 涵蓋 CPU warm-up/delta/reset、metric unavailable/zero、單位與 network rate；Windows collector integration test 真正呼叫本機 API，確認 typed readings 和 CPU/network warm-up，CTest 21/21 全通過。
- **限制：**沒有以獨立儀器或已知工作負載比對各指標精度；GPU/NVML 和 disk activity 尚無專項硬體/數值驗證。app protocol smoke 只證明 snapshot 流程完成，不能據此宣稱所有硬體值正確。

## Phase 3 — Runtime / State Machine / Bounded Cache

- **狀態：核心政策測試通過；產品執行緒整合未完成。** Ring buffer 保留最多 120 筆、latest-wins coalescer、change detector、power state machine、sampling scheduler 都有 C++ 測試。
- **測試：PASS** — CTest 21/21，包括有界 history/coalescing、狀態轉換、防抖與 scheduler 不補跑過期採樣。
- **限制：**目前 app 以 UI timer 同步採樣；尚無背景 sampling worker 與已驗證的 worker→UI mailbox lifecycle、shutdown/race stress、session/display/power notification、WebView suspend/resume。

## Phase 4 — WebView2 Host + Protocol v1

- **狀態：原生 host 與 JSON protocol 已建置並做程序層整合 smoke；安全負面與 GUI 渲染驗收未完成。** Host 使用 WebView2 virtual host mapping、私有 user-data directory，處理 SDK hello/ready、snapshot/history/subscribe；拒絕非本機 navigation/resource 和新視窗。
- **測試：PASS** — CTest 21/21，含原生 JSON 序列化/解析、64 KiB 限制、版本/欄位/請求 ID/history/subscribe cases；`scripts/test-webview2-smoke.ps1` 對 `minimal` live collector 與 `dashboard --mock-metrics` 均觀察到完成 hello→snapshot→subscribe 的 `Live metrics` 標題。
- **限制：**未用真實 JS 惡意 payload/外部請求做 WebView2 負面整合測試；無 renderer crash/reload 恢復測試；未用截圖或人工視覺檢查 DOM/排版；WebView2 執行於 UI thread，metrics 也在 UI timer 同步採集。

## Phase 5 — Theme Manager / SDK / Examples

- **狀態：SDK/作者工具完成可測部分；原生 Theme Manager 未實作。** 有 manifest validator、TypeScript 宣告、JS SDK/MockHost、minimal/dashboard 範例、`.dmt` 封裝/驗證器。WebView2 透過 CLI 可各自載入兩個內建來源，尚未提供執行期熱切換。
- **測試：PASS** — 18/18 Node 測試；`.dmt` validator 接受有效包，拒絕 traversal、大小寫重複路徑、不允許副檔名、錯誤 API version、超過 10 MiB 檔案；SDK package 解壓後重跑測試與兩個 theme validator，SHA-256 可重現。
- **產物：**`artifacts/DrillPaper-Theme-SDK-1.0.0-rc3.zip`，49,107 bytes，SHA-256 `68E0B5F41FB2337B396A5335CA1707B0F6F5E275F3771EF913E1DF8210D01656`。Apache-2.0；本機評估包，不含 app。
- **限制：**無 `.dmt` 原生匯入、staging/atomic install、列舉、切換、rollback、舊 API 提示或 100 次切換資源測試。

## Phase 6 — Smart Sleep / Recovery / Security Hardening

- **狀態：部分策略與 baseline host 控制已實作；未達安全或省電驗收。** C++ `ThemeNetworkPolicy` 模型測試通過；WebView2 host 阻擋外部 navigation/resource 和新視窗。
- **測試：PARTIAL** — CTest policy/schema cases 通過；未對 WebView2 執行 egress、redirect、fetch/XHR/image/script/iframe/WebSocket、permission 或 download 負面測試。
- **限制：**使用者要的首次阻擋提示與單一全域 allow HTTP/HTTPS 開關尚未接入；network policy model 未整合至 request interception。尚無 WTS/display/power events、TrySuspend/Resume、renderer/Explorer crash recovery。不得宣稱外部主題已沙箱化或 egress 已驗收。

## Phase 7 — Performance / Regression / Compatibility

- **狀態：量測工具有 smoke；產品效能與相容性驗收未跑。** Process-tree sampler 支援將可追溯 WebView2 child processes 計入統計；曾以 DrillPaper+WebView2 跑短時程序樹 smoke，觀察到 app 與 `msedgewebview2`，共兩筆 sample。
- **測試：NOT RUN** — 無 10–30 分鐘產品 CSV，也未比較 minimal/dashboard、locked/display-off、主題切換或長時間資源成長。
- **相容性：NOT RUN** — 目前只在 Windows 10 Pro x64 build 19045 建置；Windows 11、多螢幕、DPI/熱插拔與 Explorer recovery 未驗收。

## Phase 8 — CI / Packaging / Release Candidate

- **狀態：SDK RC 可交付本機評估；DrillPaper app RC 被正確 gate 阻擋。** `scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1 -LocalToolchain` 實際完成 build、完整測試後停止，明確報告缺 `src/themes/theme_manager.cpp`。沒有產生 app ZIP；不要稱 app RC 已完成。
- **測試：PASS / BLOCKED** — `scripts/test.ps1 -Configuration Release -LocalToolchain`：CTest 21/21、Node 18/18、環境檢查回歸、`.dmt` 正負案例及 SDK ZIP 解壓/重封驗證全通過。Windows GitHub Actions 未執行。`--version`、`--diagnostics` 與 WebView2 smoke 已實測。
- **限制：**沒有安裝器、乾淨 Windows user install/uninstall 驗證、app ZIP、簽章、長時間效能報告或 CI runner log。
- **下一步：**實作與測試 Theme Manager、使用者網路提示/全域設定、worker/smart sleep、原生 Shell GUI 支援；完成安全與效能矩陣後再解除 RC gate。需在可寫 `.git` 的受控環境按 Phase 建立 commit。
