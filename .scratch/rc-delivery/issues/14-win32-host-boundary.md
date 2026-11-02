# 桌布附掛判斷與診斷屬性移回 Win32 宿主邊界

Status: implemented
Type: refactor
Blocked by: 13

## Scope

修正整體 code review 標準面第 1 項。`AGENTS.md`：「Keep collection, runtime policy, Win32 hosting, WebView2, and theme loading behind the boundaries in `docs/ARCHITECTURE.md`」；`docs/ARCHITECTURE.md`：platform/windows 管理桌面 Shell 視窗。目前 `src/app/main.cpp:441-455` 由 app 直接用 `GetParent`／`GetShellWindow`／`GetWindowThreadProcessId` 判斷是否仍附掛 Explorer，並直接寫入 `DrillPaper.DesktopEpoch`／`DesktopFailure`／`TargetDpi` 等診斷視窗屬性。

## Acceptance

- 附掛狀態判斷移到 platform/windows 的桌面宿主（例如 `Win32DesktopHost::IsAttached()` 或等價介面），診斷屬性寫入集中在宿主或單一診斷 helper；app 只透過介面使用，不直接呼叫上述 Win32 API。
- 純重構：行為不變。既有診斷屬性名稱與語意保持相容（現有原生整合測試與腳本依賴它們），不改命令 ID 或訊息語意。
- 以既有相關測試（多螢幕、管理視窗、桌面 fallback、主題 CLI 等原生 CTest）證明行為不變；新增介面若可測則補對應測試。不虛構 Red。
- 只處理本項邊界；review 中其他判斷題（裸 `WM_APP` 數字、腳本重複 helper 等）不在本票範圍，可記在 Comments 供後續。

## Comments

- 2026-10-30 完成：原附掛 parent／Shell PID 判斷與 thread／process 所有權檢查移入 Win32DesktopHost，app 保留 Surface userdata 身分、成功世代及重試政策。桌布成功／失敗診斷寫入集中宿主，DesktopEpoch／DesktopFailure／TargetDpi 名稱、值、寫入時序不變；未改命令或訊息，也未擴張裸 WM_APP／腳本 helper／09-D2。
- 驗證：重構前相關 CTest 23/23 PASS；Release 相關 targets 建置 PASS，重構後相關 CTest 26/26 PASS（4.09秒）。三個新原生案例與 live Shell 新斷言保護所有權／附掛／診斷契約，純重構未虛構 Red。非 Temp 使用者副本經 Node 直接啟動 live Shell 1案例／17斷言及產品多螢幕矩陣 PASS；雙區域 DPI144／96、保存重啟、世代隔離、父 fixture 崩潰復原、模式與全離線退化通過，三次 GUI exit0、19個已觀察 WebView2 退出。首次 cmd 工具呼叫 exit1 無案例結果，改既有 Node 啟動器後取得獨立 PASS，不推定產品／防毒根因。
- 證據：`docs/acceptance/2026-10-30/win32-host-boundary/REPORT.md`、REQUEST／REVIEW／MANUAL_CHECKLIST 及原始 JSON／log ZIP；最終產品 SHA `8E8953FA98842F37965C4FC0C8F3C3FD93E22FD7E1A161B8D9AED3180CE6214A`。Standards 0／Spec 0，無決策衝突。完整套件／SDK／CI／封裝依指示 NOT RUN，人工畫面、真正 Explorer／拔插／電源及其他環境 NOT RUN 並附清單；既有 RC gate 保留。
- 安全／交付：產品實測循序，非 Temp 使用者繁中空白目錄、Node 直接啟動；Apex One 可讀 BM 日誌前後 hash／時間不變，未觀察新增攔截不等於完整觀測，無已證實防毒 BLOCKED。原桌布83428 path／UTC ticks／hash不變，收尾唯一app、無本票profile殘留；不重啟Explorer、不關閉／替換原桌布。更新STATUS後依commit-msg生成繁中Conventional Commit，本票只commit一次並push `feature/rc-14-win32-host-boundary`，不合併main、不公開發布。

- 2026-10-30 開始：票 13 已 implemented；從乾淨 HEAD `e3c7bda` 建立 `feature/rc-14-win32-host-boundary`。目前程式與票內前提一致，需求及純重構方案記於 `docs/acceptance/2026-10-30/win32-host-boundary/REQUEST.md`。使用既有原生整合 seam，只跑相關測試，不虛構 Red。

- 2026-10-30 決策（使用者確認）：依整體 code review 開單，交由 Codex 於 13 之後處理；每票完成即 commit＋push，不合併 main。
