# 原生主題平台續作與驗收

日期：2026-10-28，Windows 11 Pro 25H2 26200.8737。依既有 Handoff 及使用者持續完成剩餘項目的授權，補原生主題管理；全產品仍未達發行條件。

## 實作

- `.dmt` 使用鎖定 SHA-256 的 miniz 3.0.2，在 50 MiB 壓縮上限內讀取，先驗證全部項目的路徑、數量、解壓長度及外部屬性。使用有界緩衝區解壓、CRC 驗證與寫入完成檢查；驗證 manifest／資產後原子 rename 安裝。單檔 10 MiB、總解壓 50 MiB、256 個檔案、512 個 ZIP 項目、manifest 256 KiB。
- CLI `--import-theme <資料夾或.dmt>`、`--list-themes`。必須有 LOCALAPPDATA，不回退到其他目錄；相同 ID／版本禁止覆蓋；安裝目錄及祖先拒絕 reparse point。錯誤輸出為友善繁體中文並回非零，合法資料目錄下另有錯誤日誌。
- Win32「主題」功能表提供內建、已安裝主題及重新整理；使用既有 WebView2 controller 熱切換。每次載入建立新 GUID origin，解除舊 mapping 並重設握手；20 秒握手逾時後只嘗試回復 Minimal 一次。沒有圖形化匯入、移除或持久化目前選擇。
- 新增 miniz／nlohmann JSON 完整授權文字，隨建置放到 resources/licenses。

## Red／Green 與整合證據

1. `.dmt` 正常安裝測試先 FAIL，再實作通過；包含中文套件／安裝路徑。
2. CLI 舊版不識別命令、15 秒未退出，先 FAIL；實作後匯入、列舉、含空白路徑、同版本拒絕、缺少設定／參數通過。
3. Junction CLI 先重現錯誤日誌沿 reparse 路徑向外寫入，FAIL；改為在資料目錄初始化時檢查祖先，尚未設定日誌目錄前即拒絕。修正後 junction 情境拒絕且外部測試目錄保持空白，PASS。
4. 原生熱切換先重現仍停在 Minimal，FAIL；加功能表及 adapter LoadTheme 後通過。
5. 已安裝主題先重現無法選擇，FAIL；接上安裝清單後，`.dmt` 匯入→原生列舉→同一 app 載入→SDK 訂閱完成，PASS。
6. Windows PowerShell 5.1 的短命程序 ExitCode 取得失敗，修正測試 helper 先保留 Process.Handle 後，CTest CLI 通過。測試腳本使用 UTF-8 BOM 以支援 Windows PowerShell。

命令：

```powershell
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperThemeTests --parallel 8
.\build\windows-msvc-release\Release\DrillPaperThemeTests.exe '[themes]'
ctest --preset windows-msvc-release -R '^DrillPaperThemeCli$' --output-on-failure
.\scripts\test-theme-switch.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Cycles 100 -IncludeInstalled
.\scripts\test-theme-switch.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Cycles 2 -IncludeInstalled -BrokenInstalled
```

- 原生主題：8 個案例、71 項斷言 PASS。ZIP 負面情境含 traversal、絕對路徑、ADS、大小寫碰撞、非法資產、單檔／總量／檔案數配額、symlink 屬性、截斷、CRC 錯誤、API 不相容。拒絕後未留下已安裝內容、外部 escape.js 或暫存目錄。
- 原生 CLI：CTest PASS；包含真實 Windows junction 拒絕，非 mock 檔案系統。
- 同一 app 完成 100 次內建切換，接著載入已安裝套件，PASS_PROTOCOL，退出碼 0。證據：[switch-100/summary.json](switch-100/summary.json)。此為協定／程序整合，不是每次畫面截圖。
- 損壞主題已觀察到載入中狀態，再於逾時後回復 Minimal、重新訂閱，PASS_PROTOCOL，退出碼 0。證據：[broken-fallback/summary.json](broken-fallback/summary.json)。

## 切換資源限制

100 次後程序樹 Private Bytes 197.24→330.62 MiB，7 個程序不變，根 app handles 234→234。不能僅因功能通過便宣稱無洩漏。

因此再以同一 app 測 300 次並閒置約 60 秒：[switch-300/summary.json](switch-300/summary.json) 及各階段 CSV。

| 階段 | Private MiB | 程序數 |
| --- | ---: | ---: |
| 初始 | 195.99 | 7 |
| 100 次 | 333.68 | 7 |
| 200 次 | 404.32 | 7 |
| 300 次 | 366.77 | 7 |
| 閒置後 | 330.71 | 7 |

300 次根 app handles 234→257；通訊通過且正常退出。記憶體有回落，仍不能排除長時間成長或其他資源累積。A09／A13 的洩漏條件保留 PARTIAL；需更長測量及原因分析，未將 300 次短時測試寫成完整效能 PASS。

## 邊界與尚未執行

- 套件讀取／安裝測試不是 WebView2 沙箱證明；外連流量、CSP、WebSocket、permission、download、惡意訊息負面整合仍未完成。只安裝信任的主題，發行閘門保留。
- reparse 檢查為檢查當下的既存路徑；沒有宣稱隔離同使用者同時修改檔案的攻擊者。
- 背景 sampling worker／電源生命週期正在下一階段實作；其起始失敗測試不屬本階段已通過的範圍。
- 實際 Shell 桌布、Explorer 復原、Windows 鎖定／電源、乾淨安裝、CI、30 分鐘資源矩陣仍 NOT RUN。
