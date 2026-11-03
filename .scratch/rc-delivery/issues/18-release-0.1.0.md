# 發布 0.1.0（GitHub Pre-release）

Status: resolved
Type: task
Owner: James（發行維護者）
Blocked by: 無

## Scope

把產品版本設為 `0.1.0`，由 GitHub Actions 依 tag `v0.1.0` 從該 commit 乾淨建置、測試、打包免安裝 ZIP 與 Inno Setup 安裝檔，並建立 GitHub Pre-release。repo 為 PRIVATE，Release 只有協作者看得到。依據為票 11 的有條件放行判定（`docs/acceptance/2026-11-02/rc-gate-evidence/REPORT.md` 已知限制清單）。

不在範圍：程式碼簽章、移除 `scripts/package.ps1` 的 RC blocker、公開 repo、MSI／MSIX。

## Acceptance

- 產品版本字串（`--version`、主題握手的 `hostVersion`）改為 `0.1.0`，與 CMake `project(VERSION 0.1.0)` 一致；版本不一致時 release workflow 要 fail-fast。
- 打包流程接受正式版號 `X.Y.Z`，同時保留 `X.Y.Z-trial.N`：正式版檔名為 `DrillPaper-0.1.0-win-x64.zip` 與 `DrillPaper-0.1.0-Setup.exe`，試用版維持原本 `-unsigned` 命名；manifest 區分 `kind`（release／trial），驗證腳本兩種都能驗。安裝檔顯示名稱依版本類型區分。先寫失敗測試。
- 新增 `.github/workflows/release.yml`：推送 `v*.*.*` tag 時，檢查 tag 與產品版本一致，執行建置與原生測試、打包 ZIP、驗證白名單與 hash、產生安裝檔，附上 metadata 與 `SHA256SUMS.txt`，以 `--prerelease` 建立 Release。不覆寫既有 Release。
- 繁中 Release notes：功能、安裝與移除、系統需求、**未簽章**與防毒提醒、已知限制、SHA-256 核對方式。包內 README 改為不綁定特定試用版號的使用說明。
- 經 PR 合併 main 後，在 main 打 `v0.1.0` tag 並推送；確認 workflow 成功、Release 為 Pre-release、資產齊全，並下載驗證 hash 與白名單。
- 更新 STATUS、INSTALLER／TRIAL_PACKAGE 文件與本票；每步 commit＋push。

## Comments

- 2026-11-03 實作（Claude）：
  - `6d819ef`：產品版本以 CMake `project(VERSION)` 為唯一來源（產生 `desktopmonitor/version.h`），`--version` 與握手 `hostVersion` 改為 0.1.0；CLI 輸出被導向時以 UTF-8 寫入。CTest `DrillPaperVersionCli` 先 Red 再 Green。
  - `fc57050`：打包接受 `X.Y.Z` 與 `X.Y.Z-trial.N`；正式版 kind=release，檔名不帶 trial／unsigned；驗證腳本檢查 kind 與版號一致；安裝檔顯示名稱依版本類型區分；入口訊息中性化。兩支契約測試與入口測試先 Red 再 Green。
  - `93c9310`：`.github/workflows/release.yml`、`docs/release-notes/0.1.0.md`、包內 README 改寫、安裝檔說明。
  - 本機演練（從 `93c9310` 乾淨建置 0.1.0）：ZIP 通過白名單與 hash 驗證，EXE 回報 `DrillPaper 0.1.0`，產出 `DrillPaper-0.1.0-win-x64.zip`／`.json`、`DrillPaper-0.1.0-Setup.exe`／`.json`；靜默安裝後「設定 → 應用程式」顯示「DrillPaper」0.1.0，靜默解除安裝無殘留。
  - 完整測試：CTest 61/61，node／SDK 測試 fail 0。

- 2026-11-03 決策（使用者確認）：
  1. 版本設定為 0.1.0 並在 GitHub 發布。
  2. Release 類型：Pre-release。
  3. 檔名完全不標示：`DrillPaper-0.1.0-win-x64.zip`、`DrillPaper-0.1.0-Setup.exe`（不含 trial、unsigned）；未簽章仍須在 Release notes 與說明中寫明。
  4. 建置來源：GitHub Actions 依 tag 建置。
  5. `scripts/package.ps1` 的 RC blocker 保留，改走已驗證的 build-trial／build-installer 流程（放寬版號格式接受 0.1.0）。
