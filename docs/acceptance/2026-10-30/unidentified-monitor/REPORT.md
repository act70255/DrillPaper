# RC 12 螢幕無法辨識退化

票 12 **implemented**：完成程式、可自動驗證部分與人工交接；不代表 RC 放行。從 HEAD `054c9017156098c36c33832c7740086e02aede97` 建立 `feature/rc-12-unidentified-monitor-degrade`。依已確認票與 [需求／方案](REQUEST.md) 實作，沒有決策衝突或前提不成立。未合併 main、未公開發布、未重新封裝 app，其他票狀態不變。

## 實作與邊界

- runtime `ResolveMonitorTargets`：空 ID 明確代表無法辨識，任一連接目標符合即忽略保存選擇、選取全部區域；同矩形 clone 去重，回傳退化旗標。恢復辨識立即回原有部分／全斷線政策，不修改輸入選擇。
- platform/windows：注入 `DisplayConfigGetDeviceInfo` 邊界，target／source 查詢失敗、空裝置路徑／source 名稱不再整批拋錯。可辨識項目照常回傳；失敗項保留原生矩形／有效 DPI，空 ID 與「無法辨識」名稱。source 名稱不可用時以 source mode 對應矩形；無法對應時保守加入各原生區域的無法辨識項目，確保不漏掉退化。區域鍵只作目前定位／clone 去重，不保存。真正幾何／DPI 失敗仍回報列舉錯誤，未猜縮放。
- `MonitorInventory`：整體列舉暫時失敗保留上次成功清單；首次失敗另用原生主屏 API 取得矩形／DPI。app 在局部更新邊界記詳細日誌，繼續 reconcile、採樣傳送、renderer 健康檢查及重試；管理介面顯示首次退化／快取提示。
- 管理清單拒絕勾選空 ID，Preferences 亦排除空 ID。原保存 ID 保留為未連接選項。所有螢幕恢復辨識後退化提示自動消失，依保存目標顯示。首次／舊設定的主屏 ID 僅在辨識成功後於記憶體解析，沒有自動寫入退化目標。
- 獨立 Preview 不呼叫拓樸列舉；含管理介面的 Preview 可更新清單，但列舉故障不阻擋運作。測試 fixture 以另一編譯目標注入列舉器並使用相同產品入口，不在產品 EXE 增加故障開關。觀測使用公開 HWND／屬性／管理文字／SettingsStore，不把程序證據當成人眼畫面。

README、多螢幕政策及架構文件同步。票 13 的空選擇提示、14 的 Win32 宿主邊界、15 的 SDK 文件路徑仍由各票處理；本票保持空選擇不能保存。沒有新 ADR，沿用確認的產品政策及 C++20／Win32／WebView2 邊界。

## 環境與來源

Windows 11 專業版 10.0.26200，本機既有 MSVC 19.44／WebView2 SDK 1.0.2478.35、Runtime 156.0.4314.50、Node v24.17.0。實際列舉為兩個 1920×1080 區域，主屏 `(0,0)-(1920,1080)` DPI 144、副屏 `(1920,0)-(3840,1080)` DPI 96，見 final-related-tests.log。不是乾淨一般使用者／其他硬體驗收。

| 受測位元 | SHA-256 |
| --- | --- |
| 本次產品 DrillPaper.exe | `A19BBF0272450099BC08378B07F17F4F8E080E077C0163B7202BEF70D272C708` |
| 最終測試入口 DrillPaperMonitorDegradeFixture.exe | `9013D5A3E6C8B8261DB81B6CF69E4820BF00E8B03054B120B3B7DB90422046F0` |

來源為 base 加本票工作樹，提交後以本票唯一 commit 追溯，不冒稱兩個 EXE 相同或有位元可重現保證。建置／測試命令使用既有原生 `C:/Users/James/AppData/Roaming/uv/tools/cmake/Lib/site-packages/cmake/data/bin/{cmake,ctest}.exe`，沿用已知 Python launcher 失效的處理方式，未重裝工具。產品及 fixture 複製到非 Temp 使用者繁中／空白目錄，各輪使用全新 LOCALAPPDATA，由既有 Node launcher 直接 spawn EXE；產品測試全程循序，未與其他測試並行。

## TDD 與相關檢查

| 行為／命令 | 結果 | 證據 |
| --- | --- | --- |
| runtime 未辨識另一屏仍只選原目標 | Red：`{0}` 不等於 `{0,1}` → Green | runtime-red.log；final-related-tests.log |
| 原生 target／source 讀取失敗 | Red：整批拋錯 → Green；追加空裝置路徑、空 source 名稱及全部 target 失敗 | native-red.log；最終原生案例 28 assertions |
| 首次及後續整體列舉失敗 | Red：例外向外拋出 → Green；首次主屏、成功快取、再次失敗、恢復清除錯誤 | cache-red.log；最終案例 11 assertions |
| 管理清單空 ID | Red：顯示識別時拋錯 → Green；原生 check state／空白鍵拒絕、恢復後可選且只輸出合法 ID | management-red.log；最終案例 7 assertions |
| `cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperSettingsTests DrillPaperMonitorIntegrationTests DrillPaperManagementIntegrationTests --parallel 8` | PASS，產品與相關 targets 編譯 | related-build.log |
| `cmake --build --preset windows-msvc-release --target DrillPaperMonitorDegradeFixture DrillPaperMonitorIntegrationTests --parallel 8`；審查修正後再建 fixture | PASS；無本票 C++ warning，既有 miniz CMake deprecation 保留 | fixture-build.log、fixture-review-build.log |
| `ctest --preset windows-msvc-release --tests-from-file C:/WorkSpace/-James/DrillPaper/docs/acceptance/2026-10-30/unidentified-monitor/related-tests.txt --output-on-failure -V` | **17/17 PASS**，8.96 秒；含目標／clone、SettingsStore、全部原生管理及列舉相關案例 | related-tests.txt、final-related-tests.log |
| PS7 parser／證據拒覆寫／Git 空白檢查 | PASS；拒覆寫預期 exit 1、sentinel hash 相同 | refusal-result.json；收尾紀錄 |

完整 CTest／SDK／其他工具套件 **NOT RUN**：依使用者要求留收尾。沒有將完整套件當成本票完成條件。

## Windows 自動整合

`scripts/test-unidentified-monitor.ps1 -ApplicationPath <Release/DrillPaperMonitorDegradeFixture.exe> -EvidenceDirectory 'C:/Users/James/DrillPaperTests/RC12 螢幕退化 round3'`：三個情境全部 **PASS**、正式 exit 0：

1. 保存單一主屏，另一屏識別不可用：兩區域各一宿主、完整矩形與 DPI、WebView2 握手及指定提示；注入整體列舉失敗後保持兩宿主及新 MetricsTick，恢復後只顯示原保存目標；再經原生管理命令保存，ID 不變。
2. 首次列舉失敗：主屏一宿主、144 DPI、指定提示及持續推送；恢復辨識後仍為首次預設主屏，明確保存才寫穩定 ID。
3. 獨立 Preview：一視窗、握手／指標更新，故障列舉器呼叫 **0 次**。

round3 三次分別觀察並核實 7／6／6 個 WebView2 程序退出，沒有該隔離 profile 殘留；未聲稱捕捉所有短命程序。部分 CIM 未提供 ExecutablePath 的觀測明記 observation-gaps.log，不算已核實退出程序。結果與啟動／精確程序身分／時間、fixture 日誌及合法 settings.json 見 live-round3/。

正式產品回歸：`scripts/test-multi-monitor.ps1 -ApplicationPath 'C:/Users/James/DrillPaperTests/RC12 產品 回歸/DrillPaper.exe' -EvidenceDirectory 'C:/Users/James/DrillPaperTests/RC12 產品 回歸 evidence'` **PASS**。兩目標／兩區域、Minimal／Dashboard 握手、保存／取消／重啟、原生幾何／viewport、世代與網路、受控父 fixture crash 恢復、單選、模式往返、全斷線主屏提示及設定 hash 保留；19 個已觀察核實子程序退出。沒有啟用其他票的 DesktopPowerRecovery 擴充，不把此結果覆蓋 09-D2 FAIL。完整 phases／launch／exit 見 product-multi-monitor/。

### 工具失敗與保留紀錄

- round1 在嚴格比對 CIM 與 Process ticks 時中止；CIM 的微秒量化與 .NET ticks 不同，改採既有工具的小於 1ms 容差。round2 的 degrade 已 PASS，initial-failure 階段又因 CIM ExecutablePath 為 null 中止；工具現將該項記為觀測不足、不計入已核實程序，沒有終止該未知子程序。兩輪 wrapper 工具失敗與已確認自有 app 的清理紀錄保留，不當產品 FAIL／防毒 BLOCKED 或完整退出 PASS。
- related-green.log 曾在多 target 建置尚未完成時執行舊測試位元，兩個預期 Red 仍存在；等待建置完成後 related-green-final.log 11/11，再以明確清單最終驗證 17/17。沒有放寬產品判準。
- 初始 CMD 引號／regex 選取及 `--tests-from-file` 相對路徑曾未選中／讀到測試清單；最後用絕對路徑與明確 17 項清單，未把空測試結果當 PASS。相對路徑失敗見 test-list-relative-path-error.log。
- 原始文字日誌打包在 raw-logs.zip；可讀版本僅正規化行尾空白／檔尾空行，CTest 清單 JSON 亦去除產生器輸出的行尾空白。其他 JSON／程序證據保留原始位元組，Git 對本證據目錄保留 CRLF 並辨識 CR 行尾。原始 SHA 與最終來源／證據指紋另記，不更改 PASS／FAIL 內容。user 目錄原輪次／profile 保留，未複製 WebView2 profile 到 Git。

## 防毒、清理及人工缺口

Trend Micro Apex One 可讀 AEGIS_BM.log 前後均為 45890 bytes、最後修改 2026-10-30 14:51:46+08、SHA `C1550D0520F87091EDB2A2BB76507B1C6B06174718843AD1C1EBD6B664DA7D88`。沒有觀察本輪新增攔截，這不是完整防毒觀測；未修改防毒，沒有已證實受攔截影響而須標 BLOCKED 的本票項目。歷史 Temp／PowerShell 事件與其他專案事件不當本票根因。

原持續桌布 83428 的路徑、精確建立時間 `639288432499803524` UTC ticks、SHA `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 前後相同，收尾為唯一 DrillPaper app；沒有 RC12 profile 對應 WebView2 殘留。未關閉／替換原桌布，未重啟 Explorer。environment-before／after 保存完整比對。

真正無法辨識硬體、實體拔插／clone／其他 DPI、真正 OS 列舉故障、人眼桌面與其他 Windows／Runtime **NOT RUN**，原因及逐項步驟見 [人工清單](MANUAL_CHECKLIST.md)。單元及注入結果不建立桌面畫面 PASS，不宣稱沙箱或解除其他 RC gate。

[兩軸審查](REVIEW.md) 最終 Standards 0／Spec 0。更新票及 STATUS 後用 commit-msg 技能依暫存差異產生繁中 Conventional Commit，本票唯一 commit＋push 功能分支，commit hash 以 Git 記錄為準。
