# 架構

## 目標邊界

- `core` 管理不可變指標值、品質、單位與能力名稱。
- `monitoring` 讀取作業系統與選用硬體 API，回報 core 資料；不依賴 renderer。
- `runtime` 管理排程、變更偵測、有界歷史、latest-wins 傳遞與電源狀態政策。
- `platform/windows` 管理 Preview 與桌面 Shell 視窗、DPI、工作階段/電源通知與 Explorer 復原。
- `web` 管理 WebView2 生命週期、版本化 JSON bridge 與導覽政策。
- `theme` 管理 manifest/封裝驗證、安裝、啟用、示範主題與公開 SDK。

依賴方向指向 `core`。WebView2 API 必須在持有視窗的執行緒呼叫。Renderer 佇列最多保留最新一份待處理快照；圖表歷史則使用獨立固定容量。主題預計是離線靜態檔案，不可直接呼叫原生 API。

## 已與使用者確認的測試 seam

1. 公開 MetricsSnapshot 與採集器行為，包含 unavailable 與 warm-up。
2. Runtime 狀態轉換、有界歷史與 latest-wins 傳送。
3. Theme manifest/封裝驗證與 Protocol/SDK 行為。
4. Win32 Shell 與 WebView2 在原生環境可用時用 GUI/整合測試；單元測試不能證明這些結果。

## 目前實作邊界

目前的 Release app 可建置並以 WebView2 Preview 載入內建及已安裝主題，完成 protocol handshake、snapshot request 與 subscribe。原生 CLI 經 ThemeManager 限額驗證、暫存及原子安裝主題；Win32 功能表選擇版本，WebView2 adapter 在既有 controller 建立每次載入獨立的 GUID 來源、解除舊 mapping 並重設握手，不重新啟動採集程序。metrics 目前仍由 UI timer 同步採樣，背景 worker 尚未接入。

`.dmt` 支援原生匯入與主題切換，但圖形化匯入、移除、持久化目前選擇尚未提供。網路提示／開關、Windows power/session integration、Explorer/WebView recovery、Shell GUI 與完整效能矩陣仍待完成。套件驗證不等於 WebView2 沙箱；同使用者並行修改檔案不在檔案系統隔離保證內。證據與限制以 `docs/STATUS.md` 為準。
