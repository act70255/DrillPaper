# 移除對外 SDK 文件中的個人路徑

Status: open
Type: task
Blocked by: 14

## Scope

修正整體 code review 標準面第 2 項：對外的 `sdk/author-starter/README.md` 寫死 `C:\Users\James\DrillPaperTests\...` 個人路徑。

## Acceptance

- 改用通用寫法（例如 `%USERPROFILE%\...` 或相對路徑／佔位符），說明仍可依步驟完成作者流程。
- 掃描隨 SDK ZIP 或 app 交付包散布的檔案（SDK、`scripts/trial/`、交付 README、使用者文件），一併移除其他個人路徑或使用者名稱；驗收證據（docs/acceptance）屬歷史紀錄不改。
- 跑 SDK 封裝相關測試確認文件變更未破壞封裝清單／hash 驗證（若清單含 README hash，依流程更新）。

## Comments

- 2026-10-30 決策（使用者確認）：依整體 code review 開單，交由 Codex 於 14 之後處理；每票完成即 commit＋push，不合併 main。
