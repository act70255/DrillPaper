# Dashboard 實機 Preview 初始資源基線

2026-10-28 13:55–14:05（Asia/Taipei）。使用者授權直接執行；由 agent 啟動本次專屬 Dashboard 視窗，完成量測後正常關閉。未關閉其他使用者程式，也未改動產品功能。

## 環境與重現

- Windows 11 Pro 25H2 build 26200.8737、Intel Graphics、14 邏輯處理器，其他環境同上層驗收報告。
- app：`build/windows-msvc-release/Release/DrillPaper.exe --preview --theme=dashboard`，未使用 mock。
- 根 PID：86000；起訖標題均為 `DrillPaper Preview — dashboard — Live metrics`，完成 SDK hello／snapshot／subscribe。
- 量測命令：`scripts/measure-process-tree.ps1 -ProcessId 86000 -DurationSeconds 600 -IntervalSeconds 5 -OutputFile artifacts/acceptance/dashboard-live-20261028-135536.csv`。
- 量測時未另外跑編譯／測試；沒有控制整台電腦其他工作負載、視窗遮蔽、電源模式或 GPU engine。
- 原始 [CSV](dashboard-live-20261028-135536.csv)、[採樣 metadata](dashboard-live-20261028-135536.metadata.json)、[啟動／退出紀錄](dashboard-live-20261028-135536.run.json)、[分析 JSON](dashboard-live-20261028-135536.summary.json)。metadata 的 `OsCaption` 為 null；實際 build 有記錄，作業系統名稱依既有環境紀錄。

## 結果

| 項目 | 結果 |
| --- | --- |
| 指定採樣任務 | 600 秒；每輪等待 5 秒，另有列舉／讀取成本 |
| 有效樣本 | 113；全部包含根程序及 WebView2，固定 7 個程序、1 組 PID 集合 |
| CSV 實際覆蓋 | 第 0.476 至 595.447 秒，共 594.971 秒；現有迴圈不會在超過截止時間後補最後一筆，不能把指定 600 秒誤寫成 CSV 覆蓋至少 600 秒 |
| CPU 平均 | 0.116%（佔整機 14 邏輯處理器總容量） |
| CPU p95／最大區間平均 | 0.422%／0.821% |
| Private Bytes 平均 | 240.54 MiB |
| Private Bytes 起始／結尾 | 226.48／240.43 MiB，增加 13.94 MiB |
| Private Bytes 最小／最大 | 226.48／245.50 MiB |
| 第一分鐘後 Private Bytes 線性趨勢 | -0.018 MiB／分鐘，這段短時間樣本接近平坦 |
| Working Set 平均／最大 | 451.37／457.68 MiB；為各程序加總，共用頁面可能重複計入，不能當作唯一實體記憶體佔用 |
| 正常關閉 | CloseMainWindow 成功，15 秒內退出，exit 0 |
| 子程序退出 | 關閉前觀察到的 6 個存活 WebView2 子程序均退出；後續依 PID 檢查亦未見存活 |

CPU 由相鄰樣本的程序樹累積 CPU 秒數差值除以經過秒數，再除以 14。112 個有效區間，0 個因 PID 集合變更、倒退或時間異常而排除；平均依區間秒數加權，p95 採區間值最近秩。這是約 5 秒區間平均，不是瞬時尖峰或整台電腦總 CPU 使用率。

可重新分析：

```powershell
.\docs\acceptance\2026-10-28\performance\analyze-dashboard-run.ps1 -Csv .\docs\acceptance\2026-10-28\performance\dashboard-live-20261028-135536.csv
```

## 驗收判定

**PASS：初始程序樹資源基線已取得、正常關閉及本次觀察到的子程序退出已驗證。** 第一分鐘後沒有呈現明顯向上的線性 Private Bytes 趨勢，但不能據此宣稱無記憶體洩漏。

**A13 仍為 PARTIAL**：未取得至少 30 分鐘趨勢、Minimal 對照、locked／display-off 比較、GPU engine、100 次熱切換等證據；CSV 本身的實際時間跨度也尚未達 600 秒。結果只適用這台電腦、這個實機 Dashboard Preview 情境，不能外推到真正桌布或其他 Windows 組態。
