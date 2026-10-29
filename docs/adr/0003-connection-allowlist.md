# ADR 0003：以宿主 Connection-Allowlist 補足 WebRTC 邊界

日期：2026-10-29。狀態：採用，支援範圍以實測 Runtime 為限。

## 問題與證據

真實 WebView2 測試在 allowNetwork=false 時，RTCPeerConnection data channel 仍向 loopback STUN 接收端送出三個具有 STUN magic cookie 的 UDP 封包。無音訊／視訊，沒有要求攝影機／麥克風權限。CSP 的 fetch／WebSocket 政策不能由此推論涵蓋 WebRTC。

## 決策

宿主對每份本機資產回應附加 `Connection-Allowlist`，關閉時只允許 `response-origin`；開啟時再允許任意主機／port 的 HTTP／HTTPS。固定 `webrtc=block`，讓 data channel 與 ICE 不隨全域開關放行。保留 `redirects=allow` 以維持既有 HTTP redirect 行為；每個請求仍經 CSP 與宿主 request／navigation policy，其他 scheme 不因此放行。不指定 reporting endpoint，不產生外部報告流量。

這是瀏覽器強制的回應政策，沒有用可被主題覆寫的 JavaScript API 包裝器充當隔離，也沒有改系統／使用者的瀏覽器設定。既有 CSP、導航／權限／下載事件仍保留。

依據：[WICG 規格](https://wicg.github.io/connection-allowlists/)、[Chromium 實作設計](https://chromium.googlesource.com/chromium/src/+/main/docs/connection_allowlist_design.md)。此機制仍為新功能，各 WebView2 Runtime 是否支援必須實測；不能把 Chromium 文件視為所有 Edge Runtime 的支援保證。

## 驗證與限制

測試先以原生 UdpClient 發送固定控制封包證明接收端可用，再讓實際 WebView2 嘗試 RTCPeerConnection／ICE，要求安全拒絕，且在 off→on→off、管理及獨立重啟期間沒有額外 UDP 收件。保留修正前 STUN 收件作為瀏覽器正向證據；WSS 原有 TCP 正向控制亦繼續執行。

結果與 EXE hash 依 management/REMAINING.md；未測的 Runtime 不建立此邊界聲明。完整 DNS、TURN／WebTransport、瀏覽器背景流量、不同網路介面／proxy、舊頁面競態、OS sandbox 逃逸仍需另驗，A12 與 RC gate 不由單一 STUN 案例解除。
