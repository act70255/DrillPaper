# DrillPaper JSON Protocol v1

本文定義 SDK 側的 v1 訊息契約。JavaScript SDK/`MockHost` 與原生 JSON parser/serializer、WebView2 bridge 均已實作並建置。CTest 與 Node tests 驗證 parser、SDK 契約；兩個內建 theme 也通過真實 WebView2 hello/snapshot/subscribe 程序層 smoke。這些結果不代表完整安全負面案例、renderer recovery 或畫面視覺驗收已通過。

## 訊息外框

每個訊息都是包含下列欄位的 JSON object：

```json
{
  "apiVersion": "1",
  "type": "metrics.snapshot",
  "requestId": "dm-1",
  "timestamp": "2026-10-27T07:00:00.000Z",
  "payload": {}
}
```

- `apiVersion` 固定為字串 `"1"`。JS SDK 忽略不相容版本，握手逾時。
- `type` 使用下表列出的名稱；未知訊息不得觸發任何原生操作。
- `requestId`：事件使用 `null`；請求使用不透明字串，回覆必須回送同一 ID。
- `timestamp` 是 UTC RFC 3339，結尾為 `Z`，小數秒可有 1–9 位。快照事件使用採樣時間；命令外框使用送出時間。
- `payload` 必須是 object。原生端收到訊息後必須先驗證 schema 才能分派。

單一訊息上限為 64 KiB；每個 renderer 最多 32 個未完成請求；歷史最多保留 120 筆。這些是協定限制，正式原生 host 仍須自行強制執行，不能信任 SDK 的前端檢查。

## 訊息流程

| 方向 | type | `requestId` | payload |
| --- | --- | --- | --- |
| JS → host | `theme.hello` | `null` | `{ sdkVersion: string }` |
| host → JS | `host.ready` | `null` | `{ hostVersion, capabilities, state, limits }` |
| JS → host | `metrics.getSnapshot` | 請求 ID | `{}` |
| host → JS | `metrics.snapshot` | 相同 ID；推播時 `null` | 完整 snapshot 欄位 |
| JS → host | `metrics.getHistory` | 請求 ID | `{ limit: 1..120 }` |
| host → JS | `metrics.history` | 相同 ID | `{ snapshots: MetricsSnapshot[] }` |
| JS → host | `metrics.subscribe` | `null` | `{ metrics: string[], intervalMs: 1000..60000 }` |
| JS → host | `metrics.unsubscribe` | `null` | `{}` |
| host → JS | `metrics.changed` | `null` | 完整 snapshot（v1 使用完整快照） |
| host → JS | `host.stateChanged` | `null` | `{ state: HostState }` |
| 任一方向 | `host.error` | 相關 ID 或 `null` | `{ code, message, recoverable? }` |

SDK 將 `getHistory` 限制在 1–120 筆。訂閱指標僅接受 `cpu`、`gpu`、`memory`、`disk`、`network`、`clock`，並移除重複與未知項目；更新間隔限制在 1,000–60,000 ms。原生 host 必須重複檢查，並可因能力或省電政策施加更嚴格限制。空指標清單表示訂閱 host 宣告能力範圍內的所有指標。

## 資料型別

`HostState` 為 `active | obscured | locked | display-off | recovering`；`MetricQuality` 為 `available | unavailable | stale | error`。`MetricValue` 格式為 `{ value: number | null, unit, quality }`。`null` 表示沒有讀值，不能當成零。單位是 `percent`、`bytes`、`bytes_per_second` 或 `celsius`。

時間戳記放在外框。SDK 回傳的快照與 `metrics` 事件會將它合併成 `timestamp` 欄位。記憶體是 bytes 或 `null`；CPU/GPU/磁碟活動使用 `MetricValue`；網路速率使用 `bytes_per_second`。

## 順序、錯誤與相容性

Renderer 只送一次 `theme.hello`，並等待 `host.ready` 後才由 SDK 發出查詢。Host 應先驗證來源、協定版本與主題識別後再回覆 ready。請求回覆必須同時符合 request ID 與預期回覆 type。非請求快照會送給訂閱者；帶相同 request ID 的 `host.error` 會拒絕該請求。

v1 穩定錯誤碼為 `invalid-envelope`、`unsupported-api-version`、`unsupported-message`、`invalid-payload`、`rate-limited`、`unavailable`、`internal-error`。`message` 供診斷，不是程式判斷用識別碼。Host 必須拒絕未知命令與越界值。

SDK 版本與協定版本分開。相容的 v1 host 可增加 capability 名稱，但不能改動既有單位、品質狀態意義、事件名稱、必要外框欄位或請求/回覆配對。未知 capability 只能當資訊，不能視為權限授予。

## 實作與尚未實作項目

JavaScript SDK 與 MockHost 支援握手、snapshot/history 查詢、訂閱、metrics 事件、歷史與更新間隔上限、請求逾時、32 個請求上限與版本拒絕；Node tests 覆蓋上述行為。原生端使用 `PostWebMessageAsJson`/`WebMessageReceived`，有 64 KiB、深度/節點數、欄位和 API version 檢查，並將內建 theme 映射到固定本機 virtual host；CTest 覆蓋 JSON parser/serializer，程序 smoke 覆蓋 hello→snapshot→subscribe。尚未以惡意 WebView message 做整合負面測試，也未執行 renderer crash recovery、截圖/人工視覺驗收。WebView2 host 的安全限制另見 `docs/theme-security.md`。
