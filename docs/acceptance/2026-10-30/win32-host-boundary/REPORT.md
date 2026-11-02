# 票 14 驗證紀錄

票 14 implemented：純重構、相關自動驗證及人工交接完成。沒有決策衝突；這不是 RC 放行，票 09-D2 與既有必要 gate 保留。

來源為 `e3c7bdae12ba85143be25d190fba14c0a4ee1e2b` 加本票工作樹，分支 `feature/rc-14-win32-host-boundary`。原工作樹乾淨，票 13 已 implemented。[需求與方案](REQUEST.md)、[來源與產物指紋](source-binary.json) 隨唯一提交保存；提交 hash 以 Git 記錄為準。

## 實際變更

Win32DesktopHost 封裝原 parent／Shell PID 附掛判斷及 thread／process 身分檢查。app 保留 Surface userdata 比對、全程序成功世代及重試政策，透過宿主介面更新診斷。成功仍寫 `DrillPaper.DesktopEpoch`、清除 `DrillPaper.DesktopFailure`、寫 `DrillPaper.TargetDpi`；失敗仍於隱藏視窗後只寫 failure，不清除舊世代或 DPI。名稱、代碼、指標寬度、命令與訊息語意不變。

新增三個原生案例驗證無效／跨執行緒所有權、非 Shell 父視窗／Preview／失效 HWND、診斷初始失敗→成功→失敗→恢復（含超過 32 位元的世代與 144→96 DPI）。既有 live Shell 案例補介面成功／RestorePreview 後未附掛斷言。這是純重構保護，沒有行為修復，不虛構 Red，也不以編譯缺少新介面當 Red。

## 執行結果與命令

本次使用既有 uv CMake 套件的原生 `data/bin/cmake.exe`、`ctest.exe`，沒有使用已失效的 Python launcher 或重新安裝工具。以下兩工具的目錄為 `C:/Users/James/AppData/Roaming/uv/tools/cmake/Lib/site-packages/cmake/data/bin`。

| 項目 | 結果 |
| --- | --- |
| 重構前相關 CTest | **23/23 PASS**，4.66 秒，`baseline-related.log` |
| Release 相關 targets 編譯 | **PASS**，`build.log`，無新增編譯警告 |
| 重構後相同篩選及新增原生案例 | **26/26 PASS**，4.09 秒，`related-tests.log` |
| 非 Temp 使用者副本 live Shell | **PASS**，1 案例／17 斷言，exit 0，見 [Node 結果](live-shell-request.json.result.json) |
| 隔離產品多螢幕腳本 | **PASS**，2 目標／2 區域，見 [完整原生結果](multi-monitor/result.json) |
| 原持續桌布身分／測試清理 | **PASS**，原 PID 83428 身分未變，唯一 DrillPaper app、無 RC14 profile WebView2 殘留 |
| 完整套件／SDK／其他工具／CI／封裝 | **NOT RUN**，使用者要求本票只跑相關測試，留收尾 |

```powershell
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperWindowsHostIntegrationTests DrillPaperManagementIntegrationTests DrillPaperMonitorIntegrationTests DrillPaperSettingsTests DrillPaperTests DrillPaperParentFixture --parallel 8
ctest --preset windows-msvc-release -R '^(Desktop |Management |Monitor |Clone targets|Unidentified monitor|Connected monitors|Settings |Invalid settings|Invalid monitor|Preview settings|First Preview settings|DrillPaperThemeCli)' --output-on-failure -V
node tests/fixtures/theme-cli-launcher.mjs 'C:/Users/James/DrillPaperTests/RC14 宿主邊界 evidence/live-shell-request.json'
pwsh -NoProfile -File scripts/test-multi-monitor.ps1 -ApplicationPath 'C:/Users/James/DrillPaperTests/RC14 宿主邊界 binary/DrillPaper.exe' -EvidenceDirectory 'C:/Users/James/DrillPaperTests/RC14 宿主邊界 evidence/multi-monitor'
```

PowerShell 僅協調測試；CTest 原生啟動測試 EXE，主題 CLI、live Shell 及多螢幕產品／fixture 均由 Node 直接啟動 EXE。CTest 將 TEMP／TMP 指向非 Temp 使用者測試目錄；產品副本、隔離 LOCALAPPDATA 與全部實測資料另放使用者繁中空白目錄。產品實測全程循序，不與其他測試並行。

首次嘗試由工具呼叫 cmd 啟動 live Shell 副本時，工具 exit 1、沒有取得測試案例結果；不計入產品 FAIL 或防毒 BLOCKED。後續改用既有 Node 啟動器，取得上述獨立原始 PASS 結果，未修改測試或產品判準。原始建置、兩輪 CTest 與產品輸出保存於 `raw-logs.zip`，未正規化或覆寫原始 log；原生 JSON 副本保持原始位元組，未複製瀏覽器 profile。

## 產品實測範圍

產品 EXE SHA-256：`8E8953FA98842F37965C4FC0C8F3C3FD93E22FD7E1A161B8D9AED3180CE6214A`。Windows 11 專業版 build 26200，兩個 1920×1080 區域，目標 DPI 144／96。固定 WebView2 SDK 1.0.2478.35；已安裝 Runtime 154.0.4258.62、155.0.4283.62、156.0.4314.50，本輪未另外採集實際載入 Runtime 版本，不能據安裝清單宣稱跨 Runtime 驗證。

既有多螢幕腳本以同一份最終 EXE 驗證多選、取消草稿、原生幾何與 viewport、每個宿主握手／載入與附掛世代、快速切題及舊世代通知隔離、網路／暫停政策、保存重啟、跨程序父視窗崩潰後全部重建、單選、Preview／桌布往返及全部目標離線暫用主螢幕且不改寫設定。三次 GUI 正常退出及一次主題匯入均 exit 0；故障 fixture 依腳本明確終止。當下合計 **19 個已觀察 WebView2 子程序**均退出，不宣稱捕捉所有短命程序。

live Shell 案例只將自己建立的測試視窗附掛並還原，未重啟 Explorer。上述原生／程序證據不能代替人眼、真正 Explorer／OS 電源／實體硬體驗收；本票未啟用 09-D2 電源擴充模式，不把基本腳本 PASS 當作該缺陷修復。

## 防毒與安全

[測試前](environment-before.json)、[測試後](environment-after.json) 的原桌布 path、UTC ticks `639288432499803524` 及 SHA `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 完全相同。未關閉／替換原桌布、不重啟 Explorer。

Apex One 可讀 `AEGIS_BM.log` 前後皆 45890 bytes、最後修改 2026-10-30 14:51:46+08、SHA `C1550D0520F87091EDB2A2BB76507B1C6B06174718843AD1C1EBD6B664DA7D88`。未觀察新增攔截；這不是完整防毒事件觀測。本票沒有已證實受攔截影響的 BLOCKED 項，不修改防毒設定；若人工後續遇攔截，依清單記錄產品／規則／時間／影響並標 BLOCKED，不推定未知失敗原因。

[人工清單](MANUAL_CHECKLIST.md) 保留 NOT RUN 項及原因。[兩軸審查](REVIEW.md) Standards 0／Spec 0。更新票及 STATUS 後依 commit-msg 產生訊息，本票一次 commit 並 push 功能分支，不合併 main、不公開發布。
