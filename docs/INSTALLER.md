# 安裝檔（Inno Setup）

DrillPaper 提供兩種試用交付形式，內容完全相同，都來自同一份白名單 `scripts/trial-files.json`：

| 形式 | 檔名 | 用法 |
| --- | --- | --- |
| 免安裝 ZIP | `DrillPaper-<版本>-win-x64-unsigned.zip` | 解壓到任意資料夾，執行 `Start-DrillPaper.cmd` |
| 安裝檔 | `DrillPaper-<版本>-Setup-unsigned.exe` | 點兩下安裝，從開始功能表開啟 |

兩者都標示 **trial（試用版）** 與 **unsigned（未簽章）**，都不是正式 RC 或公開發行版。決策與範圍見票 17（`.scratch/rc-delivery/issues/17-inno-setup-installer.md`）。

## 給使用者：安裝與移除

- **需求**：Windows 10／11 x64，以及 Microsoft Edge WebView2 Runtime（Evergreen，Windows 11 大多已內建）。不需要 VC++ 可轉散發套件，app 已靜態連結 C/C++ 執行環境。
- **安裝**：執行 `DrillPaper-<版本>-Setup-unsigned.exe`，依精靈完成。只安裝給目前使用者，裝到 `%LOCALAPPDATA%\Programs\DrillPaper\`，**不需要管理員權限**。完成後可從開始功能表的「DrillPaper」開啟管理視窗。缺少 WebView2 時，安裝程式會顯示官方下載網址，並讓你決定是否繼續。
- **覆蓋安裝（更新到新試用版）**：直接執行新的安裝檔。安裝程式會先要求執行中的 DrillPaper 正式結束（和系統匣的「結束 DrillPaper」相同），結束後才替換檔案；無法結束時會停止並提示你手動結束。
- **解除安裝**：在「設定 → 應用程式 → 已安裝的應用程式」找到「DrillPaper（試用版）」並解除安裝。程式會先正式結束 DrillPaper，再移除程式檔與捷徑，最後詢問「要保留 DrillPaper 的使用者資料嗎？」，按鈕直接寫明動作：〔保留資料（建議）〕〔刪除資料〕，對象是 `%LOCALAPPDATA%\DrillPaper`（設定、匯入的主題、日誌）。**預設為保留**；靜默解除安裝（`/VERYSILENT`）一律保留。
- **未簽章提醒**：安裝檔與程式都沒有程式碼簽章，Windows SmartScreen 或企業防毒（例如 Trend Micro Apex One）可能警告或攔截。請確認檔案來自可信來源，並核對 metadata 中的 SHA-256；企業環境請向 IT 申請例外，不要自行停用防毒。

## 給維護者：產生安裝檔

需求：Inno Setup 6（例如 `winget install JRSoftware.InnoSetup --scope user`；GitHub `windows-2022` 映像已內建）。

```powershell
./scripts/build-trial.ps1 -SourceCommit <完整 40 碼 commit SHA> -Version 0.1.0-trial.9
./scripts/build-installer.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.9-win-x64-unsigned.zip -SourceCommit <同一個 SHA>
```

- `build-installer.ps1` 會先以 `verify-trial-archive.ps1` 重新驗證 ZIP（白名單、逐檔 hash、來源 commit），通過後才解壓到輸出目錄下的暫存資料夾（不使用 `%TEMP%`）並呼叫 ISCC。
- 輸出 `DrillPaper-<版本>-Setup-unsigned.exe` 與同名 `.json` metadata，內含版本、來源 commit、`signed=false`、安裝檔 SHA-256 與來源 ZIP SHA-256。同版本已存在時拒絕覆寫。
- 找不到 ISCC 時會以繁中錯誤停止；可用 `-IsccPath` 或環境變數 `ISCC_PATH` 指定位置。
- CI：推送到 `feature/rc-*` 分支時，`trial.yml` 會產出 artifact `drillpaper-installer-unsigned`。
- 契約測試：`./scripts/test-installer-package.ps1` 涵蓋缺編譯器、試用包驗證失敗、正常產出與拒絕覆寫。

## 技術說明與已知限制

- 腳本：`installer/DrillPaper.iss`。`PrivilegesRequired=lowest`，固定 AppId `{DC8FDCBC-C926-406F-9B9C-DBA6294EAD9C}`，`CloseApplications=no`，改由 `[Code]` 呼叫 `DrillPaper.exe --exit-running`。`--exit-running` 只會對**同一路徑**的實例送出正式結束命令並等待 15 秒；其他位置的 ZIP 副本不受影響。
- 解除安裝刪除資料時，資料位置取自 `LOCALAPPDATA` 環境變數，和 app 相同。
- 介面語言使用 Inno Setup `is-6_7_3` 標籤中社群維護的 `ChineseTraditional.isl`（Unofficial）。其中少數新版訊息（下載、封存檔解壓相關）尚未翻譯，會以英文顯示；本安裝檔不使用這些功能。
- 不在範圍：程式碼簽章、MSI／MSIX、所有使用者安裝、開機自動啟動、單一免安裝 EXE。
