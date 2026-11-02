# RC 10 需求與執行方案

- 依已確認票「雙目標受控鎖定往返後解除手動暫停未恢復推送」實作；base 為 `a3c183f5abe9d10f5184ad95aca8bb63bab0ed6f`，分支 `feature/rc-10-controlled-resume-regression`。
- 先核對 RC 09 trial.7 ZIP／EXE hash，以原 `test-multi-monitor.ps1 -DesktopPowerRecovery` 命令及獨立證據目錄執行；再建置目前 HEAD 的 Release，以隔離副本執行同命令，兩輪循序且分開保存。
- 保留原 35 秒指標斷言、17 秒暫停觀察及歷史 FAIL；取得可重現失敗後才最小化、診斷與修正。同步觀測不足不推定產品、OS 或防毒根因。
- 若根因涉及未確認的手動暫停／鎖定／恢復優先權，或前提不成立，停止、不 commit／push，回報具體衝突與選項。
- 若可修正，先在已確認 runtime／管理命令 seam 補失敗行為測試，再最小實作；只跑相關測試。產品變更另包新版本並重驗產品預設啟動／保存 Preview／退出及受影響範圍。
- 測試 EXE、隔離資料與 TEMP／TMP 位於非 Temp 使用者目錄；透過既有 Node launcher 啟動產品，記錄可讀 Apex One 日誌前後指紋及每次攔截，已證實受影響項標 BLOCKED。
- 不操作 Explorer、不關閉或替換原桌布 PID 83428；每輪核對身分與測試殘留。人工畫面／真正 OS 事件標 NOT RUN 並附清單，不由受控通知或單元結果推論。
- 完成時執行 implement 所要求的 code-review、更新票與 STATUS、以 commit-msg 產生訊息，只 commit 一次並 push 本票分支；不合併 main、不公開發布，未完成 gate 仍拒絕 RC。
