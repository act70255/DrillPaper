# RC 02 固定設定視窗實作與驗證

日期：2026-10-29。基準 `0c97d4fdda3881a3d11bc7f93d7fc12829749f56`，分支 `feature/rc-02-fixed-settings-window`。需求與人工清單：[FIXED_SETTINGS_WINDOW](../../../FIXED_SETTINGS_WINDOW.md)。本票一次提交，提交訊息見 STATUS／Git 歷史。

## 版本與環境

- Release app SHA-256：`68CC8BDFDA3593046777D412298D6E1B7F5B92A77F6B93B161E74396F763CBD0`。管理、多螢幕與安全最終結果 JSON 均為此 hash。
- 原生管理測試 EXE SHA-256：`429DF45000DC9FC249C118D3610945B346DE7B589FC6911336E317EB4E4F4B50`；與產品編譯同一份 ManagementShell，測試使用獨立 HWND／fixture 資料。
- Windows 11 Pro 25H2 build 26200.8737；兩個 1920×1080 螢幕，主屏 DPI 144（150%）、外接 DPI 96（100%）。未改 Windows 顯示設定。
- 本輪 WebView2 Runtime 為 **156.0.4314.50**，由 EdgeUpdate 登錄與本輪隔離 profile 的 `EBWebView/Last Version` 核對；與 01 報告的 155 不同。本輪實際回歸結果不沿用前版 Runtime 證據。SDK 仍固定 1.0.2478.35。
- 原持續桌布 PID 83428、建立時間 2026-10-29 12:00:49、固定 `persistent-readiness-20261029-120049/binary/DrillPaper.exe` 未關閉／替換；未重啟 Explorer。所有測試使用隔離資料。

## 實作範圍

原生管理用戶區固定為 800×600 DIP；建立與 WM_DPICHANGED 均由當前 DPI 重算外框。拒絕最大化並限制尺寸，保留最小化／還原。左右兩欄列出主題與螢幕，底部保留設定與主要操作。長主題水平捲動，多目標清單垂直捲動；無名稱的裝置路徑改為短標籤，完整名稱／識別在可複製與捲動的詳細區。

狀態改為可捲動唯讀文字，相同狀態更新不重設閱讀位置。Tab／Shift+Tab 明確跨控制項移動，略過停用操作，顯示焦點提示；空白鍵沿用原生控制項。保存／取消／匯入／移除／網路政策仍沿用既有 composition 邊界。

## TDD 與審查

| 行為 | 先失敗，再修正 |
| --- | --- |
| 固定用戶區 | [size-red](size-red.log)：150% 舊版 900×900，預期 1200×900；調整寬度並於跨 DPI 時重算固定尺寸後 [PASS](size-green.log) |
| 最大化與外部尺寸要求 | [fixed-red](fixed-red.log)：SC_MAXIMIZE 將視窗最大化；加入原生尺寸限制後 [PASS](fixed-green.log) |
| 長狀態訊息 | [readability-red](readability-red.log)：舊 STATIC 無法捲動；改為多行唯讀 EDIT 並避免相同狀態重設捲動後 [PASS](readability-green.log) |
| Tab 導覽 | [keyboard-red](keyboard-red.log)：焦點停在多行文字區；由 Translate 明確處理 Tab／Shift+Tab 後通過。多行 EDIT 的按鍵行為參考 [Microsoft](https://learn.microsoft.com/en-us/windows/win32/controls/about-edit-controls) |
| 無名稱螢幕標籤 | [label-red](label-red.log)：大寫裝置路徑未被縮短；不分大小寫尋找路徑並保留幾何／DPI／主屏資訊後通過 |

最終 [原生管理測試](native-management.log) 5 cases／776 assertions PASS（含證據輸出），覆蓋實體用戶區尺寸、禁止最大化／任意改尺寸、24 列捲動、完整 ID、長錯誤閱讀位置、主題水平捲動、控制項在邊界內且互不重疊、受控 Tab／Shift+Tab／空白鍵及草稿還原。

依 code-review 技能分別執行 Standards／Spec 平行審查。Standards 找到測試擷取資源的失敗路徑未使用 RAII，已修正並複查；未解決項 0。Spec 未解決項 0。審查採起始 HEAD 對未提交工作樹及新增檔，符合本票完成後只 commit 一次的要求。

## 可重現命令

```powershell
cmake --preset windows-msvc-release
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperManagementIntegrationTests DrillPaperSettingsTests DrillPaperTests --parallel 8
$env:DRILLPAPER_SETTINGS_EVIDENCE = (Resolve-Path docs/acceptance/2026-10-29/fixed-settings).Path
build/windows-msvc-release/Release/DrillPaperManagementIntegrationTests.exe '[management]'
Remove-Item Env:DRILLPAPER_SETTINGS_EVIDENCE
ctest --test-dir build/windows-msvc-release -C Release -R '^Management |Settings |Invalid settings|Invalid monitor|Monitor target|Monitor selection|Clone targets|Manual pause' --output-on-failure
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-management-shell.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Desktop
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-multi-monitor.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-webview2-security.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe
```

證據輸出環境變數僅供測試選用，未設定時不輸出 PNG；不影響產品設定。畫面測試應循序執行，避免測試程序互相搶前景。

| 範圍 | 結果與證據 |
| --- | --- |
| Release 編譯／型別檢查 | PASS，[build.log](build.log)；相關 targets 均實際編譯 |
| 相關 CTest | PASS 13/13，[related-ctest.log](related-ctest.log)，完整套件未執行 |
| 用戶區／控制項 | PASS；96 DPI 實測 **800×600**，144 DPI 實測 **1200×900**；原生 GetClientRect／子控制項矩形及受控鍵盤訊息，不推論人工按鍵結果 |
| 100%／150% 基本畫面 | 已檢視 [100%](fixture-96.png)、[150%](fixture-144.png)、[長文字 100%](long-text-96.png)／[150%](long-text-144.png)。這些為 fixture 的 **WM_PRINT 原生列印畫面**，包含相同產品控制項與字型；非客戶區採列印外觀，其最大化圖示不能當實際 DWM 標題列證據。主要文字／操作完整可見，過長名稱與 ID 可捲動 |
| 實際 app 管理畫面 | 已檢視 [150% app PNG](management.png)，本機真實螢幕清單、完整識別及底部操作可見；由既有腳本 PrintWindow 擷取，不宣稱人工點擊通過 |
| 管理生命週期／設定 | PASS；關閉只隱藏／重開同一視窗 5 次、暫停／繼續、桌布／預覽、保存／取消及重啟、正式退出與已觀察子程序清理。[log](management.log)、[result](management-result.json) |
| 01 目標選擇回歸 | PASS；單／雙選與取消、原設定重啟、模式往返、全斷線提示／不改偏好、全域網路 off→on→off、19 個已觀察子程序退出；受控父程序 crash 非真正 Explorer。[log](multi-monitor.log)、[result](multi-monitor-result.json)、[viewport](viewports.json) |
| 保存與安全政策 | PASS 於既有腳本所列邊界；首次提示、HTTP／HTTPS、儲存／worker／導覽復原、WebRTC／preconnect、設定往返及子程序清理。[log](security.log)、[result](security-result.json)。不宣稱完整沙箱／全部通訊邊界 |

## 工具失敗與限制

- 新增擷取測試初次編譯缺少 GDI+ 所需的 objidl 宣告，補 include 後通過；曾遇瞬時 LNK1104，核對無殘留測試程序後重新建置通過，沒有終止未知程序。
- PrintWindow 在跨 DPI 的同程序擷取曾輸出空白／縮放失真；改用 WM_PRINT 後重新檢視，最終 fixture PNG 才是有效證據。畫面擷取中一次要求前景視窗時失敗，不視為產品測試 PASS，已移除對前景的依賴。
- Tab 測試初次 oracle 未略過已停用的「預覽模式」；依既有有效狀態修正預期，未修改產品啟用政策。
- 受控訊息與原生列印畫面不能代替真實輸入／畫面互動；Computer Use 原生管道回報找不到檔案（os error 2），人工項依已確認決策不阻斷實作票。

## NOT RUN 與下一步

- 真實 Tab／Shift+Tab／空白鍵、實際系統匣點擊重開、匯入檔案選擇器／移除確認的取消與確認、人工長錯誤閱讀：本輪原生管道不可用，按 [人工清單](../../../FIXED_SETTINGS_WINDOW.md#人工清單) 後續補驗，不能沿用舊 hash 的人工 PASS。
- 小於視窗的工作區：已提供 Alt+Space、M、方向鍵與 Tab／Shift+Tab 可達方式；未改本機解析度／工作區實測。其他 DPI／Windows 版本、桌布混合 DPI 矩陣保留 01／05。
- 真正 Explorer、實體拔插／主屏改變、真實電源／硬體／長時間效能：本票範圍外，未操作；沿後續票處理。
- 完整測試套件、CI、打包：NOT RUN，依使用者指示留後續票及 09 收尾。不產 ZIP、不合併 main、不解除 RC gate。下一票為 03 首次試用打包。
