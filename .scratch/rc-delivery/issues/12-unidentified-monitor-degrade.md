# 螢幕無法辨識時退化套用而非整個停擺

Status: implemented
Type: bug
Blocked by: 無

## Scope

修正整體 code review（b4616ec...e629493）規格面第 1 項：`win::EnumerateMonitors` 遇到任一 active path 取不到 `monitorDevicePath`（或 target／source 名稱）就整批拋錯（`src/platform/windows/monitor_info.cpp:62-64`）。啟動時無條件呼叫（`src/app/main.cpp:666`，含 `--preview`）會導致無法啟動；每秒 tick／顯示變更呼叫（`main.cpp:627`）拋錯後 `ReconcileSurfaces` 不執行，其他螢幕的恢復也停擺。

## Acceptance

- 列舉時單一螢幕無法辨識不再使整批失敗：可辨識的螢幕照常回傳；無法辨識的螢幕仍回傳其桌面矩形／DPI，並明確標示為「無法辨識」（不給可保存的穩定 ID）。
- 只要偵測到任一無法辨識的螢幕，桌布模式跳過目標判斷，改為每個連接中的螢幕（含無法辨識者）各自顯示一份完整的同一主題；clone 仍為每區域一個宿主，逐屏 DPI 照舊。管理介面明確提示「有螢幕無法辨識，暫時套用到所有螢幕」，不寫回保存的目標；所有螢幕恢復可辨識後自動回到保存的目標政策。
- 無法辨識的螢幕在清單標示「無法辨識」且不可勾選；保存時不寫入無法辨識螢幕的任何暫時 ID。
- Preview 模式啟動與運作不依賴螢幕列舉成功。
- 列舉本身暫時失敗（例如 QueryDisplayConfig 失敗）時保留上一次成功結果並寫詳細日誌，不讓 tick／訊息處理中斷；首次啟動就失敗時以主螢幕退化顯示並提示，不 crash。
- 公開 seam（`runtime/monitor_targets` 目標解析）先寫失敗行為測試再最小修正；原生列舉以可注入／fixture 方式驗證無法辨識路徑，不能只靠單元測試宣稱桌面畫面 PASS。實機真正無法辨識的顯示器若無法取得，標 NOT RUN 並附人工清單。
- 既有決策（首次預設主螢幕、全斷線暫顯主螢幕、部分斷線、clone、空選擇不可保存）的相關測試維持通過。

## Comments

- 2026-10-30 完成：runtime 空 ID 觸發全區域暫時退化及 clone 去重，恢復後回保存政策；原生 target／source 查詢錯誤與空路徑／名稱保留矩形及 DPI，管理清單禁止勾選且 Preferences 排除空 ID。平台 MonitorInventory 保留成功快取，首次失敗用原生主屏退化；app 記詳細錯誤仍執行 reconcile／健康檢查，獨立 Preview 不列舉。首次／舊設定待主屏可辨識才於記憶體解析，未自動保存退化目標。
- 驗證：runtime、原生識別、快取及管理空 ID 各有 Red→Green；最終相關 CTest **17/17 PASS**。隔離測試入口三情境（未辨識→整體失敗快取→恢復、首次列舉失敗→恢復、Preview 故障列舉器 0 呼叫）均 exit0；正式產品多螢幕回歸 PASS。建置與 PS parser／證據拒覆寫 PASS。完整套件依使用者指示 NOT RUN，留收尾；API fixture／HWND 證據不當人工畫面 PASS。
- 證據／限制：`docs/acceptance/2026-10-30/unidentified-monitor/REPORT.md`、`REVIEW.md`、`MANUAL_CHECKLIST.md` 保存來源／hash、命令、原始工具失敗及結果；Standards 初審路徑寫入問題與情境白名單建議已修正，複查 Standards 0／Spec 0。真正無法辨識硬體、拔插／clone／其他 DPI、真實 OS 列舉故障及人工畫面 NOT RUN，已附清單。票 13～15 的其餘範圍維持各票處理，既有空選擇不能保存仍通過。
- 安全／交付：所有產品實測循序，非 Temp 使用者目錄、Node 直接啟動；可讀 Apex One 日誌前後 hash／時間不變，沒有觀察本票新增攔截，非完整觀測，無已證實防毒 BLOCKED。原持續桌布 83428 path／UTC ticks／hash 不變，收尾唯一 app、無 RC12 profile WebView2 殘留；未重啟 Explorer、未關閉／替換原桌布。更新 STATUS 後依 commit-msg 技能產生繁中訊息，本票一次 commit 並 push `feature/rc-12-unidentified-monitor-degrade`；不合併 main、不公開發布、不解除 RC gate。

- 2026-10-30 開始：從 HEAD `054c9017156098c36c33832c7740086e02aede97` 建立 `feature/rc-12-unidentified-monitor-degrade`。已讀 handoff／STATUS／架構／spec；原始缺陷前提成立。需求與注入邊界記於 `docs/acceptance/2026-10-30/unidentified-monitor/REQUEST.md`；只跑相關測試，完整套件留收尾。

- 2026-10-30 決策（使用者確認）：螢幕無法辨識時跳過目標判斷，把桌布套用到整個螢幕——即每個連接中的螢幕整個畫面都顯示桌布（各自一份完整主題，非跨屏拼接），而不是整個停擺；屬暫時退化，不寫回設定，恢復可辨識後回到保存的目標。
- 2026-10-30 決策（使用者確認）：本票與 13～15 交由 Codex CLI 依序實作（12 → 13 → 14 → 15），每票完成即 commit＋push。依 spec 防毒決策測試放非 Temp 使用者目錄、不經 PowerShell 啟動 EXE；不重啟 Explorer、不關閉／替換原持續桌布；不合併 main。
