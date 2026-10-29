# 本機開發環境

2026-10-28 在 `C:\WorkSpace\-James\DrillPaper` 準備；與舊交接的 Windows 10 電腦不同。

| 元件 | 本機版本／位置 |
| --- | --- |
| Windows | Windows 11 Pro 25H2，build 26200.8737；舊 registry ProductName 仍顯示 Windows 10，依 build 判定 |
| Visual Studio | Professional 2022 17.14.17，C++ x64 工具已存在 |
| MSVC | 19.44.35217，工具目錄 14.44.35207 |
| Windows SDK | 10.0.26100.0，含 headers 與 x64 import libraries |
| CMake／CTest | 3.31.6，透過 `uv tool install cmake==3.31.6` 安裝至使用者工具目錄 |
| WebView2 SDK | 1.0.2478.35，官方 NuGet 包，位於 `%USERPROFILE%\.nuget\packages\microsoft.web.webview2\1.0.2478.35` |
| WebView2 Runtime | 已有 Evergreen 155.0.4283.62 |
| Node.js | 已有 24.17.0；用於 SDK 與工具測試，產品不依賴 Node runtime |
| GPU | Intel Graphics；沒有 NVIDIA，NVML 為選配，不安裝無用途的 NVIDIA 元件 |

CMake／CTest 使用既有 `%USERPROFILE%\.local\bin` PATH；不需系統管理員權限，不變更系統 PATH 或 ACL。Python／uv 只用來安裝建置工具，不納入產品。

## 重現

先安裝 Visual Studio 2022 C++ 桌面工作負載及 Windows SDK，並保留已安裝的 Evergreen Runtime。CMake：

```powershell
uv tool install cmake==3.31.6
cmake --version
ctest --version
```

WebView2 SDK 來源：`https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.2478.35/microsoft.web.webview2.1.0.2478.35.nupkg`。解壓到上表指定目錄；CMake 會檢查 headers 及 x64 loader，缺少即停止，不退回舊版本。

乾淨環境可用固定包與雜湊的還原腳本（目的地必須不存在，既有安裝不覆寫）：

```powershell
$sdkRoot = Join-Path $env:USERPROFILE '.nuget/packages/microsoft.web.webview2/1.0.2478.35'
./scripts/restore-webview2-sdk.ps1 -Destination $sdkRoot
```

SDK 1.0.2478.35 官方包的 SHA-256 為 `B1DF2D7FE955A3378603735F910B126647E43033213B5CC071B8D6F0168A3B96`。可指定 `-ArchivePath` 使用既有官方封包，仍須通過相同雜湊。CI 還原到 runner 暫存目錄，再設定 `WEBVIEW2_SDK_ROOT`；沒有將開發機已安裝依賴當作 runner 預設。

```powershell
.\scripts\check-environment.ps1 -RequireNativeBuildTools
.\scripts\build.ps1 -Configuration Release
.\scripts\test.ps1 -Configuration Release
```

不需要 `-LocalToolchain`；那是上一台電腦專用的 SDK wrapper。首次 configure 會下載鎖定 SHA-256 的 Catch2 3.8.1，以及主題管理依賴 miniz 3.0.2／nlohmann JSON 3.11.3。使用官方版本壓縮檔，避免 shallow clone 仍擷取多個 tags 所造成的首次下載延遲。

環境可建置不代表桌布、GUI、安全、硬體精度或 Windows 相容性已驗收；實際命令結果另記 `docs/STATUS.md`。
