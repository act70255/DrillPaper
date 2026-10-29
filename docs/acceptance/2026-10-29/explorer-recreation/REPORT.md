# Explorer 宿主視窗銷毀復原修正

## 根因與範圍

使用者真正重啟 Explorer 後，原 HWND 已失效而 app／通知視窗仍存在；原復原函式直接略過失效 HWND，背景採樣也只對舊 HWND 發送訊息。另一種跨程序正常關閉路徑會送 WM_DESTROY，舊碼把它當成整個 app 的正常退出。

現在由穩定且不附掛 Shell 的通知視窗接收樣本；區分 WM_CLOSE 與非預期 WM_DESTROY，必要時清理舊宿主、建立新的原生視窗與 WebView2。WebView2 adapter 保留主題目錄／名稱／入口、快照與 runtime 政策，原生 UI thread 負責重建，不重啟採集工作者。新增的 parent fixture 僅在 BUILD_TESTING 建置，不屬產品依賴。

## Red／Green

- `before-parent-destroy.json`：舊版公開 app 經隔離父視窗銷毀後提前退出，實際測試先失敗。
- `close-5.json`：正常關閉隔離父程序 5 次，新握手與新指標均恢復。
- `crash-no-notification-5.json`：終止自己啟動的隔離父程序 5 次，不發送復原通知，新握手世代 1→6，仍重建並附掛。
- 各測試只操作自己啟動並驗證 PID／視窗類別的 app 及 fixture，不終止 Explorer。正常 app 退出碼 0，最後觀察的 WebView2 子程序全退出。
- `MetricsTick` 只在 metrics.changed 成功交給 WebView2 後更新；重建後要求至少兩次新 tick，以免只測新握手而漏掉採樣仍送舊 HWND。這不等於 JavaScript 畫面或 GPU 像素驗收。

```powershell
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperParentFixture --parallel 8
powershell -NoProfile -File scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -RecoveryCycles 5 -DestroyParent -TimeoutSeconds 20
powershell -NoProfile -File scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -RecoveryCycles 5 -DestroyParent -ParentExit crash -NoRecoveryNotification -TimeoutSeconds 20
```

## 相關回歸

`regression/` 保存完整本機測試及相關腳本輸出。CTest 28/28、SDK 18/18；受控生命週期 5 次、50 次快速往返與暫停期間退出；自訂入口 renderer 故障 3 次；主題切換與 Dashboard mock Preview 皆通過。

Windows PowerShell 5.1 的 UIntPtr 轉換與單一 CIM 物件 Count 差異均曾造成工具失敗，已修正後重跑；未放寬目標身分或數量上限。協定測試停用 Smart Sleep，避免真實 display-off 干擾；不能用它們取代電源測試。

最終版另補上 HWND 的程序／UI 執行緒／類別核對，避免作業系統重用舊控制代碼。`close-5.json`、`crash-no-notification-5.json` 與 `full-final.log` 均對應下列最終 hash；其他相關 GUI 腳本在加入此身分核對前的 `83ECE8B4…` 版本執行，原始輸出保留，不混稱受測二進位相同。

## 仍待驗收

修正 commit `f2cff39` 已在 [CI 40810412264](https://github.com/act70255/DrillPaper/actions/runs/40810412264) 通過乾淨 Windows runner 的 build／CTest 28/28／SDK 18/18；新增 fixture 也已編譯。此 CI 不執行目前使用者桌面的附掛或實體 Explorer 重啟。metadata 與節錄保存在 `ci.json`／`ci.log`。

受測 Release EXE SHA-256 為 `AC61E02C42E78102514A0C3558E1951FE87D37E9E6D5D042E1B8FADD28C273BA`。真正 Explorer 重啟仍需以此修正版再測，並由使用者確認桌布可見、持續更新。先前失敗證據保留在 `../explorer-failure/`。其他 Windows builds、混合 DPI、電源與重建交錯、長時間資源觀測仍 NOT RUN。
