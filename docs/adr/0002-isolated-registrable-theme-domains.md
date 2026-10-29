# ADR 0002：每次載入使用不同的可註冊主題網域

日期：2026-10-29。狀態：採用。

## 問題

GUID 子網域只隔離 origin storage，無法隔離共同父網域 Cookie。原 `theme-<GUID>.drillpaper.local` 允許主題寫入 `Domain=drillpaper.local`，下一個 GUID 來源仍可讀取。同一個 WebView2 profile 內的主題不應沿用前一來源的瀏覽器資料。

## 決策

每次載入改用 `drillpaper-theme-<GUID>.invalid`，直接位於特殊用途 TLD 下，沒有共同的可註冊父網域。維持 HTTPS 與宿主資產回應，無 DNS 或 HTTP server 依賴。原 `.drillpaper.local` 與 `.invalid` 來源均視為保留來源；只有目前完整 origin 能讀取本機資產，其他保留來源不外送。

Cookie 的 Domain／public-suffix 規則見 [RFC 6265](https://www.rfc-editor.org/rfc/rfc6265.html#section-5.3)，特殊用途 `.invalid` 見 [RFC 6761](https://www.rfc-editor.org/rfc/rfc6761.html#section-6.4)。是否確實拒絕共同父網域 Cookie 仍以真實 WebView2 結果判定，不能只由命名推論。

## 驗證與代價

`security-probe.js` 每次載入先檢查 localStorage、sessionStorage 與父網域 Cookie 不存在，寫入目前來源資料及嘗試父網域 Cookie。宿主的 off→on→off 與兩種重啟會載入不同來源；目前來源的 host-only Cookie 亦須能成功讀寫作為正向控制。舊產品新增測試後在第二次載入 FAIL，修正版沿用相同測試。

來源仍為每次載入隨機產生，主題不能依賴瀏覽器 storage 跨載入保存設定。這符合既有生命週期，但不提供 profile 資料自動清除或磁碟容量上限；IndexedDB、Cache Storage、舊頁面競態及其他瀏覽器邊界仍依各自證據記錄。
