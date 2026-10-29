# 開發狀態

## 2026-10-29 RC 02 — 固定 800×600 設定視窗

- Date／branch／base：2026-10-29，從目前 HEAD `0c97d4fdda3881a3d11bc7f93d7fc12829749f56` 建立 `feature/rc-02-fixed-settings-window`，起始工作樹乾淨。前置 01 implemented；本票需求與 seam 先記於 FIXED_SETTINGS_WINDOW.md，未發現決策與現況衝突。
- Scope／files：platform/windows ManagementShell 固定 800×600 DIP、跨 DPI 精確換算、最大化／尺寸限制、主題／螢幕兩欄、長錯誤與完整識別捲動、無名稱路徑縮短、鍵盤導覽；新增 Windows 原生管理測試與 CMake target，更新票據、README／需求／交接與驗收報告。不改 composition 保存、主題或網路政策。
- TDD PASS：尺寸、最大化、長訊息、Tab 吞鍵與大小寫裝置標籤均先失敗後修正；原生管理最終 5 cases／776 assertions（含畫面證據）。Standards／Spec 平行審查及複查未解決項各 0；修正擷取測試失敗路徑的 RAII 清理。工具編譯／擷取及 oracle 中間失敗另記報告，不計 PASS。
- Build／typecheck／相關測試 PASS：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperManagementIntegrationTests DrillPaperSettingsTests DrillPaperTests --parallel 8`；相關 CTest `-R '^Management |Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause'` 13/13。命令與原始 red／green／build log 見 [報告](acceptance/2026-10-29/fixed-settings/REPORT.md)。未跑完整套件。
- Windows 原生／畫面：Windows 11 Pro 25H2 26200.8737、兩個 1920×1080、DPI 144／96；實測用戶區 1200×900／800×600，控制項在範圍內且不重疊。100%／150% fixture WM_PRINT（含長文字）及真實 app 150% PrintWindow PNG 已檢視，主要操作可見。WM_PRINT 非客戶區外觀不是實際 DWM 標題列或人工點擊證據。
- Management／monitor／security PASS：既有 `test-management-shell.ps1 -Desktop`、`test-multi-monitor.ps1`、`test-webview2-security.ps1`；包含唯一視窗重開、關閉隱藏、保存／取消／重啟、目標單／雙選、模式／暫停、HTTP off→on→off、首次提示與腳本所列安全邊界、已觀察子程序退出。最終 app SHA-256 `68CC8BDFDA3593046777D412298D6E1B7F5B92A77F6B93B161E74396F763CBD0`；本輪實際 Runtime **156.0.4314.50**（登錄及隔離 profile 核對），不沿用 01 的 155 結果，不宣稱完整沙箱。
- NOT RUN／blockers：真實鍵盤／系統匣點擊／匯入移除確認、小工作區實機、其他 DPI／Windows；Computer Use 原生管道 os error 2，按已確認決策附人工清單留後續，不中斷本票。真正 Explorer／實體拔插／電源／硬體／長測為後票；完整套件留 09，CI／打包 NOT RUN。本票不產 ZIP、不合併 main、不解除 RC gate。原持續桌布 83428 固定副本未關閉或替換，未重啟 Explorer。
- Ticket／next：02 設 implemented，表示程式與可自動驗證範圍完成，人工矩陣保留；03 首次試用打包尚未開始。
- Commit：`feat(settings): 新增固定尺寸與 DPI 適配的設定視窗`；依 commit-msg skill 檢視實際差異產生，本票一次 commit 並 push `origin/feature/rc-02-fixed-settings-window`。

## 2026-10-29 RC 01 — 多螢幕套用管理

- Date／branch／base：2026-10-29，從 HEAD `7806266` 建立 `feature/rc-01-multi-monitor`；工作樹原乾淨。票 `.scratch/rc-delivery/issues/01-multi-monitor.md` 設為 implemented，代表程式及可自動執行驗證完成，人工矩陣未宣稱通過。
- Scope：穩定 monitorDevicePath、source clone 群組、實體幾何／逐屏 DPI；schema 2 原子保存與主屏遷移；目標草稿／取消／未連接清單；部分斷線不補位、全斷線明確提示暫用主屏不改偏好；每區域獨立 HWND／controller／重試／逾時，Preview 唯一；全域主題／網路／快照／暫停／電源／退出廣播，世代與來源隔離。調查／測試 seam／人工清單先記錄於 MULTI_MONITOR.md，與已確認決策無衝突，沒有新 ADR 或逐屏權限。
- Files：app composition／SettingsStore、platform/windows monitor_info／desktop_host／management_shell、runtime monitor_targets、WebView2 載入／DPI／訊息隔離、CMake、相關 unit／原生 integration／PowerShell probes，及 ticket／需求／README／架構／交接與驗收文件。
- Build／typecheck PASS：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperSettingsTests DrillPaperMonitorIntegrationTests DrillPaperWindowsHostIntegrationTests --parallel 8`。精確相關 CTest `-R` 命令與 log 見 [報告](acceptance/2026-10-29/multi-monitor/REPORT.md)，25/25 PASS。Settings 5 cases／29 assertions、目標解析 2 cases／13 assertions；保存遺失、解析、clone、設定容量／空目標、主題重選復原均有 Red→Green，未捏造既有保護的 Red。
- Windows 原生 PASS：Windows 11 Pro 25H2 build 26200.8737、WebView2 155.0.4283.62；兩屏 `(0,0)–(1920,1080)` DPI 144 與 `(1920,0)–(3840,1080)` DPI 96。單／雙選、取消保存、原設定重啟、獨立 HWND／完整矩形、Minimal／Dashboard 握手、JS viewport×DPR 完整覆蓋、暫停／模式、19 個已觀察子程序退出、單目標故障／跨世代拒絕及 HTTP off→on→off 與來源隔離。各 HWND／附掛／世代／截圖見報告。
- Recovery PASS（受控）：雙屏跨程序 fixture 父視窗 crash 後全部重建；`test-desktop-host.ps1 -DestroyParent -ParentExit crash -NoRecoveryNotification -RecoveryCycles 2` 單屏無通知復原；`test-renderer-recovery.ps1 -Crashes 4 -ReselectBeforeFinal` 選題額度重設與新握手。不是 Explorer 重啟或人工畫面證據。
- Management／security PASS：`test-management-shell.ps1 -Desktop` 與 `test-webview2-security.ps1` 完成相關回歸；150% 管理 PNG 已檢視，底部按鈕可見。既有 HTTP／HTTPS／來源儲存／worker／導覽復原／WebRTC／preconnect 等僅聲明腳本所列範圍，不宣稱完整沙箱。受測 EXE hash `CE7223F45B2EE7BE94E4C1EDD0F71BF107D2290C4ABA9A7E30F69D5320028774`，最終結果 JSON hash 一致。
- Review：依 code-review skill 做 Standards／Spec 平行審查，修正管理視窗過高、重選主題額度、設定讀寫容量不一致及錯誤轉碼等；兩軸複查未解決 finding 0。開發中另校正測試的智慧休眠前提、宿主建立等待及主題顯示名稱 oracle，失敗不算 PASS。
- NOT RUN／blockers：真正新版 Explorer、人工桌面畫面與完整圖示／工作列／系統匣操作、實體拔插／接回、主屏變更、負座標／不同解析度／clone／其他 DPI／Windows；依使用者指示附人工清單後留待後續，未重啟 Explorer。真實電源／NVIDIA／乾淨環境／長時間效能及完整安全矩陣另票處理。完整測試套件留 09 收尾，CI／打包 NOT RUN；本票不產 ZIP、不合併 main、不解除 RC gate。
- Next：02 最終固定 800×600 設定版面；本票暫用 600×600，超長裝置路徑列截斷記入本票 Comments 供 02 處理。原持續桌布 83428 固定 a241856 副本未關閉／替換，測試程序已退出。
- Commit：`feat(monitors): 新增多螢幕目標管理與獨立桌布宿主`；本票完成後依 commit-msg skill 產生，僅 commit 一次並 push `origin/feature/rc-01-multi-monitor`。

## 2026-10-29 建立剩餘工作 9 張 tickets — 先試用打包再補驗收

- Scope：使用者指示「建立ticket」，依已確認順序 1 → 2 → 7A → 3～6 → 7B → 8 建立 .scratch/rc-delivery/spec.md 與 issues/01～09。每票列出範圍、前置依賴、驗收與 Comments，初始 open；保留多螢幕既有 spec 並連結唯一實作票。
- 明確化：設定用戶區固定 800×600 邏輯尺寸；7A 為完成多螢幕／設定後的首次試用 ZIP，7B 沿用流程納入修正並驗乾淨一般使用者交付，09 才判定 RC。打包與 CI 綠燈不代替安全／實機 gate。
- 基準：main b4616ec，工作樹原乾淨；新建 feature/rc-delivery-plan。已完成的舊功能分支先前已清理，不因多螢幕規劃誤稱有未完成程式分支；本輪不合併 main、不發行。
- PASS：核對 issue-tracker／triage 慣例、既有 spec／架構／交接與驗收缺口；git diff --check 通過。9 票數量／open 狀態／必要欄位及前置票順序均有效，20 個本機 Markdown 連結存在；無產品變更。
- NOT RUN：產品／GUI／多螢幕／安全／硬體／打包與完整測試（本輪僅文件與工作規格，無產品變更）；未啟動或操作桌布／Explorer／顯示配置。新票未完成，RC gate 保留。
- Commit：`docs(plan): 建立功能打包與驗收九張工作票`，依 commit-msg skill 檢視實際差異產生後立即 commit＋push origin feature/rc-delivery-plan。

## 2026-10-29 完成分支整合至 main — 使用者授權合併

- main 整合與交接提交 `0f548ae` 已推送 origin/main；實際 [CI 40848448010](https://github.com/act70255/DrillPaper/actions/runs/40848448010) PASS：乾淨 Windows configure／build、CTest 33/33（1.96 秒）、SDK 18/18、SDK 還原／封裝與 artifact，RC job skipped。證據為 acceptance/2026-10-29/main-integration/ci.json／log，完整原始 log 在 artifacts/acceptance/main-integration-ci.log。最後僅保存結果的文件提交不改產品，使用 commit-msg skill 產生 `docs(ci): 保存 main 分支整合驗證結果` 後推送。
- 使用者最新指示「把完成的分支合併到Main」，取代先前本輪不合併 main 的限制。先 fetch origin 並核對乾淨工作樹；main／origin/main 原為 5697bf7，feature/tray-management 為 bec20d4，落後 33 個提交且無分歧。
- 已以 `git switch main`、`git merge --ff-only origin/main`、`git merge --ff-only feature/tray-management` 完成本機快轉整合，保留原提交歷史。16 個現有功能／修正分支及所有遠端分支均為該來源分支的祖先，`git branch --no-merged main` 為空；分支與其他 worktree 保留。
- 產品程式與既有 62f01ab 實測版本相同；此前 6672610 的 CI 40840814142 通過 CTest 33/33、SDK 18/18。多螢幕只有 planned spec，完整安全／相容性等 NOT RUN 與 RC gate 保留，合併不代表產品已可發行。
- 本輪本機產品／GUI 測試 NOT RUN（純快轉整合及交接文件，沒有衝突或程式改動）；已核對原持續桌布 83428 固定副本路徑，未操作／替換。推送 main 後另確認主分支 CI，不由前版結果代替。
- 文件 Commit：`docs(status): 記錄完成分支整合至 main`，依 commit-msg skill 產生後 commit＋push origin main。

## 2026-10-29 多螢幕需求收斂 — 勾選目標、每屏完整桌布

- 使用者指定不做跨螢幕拼接，改為選擇哪些螢幕套用，每個目標各顯示一份完整桌布。新增 .scratch/multi-monitor/spec.md（planned），沿用同一全域主題，未選螢幕保留 Windows 桌布；保存目標與基本螢幕／Explorer 生命週期另於實作前具體化。
- 同步剩餘工作、總交接、相容性矩陣與原管理 spec，區分「選擇目標螢幕」和仍不納入的「逐螢幕不同主題」。不將需求整理寫成已實作。
- 驗證：文件差異與 `git diff --check`。產品／GUI／多螢幕測試 NOT RUN（僅整理需求，未改程式或顯示配置）；原持續桌布未操作，不合併 main。
- Commit：`docs(plan): 定義目標螢幕各自顯示完整桌布`，依 commit-msg skill 產生後 commit＋push。

## 2026-10-29 剩餘工作分類 — 多螢幕列為必要完整性功能

- 使用者明確要求「多螢幕情境也需要先列為必要的完整性功能」。新增 REMAINING_WORK.md，將必要多螢幕與 app 交付收尾、既有驗證缺口、補充功能分開；同步 FINAL_HANDOFF、相容性矩陣與管理 spec 的範圍界線。
- 多螢幕須調查／補齊實作與對應驗收，不只列為相容性待測，也不列為選配。呈現方式與逐螢幕操作細節於實作前具體化；本次沒有新增逐螢幕不同主題等未定義功能。
- 驗證：文件差異核對、`git diff --check`。產品／GUI／多螢幕測試 NOT RUN（本次僅調整需求分類，未改程式或顯示配置）。不操作原持續桌布，不合併 main，RC gate 保留。
- Commit：`docs(plan): 將多螢幕列為必要完整性功能`，依 commit-msg skill 產生後 commit＋push feature/tray-management。

## 2026-10-29 本輪驗收結案 — 最後新增測試 CI 通過

- 驗收／測試提交 `6672610` 的 [CI 40840814142](https://github.com/act70255/DrillPaper/actions/runs/40840814142) 完成且 PASS：Windows configure／build、CTest 33/33（1.95 秒）、SDK 18/18、固定 SDK bootstrap／封裝及 artifact。release-candidate job 預期 skipped，未發行、未合併 main。
- metadata／節錄：management/remaining-final-ci.json／log；完整原始 log：artifacts/acceptance/6672610-ci.log。產品程式仍為 62f01ab（hash 8AACD0…），後續測試與文件提交未改產品，所有原生／人工 hash 界線見 REMAINING.md。
- 本輪三項修正、指定擴充安全、真正新版 Explorer 人工結果與完整回歸均已各階段提交推送。完整 DPI／DNS／其他安全與 MVP 未驗矩陣照列 NOT RUN，A12／RC gate 保留，不宣稱完整沙箱。
- 收尾只留下原持續桌布 PID 83428，固定 a241856 程序路徑未變；測試 app 已正常退出。Nowledge Mem 無法連線，ADR 0002–0004 與驗收文件為本輪可接續紀錄。
- 本次僅保存 CI 結果及更新交接，產品測試 NOT RUN（沒有產品改動；已核對實際 CI）。Commit：`docs(acceptance): 記錄剩餘驗收 CI 通過`，依 commit-msg skill 產生後 commit＋push。

## 2026-10-29 剩餘驗收收尾 — 新版 Explorer 人工通過

- 使用者確認「新版畫面恢復且持續更新，圖示／工作列可用」。受測產品 62f01ab，EXE hash `8AACD05B50BEDF89E2F191B14986E3A1AB380A60B075C0CA5097DDAE539176D1`，Windows 11 Pro 25H2 build 26200.8737、Dashboard mock／no-smart-sleep。隔離資產僅 h1 增加「新版管理驗收 62f01ab」識別，hash 另存，沒有修改原桌布。
- 真正 Explorer：Shell 98068→93396，同一受測 app PID 85932，HWND 1376352→1054746，DesktopEpoch 2→3、ReadyEpoch 2→4、新 metrics 1493736796、TrayRegistered=1。人工結果補足畫面與圖示／工作列，不外推 Alt+Tab／虛擬桌面或其他 Windows。腳本原始 visual=NOT RUN 是自動腳本的範圍，人工結論另存 remaining-user-confirmation.json。
- PASS：最終管理生命週期／設定／重啟及已觀察子程序清理；新增 VisualObservationSeconds 供真正重啟後保留人工觀察時間，並以父子建立時間及預先持有 handle 排除 PID 重用。150% 管理 PNG 已檢視，控制項／文字未裁切；先前人工鍵盤／取消／唯一視窗的原始回報與 hash 一併保存。
- PASS：62f01ab 完整 Release build、`test.ps1 -Configuration Release`，CTest 33/33（26.08 秒）、SDK 18/18 及封裝／環境／採樣器／負面 oracle。原生受控 runtime 1 次＋50 次快速往返、custom-entry renderer crash 3 次、主題切換 100 次＋已安裝主題握手皆通過；不是新一輪真實鎖定／睡眠、像素切換或洩漏結論。
- PASS：62f01ab [CI 40839289477](https://github.com/act70255/DrillPaper/actions/runs/40839289477)，CTest 33/33、SDK 18/18、SDK 還原與封裝。metadata／節錄另存 62f01ab-ci.json／log；完整原始 log 位於 artifacts/acceptance/remaining-final-ci.log。
- 追加 preconnect 負面回歸：舊 F0238D… 在網路預設關閉仍多一筆 loopback TCP；現有 Connection-Allowlist 的同測試通過，開啟時另有瀏覽器正向控制、再次關閉時無新增 TCP。未再更改產品。安全 session security-afe8952ca34242c28adce0b05c1e2c0c，含既有 HTTP／HTTPS／WS／WSS／STUN／TURN-TCP、儲存／worker／導覽回復及兩種重啟，詳見 remaining-security-result.json。
- NOT RUN：完整 DPI（使用者回報固定視窗無法拖曳縮放，沒有做 Windows DPI 更動）、全部 DNS／推測連線／瀏覽器背景流量、TURN-UDP／TLS、其他 Runtime／權限設備 API／scheme／舊頁面競態，以及其他 MVP 硬體／電源／相容性與乾淨安裝 gate。A12 與 RC gate 保留，不宣稱完整沙箱。
- 原持續桌布 83428 路徑仍為固定 a241856 副本；真正重啟後 ReadyEpoch=4、parent=93396、兩秒 metrics 1493809578→1493811593。未關閉／替換，舊 A04 PASS 保留；新管理程序正常退出。證據、命令與限制見 REMAINING.md。
- Commit：`test(acceptance): 補齊新版管理與安全回歸證據`；依 commit-msg skill 產生後立即 commit＋push。新增測試檔的 CI 會在推送後另觸發，不把上述產品版本 CI 寫成尚未執行的提交。

## 2026-10-29 安全續驗 — 失敗導覽回復與擴充矩陣

- Scope／Red→Green：worker 遭拒後外部頂層導覽雖無流量，WebView2 卻提交 chrome-error 空白頁。獨立 security-z-navigation 先訂閱、導覽、再次訂閱，舊 DF658C… 固定副本精確 FAIL。改監聽失敗 NavigationCompleted 與實際 Source，以載入世代通知 app 切回可信 Minimal，不寫回保存偏好；Minimal 自身失敗則停止 renderer，保留管理與友善錯誤，避免迴圈。詳見 ADR 0004。
- PASS：Release app build；同一獨立導覽案例於網路 off→on→off 通過，原頁面繼續或可信 Minimal 完成新訂閱，navigate endpoint 無收件。hash `8AACD05B50BEDF89E2F191B14986E3A1AB380A60B075C0CA5097DDAE539176D1`，session security-ddad2d5848c94edfb672e3d87d1ff809。
- PASS（相同實機腳本）：IndexedDB／Cache Storage 各有當前來源讀寫正向控制且後續載入不重用；host-only Cookie／父網域 Cookie／localStorage／sessionStorage；Dedicated／Shared／ServiceWorker 明確拒絕；camera／microphone 查詢為 denied。STUN UDP 與 TURN-TCP／WSS 的接收端僅原生控制各一筆，無主題收件。HTTP／HTTPS、其他既有負面、管理／獨立重啟仍通過。不把權限狀態查詢推論為所有設備 API 已測。
- 診斷：先後排除只要求例外、頂層 await／worker 清理等測試假設；NavigationStarting 後額外 Stop 無效，已撤回。隔離 CDP 實際讀到 chrome-error Frame（暫態 Stop 嘗試 hash FB7418…）；未在原桌布開啟偵錯。原始過程在 artifacts/acceptance/expanded-*，navigation-error-frame.jsonl 與精確 Red／Green／封包及請求證據已保存。
- 測試判斷另核對實際探針主題，防止 Minimal fallback 冒充資源案例成功；資源與導覽分為兩個真實匯入主題，導覽允許原頁面存活或立即安全回復。
- NOT RUN：完整 DNS／preconnect／推測連線、TURN-UDP／TLS／其他 Runtime、舊頁面訊息競態、完整權限／scheme 與整體 RC。管理／Explorer、完整回歸與本版 CI 接續執行；d3a24dc 的 CI 40837047952 已成功，但不代替本次修正。原持續桌布 83428 路徑未變。
- Commit：`fix(web): 復原遭政策拒絕的頂層導覽`；依 commit-msg skill 產生後立即 commit＋push。

## 2026-10-29 剩餘安全驗收 — WebRTC/STUN 缺口修正

- Red→Green：新增真實 RTCPeerConnection data channel／ICE，舊 F0238D… 固定副本在網路關閉時收到三筆 STUN UDP（20 bytes、magic cookie 符合），精確失敗於「預設網路關閉時 WebRTC 仍傳送 UDP／STUN 封包」。不需音訊／視訊，也不由權限拒絕推論網路封鎖。
- 最小實作：所有宿主資產回應加 Connection-Allowlist；只允許自身來源，開關開啟才再允許 HTTP／HTTPS 任意網域與 port，固定 webrtc=block。保留 CSP 與原生導覽／資源／權限等限制。決策見 ADR 0003，支援範圍只聲明實測 Runtime 155.0.4283.62。
- PASS：Release app build；安全腳本 off→on→off、兩種重啟、HTTP／HTTPS 等原有負面與來源儲存隔離。session security-a51c31974b1046a0a4f0114a5c78db5b，hash `DF658C57DA4EFAE79CAF7F6CFB6A4E88EA97A1B9AAD2D3CE356799994D0FC7B1`。UDP 接收端有一筆 UdpClient 正向控制、主題封包 0；舊版三筆為瀏覽器正向證據。webrtc-{red,green}-packets.jsonl／結果與日誌已保存。
- 測試校正：初版錯把「一定拋 SecurityError」當作政策判定，曾在無 UDP 收件時仍失敗；實際允許建立物件後禁止 ICE。改由接收端收件判定，對舊／新產品重跑同一案例取得 Red→Green；先前誤判日誌保留，不稱每輪皆首次通過。
- NOT RUN：TURN／完整 DNS／推測連線、其他 Runtime 與完整安全矩陣；後續擴充。完整回歸與 CI 留待本輪實作收尾。原桌布 83428 未關閉或替換，A12／RC gate 保留。
- Commit：`fix(security): 阻止主題 WebRTC 外連`；依 commit-msg skill 產生後立即 commit＋push feature/tray-management。

## 2026-10-29 剩餘安全驗收 — 隔離父網域 Cookie

- Scope：承接使用者要求繼續剩餘工作，保持 feature/tray-management、不合併 main；續驗計畫見 management/REMAINING.md。
- Red→Green：新增真實 localStorage／sessionStorage／Cookie 載入隔離，舊來源在 allowNetwork=true 第二次載入 FAIL；共同 drillpaper.local 父網域 Cookie 會跨 GUID 子網域保留。改用每次載入不同可註冊網域 `drillpaper-theme-<GUID>.invalid`，保留來源判斷同時拒絕舊命名空間及非目前 .invalid。決策見 ADR 0002。
- PASS：Release app build；相同 `test-webview2-security.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe`，off→on→off、管理／獨立重啟與既有網路負面通過。session security-59a3f05723ca4f3abcc2080c1f1255a5，hash `8F3DB185176D5A2BCE9DDF445D63D8016DC281B260510AAF2C2A7B5D48BA4CAB`；storage-red.log／storage-result.json／storage-green.log 保存於 management。
- 人工：使用者對獨立固定副本 PID 90952（前版 F0238D…）回報「操作皆正常 但無法縮放因此未測試縮放」，對應 Tab／Shift+Tab、空白鍵、取消草稿、重複開啟唯一視窗；DPI 仍 NOT RUN。原持續桌布 83428 路徑未變，未關閉／替換。
- NOT RUN：IndexedDB／Cache Storage／舊頁面競態、WebRTC／推測連線及其他未覆蓋安全矩陣，後續補驗。完整回歸／本版 CI 留待本輪實作收尾，A12 與 RC gate 保留。
- Commit：`fix(security): 隔離主題父網域 Cookie`；依 commit-msg skill 產生後立即 commit＋push。

## 2026-10-29 管理三階段實作收尾 — 最終 CI 通過

- 最終產品程式提交 `63e86ff`，分支 feature/tray-management。實際 [CI 40832496506](https://github.com/act70255/DrillPaper/actions/runs/40832496506) PASS：乾淨 Windows runner configure／build、CTest 33/33（3.10 秒）、SDK 18/18、固定 SDK 還原／bootstrap 邊界及主題封裝 artifact。RC job 預期 skipped，沒有發行。
- 證據：management/final-ci.json、final-ci.log；完整原始 log 位於 artifacts/acceptance/63e86ff-ci.log。前版 bcb6d2c 的成功與本機／原生整合證據各自保留，不混用 hash。
- 第三階段票與 spec 設為 implemented，表示程式與所列驗證範圍完成；不表示整體 MVP／RC 或所有人工矩陣通過。使用者已確認系統匣可開、匯入正常、移除測試完成，隔離目錄結果吻合；原生重複開啟 5 次／真正 Explorer 程序重啟及 junction 負面亦已有各自證據。
- NOT RUN：新版 Explorer 像素人工結論、完整鍵盤／DPI、全部權限／scheme／WebRTC／DNS／跨主題 storage 等矩陣。原因及安全限制見 FOLLOWUP.md／theme-security.md；A12 與 RC gate 保留，沒有宣稱完整沙箱。
- 收尾核對：只有持續桌布 PID 83428，路徑仍為原固定 a241856 副本。測試與人工程序均已收尾，沒有關閉或替換原桌布，未合併 main。
- 本輪僅更新文件／票項／CI 證據，產品測試 NOT RUN（本輪無程式變更；已核對 63e86ff 的實際 CI）。Commit：`docs(acceptance): 記錄管理階段驗收與 CI 結案`，依 commit-msg skill 產生後 commit＋push。

## 2026-10-29 最後安全回歸 — 保留主機判斷與人工回報

- Scope／Red→Green：新增正常 URL 路徑含 `.drillpaper.local` 的真實 fetch，先在 allowNetwork=true 重現失敗；將保留命名空間判斷限制在 URI authority 的主機名稱，不再用整段 URL 子字串拒絕。
- PASS：Release app hash `F0238D6151CF4FC812F94483D99F40AE869D675DA2CF308C201D959B5D6EB757`；安全測試 session security-4e94d27238ce4faf82bf0b39b5b4e71f，含新路徑及 HTTP／HTTPS、WS／WSS、管理與獨立重啟。完整套件再次通過 CTest 33/33（28.19 秒）、SDK 18/18 與其他腳本檢查。
- 測試工具缺陷：清理觀測曾把建立於 14:39 的 MSBuild 29340 列入 14:53 測試 app 的子程序，因舊 ParentProcessId 被重用；未終止該 MSBuild。改為比較父子建立時間並在關閉前保留 process handle，且必須觀察到真正子程序，重測通過。另保留一次原因未定的提前退出與路徑 Red，不稱首次即成功。
- 人工回報：使用者確認系統匣可開啟、匯入操作看起來正常，接續回報移除測試已執行完畢且未述異常；隔離 minimal-monitor@1.0.0 目錄已不存在。取消／確認各步細節未另述，不擴大為完整矩陣。額外視窗來自隔離測試；核對後僅原桌布與人工程序，人工程序已正常退出 0。
- CI：bcb6d2c 的 [40831527263](https://github.com/act70255/DrillPaper/actions/runs/40831527263) 完整 PASS，CTest 33/33、SDK 18/18，RC job 預期 skipped。本次最後主機判斷修正將提交推送後另觸發，不沿用前版 PASS。
- NOT RUN：新版 Explorer 像素人工結論、完整鍵盤／DPI、完整 egress／WebRTC 等安全矩陣；理由及剩餘 gate 仍見 FOLLOWUP.md。原持續桌布 83428 保留，沒有合併 main。
- Commit：`fix(security): 依主機名稱判斷保留來源`，依 commit-msg skill 產生後立即 commit＋push feature/tray-management。

## 2026-10-29 管理續驗 — 獨立啟動全域偏好、junction 與真正 Explorer

- Scope：補足管理功能收尾，發現獨立 `--preview` 不讀保存偏好，先以真實 WebView2 重啟測試重現 FAIL，再讓全部 GUI 啟動先讀 SettingsStore、其後套 CLI 暫時覆寫，啟動不寫回。其他 ticket／發行功能未納入。
- PASS：最終 Release app 建置，hash `746878782C24CF798CA3B9A84F708607994B11FC5B06A87C57DA07A77F2C2A67`；安全整合 off→on→off、管理／獨立重啟、WS／WSS（含獨立 TCP 正向控制）及原有負面案例。最新 session security-d9c5ad6d554f44eba85bb5a87c1ae9f7。
- PASS：真正 NTFS junction 的移除拒絕：root／版本／巢狀資產，12 斷言且外部目標保留；ThemeManager 共 10 案例／87 斷言。產品既有防護通過，沒有虛構 Red。
- PASS（3871e72 的原生程序／bridge）：實際 Explorer 50496→98068；同一管理 app 56892，新 HWND、DesktopEpoch 2→3、ReadyEpoch 2→4、新指標及 TrayRegistered=1。正常退出及已觀察子程序清理通過。沒有把此結果外推至畫面或真正圖示點擊。
- 持續桌布：PID 83428 仍為原固定 a241856 路徑；新 parent 為 Shell 98068，ReadyEpoch=3，兩秒 metrics tick 1488842593→1488844625。未關閉或替換；舊 A04 人工 PASS 保留。
- PASS：最終 `test.ps1 -Configuration Release`，CTest 33/33（22.33 秒）、SDK 18/18，其他環境／採樣／封裝／負面 oracle 全通過。3871e72 另通過 1 次 runtime＋50 次快速往返、自訂入口 renderer crash 3 次、100 次主題切換與管理 150% PNG 檢視。最後 CLI 偏好修正不冒稱重跑這些舊 hash 情境。
- NOT RUN：真正圖示點擊、檔案選擇／移除確認、新版 Explorer 像素人工結論、完整鍵盤／DPI。Computer Use 原生 pipe 缺失（os error 2），已準備隔離固定副本 PID 100000 與 .dmt 並請使用者回報；尚無結果。完整 egress／WebRTC 等及 RC gate 照舊保留。
- CI：NOT RUN，須先推送本次程式與測試提交才能觸發對應版本，接續執行 workflow_dispatch。證據、命令、hash 界線見 [FOLLOWUP.md](acceptance/2026-10-29/management/FOLLOWUP.md)。
- Commit：`fix(settings): 讓獨立啟動沿用全域偏好`，完成本機檢查後立即 commit＋push feature/tray-management；不合併 main。

## 2026-10-29 管理介面階段 3 — 真實網路控制與安全負面整合

- Scope：全域 HTTP／HTTPS 草稿、套用／取消與保存／重啟接入 WebView2；首次封鎖只提醒前往原生設定。每次載入 GUID HTTPS 來源改由宿主回應強制 CSP，保留離線且不啟動 HTTP server；ADR 0001 記錄替代 folder mapping 的原因。外部導覽、框架、worker／WebSocket、下載、權限及彈窗各自拒絕。
- Red／Green：首次提示缺失、介面缺少開關、預設封鎖仍有 WebSocket 到達 loopback server，均先失敗後通過。新增離線 JSON 回歸再抓到 connect-src 過嚴，縮至目前主題來源後通過。
- PASS：Release app build；`test-webview2-security.ps1` 真實 HTTP off→on→off、HTTPS example.com no-cors、script／image／fetch／XHR／redirect、iframe／WebSocket／彈窗／導覽負面、通知／定位 denied、下載取消事件、保存／取消／重啟及已觀察子程序退出。最新 session `artifacts/acceptance/security-a804c15b069b4ad2bf9c79a44037a7be`，hash 與詳細界線見 [PHASE3.md](acceptance/2026-10-29/management/PHASE3.md)。
- PASS：`test-management-shell.ps1 ... -Desktop` 的既有管理生命週期／設定回歸，以及 Dashboard mock Preview smoke（PID 92592）。`git diff --check` 通過。完整套件與 CI 尚待下一階段收尾。
- NOT RUN：完整 egress／WebRTC／DNS／preconnect、跨來源 storage／舊頁面競態、全部權限及 scheme，因不在目前測試覆蓋內；不宣稱完整沙箱，A12 與 RC gate 保留。真正圖示點擊、檔案選擇／確認、新版真正 Explorer、移除 junction 與完整回歸／CI 接續補驗，尚未以舊版結果替代。
- 持續桌布：已核對 PID 83428 的固定 a241856 EXE 路徑，未關閉或替換。舊版 A04 人工 PASS 保留。
- Commit：`feat(security): 接入主題網路開關與強制安全政策`；依階段規則立即 commit＋push 至 feature/tray-management，不合併 main。

## 2026-10-29 管理介面階段 2 — 主題與設定；使用者要求交接暫停

- 實作：原生主題清單、預覽／套用、`.dmt` 檔案選擇器、確認移除、模式與智慧休眠設定、套用／取消；`SettingsStore` schema 驗證、同目錄暫存／flush／原子保存、損毀原檔保留，CLI 暫時覆寫不自動保存。ThemeManager 只允許移除安裝目錄中驗證吻合的版本；使用中的版本先換 Minimal 並關閉舊 controller。
- Red／Green：保存往返、移除所選版本、prerelease 主題名稱各先失敗再實作；新流程誤將內建 `.d.ts` 送入匯入限制的回歸亦由真實啟動抓到並修正，未放寬第三方政策。
- PASS：Release build；Settings 3 案例／15 斷言、ThemeManager 9 案例／75 斷言；管理生命週期、模式切換、保存／取消／重啟恢復；Dashboard mock Preview smoke。150% 管理視窗 PNG 已檢視，控制項未裁切。命令、版本 hash 與界線見 [PHASE2.md](acceptance/2026-10-29/management/PHASE2.md)。
- NOT RUN：檔案選擇器與移除確認的人工作業、真正圖示點擊、新介面的真正 Explorer 重啟、完整 DPI／鍵盤、移除 junction 負面案例；原因為尚需針對性原生互動驗證。完整套件與本版 CI 尚未重跑，留待剩餘實作收尾，不沿用舊版 PASS。
- 使用者因 console 過長要求告一段落停止，故本階段提交推送後暫停；第三階段尚未開始。`allowNetwork` 僅保存欄位，沒有可用開關或 host 接線。續作票：`.scratch/tray-management/issues/03-network-security.md`；01／02 為 implemented、仍有人工待驗。
- 現有持續桌布 PID 83428 仍使用固定 `a241856` EXE；先前 A04 人工 PASS 有效，新介面的實機驗收另計。不要關閉此程序、不要再用會逾時關閉的觀測 runner 作為持續桌布。
- Commit：`feat(management): 新增主題管理與設定原子保存`，分支 `feature/tray-management`，依既有規則 commit＋push。未合併 main，整體 MVP／RC 仍未通過。

## 2026-10-29 管理介面階段 1 — 系統匣與生命週期

- 使用者已明確確認完整三階段 spec；第一階段實作 `ManagementShell`，由穩定通知視窗持有圖示，獨立可信管理視窗可重複開啟／隱藏，提供主題、模式、暫停／繼續、日誌與退出。
- 公開 runtime `ManagedPlayback`：手動暫停優先於智慧休眠及暫停停採，恢復時重新採樣；Red 原政策仍為 Active，Green 1 案例／8 斷言。
- PASS：Release build；`test-management-shell.ps1 -Desktop` 的 5 次唯一視窗、暫停／新指標恢復、3 次受控圖示重註冊、模式 parent 切換、正式退出及子程序清理；既有 runtime 1 次與暫停中退出通過。命令與界線見 [management/REPORT.md](acceptance/2026-10-29/management/REPORT.md)。
- NOT RUN：新介面的真正圖示點擊與 Explorer 重啟／像素、完整 DPI／鍵盤；理由為尚需實機人工操作。圖示建立失敗保留可見管理入口，有界重試十次；沒有操作使用者工作列顯示設定。
- 介面以 `--management` 開啟；既有明確 `--preview`／`--experimental-desktop` 驗收仍可正常關閉。使用者現有持續桌布不受影響。
- Commit：`feat(management): 新增系統匣入口與管理生命週期`，分支 `feature/tray-management`。下一步：主題管理與設定保存；網路開關仍未交付。

## 2026-10-29 管理介面範圍確認整理

- 依使用者「協助我完成確認範圍」，在 `.scratch/tray-management/spec.md` 補上三階段功能與可觀察的完成判定，建議完整功能分階段交付。
- 明列本次不新增開機自動啟動、主題編輯器／線上商店、逐螢幕主題設定及雲端同步；保留原 handoff 的整體驗收要求，未將選配自動啟動改成必做。
- Approval 仍為待確認，尚未把協助整理範圍視為同意實作。驗證：核對 handoff、既有 spec 及 `git diff --check`；產品測試 NOT RUN，原因為僅變更需求文件。
- Commit：`docs(management): 明列管理介面範圍與驗收條件`；依既有階段提交規則 commit＋push 至 `feature/tray-management`。

## 2026-10-29 管理入口需求草案

- 使用者提出以工作列右下角的系統匣圖示作為管理入口。已核對目前只有原生主題選單與 CLI，沒有系統匣／完整設定視窗／設定保存。
- 需求已整理於 [.scratch/tray-management/spec.md](../.scratch/tray-management/spec.md)，狀態 needs-info，等待確認本版互動與範圍；原 handoff 中的 SystemTray 需求不等於這份 UI 細節已確認。
- 交付分為系統匣與管理生命週期、主題／設定保存、網路與安全整合三階段；測試 seam 與實機界線一併列出。此階段只寫需求，產品行為及測試 NOT RUN，原因為尚未實作。
- 規劃提交：`docs(management): 規劃系統匣入口與設定介面`，分支 `feature/tray-management`；後續依使用者確認再開始程式碼。

## 2026-10-29 A04 實機結案 — Explorer 重啟後桌布恢復並持續更新

- PASS（本機本次情境）：使用者確認「可以了 有恢復並持續更新」。受測 `a241856`，EXE SHA-256 `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE`，Windows 11 Pro 25H2 build 26200.8737、Dashboard、`--no-smart-sleep`。
- 原生比對：同一 app PID 83428；Shell PID 988→50496；HWND 688652446→1183238；新父視窗為 PID 50496 的 WorkerW；握手世代 1→2、附掛世代 1→3、失敗碼 0；3840×1080，兩秒間 metrics tick 1481971265→1481973328。人工確認補足 bridge 指標不能代表畫面的限制。
- 證據：`acceptance/2026-10-29/shell-readiness/actual-{session,before,after}.json` 與 `user-confirmation.json`。保留前兩版失敗及受控測試，不以這次成功改寫歷史。
- CI：同一 commit 的 [run 40815261057](https://github.com/act70255/DrillPaper/actions/runs/40815261057) 第 2 次完整通過，CTest 29/29、SDK 18/18；第 1 次在負面測試判斷腳本 60 秒逾時，原因未定，原 log 亦保留，不記為第一次即成功。
- 範圍：A04 在上述實機組態 PASS；Smart Sleep 與重建交錯、其他 Windows／顯示配置及 A03 完整圖示／焦點互動仍分開驗收。A12 安全與其他 RC 阻擋未解除，整體產品尚未驗收通過。桌布持續開啟，未擅自關閉。
- 結案 Commit：`docs(acceptance): 記錄 Explorer 實機復原通過`，依使用者規則提交並推送 `bugfix/explorer-shell-readiness`。

## 2026-10-29 真正重啟續驗 — 等待 Shell 就緒再重掛

- 實機證據：使用者回報已重啟；同一 app PID 70156 重新建立 HWND、握手 1→2，metrics tick 持續增加，但父視窗為空、760×480 預覽，DesktopFailure=1。原因為新 Shell 管理視窗尚未就緒，原復原只試一次即永久退化；此次不記為桌布重掛通過。
- Scope：新增純 runtime 重試政策，以單調毫秒每隔至少 1000 ms 再試，最多 10 次；成功後重設額度，超過上限才退回預覽。UI 在等待期間隱藏暫態視窗，以穩定通知計時器執行後續嘗試；不是無限迴圈，也不重啟採集工作者。
- Red／Green：公開 runtime 狀態契約先 FAIL 於首次失敗即不排重試；實作後 1 案例／28 斷言通過，涵蓋間隔、預算耗盡與成功後重設。真正單次退化的原生證據與新政策證據見 [shell-readiness/REPORT.md](acceptance/2026-10-29/shell-readiness/REPORT.md)。
- PASS：Release build；完整本機 CTest 29/29、SDK 18/18、其他封裝／採樣／測試判斷檢查；父程序崩潰且無注入通知 3 次，新握手／持續指標／正常退出與已觀察子程序清理皆通過。
- NOT RUN：加入等待政策後的真正 Explorer 重啟與畫面。單元測試只證明重試時序與上限，不能證明 Shell 附掛或畫面；仍須以新版本再做實機確認。
- Commit：`fix(desktop): 等待 Explorer 就緒再有界重掛`，分支 `bugfix/explorer-shell-readiness`，完成相關驗證後提交推送。

## 2026-10-29 Explorer 視窗銷毀復原 — 受控修正完成，真正重試待驗

- Scope：區分使用者 WM_CLOSE 與非預期 WM_DESTROY；以獨立通知視窗接收採樣／錯誤，原 HWND 消失後重建原生視窗、功能表、計時器與同一主題的 WebView2 controller。通知遺漏時由每秒一次的宿主檢查補救；重建失敗保留明確錯誤與停止路徑，不無限建立視窗。
- Red：公開 app／Win32 整合 seam 的跨程序父視窗 fixture，銷毀父視窗後舊版 app 提前退出；此前真正 Explorer 重啟則造成失效 HWND 與背景程序殘留。兩條生命週期失敗都列入修正，見 [explorer-recreation/REPORT.md](acceptance/2026-10-29/explorer-recreation/REPORT.md)。
- PASS：正常關閉父視窗 5 次；直接終止隔離父程序且不注入 TaskbarCreated 5 次；每次新握手世代及至少兩次新的 metrics.changed 成功送入 WebView2 bridge，正常退出 0，已觀察子程序全退出。此指標只證明 bridge 接受訊息，畫面仍需人工確認。
- PASS：既有重掛回歸、Dashboard mock Preview、內建及已匯入主題切換、自訂入口 renderer 故障 3 次；生命週期 5 次＋50 次快速往返及暫停期間關閉。完整本機 CTest 28/28（6.80 秒）、SDK 18/18 及其他腳本檢查通過。
- 測試工具修正：Windows PowerShell 5.1 使用明確 UIntPtr 建構式與外層陣列，避免把單一 CIM 物件的空 Count 誤判為沒有 renderer；renderer 初始／自訂入口皆要求新握手世代。Preview／主題協定測試以 no-smart-sleep 隔離當前 display-off，省電仍由獨立生命週期測試驗證。
- NOT RUN：修正版的真正 Explorer 重啟與像素畫面、重建與電源故障交錯、其他 Windows／顯示配置。不能用上述受控結果把舊版真正失敗改寫為通過；待使用者再做一次同情境驗收。
- Commit：`fix(desktop): 重建 Explorer 銷毀的宿主與資料通道`，分支 `bugfix/explorer-window-recreation`，完成相關驗證後提交推送。

### Explorer 修正遠端驗證

- `f2cff39` 已推送並核對 origin；[CI 40810412264](https://github.com/act70255/DrillPaper/actions/runs/40810412264) 全數通過，包含新增 parent fixture 編譯、CTest 28/28、SDK 18/18 與封裝／SDK 還原檢查。metadata 與節錄見 `explorer-recreation/ci.json`／`ci.log`。
- 已開啟固定副本的修正版實機觀測，仍待使用者真正重啟與畫面結果，不預先列 PASS。整體 RC gate 保持阻擋。

## 2026-10-29 人工 Explorer 驗收 — 失敗已重現

- 使用者已啟動桌布並回報「重啟檔案總管後才消失」。真實 Shell PID 31956→70652，受測 app PID 97976 繼續存活，但原 HWND 88151400 已無效，獨立通知視窗仍有效。這次是 A04 FAIL，取代先前待驗狀態；不是腳本 30 秒後自動關閉。
- 失敗點：`RecoverDesktopHost` 遇到無效 gWallpaperWindow 直接返回；初期受控重掛只改 parent、未銷毀 HWND，未涵蓋此行為。需補上跨程序父視窗銷毀回歸與真正的視窗／WebView2 重建，不把訊息注入通過外推。
- 證據：`acceptance/2026-10-29/explorer-failure/` 保存原生視窗診斷、使用者回報與 runner 結果。期限到達後 runner 找不到有效主視窗可正常關閉，終止自己啟動的受測 app（退出 -1）；沒有終止 Explorer。
- 本機完整回歸仍 PASS：CTest 28/28（17.14 秒）、SDK 18/18、環境／採樣／封裝及隔離變異檢查；commit 7902c02 的 [CI 40803087109](https://github.com/act70255/DrillPaper/actions/runs/40803087109) 亦全數通過。這些不推翻上述 Windows 整合失敗。
- 驗收工具已加實際 Shell PID／世代觀測、成功後 30 秒人工觀察；USER_GUIDE 改用標準 build 與完整路徑。FINAL_HANDOFF 已整合目前 A01–A16，不再沿用舊版功能缺漏表。
- Commit：`test(desktop): 保存 Explorer 實機失敗與驗收工具`，分支 `feature/shell-recovery-acceptance`，完成本輪證據整理後提交推送。下一步在獨立 bugfix 分支修正 A04。

## 2026-10-29 主題負面測試 — 修正例外判斷誤報

- Red：只在隔離副本移除 validator 的路徑檢查後，正式測試腳本仍退出 0，且將預期拒絕卻被接受的 traversal 封包印為 PASS。原生 validator／產品檔案未變更；此實驗驗證測試本身是否有辨識力。
- Fix：只捕捉 validator 的拒絕例外；「預期拒絕卻被接受」的斷言移至 catch 外。新增公開腳本入口的隔離變異回歸，納入本機 test.ps1 與 CI。
- Green：相同變異現在讓子程序在 traversal.dmt 正確退出 1；正式未變異 validator 仍通過合法封包並拒絕 5 類非法包。證據見 [theme-oracle/REPORT.md](acceptance/2026-10-29/theme-oracle/REPORT.md)。
- Commit：`fix(test): 防止主題負面案例被誤判為通過`，分支 `bugfix/theme-negative-oracle`。此修正不代表尚未執行的 WebView2 外連／下載／權限測試通過。

## 2026-10-29 封裝工具續作 — Windows PowerShell 5.1 壓縮組件

- Red：新程序直接執行 `test-theme-package.ps1` 時找不到 `System.IO.Compression.ZipArchiveMode`；完整回歸亦在同一位置停止。
- Scope：主題 validator／測試、SDK packager／測試各自明確載入 `System.IO.Compression`，不再依賴另一支腳本先間接載入。
- Green：5.1 的主題測試及 SDK ZIP 解壓重測皆成功，SDK 18/18，兩次 SDK 封裝 hash 一致。證據見 `acceptance/2026-10-29/powershell-zip/`。這只確認執行相容性與所列封裝檢查；不外推成瀏覽器安全驗收。
- Commit：`fix(scripts): 明確載入 Windows PowerShell 壓縮組件`，分支 `bugfix/powershell-zip-assembly`，相關驗證完成後提交推送。

## 2026-10-29 效能工具續作 — Windows PowerShell 5.1 相容性

- Scope：將 PowerShell 運算式中的 `[ushort]` 改為 `[System.UInt16]`；C# 原生宣告與 all-processor-groups 的 `MaxValue` 語意不變。
- Red：Windows PowerShell 5.1 執行 `scripts/test-performance-sampler.ps1`，無法辨識 ushort，退出碼 1；這也是當日本機完整回歸的中止原因。先前在 PowerShell 7 的通過結果不外推到 5.1。
- Green：相同命令於 5.1 通過，3 筆完整樣本、跨度 2.339 秒；提前退出與未知 PID 的失敗資料仍保留。原始輸出見 `acceptance/2026-10-29/powershell/`。完整套件待同步修正後再收尾重跑。
- Commit：`fix(perf): 相容 Windows PowerShell 的處理器群組型別`，分支 `bugfix/powershell-sampling`，完成相關驗證後提交推送。

## 2026-10-29 Phase 8 續作 — 乾淨 Windows CI 的 SDK 還原

- Scope：官方 NuGet WebView2 SDK 1.0.2478.35、固定 SHA-256、驗證後解壓、拒絕覆寫既有目錄、staging 清理；CI 及選配 RC job 都先還原 SDK 並設定 WEBVIEW2_SDK_ROOT，沒有移除 CMake 的必填檢查。
- Red（真正 GitHub runner）：[run 40801046281](https://github.com/act70255/DrillPaper/actions/runs/40801046281)，SDK／主題封裝通過，但 Configure 因 WebView2 headers 不存在失敗，證據見 `acceptance/2026-10-29/ci/before-fix.log`。
- PASS（本機腳本）：`powershell -NoProfile -File scripts/test-webview2-bootstrap.ps1 -ArchivePath C:/WorkSpace/-James/DrillPaper/.toolchain/webview2/sdk.zip`，官方包／空白路徑／竄改包拒絕／既有檔保留／staging 清理通過。
- 後續遠端驗證：先提交並推送 `bugfix/ci-webview2-bootstrap` 的具體修正，才可用 workflow_dispatch 執行該版本；新 runner build／CTest 結果尚待執行，不預先標為 PASS。真正 RC job 保持 opt-in，發行閘門未解除。
- Commit：`fix(ci): 還原固定雜湊的 WebView2 SDK`；來源包與版本固定方式見 `docs/ENVIRONMENT.md`。

### CI 遠端驗證結案

- Commit `9888aaf` 的 [run 40801528098](https://github.com/act70255/DrillPaper/actions/runs/40801528098) 已實際全數 PASS：乾淨 runner configure／build、CTest 28/28、Node 18/18、SDK 還原邊界及主題 artifact。取代上方執行前的待驗狀態。
- 證據見 [ci/REPORT.md](acceptance/2026-10-29/ci/REPORT.md)。此結果不證明 Windows 10／11 Shell GUI 或乾淨使用者安裝；RC job NOT RUN，未要求發行且發行條件尚未滿足。
- 結案 Commit：`docs(ci): 保存乾淨 Windows runner 驗收結果`，與修正一併推送 `bugfix/ci-webview2-bootstrap`。

## 2026-10-29 Phase 1 續作 — Windows 11 桌布附掛與受控重掛

- Scope：使用 `GetShellWindow` 錨定目前 Shell PID，排除其他程序的同名 WorkerW；支援新版 Progman 子 WorkerW，保留舊頂層搜尋與 Preview fallback。修正 SetParent 已回傳成功但殘留 LastError 導致誤判的重掛缺陷。附掛世代／最後失敗碼可由原生視窗屬性診斷。
- Red：實機公開 DesktopHost 整合測試先失敗（找不到桌布層）；改用新版建立訊息後仍失敗，inventory 顯示 WorkerW 已建立於 Progman 內。完整 app 的解除附掛／定向 TaskbarCreated 迴圈再重現錯誤碼 4；SetParent 回傳值判斷修正後轉綠。
- PASS（Windows 原生整合）：Release app 建置；原生視窗 2 案例／22 斷言；相關 CTest 1/1。完整 app 同一 PID／HWND，SDK 握手完成，3840×1080 填滿父用戶區，附掛世代 1→6，5 次受控重掛，退出碼 0，6 個 WebView2 子程序全退出。觀測已統一 Per-Monitor V2 DPI 座標。
- Commands：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperWindowsHostIntegrationTests --parallel 8`；測試 EXE `'[shell-live],[desktop]'`；`scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -RecoveryCycles 5`。證據與限制見 [shell/REPORT.md](acceptance/2026-10-29/shell/REPORT.md)。
- NOT RUN：本輪真正 Explorer 程序重啟、圖示／工作列／Alt+Tab 與像素畫面。Windows Computer Use 原生管道不存在，畫面需人工補驗；受控通知明確不算 Explorer 重啟。`[shell-live]` 會操作當前桌布層，故只手動明確呼叫，不納入無互動 CTest。
- Commit：`fix(desktop): 支援新版桌布層並修正重掛誤判`，分支 `bugfix/shell-attachment`，依階段規則提交推送。上一階段 Preview 回復提交 `edbb261` 已在 origin。

## 2026-10-28 Phase 1 續作 — Preview 回復樣式

- Scope：只修正 `Win32DesktopHost::RestorePreview`，解除父視窗後清除桌布專用的 `WS_EX_NOACTIVATE`／`WS_EX_TOOLWINDOW`，恢復一般預覽視窗。新增專屬 Win32 父子視窗整合測試，不操作 Explorer。
- Red：`DrillPaperWindowsHostIntegrationTests.exe '[desktop]'`，1 案例失敗／6 斷言中 5 通過；`WS_EX_NOACTIVATE` 仍為 `0x08000000`，重現樣式未回復。
- Green：Release 主程式及整合測試 target 建置成功；`ctest --test-dir build/windows-msvc-release -C Release -R 'Desktop fallback' --output-on-failure` 通過。最終測試輸出與二進位雜湊見 [desktop-preview/REPORT.md](acceptance/2026-10-28/desktop-preview/REPORT.md)。
- NOT RUN：真正桌布附掛、桌面圖示／工作列互動、Explorer 重啟及視覺驗收。此階段只證明本程序視窗的回復樣式，沒有操作使用者的 Shell；其餘項目仍須獨立整合驗證。完整套件留至整體收尾，這次只跑直接相關測試。
- Commit：`fix(desktop): 修正預覽回復時殘留桌布視窗樣式`；分支 `bugfix/desktop-preview-fallback`，依階段規則提交並推送至 origin。

## 2026-10-28 Phase 7 — 30 分鐘觀測與狀態分析

- Scope：Runtime 版本 Minimal 實機 Preview，60 秒暖機、1800 秒要求，獨立 EXE／profile，CPU／Private Bytes／Working Set／handles／原生狀態分組；不冒充最新 renderer 復原版本的效能。
- PASS（收集與分析）：343 筆，實際 1804.606 秒，固定 7 程序且全含 app＋WebView2，無略過或不完整資料。active CPU 平均 0.1159%、locked 0.00628%；此觀測差約 94.6%，非普遍功耗保證。
- PASS（清理）：正常退出 0、6 個已觀察子程序全退出、暫時電源需求還原。原始資料、圖表、版本、方法與限制見 [long-observation/REPORT.md](acceptance/2026-10-28/long-observation/REPORT.md)。
- PARTIAL（A13）：active 穩定區間僅 596.194 秒，未寫成 600 秒；還缺 Dashboard／GPU Engine／display-off／全螢幕等對照。Private Bytes 起訖 +9.39 MiB，長時間洩漏不能由有限觀測排除。Commit `6551113 test(perf): 保存混合狀態長測與資源分析`，已推送 `feature/performance-observation`。

## 2026-10-28 Phase 4／6 續作 — 程序退出型渲染復原

- Scope：ProcessFailed 通知、UI 迴圈重建 renderer／environment、來源與載入世代、callback lifetime、保留原生採集與快照、自訂入口保留、有界 Minimal／原生 Preview 退化。Files：WebView2 host/header、App event composition、`scripts/test-renderer-recovery.ps1` 與驗收紀錄。
- Red／Green：已辨認新握手世代後，renderer 故障未恢復的測試先 FAIL；修正後 renderer 3 次、browser 3 次、8 次故障達上限後原生退化、非 index 入口各 PASS，app 正常退出碼 0。見 [recovery/REPORT.md](acceptance/2026-10-28/recovery/REPORT.md)。
- Scope 限制：程序／協定整合，非每次像素畫面；測試以 `--no-smart-sleep` 隔離其他政策。unresponsive／無限迴圈、crash 與電源交錯、其他 process kinds、Explorer、安全與發行條件仍 NOT RUN，原因為對應情境或功能尚未完成。
- Commit `1a0bad1 feat(web): 新增有界程序故障復原與握手驗證`，已推送 `feature/renderer-recovery`。

## 2026-10-28 階段提交與遠端同步

- 使用者已指定每階段完成後直接 commit＋push；規則已加入 repository `AGENTS.md`，後續依此執行。
- 已推送並用 `git ls-remote --heads origin` 核對：`feature/theme-manager` → `66edcbb`、`feature/runtime-lifecycle` → `3bdca3f`、`bugfix/performance-sampling` → `a41261e`。`main` 維持 `5697bf7`，未合併開發分支。
- 渲染器復原尚在開發：目前只有故障注入腳本與新握手診斷；已觀察失敗，實際自動復原未完成。這些 WIP 尚未推送，未當作驗收通過。

## 2026-10-28 效能工具修正與長測啟動

- `bugfix/performance-sampling`：要求 2 秒只覆蓋 1.205 秒的 regression 先 FAIL，修正以 CSV 首末跨度判定結束後 PASS。新增身分／狀態／handles、原始 Handle 身分保留、根程序退出 FAILED 與部分資料保存，不記為成功的零資源樣本。
- PASS：`scripts/test-performance-sampler.ps1`，完整跨度 2.467 秒、缺身分欄位修正、提前退出及不存在 PID 皆驗證。觀測 runner 短測亦確認正常退出、已觀察子程序全退出及暫時電源需求還原。
- 17:50 啟動 Minimal 30 分鐘實機觀測，60 秒暖機，獨立 profile／EXE 副本；尚未預判結果。證據與命令見 [sampler/REPORT.md](acceptance/2026-10-28/sampler/REPORT.md)。
- Commit `a41261e fix(perf): 修正採樣跨度並保留失敗證據`，已推送。後續繼續 renderer 復原、安全及桌布整合。長測與其他開發工作可能同時執行，保留環境限制。

## 2026-10-28 Phase 3／6 續作 — 背景採樣與生命週期

- 分支 `feature/runtime-lifecycle`，承接 `66edcbb`；Commit `3bdca3f feat(runtime): 串接背景採樣與電源生命週期`。Files：SamplingWorker、Windows PowerNotifications、App composition、WebView2 host、runtime unit／原生整合腳本及驗收文件。
- Scope：採集移出 UI、條件等待／可停止工作者、latest-wins mailbox 與設定世代、恢復基準重設、WTS／顯示器通知、前景全螢幕防抖、WebView2 hide/TrySuspend/Resume、非同步 callback lifetime／狀態世代。
- Red／Green：背景樣本未送出、Windows 通知宿主缺失、快速狀態往返後未暫停皆有失敗證據再修正。Worker 4 案例／21 斷言；完整回歸初次 CTest 27/27、SDK 18/18、封裝檢查通過，最終紀錄見 [runtime/REPORT.md](acceptance/2026-10-28/runtime/REPORT.md)。
- PASS（受控原生整合）：5 次往返、50 次快速往返、暫停期間正常退出。實際查詢 IsSuspended，不以 callback 成功代替目前狀態。
- PASS（人工實機）：使用者回報 Windows 真實鎖定／解鎖 5 次均恢復更新、可正常關閉；受測 EXE hash 與 PID 退出紀錄保存在 manual-session.json。
- PASS（實機 GPU 退化）：非 mock SDK 探針確認 CPU／RAM 已可用，GPU unavailable/null，沒有假 0；非 Intel GPU 支援或讀值精度聲明。
- NOT RUN：真實 display-off／待機、完整全螢幕／多螢幕、renderer／Explorer 復原、安全、長時間與安裝／CI矩陣。下一步：補齊效能採樣邊界、復原與安全驗證；發行閘門不變。

## 2026-10-28 Phase 5 續作 — 原生匯入與熱切換

- Scope：原生 `.dmt`／目錄驗證與 staging/atomic install、CLI 匯入／列舉、Win32 主題功能表、已安裝版本熱切換、逾時回復 Minimal。隔離 GUID origin 避免沿用舊來源。新依賴授權納入建置。
- Files：`src/themes/theme_manager.cpp`、`src/app/{main,theme_commands}.cpp`、WebView2 host 與對應 headers、`tests/unit/theme_manager_test.cpp`、`scripts/test-theme-{cli,switch}.ps1`、CMake、第三方 notices/licenses、README 及架構／使用者／驗收文件。
- Red／Green：ZIP、CLI、內建切換、已安裝主題與 junction 日誌寫入邊界均先有失敗證據再修正。原生主題 8 案例／71 斷言 PASS；CLI CTest PASS。相關命令、檔案範圍及原始證據見 [主題平台驗收報告](acceptance/2026-10-28/theme-platform/REPORT.md)。
- Windows 整合 PASS（程序／協定）：100 次內建切換後載入已匯入主題，正常退出；損壞主題逾時回復 Minimal 並重新訂閱。非畫面截圖驗收。
- 資源 PARTIAL：100 次 Private Bytes 約 197→331 MiB；追加 300 次峰值約 404 MiB、閒置後約 331 MiB，handles 234→257。不得宣稱無洩漏，長時間矩陣保留。
- NOT RUN：瀏覽器完整安全負面、Shell GUI、電源實機與乾淨安裝／CI；未具備完整產品整合或證據。發行閘門維持阻擋。
- Commit：`66edcbb feat(themes): 新增原生主題匯入與熱切換驗證`。下一步：在 `feature/runtime-lifecycle` 實作背景 worker／生命週期，並持續補安全與效能驗證。

## 2026-10-28 14:05 Dashboard 初始效能基線

- 使用者授權由 agent 直接開啟 Dashboard 實機 Preview，執行 600 秒任務、每輪等待 5 秒，並正常關閉。未修改產品行為；未提交。
- **PASS（量測與退出）**：113 樣本皆包含 app 與 WebView2，共 7 程序；CPU 平均 0.116%、p95 0.422%（14 邏輯處理器整機容量）；Private Bytes 平均 240.54 MiB，首分鐘後趨勢 -0.018 MiB/min；正常退出碼 0，觀察到的 6 個子程序全退出。
- 原始 CSV 實際跨度 594.971 秒，不能宣稱 CSV 覆蓋至少 600 秒。原始資料、退出證據、方法與限制見 [performance/REPORT.md](acceptance/2026-10-28/performance/REPORT.md)。
- **PARTIAL（A13）**：只有初始 Preview 基線；30 分鐘、Minimal／休眠對照、GPU engine 及 100 次切換 NOT RUN，尚無相應證據及完整產品整合。不能由此宣稱沒有洩漏或產品效能驗收完成。

## 2026-10-28 續驗：原生主題負面案例

- 範圍：公開 ThemeManager manifest 與安裝行為；延續既有主題分支。Files：原生主題管理實作／header、主題測試及驗收紀錄。Commit：尚未提交。
- **FAIL → PASS**：新增 101 字元名稱案例，先重現原生驗證器錯誤接受（exit 1），再修正 UTF-8 字元長度判斷。名稱／作者／說明採 manifest 字元上限；不以放大的 bytes 限制代替字元數。
- **PASS**：主題測試 target 建置；`DrillPaperThemeTests.exe '[themes]'` 6 案例／16 斷言；`ctest --preset windows-msvc-release --output-on-failure` 22/22，14.53 秒。原始紀錄與命令見 `docs/acceptance/2026-10-28/REPORT.md`。SDK 未更動，未重跑。
- **PARTIAL（Dashboard 實機人工驗收）**：使用者後續回報持續更新、有 CPU 圖表且可正常關閉，此三項 PASS。GPU unavailable、個別版面／縮放、可追溯程序樹的長時間效能及退出後子程序清理仍未驗證；已提供 10 分鐘 Dashboard 程序樹採樣命令。
- 發行阻擋保留：Theme Manager 未接入 app、無原生 ZIP／熱切換、背景採樣／休眠與網路策略整合缺漏，以及桌布、安全、效能與安裝矩陣未驗收。下一步：取得程序樹 CSV 與 metadata 後分析；補齊產品整合後再驗收相應項目。

## 2026-10-28 13:05 Windows 11 驗收

- 範圍：目前工作樹的 Release 建置、完整自動回歸、產物存在檢查與 GUI 工具可用性；未修改產品行為。分支 `feature/theme-manager`，本次未提交。
- **PASS**：`cmake --build --preset windows-msvc-release --parallel 8`、`scripts/test.ps1 -Configuration Release`，均 exit 0。CTest 22/22（含 Windows collector 與主題管理入口），SDK 18/18、環境回歸、主題 ZIP 正負案例及 SDK ZIP 解壓／重封全通過。
- **PARTIAL（人工 Preview）**：2026-10-28 13:18 使用者回報 Dashboard mock 文字與數值皆符合預期。13:19 再回報 Minimal 實機數值及時間持續更新（CPU 83%、RAM 81%、RX 18 KB/s、Host active），此範圍 PASS。Dashboard 個別版面、硬體精度及實機 GPU unavailable 仍待確認；Minimal 縮放與正常關閉已獲後續確認。Computer Use 管道不可用（os error 2），沒有工具截圖。
- **NOT RUN**：桌布／Explorer 復原、硬體精度、WebView2 安全負面整合、Windows 休眠、長時間效能、CI、乾淨安裝；原因及未完成產品功能見[本次驗收報告](acceptance/2026-10-28/REPORT.md)。整體產品仍未驗收通過，app RC 阻擋保留。
- **PASS（本輪基本 Preview 操作結案）**：使用者接續回報「1.2 OK」，確認目前 Minimal 視窗縮放無重疊／裁切，正常關閉無卡住。連同 Dashboard mock 文字／數值與 Minimal 實機更新，完成此次基本操作驗收；不外推到 Dashboard 個別版面、GPU、硬體精度、退出後子程序清理或桌布整合。
- 原始原生測試 log 已保存至 `docs/acceptance/2026-10-28/ctest.log`。後續：補齊主題管理、背景採樣／休眠、網路策略等未接入功能及其整合驗證。

## 2026-10-28 本機環境與續作

- 目前工作樹在 `feature/theme-manager`；`5697bf7` 已提交先前原型，起始工作樹乾淨。下文「只有 be5cb92、工作樹未提交」是舊環境紀錄，已過期。
- 本機為 Windows 11 Pro 25H2 build 26200.8737、VS 2022 Professional 17.14.17、MSVC 19.44、Windows SDK 10.0.26100.0、Node 24.17.0、Intel GPU。已用 uv 安裝 CMake/CTest 3.31.6，並安裝 WebView2 SDK 1.0.2478.35 到使用者 NuGet 目錄；Runtime 155.0.4283.62 原已存在。詳細步驟見 `docs/ENVIRONMENT.md`。
- **PASS**：`cmake --preset windows-msvc-release` 設定完成；Release `DrillPaper.exe` 已編譯；`scripts/test.ps1 -SkipNative` 的 SDK 18/18、主題封裝及 SDK 封裝驗證成功。
- **進行中**：依 `docs/IMPLEMENTATION_PLAN.md` 補原生主題管理。已建立獨立的目錄驗證、staging 安裝及列舉雛型，尚未接入 app，也不支援 `.dmt`；不應認為 Phase 5 已完成。發行腳本明確維持阻擋。
- **Phase 5 測試**：主題安裝起始測試先以佔位實作執行，結果 FAIL（預期）；實作後 `ctest --test-dir build/windows-msvc-release -C Release -R '^DrillPaperThemeTests$' --output-on-failure` PASS（2 個案例：安裝列舉、自身子目錄拒絕）。後者是預先辨識的安全修正，未另外取得失敗測試紀錄。原生主題負面測試、安全審查及 ZIP 解壓均未完成，尚不能宣稱可安全安裝不可信主題。
- **建置修正**：Catch2 自動發現遇到中文測試名稱 JSON 編碼錯誤；改以 CTest 單一入口執行主題測試，重新編譯成功。Phase commit：尚未提交。
- **NOT RUN**：本機 GUI 桌面附掛、外連安全、Windows 休眠及硬體精度驗收；Shell inventory 只列舉視窗，不代表附掛成功。

本紀錄更新至 2026-10-28。`PASS` 僅表示所列命令或明確範圍已在本機執行成功，不外推到未測 GUI、硬體功能、發行流程或安全性。原始規格仍見根目錄 `DesktopMonitor_Codex_Handoff.md`。

## 已確認決策

- 專案名稱：DrillPaper；首版目標 Windows 10/11 x64，支援範圍仍須按實測矩陣逐版確認。
- 主題網路預設封鎖；首次外連遭封鎖時應提示使用者前往設定；單一全域開關開啟後允許 HTTP/HTTPS，其他 URI scheme 仍封鎖。DrillPaper 不送遙測。現有 WebView2 host 會阻擋非本機來源，但提示與全域開關尚未實作，網路封鎖亦未做流量測試。
- 首個 app RC 僅供本機評估，不公開發布。
- 使用者選定第一方內容 Apache-2.0（SPDX `Apache-2.0`），著作權 `Copyright 2026 DrillPaper Project`；第三方依賴與社群主題須各自遵守其授權；保留 DrillPaper 名稱及標誌。
- TDD seams：MetricsSnapshot/採集器、Runtime 狀態與有界佇列、Theme manifest/封裝、JSON protocol/SDK；Win32 Shell 與 WebView2 用原生整合/GUI 驗證。無法取得 GUI 證據的項目保持未驗收。

## 環境與目前工作樹

- Windows 10 Pro x64 build 19045；Visual Studio Enterprise 2022 17.11.2、MSVC 19.41.34120、Node.js 22.14.0。
- 在 repository 忽略目錄 `.toolchain/` 安裝並驗證 CMake 4.3.5、Windows SDK 10.0.26100.0 及 MSVC 缺少的 headers/CRT；WebView2 SDK 1.0.2478.35，已安裝 Evergreen Runtime 155.0.4283.62。未修改系統 PATH 或 ACL。`scripts/* -LocalToolchain` 使用此工作區工具鏈；乾淨環境需先準備等效 SDK 及 Catch2 FetchContent 原始碼快取。
- Release build 目錄：`build/local-msvc-release`；可執行檔：`build/local-msvc-release/DrillPaper.exe`。
- 這台電腦先前缺少 CMake/SDK，首次檢查確實失敗；安裝工作區工具鏈後，已實際完成 Release 編譯、CTest 與 app/WebView2 protocol smoke。原先失敗紀錄不再代表目前狀態。
- 使用者已明確授權 Git commits。2026-10-28 再次執行 `git -c safe.directory=C:/WorkSpace/DrillPaper add -A`，工具環境仍拒絕建立 `.git/index.lock`（Permission denied）；因此目前只有既有 commit `be5cb92`。沒有變更 ACL 或繞過寫入限制。此工作樹的程式與文件修改尚未提交。

## Phase 0 — Repository / Environment Audit

- **狀態：部分完成。** 完成 repository、AGENTS、TDD skill、原生環境與依賴 audit；固定 Catch2 3.8.1（BSL-1.0，僅測試），建立 CMake/PowerShell build-test-environment scripts。工作區安裝 CMake/Windows SDK/WebView2 開發依賴。
- **驗證：PASS** — MSVC x64 Release app 編譯；`DrillPaper.exe --version` 輸出 `DrillPaper 0.1.0-dev`；`--diagnostics` 回報 x64 及 WebView2 Runtime 155.0.4283.62。初期無工具鏈時的失敗已記錄在歷史執行脈絡，不是目前 blocker。
- **GUI：PARTIAL** — app 已建立視窗並能跑 WebView2 smoke；Computer Use 工具拒絕對 DrillPaper 進行可視操作，沒有截圖或人工視覺檢查，因此不宣稱 UI 視覺驗收。
- **Git：BLOCKED** — `.git` 唯讀，無法建立 Phase commit；使用者授權已給，不會再詢問。受限工具環境仍拒絕寫入。
- **下一步：**完成可行的原生功能與文件；不能解除的 Shell/Theme Manager/安全/效能 gate 均具體列入交接。

## Phase 1 — DesktopHost Feasibility Spike

- **狀態：未驗收；桌布附掛不支援宣稱。** 已有 `WorkerW`/`SetParent` opt-in 程式碼、Preview fallback 與 Explorer/display-change 重試。Shell inventory 在 Windows 10 Pro 19045 列舉 17 個相關 top-level windows；`Progman` 下見到 `SHELLDLL_DefView`，未觀察到可用的全螢幕 wallpaper layer。
- **測試：NOT RUN** — 沒有以 app 實際掛載桌面、檢查圖示/工作列/Alt+Tab/focus/z-order、重啟 Explorer 或測試解鎖/解析度變更的 GUI 證據。C++ app 編譯成功不等於 Shell POC 通過。
- **結果：**`--preview` 為可用的獨立視窗路徑；`--experimental-desktop` 保持 opt-in，不能列為已支援桌布。

## Phase 2 — Metrics Core + TDD

- **狀態：部分驗收。** 已實作 typed metric/unit/quality、CPU/network 差值、Windows CPU/RAM/disk/network collectors 與選配 NVML loader。
- **測試：PASS** — CTest 涵蓋 CPU warm-up/delta/reset、metric unavailable/zero、單位與 network rate；Windows collector integration test 真正呼叫本機 API，確認 typed readings 和 CPU/network warm-up，CTest 21/21 全通過。
- **限制：**沒有以獨立儀器或已知工作負載比對各指標精度；GPU/NVML 和 disk activity 尚無專項硬體/數值驗證。app protocol smoke 只證明 snapshot 流程完成，不能據此宣稱所有硬體值正確。

## Phase 3 — Runtime / State Machine / Bounded Cache

- **狀態：核心政策測試通過；產品執行緒整合未完成。** Ring buffer 保留最多 120 筆、latest-wins coalescer、change detector、power state machine、sampling scheduler 都有 C++ 測試。
- **測試：PASS** — CTest 21/21，包括有界 history/coalescing、狀態轉換、防抖與 scheduler 不補跑過期採樣。
- **限制：**目前 app 以 UI timer 同步採樣；尚無背景 sampling worker 與已驗證的 worker→UI mailbox lifecycle、shutdown/race stress、session/display/power notification、WebView suspend/resume。

## Phase 4 — WebView2 Host + Protocol v1

- **狀態：原生 host 與 JSON protocol 已建置並做程序層整合 smoke；安全負面與 GUI 渲染驗收未完成。** Host 使用 WebView2 virtual host mapping、私有 user-data directory，處理 SDK hello/ready、snapshot/history/subscribe；拒絕非本機 navigation/resource 和新視窗。
- **測試：PASS** — CTest 21/21，含原生 JSON 序列化/解析、64 KiB 限制、版本/欄位/請求 ID/history/subscribe cases；`scripts/test-webview2-smoke.ps1` 對 `minimal` live collector 與 `dashboard --mock-metrics` 均觀察到完成 hello→snapshot→subscribe 的 `Live metrics` 標題。
- **限制：**未用真實 JS 惡意 payload/外部請求做 WebView2 負面整合測試；無 renderer crash/reload 恢復測試；未用截圖或人工視覺檢查 DOM/排版；WebView2 執行於 UI thread，metrics 也在 UI timer 同步採集。

## Phase 5 — Theme Manager / SDK / Examples

- **狀態：SDK/作者工具完成可測部分；原生 Theme Manager 未實作。** 有 manifest validator、TypeScript 宣告、JS SDK/MockHost、minimal/dashboard 範例、`.dmt` 封裝/驗證器。WebView2 透過 CLI 可各自載入兩個內建來源，尚未提供執行期熱切換。
- **測試：PASS** — 18/18 Node 測試；`.dmt` validator 接受有效包，拒絕 traversal、大小寫重複路徑、不允許副檔名、錯誤 API version、超過 10 MiB 檔案；SDK package 解壓後重跑測試與兩個 theme validator，SHA-256 可重現。
- **產物：**`artifacts/DrillPaper-Theme-SDK-1.0.0-rc3.zip`，49,107 bytes，SHA-256 `68E0B5F41FB2337B396A5335CA1707B0F6F5E275F3771EF913E1DF8210D01656`。Apache-2.0；本機評估包，不含 app。
- **限制：**無 `.dmt` 原生匯入、staging/atomic install、列舉、切換、rollback、舊 API 提示或 100 次切換資源測試。

## Phase 6 — Smart Sleep / Recovery / Security Hardening

- **狀態：部分策略與 baseline host 控制已實作；未達安全或省電驗收。** C++ `ThemeNetworkPolicy` 模型測試通過；WebView2 host 阻擋外部 navigation/resource 和新視窗。
- **測試：PARTIAL** — CTest policy/schema cases 通過；未對 WebView2 執行 egress、redirect、fetch/XHR/image/script/iframe/WebSocket、permission 或 download 負面測試。
- **限制：**使用者要的首次阻擋提示與單一全域 allow HTTP/HTTPS 開關尚未接入；network policy model 未整合至 request interception。尚無 WTS/display/power events、TrySuspend/Resume、renderer/Explorer crash recovery。不得宣稱外部主題已沙箱化或 egress 已驗收。

## Phase 7 — Performance / Regression / Compatibility

- **狀態：量測工具有 smoke；產品效能與相容性驗收未跑。** Process-tree sampler 支援將可追溯 WebView2 child processes 計入統計；曾以 DrillPaper+WebView2 跑短時程序樹 smoke，觀察到 app 與 `msedgewebview2`，共兩筆 sample。
- **測試：NOT RUN** — 無 10–30 分鐘產品 CSV，也未比較 minimal/dashboard、locked/display-off、主題切換或長時間資源成長。
- **相容性：NOT RUN** — 目前只在 Windows 10 Pro x64 build 19045 建置；Windows 11、多螢幕、DPI/熱插拔與 Explorer recovery 未驗收。

## Phase 8 — CI / Packaging / Release Candidate

- **狀態：SDK RC 可交付本機評估；DrillPaper app RC 被正確 gate 阻擋。** `scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1 -LocalToolchain` 實際完成 build、完整測試後停止，明確報告缺 `src/themes/theme_manager.cpp`。沒有產生 app ZIP；不要稱 app RC 已完成。
- **測試：PASS / BLOCKED** — `scripts/test.ps1 -Configuration Release -LocalToolchain`：CTest 21/21、Node 18/18、環境檢查回歸、`.dmt` 正負案例及 SDK ZIP 解壓/重封驗證全通過。Windows GitHub Actions 未執行。`--version`、`--diagnostics` 與 WebView2 smoke 已實測。
- **限制：**沒有安裝器、乾淨 Windows user install/uninstall 驗證、app ZIP、簽章、長時間效能報告或 CI runner log。
- **下一步：**實作與測試 Theme Manager、使用者網路提示/全域設定、worker/smart sleep、原生 Shell GUI 支援；完成安全與效能矩陣後再解除 RC gate。需在可寫 `.git` 的受控環境按 Phase 建立 commit。
