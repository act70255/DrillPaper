# RC 09 執行需求與方案

- 已確認依據：票 09 最新「決策（使用者確認）」及本輪使用者指示；分支沿用 `feature/rc-09-regression`，base `d60816aff6e99ad1a3624075a74016909f76fa4d`。既有票內決策修改保留。
- 測試修正：保留主題 CLI 六項斷言及 15 秒期限，以 JSON 傳參給 Node，由 Node 直接啟動 EXE。完整 PowerShell 測試鏈與獨立 CTest 均將 TEMP／TMP 指向非 Temp 使用者繁中空白目錄，讓封裝及原生檔案 fixture 使用相同安全位置；不改產品行為或降低驗收門檻。
- TDD seam：票內已確認的 CLI／ThemeManager 公開行為，以及新啟動器的參數、環境、輸出、退出與逾時契約。先留失敗測試，再最小實作；舊斷言逐項核對並實際執行。
- 收尾：最終來源 Release configure／build、完整 scripts/test.ps1、獨立 CTest 清單與數量、SDK 型別及封裝檢查；產品測試循序執行。候選 ZIP 固定 trial.6，產品來源與工具來源分記，若無產品修改不重包或冒稱 ZIP 源於本票。
- 實機：先核對 PID 83428 路徑／建立時間／hash；候選解壓到非 Temp 使用者目錄、全新 LOCALAPPDATA、Node／CMD 直接啟動。驗現有入口與產品預設多輪，08-D1 保持 15 秒期限；必要時保留失敗並建追蹤。只有既定移除前提全通過才處理繞行，否則保留。
- 證據與判定：逐票 01～08、A01～A16、CI、已知限制及必要 gate 列版本／環境／命令／結果／owner／下一步。人工、真實 OS／NVIDIA／乾淨機器標 NOT RUN 並附清單；有防毒證據的受影響項 BLOCKED，不改防毒。必要 gate 未過即拒絕放行，此為有效完成。
- CI 僅查現有執行或 feature workflow；不合併 main、不建立 release／tag、不公開發布。完成後兩軸 code-review、更新票及 STATUS、commit-msg 產生繁中訊息，一次 commit 並 push 本分支。決策衝突或前提不成立即停止、不 commit。
