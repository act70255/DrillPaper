# ADR 0005：關閉每個 WebView 的 SmartScreen 信譽檢查

日期：2026-10-30。狀態：使用者已確認，已於指定 OS／Runtime 觀測時段採用並重驗。

## 問題與決策

RC 04 原始 NetLog 在 Minimal、allowNetwork=false 時證實 SmartScreen telemetry POST 實際送出並收到 HTTP 200，與 handoff §7.7 衝突。使用者於票內確認：不論 allowNetwork，一律在每個 controller 導覽前以 `ICoreWebView2Settings8::put_IsReputationCheckingRequired(FALSE)` 關閉信譽檢查；若關閉後仍上傳，停止、不提交、不另尋繞行。

設定留在 web adapter 的初始化邊界，重新載入、復原及多目標皆經同一處；介面取得或設定失敗沿用 ReportFailure，不繼續載入未套用政策的主題。不改系統 SmartScreen、企業防毒或其他瀏覽器全域設定。

## 取捨

關閉後此 WebView 失去 SmartScreen 的惡意網站／下載信譽防護。主題仍是不可信內容；宿主既有外部導覽、下載、框架、彈窗與權限拒絕政策持續必要，不能將取捨描述為沒有安全代價。HTTP／HTTPS 資源開啟後亦沒有 SmartScreen 額外保護；此決策優先滿足已確認的無背景遙測要求。

此 API 的能力是控制信譽檢查，官方文件不保證消除所有瀏覽器背景流量。[Microsoft Settings8 文件](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2settings8?view=webview2-1.0.2478.35)。WPAD 等其他流量須逐項歸因並保留限制；不宣稱整個 app 零外連或完整沙箱。

## 驗證

沿用 WebView2 原生整合 seam，以舊版實機 NetLog 得到 Red，再以新 EXE 的隔離 profile 驗證 Minimal、HTTP／HTTPS off→on→off、管理／獨立重啟。檢查器保留 source／stream 的 SEND_DATA 證據，並採較嚴格的 SmartScreen POST 嘗試即 FAIL，避免非 HTTP/2 傳輸被誤當通過。只保存去敏感聚合，原始 NetLog 留本機 artifacts。實際版本、hash、觀測範圍及結果以本票 REPORT 為準，未測 OS／Runtime 不外推。

Windows 11 26200.8737／Runtime 156.0.4314.50：原三份 NetLog Red；新三份 NetLog SmartScreen POST 0、送出 0 bytes，安全／多目標相關回歸通過。[REPORT](../acceptance/2026-10-30/security-matrix/REPORT.md) 同時保留 WPAD、Edge ECS 背景 GET（query 仍會傳送識別／版本欄位）與其他未驗邊界；不是零背景資料傳送聲明。
