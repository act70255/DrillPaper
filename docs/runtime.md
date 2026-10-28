# Runtime 政策

## 有界資料流

- `MetricsHistory` 保存 120 筆 snapshot，超量時覆寫最舊項目。
- `LatestValueCoalescer<T>` 是單執行緒政策 seam；每次 publish 取代唯一待處理值。
- `WindowsSnapshotMailbox<T>` 已接入 app，是 worker/UI 的 SRW-lock adapter；取代待處理 snapshot，最多一個待通知狀態。資料附設定世代，UI 不會把恢復前排隊的樣本當作新快照。
- `SamplingWorker` 使用背景執行緒及條件變數，不在 UI timer 採集。0 間隔停止採樣，恢復即刻要求新基準；Stop 等待進行中的 callback 返回，不強制終止同步硬體 API。
- `MetricChangeDetector` 在可用性、品質、單位改變，或值超過呼叫者設定門檻時通知；預設 CPU 顯示門檻為一個百分點。

## 電源狀態政策

優先順序為 `Recovering`、`DisplayOff`、`Locked`、`Obscured`、`Active`。工作階段鎖定和螢幕電源事件即時生效；前景/全螢幕遮蔽狀態在呼叫端設定的 debounce 時間後才接受。

| 狀態 | 採樣間隔 | Renderer 可見 |
| --- | ---: | --- |
| Active | 1000 ms | 是 |
| Obscured | 5000 ms | 否 |
| Locked | 15000 ms | 否 |
| DisplayOff | 暫停 | 否 |
| Recovering | 1000 ms | 否 |

從其他狀態回到 `Active` 時，必須要求下一份完整 snapshot。`SamplingScheduler` 會等待到期時間，不會 busy-loop；晚醒後以當前時間排下一次工作，不補跑錯過的週期。

## 整合界線

WTS／顯示器通知在獨立 Win32 視窗接收，再交給純 runtime 政策；UI 只更新 renderer。WebView2 API 維持於 UI 執行緒，非 active 狀態不發送一般 metrics；Resume 後等待新世代快照。非同步 TrySuspend 以狀態世代處理取消／晚到 callback，並查詢 IsSuspended 後才顯示已暫停。

本機已通過 worker 行為、受控 Windows 事件整合、實際 WebView2 暫停／恢復及使用者真實鎖定／解鎖 5 次。`--no-smart-sleep` 可停用政策。真實 display-off／待機、全螢幕／多螢幕與長時間效能仍待驗收；證據見 `acceptance/2026-10-28/runtime/REPORT.md`。
