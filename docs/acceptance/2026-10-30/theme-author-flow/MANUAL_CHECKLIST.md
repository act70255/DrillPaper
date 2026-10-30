# RC 07 人工驗收清單（NOT RUN）

本輪已完成可自動執行部分。下列項目依 spec 2026-10-29／30 決策保留，不中斷本票，不解除 A10／A12／RC gate。不得重啟 Explorer 或關閉／替換原持續桌布。

1. **GUI 匯入與確認畫面**：用隔離副本與測試資料（不可使用日常 LOCALAPPDATA），在原生管理視窗按匯入，選 `author-final.dmt`，目視檔案選擇器、成功提示與主題列。以鍵盤取消再重開，確認取消不改清單。再次匯入同版本，目視友善拒絕提示及詳細日誌。自動流程已驗正式 CLI／同版本拒絕，未冒充這些畫面操作。
2. **實際版面**：Preview 縮放至 320px、一般視窗及最大化；於每個選取目標目視 CPU／RAM／GPU unavailable／速率／單位／時間更新，不重疊、不裁切。比對 100%／150% 及不同解析度。自動探針僅驗 DOM、主內容寬度、viewport 與 DPR，不能證明每個字皆可讀或像素完整。
3. **切換、移除與重新匯入畫面**：作者主題→Minimal→作者主題；從管理視窗移除目前作者版本，先取消再確定。確認取消無變更、確定後回復 Minimal，內建主題不能移除；重新匯入同一份 `author-final.dmt` 後可再次預覽與套用。公開 ThemeManager 移除／同版重裝測試已執行，未代替原生確認對話框。
4. **錯誤畫面**：以 API v2、含 `.ts`／`.d.ts` 的非法包驗原生提示、清單不增加、原主題仍運作。自動原生／工具封裝負面案例及瀏覽器 API v2 錯誤已通過，人工文字呈現仍未驗。
5. **隔離的瀏覽器 MockHost 開發預覽**：在作者開發環境使用 MockHost／SDK，透過本機靜態伺服器供開發瀏覽器載入（勿用 file URL）。本範本預設為正式 host 用途；如要瀏覽器預覽，需自行在開發入口建立 MockHost，勿把伺服器或 Node 加入 app runtime。Node MockHost 契約與 TypeScript compiler 已驗，獨立瀏覽器的畫面 NOT RUN。
6. **其他環境與真正 OS 事件**：乾淨一般使用者／無來源樹與無 Node 的電腦、其他 Windows／Runtime、NVIDIA、真實拔插／鎖定／睡眠／DPI 切換由 08／09 續驗。此次作者無來源樹建置與隔離 app 載入不代表乾淨 OS 交付。完整網路、背景流量、DNS／WebRTC／沙箱邊界沿用 04 未驗清單，不以單一 HTTP 開關宣稱完全封鎖外傳。

測試資料在 `%USERPROFILE%\DrillPaperTests\RC07 作者流程`。SDK ZIP／DMT 的完整 SHA-256 見 `hashes.json`；sample 原包與最終獨立作者重建包 hash 相同。人工執行前自行核對原持續桌布的 path／精確建立時間／hash，只操作新隔離實例。

若 Apex One 或其他防毒攔截，記錄產品／版本、規則、時間、檔案 hash 與影響步驟，該項標 BLOCKED；不要修改防毒設定或把攔截當產品 FAIL。所有 app 測試解壓至非 Temp 使用者目錄，以直接執行／cmd／Node 啟動 EXE，避免 PowerShell 包裝 EXE。
