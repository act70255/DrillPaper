# 採樣器時間邊界與身分驗證

2026-10-28，`bugfix/performance-sampling`，承接 Runtime commit `3bdca3f`。此階段修正觀測工具，不更改產品採集政策。

- Red：要求 2 秒的 CSV 實際跨度僅 1.205 秒，起始 regression FAIL。
- Green：以第一筆至最後一筆的輸出時間戳差值判定結束，不在截止前跳出。metadata 明確記錄 ObservedSpanSeconds，與 CSV 毫秒精度值一致。
- Red：舊輸出缺少程序建立時間、狀態與 handles，無法追溯測量身分；補上 RootProcessStartedUtc、RootWindowTitle、RootHandles／TotalHandles、略過讀值的 PID／次數。原始根程序 Handle 保留至結束，避免 PID 重用造成誤認。
- 根程序提前退出會保留部分 CSV 與 FAILED metadata，命令失敗；不存在的 PID fail-fast，不替換成其他程序。CPU／記憶體／handles 全部取得後才累加單一程序，不在讀取失敗時留下部分加總。
- CPU 分母使用 GetActiveProcessorCount(ALL_PROCESSOR_GROUPS)，不把觀測程序的可用 CPU 數逕當整機容量；此機兩者均為 14。
- `scripts/test-performance-sampler.ps1` PASS：3 筆完整樣本、實際跨度 2.467 秒；提前退出保留資料且標 FAILED；不存在 PID 為 0 樣本 FAILED。這只是工具驗證，不代表產品效能通過。紀錄：[test.log](test.log)。

## 觀測 runner

`scripts/run-performance-observation.ps1` 複製本次 EXE／DLL／資產，使用獨立 LOCALAPPDATA，先確認 session 已解鎖並完成 SDK ready，可指定暖機後量測。短測要求 2 秒、間隔 5 秒，輸出跨度 5.373 秒，含 WebView2，正常退出碼 0、6 個已觀察子程序全退出、暫時電源需求已還原；見 [runner-smoke/run.json](runner-smoke/run.json) 與 CSV／metadata。

暫時電源需求只用於觀測工作者，不更改電源計畫，也不阻擋使用者主動休眠或鎖定；結束時還原。API 語意見 [Microsoft SetThreadExecutionState](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate)。CPU 計數範圍見 [GetActiveProcessorCount](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getactiveprocessorcount)。

```powershell
.\scripts\test-performance-sampler.ps1
.\scripts\run-performance-observation.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Theme minimal -DurationSeconds 1800 -WarmupSeconds 60
```

2026-10-28 17:50 已啟動實機 Minimal 觀測，PID 84444，輸出 `artifacts/acceptance/observation-20261028-175019-61763a`。此處記錄啟動，不預先標 30 分鐘通過；完成後須檢查跨度、狀態、資料缺口及清理結果。其他開發工作可能同時執行，CPU 觀測不當作受控純閒置效能保證。
