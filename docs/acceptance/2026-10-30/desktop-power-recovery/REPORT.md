# RC 05：前輪啟動調查與接續驗收

下列「停止點」及原始結果保留前一輪歷史；最新使用者決策已將啟動缺陷改記「未重現，疑似環境」，不再追 Red。本輪接續結果、無回應缺陷的 Red／Green、版本及 gate 見 [接續報告](resume/REPORT.md)，真實 OS／目視缺口見 [人工清單](MANUAL_CHECKLIST.md)。前輪「未完成／未提交」不是本輪的結案狀態。

2026-10-30。分支 `feature/rc-05-desktop-power-recovery`，起始及停止 HEAD 均為 `2a69ed18a649770359c03b76b1503cfd51262a0c`。05 維持 in-progress，**未完成、未 commit、未 push**。產品 src/include、智慧休眠預設、03 試用入口與 ZIP 均未修改。

## 停止點

本票 Comments 與使用者要求「先留下可重現失敗回歸，再診斷根因、最小修正」。在已確認的非 Temp／Node 啟動條件下，原失敗產品 EXE 的兩次全新資料測試都完成握手，尚無可重現 Red，無法進入根因診斷或宣稱修復。依「前提不成立時停止、不 commit」保留工作樹與證據，不製造失敗、不套用推測性修正。

這不表示歷史缺陷不存在，也不證明防毒是根因。03 的 [原失敗](../../2026-10-29/trial-package/default-startup-failure.log) 與歷史 FAIL 保留；其時段防毒紀錄已不存在，不能排除干擾。08 不應據本輪握手成功移除 `--no-smart-sleep` 繞行，09 gate 亦未解除。

## 環境及隔離

- Windows 11 Pro 25H2 26200.8737，WebView2 Runtime `156.0.4314.50`（原版本隔離 profile 的 `EBWebView/Last Version`），SDK 1.0.2478.35；本機一般使用者。
- 兩個實體桌面矩形：主屏 `(0,0)-(1920,1080)`／DPI 144，副屏 `(1920,0)-(3840,1080)`／DPI 96。原生列舉 [monitors.log](monitors.log)；未變更顯示設定、未拔插，不能代表桌布幾何通過。
- 原 ZIP `0.1.0-trial.4` SHA-256 `C3ECF566EAB58D4A015D44D749E60F1E6872F5830F31AEB0F3B303ECC40C3287`，產品來源 `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53`。解壓至 `%USERPROFILE%/DrillPaperTests/桌面電源 含空白/rc05-original`，直接啟動 EXE 並指定 `--management --preview`，不經試用包入口、不帶 `--no-smart-sleep`。原 EXE hash 與 trial.3 原失敗相同，見下表。
- HEAD 觀測用另一解壓副本 `rc05-baseline`，只將 EXE 換成目前建置位元；不是重新建置／封裝的交付包。
- 每輪獨立且事先不存在的 evidence/appdata 作 LOCALAPPDATA；Node 直接 spawn EXE，PowerShell 7 僅負責呼叫 Node 與 Win32 觀測。父子 PID、啟動時間及退出碼為本目錄 `launch-*.started.json`／`*.exit.json`，原始 request 與 profiles 留忽略目錄 artifacts。未載入原使用者設定。
- Apex One 可讀 `AEGIS_BM.log` 前後均 8332 bytes、修改時間 `2026-10-30T09:22:30.9964599+08:00`、SHA-256 `0B6BE9A504AAC9279EB2E3852B84CF8371DCFC5031142CB76635FE0FD1C59A2E`。本輪未觀察新增攔截；不是完整防毒觀測，不將 03 的規則 `NON_POLICY_JUST_MEERKAT` 誤算為本輪事件。未修改防毒設定。未來受攔截輪次須記產品／規則／時間／項目並列 BLOCKED。

## 實際結果

| 輪次 | EXE SHA-256 | 結果及限制 |
| --- | --- | --- |
| Windows PowerShell 5.1 初次工具失敗 | `AA41960045CBDDE7B6EDB585A84D7E92E235C215C202137EEA4A9AB023151D8E` | [紀錄](rc05-startup-red1.json)：Start-SecurityProcess 身分檢查失敗，沒有握手樣本，**不算產品 Red**。唯讀另查發現該環境未指定 UTF-8 讀取 Node JSON 會產生繁中亂碼，但未確定為身分檢查失敗根因；未改既有 helper。核對漏接的測試 PID 93144 的 path／精確建立時間後，經原生命令退出 0。 |
| HEAD 首次 PowerShell 7 觀測 | 同上 | [紀錄](rc05-startup-red2.json)：約 1.74 秒 ReadyEpoch=1，非 Red。草稿誤用通知視窗類別，清理逾時後終止自身測試 app，退出 -1；**不算正常退出 PASS／產品失敗**。修正測試類別為既有 `DrillPaperShellNotifications`，沒有修改產品。 |
| 原失敗產品版本，第 1 輪 | `B0FF9A734713AF939C6444092B6D008DEDEF9480A17932D1B4B9D92C0FE71781` | [紀錄](rc05-startup-original1.json)：約 2.49 秒 ReadyEpoch=1，觀測至約 30 秒；正式退出 0、6 個已觀察子程序 handle 均退出。未操作設定，但此輪尚未讀取勾選狀態。 |
| 原失敗產品版本，第 2 輪 | 同上 | [紀錄](rc05-startup-original2.json)：約 2.55 秒 ReadyEpoch=1，觀測至約 30 秒；唯一管理視窗智慧休眠 BM_GETCHECK=1；正式退出 0、已觀察子程序均退出。 |

原版本兩輪最後標題為 `Live metrics`，只能作握手與標題觀測；未逐次讀取 MetricsTick、未檢查 DOM 或畫面，不宣稱畫面持續更新／存活。觀測迴圈為 250ms 取樣，最後樣本在 30 秒邊界前，未偽稱精確 30.000 秒截點。

測試草稿 [test-default-startup.ps1](../../../../scripts/test-default-startup.ps1) 要求 PowerShell 7，保留握手等待、原生智慧休眠勾選、退出及子程序身分／handle。仍是未提交草稿，未完成整體審查；檔名含 red 的早期證據均是預期名稱，不代表取得產品 Red。

## 命令與驗證

```powershell
# 既有 ZIP 解壓至非 Temp 使用者目錄；不呼叫帶繞行參數的試用入口。
$application = Join-Path $env:USERPROFILE 'DrillPaperTests/桌面電源 含空白/rc05-original/DrillPaper.exe'
pwsh -NoProfile -File scripts/test-default-startup.ps1 -ApplicationPath $application -EvidenceDirectory artifacts/acceptance/rc05-startup-original1
pwsh -NoProfile -File scripts/test-default-startup.ps1 -ApplicationPath $application -EvidenceDirectory artifacts/acceptance/rc05-startup-original2
ctest --preset windows-msvc-release -V -R '^Connected monitors '
```

兩次 startup 命令均退出 0；同名 evidence 不覆寫，重跑需換新目錄。第 1 輪在加入有效勾選讀取前執行，第 2 輪使用目前草稿。相關 monitor CTest 1/1、12 assertions PASS，只驗原生列舉。未跑完整套件。

## NOT RUN／後續所需

1. 原缺陷可重現 Red、根因假說／診斷、最小修正、修正前後回歸：NOT RUN／停止，兩輪原版本未重現。需要保留原失敗時的前景全螢幕、電源／工作階段、載入時間線及防毒事件等額外條件，或確認新的環境／時序調查範圍後接續；目前不斷言任何一項是根因。
2. 新版多宿主混合 DPI 桌布幾何、全螢幕／部分覆蓋政策、暫停／繼續、無回應 JS、renderer／browser 與電源／Explorer 交錯：NOT RUN，尚未通過本票要求的第一步；不以既有腳本結果代替本輪。
3. 真正 Explorer 重啟／系統匣點擊、桌面圖示／工作列／Alt+Tab／焦點／虛擬桌面、拔插／其他解析度／DPI、鎖定解鎖／顯示器關閉／待機喚醒：NOT RUN，依已確認決策保留人工清單。接續應於合適隔離桌面逐項觀察每個宿主畫面與更新、圖示／工作列、唯一管理入口與退出，不以受控訊息代替 OS 事件，不操作原持續桌布。
4. 其他 Windows／Runtime、完整測試套件、重新建置與打包、code-review／commit-msg／commit／push：NOT RUN；環境矩陣與全套留後票，其餘因尚無 Red 而停止，沒有宣稱完成實作。

收尾僅剩原持續桌布 PID 83428，path／StartTime `2026-10-29T12:00:49.9803524+08:00`／SHA-256 `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 不變，見 [收尾環境](after-environment.json)。未關閉／替換、未重啟 Explorer。所有新測試 app 均已退出。
