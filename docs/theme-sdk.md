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

ID 是小寫、可攜式資料夾名稱；`version` 使用 SemVer 2.0.0；`entry` 是相對 `.html` 路徑。API v1 支援 `cpu`、`gpu`、`memory`、`disk`、`network`、`clock`，不提供選用權限。`sdk/javascript/theme-manifest.js` 的 validator 回傳 `{ valid, errors }`，可供本機作者工具使用；正式匯入仍由原生 ThemeManager 重新驗證 ZIP／manifest、staging 與原子安裝，作者檢查不能取代宿主邊界。

## 使用 SDK

```js
import { DrillPaper } from './desktop-monitor-sdk.js';

const host = await DrillPaper.ready();
const snapshot = await DrillPaper.getSnapshot();
render(snapshot);

const off = DrillPaper.on('metrics', (nextSnapshot) => render(nextSnapshot));
await DrillPaper.subscribe({ metrics: ['cpu', 'memory', 'network'], intervalMs: 1000 });

/** 顯示 CPU 可用性。
 * Args:
 *     snapshot: SDK 快照。
 */
function render(snapshot) {
  // 缺值必須顯示不可用；available 與 null 仍要分別檢查。
  const value = snapshot.cpu?.usage;
  document.querySelector('#cpu').textContent =
    value?.quality === 'available' && value.value !== null ? `${Math.round(value.value)}%` : 'unavailable';
}

window.addEventListener('pagehide', () => {
  off();
  void DrillPaper.unsubscribe();
}, { once: true });
```

`getHistory({ limit })` 最多回傳 120 筆快照。`ready()` 回傳 host 版本、宣告能力、狀態與限制。監聽器註冊會回傳取消函式。`DrillPaperClient` 接受可注入的 WebView 相容 transport，方便測試。初始交接規格中的 `DesktopMonitor` 與 `DesktopMonitorClient` 匯出仍保留為相容別名。TypeScript 宣告在 `sdk/javascript/desktop-monitor-sdk.d.ts`。

`HostReady.limits` 與原生 v1 一致：`{ history: 120, messageBytes: 65536 }`；訂閱最低 1000 ms 由 `MIN_UPDATE_INTERVAL_MS` 提供。舊宣告／MockHost 的 `maxHistory/minUpdateIntervalMs` 並非原生握手欄位，RC 07 已修正。MockHost 宣告另在 `sdk/javascript/mock-host.d.ts`。GPU 缺設備時是 `{ value: null, quality: 'unavailable', unit: 'percent' }`；真實 CPU／網路首次差分採樣可能 warm-up，勿把短暫不可用視為假 0 或 SDK 失敗。

## 從 SDK ZIP 建立 TypeScript 主題

SDK ZIP 包含 `sdk/author-starter/`、宣告、範例與正式 `scripts/package-theme.ps1`／`validate-theme-package.ps1`，不需要開發來源樹。將範本複製到自己的乾淨目錄，依其 [README](../sdk/author-starter/README.md) 安裝、準備宣告、執行 compiler 正負檢查並建置。完整命令如下；在複製出的作者目錄執行，路徑改成實際 SDK 解壓位置：

```powershell
npm ci --ignore-scripts --no-audit --no-fund
npm run configure -- 'C:\Users\James\DrillPaperTests\SDK\sdk\javascript'
npm run check
npm run build
& 'C:\Users\James\DrillPaperTests\SDK\scripts\package-theme.ps1' -ThemeDirectory .\dist -OutputFile ..\my-theme.dmt
& 'C:\Users\James\DrillPaperTests\SDK\scripts\validate-theme-package.ps1' -Path ..\my-theme.dmt
```

TypeScript **5.9.3** 由範本 `package.json` 與 lockfile 固定；`check` 明確核對版本，實際以 compiler 驗證 SDK／MockHost 正確用法及四個指定型別錯誤。編譯使用 ES2022 modules、strict、noEmitOnError，不略過宣告檢查。設定語意見 [TypeScript 官方 TSConfig](https://www.typescriptlang.org/tsconfig/)。Node／npm／compiler 僅用於作者建置，首次 npm ci 需取得 compiler；封裝後的 app 不需要這些工具或 HTTP server。

只打包 `dist`，它包含 `theme.json`、HTML、CSS、編譯出的 `main.js`；SDK JS／MockHost JS 由封裝器加入。不要把 `src`、`.ts`、`.d.ts`、`node_modules`、compiler 或 `.mjs` 放進 `.dmt`。匯入副檔名白名單未放寬；dist 也不可自行加入封裝器保留名稱的 SDK 模組。若使用 framework，亦須輸出離線靜態資產並沿用同一驗證邊界。

原生管理視窗按「匯入 .dmt」、選主題預覽，再勾選一個或多個目標、選桌布模式並套用儲存；各目標各自排版完整主題。API 不相容、非法資產與同 id／version 重匯入會拒絕；更新時增加 version，或先切換 Minimal、確認移除舊版本後再匯入。HTML 不具移除、設定或結束 app 的管理權限。網路預設關閉，開啟時允許 HTTP／HTTPS 資源，完整限制見 [安全模型](theme-security.md)。匯入的第三方內容仍是不受信任內容，套件通過不代表沙箱驗收完成。

## 本機 MockHost 預覽

`sdk/javascript/mock-host.js` 提供瀏覽器介面模擬 host，會產生 CPU 數據、提供固定 RAM/網路值、歷史記錄與狀態事件。兩個示範來源在 `sdk/examples/minimal/` 與 `sdk/examples/dashboard/`。可用本機靜態開發伺服器提供 repository 檔案，再開啟範例入口；瀏覽器通常會禁止從 `file://` URL 載入 ES module。這是開發預覽，不是 DrillPaper WebView2 host；應用程式不會附帶 HTTP server。

示範來源的 `.dmt` 封裝會把 SDK 與 MockHost 模組放進套件，並將範例的相對匯入改成套件內路徑。可透過 EXE 的 `--import-theme` 匯入，並由原生「主題」功能表切換；操作見 `USER_GUIDE.md`。

## 目前驗證範圍

RC 07 已執行固定 compiler、乾淨作者目錄／SDK ZIP、正式封裝、原生匯入／切換及 Preview／多目標的指定協定與 DOM 探針。證據、來源與套件 hash 見 repository 的 `docs/acceptance/2026-10-30/theme-author-flow/REPORT.md`（驗收紀錄不隨 SDK 散布）。GUI 檔案選擇器／匯入確認、人工版面、完整移除再匯入操作等仍為 NOT RUN，附人工清單；公開 ThemeManager 移除／重匯入契約另跑相關測試。SDK ZIP 驗證不替代 app 的 08 交付或 09 RC，既有安全／長時間限制仍保留。
