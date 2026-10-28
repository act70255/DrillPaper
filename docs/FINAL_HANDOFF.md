# DrillPaper 最終交接

> Runtime 最新續作：背景採樣、世代化 latest-wins mailbox、WTS／顯示器通知與 WebView2 暫停／恢復已接入。完整回歸 27/27、SDK 18/18；受控事件與快速競態回歸通過，使用者回報真實鎖定／解鎖 5 次恢復正常。GPU 實機 unavailable 契約已由非 mock SDK 探針確認。證據與版本範圍見 [runtime/REPORT.md](acceptance/2026-10-28/runtime/REPORT.md)，不得沿用下文舊版「UI timer 採集／未整合」狀態。

> 最新主題平台續作：原生 `.dmt`／資料夾 CLI 匯入、已安裝主題列舉與熱切換、逾時回復已接入 app 並有整合測試。100／300 次切換協定通過，但記憶體與 handles 的成長仍需長時間分析。請以 [theme-platform/REPORT.md](acceptance/2026-10-28/theme-platform/REPORT.md) 及 STATUS 的最新階段為準；下列舊版「尚無原生匯入器」為歷史狀態。

> 2026-10-28 13:05 更新：最新 Windows 11 驗收請以 [acceptance/2026-10-28/REPORT.md](acceptance/2026-10-28/REPORT.md) 為準。Release build、CTest 22/22 與 SDK 18/18 已實測通過；GUI 工具通訊不可用，畫面等待人工檢查。下文 Windows 10、舊 Git 限制與 SDK hash 為先前環境的歷史紀錄，不能套用到目前工作樹。原生主題管理已增目錄安裝雛型，尚未接入 app；整體仍不可發行。

**交付狀態：開發原型已能在目前 Windows 10 x64 環境編譯、啟動並完成 WebView2 protocol smoke；整體工作尚未完成，DrillPaper app Release Candidate 未產生、不可安裝或發布。** Theme SDK `1.0.0-rc3` ZIP 已實際封裝、解壓、測試及驗證，可供本機評估。此文件只把實測範圍標為通過；未做 GUI、安全、長時間效能與乾淨安裝的項目保持未驗收。

專案名稱依使用者決定為 **DrillPaper**。執行檔為 `DrillPaper.exe`；SDK 主要入口為 `DrillPaper`/`DrillPaperClient`，並保留 DesktopMonitor 相容別名。原始規格名稱、C++ namespace/include 路徑及部分檔名仍沿用 DesktopMonitor。

## 1. 驗收矩陣 A01–A16

| ID | 結果 | 證據與未完成項目 |
| --- | --- | --- |
| A01 | **PASS（本機開發環境）** | MSVC x64 Release 經 CMake 實際編譯；`DrillPaper.exe --version` 與 `--diagnostics` 實際執行。尚未驗證乾淨使用者安裝或其他 Windows builds。 |
| A02 | **PARTIAL** | WebView2 實際載入 `minimal`（live collector）與 `dashboard`（mock metrics）；兩者完成 SDK hello、snapshot request、subscribe smoke。沒有截圖/人工視覺檢查，DOM 排版與 dashboard 視覺呈現仍未驗收。 |
| A03 | **NOT RUN** | `--experimental-desktop` 有 opt-in Shell 程式碼，但未驗證圖示、工作列、Alt+Tab、焦點、z-order 或桌布位置；桌布附掛不宣稱支援。 |
| A04 | **NOT RUN** | 沒有實際重啟 Explorer、重建宿主或確認安全 fallback 的 GUI 結果。 |
| A05 | **PARTIAL** | CTest 的 Windows collectors integration test 實際讀取 API，驗證 typed readings 與 CPU/network warm-up；演算法/單位測試通過。沒有核對 CPU/RAM/Network/Disk 的量測精度，也未用產品 NVML adapter 驗證 NVIDIA GPU。 |
| A06 | **PARTIAL** | 實作與測試有界 history、latest-wins、排程策略；app 目前在 UI timer 同步採集，沒有背景 worker 到 renderer 的解耦整合或 shutdown/race 測試。 |
| A07 | **PASS（核心有界政策）** | CTest 覆蓋最多 120 筆 history、latest-wins coalescing 與 change detection。SRW mailbox/thread stress 不在本次驗收範圍。 |
| A08 | **PARTIAL** | CTest 驗證 state machine、debounce、sampling schedule/resume policy；沒有 Windows session/display/power event 或 WebView2 hide/TrySuspend/resume/fresh snapshot 整合測試。 |
| A09 | **PARTIAL** | minimal/dashboard 兩個內建來源均由真實 WebView2 host 啟動並完成 protocol smoke；切換要重啟程式，不支援執行期 hot switch。沒有視覺檢查或 100 次切換測試。 |
| A10 | **PARTIAL** | JS SDK、`.d.ts`、MockHost、文件、範例、18 個 Node 測試與可重現 SDK ZIP 已完成；尚未實測 TypeScript compiler 與第三方獨立瀏覽器作者流程。SDK ZIP：49,107 bytes，SHA-256 `68E0B5F41FB2337B396A5335CA1707B0F6F5E275F3771EF913E1DF8210D01656`。 |
| A11 | **PARTIAL** | `.dmt` 開發 validator 通過有效包並拒絕 traversal、重複大小寫路徑、不允許副檔名、錯誤 API 版本與超大檔案；無 native import、staging/atomic install、quota extraction 或 rollback。 |
| A12 | **PARTIAL** | 原生 parser 測試 schema/版本/大小等限制；WebView2 host 原始碼有本機 virtual-host mapping、拒絕非本機 navigation/resource 和新視窗。未執行外連流量及惡意 message、redirect、download、permission 等 WebView2 security regressions。沒有首次提示/全域網路開關；第三方主題未沙箱化。 |
| A13 | **NOT RUN** | 僅有短時間程序樹 smoke（看見 DrillPaper 與 WebView2 child）；沒有 app 的 10–30 分鐘 CSV/report，也沒有 minimal/dashboard、locked/display-off 對比。 |
| A14 | **PARTIAL** | Windows GitHub Actions workflow、build/test/package scripts 存在。Release build/test 實際通過；package gate 因缺少 `src/themes/theme_manager.cpp` 而停止，未產生 app ZIP；CI、乾淨安裝與卸載未跑。 |
| A15 | **PARTIAL** | README、SDK/Protocol/安全/metrics/runtime/performance/使用者文件、授權與限制已記錄；沒有可用的 app 安裝、主題匯入/切換/移除流程說明，因產品功能尚未實作。 |
| A16 | **PASS（交接文件）** | 本文件與 `docs/STATUS.md` 逐項列出實際證據、未測項目、命令、環境與 blockers；沒有將未執行的驗收列為 PASS。 |

## 2. 環境、建置與測試證據

實測環境為 Windows 10 Pro x64 build 19045、Visual Studio Enterprise 2022 17.11.2 / MSVC 19.41.34120、CMake 4.3.5、Windows SDK 10.0.26100.0、Node.js 22.14.0、WebView2 SDK 1.0.2478.35 與 Evergreen Runtime 155.0.4283.62。CMake、SDK headers/libraries 與缺少的 MSVC CRT headers 安裝在忽略的 `.toolchain/` 工作區路徑；沒有修改全域 PATH 或 ACL。

這台機器原本缺 CMake 和 Windows SDK。之後以 repository 本機工具鏈完成 x64 Release build。可重跑：

```powershell
.\scripts\build.ps1 -Configuration Release -LocalToolchain
ctest --test-dir build/local-msvc-release --output-on-failure
.\scripts\test.ps1 -Configuration Release -LocalToolchain
```

最後一次完整測試命令成功：C++ CTest **21/21**、Node SDK/manifest **18/18**、環境檢查 CIM-denial regression、`.dmt` 正負案例、SDK ZIP 解壓後測試、minimal/dashboard package 驗證與可重現 SHA-256。CTest 包含 Windows metrics collector integration test。

WebView2 程序層整合 smoke：

```powershell
.\scripts\test-webview2-smoke.ps1 `
  -ApplicationPath .\build\local-msvc-release\DrillPaper.exe `
  -Theme minimal

.\scripts\test-webview2-smoke.ps1 `
  -ApplicationPath .\build\local-msvc-release\DrillPaper.exe `
  -Theme dashboard -MockMetrics
```

兩項都觀察到視窗標題 `DrillPaper Preview — <theme> — Live metrics`。Host 只在 hello、snapshot request/response 與 subscribe 進入有效流程後更新此標題。這驗證了程序與 protocol 路徑，**不是螢幕截圖、視覺檢查、桌布或安全驗收**。Computer Use 工具對直接可視操作 DrillPaper 回覆 `Computer Use was not approved to use drillpaper`；因此本次沒有畫面證據，沒有把這項工具限制改寫為視覺通過。

CLI 檢查：

```powershell
.\build\local-msvc-release\DrillPaper.exe --version
.\build\local-msvc-release\DrillPaper.exe --diagnostics
```

在附掛 console 執行時分別輸出 `DrillPaper 0.1.0-dev` 與 `x64 / WebView2 Runtime: 155.0.4283.62`。

### App RC 閘門

實際執行：

```powershell
.\scripts\package.ps1 -Configuration Release -Version 0.1.0-rc1 -LocalToolchain
```

命令重新建置並重跑所有測試後，明確以 `Release feature is not implemented: src/themes/theme_manager.cpp` 結束（exit code 1）。因此沒有 `DrillPaper-0.1.0-rc1-win-x64-unsigned.zip`，也沒有安裝器、簽章或 app RC。不要手動改名 EXE/SDK ZIP 當作 app RC。修復並測試 Theme Manager 與其他發行條件後，再重跑此 gate。

### Theme `.dmt` 與 SDK ZIP

可在 PowerShell 執行：

```powershell
.\scripts\test-theme-package.ps1
.\scripts\test-sdk-package.ps1
.\scripts\package-sdk.ps1 -Version 1.0.0-rc3 `
  -OutputFile artifacts/DrillPaper-Theme-SDK-1.0.0-rc3.zip
```

`artifacts/DrillPaper-Theme-SDK-1.0.0-rc3.zip` 已由測試產生、解壓、重跑 18 個 Node tests 和驗證兩個 `.dmt`。大小 **49,107 bytes**，SHA-256 **`68E0B5F41FB2337B396A5335CA1707B0F6F5E275F3771EF913E1DF8210D01656`**。它含 Apache-2.0 LICENSE，是本機 SDK 評估包，並非 app RC。

## 3. Preview 使用與乾淨 Windows 安裝

目前沒有安裝程式或乾淨使用者驗收，所以不能提供已驗收的安裝、匯入、切換、解除安裝步驟。在本機已建置目錄可啟動開發 Preview：

```powershell
.\build\local-msvc-release\DrillPaper.exe --preview --mock-metrics --theme=dashboard
.\build\local-msvc-release\DrillPaper.exe --preview --theme=minimal
```

第一個命令會使用 deterministic mock metrics；第二個走本機 Windows collectors。關閉視窗即可正常退出。此為開發執行方式，不代表桌面附掛支援或安裝體驗完成。其他電腦須有 WebView2 Evergreen Runtime；產品套件尚未建立，也沒有替使用者安裝 Runtime 的流程。

原生 host 目前只按啟動參數選擇內建 `minimal`/`dashboard` theme。PowerShell `.dmt` 工具能封裝與驗證檔案，不能把 `.dmt` 匯入正在運行的 app。

## 4. Theme SDK 作者流程

第三方作者可在 Node.js 22 開發環境從 repository 測試 SDK：

```powershell
npm run test:sdk
.\scripts\package-theme.ps1 -ThemeDirectory sdk/examples/minimal `
  -OutputFile artifacts/theme-sdk/minimal.dmt
.\scripts\validate-theme-package.ps1 -Path artifacts/theme-sdk/minimal.dmt
```

SDK JS API、`.d.ts`、MockHost、manifest schema、minimal/dashboard 範例與指南位於 `sdk/`、`docs/theme-sdk.md` 和 `docs/protocol-v1.md`。SDK/MockHost 能獨立接受 Node 測試；尚無 TypeScript compiler 或第三方獨立主題在瀏覽器的驗證。由於原生 Theme Manager 尚未實作，作者產生的 `.dmt` 目前不能安裝進 DrillPaper。

## 5. Git、授權、依賴與 commits

- 實際 commit 僅有 `be5cb92 chore(phase-0): establish audit and native scaffold`；後續 Phase 0–8 變更留在未提交工作樹，無法提供逐階段 commit hash。
- 使用者已明確授權 Git commits；2026-10-28 重新執行 `git -c safe.directory=C:/WorkSpace/DrillPaper add -A`，執行環境仍把 `.git` 標為唯讀，建立 `.git/index.lock` 得到 Permission denied。**阻擋是工具 sandbox 寫入權限，不是等待使用者批准**；沒有更改 ACL 或繞過限制。需在 `.git` 可寫的工作區將變更拆成階段提交。
- 第一方授權已選 Apache-2.0，見 `LICENSE` 與 `LICENSE_DECISION.md`。Catch2 3.8.1 為 BSL-1.0 測試依賴，詳見 `THIRD_PARTY_NOTICES.md`。WebView2 SDK 使用 NuGet cache 版本 1.0.2478.35；Runtime 未打包。NVML 為選配，未把 NVIDIA DLL 放入發行包。
- 無正式 ADR；設計選擇與使用者確認條件列於 `docs/STATUS.md`、`docs/ARCHITECTURE.md` 與安全文件。

## 6. Windows、硬體、效能與安全限制

- **Windows：**只在 Windows 10 Pro x64 build 19045 編譯/執行；Windows 11、多螢幕、混合 DPI、熱插拔、鎖定/喚醒均 NOT RUN。Shell inventory 不是桌面附掛測試；`--experimental-desktop` 不支援承諾。
- **Metrics：**有 Windows collector integration smoke 與資料單位/quality 測試。沒有用儀器或受控負載比較所有 CPU/RAM/disk/network 讀值；沒有產品 NVML GPU 驗證。
- **效能：**短時 process-tree smoke 觀察到 WebView2 子程序；未產生 10–30 分鐘 DrillPaper CSV。不能推論長期資源使用或 dashboard 開銷。
- **網路：**使用者決定主題網路預設封鎖，遭第一次封鎖時提示，並提供全域 HTTP/HTTPS 開關。程式的 host source 阻擋非本機 navigation/resource，但沒有流量測試；首次提示與全域開關未接入。因此政策尚未驗收，也不能宣稱阻止資料外傳。
- **主題：**manifest/ZIP 作者工具與原生 protocol parser 各有測試，但沒有原生 `.dmt` 安裝器。第三方主題未沙箱化；不要把目前原型描述成可安全載入任意社群主題。
- **Shell/WebView recovery：**沒有 Explorer/WebView renderer crash recovery 驗收；Smart Sleep 目前只有純 C++ policy tests，沒有 Windows notifications 或 TrySuspend integration。
- **可視 GUI：**沒有 screenshot/人工 visual check。此項未測原因包括 Computer Use 自動審查拒絕操作 DrillPaper；不能把 process smoke 當作畫面證據。
- **CI/乾淨安裝：**GitHub Actions workflow 未跑；沒有 installer/uninstaller 或乾淨使用者環境結果。

## 7. 後續解除發行阻擋的順序

1. 在允許 `.git` 寫入的工作區將已完成的 Phase 變更依範圍提交，保留目前唯一基礎 commit。
2. 以 TDD 實作原生 Theme Manager：安全抽取、staging/atomic install、enumeration、activation、rollback、失敗 fallback 與 `.dmt` 負面 integration tests。
3. 接入 sampling worker/mailbox 與 Windows power/session lifecycle；以整合測試覆蓋 shutdown、resume、fresh snapshot 和不補跑行為。
4. 將使用者確認的網路策略完整接入 WebView2：提示（不自動放行）、單一全域 allow switch、HTTPS/HTTP allow、其他 URI scheme 拒絕，並實測 request types、redirect、origin、permission、download。
5. 在能進行人工 GUI 操作的環境驗收 Preview、兩個 theme rendering、Shell attach/fallback、Explorer restart、DPI/顯示器與 WebView recovery。未通過 Shell gate 就明確標為不支援。
6. 產生並保存至少 10–30 分鐘 app + WebView2 process-tree CSV，完成 Windows 10/11 相容矩陣。
7. 執行 Windows CI；補齊乾淨使用者安裝/啟動/主題套用/解除安裝，再重跑 `scripts/package.ps1`。只有 gate 成功才建立 unsigned app RC。
