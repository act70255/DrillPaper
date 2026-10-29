# 主題安全模型與目前限制

主題是未受信任的 HTML、CSS 與 JavaScript。僅匯入信任的內容：**目前沒有完整第三方沙箱保證，A12 與 RC gate 保持未通過**。

## 已實作邊界

- ThemeManager 先檢查 manifest、路徑、ZIP 屬性、CRC、檔案數量與容量，再 staging／原子安裝；禁止覆蓋同版本。移除只接受安裝目錄內驗證吻合的版本並拒絕重新解析點。
- 每次載入產生獨立 GUID HTTPS 來源，使用不同的可註冊 `.invalid` 網域，避免共同父網域 Cookie 跨載入；停止舊頁面並重設握手。bridge 驗證目前來源、版本、schema、大小與允許操作；沒有通用檔案、shell、DLL、PowerShell 或管理設定命令。命名與實際儲存測試見 [ADR 0002](adr/0002-isolated-registrable-theme-domains.md)。
- 本機資產透過 WebView2 請求事件提供，不啟動 HTTP server。每份回應帶宿主強制 CSP、no-store、nosniff、no-referrer、停用 DNS 預取與部分 Permissions Policy。路徑僅解碼一次，拒絕越界與重新解析點；讀取上限 10 MiB。原因見 [ADR](adr/0001-host-controlled-theme-responses.md)。
- 全域 allowNetwork 預設 false。離線仍可讀取自己的資產；開啟後允許所有網域的 HTTP／HTTPS 資源。套用設定會重新載入主題，CSP 與 request policy 均使用最新偏好；取消不套用，重啟恢復保存值。
- 外部頂層導覽、框架、worker、WebSocket、物件、表單、下載、權限與彈窗分別拒絕，不隨開關放行。停用 host objects、DevTools、預設內容選單及 script dialogs。HTTP 仍受瀏覽器原有 TLS／混合內容規則限制。
- 另附宿主 Connection-Allowlist，固定拒絕 WebRTC；關閉網路只允許目前來源，開啟後加入 HTTP／HTTPS，CSP 與原生限制繼續生效。本機 Runtime 155.0.4283.62 的 data channel／STUN 負面有舊版收件與修正版零收件證據；不同 Runtime 不由此建立支援聲明，見 [ADR 0003](adr/0003-connection-allowlist.md)。
- 若被拒絕的頂層導覽仍造成瀏覽器錯誤頁，原生失敗事件以載入世代觸發可信 Minimal 回復，不改已保存偏好；可信回復亦失敗時保留管理入口與友善提示，見 [ADR 0004](adr/0004-recover-blocked-navigation.md)。
- 首次封鎖 HTTP／HTTPS 顯示可信原生設定提示，每個 app 工作階段最多一次，不放行、不保存。固定注入的 CSP 通知僅能觸發一次提示；即使主題偽造同一通知，也無法更改設定或執行管理命令。
- 一般使用者權限；私有 WebView2 user-data 目錄；只提供核准的彙總指標，產品沒有遙測。

## 真實 WebView2 驗證

執行 scripts/test-webview2-security.ps1，指定 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe。使用隔離 LOCALAPPDATA、實際匯入的測試主題與 loopback Node HTTP fixture；Node 只供測試，不是產品依賴。以瀏覽器結果、既有 SDK 訂閱及伺服器實收紀錄交叉判定，不以單元 policy 代替流量證據。HTTPS 正向案例對 https://example.com/ 發出固定 no-cors 測試請求，需要可用網路；不略過憑證驗證。

已重現舊攔截器未阻止 WebSocket；加入強制 CSP 後通過同一負面案例。HTTP／HTTPS 開關、首次提示、保存／取消／重啟、本機 JSON、script、image、fetch、XHR、iframe、WebSocket、HTTP redirect、redirect 至 file、外部導覽、彈窗、通知／定位權限、下載事件及非支援 scheme 的結果見 [階段 3 報告](acceptance/2026-10-29/management/PHASE3.md)。

## 未證實的範圍

另已測 IndexedDB／Cache Storage 的當前來源讀寫與每次載入隔離、Dedicated／Shared／ServiceWorker、camera／microphone 權限查詢 denied、TURN-TCP 接收端無主題連線。證據及精確範圍見 [續驗](acceptance/2026-10-29/management/REMAINING.md)。

另以獨立 TCP 接收端實測單一 loopback HTTP preconnect：舊版在關閉時仍連線；目前政策下，開啟時有瀏覽器正向連線，關閉時無新增連線。這不等於完整 DNS／TLS preconnect 或背景流量驗收。

NOT RUN：完整 WebRTC（含 TURN-UDP／TLS）、完整 DNS／preconnect／推測連線、瀏覽器自身背景流量、舊頁面訊息競態、完整權限種類／設備 API、所有 scheme 組合、瀏覽器漏洞與 OS sandbox 逃逸。STUN 與 X-DNS-Prefetch-Control 不等於已量測所有 WebRTC／DNS 流量，不能證明完全阻止網路外傳。

檔案檢查不是 OS 隔離，無法保證同使用者並行替換路徑的安全性。無限迴圈與資源耗盡另屬復原／效能矩陣。這些限制及未完成的 Windows 相容性、乾淨安裝等 gate 仍阻擋 app RC；不得將套件驗證或目前通訊測試稱為完整沙箱。
