# 03／7A 首次試用包驗收（2026-10-30）

本輪接續 `feature/rc-03-trial-package` 未提交工作，不另開分支、不重建產品。依兩條使用者確認決策，入口改為 `--management --no-smart-sleep` 並沿用保存模式，試用包可自動執行的驗收完成。**預設智慧休眠啟動仍為 FAIL**，05 診斷／修正，08 移除繞行、回到產品預設重包重驗，09 持續列 gate；不能以本票 PASS 解除。這是 unsigned 試用包，非 RC 或公開發行。

上輪報告另完整保留在 [REPORT-2026-10-29.md](REPORT-2026-10-29.md)，下方歷史紀錄也保留。原 trial.1～3 未覆寫；trial.3 ZIP SHA-256 核對仍為 `4CA2300347C77BB37B18DA4B329A940B760564E60DD880504A3BA6B8359C6E69`。

## 本輪新產物與來源

| 項目 | 值 |
| --- | --- |
| 版本／ZIP | `0.1.0-trial.4`／`artifacts/DrillPaper-0.1.0-trial.4-win-x64-unsigned.zip`，434303 bytes |
| ZIP SHA-256 | `C3ECF566EAB58D4A015D44D749E60F1E6872F5830F31AEB0F3B303ECC40C3287` |
| EXE SHA-256 | `B0FF9A734713AF939C6444092B6D008DEDEF9480A17932D1B4B9D92C0FE71781` |
| 產品來源 commit | `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53`，沿用上輪乾淨 Release 位元與 [provenance](build-provenance.json) |
| 本輪起始 HEAD | `fe292da667a94adfa0bf7c0de87dd14bca08a579`，只比產品來源多 05 決策文件，產品無差異 |
| 環境 | Windows 11 Pro 26200.8737、一般使用者 token；WebView2 Runtime 156.0.4314.50、SDK／loader 1.0.2478.35、VC++ 14.52.37025.0（最低 14.44.35112.0），見 [本輪環境](trial4-environment.json) |

[新 metadata](trial4-package-metadata.json) 記錄逐檔、EXE、ZIP 及封裝工具 SHA-256。工具／入口模板取本票工作樹，與產品來源 commit 分開識別；包內 EXE --version 仍是既有 0.1.0-dev。白名單 27 檔加 manifest，兩主題目錄、SDK 執行資產、loader 與授權均在 ZIP；設定、匯入內容、日誌、證據、憑證、建置暫存、NVML 與系統 CRT 均未帶入。正式 RC gate／產品程式未改。

## 本輪結果

| 檢查 | 結果與證據 |
| --- | --- |
| 新封裝 | PASS，[封裝命令](trial4-package.log)，同一產品位元只更新入口與繁中說明，未覆寫舊 ZIP |
| 封裝公開 CLI | PASS，[測試](trial4-package-tests.log)：白名單／排除私有設定／逐檔、EXE、ZIP hash；缺 EXE、缺 SDK、空檔、junction、覆寫均拒絕，失敗無 ZIP |
| 01／02 相關編譯及 CTest | PASS，[build](trial4-related-build.log)／[CTest](trial4-related-ctest.log)，13/13；完整套件留 09，NOT RUN |
| 入口 TDD | [Red](red-saved-mode.log)：舊 trial.3 強制 Preview、未關閉智慧休眠；修改入口後以新 trial.4 驗證 |
| 依賴 | PASS，[app log](trial4-app-tests.log)：Windows PowerShell 5.1 CheckOnly 查真實 Runtime；缺 loader、缺最低版本與過舊 VC++ 控制案例友善拒絕，未修改／安裝系統 Runtime |
| 首次桌布入口 | PASS，同上；全新隔離資料、Minimal、唯一宿主 parent 非零、ReadyEpoch=1；與 Windows 主螢幕矩形 `(0,0)–(1920,1080)` 一致，見 [宿主](trial4-launcher-desktop.json)／[獨立主屏幾何](trial4-launcher-primary.json) |
| 保存 Preview 後相同入口重啟 | PASS，管理介面保存後正常退出，再從相同入口啟動仍唯一 Preview、parent=0、ReadyEpoch=1，設定 hash 不變，見 [重啟](trial4-launcher-preview.json)；兩次智慧休眠／網路均關閉 |
| 雙主題與基本流程 | PASS，[app log](trial4-app-tests.log)、[管理結果](trial4-management-result.json)、[多目標結果](trial4-monitors-result.json)／[HWND 時序](trial4-monitors-phases.json)：Minimal／Dashboard 各自名稱與 SDK 握手／退出；管理唯一視窗與關閉隱藏、暫停／繼續、保存／取消／重啟、單／雙目標、網路 off→on→off、全斷線暫用主屏不改偏好、受控父程序 crash 復原、正式退出與已觀察子程序清理 |
| 預設智慧休眠啟動 | **FAIL，保留**，[原失敗](default-startup-failure.log)，根因交 05；已於 05／08／09 Comments 明確傳遞，繞行不解除 gate |
| 審查 | code-review Standards／Spec 平行審查；附掛等待競態修正後未解決問題各 0，最終文件與 ZIP／證據一致性複查通過 |

試用入口只覆寫本次智慧休眠，啟動不自動寫回偏好；按「套用並儲存設定」則包含目前關閉值。app 本身的智慧休眠預設仍開啟。隨包 README 已說明根因待 05、關閉期間不宣稱智慧休眠省電效果，以及 08 必須回到產品預設重驗。

靜態收尾：所有變更 PowerShell 腳本語法解析通過且保留 UTF-8 BOM，見 [檢查](trial4-static-checks.json)；REPORT 本機證據連結存在。暫存後 `git diff --cached --check -- . ':(exclude)third_party/licenses/webview2-1.0.2478.35-license.txt' ':(exclude)docs/acceptance/2026-10-29/trial-package/*.log'` 通過；排除上游授權原文第 13 行及原始 stderr log 的尾端空白／空行，保留證據原樣，未為排版修改授權或原始 log。

中間失敗另保留：[管理宿主讀取過早](probe-race.log)、[UTF-8 BOM 遺失造成 PowerShell 5.1 解析失敗](test-encoding-failure.log)、[附掛前過早斷言](attachment-probe-race.log)。已補宿主／握手／附掛等待並恢復 UTF-8 BOM，均未修改產品；這些是測試工具問題，不是產品結論。另一次 [Start-Process 存取被拒](process-start-denied.log) 發生於管理測試啟動，未進入入口驗收；相同 EXE hash 及診斷入口其後可執行、診斷退出碼 0（視窗已關閉）。未改 ACL／防護／系統設定，同一 ZIP 重新解壓的最終測試完整 PASS；拒絕原因未定，保留中間失敗。

## 本輪隔離、收尾與重現

最終解壓到 `%TEMP%/DrillPaper 試用 路徑 460148fddfb44d8a8902b6677a1de51f`，含空白／繁中且在來源樹外；入口與雙主題各用全新 LOCALAPPDATA，雙主題由套件外工作目錄握手。原乾淨建置的 source／build 仍為 offline，原位置不可用；這是檔案佈局與協定證據，ProcMon 全存取追蹤 NOT RUN。fixture 僅在基本入口／雙主題完成後暫放解壓目錄供多目標測試，結束移除，不在 ZIP、不屬 app 依賴。

原持續桌布 PID 83428 的路徑、建立時間及 SHA-256 與 [原基準](persistent-before.json) 一致，見 [本輪收尾](trial4-persistent-after.json)。未關閉／替換它、未重啟 Explorer；測試桌布只短暫附掛後正常退出，收尾只剩原桌布。未使用既有資料，故本輪備份／還原 NOT RUN，留 08。完整結果見 [result](trial4-trial-test-result.json)。

```powershell
# 沿用上輪的乾淨 Release 位元；重跑必須換新 trial 版本，既有同名檔會拒絕覆寫。
./scripts/package-trial.ps1 -ApplicationDirectory artifacts/trial-build-e6aa20e109da-97d656658238472dbe0cbd639177c889/build.offline/Release -SourceDirectory artifacts/trial-build-e6aa20e109da-97d656658238472dbe0cbd639177c889/source.offline -SourceCommit e6aa20e109da8cdd5402fe06ae0d11f3bc539d53 -Version 0.1.0-trial.4 -MinimumVcRuntime 14.44.35112.0
./scripts/test-trial-package.ps1
cmake --build --preset windows-msvc-release --target DrillPaperTests DrillPaperSettingsTests DrillPaperManagementIntegrationTests DrillPaperParentFixture --parallel 8
ctest --preset windows-msvc-release -R '^Management |Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause' --output-on-failure
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-trial-app.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.4-win-x64-unsigned.zip
```

08 從新的完整 SourceCommit 沿用 `build-trial.ps1` 重新建置／封裝，依 05 修正結果移除入口繞行；舊產物與證據保留各自版本。

## 本輪 NOT RUN 與人工清單

1. 預設智慧休眠啟動根因／修正／預設重驗：05／08／09，現況仍 FAIL。
2. 真正系統匣點擊、鍵盤／畫面、桌面圖示／工作列／Alt+Tab／焦點／虛擬桌面：人工尚未執行，請用隔離資料及合適桌面環境，不替換原持續桌布；原生命令／幾何／握手不等於畫面驗收。
3. 04 完整安全；05 真正 Explorer、實體拔插、鎖定／待機／電源、其他 DPI／Windows；06 NVIDIA／硬體精度／長時間效能；07 獨立作者完整流程：留各後票，不外推本票 PASS，不宣稱完整沙箱或智慧休眠省電通過。
4. 乾淨一般使用者、真正缺 Runtime、安裝／移除／備份還原：08，未卸除系統 Runtime，未提供安裝器。
5. trial CI／artifact、正式 RC gate：NOT RUN，僅新增獨立手動 workflow，原 windows.yml／package.ps1 未變。
6. 完整測試：NOT RUN，依指示留 09；未合併 main、未公開發行。提交／推送由 STATUS 記錄。

---

## 2026-10-29 歷史：試用包調查與停止（以下僅代表上輪）

**本票未完成，依使用者停止規則未 commit／push。** 分支 `feature/rc-03-trial-package`，HEAD 仍為 `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53`。01／02 均 implemented，工作樹起始乾淨；未修改產品 src/include、CMake 或正式 RC gate。

## 阻擋與可重現觀察

已確認需求要求解壓後能以一般使用者正常啟動，且保留既定智慧休眠預設。試用入口執行 `DrillPaper.exe --management --preview`，全新隔離 LOCALAPPDATA，在本機建立通知／管理／Preview 各一個、Preview parent=0、網路勾選=0，但 **30 秒後 ReadyEpoch=0**。trial.2 與 trial.3 都觀察到未握手；trial.3 的[原始失敗](default-startup-failure.log)包含明確屬性值，不能列預設啟動 PASS。

額外控制操作將智慧休眠取消並按套用，之後可握手；這同時涉及政策與重新載入，因此**尚不能判定根因是智慧休眠**。當時[繞行腳本輸出](workaround-not-acceptance.log)雖列 PASS，僅適用其明列的控制條件，不能代表預設啟動驗收。已移除自動繞行，保留直接要求預設入口 30 秒握手的測試；停止後未再次執行此最終腳本。

此現象可能涉及 05 的生命週期，但未新增產品修正、未擅自關閉預設智慧休眠，先於本票 Comments 記錄。需確認處理歸屬與預設啟動行為後再接續。未將已產 ZIP 視為可交付試用版。

## 草稿產物與來源

| 項目 | 值 |
| --- | --- |
| 版本 | `0.1.0-trial.3`（unsigned，未驗收，非 RC） |
| 路徑 | `artifacts/DrillPaper-0.1.0-trial.3-win-x64-unsigned.zip` |
| ZIP SHA-256 | `4CA2300347C77BB37B18DA4B329A940B760564E60DD880504A3BA6B8359C6E69` |
| EXE SHA-256 | `B0FF9A734713AF939C6444092B6D008DEDEF9480A17932D1B4B9D92C0FE71781` |
| 產品來源 commit | `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53` |
| 工具鏈 | MSVC `19.44.35217.0`，CMake `3.31.6`，x64 Release／MD |
| 外部 VC++ | 最低 `14.44.35112.0`（工具鏈 VCRedistVersion）；本機 `14.52.37025.0` |
| WebView2 | SDK／loader `1.0.2478.35`，實際 Runtime `156.0.4314.50` |
| Windows | Windows 11 專業版，10.0.26200；本機既有 25H2／26200.8737 環境，非其他版本驗收 |
| 權限 | 本次 token 非系統管理員，見 [environment.json](environment.json)；不是乾淨新帳號測試 |

[package-metadata.json](package-metadata.json)保存逐檔、EXE、ZIP 與本次封裝工具 hash；[build-provenance.json](build-provenance.json)保存乾淨建置來源與工具版本。產品從明確 commit 的 git archive 建置，工具與模板為本票尚未提交的工作樹，兩者沒有冒稱同一來源 commit。不同工具鏈、建置路徑或 ZIP 時間戳不保證逐位元相同；每次產物須另核對 hash。

套件含白名單的 27 個檔案加 manifest：EXE、WebView2 loader、兩個主題各 8 個資產、第一方／第三方授權、啟動入口與繁中說明。不帶 Catch2、Node、Python、NVML、系統 CRT、完整瀏覽器、設定／匯入內容／日誌／證據／憑證／建置暫存。SDK ZIP 並非此 app ZIP。

## 已執行範圍

| 檢查 | 結果與界線 |
| --- | --- |
| 乾淨來源 Release 建置 | PASS，[build.log](build.log)，只建 app，BUILD_TESTING=OFF；最終 trial.3 重用同一已記錄 EXE／資產，只更新啟動入口的缺設定檢查並封裝，[package.log](package.log) |
| 01／02 相關 CTest | PASS 13/13，[related-ctest.log](related-ctest.log)，相關 targets 編譯通過；未跑完整套件 |
| 缺 EXE TDD | [Red](red-missing.log)→[Green](green-missing.log)；最初缺腳本的工具失敗沒有算成行為 Red，使用佔位 CLI 取得明確拒絕行為 Red |
| 封裝契約 | PASS，[package-tests.log](package-tests.log)：恰好白名單、排除額外私有設定、逐檔／EXE／ZIP SHA-256、覆寫拒絕、缺 SDK／空檔／junction 拒絕與失敗無 ZIP |
| 啟動依賴 | PASS：Windows PowerShell 5.1 的 CheckOnly 查到真實 Runtime；缺 loader 顯示重解壓提示、提高最低 VC++ 版本的控制案例明確拒絕並給下載網址。真正卸除 VC++／WebView2 NOT RUN，未改系統 |
| 缺最低版本設定 | Standards 找到 fail-fast 缺口，[Red](red-required-runtime.log)後修正；trial.3 的 launcher 負面測試通過，見繞行 log 開頭。未宣稱原 trial.2 通過 |
| 預設啟動 | **FAIL／阻擋**：未在 30 秒握手，見上文；正式交付不通過 |
| 其他套件基本流程 | 控制條件下 PASS：雙內建主題真實 SDK 握手／退出、管理關閉隱藏／唯一視窗／暫停／保存／取消／重啟／正式退出；多目標單／雙選與幾何、網路 off→on→off、全斷線提示／不改偏好、受控父程序 crash 復原、觀察子程序清理。此為繞行／指定 no-smart-sleep 的自動操作，不外推預設啟動或人工視覺 |
| 審查 | `code-review` Standards 1 項缺最低版本設定，修正後複查未解決 0；Spec 0。後續實機啟動阻擋優先，不能由靜態審查視為票單完成 |

既有 management 探針在 PowerShell 7 Add-Type 遺漏框架參考，改在其既有 Windows PowerShell 5.1 環境執行；預期 native stderr 曾被 ErrorActionPreference=Stop 提前終止，測試改為接收後檢查退出碼。原生入口握手失敗另有重複觀察，沒有將前述工具問題當成產品結論。

## 隔離與自足性

- 最終草稿解壓於來源樹外 `C:\Users\James\AppData\Local\Temp\DrillPaper 試用 路徑 4d7cbd96d0a540f8aaad8e2e20992bc0`，其他失敗輪次使用不同 GUID 目錄。測試資料只在本次行程的 LOCALAPPDATA，回復父行程原值；沒有使用原資料，不需備份還原原使用者資料。
- 本次乾淨來源／build 已改名 `source.offline`／`build.offline`，原位置不可用。內建 ResolveTheme 只由 EXE 目錄尋找 resources；兩主題亦從另一工作目錄完成握手。這是程式邊界與協定證據，未執行 ProcMon 全檔案存取追蹤。
- 既有多目標腳本需額外的父視窗 fixture 與測試匯入探針；fixture 僅在解壓測試目錄暫放，測後移除，不在 ZIP、不屬 app 執行依賴。正式 ZIP 內容已先核對 whitelist/hash。
- 原持續桌布 PID 83428、建立時間 `2026-10-29T12:00:49.9803524+08:00`、固定副本路徑及 SHA-256 `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 前後一致，見 [before](persistent-before.json)／[after](persistent-after.json)。未關閉／替換、未重啟 Explorer；收尾只剩此 app。測試曾短暫建立自己的桌面目標，不將其當原桌布的替代品。

## 重現命令

```powershell
./scripts/build-trial.ps1 -SourceCommit e6aa20e109da8cdd5402fe06ae0d11f3bc539d53 -Version 0.1.0-trial.2
# 本輪已將此建置的 source/build 改名 offline；重用已記錄的產品位元封裝修正版入口：
./scripts/package-trial.ps1 -ApplicationDirectory artifacts/trial-build-e6aa20e109da-97d656658238472dbe0cbd639177c889/build.offline/Release -SourceDirectory artifacts/trial-build-e6aa20e109da-97d656658238472dbe0cbd639177c889/source.offline -SourceCommit e6aa20e109da8cdd5402fe06ae0d11f3bc539d53 -Version 0.1.0-trial.3 -MinimumVcRuntime 14.44.35112.0
./scripts/test-trial-package.ps1
cmake --build --preset windows-msvc-release --target DrillPaperTests DrillPaperSettingsTests DrillPaperManagementIntegrationTests DrillPaperParentFixture --parallel 8
ctest --preset windows-msvc-release -R '^Management |Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause' --output-on-failure
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-trial-app.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.3-win-x64-unsigned.zip
```

同名 ZIP 不覆寫；重新建置時請指定新的 trial 版本。最後一條目前預期停在預設啟動握手要求；停止後未再次執行修改後的測試包裝腳本。原始重現失敗詳見 default-startup-failure.log。

## NOT RUN 與人工清單

1. 預設啟動阻擋的根因診斷／修正與修正後套件重驗：已依使用者規則停止；需先決定本票或 05 處理，不擅自將預設智慧休眠關閉。
2. 真正系統匣點擊、鍵盤／畫面、桌面圖示／工作列／Alt+Tab／虛擬桌面：人工項尚未執行，按已確認決策保留；請用隔離資料與其他桌面環境測，不替換原桌布。
3. 04 安全完整矩陣、05 真實 Explorer／拔插／鎖定／待機／顯示器電源、06 硬體精度／NVIDIA 與長時間資源、07 獨立主題作者流程：後票，不能由本票自動操作外推。
4. 乾淨一般使用者、真正缺 runtime 環境、安裝／移除與備份還原：08；未用既有資料，因此本輪沒有原資料還原證據，也不宣稱已驗證。
5. trial CI 執行及 artifact、正式 RC gate 執行：NOT RUN；只新增獨立手動 workflow，正式 windows.yml／package.ps1 未改。沒有觸發正式發行。
6. 完整測試套件：NOT RUN，依使用者要求留 09；未合併 main、未 commit、未 push。
