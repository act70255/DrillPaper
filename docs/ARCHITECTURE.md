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

原生樣本與採樣錯誤送往不附掛 Shell 的穩定 UI 通知視窗，再交給當前 renderer。桌布 HWND 被 Explorer 銷毀時，保留採集工作者與最新快照，於同一 UI 執行緒重新建立宿主、功能表、計時器及同主題 WebView2 controller；舊 callback 的 lifetime token 失效，載入與握手世代繼續遞增。WM_CLOSE 表示使用者退出，非預期 WM_DESTROY／失效 HWND 走復原。相應跨程序父視窗正常關閉、崩潰與無通知回歸已執行；真正 Explorer 及畫面結果仍依 STATUS，不能由 fixture 推論。

目前 Release app 可載入內建及已安裝主題。原生 CLI 經 ThemeManager 驗證及原子安裝；Win32 功能表選擇版本，WebView2 adapter 使用每次載入獨立的 GUID 來源。metrics 已移到 SamplingWorker，透過帶設定世代的 latest-wins mailbox 交給 UI；UI timer 僅處理政策與回復。Windows PowerNotifications 與 WebView2 adapter 分別負責 OS 通知及 hide/suspend/resume，純 Runtime 政策不呼叫 Win32 或 COM。

`.dmt` 支援原生匯入與主題切換，但圖形化匯入、移除、持久化目前選擇尚未提供。WTS／電源通知及 renderer 暫停有有限整合證據；renderer／browser 退出已可有界重建與退化，使用載入世代忽略舊通知。無限迴圈、Explorer、網路提示／開關、Shell GUI 與完整效能矩陣仍待驗證或完成。套件驗證不等於沙箱，同使用者並行修改檔案不在檔案系統隔離保證內。證據以 STATUS 為準。
