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
