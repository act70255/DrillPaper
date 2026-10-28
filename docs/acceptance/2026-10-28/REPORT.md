# Windows 11 本機驗收紀錄

日期：2026-10-28 13:05（Asia/Taipei）。本次驗收既有工作樹，不新增產品功能；未提交，分支 `feature/theme-manager`，基底 `5697bf7`。

**結論：開發建置及自動回歸通過；產品整體未驗收通過，不可發行。**

> 14:05 續驗：已由 agent 直接完成 Dashboard 實機 Preview 的 600 秒採樣任務，取得 113 筆含 WebView2 的樣本，正常退出碼 0，觀察到的 6 個子程序均退出。CPU 平均 0.116%、Private Bytes 平均 240.54 MiB。CSV 實際跨度 594.971 秒；方法、原始證據與限制見 [performance/REPORT.md](performance/REPORT.md)。以下標為待執行的效能步驟是先前狀態；A13 最新狀態為 PARTIAL，仍缺長時間及其他情境。

## 後續負面驗收與修正

- 續驗範圍：既有公開的 ThemeManager manifest／安裝行為；沒有更動 app UI 或解除發行閘門。
- **FAIL → 修正 → PASS**：`DrillPaperThemeTests.exe '[acceptance]'` 重現 101 個 ASCII 字元的名稱未被拒絕（exit 1）。原驗證器以放大的 UTF-8 bytes 門檻代替字元數；改為在 JSON parser 驗證 UTF-8 後計算 Unicode 碼點，限制 name 100、author 200、description 1000。修正原生介面的說明：目前僅支援資料夾，並未實作 `.dmt`。
- **PASS**：`cmake --build --preset windows-msvc-release --target DrillPaperThemeTests --parallel 8`，exit 0。
- **PASS**：`DrillPaperThemeTests.exe '[themes]'`，6 個案例／16 項斷言。包括既有安裝列舉、自身子目錄拒絕，以及超長名稱拒絕、100 個中文字名稱接受、非法 `.exe` 資產拒絕且不留下安裝、重複版本拒絕且保留原資產。紀錄：[theme-tests.log](theme-tests.log)。
- **PASS**：`ctest --preset windows-msvc-release --output-on-failure`，22/22，14.53 秒，exit 0。CTest 入口數未變，主題入口內案例由 2 增為 6。紀錄：[ctest-after-manifest-fix.log](ctest-after-manifest-fix.log)。SDK／JS 未更動，沿用前述 18/18 證據。
- **PARTIAL（Dashboard 實機）**：使用者後續回報「會更新、有 CPU 圖表、可以順利關閉」，資料更新、CPU 圖表顯示及正常關閉為人工 PASS。未明確確認 GPU unavailable、個別版面／縮放、時鐘動態；程序樹資源與退出後子程序清理仍 NOT RUN。
- 原生 ZIP 匯入、熱切換、背景採樣／休眠、網路策略整合、真正桌布、乾淨安裝尚有功能缺漏；整體發行判定維持不通過。

## 環境與受測產物

- Windows 11 Pro 25H2 build 26200.8737、Intel Graphics；VS 2022 Professional 17.14.17／MSVC 19.44、Windows SDK 10.0.26100.0、CMake 3.31.6、Node 24.17.0。
- WebView2 SDK 1.0.2478.35，既有 Evergreen Runtime 155.0.4283.62。
- EXE：`build/windows-msvc-release/Release/DrillPaper.exe`。
- EXE SHA-256：`06D1FF7474BD592E4C10E630957629460793788925AF3729D1D91A8BC6B522E9`。
- `WebView2Loader.dll` 與 `resources/themes/minimal`、`resources/themes/dashboard` 存在。這項檔案檢查不能證明渲染正常。

## 本次實際執行

| 命令／範圍 | 結果 | 證據與限制 |
| --- | --- | --- |
| `cmake --build --preset windows-msvc-release --parallel 8` | PASS，exit 0 | app、原生核心／protocol、Windows collector integration、主題測試 targets 全部建置成功 |
| `scripts/test.ps1 -Configuration Release` | PASS，exit 0 | 下列 SDK、封裝、環境回歸及原生 CTest 全部完成 |
| Node SDK／manifest | PASS，18/18 | 解壓 SDK 後也重跑通過；不包含真實瀏覽器安全或 UI |
| 環境檢查回歸 | PASS | CIM 顯卡列舉遭拒時仍能完成檢查 |
| `.dmt` 作者工具 | PASS | 有效包通過；traversal、大小寫重複路徑、非法副檔名、API 不相容、超大檔案拒絕；不能代表 app 已能匯入 ZIP |
| SDK ZIP | PASS | 解壓檔案完整、兩個主題封裝驗證、兩次封裝 SHA-256 相同；50167 bytes，SHA-256 `0CA917CA4F85E676AD7897DBAC79A684ABB3A67DDBB4CE954A47797CED99A149`。此為本次暫存測試 ZIP，測試結束已清理；不能沿用舊文件包的 hash |
| 原生 CTest | PASS，22/22，18.18 秒 | 原始紀錄：[ctest.log](ctest.log)；22 是 CTest 入口數，主題入口包含 2 個案例 |
| Windows metrics collector | PASS（有限範圍） | 實際讀取 API，檢查品質／單位、RAM 及 CPU/network warm-up；未核對硬體讀值精度，也未專測 GPU 的 unavailable 結果 |
| `git diff --check` | PASS | 無 diff 空白錯誤 |
| Computer Use 畫面驗收 | BLOCKED | 兩次 `sky.list_windows()` 均回報原生通訊管道不存在（os error 2）；沒有截圖或 UI 操作結果 |

## 產品驗收未通過的項目

- A02：PARTIAL。使用者已回報本機 Dashboard mock 畫面文字及數值符合預期；時鐘持續更新、裁切／排版及視窗操作仍待確認。先前 Windows 10 的 smoke 不當作本機結果。
- A03／A04：桌布附掛、圖示／工作列／焦點／Alt+Tab 與 Explorer 復原 NOT RUN。未自動終止使用者的 Explorer。
- A05：硬體精度與缺 NVML 的產品顯示結果未驗證。
- A06／A08：背景採集執行緒尚未接入 app，Windows 電源／工作階段與 WebView2 暫停／恢復尚未完成；只有核心政策測試通過。
- A09／A11：主題管理雛型未接入 app，不支援原生 `.dmt` 匯入、熱切換及回復；主題安全負面案例不足。
- A12：首次網路阻擋提示、全域開關未接入；WebView2 egress、惡意 payload、權限、下載與 redirect 負面整合 NOT RUN。不能宣稱外部主題已沙箱化。
- A13：10–30 分鐘效能、30 分鐘資源趨勢、休眠前後比較及 100 次切換 NOT RUN；目前缺少必要產品整合與 GUI 證據。
- A14：Windows CI、乾淨使用者安裝／卸載 NOT RUN。`package.ps1` 有明確無條件發行阻擋；本次沒有執行其重複 build/test 路徑，也未產生 app ZIP。

## 使用者畫面驗收

以下都在 repository 根目錄的 PowerShell 執行。一次只開一個，完成後正常關閉再開下一個。

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --mock-metrics --theme=dashboard
```

預期 CPU `25%`（24.5 四捨五入）、RAM `50%` 及 `8.0 / 16.0 GiB`、GPU `--`、磁碟 `3%`、RX `131072 B/s`；Host 應為 active，時鐘持續更新。確認 760×480 視窗沒有空白、裁切或錯誤提示，拉大／縮小後仍可操作，右上角關閉後 app 程序結束。

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --theme=minimal
```

預期實機 CPU／RAM／網路數值能更新；warm-up 後 CPU 出現讀值，無 GPU 指標不應顯示假 0。與工作管理員比較時，只檢查合理範圍及趨勢，取樣時間不同不要求瞬間完全相同。

| 人工案例 | 結果 |
| --- | --- |
| Dashboard mock 畫面文字與數值 | PASS（使用者人工回報，2026-10-28 13:18）：CPU 25%、RAM 50%／8.0 / 16.0 GiB、GPU --、RX 131072 B/s、磁碟 3%、Host active；時鐘顯示下午 1:18:10 |
| Dashboard 排版／裁切及時鐘持續更新 | 待確認；目前只有使用者貼回的文字，無截圖或動態觀察 |
| Dashboard 實機資料更新、CPU 圖表與正常關閉 | PASS（使用者人工回報「會更新、有 CPU 圖表、可以順利關閉」）；不外推到 GPU、版面裁切及退出後子程序清理 |
| Minimal 實機讀值與時間持續更新 | PASS（使用者人工回報，2026-10-28 13:19）：確認持續跳動；CPU 83%、RAM 81%、RX 18 KB/s、Host active，時間下午 1:19:48。此為實機資料更新驗收，不代表精度核對 |
| 實機 GPU unavailable 顯示 | NOT RUN；Minimal 此次回報沒有 GPU 欄位，Dashboard mock 的 -- 不代表實機 NVML 退化已驗證 |
| Minimal 視窗縮放與正常關閉 | PASS（使用者回報「1.2 OK」）：拉大／縮小無文字重疊或裁切，右上角關閉正常、無卡住。未另外量測退出後的子程序清理 |

本輪基本 Preview 操作驗收結案：Dashboard mock 文字／數值、Minimal 實機資料／時間更新、Minimal 視窗縮放與正常關閉均有使用者人工通過紀錄。Dashboard 個別版面／動態時鐘、實機 GPU、硬體精度及下列產品整合限制仍保留各自狀態。

這些 Preview 案例通過後仍不代表真正桌布、安全、省電或可安裝產品驗收通過。

## 下一項：Dashboard 實機程序樹資源量測

下列命令由使用者在專案根目錄 PowerShell 執行，啟動獨立視窗並記錄該次 PID；請保持視窗開啟至量測完成（10 分鐘），之後才正常關閉。

```powershell
$drillPaperAcceptance = Start-Process -FilePath .\build\windows-msvc-release\Release\DrillPaper.exe -ArgumentList '--preview','--theme=dashboard' -PassThru
.\scripts\measure-process-tree.ps1 -ProcessId $drillPaperAcceptance.Id -DurationSeconds 600 -IntervalSeconds 5 -OutputFile artifacts/acceptance/dashboard-live.csv
```

量測會包含可追溯的 WebView2 子程序並輸出 CSV 與 `.metadata.json`；完成後仍須分析有效樣本、程序清單、CPU／記憶體趨勢。此處目前是待執行步驟，不能標記 PASS。10 分鐘初始量測也不能取代 30 分鐘資源趨勢及休眠前後比較。
