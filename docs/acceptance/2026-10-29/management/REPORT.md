# 管理介面第一階段

- 環境：本機 Windows 11、MSVC Release、WebView2 Evergreen。
- Red：`DrillPaperTests.exe '[management]'` 在暫停後預期 DisplayOff、實際 Active 失敗。
- Green：同一測試 1 案例／8 斷言通過。
- `cmake --build --preset windows-msvc-release --parallel 8` 通過；修正圖示命令 ID 指標轉換後，相關 target 重建無新增警告。
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-management-shell.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Desktop` 通過：管理視窗重開 5 次仍同 HWND；暫停隱藏且停止 metrics tick、繼續取得新 tick；3 次注入 TaskbarCreated 後 Shell 接受圖示重註冊；桌布／預覽 parent 切換；正式退出 0 與已觀察子程序退出。
- 本機原始結果：`artifacts/acceptance/management-46cf667f2a714349abe20f3cacdd3992/result.json`；私有測試資料不作為發行產物。
- `scripts/test-runtime-lifecycle.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Cycles 1 -CloseWhileSuspending` 通過，保留獨立 Preview 的關閉語意。
- NOT RUN：真正系統匣滑鼠點擊／圖示像素、Explorer 真正重啟後新介面復原、DPI 切換與鍵盤完整流程。原生 API 註冊／訊息命令不能證明這些結果。
- 目前使用者的持續桌布副本未替換或關閉。整體 RC、安全及其他原有驗收阻擋仍依 STATUS。

實作依 [Microsoft Shell_NotifyIconW](https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shell_notifyiconw) 設定圖示版本及回呼，並依 [NOTIFYICONDATAW](https://learn.microsoft.com/en-us/windows/win32/api/shellapi/ns-shellapi-notifyicondataw) 處理版本 4 通知參數。
