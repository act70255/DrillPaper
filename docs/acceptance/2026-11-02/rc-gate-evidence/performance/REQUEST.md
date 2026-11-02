# 票 11／09-G4 執行需求

本文件記錄已由使用者確認的票 11 最新決策及本次執行方法，不新增產品需求。只做效能；票 Status 不變，不執行其他 gate、不重新判定 RC、不改產品。沿用 feature/rc-11-gate-evidence，一次 commit／push。前提衝突或產品缺陷立即停止，不 commit。

- 候選：trial.8，來源 ae1c5e05e5562cd0297bcf22abf2e06b3749836f；ZIP SHA-256 63A98B5B20F23F9470C2EFEA2DDBC0311ED2EE03EDFFC95AA0021221D73ACD53。先用 verify-trial-archive.ps1 核對來源、白名單及逐檔 hash，再解壓至非 Temp 使用者繁中空白目錄。EXE 只由既有 Node launcher 直接啟動，各情境全新隔離 LOCALAPPDATA，TEMP／TMP 導向該測試根目錄的 scratch。
- 先切換、後 soak，循序執行。原持續桌布已不存在，不啟動其他桌布、不重啟 Explorer。正式管理退出及已核實 path／建立時間／handle 的子程序等待是唯一清理範圍。
- 切換：使用與 test-theme-switch.ps1 相同的原生 10001／10002 命令；沿用 06 的 PerformanceProbe 管理設定與程序身分 seam。原腳本只有單 Preview 且經 PowerShell／Temp 啟動，因此新目錄的一次性測試腳本改為雙桌布宿主、Node 直接啟動。Minimal 起始，100 次交替選 Dashboard／Minimal，最後為 Minimal。每次命令前後保存包含 WebView2 全可追溯程序樹的 Private Bytes／handles／threads、身分與缺失資料；保存命令到兩宿主新 load=ready、正確主題、可見且 MetricsTick 再次前進的時間，並要求新世代 HealthTick。沿用舊切換等待上限 20 秒，失敗即記錄並停止，不隱藏重試。
- soak：原封不動執行 scripts/test-metrics-performance.ps1 -Scenario MinimalMulti -DurationSeconds 7200，60 秒暖機，單一連續實例；原始 JSONL 首末單調時間跨度至少 7200 秒才算完成。既有分析工具計算時間加權 CPU 平均、nearest-rank p95、完整資源樣本的首末 300 秒中位數差及 OLS 斜率，明列被排除資源樣本與 CPU 區間。
- 兩情境均使用 --no-smart-sleep，隔離已知前景覆蓋政策；不喚醒、不防睡、不改 OS 電源設定。既有只讀 OS observer 同步記錄鎖定／console display state，報告列實際狀態及任何異常區間。這不是產品預設智慧休眠或功率驗收。
- 沿用 06 門檻：Active CPU 平均 <=1%、p95 <=3%；Private Bytes 末／首 300 秒中位數差 <=32 MiB、OLS <=1 MiB/min；handles／threads 中位數增量各 <=10。Active 每宿主推送觀察 0.7～1.2 Hz、JS 回應 0.12～0.25 Hz。切換資源只報原始前後與趨勢，不為非穩態切換自行發明門檻；上述長測門檻套用 7200 秒 soak，不放寬。有限觀測不宣稱無洩漏。
- Apex One AEGIS_BM.log 保存前、情境間及後指紋，發生變化即保存新增內容並逐次核對規則／時間／影響；證實受攔截項標 BLOCKED，不改防毒。
- 結束寫 REPORT.md、票 Comments 一條、docs/STATUS.md；保留所有原始與失敗證據，不覆寫既有檔案。純驗證未改產品，不虛構 TDD Red；完整套件／其他 gate 不在此輪範圍。
