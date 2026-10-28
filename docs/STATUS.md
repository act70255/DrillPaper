# 開發狀態

本紀錄更新至 2026-10-28。`PASS` 僅表示所列命令或明確範圍已在本機執行成功，不外推到未測 GUI、硬體功能、發行流程或安全性。原始規格仍見根目錄 `DesktopMonitor_Codex_Handoff.md`。

## 已確認決策

- 專案名稱：DrillPaper；首版目標 Windows 10/11 x64，支援範圍仍須按實測矩陣逐版確認。
- 主題網路預設封鎖；首次外連遭封鎖時應提示使用者前往設定；單一全域開關開啟後允許 HTTP/HTTPS，其他 URI scheme 仍封鎖。DrillPaper 不送遙測。現有 WebView2 host 會阻擋非本機來源，但提示與全域開關尚未實作，網路封鎖亦未做流量測試。
- 首個 app RC 僅供本機評估，不公開發布。
- 使用者選定第一方內容 Apache-2.0（SPDX `Apache-2.0`），著作權 `Copyright 2026 DrillPaper Project`；第三方依賴與社群主題須各自遵守其授權；保留 DrillPaper 名稱及標誌。
- TDD seams：MetricsSnapshot/採集器、Runtime 狀態與有界佇列、Theme manifest/封裝、JSON protocol/SDK；Win32 Shell 與 WebView2 用原生整合/GUI 驗證。無法取得 GUI 證據的項目保持未驗收。

## 環境與目前工作樹

- Windows 10 Pro x64 build 19045；Visual Studio Enterprise 2022 17.11.2、MSVC 19.41.34120、Node.js 22.14.0。
- 在 repository 忽略目錄 `.toolchain/` 安裝並驗證 CMake 4.3.5、Windows SDK 10.0.26100.0 及 MSVC 缺少的 headers/CRT；WebView2 SDK 1.0.2478.35，已安裝 Evergreen Runtime 155.0.4283.62。未修改系統 PATH 或 ACL。`scripts/* -LocalToolchain` 使用此工作區工具鏈；乾淨環境需先準備等效 SDK 及 Catch2 FetchContent 原始碼快取。
- Release build 目錄：`build/local-msvc-release`；可執行檔：`build/local-msvc-release/DrillPaper.exe`。
- 這台電腦先前缺少 CMake/SDK，首次檢查確實失敗；安裝工作區工具鏈後，已實際完成 Release 編譯、CTest 與 app/WebView2 protocol smoke。原先失敗紀錄不再代表目前狀態。
- 使用者已明確授權 Git commits。2026-10-28 再次執行 `git -c safe.directory=C:/WorkSpace/DrillPaper add -A`，工具環境仍拒絕建立 `.git/index.lock`（Permission denied）；因此目前只有既有 commit `be5cb92`。沒有變更 ACL 或繞過寫入限制。此工作樹的程式與文件修改尚未提交。

## Phase 0 — Repository / Environment Audit

- **狀態：部分完成。** 完成 repository、AGENTS、TDD skill、原生環境與依賴 audit；固定 Catch2 3.8.1（BSL-1.0，僅測試），建立 CMake/PowerShell build-test-environment scripts。工作區安裝 CMake/Windows SDK/WebView2 開發依賴。
- **驗證：PASS** — MSVC x64 Release app 編譯；`DrillPaper.exe --version` 輸出 `DrillPaper 0.1.0-dev`；`--diagnostics` 回報 x64 及 WebView2 Runtime 155.0.4283.62。初期無工具鏈時的失敗已記錄在歷史執行脈絡，不是目前 blocker。
- **GUI：PARTIAL** — app 已建立視窗並能跑 WebView2 smoke；Computer Use 工具拒絕對 DrillPaper 進行可視操作，沒有截圖或人工視覺檢查，因此不宣稱 UI 視覺驗收。
- **Git：BLOCKED** — `.git` 唯讀，無法建立 Phase commit；使用者授權已給，不會再詢問。受限工具環境仍拒絕寫入。
- **下一步：**完成可行的原生功能與文件；不能解除的 Shell/Theme Manager/安全/效能 gate 均具體列入交接。

## Phase 1 — DesktopHost Feasibility Spike

- **狀態：未驗收；桌布附掛不支援宣稱。** 已有 `WorkerW`/`SetParent` opt-in 程式碼、Preview fallback 與 Explorer/display-change 重試。Shell inventory 在 Windows 10 Pro 19045 列舉 17 個相關 top-level windows；`Progman` 下見到 `SHELLDLL_DefView`，未觀察到可用的全螢幕 wallpaper layer。
- **測試：NOT RUN** — 沒有以 app 實際掛載桌面、檢查圖示/工作列/Alt+Tab/focus/z-order、重啟 Explorer 或測試解鎖/解析度變更的 GUI 證據。C++ app 編譯成功不等於 Shell POC 通過。
- **結果：**`--preview` 為可用的獨立視窗路徑；`--experimental-desktop` 保持 opt-in，不能列為已支援桌布。

## Phase 2 — Metrics Core + TDD

- **狀態：部分驗收。** 已實作 typed metric/unit/quality、CPU/network 差值、Windows CPU/RAM/disk/network collectors 與選配 NVML loader。
- **測試：PASS** — CTest 涵蓋 CPU warm-up/delta/reset、metric unavailable/zero、單位與 network rate；Windows collector integration test 真正呼叫本機 API，確認 typed readings 和 CPU/network warm-up，CTest 21/21 全通過。
- **限制：**沒有以獨立儀器或已知工作負載比對各指標精度；GPU/NVML 和 disk activity 尚無專項硬體/數值驗證。app protocol smoke 只證明 snapshot 流程完成，不能據此宣稱所有硬體值正確。

## Phase 3 — Runtime / State Machine / Bounded Cache

- **狀態：核心政策測試通過；產品執行緒整合未完成。** Ring buffer 保留最多 120 筆、latest-wins coalescer、change detector、power state machine、sampling scheduler 都有 C++ 測試。
- **測試：PASS** — CTest 21/21，包括有界 history/coalescing、狀態轉換、防抖與 scheduler 不補跑過期採樣。
- **限制：**目前 app 以 UI timer 同步採樣；尚無背景 sampling worker 與已驗證的 worker→UI mailbox lifecycle、shutdown/race stress、session/display/power notification、WebView suspend/resume。

## Phase 4 — WebView2 Host + Protocol v1

- **狀態：原生 host 與 JSON protocol 已建置並做程序層整合 smoke；安全負面與 GUI 渲染驗收未完成。** Host 使用 WebView2 virtual host mapping、私有 user-data directory，處理 SDK hello/ready、snapshot/history/subscribe；拒絕非本機 navigation/resource 和新視窗。
- **測試：PASS** — CTest 21/21，含原生 JSON 序列化/解析、64 KiB 限制、版本/欄位/請求 ID/history/subscribe cases；`scripts/test-webview2-smoke.ps1` 對 `minimal` live collector 與 `dashboard --mock-metrics` 均觀察到完成 hello→snapshot→subscribe 的 `Live metrics` 標題。
- **限制：**未用真實 JS 惡意 payload/外部請求做 WebView2 負面整合測試；無 renderer crash/reload 恢復測試；未用截圖或人工視覺檢查 DOM/排版；WebView2 執行於 UI thread，metrics 也在 UI timer 同步採集。

## Phase 5 — Theme Manager / SDK / Examples

- **狀態：SDK/作者工具完成可測部分；原生 Theme Manager 未實作。** 有 manifest validator、TypeScript 宣告、JS SDK/MockHost、minimal/dashboard 範例、`.dmt` 封裝/驗證器。WebView2 透過 CLI 可各自載入兩個內建來源，尚未提供執行期熱切換。
- **測試：PASS** — 18/18 Node 測試；`.dmt` validator 接受有效包，拒絕 traversal、大小寫重複路徑、不允許副檔名、錯誤 API version、超過 10 MiB 檔案；SDK package 解壓後重跑測試與兩個 theme validator，SHA-256 可重現。
- **產物：**`artifacts/DrillPaper-Theme-SDK-1.0.0-rc3.zip`，49,107 bytes，SHA-256 `68E0B5F41FB2337B396A5335CA1707B0F6F5E275F3771EF913E1DF8210D01656`。Apache-2.0；本機評估包，不含 app。
- **限制：**無 `.dmt` 原生匯入、staging/atomic install、列舉、切換、rollback、舊 API 提示或 100 次切換資源測試。

## Phase 6 — Smart Sleep / Recovery / Security Hardening

- **狀態：部分策略與 baseline host 控制已實作；未達安全或省電驗收。** C++ `ThemeNetworkPolicy` 模型測試通過；WebView2 host 阻擋外部 navigation/resource 和新視窗。
- **測試：PARTIAL** — CTest policy/schema cases 通過；未對 WebView2 執行 egress、redirect、fetch/XHR/image/script/iframe/WebSocket、permission 或 download 負面測試。
- **限制：**使用者要的首次阻擋提示與單一全域 allow HTTP/HTTPS 開關尚未接入；network policy model 未整合至 request interception。尚無 WTS/display/power events、TrySuspend/Resume、renderer/Explorer crash recovery。不得宣稱外部主題已沙箱化或 egress 已驗收。

## Phase 7 — Performance / Regression / Compatibility

- **狀態：量測工具有 smoke；產品效能與相容性驗收未跑。** Process-tree sampler 支援將可追溯 WebView2 child processes 計入統計；曾以 DrillPaper+WebView2 跑短時程序樹 smoke，觀察到 app 與 `msedgewebview2`，共兩筆 sample。
- **測試：NOT RUN** — 無 10–30 分鐘產品 CSV，也未比較 minimal/dashboard、locked/display-off、主題切換或長時間資源成長。
- **相容性：NOT RUN** — 目前只在 Windows 10 Pro x64 build 19045 建置；Windows 11、多螢幕、DPI/熱插拔與 Explorer recovery 未驗收。

## Phase 8 — CI / Packaging / Release Candidate

- **狀態：SDK RC 可交付本機評估；DrillPaper app RC 被正確 gate 阻擋。** `scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1 -LocalToolchain` 實際完成 build、完整測試後停止，明確報告缺 `src/themes/theme_manager.cpp`。沒有產生 app ZIP；不要稱 app RC 已完成。
- **測試：PASS / BLOCKED** — `scripts/test.ps1 -Configuration Release -LocalToolchain`：CTest 21/21、Node 18/18、環境檢查回歸、`.dmt` 正負案例及 SDK ZIP 解壓/重封驗證全通過。Windows GitHub Actions 未執行。`--version`、`--diagnostics` 與 WebView2 smoke 已實測。
- **限制：**沒有安裝器、乾淨 Windows user install/uninstall 驗證、app ZIP、簽章、長時間效能報告或 CI runner log。
- **下一步：**實作與測試 Theme Manager、使用者網路提示/全域設定、worker/smart sleep、原生 Shell GUI 支援；完成安全與效能矩陣後再解除 RC gate。需在可寫 `.git` 的受控環境按 Phase 建立 commit。
