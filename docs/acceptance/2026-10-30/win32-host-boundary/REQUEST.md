# 票 14：需求與實作方案

- 已確認規格：`.scratch/rc-delivery/issues/14-win32-host-boundary.md`、同目錄上層 `spec.md` 及使用者本次指示。前置票 13 implemented；起點為乾淨 HEAD `e3c7bda`，分支 `feature/rc-14-win32-host-boundary`。
- 現況成立：`ReconcileSurfaces` 直接查 parent／Shell PID，並寫入 DesktopEpoch、DesktopFailure、TargetDpi；這些責任應位於 platform/windows。
- 純重構：將原判斷搬到 Win32DesktopHost 公開 `IsAttached(HWND)`，成功／失敗診斷各集中於宿主方法。全程序成功世代仍由 app 遞增，成功寫世代及 DPI、移除 failure；失敗僅寫 failure，保留既有屬性及時序。不得加強判斷或更改錯誤政策。
- app 的 HWND 身分檢查另使用同一 Win32 PID API；將原 thread／process 判斷移到宿主 `IsCurrentThreadWindow(HWND)`，app 保留 Surface userdata 比對，確保沒有直接呼叫票內列出的 API，且不改生命週期保護。
- 不變項：附掛重試、幾何變更、隱藏失敗宿主、Preview、命令 ID、訊息、WebView2 與其他邊界。本票不處理裸 WM_APP、腳本 helper 或 09-D2。
- 已確認 seam：Windows 原生宿主整合與既有診斷屬性契約。先跑既有相關基線；新介面補非 Explorer parent／無效 HWND、跨執行緒所有權、診斷失敗保留／成功清除等原生案例。新增介面測試屬純重構保護，不將編譯缺方法或已通過舊行為假報為 Red。
- 驗證：Release 相關 target 編譯、選取宿主 fallback／管理視窗／多螢幕／重試／設定／主題 CLI 的 CTest，然後循序執行隔離產品多螢幕腳本及可行的原生 Shell 案例。完整套件、SDK、CI、封裝留收尾，NOT RUN。
- 安全：測試資料與產品副本位於非 Temp 使用者目錄，EXE 使用 CTest 原生啟動或 Node／cmd；不修改防毒。記錄 Apex One 可讀日誌及每次已觀察攔截，受影響項目 BLOCKED，不把未知失敗推定為防毒。原持續桌布 83428 核對 path／建立時間／hash，不關閉或替換、不重啟 Explorer。
- 人工項目：桌面圖示／焦點／實際畫面、真正 Explorer 重啟、實體拔插／DPI、其他 Windows／Runtime，先完成可自動項目後標 NOT RUN 並交付清單。既有 RC gate 保留。
- 收尾依 implement／code-review 做 Standards 與 Spec 兩軸唯讀代理審查；更新本票與 STATUS，依 commit-msg 產生繁中 Conventional Commit，只 commit 一次並 push 功能分支，不合併 main、不公開發布。衝突或前提不成立即停止、不 commit。
