# 桌面互動與電源復原

Status: resolved
Type: task
原討論編號：4
Blocked by: 04

## Scope

在多螢幕版本補 A03／A04／A08 的剩餘桌面、電源與故障交錯驗收，包含無回應 renderer；不將舊單螢幕 Explorer 人工 PASS 誤寫為未通過或已涵蓋新配置。

## Acceptance

- 先記錄螢幕／DPI／Windows 組態與有效智慧休眠政策；桌面圖示、工作列、Alt+Tab、焦點及虛擬桌面逐項檢查，桌布不搶焦點或留下多餘可切換視窗。
- 補多目標的混合 DPI／解析度與拔插；管理視窗固定大小不免除桌布幾何驗收，Windows／Runtime 未測配置明列 NOT RUN。
- 真正鎖定／解鎖、顯示器關閉、待機／喚醒、全螢幕與多螢幕部分覆蓋按既定政策驗證；受控訊息／暫停迴圈不得代替真正 OS 事件。
- 新版真正 Explorer 重啟後，各目標畫面與更新恢復、圖示／工作列可用，另以真正系統匣點擊確認管理入口與唯一視窗；人工結果與原生註冊證據分開。
- 無限迴圈／無回應、renderer／browser 故障與電源／Explorer 交錯，有界復原或友善退化；不能只以舊 metrics 標題宣稱畫面存活。
- 暫停／繼續與正式退出涵蓋所有宿主，觀測子程序建立時間／handle 避免 PID 重用誤殺；不關閉或替換原持續桌布。
- 修正先做可重現回歸，留下環境、時序、程序／畫面及退出證據；不可執行的真實事件附原因並傳遞至 RC gate。

## Comments

- 2026-10-30 接續完成：沿用 `feature/rc-05-desktop-power-recovery` 與 HEAD `2a69ed1` 的未提交調查／啟動工具／證據，依最新使用者決策不再追啟動 Red、不做推測性啟動修正；原失敗改記「未重現，疑似環境」，03 歷史 FAIL 保留，08 須在乾淨環境用產品預設握手通過後才移除 `--no-smart-sleep`。本票 resolved 表示可執行驗證與報告完成，不代表 RC 通過。
- 2026-10-30 票內缺陷 Red→Green：原 HEAD 的雙目標真正 JS 無限迴圈 180 秒沒有有界回復，MetricsTick 仍前進，不能當頁面存活。web adapter 新增 UI 計時器驅動、至多一個 pending 的五秒 JS 探針；啟用中十五秒不回應沿既有三次重建／Minimal／停止路徑，暫停時間不計入；HealthTick 僅在 JS 回呼成功更新，舊 controller lifetime／世代隔離沿用。新 EXE `25316B…6D26D` 全輪整合通過，兩宿主約 91.66 秒有界回復且有新 JS 回應；十七秒暫停不誤判、renderer／browser 與受控電源、八輪有界退化、browser＋受控鎖定／手動暫停＋父視窗 fixture 銷毀、雙屏幾何／viewport／正式退出皆有證據。三次退出共 19 個當下可觀察子程序通過；不以舊標題或推送 tick 宣稱像素存活。
- 2026-10-30 驗證與限制：相關建置 PASS、CTest 18/18、工具 CLI 契約 Red 2/2→Green 2/2、PS parser 3/3／JS syntax PASS；修正後 EXE 單次全新預設啟動約 1.18 秒握手、智慧休眠勾選=1、正式退出 0、6 個已驗證子程序退出。第一次設定套用後等待逾時與第三輪 fixture 身分工具失敗均保留，不算全輪 PASS；fixture 經精確身分核對清理，shared helper 補 UTF-8／UTC／parent／CIM 精確時間／有界 metadata 等待。完整時序、hash、父子建立／退出與兩軸審查（未解決各 0）見 `docs/acceptance/2026-10-30/desktop-power-recovery/resume/REPORT.md`。Apex One 可讀日誌 hash／時間未變，未觀察新增攔截；非完整防毒觀測，不修改防毒。未關閉／替換原持續桌布、未重啟 Explorer。
- 2026-10-30 傳遞：真正 Explorer／系統匣點擊、桌面圖示／工作列／Alt+Tab／焦點／虛擬桌面、全螢幕／部分覆蓋、拔插、其他解析度／DPI／Windows／Runtime、真正鎖定／關屏／待機與故障交錯均 NOT RUN，原因與逐項操作清單見 `MANUAL_CHECKLIST.md`。舊單螢幕／62f01ab 特定 Explorer 人工 PASS 保留，不外推到新配置。06 應量測新增健康探針的效能／省電成本；08 重包含本票與 04 修正並補乾淨環境，09 承接 NOT RUN、首次逾時、03 歷史 FAIL 及完整回歸。只跑本票相關測試，完整套件留 09；本票一次 commit 並 push 原分支，不合併 main。

- 2026-10-30 停止／待補重現條件：原失敗產品 EXE `B0FF9A…71781`（trial.3／trial.4 相同）在非 Temp 使用者繁中／空白路徑、Node 直接啟動 `--management --preview`、兩輪全新 LOCALAPPDATA 下，約 2.49／2.55 秒 ReadyEpoch=1，觀測至約 30 秒；第二輪原生智慧休眠勾選=1，兩輪正式退出碼 0 且已觀察子程序均退出。Apex One 可讀行為日誌 hash／時間未變，未觀察新增攔截，但不能排除歷史防毒干擾或判定根因。HEAD 另一次觀測約 1.74 秒握手，早期工具身分／清理錯誤不算產品 Red。尚未建立要求的可重現失敗回歸，依使用者停止規則停止於診斷前；無產品修正、不關閉預設智慧休眠、不 commit／push，維持 in-progress。測試草稿與證據見 `docs/acceptance/2026-10-30/desktop-power-recovery/REPORT.md`。後續桌面／電源／故障及人工矩陣 NOT RUN，未操作原持續桌布；原 03 FAIL 不解除，08 不據此移除繞行，09 gate 保留。需補原失敗前景／全螢幕、電源／工作階段、載入時間線及防毒等條件，或確認環境／時序調查方向後接續。只跑相關原生螢幕列舉 1/1，完整套件留 09。

- 2026-10-30 執行規劃：從 HEAD `2a69ed18a649770359c03b76b1503cfd51262a0c` 建立 `feature/rc-05-desktop-power-recovery`。先以非 Temp 使用者繁中／空白路徑的隔離副本、Node 直接啟動及全新 LOCALAPPDATA，保留 `--management --preview` 預設智慧休眠在 30 秒內握手的失敗回歸；Apex One 介入列為變數，受攔截項目 BLOCKED。取得可重現 Red 後才診斷／最小修正並驗證；預設維持開啟。其後補可自動執行的多宿主政策／故障／退出與幾何，真正 Explorer／鎖定／待機／拔插及人工畫面依已確認決策列 NOT RUN 與操作清單。只跑相關測試，完整套件留 09；完成時本票僅 commit 一次並 push，不合併 main。若前提不成立或決策衝突則停止且不提交。

- 2026-10-30 03 傳遞：7A 試用入口暫帶 `--no-smart-sleep` 並沿用保存模式，未改產品程式；「預設智慧休眠啟動」仍為 **FAIL**，不因試用入口通過而解除。根因未定，本票承接原失敗回歸；修正後通知 08 移除入口繞行、回到產品預設重新打包／重驗，09 持續追蹤。證據保留於 `docs/acceptance/2026-10-29/trial-package/REPORT.md`。
- 2026-10-29：舊 a241856 與新版 62f01ab 的特定 Explorer PASS 保留，本票針對新多螢幕與未覆蓋情境；新版本測試 NOT RUN。
- 2026-10-30 決策（使用者確認）：本票承接 03 發現的啟動缺陷——預設智慧休眠開啟時，`DrillPaper.exe --management --preview` 以全新隔離 LOCALAPPDATA 啟動 30 秒後 ReadyEpoch=0（未握手）；取消智慧休眠並套用後可握手，根因未定。證據見 docs/acceptance/2026-10-29/trial-package/REPORT.md 與 default-startup-failure.log。本票須先留下可重現的失敗回歸，再診斷根因並最小修正，智慧休眠產品預設維持開啟；修正後通知 08 讓試用／交付入口回到預設行為。
- 2026-10-30 決策（使用者確認）：「預設智慧休眠啟動未握手」不再重現；改記為「未重現，疑似環境（Apex One 對 %TEMP% 經 PowerShell 啟動的未簽章 EXE 介入）」，不製造 Red、不做推測性修正，本票不再以此缺陷阻擋。03 歷史 FAIL 證據保留。試用入口的 `--no-smart-sleep` 繞行留到 08：在乾淨環境以產品預設（智慧休眠開啟）驗證啟動握手通過後才移除；若 08 再次失敗，屆時重新開缺陷並依 TDD 修正。本票接續完成其餘 Scope／Acceptance（桌面互動、多目標 DPI／幾何、電源、Explorer 交錯、無回應 renderer 等），沿用已建立的 test-default-startup.ps1 作為預設啟動回歸觀測。
