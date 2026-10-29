# 開發狀態

## 2026-10-29 Explorer 視窗銷毀復原 — 受控修正完成，真正重試待驗

- Scope：區分使用者 WM_CLOSE 與非預期 WM_DESTROY；以獨立通知視窗接收採樣／錯誤，原 HWND 消失後重建原生視窗、功能表、計時器與同一主題的 WebView2 controller。通知遺漏時由每秒一次的宿主檢查補救；重建失敗保留明確錯誤與停止路徑，不無限建立視窗。
- Red：公開 app／Win32 整合 seam 的跨程序父視窗 fixture，銷毀父視窗後舊版 app 提前退出；此前真正 Explorer 重啟則造成失效 HWND 與背景程序殘留。兩條生命週期失敗都列入修正，見 [explorer-recreation/REPORT.md](acceptance/2026-10-29/explorer-recreation/REPORT.md)。
- PASS：正常關閉父視窗 5 次；直接終止隔離父程序且不注入 TaskbarCreated 5 次；每次新握手世代及至少兩次新的 metrics.changed 成功送入 WebView2 bridge，正常退出 0，已觀察子程序全退出。此指標只證明 bridge 接受訊息，畫面仍需人工確認。
- PASS：既有重掛回歸、Dashboard mock Preview、內建及已匯入主題切換、自訂入口 renderer 故障 3 次；生命週期 5 次＋50 次快速往返及暫停期間關閉。完整本機 CTest 28/28（6.80 秒）、SDK 18/18 及其他腳本檢查通過。
- 測試工具修正：Windows PowerShell 5.1 使用明確 UIntPtr 建構式與外層陣列，避免把單一 CIM 物件的空 Count 誤判為沒有 renderer；renderer 初始／自訂入口皆要求新握手世代。Preview／主題協定測試以 no-smart-sleep 隔離當前 display-off，省電仍由獨立生命週期測試驗證。
- NOT RUN：修正版的真正 Explorer 重啟與像素畫面、重建與電源故障交錯、其他 Windows／顯示配置。不能用上述受控結果把舊版真正失敗改寫為通過；待使用者再做一次同情境驗收。
- Commit：`fix(desktop): 重建 Explorer 銷毀的宿主與資料通道`，分支 `bugfix/explorer-window-recreation`，完成相關驗證後提交推送。

## 2026-10-29 人工 Explorer 驗收 — 失敗已重現

- 使用者已啟動桌布並回報「重啟檔案總管後才消失」。真實 Shell PID 31956→70652，受測 app PID 97976 繼續存活，但原 HWND 88151400 已無效，獨立通知視窗仍有效。這次是 A04 FAIL，取代先前待驗狀態；不是腳本 30 秒後自動關閉。
- 失敗點：`RecoverDesktopHost` 遇到無效 gWallpaperWindow 直接返回；初期受控重掛只改 parent、未銷毀 HWND，未涵蓋此行為。需補上跨程序父視窗銷毀回歸與真正的視窗／WebView2 重建，不把訊息注入通過外推。
- 證據：`acceptance/2026-10-29/explorer-failure/` 保存原生視窗診斷、使用者回報與 runner 結果。期限到達後 runner 找不到有效主視窗可正常關閉，終止自己啟動的受測 app（退出 -1）；沒有終止 Explorer。
- 本機完整回歸仍 PASS：CTest 28/28（17.14 秒）、SDK 18/18、環境／採樣／封裝及隔離變異檢查；commit 7902c02 的 [CI 40803087109](https://github.com/act70255/DrillPaper/actions/runs/40803087109) 亦全數通過。這些不推翻上述 Windows 整合失敗。
- 驗收工具已加實際 Shell PID／世代觀測、成功後 30 秒人工觀察；USER_GUIDE 改用標準 build 與完整路徑。FINAL_HANDOFF 已整合目前 A01–A16，不再沿用舊版功能缺漏表。
- Commit：`test(desktop): 保存 Explorer 實機失敗與驗收工具`，分支 `feature/shell-recovery-acceptance`，完成本輪證據整理後提交推送。下一步在獨立 bugfix 分支修正 A04。

## 2026-10-29 主題負面測試 — 修正例外判斷誤報

- Red：只在隔離副本移除 validator 的路徑檢查後，正式測試腳本仍退出 0，且將預期拒絕卻被接受的 traversal 封包印為 PASS。原生 validator／產品檔案未變更；此實驗驗證測試本身是否有辨識力。
- Fix：只捕捉 validator 的拒絕例外；「預期拒絕卻被接受」的斷言移至 catch 外。新增公開腳本入口的隔離變異回歸，納入本機 test.ps1 與 CI。
- Green：相同變異現在讓子程序在 traversal.dmt 正確退出 1；正式未變異 validator 仍通過合法封包並拒絕 5 類非法包。證據見 [theme-oracle/REPORT.md](acceptance/2026-10-29/theme-oracle/REPORT.md)。
- Commit：`fix(test): 防止主題負面案例被誤判為通過`，分支 `bugfix/theme-negative-oracle`。此修正不代表尚未執行的 WebView2 外連／下載／權限測試通過。

## 2026-10-29 封裝工具續作 — Windows PowerShell 5.1 壓縮組件

- Red：新程序直接執行 `test-theme-package.ps1` 時找不到 `System.IO.Compression.ZipArchiveMode`；完整回歸亦在同一位置停止。
- Scope：主題 validator／測試、SDK packager／測試各自明確載入 `System.IO.Compression`，不再依賴另一支腳本先間接載入。
- Green：5.1 的主題測試及 SDK ZIP 解壓重測皆成功，SDK 18/18，兩次 SDK 封裝 hash 一致。證據見 `acceptance/2026-10-29/powershell-zip/`。這只確認執行相容性與所列封裝檢查；不外推成瀏覽器安全驗收。
- Commit：`fix(scripts): 明確載入 Windows PowerShell 壓縮組件`，分支 `bugfix/powershell-zip-assembly`，相關驗證完成後提交推送。

## 2026-10-29 效能工具續作 — Windows PowerShell 5.1 相容性

- Scope：將 PowerShell 運算式中的 `[ushort]` 改為 `[System.UInt16]`；C# 原生宣告與 all-processor-groups 的 `MaxValue` 語意不變。
- Red：Windows PowerShell 5.1 執行 `scripts/test-performance-sampler.ps1`，無法辨識 ushort，退出碼 1；這也是當日本機完整回歸的中止原因。先前在 PowerShell 7 的通過結果不外推到 5.1。
- Green：相同命令於 5.1 通過，3 筆完整樣本、跨度 2.339 秒；提前退出與未知 PID 的失敗資料仍保留。原始輸出見 `acceptance/2026-10-29/powershell/`。完整套件待同步修正後再收尾重跑。
- Commit：`fix(perf): 相容 Windows PowerShell 的處理器群組型別`，分支 `bugfix/powershell-sampling`，完成相關驗證後提交推送。

## 2026-10-29 Phase 8 續作 — 乾淨 Windows CI 的 SDK 還原

- Scope：官方 NuGet WebView2 SDK 1.0.2478.35、固定 SHA-256、驗證後解壓、拒絕覆寫既有目錄、staging 清理；CI 及選配 RC job 都先還原 SDK 並設定 WEBVIEW2_SDK_ROOT，沒有移除 CMake 的必填檢查。
- Red（真正 GitHub runner）：[run 40801046281](https://github.com/act70255/DrillPaper/actions/runs/40801046281)，SDK／主題封裝通過，但 Configure 因 WebView2 headers 不存在失敗，證據見 `acceptance/2026-10-29/ci/before-fix.log`。
- PASS（本機腳本）：`powershell -NoProfile -File scripts/test-webview2-bootstrap.ps1 -ArchivePath C:/WorkSpace/-James/DrillPaper/.toolchain/webview2/sdk.zip`，官方包／空白路徑／竄改包拒絕／既有檔保留／staging 清理通過。
- 後續遠端驗證：先提交並推送 `bugfix/ci-webview2-bootstrap` 的具體修正，才可用 workflow_dispatch 執行該版本；新 runner build／CTest 結果尚待執行，不預先標為 PASS。真正 RC job 保持 opt-in，發行閘門未解除。
- Commit：`fix(ci): 還原固定雜湊的 WebView2 SDK`；來源包與版本固定方式見 `docs/ENVIRONMENT.md`。

### CI 遠端驗證結案

- Commit `9888aaf` 的 [run 40801528098](https://github.com/act70255/DrillPaper/actions/runs/40801528098) 已實際全數 PASS：乾淨 runner configure／build、CTest 28/28、Node 18/18、SDK 還原邊界及主題 artifact。取代上方執行前的待驗狀態。
- 證據見 [ci/REPORT.md](acceptance/2026-10-29/ci/REPORT.md)。此結果不證明 Windows 10／11 Shell GUI 或乾淨使用者安裝；RC job NOT RUN，未要求發行且發行條件尚未滿足。
- 結案 Commit：`docs(ci): 保存乾淨 Windows runner 驗收結果`，與修正一併推送 `bugfix/ci-webview2-bootstrap`。

## 2026-10-29 Phase 1 續作 — Windows 11 桌布附掛與受控重掛

- Scope：使用 `GetShellWindow` 錨定目前 Shell PID，排除其他程序的同名 WorkerW；支援新版 Progman 子 WorkerW，保留舊頂層搜尋與 Preview fallback。修正 SetParent 已回傳成功但殘留 LastError 導致誤判的重掛缺陷。附掛世代／最後失敗碼可由原生視窗屬性診斷。
- Red：實機公開 DesktopHost 整合測試先失敗（找不到桌布層）；改用新版建立訊息後仍失敗，inventory 顯示 WorkerW 已建立於 Progman 內。完整 app 的解除附掛／定向 TaskbarCreated 迴圈再重現錯誤碼 4；SetParent 回傳值判斷修正後轉綠。
- PASS（Windows 原生整合）：Release app 建置；原生視窗 2 案例／22 斷言；相關 CTest 1/1。完整 app 同一 PID／HWND，SDK 握手完成，3840×1080 填滿父用戶區，附掛世代 1→6，5 次受控重掛，退出碼 0，6 個 WebView2 子程序全退出。觀測已統一 Per-Monitor V2 DPI 座標。
- Commands：`cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperWindowsHostIntegrationTests --parallel 8`；測試 EXE `'[shell-live],[desktop]'`；`scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -RecoveryCycles 5`。證據與限制見 [shell/REPORT.md](acceptance/2026-10-29/shell/REPORT.md)。
- NOT RUN：本輪真正 Explorer 程序重啟、圖示／工作列／Alt+Tab 與像素畫面。Windows Computer Use 原生管道不存在，畫面需人工補驗；受控通知明確不算 Explorer 重啟。`[shell-live]` 會操作當前桌布層，故只手動明確呼叫，不納入無互動 CTest。
- Commit：`fix(desktop): 支援新版桌布層並修正重掛誤判`，分支 `bugfix/shell-attachment`，依階段規則提交推送。上一階段 Preview 回復提交 `edbb261` 已在 origin。

## 2026-10-28 Phase 1 續作 — Preview 回復樣式

- Scope：只修正 `Win32DesktopHost::RestorePreview`，解除父視窗後清除桌布專用的 `WS_EX_NOACTIVATE`／`WS_EX_TOOLWINDOW`，恢復一般預覽視窗。新增專屬 Win32 父子視窗整合測試，不操作 Explorer。
- Red：`DrillPaperWindowsHostIntegrationTests.exe '[desktop]'`，1 案例失敗／6 斷言中 5 通過；`WS_EX_NOACTIVATE` 仍為 `0x08000000`，重現樣式未回復。
- Green：Release 主程式及整合測試 target 建置成功；`ctest --test-dir build/windows-msvc-release -C Release -R 'Desktop fallback' --output-on-failure` 通過。最終測試輸出與二進位雜湊見 [desktop-preview/REPORT.md](acceptance/2026-10-28/desktop-preview/REPORT.md)。
- NOT RUN：真正桌布附掛、桌面圖示／工作列互動、Explorer 重啟及視覺驗收。此階段只證明本程序視窗的回復樣式，沒有操作使用者的 Shell；其餘項目仍須獨立整合驗證。完整套件留至整體收尾，這次只跑直接相關測試。
- Commit：`fix(desktop): 修正預覽回復時殘留桌布視窗樣式`；分支 `bugfix/desktop-preview-fallback`，依階段規則提交並推送至 origin。

## 2026-10-28 Phase 7 — 30 分鐘觀測與狀態分析

- Scope：Runtime 版本 Minimal 實機 Preview，60 秒暖機、1800 秒要求，獨立 EXE／profile，CPU／Private Bytes／Working Set／handles／原生狀態分組；不冒充最新 renderer 復原版本的效能。
- PASS（收集與分析）：343 筆，實際 1804.606 秒，固定 7 程序且全含 app＋WebView2，無略過或不完整資料。active CPU 平均 0.1159%、locked 0.00628%；此觀測差約 94.6%，非普遍功耗保證。
- PASS（清理）：正常退出 0、6 個已觀察子程序全退出、暫時電源需求還原。原始資料、圖表、版本、方法與限制見 [long-observation/REPORT.md](acceptance/2026-10-28/long-observation/REPORT.md)。
- PARTIAL（A13）：active 穩定區間僅 596.194 秒，未寫成 600 秒；還缺 Dashboard／GPU Engine／display-off／全螢幕等對照。Private Bytes 起訖 +9.39 MiB，長時間洩漏不能由有限觀測排除。Commit `6551113 test(perf): 保存混合狀態長測與資源分析`，已推送 `feature/performance-observation`。

## 2026-10-28 Phase 4／6 續作 — 程序退出型渲染復原

- Scope：ProcessFailed 通知、UI 迴圈重建 renderer／environment、來源與載入世代、callback lifetime、保留原生採集與快照、自訂入口保留、有界 Minimal／原生 Preview 退化。Files：WebView2 host/header、App event composition、`scripts/test-renderer-recovery.ps1` 與驗收紀錄。
- Red／Green：已辨認新握手世代後，renderer 故障未恢復的測試先 FAIL；修正後 renderer 3 次、browser 3 次、8 次故障達上限後原生退化、非 index 入口各 PASS，app 正常退出碼 0。見 [recovery/REPORT.md](acceptance/2026-10-28/recovery/REPORT.md)。
- Scope 限制：程序／協定整合，非每次像素畫面；測試以 `--no-smart-sleep` 隔離其他政策。unresponsive／無限迴圈、crash 與電源交錯、其他 process kinds、Explorer、安全與發行條件仍 NOT RUN，原因為對應情境或功能尚未完成。
- Commit `1a0bad1 feat(web): 新增有界程序故障復原與握手驗證`，已推送 `feature/renderer-recovery`。

## 2026-10-28 階段提交與遠端同步

- 使用者已指定每階段完成後直接 commit＋push；規則已加入 repository `AGENTS.md`，後續依此執行。
- 已推送並用 `git ls-remote --heads origin` 核對：`feature/theme-manager` → `66edcbb`、`feature/runtime-lifecycle` → `3bdca3f`、`bugfix/performance-sampling` → `a41261e`。`main` 維持 `5697bf7`，未合併開發分支。
- 渲染器復原尚在開發：目前只有故障注入腳本與新握手診斷；已觀察失敗，實際自動復原未完成。這些 WIP 尚未推送，未當作驗收通過。

## 2026-10-28 效能工具修正與長測啟動

- `bugfix/performance-sampling`：要求 2 秒只覆蓋 1.205 秒的 regression 先 FAIL，修正以 CSV 首末跨度判定結束後 PASS。新增身分／狀態／handles、原始 Handle 身分保留、根程序退出 FAILED 與部分資料保存，不記為成功的零資源樣本。
- PASS：`scripts/test-performance-sampler.ps1`，完整跨度 2.467 秒、缺身分欄位修正、提前退出及不存在 PID 皆驗證。觀測 runner 短測亦確認正常退出、已觀察子程序全退出及暫時電源需求還原。
- 17:50 啟動 Minimal 30 分鐘實機觀測，60 秒暖機，獨立 profile／EXE 副本；尚未預判結果。證據與命令見 [sampler/REPORT.md](acceptance/2026-10-28/sampler/REPORT.md)。
- Commit `a41261e fix(perf): 修正採樣跨度並保留失敗證據`，已推送。後續繼續 renderer 復原、安全及桌布整合。長測與其他開發工作可能同時執行，保留環境限制。

## 2026-10-28 Phase 3／6 續作 — 背景採樣與生命週期

- 分支 `feature/runtime-lifecycle`，承接 `66edcbb`；Commit `3bdca3f feat(runtime): 串接背景採樣與電源生命週期`。Files：SamplingWorker、Windows PowerNotifications、App composition、WebView2 host、runtime unit／原生整合腳本及驗收文件。
- Scope：採集移出 UI、條件等待／可停止工作者、latest-wins mailbox 與設定世代、恢復基準重設、WTS／顯示器通知、前景全螢幕防抖、WebView2 hide/TrySuspend/Resume、非同步 callback lifetime／狀態世代。
- Red／Green：背景樣本未送出、Windows 通知宿主缺失、快速狀態往返後未暫停皆有失敗證據再修正。Worker 4 案例／21 斷言；完整回歸初次 CTest 27/27、SDK 18/18、封裝檢查通過，最終紀錄見 [runtime/REPORT.md](acceptance/2026-10-28/runtime/REPORT.md)。
- PASS（受控原生整合）：5 次往返、50 次快速往返、暫停期間正常退出。實際查詢 IsSuspended，不以 callback 成功代替目前狀態。
- PASS（人工實機）：使用者回報 Windows 真實鎖定／解鎖 5 次均恢復更新、可正常關閉；受測 EXE hash 與 PID 退出紀錄保存在 manual-session.json。
- PASS（實機 GPU 退化）：非 mock SDK 探針確認 CPU／RAM 已可用，GPU unavailable/null，沒有假 0；非 Intel GPU 支援或讀值精度聲明。
- NOT RUN：真實 display-off／待機、完整全螢幕／多螢幕、renderer／Explorer 復原、安全、長時間與安裝／CI矩陣。下一步：補齊效能採樣邊界、復原與安全驗證；發行閘門不變。

## 2026-10-28 Phase 5 續作 — 原生匯入與熱切換

- Scope：原生 `.dmt`／目錄驗證與 staging/atomic install、CLI 匯入／列舉、Win32 主題功能表、已安裝版本熱切換、逾時回復 Minimal。隔離 GUID origin 避免沿用舊來源。新依賴授權納入建置。
- Files：`src/themes/theme_manager.cpp`、`src/app/{main,theme_commands}.cpp`、WebView2 host 與對應 headers、`tests/unit/theme_manager_test.cpp`、`scripts/test-theme-{cli,switch}.ps1`、CMake、第三方 notices/licenses、README 及架構／使用者／驗收文件。
- Red／Green：ZIP、CLI、內建切換、已安裝主題與 junction 日誌寫入邊界均先有失敗證據再修正。原生主題 8 案例／71 斷言 PASS；CLI CTest PASS。相關命令、檔案範圍及原始證據見 [主題平台驗收報告](acceptance/2026-10-28/theme-platform/REPORT.md)。
- Windows 整合 PASS（程序／協定）：100 次內建切換後載入已匯入主題，正常退出；損壞主題逾時回復 Minimal 並重新訂閱。非畫面截圖驗收。
- 資源 PARTIAL：100 次 Private Bytes 約 197→331 MiB；追加 300 次峰值約 404 MiB、閒置後約 331 MiB，handles 234→257。不得宣稱無洩漏，長時間矩陣保留。
- NOT RUN：瀏覽器完整安全負面、Shell GUI、電源實機與乾淨安裝／CI；未具備完整產品整合或證據。發行閘門維持阻擋。
- Commit：`66edcbb feat(themes): 新增原生主題匯入與熱切換驗證`。下一步：在 `feature/runtime-lifecycle` 實作背景 worker／生命週期，並持續補安全與效能驗證。

## 2026-10-28 14:05 Dashboard 初始效能基線

- 使用者授權由 agent 直接開啟 Dashboard 實機 Preview，執行 600 秒任務、每輪等待 5 秒，並正常關閉。未修改產品行為；未提交。
- **PASS（量測與退出）**：113 樣本皆包含 app 與 WebView2，共 7 程序；CPU 平均 0.116%、p95 0.422%（14 邏輯處理器整機容量）；Private Bytes 平均 240.54 MiB，首分鐘後趨勢 -0.018 MiB/min；正常退出碼 0，觀察到的 6 個子程序全退出。
- 原始 CSV 實際跨度 594.971 秒，不能宣稱 CSV 覆蓋至少 600 秒。原始資料、退出證據、方法與限制見 [performance/REPORT.md](acceptance/2026-10-28/performance/REPORT.md)。
- **PARTIAL（A13）**：只有初始 Preview 基線；30 分鐘、Minimal／休眠對照、GPU engine 及 100 次切換 NOT RUN，尚無相應證據及完整產品整合。不能由此宣稱沒有洩漏或產品效能驗收完成。

## 2026-10-28 續驗：原生主題負面案例

- 範圍：公開 ThemeManager manifest 與安裝行為；延續既有主題分支。Files：原生主題管理實作／header、主題測試及驗收紀錄。Commit：尚未提交。
- **FAIL → PASS**：新增 101 字元名稱案例，先重現原生驗證器錯誤接受（exit 1），再修正 UTF-8 字元長度判斷。名稱／作者／說明採 manifest 字元上限；不以放大的 bytes 限制代替字元數。
- **PASS**：主題測試 target 建置；`DrillPaperThemeTests.exe '[themes]'` 6 案例／16 斷言；`ctest --preset windows-msvc-release --output-on-failure` 22/22，14.53 秒。原始紀錄與命令見 `docs/acceptance/2026-10-28/REPORT.md`。SDK 未更動，未重跑。
- **PARTIAL（Dashboard 實機人工驗收）**：使用者後續回報持續更新、有 CPU 圖表且可正常關閉，此三項 PASS。GPU unavailable、個別版面／縮放、可追溯程序樹的長時間效能及退出後子程序清理仍未驗證；已提供 10 分鐘 Dashboard 程序樹採樣命令。
- 發行阻擋保留：Theme Manager 未接入 app、無原生 ZIP／熱切換、背景採樣／休眠與網路策略整合缺漏，以及桌布、安全、效能與安裝矩陣未驗收。下一步：取得程序樹 CSV 與 metadata 後分析；補齊產品整合後再驗收相應項目。

## 2026-10-28 13:05 Windows 11 驗收

- 範圍：目前工作樹的 Release 建置、完整自動回歸、產物存在檢查與 GUI 工具可用性；未修改產品行為。分支 `feature/theme-manager`，本次未提交。
- **PASS**：`cmake --build --preset windows-msvc-release --parallel 8`、`scripts/test.ps1 -Configuration Release`，均 exit 0。CTest 22/22（含 Windows collector 與主題管理入口），SDK 18/18、環境回歸、主題 ZIP 正負案例及 SDK ZIP 解壓／重封全通過。
- **PARTIAL（人工 Preview）**：2026-10-28 13:18 使用者回報 Dashboard mock 文字與數值皆符合預期。13:19 再回報 Minimal 實機數值及時間持續更新（CPU 83%、RAM 81%、RX 18 KB/s、Host active），此範圍 PASS。Dashboard 個別版面、硬體精度及實機 GPU unavailable 仍待確認；Minimal 縮放與正常關閉已獲後續確認。Computer Use 管道不可用（os error 2），沒有工具截圖。
- **NOT RUN**：桌布／Explorer 復原、硬體精度、WebView2 安全負面整合、Windows 休眠、長時間效能、CI、乾淨安裝；原因及未完成產品功能見[本次驗收報告](acceptance/2026-10-28/REPORT.md)。整體產品仍未驗收通過，app RC 阻擋保留。
- **PASS（本輪基本 Preview 操作結案）**：使用者接續回報「1.2 OK」，確認目前 Minimal 視窗縮放無重疊／裁切，正常關閉無卡住。連同 Dashboard mock 文字／數值與 Minimal 實機更新，完成此次基本操作驗收；不外推到 Dashboard 個別版面、GPU、硬體精度、退出後子程序清理或桌布整合。
- 原始原生測試 log 已保存至 `docs/acceptance/2026-10-28/ctest.log`。後續：補齊主題管理、背景採樣／休眠、網路策略等未接入功能及其整合驗證。

## 2026-10-28 本機環境與續作

- 目前工作樹在 `feature/theme-manager`；`5697bf7` 已提交先前原型，起始工作樹乾淨。下文「只有 be5cb92、工作樹未提交」是舊環境紀錄，已過期。
- 本機為 Windows 11 Pro 25H2 build 26200.8737、VS 2022 Professional 17.14.17、MSVC 19.44、Windows SDK 10.0.26100.0、Node 24.17.0、Intel GPU。已用 uv 安裝 CMake/CTest 3.31.6，並安裝 WebView2 SDK 1.0.2478.35 到使用者 NuGet 目錄；Runtime 155.0.4283.62 原已存在。詳細步驟見 `docs/ENVIRONMENT.md`。
- **PASS**：`cmake --preset windows-msvc-release` 設定完成；Release `DrillPaper.exe` 已編譯；`scripts/test.ps1 -SkipNative` 的 SDK 18/18、主題封裝及 SDK 封裝驗證成功。
- **進行中**：依 `docs/IMPLEMENTATION_PLAN.md` 補原生主題管理。已建立獨立的目錄驗證、staging 安裝及列舉雛型，尚未接入 app，也不支援 `.dmt`；不應認為 Phase 5 已完成。發行腳本明確維持阻擋。
- **Phase 5 測試**：主題安裝起始測試先以佔位實作執行，結果 FAIL（預期）；實作後 `ctest --test-dir build/windows-msvc-release -C Release -R '^DrillPaperThemeTests$' --output-on-failure` PASS（2 個案例：安裝列舉、自身子目錄拒絕）。後者是預先辨識的安全修正，未另外取得失敗測試紀錄。原生主題負面測試、安全審查及 ZIP 解壓均未完成，尚不能宣稱可安全安裝不可信主題。
- **建置修正**：Catch2 自動發現遇到中文測試名稱 JSON 編碼錯誤；改以 CTest 單一入口執行主題測試，重新編譯成功。Phase commit：尚未提交。
- **NOT RUN**：本機 GUI 桌面附掛、外連安全、Windows 休眠及硬體精度驗收；Shell inventory 只列舉視窗，不代表附掛成功。

本紀錄更新至 2026-10-28。`PASS` 僅表示所列命令或明確範圍已在本機執行成功，不外推到未測 GUI、硬體功能、發行流程或安全性。原始規格仍見根目錄 `DesktopMonitor_Codex_Handoff.md`。

## 已確認決策

- 專案名稱：DrillPaper；首版目標 Windows 10/11 x64，支援範圍仍須按實測矩陣逐版確認。
- 主題網路預設封鎖；首次外連遭封鎖時應提示使用者前往設定；單一全域開關開啟後允許 HTTP/HTTPS，其他 URI scheme 仍封鎖。DrillPaper 不送遙測。現有 WebView2 host 會阻擋非本機來源，但提示與全域開關尚未實作，網路封鎖亦未做流量測試。
- 首個 app RC 僅供本機評估，不公開發布。
- 使用者選定第一方內容 Apache-2.0（SPDX `Apache-2.0`），著作權 `Copyright 2026 DrillPaper Project`；第三方依賴與社群主題須各自遵守其授權；保留 DrillPaper 名稱及標誌。
- TDD seams：MetricsSnapshot/採集器、Runtime 狀態與有界佇列、Theme manifest/封裝、JSON protocol/SDK；Win32 Shell 與 WebView2 用原生整合/GUI 驗證。無法取得 GUI 證據的項目保持未驗收。

## 環境與目前工作樹

- Windows 10 Pro x64 build 19045；Visual Studio Enterprise 2022 17.11.2、MSVC 19.41.34120、Node.js 22.14.0。
- 在 repository 忽略目錄 `.toolchain/` 安裝並驗證 CMake 4.3.5、Windows SDK 10.0.26100.0 及 MSVC 缺少的 headers/CRT；WebView2 SDK 1.0.2478.35，已安裝 Evergreen Runtime 155.0.4283.62。未修改系統 PATH 或 ACL。`scripts/* -LocalToolchain` 使用此工作區工具鏈；乾淨環境需先準備等效 SDK 及 Catch2 FetchContent 原始碼快取。
- Release build 目錄：`build/local-msvc-release`；可執行檔：`build/local-msvc-release/DrillPaper.exe`。
- 這台電腦先前缺少 CMake/SDK，首次檢查確實失敗；安裝工作區工具鏈後，已實際完成 Release 編譯、CTest 與 app/WebView2 protocol smoke。原先失敗紀錄不再代表目前狀態。
- 使用者已明確授權 Git commits。2026-10-28 再次執行 `git -c safe.directory=C:/WorkSpace/DrillPaper add -A`，工具環境仍拒絕建立 `.git/index.lock`（Permission denied）；因此目前只有既有 commit `be5cb92`。沒有變更 ACL 或繞過寫入限制。此工作樹的程式與文件修改尚未提交。

## Phase 0 — Repository / Environment Audit

- **狀態：部分完成。** 完成 repository、AGENTS、TDD skill、原生環境與依賴 audit；固定 Catch2 3.8.1（BSL-1.0，僅測試），建立 CMake/PowerShell build-test-environment scripts。工作區安裝 CMake/Windows SDK/WebView2 開發依賴。
- **驗證：PASS** — MSVC x64 Release app 編譯；`DrillPaper.exe --version` 輸出 `DrillPaper 0.1.0-dev`；`--diagnostics` 回報 x64 及 WebView2 Runtime 155.0.4283.62。初期無工具鏈時的失敗已記錄在歷史執行脈絡，不是目前 blocker。
- **GUI：PARTIAL** — app 已建立視窗並能跑 WebView2 smoke；Computer Use 工具拒絕對 DrillPaper 進行可視操作，沒有截圖或人工視覺檢查，因此不宣稱 UI 視覺驗收。
- **Git：BLOCKED** — `.git` 唯讀，無法建立 Phase commit；使用者授權已給，不會再詢問。受限工具環境仍拒絕寫入。
- **下一步：**完成可行的原生功能與文件；不能解除的 Shell/Theme Manager/安全/效能 gate 均具體列入交接。

## Phase 1 — DesktopHost Feasibility Spike

- **狀態：未驗收；桌布附掛不支援宣稱。** 已有 `WorkerW`/`SetParent` opt-in 程式碼、Preview fallback 與 Explorer/display-change 重試。Shell inventory 在 Windows 10 Pro 19045 列舉 17 個相關 top-level windows；`Progman` 下見到 `SHELLDLL_DefView`，未觀察到可用的全螢幕 wallpaper layer。
- **測試：NOT RUN** — 沒有以 app 實際掛載桌面、檢查圖示/工作列/Alt+Tab/focus/z-order、重啟 Explorer 或測試解鎖/解析度變更的 GUI 證據。C++ app 編譯成功不等於 Shell POC 通過。
- **結果：**`--preview` 為可用的獨立視窗路徑；`--experimental-desktop` 保持 opt-in，不能列為已支援桌布。

## Phase 2 — Metrics Core + TDD

- **狀態：部分驗收。** 已實作 typed metric/unit/quality、CPU/network 差值、Windows CPU/RAM/disk/network collectors 與選配 NVML loader。
- **測試：PASS** — CTest 涵蓋 CPU warm-up/delta/reset、metric unavailable/zero、單位與 network rate；Windows collector integration test 真正呼叫本機 API，確認 typed readings 和 CPU/network warm-up，CTest 21/21 全通過。
- **限制：**沒有以獨立儀器或已知工作負載比對各指標精度；GPU/NVML 和 disk activity 尚無專項硬體/數值驗證。app protocol smoke 只證明 snapshot 流程完成，不能據此宣稱所有硬體值正確。

## Phase 3 — Runtime / State Machine / Bounded Cache

- **狀態：核心政策測試通過；產品執行緒整合未完成。** Ring buffer 保留最多 120 筆、latest-wins coalescer、change detector、power state machine、sampling scheduler 都有 C++ 測試。
- **測試：PASS** — CTest 21/21，包括有界 history/coalescing、狀態轉換、防抖與 scheduler 不補跑過期採樣。
- **限制：**目前 app 以 UI timer 同步採樣；尚無背景 sampling worker 與已驗證的 worker→UI mailbox lifecycle、shutdown/race stress、session/display/power notification、WebView suspend/resume。

## Phase 4 — WebView2 Host + Protocol v1

- **狀態：原生 host 與 JSON protocol 已建置並做程序層整合 smoke；安全負面與 GUI 渲染驗收未完成。** Host 使用 WebView2 virtual host mapping、私有 user-data directory，處理 SDK hello/ready、snapshot/history/subscribe；拒絕非本機 navigation/resource 和新視窗。
- **測試：PASS** — CTest 21/21，含原生 JSON 序列化/解析、64 KiB 限制、版本/欄位/請求 ID/history/subscribe cases；`scripts/test-webview2-smoke.ps1` 對 `minimal` live collector 與 `dashboard --mock-metrics` 均觀察到完成 hello→snapshot→subscribe 的 `Live metrics` 標題。
- **限制：**未用真實 JS 惡意 payload/外部請求做 WebView2 負面整合測試；無 renderer crash/reload 恢復測試；未用截圖或人工視覺檢查 DOM/排版；WebView2 執行於 UI thread，metrics 也在 UI timer 同步採集。

## Phase 5 — Theme Manager / SDK / Examples

- **狀態：SDK/作者工具完成可測部分；原生 Theme Manager 未實作。** 有 manifest validator、TypeScript 宣告、JS SDK/MockHost、minimal/dashboard 範例、`.dmt` 封裝/驗證器。WebView2 透過 CLI 可各自載入兩個內建來源，尚未提供執行期熱切換。
- **測試：PASS** — 18/18 Node 測試；`.dmt` validator 接受有效包，拒絕 traversal、大小寫重複路徑、不允許副檔名、錯誤 API version、超過 10 MiB 檔案；SDK package 解壓後重跑測試與兩個 theme validator，SHA-256 可重現。
- **產物：**`artifacts/DrillPaper-Theme-SDK-1.0.0-rc3.zip`，49,107 bytes，SHA-256 `68E0B5F41FB2337B396A5335CA1707B0F6F5E275F3771EF913E1DF8210D01656`。Apache-2.0；本機評估包，不含 app。
- **限制：**無 `.dmt` 原生匯入、staging/atomic install、列舉、切換、rollback、舊 API 提示或 100 次切換資源測試。

## Phase 6 — Smart Sleep / Recovery / Security Hardening

- **狀態：部分策略與 baseline host 控制已實作；未達安全或省電驗收。** C++ `ThemeNetworkPolicy` 模型測試通過；WebView2 host 阻擋外部 navigation/resource 和新視窗。
- **測試：PARTIAL** — CTest policy/schema cases 通過；未對 WebView2 執行 egress、redirect、fetch/XHR/image/script/iframe/WebSocket、permission 或 download 負面測試。
- **限制：**使用者要的首次阻擋提示與單一全域 allow HTTP/HTTPS 開關尚未接入；network policy model 未整合至 request interception。尚無 WTS/display/power events、TrySuspend/Resume、renderer/Explorer crash recovery。不得宣稱外部主題已沙箱化或 egress 已驗收。

## Phase 7 — Performance / Regression / Compatibility

- **狀態：量測工具有 smoke；產品效能與相容性驗收未跑。** Process-tree sampler 支援將可追溯 WebView2 child processes 計入統計；曾以 DrillPaper+WebView2 跑短時程序樹 smoke，觀察到 app 與 `msedgewebview2`，共兩筆 sample。
- **測試：NOT RUN** — 無 10–30 分鐘產品 CSV，也未比較 minimal/dashboard、locked/display-off、主題切換或長時間資源成長。
- **相容性：NOT RUN** — 目前只在 Windows 10 Pro x64 build 19045 建置；Windows 11、多螢幕、DPI/熱插拔與 Explorer recovery 未驗收。

## Phase 8 — CI / Packaging / Release Candidate

- **狀態：SDK RC 可交付本機評估；DrillPaper app RC 被正確 gate 阻擋。** `scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1 -LocalToolchain` 實際完成 build、完整測試後停止，明確報告缺 `src/themes/theme_manager.cpp`。沒有產生 app ZIP；不要稱 app RC 已完成。
- **測試：PASS / BLOCKED** — `scripts/test.ps1 -Configuration Release -LocalToolchain`：CTest 21/21、Node 18/18、環境檢查回歸、`.dmt` 正負案例及 SDK ZIP 解壓/重封驗證全通過。Windows GitHub Actions 未執行。`--version`、`--diagnostics` 與 WebView2 smoke 已實測。
- **限制：**沒有安裝器、乾淨 Windows user install/uninstall 驗證、app ZIP、簽章、長時間效能報告或 CI runner log。
- **下一步：**實作與測試 Theme Manager、使用者網路提示/全域設定、worker/smart sleep、原生 Shell GUI 支援；完成安全與效能矩陣後再解除 RC gate。需在可寫 `.git` 的受控環境按 Phase 建立 commit。
