# 票 11 已確認的收尾分析需求

本次只分析既有資料，不啟動產品、觀察器、實機測試或修改產品程式。以票 11 最新「決策（使用者確認）」與本次使用者指示為準：長測門檻改為 1800 秒，約 51 分鐘時決定提早收尾；原 REQUEST.md 的 7200 秒要求屬歷史執行計畫，並非本次判定門檻。原檔不修改。

使用所有已落盤 samples，以單調時間首末跨度計算實際時長；不將 521 筆中途摘要冒充最終結果。依 06 原有容差計算 CPU、Private Bytes 首末 300 秒中位數差與 OLS、handles／threads 增量，列缺失、程序組成與每 10 分鐘中位數，對照 06。模式及雙／單目標依 launch／raw 證據說明。

強制 taskkill /T 是收尾操作失誤，不是產品崩潰；不補造 result.json／退出碼，正式退出與正常清理標 NOT RUN。有限觀測不宣稱無洩漏，不重新判定 RC。其餘硬體、Runtime 與真實節能缺口保留。

既有證據不得覆寫；新分析檔、來源 SHA-256 清單及排除 appdata／WebView2 profile 的原始資料 ZIP 使用新名稱。完成 REPORT.md、票 Comments（Status 不變）、STATUS 後，審查、commit-msg 產生訊息、在指定分支只 commit 一次並 push。不合併 main、不建 tag／release。無產品變更，TDD／型別檢查／完整產品測試 NOT RUN，因本次禁止產品實測且範圍只含既有證據收尾。
