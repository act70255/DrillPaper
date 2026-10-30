# RC 05 接續：桌面／電源與無回應復原

2026-10-30，沿用 `feature/rc-05-desktop-power-recovery`，來源 HEAD `2a69ed18a649770359c03b76b1503cfd51262a0c` 與前輪未提交調查。未另開分支、未重做前輪啟動觀測。依 ticket 最新確認決策，原啟動缺陷記為「未重現，疑似環境（Apex One 對 Temp／PowerShell 啟動介入）」，沒有斷言防毒根因，不為該缺陷製造 Red 或修正預設。

## 範圍與 TDD

已確認 seam：runtime 政策及 Win32／WebView2 原生整合；本輪新增故障觀測使用真正隔離程序與 JS，沒有以單元測試代替畫面。擴充 `test-multi-monitor.ps1 -DesktopPowerRecovery`，保留前輪 `test-default-startup.ps1` 作預設啟動觀測。完整套件留 09。

- Red：原 HEAD EXE 的兩個主題頁面在握手後執行真正 `while (true)`，180 秒內均未有界回復 Minimal；載入世代保持 29／30。原生 `MetricsTick` 仍前進，不能證明 JS 或畫面存活。[power2 日誌](power2.log)、[失敗結果](power2-red.json)、[完整時序樣本](power2-red-phases.json)。額外 [CPU 觀測](loop-renderer-cpu.json) 顯示兩個 renderer 各在約兩秒增加約兩秒 CPU；只用於確認無限迴圈確實執行，不是效能基線。
- 最小修正：web adapter 以 UI 計時器每五秒啟動非同步 `ExecuteScript("0")`，同一 controller 最多一個 pending；啟用中超過十五秒無回應，送出帶載入世代的既有 renderer 失敗訊息。沿用原主題三次重建、可信 Minimal 及其後有限停止，不新增權限或主題 API，不重啟採樣器。暫停時停止計時，恢復重新計時；Shutdown 撤銷 lifetime token、清理健康屬性。失敗記入既有 `management.log`，含世代與類型。
- `HealthTick` 僅在 JS 回呼成功後前進；測試同時要求新握手、`MetricsTick` 與 `HealthTick`，仍不宣稱每次 DOM／像素更新。Microsoft 的 [程序事件說明](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-related-events) 將 unresponsive 與輸入回應相關聯；本機無輸入的桌布不能只依賴該事件，以上 Red 是本輪修正依據。

## 環境與防毒

Windows 11 Pro 25H2 26200.8737，WebView2 156.0.4314.50、SDK 1.0.2478.35；一般使用者，雙 1920×1080，主屏 DPI 144、副屏 DPI 96。前輪 [螢幕列舉](../monitors.log) 沿用，未改解析度或拔插。

測試 EXE 是前輪 trial.4 解壓副本的衍生隔離副本，位於 `%USERPROFILE%/DrillPaperTests/桌面電源 含空白/rc05-baseline`／`rc05-fixed`；fixed 只換入本輪建置的 EXE 與 fixture，不是新交付 ZIP。原包及啟動入口沒有變更。LOCALAPPDATA 也各自隔離於同一非 Temp 使用者子目錄。EXE 全由 Node `security-launcher.mjs` 直接 spawn，PowerShell 7 只負責 Node 啟動與原生觀測。

前輪 EXE SHA-256 `AA41960045CBDDE7B6EDB585A84D7E92E235C215C202137EEA4A9AB023151D8E`。修正後 SHA-256 `25316B5067076749295B62DB557748B6DC2D88C4069CFBBE4C48E93269F6D26D`，見 [fixed-exe-hash.log](fixed-exe-hash.log)，建置輸入為 base 加本票工作樹；不冒稱該位元是 base commit 的產品。原持續桌布的身分與防毒紀錄見 [before-environment.json](before-environment.json)／[after-environment.json](after-environment.json)：path、精確建立時間 `2026-10-29T12:00:49.9803524+08:00`、SHA-256 `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 前後相同，收尾只剩該 app，沒有 fixture。未關閉／替換原桌布、未重啟 Explorer。

Apex One 可讀行為日誌前後均 8332 bytes、修改時間 `2026-10-30T09:22:30.9964599+08:00`、SHA-256 `0B6BE9A504AAC9279EB2E3852B84CF8371DCFC5031142CB76635FE0FD1C59A2E`，本輪未觀察新增攔截。不是完整防毒觀測，不把工具錯誤歸為防毒，也不改防毒設定。後續若有攔截，必須逐次記產品／規則／時間／項目並標 BLOCKED。

## 執行結果與命令

建置：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperParentFixture --parallel 8`，增加 HealthTick 後重建 `DrillPaper`。見 [build.log](build.log)、[build-health.log](build-health.log)。

相關 CTest：`ctest --preset windows-msvc-release -V -R '^(Power state|Sampling scheduler|Sampling worker|Desktop recovery|Manual pause|Monitor selection|Clone targets|Connected monitors|Protocol v1)'`，修正後 18/18 PASS，見 [ctest-after.log](ctest-after.log)；前次相關 11/11 見 [ctest.log](ctest.log)。PowerShell 7 parser 3/3 PASS，見 [parser-after.log](parser-after.log)；`node --check tests/desktop-power-tools.test.mjs` PASS。這些不證明真正 OS 事件或畫面通過。

```powershell
# 需 PowerShell 7；EXE 已在非 Temp 使用者目錄，程式內由 Node 直接啟動。
pwsh -NoProfile -File scripts/test-multi-monitor.ps1 `
  -ApplicationPath "$env:USERPROFILE/DrillPaperTests/桌面電源 含空白/rc05-fixed/DrillPaper.exe" `
  -EvidenceDirectory "$env:USERPROFILE/DrillPaperTests/桌面電源 含空白/rc05-power4" `
  -DesktopPowerRecovery
```

證據目錄不可覆寫；重跑改用尚不存在的新目錄。完整 profiles、原始主題、launcher requests 留本機隔離目錄，不提交瀏覽器 profile／完整 NetLog。版本化結果只保存診斷樣本、hash、建立時間與退出記錄。

第一次擴充觀測 [power1.log](power1.log) 在重新啟用智慧休眠設定後等待握手逾時；當時未保存該階段狀態，不能判定其原因或視為前輪啟動缺陷的重現。此輪正式退出碼 0，未注入故障；補入 timeout／failure 證據保存後的第二輪通過同一階段並在真正無限迴圈取得上述 Red。不能刪除第一次逾時或冒稱所有輪次通過。

第三輪 [power3.log](power3.log) 已完成雙目標無限迴圈回復，但接續啟動 fixture 時舊 helper 身分檢查失敗，整輪不是 PASS，結果與時序見 [power3/failure.json](power3/failure.json)。漏接的 fixture 79976 經 path、精確 CIM 建立時間及 handle 核對後單獨終止，見 [清理](fixture3-identity-cleanup.json)；當時 app 已正常退出。舊檢查失敗的確切原因未定；另確認 DateTime 經字串再 Parse 會丟 UTC，故 helper 改為 DateTimeOffset、UTF-8、持有 handle 後比對 parent／path／CIM 精確建立時間，最多五秒重取 metadata並保留 `.identity.json`，不終止未知程序。不能以原工具錯誤宣稱產品復原失敗或防毒介入。

第四輪完整 **PASS**，見 [power4.log](power4.log)、[結果](power4/result.json)、[時序](power4/phases.json)：

| 範圍 | 實際結果與限制 |
| --- | --- |
| 雙目標混合 DPI／幾何 | 兩個獨立宿主實體矩形與 Windows oracle 相符，DPI 144／96；Minimal／Dashboard、全目標重啟、完整 viewport、來源與世代隔離回歸通過。只測同為 1920×1080 的目前配置，其他解析度與拔插 NOT RUN |
| 原生互動條件 | [修正版觀測](native-fixed-observation.json)：兩宿主均 `WS_EX_NOACTIVATE`／`WS_EX_TOOLWINDOW`、無 APPWINDOW、HTTRANSPARENT=-1、唯一管理 HWND；唯讀觀測前後前景 HWND 相同。這些不代表圖示／工作列／Alt+Tab／實際焦點操作通過。初次 [未設 DPI awareness 的觀測](native-desktop-observation.json) 主屏矩形受虛擬化，不作實體幾何依據；正確實體值另見 [DPI aware 對照](native-desktop-dpi-aware.json) |
| 手動暫停／受控政策 | 設定智慧休眠開啟；所有目標手動暫停且實際 TrySuspend 成功回報，受控 lock／unlock 不取消手動暫停；等待十七秒超過健康期限，load 未重建；繼續後新 metrics 與 JS HealthTick 前進 |
| 真正程序故障與受控電源交錯 | 各一輪 renderer、browser 在受控 locked 時終止；解除受控鎖定後所有目標有新握手與新 JS 回應。注入先固定 browser 實體及 profile，再比對受害程序 path／精確建立時間及持有 handle，沒有單以 PID 終止 |
| 有界 renderer 故障 | 連續八輪：Dashboard 三次重建、回復 Minimal、其三次重建後在第八輪所有目標停止渲染並保留原生管理入口；新選題後能重新啟動 |
| 真正 JS 無限迴圈 | 先驗證兩宿主載入自訂探針，同 load 的第二次訂閱前進才標記 entered；約 **91.66 秒**（包含後續 JS／metrics 新回應確認）兩者均有界回復可信 Minimal。load 由 29／30 最終到新 Minimal；原生推送 tick 單獨不當作成功判準 |
| 父視窗／電源／browser 交錯 | 兩宿主受控 locked＋手動暫停，移入本次 fixture，終止已核對 browser，再銷毀 fixture；解除受控鎖定與暫停後，雙目標重建、新握手、完整矩形及新 JS 回應均通過。沒有重啟真正 Explorer |
| 正式退出與模式 | 全目標、單選、Preview 往返、離線目標暫用與正式退出通過；三次退出合計 **19** 個當下可觀察子程序，以持有的實體 handle 等待且比對精確建立時間，沒有宣稱發現所有歷史／未觀察子程序 |

新 EXE 的單次預設啟動回歸也通過：`pwsh -NoProfile -File scripts/test-default-startup.ps1 -ApplicationPath <rc05-fixed/DrillPaper.exe> -EvidenceDirectory <rc05-default-fixed>`，約 **1.18 秒** ReadyEpoch=1，觀測約三十秒，原生智慧休眠勾選=1，正式退出碼 0、6 個已驗證子程序均退出、未確認身分數 0。見 [日誌](default-fixed.log)、[結果](default-fixed/result.json)。這是修正後 EXE 的相關回歸，不重做或改寫前輪兩次原失敗版本的調查；也不代替 08 的乾淨環境驗收。

審查發現的兩個工具入口錯誤處理已補獨立失敗測試：`node --test tests/desktop-power-tools.test.mjs` Red 2/2 → Green 2/2，見 [tools-red.log](tools-red.log)／[tools-green.log](tools-green.log)。子程序空集合與部分身分未知均不能宣稱清理 PASS；所有宿主斷言要求預期數量，禁止空集合通過。兩軸複查未解決各 0，見 [REVIEW.md](REVIEW.md)。

本票設 **resolved**：完成可自動執行驗證、票內無回應缺陷的 Red→Green 修正與缺口交接。沿用本分支，僅一次 commit 並 push origin；提交紀錄見 STATUS／Git，不合併 main、不公開發行。

## 人工與 RC gate

真正 Explorer／系統匣點擊、桌面圖示／工作列／Alt+Tab／虛擬桌面／焦點、全螢幕／部分覆蓋、拔插及其他 DPI／解析度、真正鎖定／關屏／待機喚醒與其故障交錯一律 NOT RUN。原因及逐項判準見 [人工清單](../MANUAL_CHECKLIST.md)。父視窗 fixture 不是真正 Explorer；原生樣式、JS 回應與資料推送不是人工畫面 PASS。舊版本的特定 Explorer 人工 PASS 保留，不套用新 hash。

08 在乾淨環境以智慧休眠開啟的產品預設驗證啟動，通過後才移除 `--no-smart-sleep` 並重包；本輪即使通過也不解除 03 歷史 FAIL。09 必須承接上述 NOT RUN、第一次逾時與全部 gate，不能以本票結案放行 RC。CI、重包、其他 Windows／Runtime 與完整套件均 NOT RUN，依序留後票。

記憶查證：Nowledge MCP `thread_search`，query=`RC 05 desktop-power-recovery 預設智慧休眠 未重現`，server mode=`full`，scope=`default`，無額外 filters；rank 1 為 `0ff2b82c-7de3-43d6-bdb0-76c3b7c4f1a3`「桌面電源復原票因未能重現智慧休眠啟動缺陷而停止」，relevance_score=65.75369389851888。只取搜尋摘要，未回讀整條 thread；本輪最新 ticket／使用者決策優先。
