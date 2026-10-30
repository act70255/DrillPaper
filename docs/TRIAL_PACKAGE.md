# 首次試用包需求與重現流程

本文件落實已確認的 03／7A；01／02 均 implemented。產品來源固定為本票起始 HEAD `e6aa20e109da8cdd5402fe06ae0d11f3bc539d53`。無產品程式改動，正式 `package.ps1` 與 RC gate 保留。

2026-10-30 已確認本票只調整打包入口，不改產品程式。入口帶 `--management --no-smart-sleep`，沿用使用者保存模式；全新資料首次為 Minimal 桌布、主螢幕目標，保存 Preview 後再次從相同入口啟動仍為 Preview。預設智慧休眠啟動仍為 **FAIL**，根因與修正交給 05；08 須移除繞行、回到產品預設重新打包驗證，09 持續列為 gate。關閉智慧休眠的本票啟動 PASS 不等於產品預設啟動 PASS。

## 實作範圍

- `build-trial.ps1` 從明確 commit 用 git archive 匯出乾淨來源，在獨立目錄建置 MSVC x64 Release。只建 app，不隱含執行完整測試。建置結果與來源 commit 留存。
- `package-trial.ps1` 公開封裝入口按 JSON 白名單逐檔驗證、複製，拒絕缺檔、空檔、逃逸／連結及覆寫；不遞迴帶入設定、匯入內容、日誌、證據、憑證或暫存。輸出含逐檔 SHA-256 的 manifest，外部 sidecar 記錄 ZIP／EXE SHA-256。
- 保持 app 實際讀取的 `resources/themes/{minimal,dashboard}/index.html` 及各自 `javascript` 目錄。封裝 Apache-2.0、JSON／miniz MIT 與 WebView2 NuGet 授權／NOTICE。
- VC++ v14 x64 動態 runtime 與 WebView2 Evergreen 為外部前置依賴，不自動安裝、不提升權限。試用啟動入口先檢查，再開啟管理視窗與保存模式，本次智慧休眠關閉；未按保存不改寫偏好，按保存則包含目前關閉的智慧休眠草稿。直接 EXE 仍有原有啟動行為與產品預設。完整使用與限制隨包提供。
- ZIP 與 metadata 明確標 trial／unsigned；包內產品 `--version` 保持既有 `0.1.0-dev`，以 manifest 的 commit／EXE hash 識別。本次封裝工具本身與模板另以 SHA-256 記錄，避免把未提交工具宣稱為產品來源 commit。

## 已確認測試 seam 與驗證

依票單 Acceptance 的封裝要求，測試公開 package CLI：缺檔拒絕、友善錯誤、無半成品、白名單排除額外私有內容、路徑與來源識別、ZIP 清單／hash。先一個失敗案例再最小實作。使用真實檔案與 ZIP，不 mock 內部函式。

01／02 相關 CTest 與原生管理／多目標腳本照跑；套件解壓至含空白與繁中的另一目錄，使用隔離 LOCALAPPDATA。自足性以移走本次乾淨來源／build 後的兩主題 SDK 握手驗證，不以單元測試代替畫面。原持續桌布只核對 PID、路徑、建立時間與 hash，不關閉／替換，不重啟 Explorer。

人工畫面、真正系統匣點擊、乾淨使用者缺依賴環境與 04～07 完整矩陣按既定決策標 NOT RUN，附清單於報告；09 才跑完整套件。

## 重現

需要 Git、CMake 3.25+、VS 2022 C++／Windows SDK 及固定 WebView2 SDK 1.0.2478.35。SDK 可先用 `scripts/restore-webview2-sdk.ps1 -Destination <目錄>` 還原，設定 `WEBVIEW2_SDK_ROOT`。FetchContent 下載使用 CMake 固定 SHA-256。

```powershell
./scripts/build-trial.ps1 -SourceCommit e6aa20e109da8cdd5402fe06ae0d11f3bc539d53 -Version 0.1.0-trial.1
./scripts/test-trial-package.ps1
```

包的來源、檔案清單、實際命令與本機驗收結果見 `docs/acceptance/2026-10-29/trial-package/REPORT.md`。08 可指定新 SourceCommit 與 trial 版本沿用此流程；本入口僅產試用包，正式發行仍須原 gate。
