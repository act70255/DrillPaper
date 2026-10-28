# WebView2 程序退出復原驗收

2026-10-28，Windows 11 Pro 25H2 26200.8737，`feature/renderer-recovery`。本階段完成 renderer／browser 程序退出的有界復原，不宣稱其他安全或全部復原情境均通過。

## 重現與實作

新增原生 `DrillPaper.ReadyEpoch` 診斷屬性，只在收到當前來源的新 SDK 訂閱後遞增；不是看到舊 Live metrics 標題就當作恢復。測試先以獨立 LOCALAPPDATA 啟動 app，以 CIM 驗證 browser 父 PID 及唯一 profile 路徑，再只終止該 browser 下的 renderer；不能確認歸屬即停止，不終止其他使用者的 WebView2。

舊 app 已完成初始握手（世代 1），終止 renderer 後未取得新握手，測試先 FAIL，見 [before-fix/summary.json](before-fix/summary.json)。另有一次初始通訊未完成的 setup failure，不當作 renderer 故障重現。復原測試用既有 `--no-smart-sleep` 固定 active，隔離前景／電源政策；不外推到 crash 與實際鎖定同時發生。

實作 ProcessFailed 訂閱，回到原生 UI 迴圈後重建 controller／environment 與原主題。每次載入有新的來源及載入世代，舊通知與舊 COM callback 不影響新 view；新舊 callback 以 lifetime token 分隔。保留原生工作者與有界快照，不重新啟動 app。自訂 entry 會保留，不誤載 index.html。

每次主題載入最多 3 次自動重建；達上限後嘗試 Minimal，再次達上限便停用 renderer、退回可關閉的原生 Preview。電源非 active 時暫停計算主題握手逾時，避免把刻意暫停的頁面當作載入失敗。

## 實際驗證

| 命令情境 | 結果 |
| --- | --- |
| renderer 終止 3 次 | PASS：同一 app PID 每輪有新握手世代與 live 狀態、正常退出 0；[renderer-3/summary.json](renderer-3/summary.json) |
| browser 終止 3 次 | PASS：同一 app PID 每輪重建後有 renderer、新握手與 live 狀態、正常退出 0；[browser-3/summary.json](browser-3/summary.json) |
| renderer 終止 8 次 | PASS：前 3 次重建、切到 Minimal，再達上限後握手屬性清除、原生停止標題出現，app 仍可關閉且退出 0；[bounded-8/summary.json](bounded-8/summary.json) |
| 非 index.html 主題入口 | PASS：安裝 entry=pages/view.html 的測試主題，載入後終止 renderer，仍以原入口完成新握手並退出 0；[custom-entry/summary.json](custom-entry/summary.json) |

```powershell
cmake --build --preset windows-msvc-release --target DrillPaper --parallel 8
.\scripts\test-renderer-recovery.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Crashes 3
.\scripts\test-renderer-recovery.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -ProcessKind browser -Crashes 3
.\scripts\test-renderer-recovery.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Crashes 8 -ExpectBoundedFallback
.\scripts\test-renderer-recovery.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Crashes 1 -CustomEntry
```

以上是實際 Windows／WebView2 程序與協定測試，並非每次畫面或物理硬體驗收。測試物件與 profile 均隔離；測試紀錄保留 PID／世代／耗時及退出結果。

## 仍待驗證

實際無限迴圈／unresponsive renderer、crash 與鎖定／display-off 交錯、GPU／utility 子程序異常、Explorer 復原、安全負面矩陣及全產品發行條件未完成。ProcessFailed 的 unresponsive 分支已接上，但不能由「有 handler」宣稱無限迴圈情境通過。原生預覽停止 renderer 後需關閉再啟動，不是假裝瀏覽器仍可用。
