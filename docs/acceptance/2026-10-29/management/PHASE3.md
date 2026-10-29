# 管理階段 3：網路設定與 WebView2 安全整合

日期：2026-10-29，Windows 11 Pro 25H2 build 26200.8737，WebView2 Runtime 155.0.4283.62，MSVC Release。分支 feature/tray-management；未合併 main。

## 版本與命令

- EXE SHA-256：`3FA3C434F9B7A90E686596265798684288046821291F484760D0C4508E662BE5`。
- `cmake --build --preset windows-msvc-release --target DrillPaper --parallel 8` PASS。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-webview2-security.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe` PASS。最新 session 另由 STATUS 記錄；保留 result.json、source、隔離 appdata、server.json 及 requests.jsonl。
- `scripts/test-management-shell.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Desktop` PASS，session `artifacts/acceptance/management-ad0a4eab34c24d45955e425e74e43191`。唯一視窗、暫停／恢復、受控圖示重註冊、模式、保存／取消／重啟與已觀察子程序退出；非真實 Explorer 重啟或圖示點擊。

## Red → Green

1. 首次外連原本沒有提示：15 秒逾時退出 1。接入政策後出現可信原生設定提示，開關仍關閉。
2. 原本管理介面沒有可用網路開關：退出 1。加入草稿、套用與保存，實際 loopback HTTP 的 off→on→off 與伺服器實收紀錄相符。
3. WebSocket 在舊攔截器下仍抵達 loopback server：預設封鎖測試退出 1。改為宿主提供帶強制 CSP 的本機資產後，同一負面案例通過；iframe 在啟用網路後也沒有抵達伺服器。
4. 最初 connect-src 全拒絕造成離線主題無法 fetch 自己的 JSON：測試退出 1。縮至目前 GUID HTTPS 來源後，離線資產及外部拒絕皆通過。

測試工具亦曾因 PowerShell 5.1 的無 BOM UTF-8、fixture 使用禁止的 .txt，以及讀寫測試資產瞬間衝突而失敗；改用 UTF-8 BOM、允許的 JSON 資產與有界寫入重試。這些不是產品通過證據。

## 實際測得的邊界

| 案例 | 結果與證據 |
| --- | --- |
| HTTP fetch／XHR／script／image／redirect | 預設及再次關閉時失敗且 server 沒有新增收件；啟用時瀏覽器成功並有對應收件。 |
| HTTPS | 固定 example.com no-cors 請求只在啟用時成功；沒有略過 TLS。未做 HTTPS 封包擷取。 |
| 首次提示／設定 | 提示不允許；取消還原草稿；保存與重啟恢復 true；再次關閉後仍拒絕。 |
| WebSocket／iframe | 兩種設定下均無對應 loopback 收件；CSP 與原生 frame navigation 拒絕。 |
| 外部頂層導覽／彈窗 | 原頁面仍可完成 SDK 訂閱；window.open 為 null；server 沒有 navigate／popup 收件。 |
| redirect 至 file／其他 scheme | file、data、ftp 的 fetch 無法讀取；HTTP redirect 至 file 無法完成。不是所有 scheme 的完整矩陣。 |
| 通知／定位權限 | 真實 JS 結果為 denied／PERMISSION_DENIED；不由此外推所有權限。 |
| 下載 | 真實本機 download 連結觸發 DownloadStarting，宿主設 Handled 與 Cancel；原生屬性觀察到此事件。 |
| 正常退出 | 安全腳本在重啟與收尾使用管理退出，exit 0，已觀察程序樹退出。 |

頁面只有完成斷言後才透過既有 SDK subscribe；宿主 ReadyEpoch 因真正訂閱前進。等待上限 15 秒小於產品的 20 秒 fallback，避免把內建 fallback 當成測試成功。HTTP server 只在 127.0.0.1 隨機埠，Node 僅為驗收工具。

## 界線與下一階段

NOT RUN：WebRTC、完整 DNS／preconnect／瀏覽器背景流量、跨主題 storage／舊頁面競態、全部權限／scheme、封包層完整 egress、無限迴圈與 OS sandbox；目前測試沒有涵蓋這些通訊面。不得宣稱完整沙箱或完全阻止外傳，A12 與 RC gate 仍保留。

真正圖示點擊、匯入／移除確認、新版真正 Explorer 重啟、移除 junction、完整回歸與本版 CI 在此階段 NOT RUN，接續驗收補上；不沿用舊版結果。原持續桌布 PID 83428 的固定 a241856 副本仍保留。
