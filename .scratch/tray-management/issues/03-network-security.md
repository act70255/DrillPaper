# 網路設定與安全整合

Status: open

## Scope

完整三階段 spec 已由使用者確認。本階段尚未開始：將全域 HTTP／HTTPS 開關實際接入 WebView2 host，預設拒絕、首次封鎖提示不自動允許；其他 scheme、來源／導覽、CSP、權限、下載與彈窗邊界分別落實。完成真實 WebView2 負面驗證後才提供可用開關，不能只接設定模型。

## Acceptance

- 一個公開行為失敗測試後才做最小實作，保留原生實機與 unit 的證據界線。
- 真實外部 script／iframe／fetch／WebSocket／redirect／下載／權限／彈窗等驗證；未執行明列 NOT RUN。
- 接續補階段 1、2 人工驗收及移除 junction 負面測試；新管理介面真正 Explorer 重啟需再次確認。
- 全部完成後完整回歸、文件與 STATUS，再依 commit-msg skill commit＋push；RC 阻擋仍依原驗收矩陣，不移除 gate。

## Comments

- 2026-10-29：使用者因 console 過長要求階段收尾後停止並交接；此票僅記錄下一步，未實作／未執行測試。
