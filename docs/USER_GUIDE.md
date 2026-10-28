# 使用者指南（開發 Preview）

目前 DrillPaper 沒有安裝器或可發布 app RC。以下命令適用於已有 Visual Studio、Windows SDK、CMake 與 WebView2 Runtime 的開發電腦，不代表一般使用者安裝流程已驗收。

## 建置與測試

在 repository 根目錄開 PowerShell：

```powershell
.\scripts\build.ps1 -Configuration Release -LocalToolchain
.\scripts\test.ps1 -Configuration Release -LocalToolchain
```

若已將 MSVC/Windows SDK/CMake 設定在環境中，可省略 `-LocalToolchain`。測試涵蓋 native CTest、Node SDK、environment regression 與 theme package validators。

## 執行 Preview

```powershell
.\build\local-msvc-release\DrillPaper.exe --preview --mock-metrics --theme=dashboard
.\build\local-msvc-release\DrillPaper.exe --preview --theme=minimal
.\build\local-msvc-release\DrillPaper.exe --version
.\build\local-msvc-release\DrillPaper.exe --diagnostics
```

`--mock-metrics` 使用測試資料；省略該旗標時採集器讀取本機 Windows metrics。`--theme` 僅能選擇內建 `minimal` 或 `dashboard`，每次啟動選一個。關閉 Preview 視窗可退出。WebView2 Evergreen Runtime 是執行需求，本機測試機已安裝；不會由此開發流程自動安裝。

此視窗不是桌布附掛，不提供 `.dmt` 匯入、執行期主題切換、系統 tray、安裝或解除安裝功能。`--experimental-desktop` 不在已支援的使用方式內。

## Theme 作者檢查

```powershell
npm run test:sdk
.\scripts\package-theme.ps1 -ThemeDirectory sdk/examples/minimal `
  -OutputFile artifacts/theme-sdk/minimal.dmt
.\scripts\validate-theme-package.ps1 -Path artifacts/theme-sdk/minimal.dmt
```

`.dmt` 目前由開發工具建立並驗證；尚不能匯入 DrillPaper。SDK 使用說明見 [`theme-sdk.md`](theme-sdk.md)。

## 限制

第三方 theme 未沙箱化。外部網路提示與使用者全域開關尚未接線；網路 policy 源碼不足以證明封鎖。桌布、Explorer recovery、鎖定/顯示器電源休眠、安全負面案例與長時間效能均未驗收。請勿把這個 prototype 描述為可安全安裝社群主題的動態桌布產品。
