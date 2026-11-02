# Third-party notices

## Microsoft WebView2

- WebView2Loader.dll x64：1.0.2478.35，Microsoft，BSD-3-Clause；應用程式必要的動態 loader，隨試用包再散布。
- 來源：[固定版本 NuGet](https://www.nuget.org/packages/Microsoft.Web.WebView2/1.0.2478.35)，原包 SHA-256 `B1DF2D7FE955A3378603735F910B126647E43033213B5CC071B8D6F0168A3B96`，與現有 bootstrap 腳本一致。
- 原包 LICENSE.txt／NOTICE.txt 保持原文，收於 `third_party/licenses/webview2-1.0.2478.35-{license,notice}.txt`，試用包放在 `resources/licenses/`。原文依法保留，不翻譯授權條款。
- 完整 WebView2 Evergreen Runtime 為外部前置依賴，不隨包再散布；取得與一般使用者部署方式見 [官方散布文件](https://learn.microsoft.com/microsoft-edge/webview2/concepts/distribution)。

## Microsoft Visual C++ runtime 與 Windows

app 使用 MSVC /MD。VC++ v14 x64 runtime 與 Windows 系統 DLL 未複製進試用包；runtime 最低版本由建置工具鏈的 VCRedistVersion 記錄並寫入 manifest。缺失時啟動入口提供 [官方取得方式](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)，不自動安裝或提升權限。NVML 仍只動態讀取既有驅動，不再散布 NVIDIA DLL。

## TypeScript 作者工具

- TypeScript 5.9.3，Microsoft，Apache-2.0；來源與 integrity 固定在 `sdk/author-starter/package-lock.json`，由作者執行 npm ci 取得。此處只散布作者範本與 lockfile，不散布 compiler 或 node_modules，不是 app runtime 依賴。上游授權：https://github.com/microsoft/TypeScript/blob/v5.9.3/LICENSE.txt 。

## Catch2（原生測試）

- Version: 3.8.1 (pinned Git tag `v3.8.1` in CMake FetchContent)
- Source: https://github.com/catchorg/Catch2
- License: Boost Software License 1.0 (BSL-1.0)
- Use: native unit-test executable only; not part of the application package.

The project does not redistribute Catch2 source or binaries in its release package. The selected release and CMake targets are documented by the [Catch2 CMake integration guide](https://github.com/catchorg/Catch2/blob/v3.8.1/docs/cmake-integration.md). The upstream repository identifies its license as BSL-1.0 and contains the license text in the same tagged source.

## Theme manager dependencies

- nlohmann/json 3.11.3, MIT, Copyright 2013–2022 Niels Lohmann: https://github.com/nlohmann/json/blob/v3.11.3/LICENSE.MIT
- miniz 3.0.2, MIT, Copyright 2013–2014 RAD Game Tools and Valve Software, Copyright 2010–2014 Rich Geldreich and Tenacious Software LLC: https://github.com/richgel999/miniz/blob/3.0.2/LICENSE

The native theme commands link these dependencies into the app. Complete upstream license texts are in `third_party/licenses/` and copied to the build's `resources/licenses/`.
