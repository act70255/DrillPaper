# RC 10：同步 OS 狀態後兩版本未重現，停止未提交

2026-11-02，沿用 `feature/rc-10-controlled-resume-regression`，開始／停止 HEAD 均為 `40e007f54cc2f6920b02c604f24332cbb9efbe5c`。**本票仍 in-progress：兩輪原命令完整 PASS，但未取得原 09-D2 或上一輪前置失敗的可重現失敗回歸，不能宣稱根因修復或解除 A08／RC gate。**

依票 Comments 最新「決策（使用者確認，2026-11-02）」先記 [REQUEST](REQUEST.md)，再建立全新證據目錄。取得可重現失敗才診斷／TDD 修正的前提未成立，依使用者停止規則停止產品工作、不 commit／push；只保存本輪證據並更新票與 STATUS。不覆寫 `controlled-resume/` 或 09 原 FAIL，不把本輪 PASS 改寫成歷史失敗已被解釋。

## 來源、命令與環境

- trial.7 ZIP：472507 bytes，SHA-256 `87FE10E27EB016D144F8C775BEEA4C81C724BD513BDDE61DE9F866465FDBC29D`；EXE SHA-256 `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`，原產品來源 `676bb473efeca65614fddb40d98e3c88c302494b`。
- HEAD Release：成功建置 `DrillPaper`／`DrillPaperParentFixture`，未執行完整套件。隔離副本包含 EXE、resources、WebView2Loader.dll；EXE SHA-256 `8E8953FA98842F37965C4FC0C8F3C3FD93E22FD7E1A161B8D9AED3180CE6214A`，與上一輪相符。沒有修改 src／include／scripts／tests，沒有產生新交付包。
- 固定原工具 `scripts/test-multi-monitor.ps1` SHA-256 `56FBC0F7CABF0CA123E7159BF913B5EBFAC9AD54D980E18F451EEBE3099BC376`；原 35 秒 Wait-Condition、17 秒暫停、180 秒無限迴圈觀察與退出判準均未修改。fixture SHA-256 `0BAB8F01DCD71036AD80C520AA16C0774F80D62EA436DA218CA28AB0D501AC56`，明確指定既有外部 Release fixture。
- Windows 11 Pro `10.0.26200`；雙 1920×1080 區域、DPI144／96。兩輪實際觀察的 browser 路徑均為 `EdgeWebView/Application/156.0.4314.58/msedgewebview2.exe`，檔案版本另見 [runtime-identity.json](runtime-identity.json)。09 為 `.50`，本輪沒有切換 Runtime，不能排除版本差異。初次 environment-before 的 registry key 查詢沒有值，原 `runtime:null` 保留，以實際程序路徑／檔案版本補證，不覆寫原始紀錄。
- 全新非 Temp 使用者工作區：`C:\Users\James\DrillPaperTests\RC10 同步重試 含空白 20261102-093410`；TEMP／TMP 指向其 staging，各輪獨立 appdata，產品由既有 Node launcher 直接 spawn。兩輪產品實測循序，第一輪退出與無殘留後才建置／執行第二輪。

```powershell
# 完整路徑、開始時間、來源及各檔 SHA 見各輪 command.json。
pwsh -NoProfile -File scripts/test-multi-monitor.ps1 -ApplicationPath <trial.7 隔離 EXE> -EvidenceDirectory <新 trial7-original> -ParentFixturePath <Release fixture> -DesktopPowerRecovery

& "$env:APPDATA/uv/tools/cmake/Lib/site-packages/cmake/data/bin/cmake.exe" --build --preset windows-msvc-release --target DrillPaper DrillPaperParentFixture --parallel 8

pwsh -NoProfile -File scripts/test-multi-monitor.ps1 -ApplicationPath <HEAD 隔離 EXE> -EvidenceDirectory <新 head-original> -ParentFixturePath <Release fixture> -DesktopPowerRecovery
```

完整參數見 [trial7-command.json](trial7-command.json)、[head-command.json](head-command.json)。原工具內部以 Node 啟動產品／fixture，PowerShell 僅為原測試 runner。

## 同步只讀 OS 觀測

獨立 `observe-os-v2.ps1` 使用 `PowerSettingRegisterNotification` 訂閱 `GUID_CONSOLE_DISPLAY_STATE` 初始／後續值，另以 `WTSQuerySessionInformationW(WTSSessionInfoEx)` 直接查詢 session ID、連線及鎖定旗標。每次取樣同步讀取本次隔離宿主的標題、可見性、LoadEpoch／ReadyEpoch／MetricsTick／HealthTick／TargetDpi，未對產品送出任何控制訊息。

觀測器沒有呼叫 SetThreadExecutionState、輸入模擬、喚醒、鎖定／解鎖或電源設定變更。初版 helper 的宿主類別名稱於**產品啟動前**校正為既有 `DrillPaperPreviewWindow`；setup 原始觀測與兩版 helper 都保留，不把準備校正記成產品失敗。

- 09:36:47.030～09:50:20.878（+08），共 **5263 筆**；console display 全部 `1=on`，初始通知後 sequence 維持1；session ID1、連線狀態全部 `0=active`、鎖定旗標全部 `1=unlocked`。
- 每輪命令前另保存 [trial7-os-before.json](trial7-os-before.json)／[head-os-before.json](head-os-before.json)，皆 on／unlocked。取樣迴圈目標間隔100ms，但 API／排程有耗時，實測最大相鄰起始時間差578ms，不能宣稱精確100ms或沒有取樣間隙。
- 原始 OS JSONL 保存在 ZIP；[os-summary.json](os-summary.json) 保留所有有時間戳 phase 與最近 OS 樣本、時間差及宿主值。手動暫停快照與最近 OS 樣本時間差分別22ms／39ms。
- 觀測器會在 failure.json 出現時追加 OS 樣本；本輪沒有 failure.json，失敗當下路徑**未觸發**，不能宣稱已驗證失敗擷取分支。Windows console 回報不是每台實體螢幕的像素／面板電源量測，也不取代人工畫面驗收。

API 依據及限制見 [REQUEST](REQUEST.md) 的 Microsoft 文件。這些觀測不能反推 10-30 或上一輪 09:14～09:16 的真實狀態。

## 分開記錄的結果

| 輪次 | 原命令／退出 | 原 09-D2 觸發鏈 | 後段相關範圍 |
| --- | --- | --- | --- |
| trial.7，09:37:03～09:43:18 | PASS／exit0 | 智慧休眠握手與新資料→手動暫停→受控WTS7／8→17秒維持暫停→解除後新 MetricsTick／HealthTick 通過 | renderer／browser 與受控鎖定交錯、8輪有界退化、真正JS無限迴圈約91.09秒退Minimal、父fixture故障、模式／保存／離線暫用及退出通過 |
| HEAD Release，09:44:19～09:50:15 | PASS／exit0 | 同一原鏈通過，未重現上一輪開啟智慧休眠後未握手 | 同範圍通過；JS無限迴圈約92.04秒退Minimal |
| HEAD Release build | PASS／exit0 | 僅指定兩個target，無產品修正 | 不是新包／完整套件或CI結果 |

兩輪各三次 GUI 正式退出碼0；各19個當下可觀察的 WebView2 子程序退出，CLI匯入亦exit0。trial.7 收尾及最終按隔離路徑／profile查詢無本輪產品／fixture／WebView2殘留；不宣稱捕捉所有短命子程序。

原始 [trial7 result](trial7-original/result.json)、[HEAD result](head-original/result.json) 包含 phases／各宿主幾何與世代。OS 取樣在暫停快照後約5.724／5.816秒首次看到兩宿主皆有新 MetricsTick、HealthTick 與 Live metrics。這是「快照到取樣」的觀察時間，沒有逐次攔截管理命令時間，不冒稱精確命令回應延遲；實際通過仍由未修改原斷言認定。

## 政策與缺陷判讀

手動暫停期間，OS 為 on／unlocked、宿主標題為 `display-off — 已暫停`，兩輪均已原樣記錄。已確認[系統匣票01](../../../../.scratch/tray-management/issues/01-tray-lifecycle.md)規定「手動暫停優先於智慧休眠，繼續恢復當前有效政策」，架構也區分手動暫停與實際電源。現行 `ManagedPlayback::EffectiveState` 在 paused 時回傳 DisplayOff；因此此段標題是合成有效政策，不能當作產品讀到真實 OS 關屏的證據。解除後兩輪都恢復推送，沒有據此新增或改變政策。

本輪未取得「解除後／非手動暫停仍錯誤 display-off」失敗，也未取得「真實 display-off 下未握手」失敗；後者因真實 console 沒有關閉，該情境 NOT RUN，不能由本輪 PASS 排除上一輪症狀。沒有新增已證實獨立缺陷，沒有 TDD Red，不虛構回歸或做推測性修正。

**停止原因：可重現失敗尚未取得。** 這次不是因真實關屏到不了觸發鏈，而是兩版本已到達並通過原鏈；歷史09-D2仍原因未定。單一新版Runtime情境通過不足以宣稱原失敗是環境或產品問題。原 `.50` Runtime 的獨立環境、真實OS矩陣或未來再次失敗時的同步觀測，仍是進一步重現的選項；本輪不變更Runtime或政策。

## 防毒與原桌布

可讀 Apex One `AEGIS_BM.log` 在 before、trial.7中／後、HEAD中及after皆41998bytes、最後修改 `2026-11-01T09:42:36.4875549+08:00`、SHA-256 `E395850C13B01016BAEFBB4CADFE7846032D34768953B97E9037F2FBB3765F81`。未觀察新增攔截，沒有已證實受攔截項目；不推論完整無防毒介入，不修改防毒設定。若後續有規則／時間／產品攔截證據，受影響項須獨立標 BLOCKED。

原桌布83428路徑、建立 UTC ticks `639288432499803524`、SHA-256 `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 前後相同；收尾唯一 DrillPaper app。Explorer PID93396 建立於10-29，本輪未重啟Explorer，未關閉／替換原桌布。詳見 environment-before／after。

## 證據保存與未執行

[raw-evidence.zip](raw-evidence.zip)：217089bytes，SHA-256 `67E111165AA04593DD7F4B542E2183406D6A2E6D532B5CDE4BCEF27708B36C72`。內含92個原始檔與 manifest，包含完整 OS JSONL、兩版觀測器、彙整器、命令／啟停／建置／防毒／來源指紋、各輪根層證據與測試主題來源、設定／管理日誌摘錄。不含 EXE／DLL 或整份 WebView2 profile；原隔離資料保留本機。前一輪及09證據目錄未改動。

封存後以 `ZipFile.OpenRead`／`SHA256.HashData` 核對ZIP本身及manifest所列92項長度／雜湊，全部相符；REQUEST／REPORT／人工清單的本機Markdown連結存在，`git diff --check` 通過。`git diff --name-only -- <前輪證據> <09證據> src include scripts tests` 無輸出；這些是證據／文件完整性核對，不是額外產品測試或完整套件。

- 根因診斷／最小化、TDD新失敗測試與產品修正：**NOT RUN**，未取得可重現失敗；本票仍in-progress。
- 相關單元／SDK／型別或靜態檢查、全套／CI：**NOT RUN**，沒有程式變更；只執行上述原整合命令與指定建置，完整套件依使用者指示留收尾。
- 新版本重包、產品預設啟動／保存Preview／退出交付矩陣：**NOT RUN**，沒有產品變更；本輪模式／退出檢查不冒稱獨立交付矩陣。
- 真實OS鎖定／關屏／待機、硬體／畫面／其他Runtime：**NOT RUN**，只讀觀測與受控通知不能代替；見[人工清單](MANUAL_CHECKLIST.md)。
- code-review／commit-msg／commit／push：**NOT RUN**，本票未完成，依「前提不成立停止、不commit」停止規則；未合併main、未公開發布，無ADR或政策決策。
