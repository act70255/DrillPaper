# 乾淨 Windows CI 驗收

## 真正遠端結果

- 修正前：[run 40801046281](https://github.com/act70255/DrillPaper/actions/runs/40801046281)，commit `90c34d4`。Node 與主題封裝通過，CMake 找不到 WebView2 1.0.2478.35 headers，原生建置未執行。
- 修正後：[run 40801528098](https://github.com/act70255/DrillPaper/actions/runs/40801528098)，commit `9888aaf`。整條 windows-build-test job 通過：固定雜湊的 SDK 還原、竄改包拒絕與既有檔保留、CMake configure／build、CTest 28/28（5.24 秒）、Node 18/18、範例主題封裝與 artifact 上傳。
- `after-fix.json` 保存 run／job／step metadata，`check-results.log` 為關鍵輸出節錄；完整 log 以原 run URL 為準。`before-fix.log` 只整理了行末空白。

## 版本及範圍

使用 GitHub `windows-2022` runner、MSVC 19.44、SDK 10.0.26100、Node 22；這是乾淨建置環境，不是 Windows 10／11 桌面、乾淨一般使用者安裝或 GUI 相容性證明。

WebView2 SDK 固定 1.0.2478.35，官方 NuGet 包 SHA-256：`B1DF2D7FE955A3378603735F910B126647E43033213B5CC071B8D6F0168A3B96`。本次亦透過官方 GitHub repository 的 tag API 核對 checkout／setup-node／upload-artifact 的 v7 參照存在，實際 run 已執行成功。

RC job 未啟用，沒有 app ZIP、安裝器或公開發行。整體發行閘門仍受安全政策、Shell GUI、效能與乾淨安裝等未完成條件阻擋。後續 `b3a1946`／`8019e16` 的 Windows PowerShell 5.1 腳本相容性修正另有本機證據，不能把此 run 的受測 commit 改寫成那些版本。
