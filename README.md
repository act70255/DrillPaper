# DrillPaper

DrillPaper 是 Windows x64 C++20/Win32 與 WebView2 的本機系統指標主題宿主原型。Preview 可載入兩個內建主題、以原生功能表熱切換，並透過 CLI 安裝與列舉資料夾／`.dmt` 主題。目前**不是可安裝產品或 app Release Candidate**；桌布附掛、完整瀏覽器安全、省電整合與發行驗收仍未完成。

專案品牌為 DrillPaper；C++ namespace/include 與部分相容 API 沿用原始 DesktopMonitor 規格。JS SDK 主要入口為 `DrillPaper`，另保留 DesktopMonitor 相容別名。

## 狀態與限制

請先讀 [`docs/STATUS.md`](docs/STATUS.md) 與 [`docs/FINAL_HANDOFF.md`](docs/FINAL_HANDOFF.md)。原生建置、核心測試與 Node SDK 測試已有實測證據；原生 ZIP 匯入、安全負面案例、CLI 與主題切換也各有驗證。各次命令及驗收範圍以 STATUS 為準，不外推到硬體精度、桌布附掛或瀏覽器沙箱。

`scripts/package.ps1` 保留明確的發行阻擋；沒有 app RC ZIP 或安裝器。SDK `1.0.0-rc3` 是本機評估包，不含 app。主題尚未沙箱化，僅匯入你信任的內容；外連提示與全域網路開關尚未完成。

## 開發環境

- Windows 10/11 x64、Visual Studio 2022 C++ 工作負載、Windows SDK、CMake 3.25+、Git。
- WebView2 Evergreen Runtime；本機測試版本為 155.0.4283.62，SDK 1.0.2478.35。
- Node.js 22 僅供 Theme SDK/manifest 測試，不是預定產品 runtime。
- NVIDIA NVML 為選配；不支援時應回報 `unavailable`。目前沒有產品 GPU 精度驗證。

本機 Windows 11 環境的安裝版本與步驟見 [`docs/ENVIRONMENT.md`](docs/ENVIRONMENT.md)。建置與測試：

```powershell
.\scripts\build.ps1 -Configuration Release
.\scripts\test.ps1 -Configuration Release
```

`-LocalToolchain` 僅供先前電腦的 `.toolchain/with-winsdk.cmd` wrapper，這台電腦不需要。原生 CTest：

```powershell
ctest --preset windows-msvc-release --output-on-failure
```

## 執行開發 Preview

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --mock-metrics --theme=dashboard
.\build\windows-msvc-release\Release\DrillPaper.exe --preview --theme=minimal
```

`--version` 和 `--diagnostics` 顯示 build/runtime 資訊。`scripts/test-webview2-smoke.ps1` 會以視窗標題確認 hello、snapshot、subscribe 流程；它不是截圖或 visual QA。Preview 不代表 `--experimental-desktop` 桌面附掛獲得支援。

採集已在背景執行，Windows 工作階段與電源事件會調整採樣及 WebView2 暫停／恢復；`--no-smart-sleep` 可停用這項政策供除錯。鎖定／解鎖已有本機人工與受控事件證據，真實顯示器電源、待機及完整相容性仍待驗收，見 [`docs/runtime.md`](docs/runtime.md)。

## Theme SDK

SDK JS、TypeScript declarations、MockHost、manifest schema、兩個範例與作者指南位於 `sdk/`。執行 `npm run test:sdk` 驗證 JS API。安裝與列舉主題：

```powershell
.\build\windows-msvc-release\Release\DrillPaper.exe --import-theme "C:\Themes\example.dmt"
.\build\windows-msvc-release\Release\DrillPaper.exe --list-themes
```

主題安裝到 `%LOCALAPPDATA%\DrillPaper\themes\<id>@<version>`，同版本禁止覆蓋；失敗會清除本次暫存安裝。Preview 的「主題」功能表可選擇內建及已安裝版本；執行中從 CLI 匯入後，選「重新整理已安裝主題」即可列出。主題未於 20 秒內完成握手時會嘗試回復 Minimal。原生採集程序不因切換而重啟；目前沒有圖形化匯入器或移除介面。

詳見 [`docs/theme-sdk.md`](docs/theme-sdk.md)、[`docs/protocol-v1.md`](docs/protocol-v1.md) 和 [`docs/theme-security.md`](docs/theme-security.md)。第一方內容依 Apache-2.0 授權，見根目錄 [`LICENSE`](LICENSE)。
