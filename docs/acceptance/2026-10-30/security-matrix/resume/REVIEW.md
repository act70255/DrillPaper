# RC 04 兩軸審查

基準：`1c62cc41e54a642f5ae5ed0d723e9b0893cef542`。依使用者要求先完成驗證／審查、只提交一次，採 `git diff HEAD` 加所有新增檔案；提交列表為空。依 implement／code-review 技能分別交由兩個只讀子代理審查。

## Standards

初查 1 項：NetLog 檢查與彙整入口直接 throw，會顯示原始 Node.js 堆疊，不符合 AGENTS 的繁中友善錯誤規範。新增錯誤契約測試取得 Red，再加入入口 catch、繁中提示、非零退出，詳細錯誤留忽略的 artifacts/security-netlog-errors.log。複查未解決項 **0**，未發現新增架構／規範違反或需修正 smell。

## Spec

初查 1 項：只要求至少一份 NetLog，可能遺漏管理／獨立重啟其中一次 capture。新增兩次預期啟動但缺一份日誌的案例取得 Red；launcher request 顯式記錄 captureNetwork，檢查器逐一核對預期檔案，缺任一份／無可辨識啟動紀錄時拒絕通過。舊唯讀證據缺該欄位時依管理／Preview 啟動參數辨識。複查未解決項 **0**，無新增 scope creep。

三項工具案例 [Red](review-red.log) → [Green](review-green.log) 3/3。完整原始／新版實機 NetLog 以修正工具重播仍分別為 [Red](red-final.log)／[Green](green-final.log)，新版預期三份皆存在。產品 EXE 未因工具審查修正再變動，因此不重跑已完成的 GUI 或完整測試套件。

兩軸各 1 項已修正，最終 Standards 0、Spec 0；不影響報告明列的 PARTIAL／NOT RUN 或 RC gate。

最終工具相容性檢查另重現 Windows PowerShell 5.1 解析新增 security-process.ps1 失敗（缺 UTF-8 BOM），補 BOM 後三個 PS 腳本皆通過，見 windows-powershell-parser-red.log／windows-powershell-parser.log。只變更編碼標記，產品 EXE／實機結果不變。
