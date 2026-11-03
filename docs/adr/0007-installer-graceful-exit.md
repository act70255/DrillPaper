# ADR 0007：安裝與解除安裝前以 `--exit-running` 正式結束執行中的實例

日期：2026-11-03。狀態：已採用並驗證（票 17）。

## 問題

DrillPaper 常駐在系統匣。覆蓋安裝或解除安裝時，若程式仍在執行，EXE 與 DLL 會被鎖住；若被強制終止，則可能沒有正常保存或清理 WebView2 子程序。票 17 要求「正常關閉，不能強制終止後留下檔案鎖」，並要求評估 Inno Setup 的 Restart Manager（`CloseApplications`）或 `AppMutex`。

## 決策

- 新增 app 命令列旗標 `--exit-running`（實作在 `platform/windows/running_instances`）：以程序快照找出映像路徑與自己相同的其他實例，對擁有管理視窗者送出與「結束 DrillPaper」按鈕相同的命令（`WM_COMMAND(kManageExit, BN_CLICKED)`），等待最多 15 秒。全部結束時回傳 0；有實例逾時、命令送不出去，或沒有管理視窗（例如以 `--preview` 啟動）時回傳 2；絕不強制終止。
- 安裝檔設定 `CloseApplications=no`，由 `[Code]` 在 `PrepareToInstall` 與 `InitializeUninstall` 執行已安裝的 `DrillPaper.exe --exit-running`；回傳非 0 時停止，並以繁中提示使用者從系統匣結束、關閉預覽視窗後重試。

## 考慮過的替代方案

- **Restart Manager（`CloseApplications=yes`）**：會對沒有回應的程式發 WM_CLOSE／WM_QUERYENDSESSION，必要時強制終止；DrillPaper 的正式退出路徑是管理命令，不保證走到同一套清理，且可能強制終止，不符要求。
- **`AppMutex`**：只能偵測「是否有實例」並請使用者手動關閉，無法代為正式結束；且 app 目前沒有單一實例 mutex，需要另加，並會影響同時執行多份測試副本的既有流程。

## 取捨與限制

- 只處理**同一路徑**的實例；其他位置的 ZIP 副本不受影響（刻意設計）。
- 沒有管理視窗的實例（`--preview`、`--experimental-desktop`）無法正式結束，安裝會停止並請使用者手動關閉；不會誤報成功。
- 第一次安裝時尚無舊 EXE，不呼叫 `--exit-running`。

## 驗證

替身程序的整合測試涵蓋同路徑正式結束、不同路徑不受影響、逾時、無管理視窗回報 unreachable；實機以 trial.9／trial.11 驗證管理實例在覆蓋安裝與解除安裝前正式結束、`--preview` 實例使安裝停止且未被終止。證據見 `docs/acceptance/2026-11-02/installer/REPORT.md`。
