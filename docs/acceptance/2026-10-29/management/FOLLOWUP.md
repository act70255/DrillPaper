# 管理功能續驗與收尾

日期：2026-10-29，分支 feature/tray-management，不合併 main。階段 3 實作已推送 `3871e72`；本報告補充其後發現的獨立啟動偏好修正、負面測試及驗收。

## 獨立啟動的全域偏好

新增真實 WebView2 測試：保存 allowNetwork=true 與測試主題後，以獨立 `--preview` 重啟，要求測試主題完成其 HTTP／HTTPS 斷言及 server 有新收件。先失敗於「standalone 略過已保存的主題或全域網路偏好」。修正 app 在所有 GUI 模式讀取 SettingsStore，再套用 CLI 的暫時覆寫；不在啟動時寫回設定，CLI 匯入／版本等非 GUI 命令不受影響。

最終 EXE SHA-256：`746878782C24CF798CA3B9A84F708607994B11FC5B06A87C57DA07A77F2C2A67`。`test-webview2-security.ps1` PASS，session `artifacts/acceptance/security-d9c5ad6d554f44eba85bb5a87c1ae9f7`。本輪包含管理／獨立 Preview 重啟及 off→on→off，其他邊界沿用 PHASE3.md 的明確覆蓋。

新增 WSS loopback 接收端：以 TcpClient 正向控制確認可收件，之後瀏覽器於所有設定及重啟情境嘗試 WSS，接收數維持 1，沒有新增 TCP／TLS 連線。避免把自簽憑證拒絕誤當 CSP 封鎖。WS 的 HTTP upgrade 亦無收件。此結果仍不是完整 egress／WebRTC／DNS 驗收。

## 真正 Explorer 程序重啟

受測為 `3871e72` 的 EXE，SHA-256 `3FA3C434F9B7A90E686596265798684288046821291F484760D0C4508E662BE5`，Windows 11 Pro 25H2 build 26200.8737，管理模式、Dashboard、mock、智慧休眠關閉。CLI 偏好修正後未再次重啟 Explorer；不將舊 hash 的結果標成最終 hash 的實機測試。

命令：`scripts/test-management-shell.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Desktop -ObserveExplorerRestart -ObservationSeconds 180`。此選項只觀察，不自行終止 Explorer；本次依使用者要求，另核對目前 Shell 與持續桌布路徑後重啟真正 explorer.exe，未向測試 app 注入重建通知來代替。

- PASS（原生程序／bridge）：同一 app PID 56892，Shell 50496→98068；HWND 5642824→6884182；新父視窗屬於 Shell 98068；DesktopEpoch 2→3、ReadyEpoch 2→4，metrics tick 到 1488777171；穩定通知視窗的 TrayRegistered=1。
- PASS：受測管理視窗／設定生命週期、正式退出 0 與已觀察子程序清理；重新啟動恢復已保存主題／模式／智慧休眠，沒有自動改寫設定。
- 原始 session：`artifacts/acceptance/management-c4ae9f514e414a2a9117c1fb24c9a50f`。本目錄保存 before／after／result。150% PrintWindow 管理 PNG 已檢視，新增網路控制項及底部按鈕沒有裁切。
- NOT RUN：新版重啟後像素／持續畫面人工確認與實際圖示點擊。沒有把 bridge 或圖示註冊視為這兩項通過。

原持續桌布 PID 83428 未關閉／替換，仍使用固定 a241856 副本。重啟後唯讀檢查：ReadyEpoch=3、父程序=Shell 98068、兩秒 metrics tick 1488842593→1488844625。舊版 A04 人工 PASS 保留；本次沒有新增舊版畫面人工結論。

## Junction 與回歸

| 檢查 | 結果 |
| --- | --- |
| 真正 NTFS junction 移除負面 | PASS：安裝根目錄、所選版本與巢狀資產均拒絕，外部目標保留；1 案例／12 斷言。現有產品防護未修改，故沒有虛構新的 Red。 |
| ThemeManager 全部測試 | PASS：10 案例／87 斷言。 |
| 完整 Release build 與最後 app 重建 | PASS；沒有額外產品 runtime 依賴，shlwapi 為 Windows 系統函式庫。 |
| test.ps1 -Configuration Release | PASS：最終回歸 CTest 33/33、SDK 18/18、環境／採樣器／主題 ZIP／負面 oracle／SDK 解壓重封。 |
| Runtime 受控生命週期 | PASS：1 次暫停／恢復、50 次快速往返；不代表真正鎖定／電源循環。 |
| Renderer 自訂入口故障 | PASS：3 次 renderer 故障，新握手 2／3／4，session recovery-20261029-144327-ad8563。 |
| 主題切換 | PASS_PROTOCOL：100 次內建切換與已安裝主題握手，session theme-switch-20261029-144327-cf4d9f；非像素或長期洩漏驗收。 |
| 遠端 CI | NOT RUN：需先推送本次提交再觸發，結果另追加。 |

Runtime／renderer／100 次切換的 EXE 為 3871e72；最終 CLI 偏好修正另以安全整合與完整套件驗證，證據不混用 hash。

## 人工待驗與工具限制

Computer Use 初始化實際回報：`native pipe is unavailable ... 系統找不到指定的檔案。(os error 2)`。技能要求只用 Computer Use JS API 操作 Windows app，故本輪沒有另以 PowerShell UI Automation 模擬真正滑鼠點擊。

NOT RUN／等待使用者回報：真正系統匣點擊、檔案選擇器匯入、移除按「否」保留／按「是」移除、新版 Explorer 重啟後像素確認、完整鍵盤／DPI 矩陣。這些尚無可驗證的人工結果。已準備隔離固定副本（最終 hash）及 manual-check.dmt，人工程序 PID 100000；不影響原持續桌布。

WebRTC、完整 DNS／egress、跨主題 storage、其他權限種類及整體 RC 未驗範圍仍依 theme-security.md／FINAL_HANDOFF.md，未解除發行 gate。
