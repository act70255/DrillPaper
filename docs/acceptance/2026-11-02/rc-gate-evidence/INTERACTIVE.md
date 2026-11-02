# RC 11 互動實機驗證紀錄

票：`.scratch/rc-delivery/issues/11-rc-gate-evidence.md`。分支 `feature/rc-11-gate-evidence`。方式：使用者一次只做一項動作。每項動作前 Claude 先啟動只讀觀測，使用者回報後 Claude 核對記錄並判定結果，每步完成即 commit＋push。

## 候選與環境

| 項目 | 值 |
| --- | --- |
| 候選套件 | `artifacts/DrillPaper-0.1.0-trial.8-win-x64-unsigned.zip` |
| 套件 SHA-256 | `63A98B5B20F23F9470C2EFEA2DDBC0311ED2EE03EDFFC95AA0021221D73ACD53` |
| 來源 commit | `ae1c5e05e5562cd0297bcf22abf2e06b3749836f`（含 12～15 與 10），`build-trial.ps1` 從 git archive 乾淨建置 |
| 套件驗證 | `verify-trial-archive.ps1`：白名單 55 檔與逐檔／EXE／ZIP hash 相符，結果 PASS |
| EXE SHA-256 | `7444C1D946F9AF31B2C3EE37D8B12DB3F3BBEBE67F9707ACE16B338C20131C52` |
| 作業系統 | Windows 11 專業版 25H2 build 26200.8737 |
| WebView2 Runtime | 156.0.4314.58 |
| 顯示器 | DISPLAY1：主螢幕，1920×1080，DPI 144。DISPLAY2：1920×1080，DPI 96，位於 x=1920 |
| 防毒 | Trend Micro Apex One。開始前 `AEGIS_BM.log` 為 41998 bytes，最後修改 2026-11-01T09:42:36+08:00 |
| 測試位置 | `%USERPROFILE%\DrillPaperTests\RC11 互動 實機\trial8 套件`，非 Temp |
| 隔離資料 | `LOCALAPPDATA`、`TEMP` 與 `TMP` 導向同一測試目錄下的 `appdata`／`staging-temp` |
| 啟動方式 | `launch-trial8.cmd`：cmd `start` 直接啟動 `DrillPaper.exe --management`，未經 PowerShell。使用產品預設，智慧休眠開啟，沒有帶 `--no-smart-sleep` |
| 觀測 | 票 10 的 `observe-os-v2.ps1`（只讀）。每 100 ms 記錄 console display state、WTS 鎖定旗標，以及隔離宿主的標題、LoadEpoch、ReadyEpoch、MetricsTick、HealthTick、TargetDpi，寫入 `os-state.jsonl` |

原持續桌布 PID 83428 已不存在。本機開機時間為 2026-11-02 10:11:07，該程序最後一次確認存活約在 09:50（票 10 重試），判斷是因重新開機而結束，與本票測試無關。本票未重新啟動它，也未替換它。

## 步驟結果

| 步驟 | 時間（+08） | 使用者動作與回報 | Claude 核對 | 結果 |
| --- | --- | --- | --- | --- |
| S0 啟動 | 13:59:43 | 由 Claude 以 cmd 啟動 | PID 62112，路徑為隔離副本。首次預設為主螢幕單一宿主，ReadyEpoch=1；約 20 秒內 MetricsTick 與 HealthTick 前進，標題由「恢復中」轉為「Live metrics」。console display=1、未鎖定 | PASS |
| S1-1 管理視窗固定尺寸 | 14:02 | 回報：管理視窗出現；拖拉邊框無法改變大小，最大化沒有反應，文字正常 | 以逐螢幕 DPI 感知方式量測，用戶區 1200×900 px，DPI 144，換算為 800×600 DIP。無 WS_THICKFRAME，無 WS_MAXIMIZEBOX，視窗 DPI awareness=2（per-monitor）。以 DPI-unaware 程序量測時得到 800×600 px，屬量測端座標虛擬化，不作為產品結果 | PASS |
| S1-2 雙目標選擇與保存 | 14:20 | 回報：清單顯示「顯示器 1（未提供名稱）1920×1080 150%」與「DELL E242HS 1920×1080 100%」；勾選兩者並套用、保存後提示「設定已儲存；各目標仍須等待主題載入完成。」；兩個螢幕各自顯示完整 UI，沒有裁切 | 14:21:21 有兩個宿主 HWND 265396（DPI 144）與 462336（DPI 96），標題皆為「Live metrics」，6 秒內兩者 MetricsTick 與 HealthTick 皆前進。隔離 `settings.json` 為 schema 2，`monitorTargets` 為兩個 `monitorDevicePath`（boe0afc／delf15e），`displayMode=desktop`、`smartSleep=true`。LoadEpoch／ReadyEpoch 是全域遞增序號，不比較兩者大小 | PASS |
| S2-1 桌面圖示互動 | 14:22～14:23 | 回報：圖示正常顯示在桌布上方；單擊選取與右鍵選單皆正常，按 Esc 可關閉；桌布沒有閃爍 | 14:21:30～14:23:39 共 989 筆取樣，宿主 HWND 維持 265396／462336，沒有重建（LoadEpoch 不變），標題全程為「Live metrics」。最後一筆 MetricsTick 與 tick64 相差不到 1 秒。console display=1、未鎖定 | PASS |
