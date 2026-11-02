# RC 10：原回歸前置條件未成立，停止未提交

2026-11-02，分支 `feature/rc-10-controlled-resume-regression`，base／停止時 HEAD 均為 `a3c183f5abe9d10f5184ad95aca8bb63bab0ed6f`。**本票未完成，原 09-D2 FAIL 與 A08 gate 保留，拒絕 RC。**

已依序用 09 trial.7 EXE 與目前 HEAD 的 Release 執行原命令。兩者都在擴充測試開啟智慧休眠後、尚未進入該段手動暫停／受控 WTS 往返前失敗，沒有取得原 09-D2 的等價失敗回歸。依使用者「前提不成立時停止、不 commit」停止診斷與實作；只保存需求、證據與交接，未修改 src／include、測試腳本、政策或斷言，未 commit／push。

## 來源、環境與執行

- 原 ZIP `artifacts/DrillPaper-0.1.0-trial.7-win-x64-unsigned.zip`：472507 bytes，SHA-256 `87FE10E27EB016D144F8C775BEEA4C81C724BD513BDDE61DE9F866465FDBC29D`。
- trial.7 EXE：SHA-256 `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`，產品來源 `676bb473efeca65614fddb40d98e3c88c302494b`。從 09 原解壓包複製到全新使用者目錄，hash 相符，資產沿用包內內容。
- HEAD Release EXE：SHA-256 `8E8953FA98842F37965C4FC0C8F3C3FD93E22FD7E1A161B8D9AED3180CE6214A`，來源為 `a3c183f`，本輪成功增量建置。隔離副本包含 Release EXE、resources 與 WebView2Loader.dll，不冒稱新交付包或全新 configure。
- Windows 11 專業版 10.0.26200；兩個 1920×1080 區域，DPI144／96，原始 HWND／parent／世代見各輪 phases／failure。
- **環境差異**：已安裝 WebView2 Runtime `156.0.4314.58`，09 記錄為 `156.0.4314.50`。這是已安裝版本觀測，不宣稱已讀取實際載入 DLL 版本，也不歸因於 Runtime。
- 非 Temp 工作區：`C:\Users\James\DrillPaperTests\RC10 受控恢復 含空白 20261102-091243`。TEMP／TMP 指向其 staging；各輪使用全新隔離 LOCALAPPDATA，既有 Node launcher 直接 spawn EXE，產品實測循序執行。原始 profile 留本機，證據只複製各目錄根層 JSON／JSONL／log，未複製 appdata。
- 原命令介面及目前工具未改。`scripts/test-multi-monitor.ps1` SHA-256 `56FBC0F7CABF0CA123E7159BF913B5EBFAC9AD54D980E18F451EEBE3099BC376`，其餘來源／DLL／fixture 指紋見 [source-fingerprints.json](source-fingerprints.json)。原 35 秒 Wait-Condition、17 秒暫停觀察與退出判準不變。

```powershell
# 每輪 ApplicationPath、EvidenceDirectory、ParentFixturePath 的完整值及 hash
# 分別保存在 trial7-command.json 與 head2-command.json。
pwsh -NoProfile -File scripts/test-multi-monitor.ps1 -ApplicationPath <trial.7 EXE> -EvidenceDirectory <trial7-original> -ParentFixturePath <Release fixture> -DesktopPowerRecovery

& "$env:APPDATA/uv/tools/cmake/Lib/site-packages/cmake/data/bin/cmake.exe" --build --preset windows-msvc-release --target DrillPaper DrillPaperParentFixture --parallel 8

pwsh -NoProfile -File scripts/test-multi-monitor.ps1 -ApplicationPath <HEAD Release EXE> -EvidenceDirectory <head-original2> -ParentFixturePath <Release fixture> -DesktopPowerRecovery
```

使用既有 uv CMake 套件原生工具，沒有執行失效 Python launcher、重裝工具或跑完整測試。

## 分開記錄的結果

| 執行 | 結果／時間（+08） | 精確停止點 |
| --- | --- | --- |
| trial.7 原命令 | FAIL，09:14:34.140，工具 exit1 | `Test-DesktopPowerRecovery` 開啟智慧休眠、Wait-Ready 通過後，第一次 Assert-FreshMetrics 逾時：「宿主沒有繼續推送新的指標。」尚未記錄 smart-sleep-enabled，尚未執行該段 20002／WTS7／WTS8 |
| HEAD 初次隔離副本 | 測試準備失敗，09:15:04.172，工具 exit1 | 漏複製 WebView2Loader.dll，CLI 匯入前退出碼3221225781；沒有進入產品回歸。補齊同次 Release DLL 後用新證據目錄執行，原失敗保留 |
| HEAD 完整隔離副本 | FAIL，09:16:25.410，工具 exit1 | 開啟智慧休眠後的 Wait-Ready 逾時：「目標數量或 WebView2 握手不符。」未到 Assert-FreshMetrics 或該段手動暫停／WTS 往返 |
| HEAD Release 建置 | PASS，exit0 | 僅 DrillPaper／DrillPaperParentFixture；原始命令及 MSBuild 結果見 head-release-build.log |

trial.7 逾時時，兩目標 LoadEpoch3／4、ReadyEpoch3／4，MetricsTick0／HealthTick0，標題均 `display-off — 已暫停`。HEAD 逾時時，兩目標 LoadEpoch3／4、ReadyEpoch0／0，MetricsTick0／HealthTick0，標題均 `display-off — 低頻模式`。**兩輪前置失敗不同，不混稱完全相同症狀。**

09 原 FAIL 已成功記錄 smart-sleep-enabled、新 MetricsTick／HealthTick、擴充段的手動暫停及受控鎖定往返；最後解除手動暫停才逾時。本輪兩次沒有到達該觸發鏈，因此錯誤文字相似不足以建立等價回歸。基本流程中較早的暫停／恢復操作與擴充段分開，不宣稱本輪完全沒有傳送過20002。

本輪沒有同步觀測實際 OS 顯示器電源／工作階段狀態；`display-off` 標題是產品輸出，不能當作真正螢幕關閉的證據。手動暫停與 OS／受控通知的優先權尚未診斷，不自行新增政策，不強迫喚醒真正螢幕，也不以關閉智慧休眠繞過原斷言。

完整原始結果見 [trial7-original/failure.json](trial7-original/failure.json)、[head-original2/failure.json](head-original2/failure.json)，各輪 launch／identity／exit、requests、viewports、phases 與工具錯誤均分目錄保留。GUI 兩輪各兩次正式退出碼0，CLI 匯入亦0；初次副本缺DLL另記。沒有把整合失敗的清理結果列為整組PASS，也不宣稱捕捉了所有短命子程序。

## 防毒與原桌布

可讀 Trend Micro Apex One `AEGIS_BM.log` 在 before、中段、after 均41998bytes／最後修改 `2026-11-01T09:42:36.4875549+08:00`／SHA-256 `E395850C13B01016BAEFBB4CADFE7846032D34768953B97E9037F2FBB3765F81`。本輪未觀察新增攔截；這不是完整防毒觀測，不推定沒有介入，也不把未知前置 FAIL 改成防毒 BLOCKED。沒有修改防毒設定。09 的舊指紋不同，按日期分開，不據此推斷本輪攔截。

原桌布PID83428完整路徑、UTC ticks `639288432499803524`、SHA-256 `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 前後相符。收尾只剩此 app，本次隔離路徑對應 WebView2 程序0；未重啟 Explorer、未關閉／替換原桌布。詳見 environment-before／after.json。

## NOT RUN 與續作條件

- 原 09-D2 觸發鏈、根因診斷／最小化、TDD 回歸及最小修正：NOT RUN，兩版本都未通過先前已成立的擴充前置條件，依明示規則停止。
- renderer／browser 故障交錯、8輪有界退化、JS無限迴圈及後段父fixture：NOT RUN，前段失敗而未到達。
- 相關單元測試／型別或靜態檢查、新版重包及預設啟動／保存Preview／退出：NOT RUN，未修改產品或測試，且停止於重現階段；本輪退出碼記錄不取代獨立交付矩陣。
- 完整測試套件／CI：NOT RUN，依使用者指示留收尾。
- code-review／commit-msg／commit／push：NOT RUN，本票未完成且使用者明示前提不成立不可提交。沒有合併 main 或公開發布。
- 真正 OS／畫面／硬體人工矩陣：NOT RUN，步驟見 [人工清單](MANUAL_CHECKLIST.md)。

下一步需確認續作方向：在目前 Runtime 下先補**只讀同步 OS 電源／工作階段與產品有效政策觀測**，釐清智慧休眠前置條件；或在具原 `156.0.4314.50` Runtime 的獨立環境重現原鏈。兩者都不能先歸因於產品或環境，不改本機 Runtime／政策，也不解除09-D2。若後續證據指出優先權政策未規定，先列選項請使用者決策，再實作。
