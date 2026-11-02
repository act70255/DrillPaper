# 固定 800×600 設定視窗

Status: implemented
Type: task
原討論編號：2
Blocked by: 01

## Scope

將原生管理／設定視窗整合為固定 800×600 用戶區邏輯尺寸（100% 縮放基準），容納 01 的螢幕選擇及既有主題、模式、智慧休眠、網路、保存／取消／日誌操作。標題列與邊框另計；不增加自由調整大小或使用者縮放設定。

## Acceptance

- 100% 時實測 client area 為 800×600；最大化／拖曳邊框不改變固定版面。Windows DPI 正常換算，不能將固定尺寸解讀成忽略 DPI。
- 目前環境及可用的 100%／150% 基本縮放下，文字、清單與主要操作可見可達；多目標清單超出版面時可捲動，較小工作區的可達方式有文件。未能執行的環境明列 NOT RUN。
- Tab／Shift+Tab 順序、可見焦點、空白鍵、取消草稿、保存、匯入／移除確認及重複系統匣唯一視窗有實機結果。
- 01 的目標選擇在套用／取消／重開／重啟流程一致；關閉管理視窗仍只隱藏，正式退出語意不變。
- 保存／網路／主題政策不因 UI 排版改動放寬；錯誤與較長繁體中文訊息可讀。
- 提供尺寸與畫面證據；本票不要求任意視窗大小矩陣，桌布的多螢幕尺寸與混合 DPI 驗收仍屬 01／05。

## Comments

- 2026-10-29 結案：固定 800×600 邏輯用戶區，跨 DPI 重算含邊框尺寸，禁止最大化與任意改尺寸；主題／目標兩欄、長狀態與完整螢幕識別可捲動、無名稱路徑縮短、Tab／Shift+Tab 與可見焦點。取消／保存／關閉隱藏／退出及既有政策邊界保留。需求與人工清單見 `docs/FIXED_SETTINGS_WINDOW.md`。
- 2026-10-29 驗證：相關 CTest 13/13、原生管理 5 cases／776 assertions、管理生命週期、多螢幕目標保存重啟與安全政策回歸 PASS。100% 實測用戶區 800×600、150% 1200×900；fixture WM_PRINT 與實際 app 150% PNG 已檢視。最終 EXE SHA-256 `68CC8BDFDA3593046777D412298D6E1B7F5B92A77F6B93B161E74396F763CBD0`，本輪 Runtime 156.0.4314.50；命令／失敗與通過證據見 `docs/acceptance/2026-10-29/fixed-settings/REPORT.md`。Standards／Spec 審查與複查未解決項均 0。
- 2026-10-29 NOT RUN：真實鍵盤／系統匣點擊／匯入移除確認、小工作區實機及其他 DPI／Windows（原生操作管道 os error 2，人工項附清單留後續）；不以受控訊息／列印畫面冒稱人工 PASS。完整套件、CI、打包留後續及 09；原持續桌布未關閉／替換，未重啟 Explorer，RC gate 保留。implemented 僅代表本票程式及可自動驗證範圍完成。
- 2026-10-29 提交：依 commit-msg skill 檢視實際差異產生繁中 Conventional Commit，本票只 commit 一次並 push `origin/feature/rc-02-fixed-settings-window`；不合併 main。

- 2026-10-29 開始：從目前 HEAD `0c97d4f` 建立 `feature/rc-02-fixed-settings-window`，前置 01 implemented，工作樹乾淨；未發現決策衝突。實作前需求、排版方向、既有 Windows 原生整合 seam 與人工清單記於 `docs/FIXED_SETTINGS_WINDOW.md`。本票只跑相關測試，結束時一次 commit＋push，完整套件留 09。

- 2026-10-29：依使用者固定 800×600 的方向建立。現有固定視窗不等於本尺寸已實作；產品／GUI 驗收 NOT RUN。
