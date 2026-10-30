# 桌布附掛判斷與診斷屬性移回 Win32 宿主邊界

Status: open
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

- 2026-10-30 決策（使用者確認）：依整體 code review 開單，交由 Codex 於 13 之後處理；每票完成即 commit＋push，不合併 main。
