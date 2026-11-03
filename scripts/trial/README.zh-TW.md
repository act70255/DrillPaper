# DrillPaper

把即時系統資訊（CPU、記憶體、磁碟、網路、時間、可用時的 GPU）顯示在 Windows 桌布上的桌面監控工具。版本、產品來源 commit 與每個檔案的 SHA-256 記錄在 `package-manifest.json`；執行 `DrillPaper.exe --version` 可確認版本。

> **本程式沒有程式碼簽章。** Windows SmartScreen 或企業防毒（例如 Trend Micro Apex One）可能警告或攔截。請只從可信來源取得，並核對發布頁提供的 SHA-256；企業環境請向 IT 申請針對該檔案與 hash 的例外，不要自行停用防毒。

## 系統需求

- Windows 10／11 x64（目前只在 Windows 11 25H2 實機驗證）。
- Microsoft Edge WebView2 Runtime（Evergreen）。Windows 11 大多已內建；若沒有，請從 https://developer.microsoft.com/microsoft-edge/webview2/ 取得，一般使用者即可安裝。
- 不需要 Microsoft Visual C++ 可轉散發套件（程式已靜態連結 C/C++ 執行環境），不需要 Node、Python 或 Visual Studio。

## 安裝與啟動

兩種方式擇一，內容完全相同：

- **安裝檔**：執行 `DrillPaper-<版本>-Setup.exe`，依精靈完成。只安裝給目前使用者（`%LOCALAPPDATA%\Programs\DrillPaper`），不需要管理員權限；完成後從開始功能表開啟「DrillPaper」。
- **免安裝 ZIP**：把 `DrillPaper-<版本>-win-x64.zip` 完整解壓到任意使用者資料夾（建議不要放在 Temp），雙擊 `Start-DrillPaper.cmd`。入口會先檢查檔案與 WebView2，失敗時顯示繁中說明並停留讓你閱讀；只想檢查可執行 `Start-DrillPaper.cmd -CheckOnly`。不要只複製單一 EXE。

## 使用

- 開啟後會出現管理視窗；第一次使用預設為 Minimal 主題、只顯示在主螢幕、主題網路關閉。
- 在管理視窗選擇主題、桌布或 Preview 模式、要顯示的螢幕與網路設定，按「套用並儲存設定」生效；「取消設定變更」會還原草稿。關閉管理視窗只是隱藏，程式會留在系統匣。
- 系統匣圖示可重新開啟管理視窗、暫停／繼續，或「結束 DrillPaper」正式退出。
- 每個選取的螢幕各自顯示完整主題，未選的螢幕保留 Windows 桌布。選取的螢幕全部離線時，暫時顯示在主螢幕，接回後自動恢復原選擇。
- 智慧休眠預設開啟：鎖定、螢幕關閉或前景有全螢幕程式時會暫停更新以省電，恢復後自動繼續。
- 可匯入第三方主題（`.dmt`）。**只匯入你信任的主題**，主題內容沒有沙箱化。主題網路預設關閉；開啟後只允許 HTTP／HTTPS 資源。主題作者資源與工具在 `sdk/`、`docs/`、`scripts/`。

## 資料位置、更新與移除

- 使用者資料（設定、匯入的主題、日誌、WebView2 瀏覽器資料）在 `%LOCALAPPDATA%\DrillPaper`，與程式檔分開。
- **更新**：安裝檔直接執行新版即可，安裝程式會先正式結束執行中的 DrillPaper；ZIP 版請先從系統匣「結束 DrillPaper」，再把新版解壓到新的資料夾使用。
- **移除**：安裝檔版從「設定 → 應用程式」解除安裝，最後會詢問「要保留 DrillPaper 的使用者資料嗎？」，預設保留。ZIP 版先從系統匣結束，再刪除解壓資料夾。兩者都不會自動刪除 `%LOCALAPPDATA%\DrillPaper`；確定不再使用時再手動刪除。

## 已知限制

- 沒有程式碼簽章；可能被 SmartScreen 或企業防毒警告。
- 單一螢幕被全螢幕程式覆蓋時，所有螢幕會一起暫停並暫時顯示 Windows 原桌布。
- 程式本身沒有遙測，但 WebView2 元件仍可能有自身的背景網路流量（例如 WPAD），不宣稱整個程式零外連。
- NVIDIA GPU 讀值需要既有的 NVIDIA 驅動；沒有支援時顯示 unavailable。
- 目前只在單一 Windows 11 環境、雙螢幕（DPI 144／96）驗證；其他 Windows 版本、WebView2 版本、硬體與乾淨使用者環境尚未驗證。

授權：第一方程式為 Apache-2.0；第三方授權見 `LICENSE`、`THIRD_PARTY_NOTICES.md` 與 `resources/licenses`。
