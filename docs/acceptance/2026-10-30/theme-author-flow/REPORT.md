# RC 07：第三方主題作者流程

日期：2026-10-30。Branch `feature/rc-07-theme-author-flow`，base `1636972a570431a0feaa9070978b2503441aa3b9`；前置 06 resolved。SDK／文件／測試與作者工具為 base 加本票工作樹，隨本票唯一提交保存，最終 commit 以 Git 為準。產品 C++ 未修改；沿用 EXE SHA-256 `25316B5067076749295B62DB557748B6DC2D88C4069CFBBE4C48E93269F6D26D`（來源 c244682 產品，後續 06 僅驗證工具）。

本票可執行範圍完成，Status implemented；**A10 仍 PARTIAL，SDK ZIP 不是 app 08 交付／09 RC**。GUI 匯入／確認及像素版面等 NOT RUN 見 [人工清單](MANUAL_CHECKLIST.md)。03 歷史 FAIL、04 安全限制及 RC gate 均保留。

## 變更與測試接縫

- 公開 SDK／protocol：補 MockHost 宣告，將 `HostReady.limits` 與 MockHost 對齊既有原生 `{ history, messageBytes }`；未改原生政策、權限或協定版本。這是本票明定的 SDK 缺陷修正，不是改動已確認決策。
- 新增可從 SDK ZIP 複製的 TypeScript 作者範本（`sdk/author-starter`），固定 compiler 5.9.3、lockfile／integrity；src 宣告、compiler 與 dist 離線靜態檔分離。SDK ZIP 明確選取來源，避免 node_modules／dist／本機產生宣告流入 ZIP。一般使用者 app 不需要作者工具，app 底下已觀察到的子程序皆 WebView2，Node 是測試啟動器／接收端。
- 套件／ThemeManager：補 `.ts`／`.d.ts` 禁止案例與移除後同版重匯入公開契約。沒有放寬任何副檔名、來源或網路規則。
- Windows 整合沿用正式 CLI、原生管理命令與隔離 LOCALAPPDATA，HTML 只能使用版本化 bridge。沒有產品測試開關或原生管理旁路加入 SDK。
- 更新阻擋作者的文件：移除「原生 ThemeManager 未實作」的舊說明，補 compiler／建置／封裝／版本更新與安全限制。

## TDD 與相關檢查

1. **MockHost 宣告 Red→Green**：`compiler-red.log` 中 strict compiler TS7016（缺少 MockHost 宣告）；補 `mock-host.d.ts` 後 `compiler-green.log` 通過。初次手動 compiler 命令誤指定未安裝的 Node 型別（TS2688），移除該不需要的參數後才取得真正 TS7016，不以參數錯誤當產品 Red。
2. **limits Red→Green**：依原生 SendReady 現況新增 `host.limits.history/messageBytes` 的正確作者用法，compiler 得兩個 TS2339（`limits-compiler-red.log`）；修正 `.d.ts` 後通過（`limits-compiler-green.log`）。MockHost 公開 ready 契約測試先失敗（`mock-limits-red.log`），對齊原生欄位後 SDK 18/18 PASS（`sdk-green.log`）。舊 MockHost 的 maxHistory/minUpdateIntervalMs 不再模擬不存在的原生欄位。
3. **compiler 正負案例 PASS**：最終乾淨作者實際執行 `npm ci`、configure、check、build。valid fixture 的 SDK／MockHost／事件／快照／歷史／別名用法成功；invalid fixture 僅得到預期 TS2322、TS2769、TS2322、TS2345（間隔型別、錯誤事件、單位、狀態），不是缺檔／語法失敗。詳見 `clean-{npm,configure,compiler,build}.log`。compiler 診斷保留上游英文原文，工具的使用者提示為繁中。
4. **原生 PASS**：相關 targets 建置；protocol 七項＋ThemeManager 入口共 CTest 8/8（`ctest.log`）。增加 `.ts`／`.d.ts` 案例後 ThemeManager 1/1 再驗 PASS（`native-theme-final.log`），涵蓋移除→同版重裝、manifest API 不相容、路徑／CRC／配額等既有保護；這些既有邊界本來正確，不虛構 Red。Windows 螢幕列舉 1/1（`monitors.log`）。原生測試的 TEMP／TMP 指向非 Temp 使用者測試目錄，透過 CTest 啟動測試 EXE。
5. **作者封裝 PASS**：正式 PowerShell validator 接受合法包，拒絕 traversal、大小寫重複、EXE、TS、宣告、API v2、超額檔案；例題 SDK 相對匯入改寫通過（`package-negative-final.log`）。沒有使用開發來源樹的 packager 來替代包內工具。
6. **SDK ZIP PASS**：兩次正式 author.1 產出 SHA 相同；新建乾淨作者由最終 ZIP 複製與編譯後打包，DMT hash 與先前實機受測 sample 相同。另以相關 `test-sdk-package.ps1` 執行 required-files、禁止本機產物、解壓後 SDK 18/18、兩個範例 validator、重封一致性檢查，見 `sdk-zip-final-test.log`。ZIP 測試解壓在使用者非 Temp 目錄，不含 app EXE。
7. PS parser 四檔、Node syntax 四檔與 `git diff --check` PASS；詳見 STATUS 命令與 REVIEW。**完整測試套件、CI NOT RUN**，依使用者指示留 09；沒有改 C++ 產品故無 app 重新編譯／app 重新打包。

## 乾淨作者來源與產物

根目錄：`C:\Users\James\DrillPaperTests\RC07 作者流程`。最終 SDK 解壓至 `SDK-final`，完整複製 `sdk/author-starter` 至 `最終獨立作者` 後執行下列命令，僅讀 ZIP 內容與 npm 固定 compiler，不依賴 repo 的 SDK／來源。`sources.json` 保存宣告、作者 TS 與 dist 每檔 hash，`author-package-files.json` 列出 DMT 六個靜態資產；不含 TS、宣告或 Node。

```powershell
npm ci --ignore-scripts --no-audit --no-fund
npm run configure -- 'C:\Users\James\DrillPaperTests\RC07 作者流程\SDK-final\sdk\javascript'
npm run check
npm run build
& '..\SDK-final\scripts\package-theme.ps1' -ThemeDirectory .\dist -OutputFile ..\author-final.dmt
```

SDK author.1 ZIP：64,412 bytes，SHA-256 `376906271C8FBF0E3EDAFC9E8662E4C32524AA7974685AD7ED05DE6FF623A0C8`。SDK runtime 版本仍 `1.0.0-rc3`、API `1`，author.1 是獨立驗證包標籤。作者 DMT：7,162 bytes，SHA-256 `82BF38D3743A3F6ADCBFCC31D754B5E776D3A3B815DFB7F49A47F83C7CEE8546`；重建 `author-final.dmt` 相同。所有初版／最終探針 DMT hash 見 `hashes.json`。ZIP／DMT 留上述本機目錄，不作公開發行。

## Windows 實機範圍

Windows 11 Pro 25H2 26200.8737、Runtime 156.0.4314.50、WebView2 SDK 1.0.2478.35、Node 24.17.0／npm 11.12.1、Intel Core Ultra 7 155U／Intel Graphics，雙目標 1920×1080，DPI 144／96。本輪查詢見 `environment.json` 與 `monitors.log`，不沿用前票畫面 PASS。中等權限、非乾淨獨占主機，不量測效能或硬體精度。

EXE／Loader／內建 resources 複製至 `binary`，沒有放入開發來源樹；每輪正式 CLI 匯入／同版拒絕後，以 Node 直接啟動 `--management --preview --no-smart-sleep`，mock 輪另帶 `--mock-metrics`。多目標由可信原生管理介面選取兩個目標並保存 desktop。網路 on 輪由可信設定開啟；off 輪保持關閉。這個除錯旗標只為隔離前景覆蓋，不更動產品預設或聲稱省電驗收。

| 情境 | 結果與可觀察範圍 |
| --- | --- |
| sample-mock2 | PASS：作者原始編譯 DMT，Preview mock，正式匯入／同版拒絕、作者→Minimal→作者、持續原生推送與正常退出。未加入探針。 |
| probe-mock-off | PASS：原樣 main.js 加獨立驗收入口，API v1／limits、DOM 時間更新、單位、GPU unavailable、API v2／三種管理命令拒絕、HTTP off。 |
| probe-live-on3 | PASS：實際 metrics，等待 warm-up 後驗同一組 DOM／協定與 HTTP on；較早探針，未加後述連續訂閱 DOM 報告。 |
| probe-multi-on | PASS：雙目標同主題，兩個獨立來源、viewport／DPR／主內容寬度與實際 metrics。較早探針，範圍同前列。 |
| probe-multi-off | PASS：雙目標 live、HTTP off 零收件、非法 API／管理命令拒絕、兩輪作者載入與推送。 |
| probe-multi-on4 | PASS：雙目標兩次作者載入共四份接收端報告；每份先確認兩個不同 timestamp 的 `metrics.changed` 真正更新 DOM，再回報 `pushUpdatedDom=true`。 |
| probe-preview-on4 | PASS：Preview live 的兩次作者載入共兩份相同強度的訂閱 DOM 報告。 |

最終六份正向報告的 viewport：Preview 492×263／DPR1.5；桌布每次兩份為 1280×720／DPR1.5、1920×1080／DPR1。原生 parent 非零、保存兩目標、各自完成訂閱；不由此宣稱桌面圖示／焦點或像素完整。`integration-summary.json` 依原生啟動／退出時間界定每輪報告，保存完整 host.ready 及 CPU／RAM／網路／GPU 文字。`requests.jsonl` 是原始接收紀錄，整段沒有 mode=off 請求；on 有對應收件，另有測試端 `/control` 正向確認。只驗指定 loopback HTTP，不能外推完整 DNS／背景流量或沙箱。

`tests/fixtures/theme-author-probe.js` 保留編譯 main.js，暫攔訂閱，先在頁面確認主題行為、API v2 錯誤及 `settings.apply/theme.remove/app.exit` 全得到 unsupported-message、HTTP 偏好，再放行原生訂閱；因此先前斷言失敗不會取得作者 ReadyEpoch，Minimal fallback 也不能冒充作者名稱。on4 的後續連續推送以接收端報告另證；單靠 ReadyEpoch 或 MetricsTick 不代表 DOM／像素存活。保存設定 hash 在主題往返與惡意命令後不變。

所有情境的 `.started/.identity/.exit.json`、結果、CLI 拒絕日誌與當下可觀察 WebView2 子程序精確 path／建立時間／handle 退出結果分目錄保存。七個成功情境正式退出碼均 0；不宣稱取得所有短命子程序。

版本化 `.log` 僅正規化行尾空白、EOF 與 UTF-8；未改診斷內容或測試結果。原始副本在 `artifacts/rc07-rawlogs`，原始／正規化 SHA 見 `log-normalization.json`。JSON／JSONL 是直接保存的原始結構資料，不做相同正規化。

兩軸審查見 [REVIEW](REVIEW.md)：Standards 初審兩項工具錯誤處理／退出問題已修正，複查未解決0；Spec 0。修正後額外正常整合 `cleanup-review` PASS。受控模擬清理時 CIM 查詢不可用，工具 `cleanup-observation-fault` 正確 exit1／CLEANUP_FAILED、app正式exit0、真實CIM收尾無殘留；觀測不足不冒充PASS。缺 USERPROFILE 時友善 fail-fast 與 SDK ZIP 相關重驗也通過。

## 保留的失敗與限制

- `sample-mock`：協調工具錯把「此主題版本已安裝」診斷找成「已存在」，尚未啟動 GUI 即停止；修正工具後 sample-mock2 PASS，非產品 FAIL。
- `probe-live-on`／`probe-live-on2`：初版探針只等 1.4 秒便要求 CPU 可用，第一個 collector warm-up 仍 unavailable，未放行訂閱而逾時；on2 接收端保留 CPU 斷言錯誤。修成最多十次一秒查詢等待有效差分資料後 on3 PASS，沒有改採集器、不把 unavailable 寫成 0。這是測試時序限制，不能由此聲稱產品啟動缺陷已修復或解除 03 FAIL。
- 初次獨立 npm 調用誤在作者的父目錄執行，得到 EUSAGE／ENOENT；回到複製出的作者目錄後才執行最終 clean 流程。這不是作者文件命令失敗；最終命令工作目錄明列於上。
- GUI 匯入／移除確認、視覺、獨立瀏覽器 MockHost、乾淨一般帳號／沒有 Node 的另一台機器、其他 OS／Runtime／NVIDIA／真實 OS 事件及完整安全邊界 NOT RUN，詳見人工清單；不因此中斷可自動範圍。
- 防毒：Trend Micro Apex One 14.0.0.21008，可讀 AEGIS_BM.log 前後 fingerprint 紀錄見 before／after。未觀察新增攔截；不是完整防毒觀測。若後續攔截則記產品／規則／時間與受影響項 BLOCKED，不改設定。本輪已知工具失敗不能任意歸因防毒。
- 原持續桌布只讀核對 path／精確建立時間／hash，不關閉／替換、不重啟 Explorer；收尾與防毒 fingerprint 見 `after.json`。03／04／05／06 既有 NOT RUN 與限制繼續交給 08／09。
- 收尾一開始因 PowerShell 自動把 JSON 日期轉成 DateTime，字串比較誤判不同；以 `ConvertFrom-Json -DateKind String` 保存原始 ISO 字串並用 DateTimeOffset.UtcTicks 重核，兩端皆 `2026-10-29T04:00:49.9803524Z`、path／hash相同，唯一app仍為原桌布。已確認身分的本票 Node 接收端正常由測試方終止（`server-cleanup.json`），沒有操作其他程序。

## 可重現的整合命令

```powershell
pwsh -NoProfile -File scripts/test-theme-author-flow.ps1 -ApplicationPath '<非 Temp 使用者目錄>/binary/DrillPaper.exe' -PackagePath '<同目錄>/author-final.dmt' -EvidenceDirectory '<尚不存在的目錄>' -MockMetrics
pwsh -NoProfile -File scripts/test-theme-author-flow.ps1 -ApplicationPath '<同 EXE>' -PackagePath '<probe-on4.dmt>' -EvidenceDirectory '<新的目錄>' -Desktop -AllowNetwork
```

重建 probe：複製作者 dist，將 HTML 的 main.js 入口改為 probe.js（main.js 本身保持不變），複製 repository 的 `theme-author-probe.js`，另建 `probe.json` 為 `{ "allowNetwork": true/false, "url": "http://127.0.0.1:<port>/author?mode=on/off" }`。啟動 `node tests/fixtures/security-server.mjs <使用者測試目錄>` 取得 server.json 的 port，再用**解壓 SDK 內** package-theme／validator 打包；同版不可覆寫，應使用全新 EvidenceDirectory。off 接收端不得有請求；on 每次每目標應有一份 `pushUpdatedDom=true` 報告，並對照 native phase 的兩次作者載入。報告目前由接收端與人工／資料分析交叉核對，runner 的 PASS 僅表示其明列的原生步驟通過，不代替 HTTP 報告檢查。驗收 fixture／Node 接收端不隨 app 或 SDK 散布。
