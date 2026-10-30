# DrillPaper RC 09 — 拒絕放行

2026-10-30。完整本機 Release configure／build、CTest43/43、SDK18/18（封裝鏈重複四組）、新工具6/6與其他工具17/17通過；正式封裝入口執行完整測試後仍被 gate 阻擋，沒有正式 RC ZIP。既有 CI 最新只對應舊 main b4616ec，RC job skipped、artifact 只有 SDK 範例；不能作為目前來源的 app CI。

08 候選 trial.6（ZIP SHA FC08E190…9EFF8A5）保留；09 依已確認的本機產品預設多輪條件移除新入口繞行，另產 trial.7，ZIP SHA `87FE10E27EB016D144F8C775BEEA4C81C724BD513BDDE61DE9F866465FDBC29D`，472507 bytes。兩包 EXE／SDK／主題相同、均未簽章；trial.7 只改 CMD／README 與 manifest。新入口三輪通過不代表智慧休眠或 RC 全部通過，03／08-D1 原 FAIL 保留，本輪未重現不宣稱根因已修復。

**新的必要 FAIL：09-D2**，雙目標受控鎖定往返後解除手動暫停，兩宿主沒有在原期限恢復指標推送，原因未定，由票10診斷。完整安全、真正桌面／Explorer／電源／硬體、NVIDIA、獨立作者 GUI、乾淨使用者／更新／回復／移除及對應來源 CI 等仍不足，票11承接。必要 FAIL 或缺證任一存在就拒絕放行。

僅在明列限制下試用，優先用 Preview；依包內 README 核對 hash、使用非 Temp 使用者目錄及 CMD 入口。已有保存為關閉的智慧休眠偏好不自動更動；不藉試用取代原持續桌布或重啟 Explorer。不宣稱完整沙箱、全程序零外連、沒有洩漏或已簽章。

完整版本、原始證據、命令、A01～A16、owner／下一步與人工清單見 [RC09報告](acceptance/2026-10-30/rc-regression/REPORT.md)、[必要gate](acceptance/2026-10-30/rc-regression/GATES.md)、[最終交接](FINAL_HANDOFF.md)。本頁不是發布公告；沒有合併 main、公開發布、release 或 tag。
