# 效能量測

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

量測腳本的 regression smoke 會對程序樹取樣並確認 CSV/metadata；另曾以 DrillPaper Preview 實際啟動 WebView2，短時間觀察到 `DrillPaper` 與 `msedgewebview2` 子程序。這只證明程序樹能被找出，沒有產品資源基線。初版以 CIM 查詢自身程序時曾遇到 Access Denied，現已改用 Toolhelp32 snapshot。**尚無 DrillPaper 10–30 分鐘 CSV 或 minimal/dashboard、locked/display-off 對比**；不可將短時 smoke 當成效能驗收。
