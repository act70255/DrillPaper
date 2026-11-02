# RC 15 — SDK 文件通用路徑

## 需求與方案（實作前）

- 已確認需求：`.scratch/rc-delivery/issues/15-sdk-readme-personal-path.md`；移除對外作者文件的個人路徑，掃描 SDK、試用交付清單與使用者文件，確認封裝清單及 hash 驗證不受影響。
- 從乾淨 HEAD `746d66af9dbdb2e010f3dbc2eb3f8ba8a65fa482` 建立 `feature/rc-15-sdk-personal-path`；票 14 已 implemented，前提成立，未發現決策衝突。已讀 AGENTS、handoff、ARCHITECTURE、相關 STATUS 及 spec 的防毒／人工驗收決策。
- 文件方案：PowerShell 範例以 `$env:USERPROFILE` 與 `Join-Path` 建立 SDK 根路徑，明確指出實際解壓位置；CMD 範例以 `%USERPROFILE%` 展開。同步作者 README、theme-sdk 及現行使用／開發交接文件；歷史驗收證據不改。
- 純文件修正，未改產品、SDK API、封裝工具或白名單；沿用既有 SDK ZIP／試用封裝公開驗證，不新增測試、不虛構 Red。
- 相關驗證：`scripts/test-sdk-package.ps1`（兩次封裝 SHA 相同、解壓清單、SDK 與 DMT 驗證），另由公開試用封裝入口驗證白名單與逐檔／ZIP hash。於非 Temp 使用者繁中空白目錄執行；不啟動產品 EXE。完整套件留收尾，不執行。

## 結果

- **PASS — 文件與來源掃描**：作者 README／theme-sdk 改為 `$sdkRoot`、`$env:USERPROFILE`、`Join-Path`，CMD 資料目錄改為 `%USERPROFILE%`；FINAL_HANDOFF 的 CMake 路徑改為 `$env:APPDATA`，ENVIRONMENT 移除個人工作區路徑。掃描 SDK、scripts/trial、SDK 打包工具與測試、根目錄交付文件及現行 docs，個人名稱／Windows Users／macOS Users／Linux home 絕對路徑皆 0 筆，見 [source-scan.log](source-scan.log)。docs/acceptance 與 STATUS 歷史命令／owner 紀錄排除，既有證據不改。
- **PASS — 最終 SDK ZIP**：`pwsh -NoProfile -File scripts/test-sdk-package.ps1` exit 0；兩次重封 SHA 相同，三組 SDK 各 18/18（來源兩次＋解壓一次，共 54 次執行，非 54 個獨立案例），必要清單、授權、無本機建置產物、兩個 DMT validator 均通過。另 `scripts/package-sdk.ps1 -OutputFile <使用者測試目錄>/final-sdk.zip` exit 0，額外來源 SDK 18/18。最終 ZIP 44 entries、64874 bytes，SHA-256 `663322E82D4AE5DE0A1AEC2CAD6C5399166BDFE0A73843B1F33746395CD2F94B`；完整內容掃描無個人路徑。最終輸入以 [source-hashes.json](source-hashes.json) 追溯；log 見 [封裝驗證](raw-logs.zip)／[保留 ZIP](raw-logs.zip)。SDK ZIP 沒有持久化 README hash 清單；試用包 hash 由封裝器重算，不手改舊 manifest。
- **PASS — 實際作者命令**：從 final-sdk.zip 解壓到使用者繁中空白目錄，複製獨立作者範本；照更新文件執行 `npm ci --ignore-scripts --no-audit --no-fund`、`npm run configure -- (Join-Path $sdkRoot 'sdk\javascript')`、`npm run check`、`npm run build` 及兩個正式封裝／驗證腳本。固定 TypeScript 5.9.3，正用法通過，四個刻意錯誤由 compiler 拒絕；輸出 DMT 六檔，SHA-256 `82BF38D3743A3F6ADCBFCC31D754B5E776D3A3B815DFB7F49A47F83C7CEE8546`，見 [final-author-flow.log](raw-logs.zip)。
- **PASS — app 交付封裝契約**：以 `scripts/package-trial.ps1`、目前來源目錄及白名單所需的假程式／資產文字檔封裝，版本 `0.1.0-trial.rc15docsfinal`、sourceCommit=`a`×40 明確為 fixture。55 檔白名單＋manifest 共 56 entries 恰好相符，逐檔／工具／ZIP hash 與內外 manifest 一致，內容掃描無個人路徑；ZIP SHA-256 `8B84D9F7795C18941D58AEE8BD716D1E7EE966BB84C1FA8C57E5E8FAC5BF8E7D`。見 [final-delivery-hash-scan.log](raw-logs.zip) 及 [artifact-hashes.json](artifact-hashes.json)。此 ZIP 不含可執行產品，不是 app 驗收／交付，不公開發布。

## 首次結果與同票文件修正

- 首版通用路徑的 SDK 封裝驗證已通過（SHA `A60F0037D071D26A260D3CD8ED3EEA4C30DB7B3C4F9E2C63CF9E038F811789E1`），保留 [原 log](raw-logs.zip)。作者型別檢查及建置通過，但照舊相對輸出命令執行後，下一步 `validate-theme-package.ps1 -Path ..\my-theme.dmt` **FAIL**：找不到檔案。
- 已查證既有 `package-theme.ps1:13` 使用 `[IO.Path]::GetFullPath($OutputFile)`，以 .NET 工作目錄解析輸出；PowerShell `$PWD` 不一定相同。本次產出至工作區父目錄而非指定使用者測試目錄；確認檔案身分後將該單一輸出移回測試目錄的 `first-run-misplaced.dmt` 留存。原始作者 log 見 [author-flow.log](raw-logs.zip)，未把此失敗推定為產品或防毒原因。
- 文件改為 `$themePackage = Join-Path (Split-Path -Parent $PWD.Path) 'my-theme.dmt'`，兩步共用完整路徑；不修改封裝工具行為，仍在票內「作者步驟可完成」範圍，與已確認決策無衝突。最終全部相關封裝與作者流程已重驗通過；前輪結果不套用到新 hash。相對輸出解析本身留後續工具票評估。

## 執行環境、限制及人工清單

- Windows 11、Node 24.17.0／npm 11.12.1／PowerShell 7.6.3。CMD `%USERPROFILE%` 展開及 `$env:APPDATA` 既有 CMake 路徑檢查 PASS，見 [path-examples.log](path-examples.log)。測試目錄為 `%USERPROFILE%\DrillPaperTests\RC15 SDK 路徑 20261030-183301`；TEMP／TMP 都指向其 `staging`，SDK 解壓、作者建置及 ZIP 均在該目錄，首次相對輸出偏移另如上記錄。
- 未啟動產品 EXE，沒有產品測試並行、Explorer 操作或 PID 83428 終止／替換。不需 WebView2／硬體整合。未觀察工具攔截；本票未讀取防毒事件，因此不宣稱完整觀測或無攔截，沒有已證實受攔截而需標 BLOCKED 的項目。
- **NOT RUN — 完整 CTest／整體 test.ps1／CI／正式 app 或 RC 重封**：依使用者要求留收尾；本票只跑相關 SDK、型別與封裝契約，不解除任何既有 RC gate。
- **NOT RUN — 人工獨立作者與 GUI**：文件修正不要求產品畫面；如需後續完整作者驗收，請獨立使用者在自己的非 Temp 目錄解壓 SDK，依 README 設定實際 `$sdkRoot` 並重走建置／封裝，再於 app 管理視窗匯入、預覽、切換，檢查版面。若防毒攔截，記產品／規則／時間／hash／啟動方式並標 BLOCKED；不更改防毒、不重啟 Explorer、不關閉／替換原持續桌布。未將本票自動結果當成人工 PASS。
- 近端 Nowledge thread search：MCP／normal／default，query=`DrillPaper 15 SDK README 個人路徑`，limit 5；rank 1 thread `claude-code-520d0537-258a-452c-83de-6dd41aeef343`，標題「DrillPaper RC 票 12 修復並派發票 13」，score 31.93891296386719，摘要提及票 14 已推送。前置判定仍以 repository 票 14 implemented 及 Git HEAD 為準，未額外還原整段歷史。

## 審查與提交

依 implement／code-review 兩個唯讀代理平行審查，沒有執行測試或修改檔案。基準 `746d66af9dbdb2e010f3dbc2eb3f8ba8a65fa482` 已解析；為遵守本票僅 commit 一次，審查命令採 `git diff --cached 746d66af9dbdb2e010f3dbc2eb3f8ba8a65fa482`，提交清單 `git log 746d66af9dbdb2e010f3dbc2eb3f8ba8a65fa482..HEAD --oneline` 此時為空。最終 `git diff --cached --check` PASS；原始 log 以 raw-logs.zip 保留位元，避免改寫工具自帶空白。

## Standards

0 項硬性違規，0 項需處理的 smell。已審查實際暫存差異、AGENTS／spec／架構規則及封存原始日誌。文件採繁中、通用環境路徑與明確的 SDK 根目錄說明；未改產品或架構邊界。既有失敗與最終通過結果分開保留，完整套件及人工項目標示 NOT RUN 並附原因。原始日誌中的個人資訊僅位於驗收證據，符合歷史紀錄例外。

## Spec

0 項發現。暫存差異符合票 15 的通用路徑、散布檔案掃描與 SDK 封裝驗證要求；未修改歷史驗收證據或產品／封裝工具。已核對原始驗證紀錄，最終 ZIP 內兩份作者文件與目前來源 hash 相符。首次相對輸出失敗及文件修正已如實保留；完整套件與人工 GUI 的 NOT RUN 原因、後續步驟均有記錄。未發現需求缺漏、錯誤實作或範圍擴張。

Standards 0／Spec 0，兩軸均無待修正項。更新 ticket／STATUS 後，以 commit-msg 依實際暫存差異產生訊息，僅 commit 一次並 push 本票 feature 分支；commit hash 以 Git 記錄為準，不合併 main、不公開發布。
