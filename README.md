# DrillPaper

DrillPaper 是 Windows x64 C++20/Win32 與 WebView2 的本機系統指標主題宿主原型。Release build 可編譯，Preview 可啟動兩個內建頁面並完成 SDK protocol smoke；目前**不是可安裝產品或 app Release Candidate**。桌面 Shell 附掛、Theme Manager、安全策略完整接線、Smart Sleep 整合、長時間效能與乾淨 Windows 安裝尚未驗收。

專案品牌為 DrillPaper；C++ namespace/include 與部分相容 API 沿用原始 DesktopMonitor 規格。JS SDK 主要入口為 `DrillPaper`，另保留 DesktopMonitor 相容別名。

## 狀態與限制

請先讀 [`docs/STATUS.md`](docs/STATUS.md) 與 [`docs/FINAL_HANDOFF.md`](docs/FINAL_HANDOFF.md)。原生 Windows host/metrics collectors/protocol parser 已實際編譯；CTest 21/21、Node 18/18，以及兩個 built-in theme 的程序層 WebView2 smoke 已通過。這些結果不等於畫面目視、硬體精度、桌布附掛或安全驗收。

`scripts/package.ps1` 會因 `src/themes/theme_manager.cpp` 尚未實作而阻止 app RC；沒有 app ZIP 或安裝器。SDK `1.0.0-rc3` ZIP 是已驗證的本機評估包，不含 app。第三方主題未沙箱化；外連提示與全域網路開關尚未接入 WebView2。

## 開發環境

- Windows 10/11 x64、Visual Studio 2022 C++ 工作負載、Windows SDK、CMake 3.25+、Git。
- WebView2 Evergreen Runtime；本機測試版本為 155.0.4283.62，SDK 1.0.2478.35。
- Node.js 22 僅供 Theme SDK/manifest 測試，不是預定產品 runtime。
- NVIDIA NVML 為選配；不支援時應回報 `unavailable`。目前沒有產品 GPU 精度驗證。

目前環境的 CMake/Windows SDK/MSVC headers 安裝在忽略的 `.toolchain/`，不會修改系統 PATH。使用本機工具鏈重建與測試：

```powershell
.\scripts\build.ps1 -Configuration Release -LocalToolchain
.\scripts\test.ps1 -Configuration Release -LocalToolchain
```

在已將 MSVC/Windows SDK/CMake 配好環境變數的其他機器，可用一般模式：

```powershell
.\scripts\build.ps1 -Configuration Release
.\scripts\test.ps1 -Configuration Release
```

原生 CTest：

```powershell
ctest --test-dir build/local-msvc-release --output-on-failure
```

## 執行開發 Preview

```powershell
.\build\local-msvc-release\DrillPaper.exe --preview --mock-metrics --theme=dashboard
.\build\local-msvc-release\DrillPaper.exe --preview --theme=minimal
```

`--version` 和 `--diagnostics` 顯示 build/runtime 資訊。`scripts/test-webview2-smoke.ps1` 會以視窗標題確認 hello、snapshot、subscribe 流程；它不是截圖或 visual QA。Preview 不代表 `--experimental-desktop` 桌面附掛獲得支援。

## Theme SDK

SDK JS、TypeScript declarations、MockHost、manifest schema、兩個範例與作者指南位於 `sdk/`。執行 `npm run test:sdk` 驗證 JS API。`.dmt` 腳本可封裝和檢查 theme，但目前無法匯入 app，因原生 Theme Manager 尚未建立。

詳見 [`docs/theme-sdk.md`](docs/theme-sdk.md)、[`docs/protocol-v1.md`](docs/protocol-v1.md) 和 [`docs/theme-security.md`](docs/theme-security.md)。第一方內容依 Apache-2.0 授權，見根目錄 [`LICENSE`](LICENSE)。
