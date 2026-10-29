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

- 2026-10-29 收尾：63e86ff 的 CI 40832496506 完整 PASS（CTest 33/33、SDK 18/18、SDK 還原與封裝）；本票實作及所列驗證完成，狀態設為 implemented。新版 Explorer 像素、完整 DPI／鍵盤與安全未測矩陣仍明列 NOT RUN，並非整體 MVP／RC 通過。最終僅留下原持續桌布 PID 83428，未合併 main。

- 2026-10-29 最後續驗：保留主機過度比對正常 HTTP 路徑的 Red→Green 已修正；最終本機 CTest 33/33／SDK 18/18 與真實安全腳本通過。bcb6d2c 的遠端 CI PASS，最後修正另觸發。使用者已回報系統匣可開、匯入正常、移除測試完成，隔離主題目錄確認不存在；新版 Explorer 像素等未驗範圍仍明列，不宣稱完整沙箱。

- 2026-10-29 續驗：補上獨立啟動略過全域偏好的 Red→Green、WS／WSS 真實負面、移除真實 junction 12 斷言、完整本機回歸 CTest 33/33／SDK 18/18。3871e72 真正 Explorer 的原生復原與圖示重註冊通過，像素仍 NOT RUN。Computer Use pipe 故障，真正點擊／匯入／移除等待人工回報；本票維持 in-progress，遠端 CI 接續觸發。詳見 FOLLOWUP.md。

- 2026-10-29 續作：已核對 727be56、乾淨工作樹及持續桌布 PID 83428 的固定副本路徑，未關閉或替換。首次提示／HTTP 開關紅綠測試已執行；WebSocket 負面案例重現攔截缺口後，改用宿主 CSP 資產回應，決策見 `docs/adr/0001-host-controlled-theme-responses.md`。其餘驗證進行中。
- 2026-10-29：網路功能及指定真實 WebView2 負面測試通過，含取消／保存／重啟；相關管理與 Dashboard smoke 通過，詳見 PHASE3.md／STATUS。階段 3 實作先提交推送；本票保持 in-progress，繼續補原生互動、junction、完整回歸與 CI。未驗證的完整 egress／WebRTC 等仍保留 A12 gate。

- 2026-10-29：使用者因 console 過長要求階段收尾後停止並交接；此票僅記錄下一步，未實作／未執行測試。
