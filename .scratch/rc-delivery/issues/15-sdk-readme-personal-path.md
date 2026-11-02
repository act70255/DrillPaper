# 移除對外 SDK 文件中的個人路徑

Status: implemented
Type: task
Blocked by: 14

## Scope

修正整體 code review 標準面第 2 項：對外的 `sdk/author-starter/README.md` 寫死 `C:\Users\James\DrillPaperTests\...` 個人路徑。

## Acceptance

- 改用通用寫法（例如 `%USERPROFILE%\...` 或相對路徑／佔位符），說明仍可依步驟完成作者流程。
- 掃描隨 SDK ZIP 或 app 交付包散布的檔案（SDK、`scripts/trial/`、交付 README、使用者文件），一併移除其他個人路徑或使用者名稱；驗收證據（docs/acceptance）屬歷史紀錄不改。
- 跑 SDK 封裝相關測試確認文件變更未破壞封裝清單／hash 驗證（若清單含 README hash，依流程更新）。

## Comments

- 2026-10-30 完成：從乾淨 HEAD `746d66af9dbdb2e010f3dbc2eb3f8ba8a65fa482` 建立 `feature/rc-15-sdk-personal-path`，票 14 已 implemented，前提成立且無決策衝突。作者 README／theme-sdk 使用 `$env:USERPROFILE` 與 `Join-Path`，試用 README 使用 `%USERPROFILE%`；開發交接改用 `$env:APPDATA`，環境文件移除個人工作區名稱。SDK、scripts/trial、實際交付來源與現行使用者文件掃描 0 筆個人名稱／絕對使用者路徑；歷史驗收證據與 STATUS 歷史紀錄不改。
- 驗證：最終 `scripts/test-sdk-package.ps1` PASS（來源兩組／解壓一組 SDK 各18/18、兩次重封相同 SHA、必要清單與兩個 DMT 驗證），另保留 SDK ZIP 44 entries／64874 bytes，SHA `663322E82D4AE5DE0A1AEC2CAD6C5399166BDFE0A73843B1F33746395CD2F94B`。獨立作者 npm ci／configure／固定 TypeScript5.9.3 正負型別檢查／build／DMT封裝與驗證 PASS；公開 trial 封裝使用假程式 fixture，55檔白名單＋manifest、逐檔／工具／ZIP hash／內外manifest及兩包內容掃描 PASS，不啟動產品。清單無需手改 README hash，由正式工具重算。
- 首次作者流程保留 FAIL：既有封裝器以 .NET 工作目錄解析相對輸出，下一步找不到 DMT。票內文件改為從 `$PWD.Path` 建立完整輸出路徑，兩步共用；最終來源重新封裝與作者流程通過。封裝器相對路徑行為本身留後續工具票，不在本票修改；非決策衝突，不推定防毒根因。
- 證據／限制：`docs/acceptance/2026-10-30/sdk-personal-path/REPORT.md` 與原始 log／hash。測試放非 Temp 使用者繁中空白目錄，TEMP／TMP同樣隔離；首次相對路徑偏移已記錄並將該單一檔移回。沒有產品實測／Explorer操作或83428關閉替換；未觀察攔截但未讀防毒日誌，不宣稱完整觀測。完整套件、CI、正式app／RC重封與獨立作者人工GUI標 NOT RUN，報告附原因及人工清單；既有RC gate保留。依AGENTS更新STATUS、兩軸審查Standards0／Spec0後使用commit-msg產生繁中Conventional Commit，只commit一次並push本票分支，不合併main、不公開發布。

- 2026-10-30 決策（使用者確認）：依整體 code review 開單，交由 Codex 於 14 之後處理；每票完成即 commit＋push，不合併 main。
