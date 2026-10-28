# 主題安全模型與目前限制

## 威脅模型

主題是未受信任的 HTML、CSS 與 JavaScript。惡意主題可能嘗試連網、外部導覽、彈出視窗、下載、權限提示、偽造訊息、耗盡資源或利用壓縮檔路徑穿越。原生 host 必須把套件與所有 web message 都視為不可信輸入。主題不得取得通用檔案、shell、DLL、PowerShell 或任意原生命令能力。

## 預期控制

- 驗證 ZIP 路徑與配額後，只能安裝到目前使用者的 DrillPaper 資料目錄。
- 每個主題使用固定的本機 WebView2 virtual host mapping；驗證訊息來源、origin、API 版本與 schema，拒絕未知命令和超大 payload。
- 預設拒絕外部 top-level navigation、新視窗、下載與權限請求。
- 使用應用程式私有 WebView2 user-data 目錄，並以一般使用者權限執行。
- 使用限制嚴格的 CSP/request policy；需測試 `fetch`、XHR、圖片、script、iframe、redirect 與 WebSocket。
- 只提供核准的彙總指標；不揭露帳號、序號、任意路徑或不受限制的系統呼叫。

## 使用者已選定的網路政策（完整設定流程尚未實作）

- 主題外連預設封鎖。
- 全域網路開關維持單一設定。主題首次外連遭封鎖時提示使用者前往設定；提示本身不會放行請求。
- 使用者開啟全域開關後，主題 WebView 可對任何網域發出 HTTP/HTTPS 請求。其他 URI scheme 仍封鎖；DrillPaper 本身不送遙測。
- 已加入純 C++ `ThemeNetworkPolicy` 狀態模型，CTest 覆蓋預設封鎖、首次提示、HTTP/HTTPS 開關行為、本機資源與其他 scheme 封鎖。WebView2 host 原始碼亦拒絕非本機 navigation/resource 和新視窗；這個 baseline host 尚未接上政策模型、首次提示或全域開關。沒有網路流量實測，因此不能宣稱使用者選定的完整網路政策已執行或阻止資料外傳。

## 目前已有實測的控制

JavaScript manifest validator 會拒絕未知欄位、不支援的 API 版本、路徑穿越寫法、無效 ID/版本、未知或重複 capability，以及非空 permissions。JavaScript SDK 限制訂閱指標、更新間隔、歷史筆數與未完成請求數。這些都只是前端/作者工具檢查，惡意主題可繞過。

PowerShell `.dmt` 驗證器已在本機對正常封裝、路徑穿越、大小寫重複路徑、錯誤副檔名、未知 API 版本與超大檔案執行負面測試。它不會安裝或執行主題。

原生 `.dmt` 已加入限額／路徑／連結屬性／CRC／manifest 驗證、暫存及原子安裝，並以真實 ZIP 及 Windows junction 做負面測試。每次 WebView2 載入使用獨立 GUID origin，解除舊 mapping 並重設握手；此設計仍須進一步做惡意舊頁面訊息與跨主題 storage 測試。詳細證據見 `acceptance/2026-10-28/theme-platform/REPORT.md`。

WebView2 的非本機 navigation/resource 與新視窗拒絕已編入 Release，但外部網路負面整合、download/permission 拒絕、CSP、renderer 復原仍未完成。因此第三方主題**尚未沙箱化**，沒有完整阻止網路外傳的證據。僅匯入信任的內容；發行閘門保持阻擋。同使用者並行替換檔案不在目前檔案系統隔離保證內。
