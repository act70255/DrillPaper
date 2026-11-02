# RC 12 需求與實作方案

已確認票：`.scratch/rc-delivery/issues/12-unidentified-monitor-degrade.md`。
基準 HEAD：`054c9017156098c36c33832c7740086e02aede97`；分支：`feature/rc-12-unidentified-monitor-degrade`。

- runtime 公開目標解析：任一連接目標無法辨識，即忽略保存選擇、每區域一份完整主題；clone 去重，恢復辨識後回原政策。無法辨識使用明確旗標及空 ID，禁止保存暫時 ID。
- Windows 列舉：注入原生 API 的 fixture 覆蓋 target/source 名稱讀取失敗、空裝置路徑。以原生桌面區域保留矩形及 DPI；source 名稱失敗可由 source mode 幾何對應，仍無法對應時保守保留未辨識區域，不猜穩定 ID。
- 平台螢幕快取：暫時整體失敗保留最後成功結果、詳細記錄；首次失敗只以原生主螢幕矩形／DPI退化，不寫設定。公開快取入口用注入列舉／主螢幕讀取驗證。
- app：列舉錯誤在更新邊界內處理，使 reconcile／renderer tick 繼續。獨立 Preview 不呼叫列舉；管理介面可嘗試更新清單但不影響 Preview 運作。首次目標只在辨識到主螢幕時於記憶體解析。
- 管理清單：無法辨識項目明確顯示、禁止滑鼠／鍵盤／原生狀態訊息勾選；Preferences 排除空 ID。狀態顯示退化原因，恢復後移除提示。

依票內已確認 seam 逐步 Red→Green，不另新增未確認產品需求。本票只執行目標解析、設定、列舉、管理及多螢幕相關驗證，完整套件留收尾。Windows 程序與畫面證據分開；實體無法辨識顯示器、拔插／clone／人眼結果若無條件即 NOT RUN，附人工清單。

測試資料放非 Temp 使用者目錄，EXE 由 Node／CMD／CTest 直接啟動，產品測試循序執行。防毒攔截記規則／時間／影響項並標 BLOCKED，不改防毒。原桌布 PID 83428 只讀核對身分，不關閉／替換，不重啟 Explorer。不合併 main、不發布；完成後一次 commit＋push。
