# 以宿主資產回應強制主題 CSP

日期：2026-10-29。狀態：依已確認的網路安全階段採用。

原 handoff 建議 WebView2 virtual-host folder mapping，但 Microsoft 明確指出此映射不觸發 `WebResourceRequested`。無法可靠地在映射的 HTML 回應上加上不可由主題移除的 CSP；單靠外部請求事件亦已在本機重現 WebSocket 外連。

每次主題仍使用獨立 GUID HTTPS 來源，改由 WebView2 的 `WebResourceRequested` 提供本機記憶體串流回應，不啟動 HTTP server。回應包含宿主 CSP、no-store、nosniff、no-referrer 與停用 DNS 預取的標頭。路徑只解碼一次，拒絕越界、特殊路徑、重新解析點及超額資產；單次讀取有界。HTML 與其他資產使用相同政策，主題自己的 meta CSP 只能繼續收緊。

HTTP／HTTPS 資源由全域偏好決定；目前來源的本機 fetch 始終可用。外部頂層導覽、框架、worker、WebSocket、物件、表單、下載、權限及彈窗分開拒絕。設定套用會停止舊導覽並載入新來源，使新文件取得最新 CSP。首次提示僅能提醒使用者前往可信原生設定，不能改動開關。

代價是資產讀取回到 UI 執行緒，單檔上限 10 MiB，失敗時回傳拒絕回應；效能須另依 A13 驗收。這不是 OS 檔案隔離，不能防範同使用者的並行路徑替換，也不由已測 HTTP／WebSocket 推論 WebRTC、DNS／推測連線、瀏覽器本身背景流量或所有網路外傳已封鎖。第三方沙箱與 RC gate 保持未通過。

參考：[Microsoft：管理 WebView2 網路請求](https://learn.microsoft.com/en-us/microsoft-edge/webview2/how-to/webresourcerequested)、[本機內容載入選項](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/working-with-local-content)。實測命令與證據另見管理階段 3 報告。
