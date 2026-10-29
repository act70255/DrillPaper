# 網路設定與安全整合

Status: implemented

## Scope

完整三階段 spec 已由使用者確認。全域 HTTP／HTTPS 開關已實際接入 WebView2 host，預設拒絕、首次封鎖提示不自動允許；其他 scheme、來源／導覽、CSP、權限、下載與彈窗分別限制。指定真實 WebView2 負面測試已執行，仍需完成下列驗收收尾；不可宣稱完整沙箱。

## Acceptance

- 一個公開行為失敗測試後才做最小實作，保留原生實機與 unit 的證據界線。
- 真實外部 script／iframe／fetch／WebSocket／redirect／下載／權限／彈窗等驗證；未執行明列 NOT RUN。
- 接續補階段 1、2 人工驗收及移除 junction 負面測試；新管理介面真正 Explorer 重啟需再次確認。
- 全部完成後完整回歸、文件與 STATUS，再依 commit-msg skill commit＋push；RC 阻擋仍依原驗收矩陣，不移除 gate。

## Comments

- 2026-10-29 最後 CI 結案：6672610 的 run 40840814142 完整 PASS，CTest 33/33／SDK 18/18、SDK 還原／封裝，RC skipped。後續僅文件；產品仍 62f01ab，精確未驗範圍與原桌布保留見 REMAINING.md。不合併 main、不宣稱整體 MVP／RC 或完整沙箱完成。

- 2026-10-29 本輪結案：62f01ab 完整本機 CTest 33/33／SDK 18/18 及 CI 40839289477 通過；管理原生、50 次快速生命週期、3 次 renderer、100 次主題切換通過。使用者另確認新版真正 Explorer 畫面恢復／持續更新與圖示／工作列可用；前版鍵盤／取消／唯一視窗正常。追加 preconnect 真實 TCP 負面（含開啟時瀏覽器正向控制）通過，產品未再變更。完整 DPI／DNS／其他未測矩陣及 RC gate 保留；原持續桌布未關閉或替換，見 REMAINING.md。

- 2026-10-29 擴充續驗：拒絕外部導覽可能提交 chrome-error 空白頁，經獨立導覽主題先 Red，再加入原生失敗導覽的可信 Minimal 回復而 Green；不保存此回復至偏好。IndexedDB／Cache Storage、三類 worker、camera／microphone 權限狀態與 STUN／TURN-TCP 指定矩陣亦通過。完整範圍、失敗嘗試及原生／CDP hash 界線見 REMAINING.md、ADR 0004；本版完整回歸／CI 接續執行。

- 2026-10-29 剩餘續驗：以真實瀏覽器先抓到共同父網域 Cookie 跨 GUID 來源保留，改為每次獨立可註冊 .invalid 網域；另重現網路關閉仍有三筆 WebRTC STUN UDP。Connection-Allowlist 加入後，同接收端只有獨立控制封包，off→on→off 與重啟均無主題 UDP。相關 Red→Green／hash／限制見 REMAINING.md、ADR 0002／0003；後續繼續擴充 TURN／推測連線與儲存矩陣。使用者對前版隔離視窗回報鍵盤／取消／唯一視窗正常，DPI 未測。

- 2026-10-29 收尾：63e86ff 的 CI 40832496506 完整 PASS（CTest 33/33、SDK 18/18、SDK 還原與封裝）；本票實作及所列驗證完成，狀態設為 implemented。新版 Explorer 像素、完整 DPI／鍵盤與安全未測矩陣仍明列 NOT RUN，並非整體 MVP／RC 通過。最終僅留下原持續桌布 PID 83428，未合併 main。

- 2026-10-29 最後續驗：保留主機過度比對正常 HTTP 路徑的 Red→Green 已修正；最終本機 CTest 33/33／SDK 18/18 與真實安全腳本通過。bcb6d2c 的遠端 CI PASS，最後修正另觸發。使用者已回報系統匣可開、匯入正常、移除測試完成，隔離主題目錄確認不存在；新版 Explorer 像素等未驗範圍仍明列，不宣稱完整沙箱。

- 2026-10-29 續驗：補上獨立啟動略過全域偏好的 Red→Green、WS／WSS 真實負面、移除真實 junction 12 斷言、完整本機回歸 CTest 33/33／SDK 18/18。3871e72 真正 Explorer 的原生復原與圖示重註冊通過，像素仍 NOT RUN。Computer Use pipe 故障，真正點擊／匯入／移除等待人工回報；本票維持 in-progress，遠端 CI 接續觸發。詳見 FOLLOWUP.md。

- 2026-10-29 續作：已核對 727be56、乾淨工作樹及持續桌布 PID 83428 的固定副本路徑，未關閉或替換。首次提示／HTTP 開關紅綠測試已執行；WebSocket 負面案例重現攔截缺口後，改用宿主 CSP 資產回應，決策見 `docs/adr/0001-host-controlled-theme-responses.md`。其餘驗證進行中。
- 2026-10-29：網路功能及指定真實 WebView2 負面測試通過，含取消／保存／重啟；相關管理與 Dashboard smoke 通過，詳見 PHASE3.md／STATUS。階段 3 實作先提交推送；本票保持 in-progress，繼續補原生互動、junction、完整回歸與 CI。未驗證的完整 egress／WebRTC 等仍保留 A12 gate。

- 2026-10-29：使用者因 console 過長要求階段收尾後停止並交接；此票僅記錄下一步，未實作／未執行測試。
