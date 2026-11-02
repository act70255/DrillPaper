# 網路與安全剩餘矩陣

Status: resolved
Type: task
原討論編號：3
Blocked by: 03

## Scope

依 [最新安全證據](../../../docs/acceptance/2026-10-29/management/REMAINING.md) 與 ADR 0001～0004 補未驗邊界，尤其 01 的多宿主／載入世代隔離。既有 allowNetwork 已接 host，不重做成只有欄位的開關，也不宣稱完整沙箱。

## Acceptance

- 先建立有界矩陣，列出可聲明支援的 Windows／WebView2 Runtime、HTTP／HTTPS 開關 off→on→off、管理／獨立重啟及多目標；逐項結果對應實際版本。
- 補 DNS／TLS preconnect／推測連線及瀏覽器背景流量觀測；TURN-UDP／TLS、其他網路介面／proxy 若無環境則 NOT RUN，清楚區分主題與瀏覽器自身流量。
- 補設備／權限實際呼叫、URI scheme／外部 handler、框架／彈窗／下載及拒絕導覽後存活或可信回復；權限狀態 denied 不代替實際 API 行為。
- 快速切換、停用目標、退出或重建後，舊頁面／controller 訊息不能更新新世代或執行管理命令；來源、cookie／儲存與多目標隔離按原政策驗證。
- 拒絕案例有接收端或可觀察副作用及正向控制，不只看 JS 例外或標題。若 Runtime 不執行必要宿主政策，判定失敗並修正或明列不支援，不能照常宣稱封鎖。
- 重現的票內缺陷先留下失敗測試，再最小修正並跑相關回歸；沒有實測的瀏覽器／OS escape 邊界維持 NOT RUN，不以套件驗證等同沙箱。
- 結果記錄是否影響 03 試用限制、08 包內容與 09 gate；安全 FAIL／NOT RUN 不因本票報告完成自動解除。

## Comments

- 2026-10-30 收尾審查：依 implement 的 code-review 技能分別做 Standards／Spec 審查，兩軸各發現 1 項工具問題（入口原始堆疊／缺少某輪 NetLog 仍可能 PASS），均補 Red→Green 修正，工具契約測試 3/3，原／新完整 NetLog 重播仍 Red／Green且新三份預期日誌齊全。兩軸複查未解決各 0，見 resume/REVIEW.md；本票依 commit-msg 技能產生 `fix(web): 關閉 SmartScreen 信譽檢查並補安全矩陣`，單次 commit 並 push `origin/feature/rc-04-security-matrix`，不合併 main。
- 2026-10-30 接續決策後完成可自動執行範圍：沿用本分支與既有證據，先以原始三份 NetLog 取得 Red（19 個 SmartScreen POST 嘗試、同 source／stream HTTP/2 送出 57489 bytes；其中 telemetry 原證據為 4510／4619 bytes），再在 web adapter 每個 controller 導覽前套用 Settings8 關閉信譽檢查，失敗沿用 ReportFailure。新版 EXE `AA41960045CBDDE7B6EDB585A84D7E92E235C215C202137EEA4A9AB023151D8E` 在 Windows 11 26200.8737／Runtime 156.0.4314.50，Minimal、HTTP／HTTPS off→on→off、管理／獨立重啟的三份 NetLog 均為零 SmartScreen POST／零送出 bytes。安全與雙目標回歸、相關 CTest 15/15 PASS；非 Temp 使用者繁中／空白路徑、Node 直接啟動、獨立 LOCALAPPDATA，未觀察新增防毒攔截。取捨見 ADR 0005；WPAD 與 Edge ECS GET 仍有背景流量，後者 query 含識別／版本欄位，聚合不保存值；不宣稱整個程序零外連。完整證據、命令及未驗項目見 REPORT 接續章節。resolved 只表示本票可執行驗證及報告完成；URI handler／其他 Runtime／TURN-UDP／TLS、其他介面／proxy、真正舊 COM callback 送達競態及完整 DNS 仍 PARTIAL／NOT RUN，03 試用包 hash 不變且不含修正，08 必須重包，09 gate 保留。05 智慧休眠缺陷未修；完整套件留 09，不擴張票範圍。審查與提交紀錄見本節收尾項。
- 2026-10-30 Codex 停止／待決策：從 HEAD `1c62cc41e54a642f5ae5ed0d723e9b0893cef542` 建立 `feature/rc-04-security-matrix`。trial.4 原包解壓至非 Temp 的使用者繁中／空白路徑，Node 直接啟動 EXE、隔離 LOCALAPPDATA；既有／擴充安全與雙目標探針及相關 CTest 15/15 通過，未改產品。但 WebView2 156.0.4314.50 的 NetLog 在內建 Minimal／allowNetwork=false 時，證實向 `telem-edge.smartscreen.microsoft.com/api/browser/edge/telemetry/3` POST 4510 bytes（09:38:57.157+08:00），最後關閉網路階段另 POST 4619 bytes（09:39:36.485+08:00），均有 SEND_DATA 與 HTTP 200。這是瀏覽器背景上傳，內容未判定；與 handoff §7.7「無遙測、無背景上傳」適用範圍存在衝突，不自行縮限或停用安全防護。依使用者停止規則保持 in-progress，**未 commit／push**；原持續桌布不動，測試程序已退出。本輪未觀察到防毒新增攔截，詳細限制、原始 hash／時間／命令、URI／其他 Runtime／TURN／舊 controller race 的 PARTIAL／NOT RUN 及 03／08／09 gate 影響見 `docs/acceptance/2026-10-30/security-matrix/REPORT.md`。需釐清要求後再續作，安全 PASS 不解除此 BLOCKED。
- 2026-10-29：先前 HTTP／HTTPS、WS／WSS、STUN／TURN-TCP、單一 preconnect、worker／儲存與導覽復原的指定 PASS 保留。新增矩陣 NOT RUN。
- 2026-10-30 決策（使用者確認）：「能關閉遙測的話」採嚴格做法——不論 allowNetwork，一律以 WebView2 `ICoreWebView2Settings8::put_IsReputationCheckingRequired(FALSE)`（SDK 1.0.2478.35 已支援）關閉 SmartScreen 信譽檢查。先保留可重現的失敗行為測試（NetLog 在網路關閉時出現 `telem-edge.smartscreen.microsoft.com` 上傳即 FAIL），再最小修正，並以同一 NetLog 判準重驗網路 off／on／off 均無 SmartScreen 上傳。取捨（主題下載／外部導覽已由宿主拒絕，失去 SmartScreen 的安全代價小）寫成 docs/adr。條件：若關閉後仍有 SmartScreen 遙測上傳，視為前提不成立——停止、不 commit、回報，不另尋繞行。其他無法由 app 關閉的 OS／瀏覽器背景流量（如 WPAD）逐項歸因並列為已知限制，不宣稱整個程序零外連。
