# RC 04：有界安全矩陣

來源 HEAD：`1c62cc41e54a642f5ae5ed0d723e9b0893cef542`；沿用分支 `feature/rc-04-security-matrix` 與原有證據。下文初輪停止記錄保留為歷史；本節是使用者確認決策後的接續結果。

## 2026-10-30 接續：Red → Green 與有界結案

使用者在本票確認一律關閉每個 WebView 的 SmartScreen 信譽檢查；關閉後仍上傳即停止、不提交。沿用已確認的 WebView2 原生整合／NetLog seam，不重跑初輪原包證據。先建立 `scripts/check-security-netlog.mjs`，對初輪原始 NetLog 執行並取得 exit 1，再最小修正 web adapter 的 controller 初始化。沒有設定例外或瀏覽器命令列繞行；介面／設定失敗沿既有 ReportFailure 拒絕載入。取捨及限制見 [ADR 0005](../../../adr/0005-disable-smartscreen-reputation-checking.md)。

| 接續驗證（Windows 11 Pro 25H2 26200.8737／WebView2 156.0.4314.50／SDK 1.0.2478.35） | 結果 |
| --- | --- |
| Red：既有三份 NetLog | FAIL／exit 1：[red.log](resume/red.log)、[去敏感結果](resume/red-result.json)。19 個 SmartScreen POST 嘗試，HTTP/2 送出共 57489 bytes，包含 navigation／download 等端點；其中 telemetry 的兩筆 4510／4619 bytes 仍以原 telemetry-evidence.json 為準 |
| Green：新 EXE，Minimal、HTTP／HTTPS off→on→off、管理／獨立重啟 | PASS：[security.log](resume/security.log)、[三份 NetLog 檢查](resume/green-result.json)、[安全結果](resume/security-result.json)。SmartScreen POST 嘗試 0、HTTP/2 送出 0 bytes；採比「實際送出」更嚴格的 POST 嘗試即 FAIL。僅限本次約 09:52:31～09:53:14 的觀測時段，不推論長期永遠無上傳 |
| 接收端／真實 API 與可信復原 | PASS：HTTP／HTTPS、HTTP／TLS preconnect、STUN／TURN-TCP／WS／WSS、框架／彈窗／下載、workers／來源儲存、三種 HTML 管理命令拒絕、camera／microphone getUserMedia、定位／通知、外部導覽後存活或 Minimal 回復。各項精確範圍沿用本報告下方原矩陣限制；HTTPS 是 example.com no-cors，無設備開啟正向控制 |
| 雙目標與載入世代 | PASS：[multi-monitor.log](resume/multi-monitor.log)、[結果](resume/multi-monitor-result.json)。兩目標網路 off→on→off、來源／Cookie／localStorage、20 次快速切換、停用、父 fixture crash 重建、模式往返、過期原生通知拒絕與目前指標繼續、19 個已觀察子程序退出。此輪雙目標未擷取 NetLog，不據此擴張 SmartScreen 流量聲明；真正舊 COM 回覆送達競態仍 PARTIAL |
| 相關 targets 建置／CTest | PASS：[build.log](resume/build.log)、[related-ctest.log](resume/related-ctest.log) 15/15，於新建置後執行；只跑相關測試，完整套件留 09 |
| 防毒／隔離與原持續桌布 | PASS（已觀察範圍）：EXE 解壓至非 Temp 使用者繁中／空白目錄並以新建置替換 EXE，Node 直接啟動、獨立 LOCALAPPDATA；Trend Micro Apex One 可讀 AEGIS_BM.log 最後修改仍 09:22:30，未觀察本輪新增攔截。原 PID 83428 的 path／StartTime／hash 前後相同，收尾只剩原桌布，未重啟 Explorer。[執行前](resume/before-environment.json)／[執行後](resume/after-environment.json) |
| 完整 DNS／prefetch、真實 controller 延遲回覆 | PARTIAL：指定 DNS hint 有開啟時正向事件，prefetch 無獨立成功判準；排程舊頁面工作與原生通知注入不等同所有 COM callback 已送達 |
| URI 外部 handler、其他權限／設備、TURN-UDP／TLS、其他介面／proxy／OS／Runtime、瀏覽器／OS escape、人工畫面 | NOT RUN：缺隔離接收端／設備／對應環境；人工接續清單見下方，不宣稱完整沙箱 |
| 兩軸 code-review | PASS：[REVIEW.md](resume/REVIEW.md)。Standards／Spec 各 1 項工具問題，補 Red→Green 修正後複查未解決各 0；預期 capture 三份完整性及友善繁中錯誤契約 3/3 PASS |
| 全套測試、CI、發行包、乾淨帳號 | NOT RUN：本票限相關驗證；完整回歸留 09、重包與乾淨交付留 08 |

新 EXE SHA-256：`AA41960045CBDDE7B6EDB585A84D7E92E235C215C202137EEA4A9AB023151D8E`；來源是本分支未提交工作樹，不冒稱既有乾淨 commit。[binary.json](resume/binary.json) 保存路徑／時間及原 ZIP hash；測試副本是 trial.4 解壓資產加新 EXE 與父 fixture，**不是重新交付的 trial ZIP**。原 03 的 trial.4 ZIP／EXE hash 不變，未包含本次產品修正。Node `.started.json`／`.exit.json` 證據保存真實父子 PID、時間與退出碼。

### 背景流量歸因與限制

- SmartScreen：舊資料有實際 POST 內容傳輸；新資料三份 NetLog 無 POST 嘗試。原始檔留忽略的 artifacts，檢查結果保留 SHA-256、事件數與去敏感傳輸計數；不保存授權標頭／內容。
- `wpad:80`：NetLog 的 HOST_RESOLVER 事件，屬代理自動探索背景解析，並非探針指定網域。這是依 [Microsoft WPAD 說明](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/configure-proxy-server-settings) 與端點作的歸因；沒有改系統代理／防毒設定，也不將解析嘗試說成成功資料上傳。
- `config.edge.skype.com/config/v1/Edge/156.0.4314.50`：初始 Minimal 階段的瀏覽器背景 GET 請求嘗試；query 含 clientid、版本／OS／安裝時間等欄位。依 [Microsoft ECS 文件](https://learn.microsoft.com/en-us/deployedge/edge-configuration-and-experiments) 歸因為 Edge 組態服務，不是 SmartScreen POST。[去識別紀錄](resume/browser-background.json) 保留 method／欄位名稱，URL_REQUEST_START_JOB 本身不證明已成功送達；**GET 若送出同樣會帶出 query 資訊，不能聲明零背景資料傳送**。未在本票另改全域企業政策或探索額外關閉方式，不能聲稱 app 已阻止此流量或證實不可關閉。
- 其餘 TCP IP 不單靠位址推論用途；HTTPS 正向探針與其他背景連線的歸因有限。NetLog 不是全介面封包擷取。聚合 URL 一律移除 query／fragment；初輪衍生摘要亦重新去除識別值，原始 NetLog／hash 不變。

[新背景摘要](resume/netlog-summary.json) 與 [切換時間](resume/network-phases.jsonl)。支援聲明只涵蓋本表實際組合與觀測時段；allowNetwork 不控制所有 OS／瀏覽器背景流量。

### 接續命令與下游 gate

```powershell
node scripts/check-security-netlog.mjs artifacts/acceptance/security-856756a114904dcd92b3f083f43ba64e
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperSettingsTests DrillPaperThemeTests --parallel 8
$application = 'C:\Users\James\DrillPaperTests\安全矩陣 含空白\SmartScreen-20261030-095223\DrillPaper.exe'
& scripts/test-webview2-security.ps1 -ApplicationPath $application
& scripts/test-multi-monitor.ps1 -ApplicationPath $application
node scripts/summarize-security-netlog.mjs artifacts/acceptance/security-a083a9169b2346fca1787dd3aea17cf7
ctest --test-dir build/windows-msvc-release -C Release -R '^Protocol v1 |^Settings |^Invalid settings|^Monitor target|^Invalid monitor|^Monitor selection|^Clone targets|^DrillPaperThemeTests$' --output-on-failure
```

變更檔另跑 node --check／PowerShell Parser 通過（含新增工具測試後共 6 個 JS／3 個 PS，見 [syntax.log](resume/syntax.log)）。`node --test tests/security-netlog.test.mjs` 3/3；修正檢查器後重播完整原／新證據仍為 Red／Green，檢查結果另列 expectedNetlogs 三份。沒有執行 scripts/test.ps1。03 試用限制須保留舊版背景流量說明；08 必須從含本修正的版本重新打包並驗證，不能以試驗副本冒充新包；09 保留安全 PARTIAL／NOT RUN 及 05 智慧休眠缺陷 gate。本票 resolved 表示完成有界可執行驗證／缺陷修正／報告，**不代表 RC 放行**。

另以 Windows PowerShell 5.1.26100.8737 parser 重現新增 helper 缺 UTF-8 BOM 的解析失敗，補 BOM 後三個 PS 腳本皆通過：[失敗](resume/windows-powershell-parser-red.log)／[通過](resume/windows-powershell-parser.log)。此為工具編碼修正，沒有重跑／改寫先前的實機證據。

提交訊息依 commit-msg 技能檢視 staged diff 產生：`fix(web): 關閉 SmartScreen 信譽檢查並補安全矩陣`，本票單次 commit 並 push 原功能分支。暫存後 whitespace 檢查只排除保留 Node 原始輸出的 resume/review-red.log（四行空白行帶空格）；其他全部通過，不改寫原始失敗證據。未合併 main 或公開發行。

## 初輪歷史記錄（以下停止狀態已由上述確認決策接續）

## 執行前需求與判定

- 使用 03 的 trial.4 原始 ZIP，核對清單與 hash，解壓至 `%USERPROFILE%/DrillPaperTests/安全矩陣 含空白/<session>`。獨立 LOCALAPPDATA，不操作原持續桌布、Explorer、系統網路、防毒或 URI handler 註冊。
- 沿用 WebView2／Win32 原生整合 seam：接收端正向控制、真實 API／協定回覆、宿主世代與偏好副作用；只有重現票內產品缺陷才保留 Red 並最小修正。既有保護不虛構 Red。
- EXE 由 Node 子程序直接啟動，保存父子 PID、開始／退出時間與錯誤；PowerShell 只協調測試。記錄每次可見的防毒產品、規則、時間與受影響項目；受影響項目 BLOCKED，不改防毒設定。
- 同一版本驗證 Preview 管理／獨立重啟、HTTP／HTTPS off→on→off、雙目標來源／儲存、快速切換／停用／重建、舊世代通知及 HTML 管理命令拒絕。原生通知注入與真正舊 controller 訊息分開聲明。
- 補 camera／microphone 的 getUserMedia，保留通知／定位實際呼叫；權限 denied 查詢不代替呼叫。URI 外部 handler 沒有可隔離接收端時 NOT RUN，不能從 fetch 拒絕推論。
- 補 HTTP／TLS preconnect、prefetch、DNS-prefetch 的接收端／NetLog 觀測；NetLog 是瀏覽器觀測，不是全介面封包擷取。無法歸因的瀏覽器連線另列，不當成主題流量或遙測。
- 僅執行相關測試。完整套件留 09；人工、其他 OS／Runtime、TURN-UDP／TLS、其他介面／proxy、瀏覽器／OS escape 無環境者 NOT RUN，附接續操作。

## 執行前版本矩陣

| Windows／Runtime／模式 | 項目 | 初始結果 |
| --- | --- | --- |
| 本機 Windows 11／實際 Evergreen 版本待記錄／Preview | 管理、獨立重啟、HTTP／HTTPS off→on→off、安全 API、儲存、導覽 | NOT RUN：待執行 |
| 同本機／桌布雙目標 | 全域開關、來源／儲存、世代、快速切換／停用／重建 | NOT RUN：待執行 |
| 同本機／隔離 profile NetLog | DNS／TLS preconnect／推測與背景流量 | NOT RUN：待執行 |
| Windows 10、其他 Windows 11／其他 Runtime | 上述全部 | NOT RUN：沒有對應環境；不宣稱支援安全邊界 |
| 本機其他介面／proxy、TURN-UDP／TLS、OS／瀏覽器 escape | 外傳與隔離 | NOT RUN：缺受控環境／接收端 |

所有未測／失敗安全邊界持續影響 03 試用限制、08 文件／包內容及 09 gate；本票報告完成不解除 RC gate，不宣稱完整沙箱。

## 停止：無遙測決策與瀏覽器實際背景上傳衝突

2026-10-30，使用者指示「決策與程式現況衝突或前提不成立時：停止、不 commit、回報衝突點」。本票維持 in-progress／待決策，未 commit、未 push，沒有修改產品程式或停用 SmartScreen。後續實作、審查與最終重驗停止。

`DesktopMonitor_Codex_Handoff.md` §7.7 要求「無遙測、無背景上傳」，§1.2 要求預設無遙測；現行 `docs/theme-security.md` 亦寫產品沒有遙測。必須先釐清這項要求是否涵蓋隨 app 啟動的 WebView2 背景流量，不能自行將要求縮限為自有 C++ 程式沒有 telemetry。

隔離 WebView2 NetLog 證實：

| 時間（台灣 +08:00） | 當時條件 | 實際送出／回應 |
| --- | --- | --- |
| 09:38:57.157 | 初始內建 Minimal；allowNetwork=false；尚未選擇安全探針主題 | POST `https://telem-edge.smartscreen.microsoft.com/api/browser/edge/telemetry/3`，HTTP/2 SEND_DATA **4510 bytes**，回應 **200** |
| 09:39:36.485 | off→on→off 的最後關閉階段 | 同端點 POST，HTTP/2 SEND_DATA **4619 bytes**，回應 **200** |

[去除授權標頭的精確證據](telemetry-evidence.json) 列出 NetLog 檔名、HTTP/2 source／stream、method／authority／path／content-length、送出 bytes 與回應狀態。這些不是只看 URL_REQUEST_START_JOB 的嘗試紀錄：以同一 source ID 與 stream ID 關聯 `HTTP2_SESSION_SEND_HEADERS`、`HTTP2_SESSION_SEND_DATA`、`HTTP2_SESSION_RECV_HEADERS`。原始 NetLog 的本機路徑／SHA-256 見 [停止時環境](stop-environment.json)，原檔留在忽略的 artifacts，不提交可能包含私人資訊的原始日誌。

判定：**決策衝突／BLOCKED**。已區分瀏覽器自身背景流量與主題請求；不能據此斷言上傳內容包含系統指標，也不能聲稱 allowNetwork=false 代表整個 WebView2 程序零外連。未修改企業防毒、瀏覽器全域設定或保護功能來取得 PASS。

## 實際環境與已執行結果

- Windows 11 Pro 25H2 **26200.8737**，x64、一般使用者；WebView2 **156.0.4314.50**，由隔離 profile 的 `EBWebView/Last Version` 核對。SDK 1.0.2478.35。兩個 1920×1080 桌面區域，DPI 144／96。
- 來源 HEAD `1c62cc41e54a642f5ae5ed0d723e9b0893cef542`；產品為 03 既有乾淨來源 `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53`，本票沒有改 src/include。trial.4 ZIP SHA-256 `C3ECF566EAB58D4A015D44D749E60F1E6872F5830F31AEB0F3B303ECC40C3287`；EXE `B0FF9A734713AF939C6444092B6D008DEDEF9480A17932D1B4B9D92C0FE71781`。
- 解壓至 `C:/Users/James/DrillPaperTests/安全矩陣 含空白/20261030-093658`，逐檔核對原 manifest；測試另拷貝 `DrillPaperParentFixture.exe` 到同目錄，僅供整合 fixture，不屬原 ZIP 內容。LOCALAPPDATA 每輪使用獨立 artifacts session，產品 EXE 由 Node 直接 spawn，launcher JSON 留下真實父子 PID／時間／退出碼。
- Trend Micro Apex One，PccNTMon file version **14.0.0.21008**。本輪沒有觀察到新增攔截，CLI／GUI 均可啟動；可讀 `AEGIS_BM.log` 最後修改仍為 09:22:30，早於本輪。此檔舊規則 `NON_POLICY_JUST_MEERKAT` 是 03 的 Temp／PowerShell 事件，不算本輪攔截；不能由單一日誌推論所有防毒觀測完整。

| 本次有界矩陣（只適用上述 hash／OS／Runtime） | 結果／證據與限制 |
| --- | --- |
| 原有安全基線，Node 啟動／非 Temp EXE | PASS：[baseline.log](baseline.log)；session `security-9d60009158ad44e7a56728d10d8aa784` |
| Preview 管理與獨立重啟；HTTP／HTTPS off→on→off；首次提示／取消／保存 | PASS：[security-result.json](security-result.json)、[expanded.log](expanded.log)；HTTPS 為 example.com no-cors，非獨立 HTTPS 內容接收端 |
| HTTP preconnect／TLS preconnect | PASS：原生接收端控制各一筆；關閉零新增，開啟收到瀏覽器 TLS ClientHello。原始 `tls-preconnect.jsonl` 留 session；不是所有 TLS 或網路介面聲明 |
| DNS-prefetch／prefetch | PARTIAL：[netlog-summary.json](netlog-summary.json)。指定唯一 `drillpaper-536af503b0454dc28a44a7ad6a50396b.example.com` 的 HOST_RESOLVER／DNS_TRANSACTION 只在 apply-True 出現；有開啟正向觀測，關閉無指定主機事件。prefetch 已嘗試但未建立獨立成功判準；沒有受控權威 DNS／全介面封包接收端，不宣稱完整 DNS／推測連線封鎖 |
| 瀏覽器背景流量 | BLOCKED：Minimal、網路關閉仍有上述 SmartScreen telemetry 上傳；另觀察 WPAD、SmartScreen navigation／download／settings 等端點。無法歸因的 TCP IP 不任意當作主題或遙測 |
| camera／microphone、定位、通知 | PASS（拒絕行為）：真實 getUserMedia 分別得到 NotAllowedError，定位錯誤碼 1、Notification.requestPermission=denied；snapshot／訂閱仍完成。沒有開啟設備作正向控制，也不將 denied 的來源歸因為單一宿主事件 |
| HTML 管理命令 | PASS：settings.apply、theme.remove、app.exit 各收到對應 requestId 的 unsupported-message，之後 snapshot 正向控制仍可用；不代表所有可想像命令 |
| 框架／彈窗／下載、worker、STUN／TURN-TCP／WS／WSS、導覽後存活／可信回復 | PASS（既有腳本所列範圍）：loopback 接收端／控制、DownloadBlocked、二次訂閱及非 fallback 主題確認。TURN-UDP／TLS 未涵蓋 |
| 來源／Cookie／localStorage／sessionStorage／IndexedDB／Cache Storage | PASS：當前來源讀寫及每次載入隔離；雙目標另驗 localStorage／Cookie 與獨立 origin，不推論雙目標所有儲存 API |
| 雙目標、20 次快速切換、單目標停用、父 fixture crash 重建、兩種模式往返 | PASS：[multi-monitor-result.json](multi-monitor-result.json)、[multi-monitor.log](multi-monitor.log)。舊／跨宿主原生通知不能更新新世代／偏好，且新頁面指標持續前進；有效當前故障通知為正向控制 |
| 真正舊 controller 的延遲 JS／來源回覆競態 | PARTIAL：舊主題每 200ms 排程 unsubscribe 與管理命令，切換後新頁面仍收到指標；未證明每種停用／重建／退出時點確實有舊 COM 訊息送達，不以原生通知注入代替所有 controller race |
| 正式退出及已觀察子程序清理 | PASS：各腳本退出 0 並等待已觀察 WebView2 子程序；停止時只剩原持續桌布 83428，其路徑／建立時間未變。未關閉／替換、不重啟 Explorer |
| 相關 CTest／建置／語法 | PASS：CTest **15/15**；相關 targets 建置成功；4 個 JS 檔 node --check 與 3 個 PS parser 檢查通過。CTest 執行在相關 targets 再建置前，停止規則觸發後未再跑新建置的 binary，不能說完成最終回歸 |
| URI 外部 handler、其他設備／權限、TURN-UDP／TLS、其他介面／proxy、瀏覽器／OS escape | NOT RUN：沒有隔離正向 handler／設備與接收環境；fetch 的 file/data/ftp 拒絕不代表外部 handler 封鎖 |
| Windows 10、其他 Windows 11／Runtime、真正 Explorer／人工畫面 | NOT RUN：沒有對應環境或本輪授權的人工操作；只聲明已測組合 |
| 完整套件、CI、code-review、commit-msg／commit／push | NOT RUN：完整套件留 09；其餘因已確認決策衝突而停止 |

## 命令與證據重現

以下命令在本輪先後執行；初始安全基線在新增 API／TLS 探針前執行，擴充與雙目標命令在新增探針後執行。測試腳本仍是未提交草稿；NetLog 彙整器首版誤將縮排首筆當成 JSONL，每行解析失敗後改為兼容原始證據，未改寫原始檔；初始 phase 寫入亦改為壓縮格式，但停止後未再跑完整安全腳本。

```powershell
$application = 'C:\Users\James\DrillPaperTests\安全矩陣 含空白\20261030-093658\DrillPaper.exe'
& scripts/test-webview2-security.ps1 -ApplicationPath $application
& scripts/test-multi-monitor.ps1 -ApplicationPath $application
node scripts/summarize-security-netlog.mjs artifacts/acceptance/security-856756a114904dcd92b3f083f43ba64e
ctest --test-dir build/windows-msvc-release -C Release -R '^Protocol v1 |^Settings |^Invalid settings|^Monitor target|^Invalid monitor|^Monitor selection|^Clone targets|^DrillPaperThemeTests$' --output-on-failure
cmake --build --preset windows-msvc-release --target DrillPaperTests DrillPaperSettingsTests DrillPaperThemeTests --parallel 8
```

[相關 CTest 原始輸出](related-ctest.log)、[建置輸出](related-build.log)。原始安全 session 為 `artifacts/acceptance/security-856756a114904dcd92b3f083f43ba64e`；雙目標 session 為 `artifacts/acceptance/multi-monitor-b45ff7aa85024df99c2939a0b13c1701`。相關命令沒有執行完整 scripts/test.ps1。

## 03／08／09 影響與下一步

- 03：trial.4 與產品 hash 不變，新增已知限制是主題網路開關不涵蓋 WebView2 自身 SmartScreen 背景上傳；不能宣稱整個 app 離線零外連。既有智慧休眠缺陷仍留 05，未被本票修復。
- 08：在無遙測要求釐清與實測完成前，不得只加一句文件即視為解除；若需產品修正，必須另按確認政策、失敗行為測試、最小修正及重包流程處理，不能默默停用瀏覽器安全防護。
- 09：本票 **BLOCKED／未完成**，保留上述背景流量衝突及 PARTIAL／NOT RUN。不得由局部安全 PASS、CTest 綠燈或票據狀態放行 RC。
- 待使用者釐清無遙測對瀏覽器背景流量的適用範圍後才繼續。若保留嚴格要求，需確認可接受的實作政策與 SmartScreen 保護取捨；本輪不擅自決定。
- 接續人工／外部環境清單：在隔離測試帳號設置具有可觀察接收端與正向控制的 URI handler，測 top-level／frame／popup scheme；以受控 DNS 與 TURN-UDP／TLS 接收端覆蓋其他介面／proxy；對舊 controller 在停用／重建／退出時間點保留送達證據；逐 Windows／Runtime 組合重驗。這些結果目前均不得標 PASS。
