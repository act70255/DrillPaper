# 效能量測

## 新版採樣器

`measure-process-tree.ps1` 以 CSV 第一筆至最後一筆的實際跨度達到要求才結束；新增 RunStatus、RootProcessStartedUtc、RootWindowTitle、handles 及略過讀值的明確紀錄，提前退出保存部分資料並失敗。CPU 容量來自所有 processor groups 的作用中處理器數。工具驗證與觀測 runner 操作見 [sampler/REPORT.md](acceptance/2026-10-28/sampler/REPORT.md)；下方 594.971 秒基線是修正前的歷史資料，不改寫成 600 秒。

## 2026-10-28 已取得的本機基線

Windows 11 的 Dashboard 實機 Preview 已執行 600 秒任務，113 筆樣本、實際資料跨度 594.971 秒，全部含 app 與 WebView2。程序樹 CPU 平均 0.116%、p95 0.422%（整機容量）、Private Bytes 平均 240.54 MiB；正常關閉後觀察到的子程序全退出。原始資料、分析方法及限制見 [驗收量測報告](acceptance/2026-10-28/performance/REPORT.md)。只有這個初始基線，尚無 30 分鐘、Minimal、locked／display-off 或熱切換對照。

## 工具及先前歷史

`scripts/measure-process-tree.ps1` 每秒列出指定根 PID 與其子程序樹的 CPU 累積時間、Working Set 與 Private Bytes，並輸出 CSV 與環境 metadata JSON。若 WebView2 子程序的 parent chain 可追溯到 DrillPaper PID，會一併計入。程序在取樣間退出時會略過該次讀值。

原生應用程式建置後，執行 15 分鐘基線：

```powershell
$app = Get-Process DrillPaper | Select-Object -First 1
scripts/measure-process-tree.ps1 `
  -ProcessId $app.Id `
  -DurationSeconds 900 `
  -IntervalSeconds 1 `
  -OutputFile artifacts/performance/active-minimal.csv
```

另在 `dashboard`、`locked`、`display-off`、切換主題與長時間執行情境各做一次；metadata 記錄 Windows 版本、PID 與取樣參數。不同情境需使用相同電腦、電源模式與顯示設定，並保留原始 CSV。工具以 Toolhelp32 process snapshot 建立程序樹，再用 `Get-Process` 讀取資源數值；這些輪詢會帶來少量觀測成本。

量測腳本的 regression smoke 會對程序樹取樣並確認 CSV/metadata；先前短時間 smoke 只證明 `DrillPaper` 與 `msedgewebview2` 子程序能被找出。初版以 CIM 查詢自身程序時曾遇到 Access Denied，現已改用 Toolhelp32 snapshot。最新初始基線見上方；仍不可將短時 smoke 當成完整效能驗收。
