# Theme SDK

Theme SDK 是靜態 JavaScript 模組。已封裝的主題不需要 Node.js、C++ 或網路連線。SDK 檔案位於 `sdk/javascript/`；`sdk/theme.schema.json` 定義 `theme.json` v1。

## 授權與品牌

DrillPaper 第一方程式碼、SDK、文件與示範主題依 Apache-2.0 授權，詳見 repository 根目錄 `LICENSE`。此授權允許商業使用、修改與散布，但不授予 DrillPaper 名稱或標誌的商標使用權。第三方依賴、素材與社群主題各自依其授權。

## 主題 manifest

每個主題包含 `theme.json`、HTML 入口與本機靜態資產：

```json
{
  "id": "minimal-monitor",
  "name": "Minimal Monitor",
  "version": "1.0.0",
  "apiVersion": "1",
  "entry": "index.html",
  "author": "Example Author",
  "description": "A small local metrics theme.",
  "capabilities": ["cpu", "memory", "network", "clock"],
  "permissions": []
}
```

ID 是小寫、可攜式資料夾名稱；`version` 使用 SemVer 2.0.0；`entry` 是相對 `.html` 路徑。API v1 支援 `cpu`、`gpu`、`memory`、`disk`、`network`、`clock`，不提供選用權限。`sdk/javascript/theme-manifest.js` 的 validator 回傳 `{ valid, errors }`，可供本機作者工具使用；原生 Theme Manager 尚未實作，因此不能取代 host 端驗證。

## 使用 SDK

```js
import { DrillPaper } from './desktop-monitor-sdk.js';

const host = await DrillPaper.ready();
const snapshot = await DrillPaper.getSnapshot();
render(snapshot);

const off = DrillPaper.on('metrics', (nextSnapshot) => render(nextSnapshot));
await DrillPaper.subscribe({ metrics: ['cpu', 'memory', 'network'], intervalMs: 1000 });

function render(snapshot) {
  const value = snapshot.cpu?.usage;
  document.querySelector('#cpu').textContent =
    value?.quality === 'available' ? `${Math.round(value.value)}%` : '--';
}

window.addEventListener('pagehide', () => {
  off();
  void DrillPaper.unsubscribe();
}, { once: true });
```

`getHistory({ limit })` 最多回傳 120 筆快照。`ready()` 回傳 host 版本、宣告能力、狀態與限制。監聽器註冊會回傳取消函式。`DrillPaperClient` 接受可注入的 WebView 相容 transport，方便測試。初始交接規格中的 `DesktopMonitor` 與 `DesktopMonitorClient` 匯出仍保留為相容別名。TypeScript 宣告在 `sdk/javascript/desktop-monitor-sdk.d.ts`。

## 本機 MockHost 預覽

`sdk/javascript/mock-host.js` 提供瀏覽器介面模擬 host，會產生 CPU 數據、提供固定 RAM/網路值、歷史記錄與狀態事件。兩個示範來源在 `sdk/examples/minimal/` 與 `sdk/examples/dashboard/`。可用本機靜態開發伺服器提供 repository 檔案，再開啟範例入口；瀏覽器通常會禁止從 `file://` URL 載入 ES module。這是開發預覽，不是 DrillPaper WebView2 host；應用程式不會附帶 HTTP server。

示範來源的 `.dmt` 封裝會把 SDK 與 MockHost 模組放進套件，並將範例的相對匯入改成套件內路徑。可透過 EXE 的 `--import-theme` 匯入，並由原生「主題」功能表切換；操作見 `USER_GUIDE.md`。

## 目前驗證範圍

`npm run test:sdk` 的 Node SDK／MockHost／manifest 測試曾 18/18 通過。原生 ZIP 驗證、CLI 匯入及已安裝主題載入均有整合證據；100 次切換協定通過，資源增加及長時間穩定性仍保留限制。最新結果見 `acceptance/2026-10-28/theme-platform/REPORT.md`。TypeScript compiler 與完整瀏覽器安全負面整合尚未驗證。
