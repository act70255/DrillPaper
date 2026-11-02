# Inno Setup 安裝檔

Status: open
Type: task
Owner: James（發行維護者）
Blocked by: 無（下方「待決策」須在派工前確認）

## Scope

在現有免安裝 ZIP 之外，新增以 Inno Setup 產生的單一安裝檔（例如 `DrillPaper-<版本>-Setup.exe`）。安裝內容沿用 `scripts/trial-files.json` 的白名單，與 ZIP 相同，不另外維護一份清單。ZIP 流程保留。

不在範圍：程式碼簽章、MSI／MSIX、單一免安裝 EXE（主題資源嵌入）、開機自動啟動、正式 RC blocker（`scripts/package.ps1`）的處理。

## Acceptance

- 從明確 commit 的 Release 建置產生安裝檔，內容逐檔對應白名單並保存 SHA-256；不帶入個人設定、日誌、測試證據或建置暫存。打包腳本對缺檔、空檔、白名單不符要拒絕並給友善錯誤（先寫失敗測試）。
- 預設**使用者層級安裝**：裝到 `%LOCALAPPDATA%\Programs\DrillPaper\`，不需要管理員權限、不寫 HKLM。建立開始功能表捷徑；「設定 → 應用程式」可解除安裝。
- 安裝前檢查 WebView2 Evergreen Runtime 與 VC++ x64 執行環境，缺少時顯示繁中友善訊息與官方取得方式（依下方決策決定是否隨附）。不擅自修改系統。
- 安裝、覆蓋安裝與解除安裝前，正常關閉執行中的 DrillPaper（常駐系統匣），不能強制終止後留下檔案鎖。目前 app 沒有單一實例 mutex，須評估 Inno Setup 的 Restart Manager（`CloseApplications`）是否足夠，或在 app 加入 `AppMutex` 所需的具名 mutex。
- 解除安裝會移除程式檔與捷徑；`%LOCALAPPDATA%\DrillPaper` 的設定、匯入主題、日誌依下方決策處理，不得默默刪除。
- 安裝檔與內含的 EXE 都標示未簽章；README／安裝說明須寫明可能被 SmartScreen 或企業防毒攔截，以及處理方式（核對 hash、向 IT 申請例外），不宣稱已簽章。
- CI：`trial.yml`（或新的 workflow）在 `feature/rc-*` 推送時一併產出安裝檔 artifact；不建立 release／tag。
- 驗證（依 spec 防毒決策：非 Temp 目錄、EXE 不經 PowerShell 啟動、記錄攔截）：
  - 本機以隔離方式驗證安裝、啟動、覆蓋安裝、解除安裝與資料保留。不可影響使用者現用的 DrillPaper 資料，必要時先備份並證明還原。
  - 乾淨機器上的安裝與缺依賴情境，沿用票 16 的 BLOCKED，有環境時再補。
- 更新 `docs/TRIAL_PACKAGE.md`（或新增安裝文件）與 README 的安裝、移除說明，並記錄 STATUS。

## 待決策（派工前確認）

1. **VC++ 執行環境**：(a) 安裝檔隨附 VC++ Redistributable（需要管理員權限，與「使用者層級免提權」衝突）；(b) 改為靜態連結 CRT（`/MT`，需修改 `CMakeLists.txt` 的 `MSVC_RUNTIME_LIBRARY` 並重跑完整測試）；(c) 維持現狀，只檢查並提示。
2. **解除安裝時的使用者資料**：詢問是否刪除，或一律保留並提示位置。
3. **安裝範圍**：只支援使用者層級，或也提供「所有使用者」（需要管理員權限）。
4. **版本命名**：沿用 `0.1.0-trial.N` 標示試用，或另定安裝檔的版本規則。

## Comments

- 2026-11-02：使用者要求開票（詢問打包形式後決定採用 Inno Setup 單一安裝檔）。尚未決策、尚未派工。參考：目前 ZIP 約 470 KB；CRT 為 `/MD`（`CMakeLists.txt:82`）；app 沒有單一實例 mutex。
