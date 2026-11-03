# 票 17 安裝檔驗證紀錄

分支 `feature/rc-17-inno-setup-installer`。決策見 `.scratch/rc-delivery/issues/17-inno-setup-installer.md`。

## 候選版

| 項目 | 值 |
| --- | --- |
| 來源 commit | `54c152b542eed26a87874df6d4831335dd28df2e`（含靜態 CRT、`--exit-running`、安裝檔腳本） |
| 試用 ZIP | `DrillPaper-0.1.0-trial.9-win-x64-unsigned.zip`，610907 bytes，SHA-256 `94DEF288A17177487004AD1EB5134E808CEA53A5109F545A55CB587951320AC0` |
| 安裝檔 | `DrillPaper-0.1.0-trial.9-Setup-unsigned.exe`，2515542 bytes，SHA-256 `F0FE049A06AD44D9C5011102FEB48B4B9E9C8DA177548A5923F524ABD1C3F888` |
| 工具 | Inno Setup 6.7.3（使用者層級安裝），語言檔 `installer/ChineseTraditional.isl`（is-6_7_3 Unofficial，SHA-256 `ab22b0eb…c604`） |
| 環境 | Windows 11 專業版 25H2 build 26200.8737，WebView2 Runtime 156.0.4314.58，Trend Micro Apex One |

## 自動與 CI

| 項目 | 結果 |
| --- | --- |
| 靜態 CRT：CTest `DrillPaperStaticCrt` 先 Red（/MD 的 EXE 匯入 MSVCP140、VCRUNTIME140／140_1 與 9 個 api-ms-win-crt-*），改 `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` 後 Green；EXE 只匯入系統 DLL 與 WebView2Loader.dll（後者只匯入 KERNEL32） | PASS |
| 靜態 CRT 後完整測試（鎖定前執行）：CTest 54/54，SDK 18/18 共四組 | PASS |
| `--exit-running`：替身程序測試先 Red（stub）再 Green，涵蓋同路徑正式關閉（結束碼 0）、不同路徑不受影響、不回應時逾時回報；CLI 無實例時立即以 0 結束 | PASS |
| 試用入口：測試先 Red（入口仍檢查 VC++），移除檢查後 Green | PASS |
| 安裝檔打包契約 `test-installer-package.ps1`：缺 ISCC、試用包驗證失敗、正常產出含 SHA-256 metadata、拒絕覆寫 | PASS |
| CI `trial.yml` run 41429684943（`8987b12`）：建置、契約、ZIP、從驗證過的 ZIP 產出安裝檔；artifact `drillpaper-trial-unsigned`（595506 bytes）、`drillpaper-installer-unsigned`（1962506 bytes） | PASS |
| CI 過程中的 2 次失敗（run 41428592827、41429192452）：都是 workflow 的 `$LASTEXITCODE` 判斷問題（腳本成功時為 null；或沿用測試中預期失敗案例的 1），不是產品或打包錯誤；已分別修正（`960b588`、`8987b12`） | 已修正 |
| ISCC 警告：社群繁中語言檔缺少少數新版訊息（下載、封存檔解壓相關），改用英文；本安裝檔不使用這些功能 | 已知限制 |

## 靜默安裝／解除安裝（本機，螢幕鎖定期間執行）

以 cmd 啟動，`LOCALAPPDATA`、`TEMP`、`TMP` 導向 `%USERPROFILE%\DrillPaperTests\RC17 安裝檔\silent\`，`/DIR` 指定含空白與繁中的測試目錄。

| 項目 | 結果 |
| --- | --- |
| `/VERYSILENT` 安裝結束碼 0；安裝目錄的白名單 55 檔 SHA-256 全部與 manifest 相符，沒有額外檔案（只多 `unins000.exe／.dat`） | PASS |
| HKCU 解除安裝項目 `{DC8FDCBC-…}_is1`：顯示名稱「DrillPaper（試用版）」、版本 0.1.0-trial.9、InstallLocation 為測試目錄；未寫入 HKLM | PASS |
| 開始功能表捷徑 `%APPDATA%\Microsoft\Windows\Start Menu\Programs\DrillPaper.lnk` 指向安裝目錄的 `DrillPaper.exe --management` | PASS |
| 安裝後 EXE 沒有 VC++／UCRT 依賴；`--exit-running` 結束碼 0（此次以 PowerShell `Start-Process` 啟動，未照防毒決策改用 cmd；路徑非 Temp，未觀察攔截） | PASS |
| `/VERYSILENT` 解除安裝結束碼 0；日誌記錄 `--exit-running` 結束碼 0 與「靜默解除安裝，保留使用者資料」；安裝目錄、HKCU 項目、捷徑都已移除；隔離資料中的 `settings.json` 保留 | PASS |

## 待使用者解鎖後執行

- 完整測試套件（含管理視窗、WebView2、多螢幕原生測試）。
- 互動驗證：精靈安裝畫面、從開始功能表啟動、執行中覆蓋安裝（正式結束後替換）、解除安裝時的資料詢問（「否」保留、「是」刪除）。

## 互動驗證（2026-11-03，使用者解鎖後）

開始前執行完整測試套件：Release 建置、CTest **58/58**（新增 DrillPaperStaticCrt、DrillPaperExitRunningCli 與 3 個實例關閉整合測試），SDK／工具測試都沒有失敗。真實的 `%LOCALAPPDATA%\DrillPaper` 原本只有 10-28 建立的 WebView2 profile（388 個檔案）。已完整備份到測試目錄並比對一致，驗證結束後還原。「刪除資料」案例改在隔離資料上執行。

| 步驟 | 使用者回報 | Claude 核對 | 結果 |
| --- | --- | --- | --- |
| I1 精靈安裝（cmd 啟動，`TEMP` 導向非 Temp） | 繁中顯示正常；預設位置為 `AppData\Local\Programs\DrillPaper`；沒有 UAC；沒有 SmartScreen 或防毒警告。完成時取消「立即啟動」 | 11:15:53「Installation process succeeded」。白名單 55 檔 hash 全部相符。HKCU 解除安裝項目為「DrillPaper（試用版）」0.1.0-trial.9，InstallLocation 為預設位置；HKLM 沒有項目。開始功能表捷徑已建立。沒有啟動程式。註：使用者第一次回報時精靈仍停在前幾頁，請使用者完成後才核對 | PASS |
| I2 從開始功能表啟動 | 管理視窗出現；主螢幕出現 Minimal 桌布（首次預設）；系統匣有圖示；沒有錯誤，也沒有防毒警告 | PID 50056 於 11:17:34 由 `C:\Users\James\AppData\Local\Programs\DrillPaper\DrillPaper.exe --management` 啟動（捷徑參數正確）。Apex One `AEGIS_BM.log` 仍為 41998 bytes／2026-11-01T09:42:36，沒有新增攔截 | PASS |
| I3 執行中覆蓋安裝 | 安裝時 DrillPaper 自動結束（桌布消失、圖示不見）；沒有「檔案使用中」等錯誤；安裝完成 | 安裝日誌 11:25:24.847「DrillPaper --exit-running 結束碼：0」，表示正式結束了 PID 50056；11:25:30「Installation process succeeded」「Need to restart Windows? No」。之後沒有 DrillPaper 程序，也沒有該 profile 的 WebView2 子程序。覆蓋後 55 檔 hash 全部相符。註：第一次產生的啟動批次檔是 LF 換行，cmd 無法執行，改為 CRLF 後重新啟動 | PASS |
| I4 執行中從「設定」解除安裝並選「否」保留資料 | DrillPaper 自動結束；資料詢問顯示 `AppData\Local\DrillPaper`、預設按鈕為「否」；沒有錯誤 | 程式目錄、HKCU 項目、捷徑都已移除，沒有殘留程序。**但真實的 `%LOCALAPPDATA%\DrillPaper` 被刪除**。從「設定」啟動的解除安裝沒有日誌，無法確認當時第二題的實際選擇。已立即從備份還原，388 檔與測試前一致 | **FAIL（資料被刪；原因見重現）** |
| I4 重現（隔離資料、GUI、開日誌） | 第 1 次：在第一題「您確定要完全移除…」按「否」，因此沒有進行解除安裝；第 2 次：第一題按「是」、第二題按「否」 | 第 2 次日誌：13:17:47 第一題 User chose Yes，13:17:49「Uninstallation process succeeded」；13:17:51 第二題「是否同時刪除…」User chose No，接著記錄「使用者選擇保留資料」，隔離資料保留。程式中只有第二題選「是」才會刪除資料 | 重現：「否」正確保留 |

**判讀**：程式邏輯正確，I4 資料遺失最可能是第二題誤按「是」。根本問題是設計：Inno 內建的第一題「確定要移除？」選「是」代表繼續，緊接著的第二題選「是」卻代表刪除，兩題語意相反，容易誤按。改善方向：第二題改用明確標示動作的按鈕（「保留資料（建議）」／「刪除資料」），預設為保留。

### 修正後重驗（trial.10）

使用者決策：資料詢問改為按鈕直接寫明動作（commit `3fac3cd`，文件 `1ccf3a2`）。以 `1ccf3a2b4770ae5695be16a07e7928ee495180c3` 建置 `DrillPaper-0.1.0-trial.10-Setup-unsigned.exe`（SHA-256 `36E6533FA96D1B70AA9119ED41F2B22B2BA715AE7A0550A31960081B0B29C50A`），靜默安裝到隔離目錄並以 GUI 解除安裝（`LOCALAPPDATA` 導向隔離資料，開日誌）。

| 步驟 | 使用者回報 | Claude 核對 | 結果 |
| --- | --- | --- | --- |
| I5 新版詢問選「保留資料」 | 按鈕文字清楚，預設為「保留資料（建議）」；按下保留 | 13:30:25 第一題 Yes，13:30:28「Uninstallation process succeeded」；13:30:33 第二題回傳 Yes（＝保留），記錄「使用者選擇保留資料」；程式已移除，隔離 `settings.json` 保留 | PASS |
| I6 新版詢問選「刪除資料」（隔離資料） | 第二題顯示的路徑含 `DrillPaperTests`，按下「刪除資料」，沒有錯誤 | 13:36:13 第一題 Yes，13:36:15「Uninstallation process succeeded」；13:36:30 第二題回傳 No（＝刪除），記錄「已刪除使用者資料」，隔離資料夾確實刪除。真實 `%LOCALAPPDATA%\DrillPaper` 仍為 388 檔，與測試前一致。HKCU 項目、捷徑、程序都沒有殘留 | PASS |

## 小結

- **PASS**：I1 精靈安裝、I2 開始功能表啟動、I3 執行中覆蓋安裝（正式結束後替換）、I5 保留資料、I6 刪除資料；以及鎖定期間的靜默安裝與靜默解除安裝、CI 產出安裝檔、完整測試 58/58。
- **FAIL → 已修正**：I4 使用 trial.9 時，真實使用者資料在解除安裝時被刪除。重現證實程式只會在第二題選「是」時刪除；根本原因是兩題「是／否」語意相反，容易誤按。依使用者決策改為標示動作的按鈕，預設保留（trial.10），並以 I5、I6 重驗通過。真實資料已從備份完整還原。
- **整個驗證期間**：Apex One `AEGIS_BM.log` 維持 41998 bytes，沒有新增攔截；安裝檔與 EXE 未簽章，本機沒有出現 SmartScreen 警告。
- **NOT RUN／BLOCKED**：乾淨機器（無開發工具、缺 WebView2）上的安裝，沿用票 16 的 BLOCKED。
