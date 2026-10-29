# 多螢幕套用政策與驗證

本文件實作 RC 01 已確認需求，基準為 `7806266`，功能分支為 `feature/rc-01-multi-monitor`。

## 所有權與政策

- `platform/windows` 使用 QueryDisplayConfig 的 active paths 與 DisplayConfigGetDeviceInfo，保存 target monitorDevicePath；GDI DISPLAY 名稱只用來對應目前桌面矩形。名稱缺失時顯示裝置路徑，識別或幾何取得失敗則回報錯誤，不猜測目標。
- 首次或 schema 1 設定沒有目標時，在 UI 初始化列舉後解析成當時主螢幕 ID。schema 2 保存明確 ID 陣列，沿用既有原子寫入；桌布模式禁止空選擇。
- 保存的斷線目標保留並標示未連接。部分斷線只顯示仍連接目標；全部斷線暫用目前主螢幕並提示，不改寫原選擇，任一目標接回即恢復。
- clone 使用相同桌面 source 的群組，任一 target 選中只建立一個宿主；清單標示鏡像群組。每個有效區域顯示完整同一全域主題，無跨屏拼接或逐屏權限。
- app composition 管理每個區域獨立 HWND、Win32DesktopHost、WebView2Host 與復原／逾時狀態。Preview 只有一個視窗。穩定通知視窗持有採樣、電源與管理入口，所有 renderer 收到相同快照、主題與全域網路政策。
- 以螢幕實體矩形轉 WorkerW client 座標；明確設定 WebView2 rasterization scale，bounds 保留實體像素。顯示／裝置事件與定期列舉偵測拓樸及 DPI 改變，移除不再需要的宿主，保留未變動宿主。
- callback lifetime token、宿主 HWND 與全程序唯一載入世代共同隔離舊訊息；單目標失敗僅處理該 renderer，管理入口保持有效。

## 可自動驗證案例

SettingsStore：schema 1 遷移、schema 2 round trip、斷線 ID 保留、非法／重複／空 ID、原子取代失敗及損毀檔保留。
Runtime 公開目標解析：單選／雙選、部分／全部斷線、接回、主屏變更、負座標／不同尺寸、鏡像去重。
原生整合：列舉實際螢幕與 DPI、各目標 HWND／附掛矩形／握手、主題／暫停／模式／退出、舊世代與全域網路回歸。程序證據不等於人工畫面 PASS。

## 人工操作清單

使用獨立受測程序及隔離 LOCALAPPDATA，不關閉或替換原持續桌布。記錄 EXE hash、Windows／Runtime 版本與實際螢幕配置。

1. 單選、雙選、取消一屏，確認 Minimal／Dashboard 各完整顯示、未選屏保留桌面，取消草稿與重新開啟／重啟一致。
2. 更換主螢幕、負座標、不同解析度／混合 DPI，確認位置、縮放與內容完整。
3. 部分斷線、全部斷線、重連及鏡像，核對提示、保存 ID、不多建宿主、不套到其他區域。
4. 真正 Explorer 重啟後核對所有已選目標恢復、持續更新、圖示／工作列／系統匣；本票自動執行不重啟 Explorer。
5. 所有目標主題切換、暫停／繼續、Preview／桌布往返與正式退出；觀察程序樹清理。

實際命令、結果與 NOT RUN 原因於本票完成時記錄於 docs/STATUS.md 與 acceptance 報告。最終 800×600 設定版面由 RC 02 處理。

## 官方 API 依據

- [QueryDisplayConfig](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-querydisplayconfig)
- [ICoreWebView2Controller3](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2controller3)
