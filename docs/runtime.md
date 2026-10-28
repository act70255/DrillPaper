# Runtime 政策

## 有界資料流

- `MetricsHistory` 保存 120 筆 snapshot，超量時覆寫最舊項目。
- `LatestValueCoalescer<T>` 是單執行緒政策 seam；每次 publish 取代唯一待處理值。
- `WindowsSnapshotMailbox<T>` 是 worker/UI 配對預計使用的 SRW-lock adapter。它最多送一個 UI 通知，並取代待處理 snapshot；目前 app 沒有接上此 mailbox 或背景採樣 worker。
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

TDD CTest 覆蓋純 C++ 值型別政策，包括 bounded history/coalescing、state transition 與 scheduler。app 目前在 UI timer 同步採集，採樣 thread、取消/清理、Windows session/power event 註冊、renderer suspend/resume 與即時 mailbox 傳送仍未整合或驗證；核心單元測試不代表這些整合行為已通過。
