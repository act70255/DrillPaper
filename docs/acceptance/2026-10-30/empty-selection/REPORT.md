# RC 13 空選擇提示與 Preview 範圍

票 13 **implemented**：程式、可自動驗證部分及人工交接完成。從乾淨 HEAD `c8b9b0a9329704c719aad67bfb2533833725830f` 建立 `feature/rc-13-empty-selection-notice`。已確認票及 [需求方案](REQUEST.md) 與現況一致；票 12 已完成，沒有決策衝突或前提不成立。未合併 main、未公開發布、不解除 RC gate。

## 變更

- 桌布空選擇在套用副作用前拒絕，設定檔及有效目標不變。預期 SettingsValidationError 顯示「桌布模式至少需選擇一個目標螢幕。」於訊息框及管理狀態並記日誌；其他錯誤仍顯示通用訊息並寫詳細日誌。
- Preview 可暫時預覽、保存空陣列及重啟，首次未解析目標也可保存成 schema 2 空陣列；桌布空陣列、未解析桌布保存、非法／重複 ID 等保護仍在。
- 已保存空 Preview 的 CLI `--experimental-desktop` 於既有 startup try 內、COM／HWND／宿主建立前共用驗證，具體提示後退出 1；不影響首次未解析偏好的主屏遷移。
- 原生管理視窗只轉送操作命令 ID 範圍的 BN_CLICKED，狀態文字、草稿及焦點通知不再誤清提示。清單標籤寫明「桌布至少一個」。未改 Shell 宿主／採集／WebView2／主題安全責任界線，ADR 無。

## 來源與環境

最終產品 EXE SHA-256：`D586024E37062325B39527A1E5B711E359AFC83343AFCCEA2A159928E5059721`，由 base 加本票工作樹編譯；最終七個產品／測試／工具來源 hash 見 [source.json](source.json)，提交後以本票唯一 commit 追溯。不宣稱位元可重現。前輪不同 EXE 與逐輪證據保留，不混稱相同版本。

Windows 11 專業版 10.0.26200，既有 MSVC／WebView2 SDK 1.0.2478.35；本機 Runtime 沿既有 156.0.4314.50 環境。原生管理幾何測試實際覆蓋兩屏 DPI 144／96，包含固定邏輯用戶區與長訊息／鍵盤行為；不是其他 OS／DPI 或人眼驗收。

工具使用既有原生 `C:/Users/James/AppData/Roaming/uv/tools/cmake/Lib/site-packages/cmake/data/bin/{cmake,ctest}.exe`，避免已知失效的 Python launcher，不重裝工具。CTest 資料由既有 `ctest-workspace.cmake` 導到非 Temp 使用者目錄。產品每輪使用全新 `%USERPROFILE%/DrillPaperTests/RC13 空選擇 …` 副本／LOCALAPPDATA，由既有 Node launcher 直接啟動；所有產品測試循序，未與其他測試並行。

## TDD 與驗證

| 行為／命令 | 結果與證據 |
| --- | --- |
| Preview 空陣列保存 | `settings-red.log`：舊驗證拒絕；最小修正後 `settings-green.log` PASS，最終相關輪仍 PASS |
| 首次未解析 Preview 保存 | `unresolved-red.log`：舊 Save 要求已解析；最小修改保存為空陣列後最終 PASS |
| 桌布空選擇的具體管理提示 | `native-red/`：訊息框及管理狀態只有通用提示；最終具體提示／hash／宿主不變 PASS |
| CLI 空 Preview 強制桌布 | `native-cli-red/`：逾時且零宿主，未友善拒絕；共用驗證後最終具體提示、exit 1、保存 hash 不變 PASS |
| 文字／焦點通知不得變成操作 | `notifications-red.log`：`commands.empty()` FAIL；最小通知過濾後，文字／焦點不送命令、有效按鈕只送一次，最終 PASS |
| Release 型別／編譯檢查 | 最終 `cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperManagementIntegrationTests --parallel 8` PASS，`verified-build.log`；較早亦建置 DrillPaperTests／SettingsTests |
| 相關 CTest | `ctest --preset windows-msvc-release -R '^(Settings \|Invalid settings\|Invalid monitor\|Monitor target\|Monitor selection\|Clone targets\|Preview settings\|First Preview settings\|Management )' --output-on-failure -V`：**16/16 PASS**、2.92 秒，`verified-related-tests.log`。上表以 Markdown 逸出 pipe 顯示，實際命令使用一般 regex `|` |
| PS7 parser／證據拒覆寫 | PASS；相同 evidence 目錄拒絕 exit 1，result.json hash 不變，`tool-checks.json`、`refusal.log` |

完整 CTest／SDK／其他工具套件／CI／封裝 **NOT RUN**，依使用者指示留收尾；未產生新的試用 ZIP 或 RC。

## 最終產品自動實測

`pwsh -NoProfile -File scripts/test-multi-monitor.ps1 -ApplicationPath 'C:/Users/James/DrillPaperTests/RC13 空選擇 verified binary/DrillPaper.exe' -EvidenceDirectory 'C:/Users/James/DrillPaperTests/RC13 空選擇 verified evidence' -EmptySelectionNotice` **PASS**，見 `native-verified.log` 與 [原始結果](native-verified/result.json)。

1. 原生勾選所有連接目標，保存並確認完整桌面矩形／握手；清空草稿後，保存及「套用為桌布」均顯具體提示，設定 hash、HWND、parent、幾何及載入世代不變。
2. 空選擇主題預覽不保存；切 Preview 保存空陣列及連網偏好成功，單一非附掛宿主持續推送新 MetricsTick。切回桌布被具體提示拒絕，原 Preview／設定不變。
3. 僅破壞本輪隔離安裝主題的 manifest 並立即於 finally 還原，正式套用顯通用提示，設定及有效宿主不變；日誌有具體缺題原因及預期空選擇原因。
4. 正式退出後，已保存空 Preview 的 CLI 桌布覆寫顯具體提示並 exit 1、設定 hash 不變；再以管理入口重啟，Preview／空陣列／握手／持續新資料與保存 hash 保留。管理切桌布仍拒絕且訊息框及管理狀態都有原因。
5. 選回一個目標後套用桌布、保存及握手成功。兩次正常 app exit 0，當下合計 **12 個已觀察 WebView2 子程序**均在既有期限退出；不宣稱捕捉所有短命程序。CLI 早期驗證 exit 1 不建立 renderer。

完整 HWND、文字、時間、啟動／精確程序身分、exit、設定與管理 log 保存在 `native-verified/`，沒有複製 WebView2 profile。標籤微調前 `native-complete/` 也 PASS（不同 EXE hash），不取代最後來源的結果。

### 保留的失敗輪

- `native-green/`、`native-green2/`、`native-green3/` 是工具對標準訊息框關閉／按鈕定位的失敗。曾觀察到具體文字與可見 dialog，但固定按鈕 ID 1 不存在；不推論防毒或產品根因。工具改讀唯一可見文字 dialog，使用標準 WM_CLOSE 並保留關閉期限，沒有放寬提示內容／設定／宿主斷言。
- `native-green4/`、`native-final/`、`native-reviewed/` 的重啟後管理狀態斷言 FAIL 保留。最初懷疑更新時序／舊 HWND，增加有界等待與重新列舉仍重現；後由原生 Red 確認文字／焦點通知被錯轉成管理命令，修正後 `native-complete/` 及 `native-verified/` 才全通過。原 FAIL 不改寫為 PASS，也不當作已證實防毒攔截。
- top-level 原始建置／測試 log 保存於 `raw-logs.zip`，可讀副本僅正規化行尾空白與檔尾空行；結果不改寫。其他 JSON／程序證據保留原始位元組。

## 安全與未執行範圍

原持續桌布 83428 的 path、UTC ticks `639288432499803524`、SHA `3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE` 前後一致；收尾唯一 DrillPaper app，沒有 RC13 profile 的 WebView2 殘留。未重啟 Explorer、未關閉或替換原桌布。

Trend Micro Apex One 可讀 AEGIS_BM.log 前後均 45890 bytes、修改時間 2026-10-30 14:51:46+08、SHA `C1550D0520F87091EDB2A2BB76507B1C6B06174718843AD1C1EBD6B664DA7D88`。未觀察新增攔截，這不是完整防毒觀測；沒有已證實本票受攔截影響的 BLOCKED 項，未修改防毒。見 environment-before／after。

人工畫面可讀性、真實拔插／其他 DPI／OS／Runtime 等 **NOT RUN**，逐項原因及操作見 [人工清單](MANUAL_CHECKLIST.md)。原生 API 證據不建立人眼畫面、完整安全或 RC 放行結果，既有 09-D2 與其他 gate 保留。

[兩軸審查](REVIEW.md) 最終 Standards 0／Spec 0。票／STATUS 隨本票唯一提交保存；commit-msg 依實際暫存差異產生繁中 Conventional Commit 後，一次 commit 並 push 本票功能分支，hash 以 Git 記錄為準。
