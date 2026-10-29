# ADR 0004：從被網路政策拒絕的瀏覽器錯誤頁回復

日期：2026-10-29。狀態：採用。

## 問題

在本機 WebView2 155，拒絕 worker 後嘗試外部導覽，Connection-Allowlist 會阻擋請求，但仍可能提交 `chrome-error://chromewebdata/`。原生視窗保留舊的「Live metrics」標題，實際頁面已空白，無法再回應協定。單看伺服器零收件或原生指標不足以驗證畫面存活。

獨立 `security-z-navigation` 真實主題重現：先訂閱一次，嘗試被拒絕的導覽，再要求第二次訂閱；舊產品無法完成。隔離 CDP 診斷亦觀察到實際錯誤 Frame／unreachableUrl；該診斷的暫時 browser arguments 僅影響本次隔離子程序，沒有改全域設定。嘗試在 NavigationStarting 取消後再 Stop 並未修正，已撤回。

## 決策

保留 NavigationStarting 來源拒絕與宿主連線政策，另監聽頂層 NavigationCompleted。若導覽失敗且 WebView2 Source 已離開目前完整來源，透過帶載入世代的原生通知，於 UI 訊息迴圈切回可信 Minimal。通知不從 HTML 接受，不在 COM callback 內重入載入。

復原不寫回 SettingsStore，不自動放行網路；可信管理介面提示此次回復及保存偏好不變。若目前已是 Minimal，或 Minimal 無法開始載入，停止 renderer 並保留原生管理入口與友善錯誤，不反覆重載不可信主題。舊世代的排隊通知忽略。

## 驗證

資源／儲存／worker 探針與導覽復原探針分開，避免一個瀏覽器錯誤頁掩蓋前面所有能力結果。完成資源斷言才訂閱，並核對宿主仍為測試主題，防止 Minimal fallback 冒充成功。導覽探針則要求兩次訂閱世代：原頁面繼續，或第一個訂閱後已由 Minimal 完成新握手；同時要求外部 navigate endpoint 無實收請求。

每次 off→on→off 均執行此案例。實際 hash、日誌及限制見 management/REMAINING.md。這不建立完整舊頁面競態、所有導航方式／scheme 或其他 Runtime 的保證；RC gate 仍依完整矩陣。

參考：[Microsoft NavigationStarting](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2navigationstartingeventargs?view=webview2-1.0.2478.35)、[NavigationCompleted](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2navigationcompletedeventargs?view=webview2-1.0.2478.35)。
