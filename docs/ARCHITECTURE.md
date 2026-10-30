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
5. 已於系統匣 spec 確認 AppSettings／SettingsStore、runtime 管理命令與有效狀態、ThemeManager 移除契約；原生檔案選擇器／確認視窗仍以 Windows 實機驗收。

## 目前實作邊界

RC 12 的螢幕錯誤邊界位於 platform/windows：可注入 Windows 裝置名稱讀取，無法辨識者保留原生矩形／DPI 並回傳空 ID；MonitorInventory 保留上次成功列舉，首次失敗暫取主螢幕。runtime 只看 ID／area 值，任一空 ID 暫時選全區域並去重；app 負責提示、記錄錯誤與繼續 reconcile，不持久化退化結果。獨立 Preview 不讀取拓樸，管理控制項拒絕勾選空 ID。相關 fixture 不編入產品 EXE，實機及人眼證據仍分開記錄。

多螢幕由 app composition 持有每個有效桌面區域的 Surface，各自管理 HWND、Win32DesktopHost、WebView2Host、附掛重試與載入逾時；Preview 僅一個 Surface。platform/windows 透過 QueryDisplayConfig 提供 monitorDevicePath、source 群組、實體矩形與 DPI；runtime 公開目標解析處理部分／全部斷線及 clone 去重，不接觸 Win32。SettingsStore schema 2 保存 ID 陣列，schema 1 在 composition 首次列舉時遷移至主螢幕，保存沿用原子取代。詳見 MULTI_MONITOR.md。

穩定通知 HWND 統一接收採樣、電源、拓樸與管理命令，最新快照與有效政策廣播至所有目標。每次選題重建 controller 並重設該目標的復原額度；自動 Recover 則累計額度。各載入使用全程序唯一世代及獨立 GUID origin，舊 callback token 失效，排隊的失敗／網路通知須符合接收 HWND 的目前世代；單目標安全 fallback 不改其他目標或保存偏好。

原生樣本與採樣錯誤送往不附掛 Shell 的穩定 UI 通知視窗，再交給當前 renderer。桌布 HWND 被 Explorer 銷毀時，保留採集工作者與最新快照，於同一 UI 執行緒重新建立宿主、功能表、計時器及同主題 WebView2 controller；舊 callback 的 lifetime token 失效，載入與握手世代繼續遞增。WM_CLOSE 表示使用者退出，非預期 WM_DESTROY／失效 HWND 走復原。相應跨程序父視窗正常關閉、崩潰與無通知回歸已執行；真正 Explorer 及畫面結果仍依 STATUS，不能由 fixture 推論。

目前 Release app 可載入內建及已安裝主題。原生 CLI 經 ThemeManager 驗證及原子安裝；Win32 功能表選擇版本，WebView2 adapter 使用每次載入獨立的 GUID 來源。metrics 已移到 SamplingWorker，透過帶設定世代的 latest-wins mailbox 交給 UI；UI timer 僅處理政策與回復。Windows PowerNotifications 與 WebView2 adapter 分別負責 OS 通知及 hide/suspend/resume，純 Runtime 政策不呼叫 Win32 或 COM。

`ManagementShell` 位於 platform/windows，透過原生命令接回 app composition，不讓 HTML 主題執行管理操作。系統匣由穩定通知 HWND 持有，與桌布 HWND 分離，使用有界 Shell 就緒重試。`ManagedPlayback` 在純 runtime 合成手動暫停與電源政策；採集與 WebView2 各自套用有效結果。

`SettingsStore` 位於 app，管理版本化非敏感偏好、內容及路徑檢查、同目錄暫存／flush／原子取代；損毀原檔不覆蓋。原生管理視窗提供圖形化匯入／確認移除及設定草稿，沿用 ThemeManager 驗證與安裝邊界；移除目前主題先載入 Minimal 並關閉舊 controller。可信內建資產含 SDK 型別宣告，與受限制的第三方安裝內容分開載入，沒有放寬匯入副檔名政策。

`web` 使用每次載入獨立的 GUID HTTPS 來源，透過 WebView2 資源事件提供含宿主 CSP 的本機回應；不啟動 HTTP server。HTTP／HTTPS 全域偏好同時接入 CSP 與 request policy，原生管理介面處理首次提示，通知不授權連網。外部導覽、框架、下載、權限及彈窗各自拒絕。由 folder mapping 改為宿主回應的理由、效能代價及限制見 `docs/adr/0001-host-controlled-theme-responses.md`。

每次載入採不同可註冊 .invalid 網域，隔離父網域 Cookie；宿主 Connection-Allowlist 補足 WebRTC 與推測連線的政策。本機已證實 STUN／TURN-TCP 與單一 loopback preconnect，不推論所有 Runtime／DNS。失敗頂層導覽若提交來源外的錯誤頁，Web adapter 以世代通知 app 切回可信 Minimal；不寫回偏好，Minimal 也失敗則停止 renderer、保留原生管理入口。詳見 ADR 0002–0004。

WTS／電源通知及 renderer 暫停有有限整合證據；renderer／browser 退出已可有界重建與退化，使用載入世代忽略舊通知。web adapter 的 JS 回應探針由 UI 計時器驅動，同一 controller 最多一個待回應工作；非 Active 不累計逾時，逾時送回既有世代檢查及有限復原，不把採樣／JS 回應等同像素存活。新管理 62f01ab 真正 Explorer 重啟已有原生與人工畫面／持續更新／圖示／工作列結果，另有鍵盤／取消／唯一視窗及匯入／移除人工回報；不套用於新多宿主版本。無限迴圈結果見 RC 05，完整 DPI 與效能矩陣仍待驗證。已測 WebRTC、preconnect、IndexedDB／Cache Storage 等範圍不代表完整阻止外傳；完整 DNS／推測連線、其他 Runtime 與舊頁面競態仍未驗。套件驗證不等於沙箱，同使用者並行修改檔案不在檔案系統隔離保證內。證據以 STATUS 為準。
