# DesktopMonitor — Codex CLI 全流程開發 Handoff

> 文件版本：v1.0｜建立日期：2026-10-27｜語言：繁體中文（台灣）｜預定平台：Windows 10 / Windows 11 x64
>
> **交接目標**：將本文件放到本機 Git 專案根目錄，交由 Codex CLI 依規格完成設計、實作、測試、效能驗證、文件、封裝與發行準備。這是一份 **可執行的工程規格**，不是純粹概念說明。

---

## 0. 給 Codex CLI 的直接執行指令（先讀）

你現在是本專案的主要實作工程師、架構師與測試工程師。請完整閱讀 `DesktopMonitor_Codex_Handoff.md`，先調查當前 repository 和 Windows 開發環境，再按本文工作流逐階段實作 **DesktopMonitor**。

**主要任務：**打造一套可公開發行的 Windows 動態桌面資訊儀表板平台。原生 C++ 核心採集系統資訊，WebView2 顯示可由社群自行開發的 HTML/CSS/JavaScript 主題，並提供 Theme SDK、預覽模式、測試與封裝。

**執行紀律：**

1. 先做 repository/environment audit 和可驗證的桌布整合 Proof of Concept（POC），之後按各階段逐步交付；不要直接一次生成大量未驗證的程式碼。
2. 延用 repository 已存在的規範、Skills、TDD 流程及建置工具。若找到適用的本機 TDD skills，先閱讀並依其慣例執行；但不能犧牲 Windows 原生 GUI 與硬體測試的正確性。
3. 每個可測試的需求遵循 **Red → Green → Refactor**，持續跑單元測試、整合測試及靜態檢查；以小步 Git commits 紀錄可運作的里程碑。
4. 若本機可用 MSVC、Windows SDK、WebView2 SDK，就實際編譯與測試。**不得把未實際執行的編譯、GUI、效能、Windows 相容性測試寫成 PASS。**
5. 外部依賴僅選成熟、文件完整、授權允許再散布的函式庫；鎖定版本或記錄來源與版本。避免無必要的 Qt、Node.js、Electron、Python Runtime、HTTP Server、SQLite。
6. 除非存在無法自行解決的根本性阻礙，請自主完成可行工作，不要每一步都要求人工確認。受限於硬體、作業系統或憑證的任務要明確標記 BLOCKED，仍完成其餘工作。
7. 不得因為方便而弱化第三方 HTML 主題安全性；**沒有安全驗證就不能宣稱第三方主題是沙箱化的**。
8. 每個階段更新 `docs/STATUS.md`：已完成、測試證據、缺陷、下一步。最後交付 `docs/FINAL_HANDOFF.md`，說明所有可重現的建置、執行、測試、發行步驟。
9. 本文件的「必須」是驗收條件；「建議」是可依技術證據調整的預設值。若採不同設計，寫成 ADR（Architecture Decision Record）並解釋可測試的理由。

**完成定義：**原生宿主可在支援的 Windows 環境作為真正桌布顯示且不阻擋桌面圖示，能以 C++ 監控系統資料，WebView2 以 JSON 事件推送更新，能安裝／切換／預覽第三方 HTML 主題，具備智慧休眠、有限快取、錯誤復原、安全檢查、測試、文件、CI 和可供他人安裝的發行產物。若特定 Windows Shell 版本仍有相容性缺口，必須提供可用的 Preview fallback 並誠實記錄，不能假裝功能已完成。

---

## 1. 產品目標、使用者與邊界

### 1.1 願景

**DesktopMonitor = Native System Metrics Engine + Web Wallpaper Host + Open Theme Platform**

- 一般使用者：安裝應用程式，選擇主題後，在 Windows 桌面背景看到時間與系統資源資訊。
- 主題創作者：僅使用 HTML、CSS、JavaScript（也可用 React/Vue/Svelte 編譯出的靜態檔）製作主題，不需要 C++／Windows SDK。
- 核心開發者：可持續增加新的感測器、監控指標與桌面相容性修正，而不破壞已發行主題。
- 隱私原則：資料在本機採集、本機顯示；預設不需要登入、雲端帳號、遠端伺服器或遙測。

### 1.2 不可妥協的設計

- Windows 專用，首版以 x64、單一顯示器為驗收基準；多顯示器列為後續階段，但架構不能封死。
- **C++20 + Win32 + WebView2 Evergreen + CMake + MSVC** 為預設主技術棧。Qt 不列為 MVP 必需依賴；若要加入，必須由實測及功能需求證明價值。
- 採集／排程／狀態／儲存／傳輸／UI 解耦；一個原生主程式可以使用數個執行緒，但 **WebView2 必然可能啟動多個 `msedgewebview2.exe` 子程序**，不得標成真正單程序產品。
- 主題完全可替換，不綁死特定 HTML UI；不提供會執行任意原生碼的外掛機制。
- 不需要額外本機 HTTP Server；優先 WebView2 virtual-host folder mapping。
- 不允許監控程式要求系統管理員權限才能執行基本功能；需要提升權限的感測器只能作為選配並清楚標示。
- 預設採集低頻更新、UI 變更推送；大量資料事件要合併，防止 UI 通訊積壓。
- 具備全螢幕、鎖定、顯示器關閉狀態下的節能政策；安全地恢復顯示。

### 1.3 MVP：必做

1. 真正的桌面背景顯示，**在桌面圖示後方**，圖示與工作列能正常點擊；另有獨立視窗 `--preview` 測試模式。
2. CPU 使用率、RAM 已用／總量、網路上下傳 bytes/s、目前時間；GPU 使用率先支援 **NVIDIA NVML 可用的裝置**，偵測不到時顯示 `unavailable` 而非 0。磁碟使用率／活動量應提供 Windows 可實現的可靠指標與單位定義。
3. 原生定期採樣，標準化 immutable snapshot，ChangeDetector，bounded history／ring buffer，coalescing event queue。
4. WebView2 啟動、載入本機 HTML，原生 JSON 訊息與 JS API，主題載入／切換／預覽／錯誤 fallback。
5. 至少兩個可運行示範主題：`minimal`（幾乎無動畫）、`dashboard`（基本折線圖／進度條）。
6. 第三方主題資料夾／`.dmt`（ZIP）匯入驗證；`theme.json` 統一規格，`apiVersion` 相容性檢查。
7. 全螢幕／鎖定／顯示器關閉／恢復的省電策略；Explorer 重啟後的復原策略及失敗 fallback。
8. 可重現建置、單元測試、Mock metrics、主題 SDK 文件、安裝包／可攜式套件、基本 Windows CI。

### 1.4 非 MVP／禁止偷偷納入

- 主題商城、雲端帳號、社群後端、付款、遠端資料收集、AI 主題生成。
- 第三方 DLL 或任意原生程式碼插件。
- 開發自有核心模式驅動程式、規避權限管制、無限制感測器讀取。
- 影音桌布、音效、即時網路互動、主題直接存取本機檔案系統。
- 自行實作瀏覽器引擎或取代 WebView2 Chromium 程序。
- 同時支援 Linux / macOS，除非未來另立規格。

---

## 2. 實作架構與元件契約

```text
DesktopMonitor.exe (C++20 / Win32)
│
├─ Bootstrap / AppLifecycle / Logging / Config / DI (manual composition)
├─ Platform.Windows
│  ├─ DesktopHost / ShellWindowLocator / ExplorerRecovery
│  ├─ MonitorInfo / DpiAwareWindow / PowerAndSessionNotifications
│  └─ PreviewWindow / SystemTray (simple management interface)
├─ Monitoring
│  ├─ CpuCollector (GetSystemTimes or PDH)
│  ├─ MemoryCollector (GlobalMemoryStatusEx)
│  ├─ DiskCollector (PDH / tested Windows counters)
│  ├─ NetworkCollector (IP Helper API + time deltas)
│  └─ GpuCollector (optional NVML adapter + graceful fallback)
├─ Runtime
│  ├─ MetricsSnapshot / CapabilityCatalog / MetricQuality
│  ├─ SamplingScheduler / ChangeDetector / LatestSnapshot
│  ├─ RingBuffer / EventCoalescer / PowerStateMachine
│  └─ RendererVisibilityPolicy
├─ Web
│  ├─ WebView2Environment / Controller / NavigationPolicy
│  ├─ ThemeHost / NativeBridge / MessageSchemaValidator
│  └─ ErrorFallback / RendererRecovery
└─ ThemePlatform
   ├─ ThemeManifest / PackageValidator / ThemeManager
   ├─ VirtualHostMapping / PermissionPolicy
   └─ ThemeSdkAssets / MockMetricsMode

[WebView2 Runtime: browser / renderer / GPU / helper child processes]
    ↕ strict versioned JSON protocol
HTML + CSS + JavaScript (theme, via DesktopMonitor SDK)
```

### 2.1 依賴方向

- `Monitoring` 只依賴 `Core` 資料模型與 Windows API，不依賴 WebView2 / HTML / DesktopHost。
- `Runtime` 不接觸 UI；透過資料或訊息介面提供 `MetricsSnapshot`。
- `Web` 是 renderer adapter，與 UI 通訊使用版本化 JSON contract。
- `DesktopHost` 管理 Windows Shell parent/z-order/lifecycle；任何 Shell 技巧要藏在介面後，不得滲透到 Renderer 或 Collector。
- `ThemeManager` 決定可載入內容、來源、權限與相容版本；不能直接允許主題自行呼叫 Native API。
- 使用 RAII、`std::unique_ptr`、必要時 WIL smart pointers 封裝 COM／HANDLE；明確規定 COM apartment 與 UI thread ownership。

### 2.2 建議介面（概念性；以測試與實際 SDK 型別為準）

```cpp
struct MetricValue {
    std::optional<double> value;
    std::string unit;       // percent / bytes / bytes_per_second / celsius
    std::string quality;    // available / unavailable / stale / error
};

struct MetricsSnapshot {
    std::chrono::system_clock::time_point timestamp;
    MetricValue cpu_usage;
    MetricValue gpu_usage;
    MetricValue ram_used_bytes;
    MetricValue ram_total_bytes;
    MetricValue disk_activity_percent;
    MetricValue net_rx_bytes_per_sec;
    MetricValue net_tx_bytes_per_sec;
};

class IMetricCollector {
public:
    virtual ~IMetricCollector() = default;
    virtual void collect(MetricsSnapshot& snapshot) = 0;
};

class IDesktopHost { /* attach / detach / restore / monitor events */ };
class IRenderer { /* initialize / navigate / send / suspend / resume */ };
class IThemeManager { /* list / validate / import / activate / rollback */ };
```

**重點**：不可把 `0` 同時當成「正常 0%」和「無法讀取」。讀數必須有可用性／品質狀態；採樣速率、磁碟百分比與網路速率必須有清楚定義。時間戳記與採樣間隔分開處理，避免睡眠恢復後出現異常巨大數值。

### 2.3 執行緒／佇列

- Win32 主執行緒持有視窗、COM WebView2 controller、訊息迴圈；回到此執行緒處理 WebView2 API 呼叫。
- 背景採樣執行緒執行同步硬體讀取，不可長時間阻塞 UI；可停止、可取消、可安全釋放資源。
- 採樣器產生 immutable snapshot，ChangeDetector 判斷值是否達到有意義的差異，再向 UI 送出「最新快照可用」訊號。
- UI 待處理佇列最多保留 **1 個最新快照**（replace/latest-wins），絕不無限成長；UI 忙碌時跳過過期資料。
- 需要保留曲線的歷史記錄使用獨立有界 Ring Buffer；不要把「丟棄 UI 訊息」誤用成「丟棄所有歷史資料」。
- 不持有 UI 鎖時執行 COM callback，避免 deadlock 與 stale event after shutdown。

---

## 3. Windows 桌布整合（最高技術風險，先做 POC）

### 3.1 必須驗證的事

Windows 沒有對第三方 HTML 動態桌布公開保證穩定的標準 API。常見 `Progman`／`WorkerW`／`SHELLDLL_DefView` 加上 `SetParent` 的做法，依賴 Explorer 內部視窗結構；Windows 11 的部分版本曾改變相關結構。

**工作要求：**

1. 建立 `IDesktopHost` 實作及功能偵測；禁止假設 `WorkerW` 一定存在或一定是正確父視窗。
2. 先用純色／測試視窗驗證桌布宿主，再放入 WebView2。避免將畫面渲染問題誤判為 Shell 問題。
3. 視窗應位於桌面圖示之後、一般應用程式視窗之前後關係正確；不能覆蓋工作列或攔截桌面圖示點擊。
4. 測試 `Explorer.exe` 重啟、解析度／DPI 改變、登入解鎖、睡眠喚醒、WebView2 renderer crash、顯示器切換。
5. 若受 Windows 版本影響無法安全附掛，**退回可見且可關閉的 Preview 模式**，顯示明確錯誤。不得以置頂透明全螢幕視窗偽裝成功。
6. 使用 `/docs/compatibility-matrix.md` 記錄實測 Windows build、螢幕配置、成功方式、問題與證據；不要將未測試版本列為支援。

### 3.2 POC 驗收

- 設定桌布後，桌面圖示可見且可操作，工作列與 Alt+Tab 行為正常。
- 桌布不搶前景焦點；不需要手動每隔數秒把視窗送到最底層。
- 退出程式時不殘留 Explorer 視窗異常；能恢復原先 Windows 桌布顯示。
- Explorer 終止／恢復後可重建桌布宿主，或安全返回 Preview 並記錄原因。
- GUI smoke test 與實機檢查必須明確區分；不可用單元測試取代桌面操作驗收。

---

## 4. 系統資料與採樣規格

| 指標 | 來源（建議） | 預設採樣 | 單位 | 錯誤處理 |
|---|---|---:|---|---|
| CPU 總使用率 | `GetSystemTimes` 兩次採樣差值，或 PDH | 1 s | percent | 第一筆 warm-up，不顯示假 0 |
| RAM 已用／總量 | `GlobalMemoryStatusEx` | 1 s | bytes | API 失敗標記 error |
| 磁碟活動量 | PDH 經實測的計數器 | 1–2 s | percent 或 bytes/s | 分清活動率與吞吐量 |
| 網路 RX/TX | IP Helper API 累積計數差值 | 1 s | bytes/s | 介面切換、計數器重設時重置基準 |
| NVIDIA GPU 使用率 | 動態載入 NVML | 1–2 s | percent | 無 NVML/非 NVIDIA/不支援時 unavailable |
| GPU 溫度（可選） | NVML 有支援才顯示 | 3–5 s | celsius | 選配／可缺省 |
| CPU/主機板溫度 | 非 MVP | — | celsius | 不自行寫核心驅動 |
| 當地時間 | 系統時鐘／前端時間顯示 | 1 s 顯示 | ISO8601 / local display | 恢復後重新同步 |

- 採樣不得直接觸發頻繁完整重繪，UI 只更新真正有變化的值；文字顯示精度與內部數值精度分離。
- 設定預設 ChangeDetector 門檻（例如使用率顯示差距 1 個百分點，或四捨五入值改變）；門檻須可測試。
- MVP 不要求不同廠牌的所有 GPU 都有完整資訊；未支援硬體須在 capability 清單清楚呈現，不能無訊息地假裝成功。
- 所有 native SDK 授權與散布限制必須檢查；NVML 採系統已安裝驅動程式的函式庫，不能未經確認把供應商 DLL 打包。

---

## 5. 智慧休眠：狀態機與政策

| 狀態 | 觸發條件 | 採樣建議 | Web 渲染政策 |
|---|---|---|---|
| `Active` | 桌布可見／正常操作 | 1 s | 推送有變更的資料；允許主題動態效果 |
| `Obscured` | 對應顯示器被全螢幕程式遮蔽 | 5 s | 停止推送動畫資料，視情況隱藏 WebView2 |
| `Locked` | 工作階段鎖定 | 15 s 或停止 | WebView2 暫停 |
| `DisplayOff` | 顯示器關閉 | 暫停非必要採樣 | WebView2 暫停 |
| `Recovering` | Shell/WebView2 crash、睡眠恢復 | 依恢復程序 | 重新初始化並送出最新完整快照 |

- 事件來源：`WTSRegisterSessionNotification`、`RegisterPowerSettingNotification`、前景視窗事件及全螢幕判斷；全螢幕判斷可能有誤差，不能當作安全邊界。
- 必須避免因視窗重疊事件而反覆啟動／關閉引擎（debounce / hysteresis）。
- **WebView2 的 `TrySuspend` 有使用前提：controller 不可見 (`IsVisible == FALSE`)；失敗時要退化為降低事件／動畫更新，而不是當成已成功暫停。**
- `Resume` 後必須補送 full snapshot，重置需要重新採樣的差分基準，確保時間與數值正確。
- 若已暫停但有新 Native Metric 事件，不可不斷強迫 WebView2 自動恢復。
- 設定可關閉智慧休眠以利除錯，發行版預設啟用。

---

## 6. Theme SDK：對外公開 API（穩定性重點）

### 6.1 主題目錄與封裝

```text
DesktopMonitor/
├─ DesktopMonitor.exe
├─ resources/
│  ├─ themes/minimal/{theme.json,index.html,style.css,main.js}
│  └─ themes/dashboard/{theme.json,index.html,assets/...}
├─ sdk/
│  ├─ desktop-monitor-sdk.js
│  ├─ desktop-monitor-sdk.d.ts
│  ├─ mock-host.js
│  └─ examples/
└─ docs/
   ├─ theme-sdk.md
   ├─ theme-security.md
   └─ protocol-v1.md

%LOCALAPPDATA%/DesktopMonitor/
├─ config.json
├─ themes/<installed-theme-id>/...
├─ WebView2UserData/...
└─ logs/...
```

`.dmt` 定義為 UTF-8 manifest + HTML 靜態資產的 ZIP 容器；主題打包為單一 `.dmt` 檔案，匯入時先驗證再展開到 staging，通過後採原子性替換／安裝。不得將第三方資料寫入 Program Files 或任意系統路徑。

**`theme.json` v1 範例：**

```json
{
  "id": "minimal-monitor",
  "name": "Minimal Monitor",
  "version": "1.0.0",
  "apiVersion": "1",
  "entry": "index.html",
  "author": "Example Author",
  "description": "Low-overhead monitor",
  "capabilities": ["cpu", "memory", "network", "clock"],
  "permissions": []
}
```

- 規定唯一 ID 格式、語意版本、主題 entry 相對路徑、檔案大小／數量與解壓上限。
- Manifest 各欄位的驗證條件、預設值、錯誤回報必須有 JSON Schema 和負面測試。
- 可使用既有 Web 前端框架，但輸出必須是**可離線載入的靜態產物**，不可要求 Node.js 執行時。
- 主題切換不重啟原生採集程序；載入失敗時回復前一主題或內建 `minimal`。

### 6.2 訊息協定 v1

**統一封包**（示例）：

```json
{
  "apiVersion": "1",
  "type": "metrics.snapshot",
  "requestId": null,
  "timestamp": "2026-10-27T07:00:00Z",
  "payload": {
    "cpu": { "usage": { "value": 24.5, "unit": "percent", "quality": "available" } },
    "gpu": { "usage": { "value": null, "unit": "percent", "quality": "unavailable" } },
    "memory": { "usedBytes": 33751040000, "totalBytes": 103079215104 },
    "network": { "rxBytesPerSec": 123456, "txBytesPerSec": 23456 }
  }
}
```

必要的事件／命令（可按測試調整具體名稱，發布 v1 後不可任意更改）：

| 方向 | 訊息 | 作用 |
|---|---|---|
| JS → Native | `theme.hello` | API 版本握手、主題來源驗證 |
| Native → JS | `host.ready` | 能力清單、有效功能、初始狀態 |
| JS → Native | `metrics.subscribe` | 訂閱指標與更新節奏；須套用主機限制 |
| JS → Native | `metrics.unsubscribe` | 取消訂閱 |
| JS → Native | `metrics.getSnapshot` | 取得最新完整快照 |
| JS → Native | `metrics.getHistory` | 讀取有上限的歷史資料 |
| Native → JS | `metrics.snapshot` | 初次載入／恢復後完整狀態 |
| Native → JS | `metrics.changed` | 合併後的差分更新（或 v1 先全快照） |
| Native → JS | `host.stateChanged` | active / obscured / locked / display-off |
| Native → JS | `host.error` | 明確錯誤碼、可復原狀態 |

**定義 v1 的數據資料型態、時間戳記、缺失值、版本相容性、推送頻率、訂閱上限、錯誤碼、同步順序。** 不要允許主題傳任意 C++ 函式名稱或 Windows API 名稱。

### 6.3 前端 SDK 目標用法

```javascript
import { DesktopMonitor } from './desktop-monitor-sdk.js';

await DesktopMonitor.ready();
const snapshot = await DesktopMonitor.getSnapshot();
const off = DesktopMonitor.on('metrics', (data) => {
  document.querySelector('#cpu').textContent =
    data.cpu.usage.value == null ? '--' : `${Math.round(data.cpu.usage.value)}%`;
});
// 主題銷毀時 off();
```

- `desktop-monitor-sdk.js` 要封裝 raw `window.chrome.webview`，不能讓主題作者依賴內部 message wire format。
- 提供 `.d.ts` 型別宣告、`mock-host.js`；允許直接開瀏覽器預覽模擬數值、錯誤狀態、休眠／恢復事件。
- SDK、protocol 需獨立測試；一個舊版 v1 主題在未來更新後仍可正常載入。

---

## 7. WebView2 與第三方主題安全規格（發行阻擋條件）

1. **來源限制**：以 `SetVirtualHostNameToFolderMapping` 對應經驗證的本機主題根目錄，不以 `file://` 跨路徑亂讀；載入來源須明確驗證，主題間不得互相讀取資料。設定最低必要 `HostResourceAccessKind` 並驗證效果。
2. **導覽／彈窗**：拒絕未授權的 top-level navigation、`window.open`、新視窗、下載、權限請求；需要外部 URL 時應經明確可控制流程，預設禁止。
3. **Native Bridge**：接收訊息前驗證來源、API 版本、schema、訊息大小、事件速率、允許的操作、請求權限；不可提供任意命令、PowerShell、shell execute、DLL 載入或通用檔案讀寫。
4. **網路存取**：未獲授權的主題預設不得取得網路存取能力；設計 `CSP` 與 request/navigation policy，並測試 `fetch`、XHR、圖片、script、iframe、WebSocket、重新導向。**單靠 CSP / WebResourceRequested 未必對所有通訊面向構成完整沙箱；未驗證前不可承諾可完全阻擋網路外傳。**
5. **壓縮檔安全**：拒絕 absolute paths、`..` traversal、UNC、NTFS alternate data streams、reparse-point／符號連結危害、ZIP bomb、極端巢狀與過量檔案；先驗證總解壓大小、單檔上限、檔案數量與名稱正規化。
6. **權限最小化**：預設以一般使用者權限執行；WebView2 user data 使用 app 私有目錄；不要以系統管理員身分執行 WebView2。
7. **資訊隱私**：API 預設只揭露已核准的使用率和記憶體等必要資訊；裝置序號、路徑、使用者帳號等敏感資訊不列為開放欄位。無遙測、無背景上傳。
8. **程式碼注入避免**：原生發送 JSON 使用 WebView2 `PostWebMessageAsJson`；不要把不可信字串串接到 `ExecuteScript`。
9. **恢復安全**：主題崩潰或迴圈造成高資源使用時，可切回安全內建主題；限制重試次數並提供使用者停用問題主題的方法。

安全文件須提供威脅模型、已覆蓋與未覆蓋的攻擊面、測試方式。**如果無法以 MVP 架構可靠限制第三方主題網路行為，必須在發行說明提醒使用者只安裝信任的主題，或先停用任意第三方主題匯入，不能隱瞞限制。**

---

## 8. 效能政策與測試方法

### 8.1 原則

- 目標是**在相同儀表板功能下，最低可行的整體系統資源使用量**，不是承諾 C++ 自然比其他語言更快。
- 渲染引擎實際的記憶體必須把 `DesktopMonitor.exe` 與屬於它的 WebView2 子程序**合計**，不能只看主程式。
- `minimal` 主題預設無 CSS 無限動畫、無固定 60 FPS requestAnimationFrame 迴圈。
- 對變更資料使用合併更新；時間顯示可以 1 秒更新，不需要重繪所有卡片。
- 固定長度歷史資料預設 120 筆/指標，寫入時覆蓋舊值，不會無限成長。
- 閒置時優先使用等待事件而非 busy-loop；避免高頻率輪詢 UI visibility。

### 8.2 量測矩陣（必須留原始資料與重現步驟）

| 情境 | 時間 | 測量指標 |
|---|---:|---|
| 啟動至首次有效資料 | 至穩定 | 啟動時間／首筆數值時間 |
| `minimal` 桌布正常顯示 | 10 分鐘 | CPU 平均／p95、總 Private Bytes、Working Set、GPU Engine、讀取頻率 |
| `dashboard` 主題正常顯示 | 10 分鐘 | 同上 |
| 被全螢幕遊戲覆蓋 | 10 分鐘 | CPU／GPU／WebView2 暫停狀態與恢復正確性 |
| Windows 鎖定／解鎖 | 往返 5 次 | 恢復延遲、錯誤、資料一致性 |
| 螢幕關閉／打開 | 往返 5 次 | CPU／GPU／採樣與渲染狀態 |
| 主題切換 A↔B | 100 次 | private bytes 變化、handle count、崩潰／資源洩漏 |
| Explorer 重啟／WebView2 crash | 各至少 3 次 | 回復行為／未復原警示 |

**效能接受準則：**

- 不得在沒有 benchmark 的情況下寫出「一定 < 20MB」等保證。
- 第一個成功的 POC 先記錄 baseline；以 `minimal` 為基準衡量每項功能增加的成本。
- 必須至少提供 30 分鐘 memory trend，確認沒有無界成長跡象；觀察 cache 與 Chromium 緩存造成的合理波動。
- 對 `Active` 與 `DisplayOff`／`Locked` 的 CPU 消耗做量化比較；若暫停反而沒有改善，調查根因並記錄。
- 優先完成 Windows Performance Recorder/Analyzer、Process Explorer 或 PowerShell 性能採樣腳本之一；輸出 CSV 與簡明 summary。

---

## 9. Git repository 建議結構

```text
DesktopMonitor/
├─ .github/workflows/windows.yml
├─ .gitignore
├─ AGENTS.md                      # 將本文件最重要的不可妥協規範摘錄於此
├─ CMakeLists.txt
├─ CMakePresets.json
├─ LICENSE                       # 決定授權後補齊；不要自行冒用第三方授權
├─ README.md
├─ DesktopMonitor_Codex_Handoff.md
├─ cmake/
├─ third_party/                   # 僅包含可合法散布的必要宣告/小型元件
├─ src/
│  ├─ app/
│  ├─ core/
│  ├─ platform/windows/
│  ├─ monitoring/
│  ├─ runtime/
│  ├─ web/
│  └─ themes/
├─ include/desktopmonitor/
├─ resources/themes/minimal/
├─ resources/themes/dashboard/
├─ sdk/javascript/
├─ sdk/mock/
├─ tests/
│  ├─ unit/
│  ├─ integration/
│  ├─ contracts/
│  ├─ fixtures/
│  └─ manual/
├─ scripts/
│  ├─ build.ps1
│  ├─ test.ps1
│  ├─ perf.ps1
│  └─ package.ps1
└─ docs/
   ├─ STATUS.md
   ├─ FINAL_HANDOFF.md
   ├─ ARCHITECTURE.md
   ├─ ADR/
   ├─ compatibility-matrix.md
   ├─ protocol-v1.md
   ├─ theme-sdk.md
   ├─ theme-security.md
   ├─ performance.md
   └─ release-checklist.md
```

- 建置用 MSVC 與 Windows SDK，`CMakePresets.json` 至少支援 Debug/Release；考慮 Ninja。
- 測試框架選 GoogleTest 或 Catch2（擇一）；第三方依賴版本與授權寫入 `THIRD_PARTY_NOTICES.md`。
- JSON 採用成熟 C++ library，Theme schema 驗證應具備獨立負面測試。
- 所有程式碼或文件路徑儘量支援非英文 Windows 使用者資料夾。
- UTF-8、x64、DPI aware、預設 Release 優化，避免隱含管理員需求。

---

## 10. Codex 完整開發工作流（依序執行）

> 每一階段都要記錄：需求 → 失敗測試 → 最小實作 → 通過測試 → 重構 → commit → `docs/STATUS.md` 更新。

### Phase 0 — Repository / Environment Audit

**任務**
- 檢查是否已存在 repo、`.git`、`AGENTS.md`、本機 TDD skills 與既有程式；不要覆蓋既有工作。
- 檢查 OS、MSVC / VS Build Tools、CMake、Windows SDK、WebView2 Runtime / SDK、PowerShell、Git、可用的 GPU。
- 建立建置腳本及 CMake Presets，選定 dependency pinning 與測試框架。
- 記錄完整可重現的 Windows 建置步驟；若缺工具，先調整可用範圍且標註 blocker。

**交付物**：`README.md` 初版、`docs/STATUS.md`、`docs/ARCHITECTURE.md`、基本可編譯最小 Win32 程式、`AGENTS.md`、環境檢查腳本。

**Gate**：能在現有環境實際編譯並執行（若目前非 Windows，必須誠實標示 Windows GUI 為未測）。

### Phase 1 — DesktopHost Feasibility Spike（優先）

**任務**
- 建立 `PreviewWindow` 與 `DesktopHost`，先用測試色塊驗證桌面附掛，不涉及硬體 SDK。
- 偵測 Shell window hierarchy、DPI、螢幕邊界，驗證圖示是否仍能互動。
- 提供安全失敗 fallback；加入 Explorer restart 復原與故障日誌。

**測試**：窗口管理單元／模擬測試 + Windows GUI manual matrix。

**Gate**：桌面圖示仍可用、不阻擋前景、能關閉、能在支援環境恢復；否則不得宣稱桌布功能完成。

### Phase 2 — Metrics Core + TDD

**任務**
- 定義 `MetricsSnapshot`、品質狀態、metric capabilities、MockCollector、FakeClock。
- 完成 CPU / RAM / Network / Disk 基礎採集；NVML 選配 adapter，缺少設備可正常運行。
- 加入單位正規化、採樣失敗、網卡重設、系統睡眠時間跳動之測試。
- 採樣來源與 Renderer 雙向完全獨立。

**Gate**：在無 GPU、API 拋錯、首次 warmup 的測試中均正常且無錯誤的假數值；單元測試可無 GUI 執行。

### Phase 3 — Runtime / State Machine / Bounded Cache

**任務**
- `SamplingScheduler`、`LatestSnapshot`、`RingBuffer`、`ChangeDetector`、`EventCoalescer`。
- 實作 `Active/Obscured/Locked/DisplayOff/Recovering` 狀態機。
- 以 FakeClock 與 FakePowerEvents 測試 debounce、頻率切換、取消與 resume。
- 確保停機能 clean shutdown；無資料競爭、無死結。

**Gate**：歷史記錄永遠有限、事件爆量時最後值正確、沒有 busy-loop，鎖定／恢復有測試。

### Phase 4 — WebView2 Host + Protocol v1

**任務**
- 初始化 WebView2 Environment 與單一 controller（首版）；處理 Runtime 缺失／WebView2 crash。
- 實作來源限制、virtual host mapping、host→web `PostWebMessageAsJson`、web→host schema 驗證。
- 定義並測試 `hello / ready / snapshot / subscribe / unsubscribe / stateChanged`。
- `--preview --mock-metrics` 可以在一般視窗上演示完整資料流。

**Gate**：host 與 JS 通訊真實可運行，非法訊息被拒絕，web renderer 故障可恢復，沒有額外 HTTP server。

### Phase 5 — Theme Manager / SDK / Examples

**任務**
- `theme.json` schema，`.dmt` ZIP 匯入／驗證／atomic install，主題列舉與切換。
- 實作 `desktop-monitor-sdk.js`、`.d.ts`、`mock-host.js`、最小範例。
- 完成 `minimal`、`dashboard` 主題；可不重啟 host 切換主題。
- 主題 loader 加入超時、HTML 掛掉 fallback、舊版 API 警告。

**Gate**：非 C++ 開發者只靠文件可製作第三方主題；主題切換 100 次無明顯洩漏；惡意 ZIP 測試通過。

### Phase 6 — Smart Sleep / Recovery / Security Hardening

**任務**
- 系統工作階段、螢幕電源、前景全螢幕事件整合。
- WebView2 hide → TrySuspend → Resume → fresh snapshot，失敗時有退化策略。
- 外部導覽／下載／權限／視窗要求拒絕；驗證 message origin、CSP、網路限制的適用範圍。
- Explorer restart、WebView2 process crash、主題損壞、硬體 API 不可用。

**Gate**：復原事件與安全負面案例可重現通過；不能通過的安全條件須列成發行阻擋。

### Phase 7 — Performance / Regression / Compatibility

**任務**
- 量測應用程式與 WebView2 子程序合計資源，提供 PowerShell script 和測試報告。
- 比較 `minimal`／`dashboard`、`Active`／`Locked`／`DisplayOff`、主題切換與長時間執行。
- 實機驗證 Windows 10/11 可用的版本與顯示器配置；未驗證者不要宣稱支援。
- 對持續 CPU/GPU 負載、記憶體成長、反覆 Shell 附掛做根因分析。

**Gate**：不發生持續無界資源成長，所有測試證據與測試環境可追溯；開放已知限制。

### Phase 8 — CI / Packaging / Release Candidate

**任務**
- GitHub Actions Windows runner：配置、編譯、CTest、打包和可追溯 artifact。
- Release ZIP 或安裝程式：包含 EXE、內建主題、SDK、必要 notice；檢查 WebView2 Evergreen 存在，缺少時引導或合法安裝。
- 提供 `--preview`、`--mock-metrics`、`--version`、`--diagnostics` 等除錯功能。
- 撰寫 `README`、`CHANGELOG`、`LICENSE` 選擇說明、第三方授權、一般使用者安裝／卸載、主題開發者教學。
- 自動啟動（選配，預設不強迫）；卸載時說明使用者主題與資料的保留／刪除選項。

**Gate**：在乾淨 Windows 使用者環境中可安裝／啟動／套用內建主題／卸載；交付 Release Candidate 與版本說明。若簽章憑證不存在，標註 unsigned，而非宣稱已簽章。

---

## 11. 測試清單（不可跳過）

### 11.1 單元測試

- CPU delta 計算、第一次採樣、計數溢位、時間非單調情形。
- RAM bytes、百分比單位、`quality` 狀態。
- 網路 counter wrap/reset、介面切換、休眠恢復後第一筆資料。
- ChangeDetector 閾值、相同值不通知、display rounding 不造成閃爍。
- RingBuffer capacity、覆寫次序、空 buffer、最大請求時長限制。
- EventCoalescer 高頻資料時 latest-wins 與 shutdown race。
- PowerStateMachine 各種轉換、防抖、重複通知、無法暫停之退化。
- Theme manifest 缺欄、未知版本、越界路徑、重複 ID、無效版本。
- JSON protocol 正負面案例、大小限制、來源錯誤、權限越界。

### 11.2 整合／契約測試

- WebView2 真正收到 Snapshot，SDK 解碼並更新 DOM；JS 送來非法命令被拒絕。
- 關閉 WebView2 renderer、reload，原生核心不崩潰並能恢復。
- 主題未指定的 metrics 能正確顯示 unavailable，不能崩潰。
- 以獨立示範主題驗證 Theme SDK 可以在不修改核心的情況下運行。
- 主題 ZIP 的 traversal、zip bomb、非法副檔名、超過配額等負面測試。
- 外部 script、iframe、fetch、WebSocket、頁面導覽、下載與彈窗政策。

### 11.3 Windows GUI／硬體手動測試

- 桌面圖示、工作列、Alt+Tab、Win+D、切換虛擬桌面、工作列自動隱藏。
- 更改解析度／縮放比例／DPI、多螢幕拔插（即便首版不支援所有情況，也要安全退化）。
- Explorer 終止／重啟、Windows 鎖定、待機／喚醒、顯示器電源切換。
- 一般視窗／最大化視窗／全螢幕遊戲模式切換。
- 無 NVIDIA 顯卡、缺 NVML、NVML API failure 時仍能運行基本監控。
- 長時間運作的 handle/resource leak、例外復原、退出後無背景殘留。

### 11.4 測試環境原則

- 純演算法、資料契約、Theme SDK 模擬測試可以在其他環境執行。
- WebView2 真正渲染、Explorer 桌布嵌入、電源事件、顯卡讀數必須在實際 Windows 環境驗證；**Docker/Linux 測試不能取代 GUI 驗收**。
- 不具備條件的案例標記 `NOT RUN (reason)`，不能偽造測試結果。

---

## 12. 發行與授權決策

- 核心與 SDK 是否開源尚未指定；**Codex 不得擅自宣稱特定專案授權已獲同意**。可先建立 `LICENSE_DECISION.md`，比較 MIT／Apache-2.0／閉源的義務與專案相容性；在明確確定前，不做公開自動發布。
- 第三方元件應有 SPDX identifier、版本、著作權聲明及再散布確認；檢查 WebView2 SDK、C++ JSON/test library、NVML SDK 等具體用法與授權。
- WebView2 建議 Evergreen，安裝前檢測；不要未經允許重新打包完整瀏覽器。
- GitHub Releases 可先作為發行管道；程式簽章、Microsoft Store、主題商城為後續規劃。
- README 必須說明 WebView2 的多程序成本、Windows Shell 未公開 API 的相容風險與主題安全界線。

---

## 13. 驗收矩陣 / Definition of Done

| ID | Must-have | 驗收證據 |
|---|---|---|
| A01 | 可在 Windows x64 建置／啟動 | 實際 CMake build log 與版本資訊 |
| A02 | `--preview` 顯示 mock 儀表板 | 執行畫面／整合測試 |
| A03 | 真正桌布位於圖示後方且不搶焦點 | Windows 實機測試表 |
| A04 | Explorer 重啟後能恢復或安全 fallback | 復原測試紀錄 |
| A05 | CPU/RAM/Network + GPU optional + Disk 有正確單位與狀態 | 資料測試、實測值驗證 |
| A06 | 定期採樣與事件推送解耦 | MockCollector + renderer mock tests |
| A07 | 合併更新與有界快取 | 佇列與 RingBuffer 單元測試 |
| A08 | Smart Sleep 狀態轉換、恢復全快照 | 狀態機與 WebView2 實測 |
| A09 | 兩個內建 HTML 主題與熱切換 | 主題切換整合測試 |
| A10 | 對外 Theme SDK、TypeScript 宣告、Mock Host、文件 | 第三方示範主題可獨立運作 |
| A11 | `.dmt` 匯入、防路徑穿越與配額限制 | 安全負面測試 |
| A12 | WebView2 navigation/message 最小權限與來源驗證 | Security regression tests |
| A13 | 10–30 分鐘以上可重現效能測量，包含 WebView2 子程序 | CSV / report / 環境資訊 |
| A14 | CI、測試、封裝腳本，乾淨 Windows 安裝驗證 | Workflow log、ZIP/installer |
| A15 | README、使用者手冊、Theme SDK、已知限制、授權清單 | Docs review |
| A16 | 未測試與無法完成項目全部具體列出 | `docs/FINAL_HANDOFF.md` |

> **發行判定**：A01、A02、A05–A12、A14–A16 是軟體開發交付基礎；A03/A04 若在特定 OS 版本未達成，必須清楚列為不支援、提供 preview fallback，並在 release notes 中說明，不能對所有 Windows 版本宣稱完全支援。

---

## 14. Codex 每次工作循環的固定輸出

每個階段完成後在 `docs/STATUS.md` 更新以下表格（不可只以口頭描述）：

```markdown
## Phase N — <title>
- Date / commit:
- Scope completed:
- Files changed:
- Unit tests: PASS / FAIL / NOT RUN（附命令與摘要）
- Integration tests: PASS / FAIL / NOT RUN（附環境）
- GUI / hardware tests: PASS / FAIL / NOT RUN（附 Windows build）
- Security / performance evidence:
- Known issues / blockers:
- ADR / changed assumptions:
- Next step:
```

最終 `docs/FINAL_HANDOFF.md` 必須包含：

1. 已完成功能與未完成需求，逐項對應 A01–A16。
2. 實際可重現的 `cmake`、`ctest`、`scripts/package.ps1` 操作指令。
3. 如何在 Windows 乾淨環境安裝、執行、匯入主題、切換主題。
4. 如何用 SDK 與 mock host 開發第三方主題（不需 C++）。
5. Git commit 清單／關鍵 ADR／依賴授權與版本。
6. 對不同 Windows build 的支援證據及限制。
7. CPU／RAM／GPU 測試方法與報告位置，是否包含 WebView2 子程序。
8. 已知安全限制，尤其 WebView2 網路存取、外部主題信任模型。
9. 未測試項目，不得以推測當成測試通過。

---

## 15. Windows 上建議的 Codex CLI 啟動方式

在 PowerShell 專案根目錄：

```powershell
# 先建立／進入工作目錄（可替換為既有 Git repository）
mkdir DesktopMonitor -ErrorAction SilentlyContinue
cd DesktopMonitor

# 將 DesktopMonitor_Codex_Handoff.md 複製進此資料夾後
# 在互動式 Codex CLI 中貼上下面這段啟動任務：
codex
```

**貼入 Codex CLI 的啟動任務文字：**

```text
請閱讀專案根目錄的 DesktopMonitor_Codex_Handoff.md，並執行第 0 節全部交接指令。
先檢查 repo、AGENTS.md、既有 TDD skills 與 Windows/MSVC/CMake/WebView2 環境，
再依 Phase 0→8 以小步 TDD + 驗證 + commit 完成可發布的 Windows 系統監控桌布平台。
優先驗證 DesktopHost 可行性，其次建立 Metrics Core、WebView2 Bridge 與 Theme SDK。
不要只是產生計畫或偽代碼；要實際建立程式、編譯、測試、修復、撰寫文件和封裝。
每個階段更新 docs/STATUS.md，所有未執行測試要標為 NOT RUN，
遇到無法自動處理的環境阻礙，留下明確重現步驟並繼續其餘可進行的工作。
最終輸出 docs/FINAL_HANDOFF.md 與 release candidate，並回報驗收矩陣 A01–A16 的實際結果。
```

**建議建置／測試介面**（Codex 應實作對應 CMake Presets 與 PowerShell scripts，實際 preset 名稱以其建立後文件為準）：

```powershell
cmake --preset windows-msvc-debug
cmake --build --preset windows-msvc-debug
ctest --preset windows-msvc-debug --output-on-failure

cmake --preset windows-msvc-release
cmake --build --preset windows-msvc-release
powershell -ExecutionPolicy Bypass -File scripts/package.ps1
```

> 如果 Codex CLI 由非 Windows 環境啟動，請先交付不依賴 Windows GUI 的 core、contracts 與 theme SDK 工作；GUI 真實驗證仍必須在 Windows 補做。不要使用 Linux/Docker 的成功編譯來宣稱 Windows 動態桌布已通過驗收。

---

## 16. 核對用的官方文件與技術參考

以下為 Codex 實作時應再次查閱的權威來源。對於 Windows Shell 的未公開方法，應以程式碼 POC 和相容矩陣實測為準，勿把社群技巧當作微軟的支援承諾。

- Microsoft — WebView2 Win32 C++ Quick Start: https://learn.microsoft.com/en-us/microsoft-edge/webview2/get-started/win32
- Microsoft — WebView2 security best practices: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/security
- Microsoft — WebView2 local content and virtual host mapping: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/working-with-local-content
- Microsoft — WebView2 process model: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/process-model
- Microsoft — WebView2 Runtime distribution: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution
- Microsoft — WebView2 performance best practices: https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/performance
- Microsoft — WebView2 Win32 `ICoreWebView2_3` (TrySuspend / mapping): https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2_3
- NVIDIA — NVML API Reference: https://docs.nvidia.com/deploy/nvml-api/nvml-api-reference.html
- Microsoft — Win32 API documentation: https://learn.microsoft.com/en-us/windows/win32/api/

---

## 17. 目前已確定的設計決策與待證明假設

### 確定

- 核心：C++20 + Win32。
- HTML 主題：WebView2 + 標準 JavaScript SDK。
- 第三方主題可完全自訂 UI 並分享；不是單一內建 dashboard。
- 資料採集與渲染解耦；ChangeDetector、bounded cache、smart sleep 均列為必做。
- 預設本機執行；基本監控不需網路、不需管理員權限。
- 首版不加 Qt／Electron／Node server；不以 C++ 原生 DLL 作為第三方主題外掛。

### 尚須 POC／決策紀錄

- 各版 Windows 10/11 Explorer 視窗階層與桌布附掛的可靠方式。
- 單／多顯示器的第一版明確支援矩陣。
- WebView2 windowed controller 是否完全滿足桌面 host；若不符合，評估 composition controller 及其成本（先 POC 再定案）。
- GPU 非 NVIDIA 硬體的最低支援層級與可再散布 SDK。
- 各種 network request interception 是否足以支撐第三方主題的「離線預設安全」主張。
- 發行採用 MIT／Apache-2.0／其他授權；公開發行前確認。
- 性能數值目標需在實際電腦建立 baseline 後訂定，不可憑空保證。

---

**Handoff 結束。Codex 的第一個動作應是閱讀本文件，完成 Phase 0 audit，接著立即進入 Phase 1 桌布宿主 POC。**
