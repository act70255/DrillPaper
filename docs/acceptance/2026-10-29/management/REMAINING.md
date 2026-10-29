# 管理功能剩餘驗收續作

日期：2026-10-29。承接已確認的三階段 spec 與 `488a832`，分支 `feature/tray-management`，不合併 main。

## 範圍與方法

- 沿用原生 Win32／WebView2 整合 seam，先增加可失敗的實際行為測試；只有重現缺陷才做最小修正。
- 補每次來源載入的 localStorage／sessionStorage／Cookie 隔離，包含共同父網域 Cookie 的負面案例。
- 補 WebRTC 的 UDP/STUN 接收端，以獨立 UDP 正向控制確認接收端可用，再比對網路開關及重啟期間收件。
- 續驗 worker、額外權限及 URI scheme；具體覆蓋與未執行範圍依結果記錄，不推論完整沙箱。
- 重測最終版本的管理／復原；鍵盤、縮放與真正 Explorer 的像素確認由人工補充，Computer Use 管道仍為 `os error 2`，不將原生命令注入視為真正點擊。
- 每個修正階段更新 STATUS，使用 commit-msg skill 產生繁中訊息後 commit＋push。完整回歸在本輪實作完成後執行，CI 對應實際提交。

原持續桌布 PID 83428 已核對為 `persistent-readiness-20261029-120049/binary/DrillPaper.exe`，固定 a241856 副本，保持運作。人工鍵盤／版面測試另用隔離固定副本 PID 90952，受測 hash `F0238D6151CF4FC812F94483D99F40AE869D675DA2CF308C201D959B5D6EB757`，不與後續修正版混用。

## 結果

### 本輪結案總表

| 範圍 | 實際結果與證據 |
| --- | --- |
| 最新產品 | 62f01ab，EXE SHA-256 `8AACD05B50BEDF89E2F191B14986E3A1AB380A60B075C0CA5097DDAE539176D1`。本輪修正為 a8c39b5（Cookie）、d3a24dc（WebRTC）、62f01ab（失敗導覽回復），均已各階段提交推送。 |
| 真正新版 Explorer／人工 | PASS：使用者回報「新版畫面恢復且持續更新，圖示／工作列可用」。Shell 98068→93396，同一 app 85932、HWND 1376352→1054746、ReadyEpoch 2→4、DesktopEpoch 2→3、新指標與系統匣重註冊。使用 Dashboard mock／no-smart-sleep，固定副本僅 h1 加識別標題，資產 hash 另存 remaining-explorer-fixture.json。 |
| 管理生命週期 | PASS：5 次開關唯一視窗、暫停／恢復、模式、保存／取消／重啟、正式退出 0 與已觀察子程序清理。持有 handle 與父子建立時間避免 PID 重用。remaining-management.log／result.json、150% remaining-management.png。 |
| 鍵盤／唯一視窗 | PASS（人工，F0238D…）：原文與範圍見下節及 remaining-user-confirmation.json。DPI 未由此通過。 |
| 完整本機回歸 | PASS：Release build、test.ps1，CTest 33/33（26.08 秒）、SDK 18/18、其他封裝／環境／負面 oracle／採樣工具。remaining-full-regression.log。 |
| 原生其他回歸 | PASS：1 次受控 runtime＋50 次快速往返；3 次 custom-entry renderer 故障，握手世代由 2／3／4 分別前進至 3／4／5；100 次主題切換及已匯入主題。remaining-{runtime,renderer,switch}.log／summary.json；不外推真正電源循環、像素切換或無洩漏。 |
| 產品 CI | PASS：[62f01ab run 40839289477](https://github.com/act70255/DrillPaper/actions/runs/40839289477)，CTest 33/33、SDK 18/18 及 SDK 還原／封裝。62f01ab-ci.json／log。RC job skipped，沒有發行。 |
| 最終擴充安全 | PASS：security-afe8952ca34242c28adce0b05c1e2c0c，同 hash；新增 preconnect 與所有列明案例，remaining-security-result.json。 |
| 原持續桌布 | PID 83428 未關閉／替換；固定 a241856 路徑，重啟後 parent=93396、ReadyEpoch=4、兩秒指標持續增加；remaining-persistent-after.json。 |

命令：

```powershell
cmake --build --preset windows-msvc-release --parallel 8
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1 -Configuration Release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-management-shell.ps1 -ApplicationPath artifacts/acceptance/remaining-explorer-20261029-155140/binary/DrillPaper.exe -Desktop -ObserveExplorerRestart -ObservationSeconds 180 -VisualObservationSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-runtime-lifecycle.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Cycles 1 -Rapid -RapidIterations 50
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-renderer-recovery.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Crashes 3 -CustomEntry
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-theme-switch.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Cycles 100 -IncludeInstalled
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-webview2-security.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe
```

Explorer 指令本身只觀察；實際另核對 GetShellWindow owner、真正 explorer.exe 路徑與原持續桌布路徑後重啟 Shell，未向 app 注入通知代替。三分鐘觀察期取得上述人工回報。原始腳本的 visual／actualTrayClick=NOT RUN 沒有被改寫，人工畫面／圖示／工作列結論另存；新版重啟後的真正系統匣點擊沒有額外人工回報，不由圖示註冊推論。

### Preconnect 的實際 TCP 邊界

以獨立 loopback TCP 接收端及原生 TcpClient 控制一筆，瀏覽器插入 link rel=preconnect。舊固定副本 F0238D… 在預設關閉時仍多一筆 TCP，session security-1add9fb4f3f545a990af3fda927d5369，preconnect-red.log／connections.jsonl。現有 62f01ab 的 Connection-Allowlist 已能拒絕，故未再改產品；同探針確認開啟時有瀏覽器正向連線，再關閉時沒有新增 TCP。完整安全結果 PASS，preconnect-green.log／connections.jsonl。這是單一 loopback HTTP preconnect，不是完整 DNS、TLS preconnect 或背景流量驗收。

### 尚未執行與限制

NOT RUN：完整 Windows DPI／解析度與跨螢幕矩陣；完整 DNS／其他 preconnect／推測連線／瀏覽器背景流量；TURN-UDP／TLS、其他 WebView2 Runtime、全部權限與設備 API、scheme／舊頁面訊息競態、瀏覽器與 OS sandbox 逃逸。完整 Alt+Tab／虛擬桌面、display-off／待機、硬體精度、效能／乾淨安裝等依 FINAL_HANDOFF 的原有 gate，沒有由此次管理驗收外推。

Computer Use 仍回報 os error 2，未混用 PowerShell UI Automation；人工回報補足可觀察的畫面與操作。一次唯讀輔助腳本因 PowerShell 7 組件／PowerShell 5 UTF-8 BOM 需校正後才執行，不是產品失敗。報告內終端日誌僅正規化行末空白；原始 byte 版本留在 artifacts/acceptance。

Nowledge Mem 在收尾時 MCP／CLI status 均回報 127.0.0.1:14242 拒絕連線，未宣稱新決策已同步。ADR 0002–0004、STATUS 與本報告保留可接續證據，不因記憶服務中斷而略過工程收尾。

本表及人工回報取代較早的「新版 Explorer 像素待驗／鍵盤待驗」狀態；未測範圍仍保留。整體 MVP／RC 尚未通過，不宣稱完整沙箱，不合併 main。

### 空白錯誤頁與擴充安全矩陣

新增 worker／儲存測試後，原探針停在外部導覽後。先後移除 service／shared／dedicated worker、改事件確認、改非同步函數，以及暫時於 NavigationStarting 取消後 Stop，均未建立完整通過；沒有以這些嘗試改寫成 PASS。隔離 CDP 證明已提交 `chrome-error://chromewebdata/`，unreachableUrl 為 loopback navigate endpoint，body 空白。CDP 證據來自暫態 Stop 嘗試 hash FB7418…，該改動已撤回。此時原生標題仍可保留舊的 Live metrics，因此不能用標題／metrics tick 單獨判定畫面存活。

獨立最小 Red：DF658C… 固定副本、security-z-navigation，先完成一次訂閱，worker 遭拒再嘗試外部導覽，第二次訂閱不成立。新增失敗 NavigationCompleted／實際 Source 的可信 Minimal 回復後，同案例及完整安全腳本 PASS，session security-ddad2d5848c94edfb672e3d87d1ff809，EXE hash `8AACD05B50BEDF89E2F191B14986E3A1AB380A60B075C0CA5097DDAE539176D1`。ADR 0004 明列新行為及保存偏好不變。

同一輪亦 PASS：IndexedDB、Cache Storage（當前來源讀寫正向控制與每次載入隔離）；host-only Cookie；Dedicated／Shared／ServiceWorker；camera／microphone 權限狀態 denied；STUN UDP 與 TURN-TCP、WSS 只有接收端的原生控制各一筆，無主題收件。HTTP／HTTPS 開關、其他既有負面與兩種重啟通過。navigation-{red,green}.log、navigation-result.json、navigation-{stun,tcp,requests}.jsonl 保存結果；權限查詢不等於所有設備呼叫已測。

完整 DNS／preconnect、TURN-UDP／TLS、其他 Runtime、舊頁面訊息競態等仍 NOT RUN。後續人工與回歸另記，不解除 RC gate。

### WebRTC／STUN

Red：舊固定副本 F0238D…，security-f52a3c6928d94e519a0561ebf9857e1b，網路關閉時仍有三筆真正 STUN UDP；獨立 UdpClient 控制封包另有一筆，見 webrtc-red-packets.jsonl。新增宿主 Connection-Allowlist 後，hash `DF658C57DA4EFAE79CAF7F6CFB6A4E88EA97A1B9AAD2D3CE356799994D0FC7B1`，同測試 PASS，security-a51c31974b1046a0a4f0114a5c78db5b。off→on→off 與管理／獨立重啟期間僅控制封包一筆、主題 UDP 0；既有 HTTP／HTTPS 及其他負面通過。

初版探針假設必須拋出 SecurityError，造成一輪修正版無 UDP 但仍 FAIL。實際政策可允許物件建立而禁止 ICE，因此修正測試判定並以原產品重新證實收件斷言會失敗。保留 webrtc-exception-assumption.log。這是測試校正，不把錯誤斷言視為產品缺陷。

此證據涵蓋本機 WebView2 Runtime 155.0.4283.62、loopback STUN；TURN、完整 DNS／preconnect、其他介面／proxy 與其他 Runtime 尚未由此驗證。ADR 0003 明列政策及限制，A12 與 RC gate 保留。

### 父網域 Cookie

Red：只新增儲存行為測試，舊產品於 allowNetwork=true 第二次載入未能訂閱，exit 1；見 storage-red.log，session security-817687856ec948dfa4c8bcf5939e2d92。移至各自可註冊網域後，同一測試 PASS，session security-59a3f05723ca4f3abcc2080c1f1255a5，hash `8F3DB185176D5A2BCE9DDF445D63D8016DC281B260510AAF2C2A7B5D48BA4CAB`。目前 host-only Cookie 有讀寫正向控制，localStorage／sessionStorage 與父網域 Cookie 在後續來源未沿用。

範圍是每次載入的隔離，不代表整個 storage 矩陣。IndexedDB／Cache Storage 與舊頁面訊息競態仍 NOT RUN，接續補驗。

### 人工鍵盤／唯一視窗

使用者原文：「操作皆正常 但無法縮放因此未測試縮放」。對應 PID 90952 的提問範圍：Tab／Shift+Tab 走遍控制項、空白鍵切換智慧休眠、取消還原草稿、重複系統匣操作只有一個視窗。因此上述操作 PASS（人工）；DPI／Windows 縮放矩陣 NOT RUN，固定視窗沒有拖曳調整大小功能。不將此結果套用到未測的產品 hash 或不同組態。
