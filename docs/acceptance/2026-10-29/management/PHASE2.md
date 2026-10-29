# 主題與設定管理第二階段

## 版本與命令

- 日期：2026-10-29，本機 Windows 11，MSVC Release，150% DPI。
- EXE SHA-256：`56A6D7CD40CA5E9E77D5D3DD709519D52259108AF4A33D8354EF12A284CCB73A`。
- `cmake --build --preset windows-msvc-release --parallel 8` PASS；最終 app target 亦重建通過。
- `DrillPaperSettingsTests.exe`：3 案例／15 斷言 PASS，涵蓋保存往返、非法偏好、損毀與版本拒絕、原子取代失敗保留原檔及清理暫存、manifest 相容的主題版本名稱。
- `DrillPaperThemeTests.exe`：9 案例／75 斷言 PASS，含原匯入／ZIP 安全與新移除契約；移除不影響來源目錄，穿越及不存在的內建版本拒絕。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-management-shell.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Desktop` PASS：沿用第一階段生命週期檢查，增加控制項套用／保存、新主題握手、取消不改寫及重啟恢復偏好。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-webview2-smoke.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Theme dashboard -MockMetrics` PASS，PID 29596。
- 原始管理結果及截圖來源：`artifacts/acceptance/management-398d82cc3a084839b6f2772f3992169e/`；同目錄保存已複製的 `phase2-result.json`／`phase2-management.png`。

## Red／Green 與缺陷

- Settings 的保存／讀取原先失敗，實作同目錄暫存、flush 與原子取代後通過。損毀設定不靜默覆蓋；schema、路徑與寫入錯誤在 app 邊界顯示友善訊息，詳細日誌為 UTF-8。
- 移除原先未刪除所選版本，公開契約失敗；實作目標目錄驗證、識別比對及 reparse 拒絕後通過所列案例。
- 新增已安裝 prerelease／build 名稱時 Settings 驗證原先過嚴；先重現失敗後對齊 manifest 支援。
- 新啟動流程曾把可信內建資產送進第三方匯入驗證，SDK `.d.ts` 遭拒，管理與獨立 Preview 無法握手。原有 smoke 與新管理檢查捕捉失敗；修正內建載入來源後兩者通過。沒有放寬第三方可匯入副檔名。
- 已檢視 native PrintWindow 對本次受測管理視窗擷取的 PNG，150% 下主題清單、模式、智慧休眠及底部操作均完整可見。這不代表真實圖示點擊或多 DPI 切換驗收。

## 未執行與交接

- NOT RUN：圖形化檔案選擇器匯入／移除確認的人工作業、真正系統匣滑鼠點擊、新管理版本的真正 Explorer 重啟、完整鍵盤／DPI 矩陣及移除 reparse 的實際 junction 負面案例。
- 原因：尚需補原生互動與針對性負面測試；使用者要求本階段收尾後重開 console，不擅自操作 Explorer 或認證。
- 子程序清理證據來自第一個受測 session 的已觀察程序樹；重啟 session 驗證 app 正常退出 0，未另外取樣該次全部子程序，不外推完整觀測。
- 完整本機套件及本版遠端 CI NOT RUN：功能三階段尚未完成，使用者要求階段交接；下一個 console 完成剩餘實作後收尾。最近全套／CI 的舊結果仍依原 commit 記錄。
- 第三階段尚未開始。allowNetwork 僅為設定欄位，沒有 UI 開關或 host 接線；不能宣稱完成網路控制或第三方沙箱。
- 使用者持續桌布 PID 83428、固定 `a241856` 副本保持運作，未替換／關閉。先前 A04 scoped PASS 保留，新介面仍須另驗。
