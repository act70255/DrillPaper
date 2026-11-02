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
| S2-2 Alt+Tab 與焦點 | 14:25 | 回報：Alt+Tab 清單沒有出現桌布視窗，焦點沒有被搶走 | 兩個宿主皆為 WS_CHILD，父視窗為 WorkerW 134834，根為 Progman，有 WS_EX_TOOLWINDOW、沒有 WS_EX_APPWINDOW，因此不會列入 Alt+Tab。當下前景視窗為其他程式（Qt663QWindowIcon），不是桌布宿主 | PASS |
| S2-3 Win+D 顯示桌面 | 14:26～14:27 | 回報：按 Win+D 後兩個螢幕的桌布都在且持續更新；再按一次視窗正常還原；沒有閃爍 | 14:25:30～14:27:37 共 961 筆取樣，宿主沒有重建且全程可見，標題皆為「Live metrics」。MetricsTick 相鄰更新的最大間隔為 1234 ms（約 1 Hz）。最後一筆 MetricsTick 落後 390 ms、HealthTick 落後 781 ms | PASS |
| S2-4 虛擬桌面切換 | 14:35:26～14:35:46 | 回報：新增並切到新虛擬桌面時，兩個螢幕都有桌布且持續更新；切回原桌面正常；沒有閃爍 | 14:27:40～14:36:11 共 3938 筆取樣，宿主 HWND 與 LoadEpoch 不變（沒有重建），全程可見。切換期間智慧休眠三次判定 `obscured`，短暫進入「已暫停」或「低頻模式」，時間點為 14:35:26、14:35:33 與 14:35:43，各在 3～5 秒內自動回到「Live metrics」（最後一次經「恢復中」，於 14:35:46.8 恢復）。MetricsTick 最大停頓 6015 ms，與暫停區間吻合。console display=1、未鎖定 | PASS（觀察：虛擬桌面過場會讓智慧休眠短暫暫停約 3～5 秒，符合遮蔽政策，並會自動恢復） |
| S3 真實鎖定／解鎖（第 1 次） | 14:40:20～14:42:41 | 回報：5 次都恢復，約 3 秒內數字繼續更新 | 14:36:12～14:43:15 的 OS 紀錄只有 **1 次**鎖定（WTS 旗標 0）。14:40:20 鎖定後兩個宿主皆為「locked — 已暫停」；14:40:57 鎖定畫面逾時，真實 console display 轉為 0，宿主改為「display-off — 已暫停」；14:42:35 display 回到 1，仍維持鎖定與暫停；14:42:41.560 解鎖，14:42:41.793（0.23 秒）兩個宿主皆恢復「Live metrics」且 MetricsTick 前進。鎖定期間 MetricsTick 沒有前進。宿主沒有重建。紀錄中沒有其餘 4 次鎖定，已向使用者確認 | 第 1 次 PASS（附帶驗證：鎖定中真實關屏再亮起）；S3 目前 1/5 次，未完成 |
| S3 真實鎖定／解鎖（第 2～5 次） | 14:47:12～14:49:24 | 回報：補做 4 次，每次都約 1 秒內恢復。另口述 10-30 曾以舊版本完成一輪 5 次，該輪沒有同步觀測，版本也不同，只作參考，不計入 | OS 紀錄有 4 次鎖定：13.5 s、15.9 s、38.1 s（期間真實 display 轉為 0 再回到 1）、25.7 s。鎖定期間兩個宿主皆為「locked／display-off — 已暫停」，MetricsTick 不前進。解鎖後兩個宿主恢復「Live metrics」且 MetricsTick 前進，分別在 250、593、390、2016 ms 內完成。宿主 HWND 與 LoadEpoch 不變 | PASS |
| **S3 小結** | | trial.8 上有同步紀錄的真實鎖定／解鎖共 5 次 | 恢復時間 0.23～2.0 秒。其中 2 次在鎖定期間真實關屏再亮起，也正確暫停並恢復 | **PASS（5/5）** |
