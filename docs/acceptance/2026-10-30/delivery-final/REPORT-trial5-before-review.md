# RC 08：交付候選包完成，保留繞行與 RC gate

2026-10-30。分支 `feature/rc-08-delivery-finalization`，base／產品來源 `676bb473efeca65614fddb40d98e3c88c302494b`。本輪沿用未提交工具、既有建置與全部證據，不另開分支、不重做預設智慧休眠多輪，也未修改產品 C++。依票內「決策（使用者確認，08 停止後）」：停止追 08-D1，正式交付入口保留 `--no-smart-sleep`；缺陷及繞行移除交給 09。本票 implemented 只表示已完成可自動交付工作與人工交接，**不是 RC 放行或全部驗收 PASS**。

原 `../delivery/` 逐檔 SHA-256 未變，核對見 `prior-evidence-hashes.json`／`prior-evidence-verify.log`。原第 2 輪仍 **FAIL／CLEANUP_FAILED**，後來自行 exit 0 不改寫結果。08-D1 原因未定；其時段 Apex One 的 WinVerifyTrust 失敗與其他封裝並行可能影響時序，但未證實。使用者 14:32 所見 python.exe 攔截屬別的專案，不能作為本票產品根因。

## 正式交付識別與來源

| 項目 | 結果 |
| --- | --- |
| 本票正式交付版本 | `0.1.0-trial.5`（候選、本機、未簽章；不是 RC） |
| 產品／SDK 來源 | `676bb473efeca65614fddb40d98e3c88c302494b`，包含 04／05／07 |
| EXE SHA-256 | `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA` |
| ZIP | `artifacts/DrillPaper-0.1.0-trial.5-win-x64-unsigned.zip`，472371 bytes |
| ZIP SHA-256 | `9A917C07A4A4AD3A273429CF0A700AA7BD38577CEF25533940D9F054F6C5C590` |
| 清單／逐檔 hash | PASS：55 檔白名單＋package-manifest；`package-metadata.json`／`inventory-final.log` |
| 簽章 | NotSigned、SignerCertificate=null，見 `signature.json`；沒有簽章完成聲明 |
| 工具鏈 | 沿用前輪乾淨 git archive 來源的 MSVC 19.44.35217.0／x64 Release／BUILD_TESTING=OFF；最低 CRT 14.44.35112.0，原建置證據 `../delivery/build-probe.log`／`build-provenance.json` |

本輪先核實既有乾淨來源建置 EXE 與原探針 hash 一致，再用同一 build/Release 重新封裝，不重新編譯未變動的產品。產品／SDK 固定於來源 commit；封裝工具、入口及交付 README 為本票工作樹，逐檔 tooling hash 隨 manifest／sidecar 保存，不冒稱已包含於產品來源 commit。EXE --version 保持 0.1.0-dev，封裝版本以 manifest 識別。trial.1～4 與 trial.5.probe 原檔未覆寫；ZIP 不入 Git，metadata 與證據隨本票唯一提交保存。

沿用 03 白名單，補 07 最新 MockHost 宣告、TypeScript 範本／lockfile、schema／SDK 文件及作者打包工具。沒有 Node runtime、compiler、node_modules、個人設定、WebView2 profile、日誌或開發暫存入包。沿用已核實的 Apache-2.0／miniz／nlohmann-json／WebView2Loader 授權檔及 NOTICE；完整 Evergreen／系統 CRT／NVML 不再散布。CI 新增相同清單／逐檔 hash 驗證；遠端 CI **NOT RUN**，09 核對對應提交與 artifact。沒有宣稱 EXE／ZIP 位元可重現。

## 實作與相關驗證

- 入口：CMD 先呼叫 Windows PowerShell 5.1 的 `-CheckOnly` 取得繁中依賴／資產提示，成功後由 CMD `start` 直接啟動 EXE `--management --no-smart-sleep`；不強制 Preview。PS 入口正常啟動亦委派 CMD，不直接啟動 EXE。`-CheckOnly` 不開 app；錯誤回傳 1，不自動安裝／提升權限。
- 交付 README：包含安裝、功能、使用、支援目標與已測配置、外部依賴、資料／日誌位置、隔離、更新／替換／回復、ZIP 移除／主動清除、前票 gate。明列「未簽章 EXE 可能被企業防毒攔截或警告」、確認可信來源 hash、向 IT 申請例外、記錄每次攔截與 BLOCKED，不停用防毒、不宣稱零背景外連或主題沙箱。
- TDD：沿用公開封裝 seam 的 `../delivery/package-red.log`→green；必要主題入口缺失 `../delivery/resources-red.log`→本輪 `resources-green-child.log` 完成 Green。首次 `resources-green-resume.log` 本身 PASS，但外層把預期負面案例遺留的 LASTEXITCODE=1 誤判為命令失敗；改由獨立 pwsh 呼叫後整體 exit 0，未變更判準。`launcher-final.log` 再驗最終包：缺主題入口／loader／最低 CRT 設定與過舊 CRT 均有繁中 fail-fast，未修改系統 runtime。真實缺 Runtime 的機器仍 NOT RUN。
- 封裝契約 PASS：缺 EXE、最新 SDK、白名單恰好相符／私有資料排除、空檔／缺 SDK／junction、拒絕覆寫與各 hash，見 `package-green-final.log`；來源與 inventory 見 `package-final.log`／`inventory-final.log`。
- 相關 CTest **18/18 PASS**，包含 SettingsStore、目標、取消相關政策、protocol／runtime 及 ThemeManager 安裝／移除／同版重裝、junction／路徑與禁止資產邊界，見 `related-ctest-native.log`。相關 targets 建置與 7 檔 PS parser PASS，`related-build-native.log`／`syntax.log`。沒有用單元測試宣稱桌面／硬體／渲染驗收。
- 建置環境插曲：PATH 上的 CMake 是 Python 啟動器，所指 Python 已不存在，`related-build.log` 在編譯前失敗。改呼叫同一已安裝 CMake 套件的原生 data/bin/cmake.exe、ctest.exe，重新 configure 與相關 targets 成功。未安裝 Python、未修改防毒，不將缺檔推定成防毒根因；原生 CMake 命令見下。完整測試套件依指示 **NOT RUN，留 09**。

## 最終 ZIP 的 Windows 整合

非 Temp 使用者路徑 `C:/Users/James/DrillPaperTests/交付收尾 含空白/`；本機有來源樹、建置工具與 Apex One，**不是乾淨一般使用者機器**。Windows 11 Pro 25H2 build 26200、Intel Graphics、雙 1920×1080／DPI144與96、WebView2 Runtime156.0.4314.50。各情境循序執行，產品實測沒有與另一產品測試並行；原持續桌布依限制保持運行，不將此機當獨占效能環境。

1. `final-entry-1-result.json`：真正最終 CMD 入口 **兩輪 PASS**，每輪全新隔離 LOCALAPPDATA。首次唯一主螢幕桌布、實體矩形(0,0)-(1920,1080)、ReadyEpoch=1、有效智慧休眠=0／網路=0；取消開網草稿回復0；保存 Preview／單一目標／網路=1／智慧休眠=0，正式退出後同入口重啟，parent=0、網路=1、設定 hash 不被啟動改寫；Dashboard 握手。四次正式退出0；當下持有且核實身分的4／6／2／6個 WebView2 handle全退出。只宣稱已觀察子程序，不宣稱捕捉所有短命程序。這不是產品預設休眠回歸；原預設測試FAIL保留。
2. `theme-final-result.json`：同包 EXE、另一全新隔離資料，Node直接啟動。沿用07可信作者DMT，hash `82BF38D3743A3F6ADCBFCC31D754B5E776D3A3B815DFB7F49A47F83C7CEE8546`。正式CLI匯入成功／同版拒絕，作者主題載入→Minimal→作者切換，非保存命令不改設定；原生管理移除確認選「否」保留清單與設定，選「是」回退Minimal且清單移除；同版CLI重匯入成功、重新整理後載入作者主題。正常退出0、6個當下核實子程序退出。以原生訊息操作可信管理入口，不是HTML可呼叫旁路；GUI選檔、人眼版面、真實滑鼠點擊仍NOT RUN。MetricsTick只代表推送，不能作為頁面有回應或完整渲染證據。
3. 原始入口身分／命令列、CLI啟動／退出與結果位於 `launch-evidence/`；完整 profile 留本機不提交。沒有套用／關閉原持續桌布，沒有重啟Explorer。`environment-before.json`／`environment-after.json` 顯示 PID83428、完整path、UtcTicks639288432499803524與EXE hash不變；收尾沒有本票app／隔離profile對應WebView2。

## 移除、資料與防毒

移除前檢查 **PASS**：本票app／profile對應WebView2已退出；設定／匯入主題檔案逐檔hash已保存於 `data-before-removal.json` 並再核對不變。**實際刪除解壓目錄 BLOCKED**：自動核准政策拒絕經邊界檢查的刪除及縮小為明確完整路徑的刪除，僅回報 `blocked by policy`；沒有繞過、沒有宣稱刪除成功。`removal-data-retention.json`保存狀態。使用者主動清除專用資料複本 NOT RUN，交人工清單；沒有安裝器，不宣稱安裝／解除安裝PASS。解壓目錄仍在本機可供人工檢查，原ZIP保留。

Apex One可讀程序ProductVersion只取得14.0（非完整build）。BM日誌前後均27830bytes、修改時間14:30:45.732+08、SHA `A62A71B541E9A7617673AB177117CA76688DC4E426D3DAEAA6E3C117F57408FB`，未觀察本輪新增攔截，但不是完整防毒觀測。`antivirus-drillpaper-records.json`以UTF-16LE讀到歷史Temp／PowerShell的`NON_POLICY_JUST_MEERKAT`記錄，屬前票，不改寫為本輪攔截；本輪無已證實受防毒攔截項，工具刪除BLOCKED與防毒分記。其他日誌欄位／完整版本不足仍交人工，不自行更動產品例外。未簽章狀態已獨立核實並寫入交付說明。

## 前票 gate 與 09 工作

| 來源 | 仍保留的判定／下一步（owner：09） |
| --- | --- |
| 01／02 | 本輪只核實主螢幕單目標與保存；其他DPI／解析度／部分及全部離線／拔插、完整人工版面NOT RUN |
| 03 | 歷史預設休眠啟動FAIL永久保留，trial.1～4未改；本票繞行PASS不能解除 |
| 04 | 安全PARTIAL：完整DNS／其他Runtime／TURN／proxy／外部handler／真實舊callback競態未完；不宣稱全程序零外連或主題沙箱 |
| 05 | 新版有界JS無回應復原已含；真正Explorer／桌面互動／OS電源等人工清單仍NOT RUN，不推定歷史啟動根因 |
| 06 | A05／A13 PARTIAL：資源缺失與長測記憶體上升、不能排除洩漏；NVIDIA／真正電源／其他網路與更長soak未完 |
| 07 | 最新SDK已入包；A10仍PARTIAL，獨立作者／GUI選檔與完整版面、乾淨無工具機器仍待驗 |
| 08 | 08-D1與繞行移除交09；原第2輪FAIL不改。刪除套件BLOCKED、主動清除／更新回復／真正乾淨機器NOT RUN |
| 09 | 對固定產品來源＋本票工具提交、最終ZIP/hash做完整套件、乾淨Windows CI、人工清單、A01～A16及RC判定；任一必要gate未過就拒絕放行。產品變動須新版本重包並重測受影響部分 |

## 重現命令

```powershell
# 沿用前輪固定commit的乾淨建置，不重新編譯未變動產品。
pwsh -NoProfile -File scripts/package-trial.ps1 -ApplicationDirectory artifacts/trial-build-676bb473efec-4245f767154e4371a36edee9c78c218f/build/Release -SourceDirectory artifacts/trial-build-676bb473efec-4245f767154e4371a36edee9c78c218f/source -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b -Version 0.1.0-trial.5 -MinimumVcRuntime 14.44.35112.0
# 既有ZIP拒絕覆寫；重現請選新版本，或在另一輸出目錄驗證清單。
pwsh -NoProfile -File scripts/verify-trial-archive.ps1 -ArchivePath artifacts/DrillPaper-0.1.0-trial.5-win-x64-unsigned.zip -SourceCommit 676bb473efeca65614fddb40d98e3c88c302494b
pwsh -NoProfile -File scripts/test-trial-package.ps1
pwsh -NoProfile -File scripts/test-trial-launcher.ps1 -PackageDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-trial-5"
pwsh -NoProfile -File scripts/test-delivery.ps1 -PackageDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-trial-5" -EvidenceDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-entry-1" -UseLauncher -Rounds 2
pwsh -NoProfile -File scripts/test-theme-author-flow.ps1 -ApplicationPath "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-trial-5/DrillPaper.exe" -PackagePath "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-author.dmt" -EvidenceDirectory "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/final-author-1" -VerifyRemoval
# 後兩命令的證據目錄亦拒絕覆寫，重跑須新名稱；不得同時跑另一產品測試。
$nativeCMake = Join-Path $env:APPDATA 'uv/tools/cmake/Lib/site-packages/cmake/data/bin'
$env:TEMP = "$env:USERPROFILE/DrillPaperTests/交付收尾 含空白/native-test-temp-1"
$env:TMP = $env:TEMP
& "$nativeCMake/cmake.exe" --preset windows-msvc-release
& "$nativeCMake/cmake.exe" --build --preset windows-msvc-release --target DrillPaperTests DrillPaperSettingsTests DrillPaperThemeTests --parallel 8
& "$nativeCMake/ctest.exe" --preset windows-msvc-release -V -R '^(Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause|Protocol v1 |Power state|Sampling scheduler|DrillPaperThemeTests$)'
```

code-review兩軸結果另見 `REVIEW.md`。唯一commit以本分支Git紀錄為準，使用commit-msg依實際暫存差異產生繁中Conventional Commit後commit並push；不合併main、不公開發布。

記憶查證：Nowledge MCP thread_search；query=`RC-08 08-D1 停止 交付`、limit3、無其他filters；server mode=`full`，scope=`default`，rank1 thread=`096776b6-a100-48c1-825b-2c0c62b10ae0`，題名「票 08：重新打包驗證與退出逾時停止點」，relevance_score=34.080902099609375。只讀摘要／搜尋片段、未讀取整個thread，未取Memory故無圖。以本票新的使用者確認決策覆蓋歷史停止前提。
