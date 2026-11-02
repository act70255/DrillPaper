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
| S4 未鎖定下關屏／開屏 5 次 | — | 使用者決策：這是人為強制關屏的情境，使用者的實際使用不會遇到，可以註記，但本輪不列為完成驗收的條件 | 未執行，沒有送出任何關屏訊息。現有相關證據：S3 第 1、4 次在鎖定期間真實 console display 轉為 0 再回到 1，宿主正確暫停並在解鎖後 0.23／0.39 秒恢復 | NOT RUN（使用者決策略過，不列入本輪驗收條件） |
| S5 待機／喚醒 | — | 使用者決策：平常用不到待機／喚醒情境，略過 | 未執行 | NOT RUN（使用者決策略過，不列入本輪驗收條件） |
| S6 單一螢幕全螢幕覆蓋 | 15:00～15:10 | 回報：主螢幕瀏覽器 F11 全螢幕並取得焦點時，沒被覆蓋的 DELL 螢幕桌布也會消失；退出後正常。使用者表示可以接受此情境 | 全螢幕或焦點期間，智慧休眠判定 `obscured`，**兩個**宿主同時進入「已暫停」，包含沒被覆蓋的 DELL（DPI 96）宿主。暫停時 WebView2 controller 會隱藏（`put_IsVisible(FALSE)`），因此 DELL 露出 Windows 原桌布。每次退出全螢幕或焦點移開後 2～20 秒內兩者都恢復「Live metrics」。HWND 全程 visible=true，LoadEpoch 不變，沒有重建。15:07～15:08 另有一次使用者自行鎖定，期間真實關屏，解鎖後 0.2 秒恢復，也是 PASS | **PARTIAL（已知限制，使用者接受）**：與 handoff「`Obscured`：對應顯示器被全螢幕程式遮蔽」的逐顯示器政策不一致，目前是全域暫停；暫停與恢復本身正確 |
| S7 實體拔插 DELL 螢幕 | 15:25:55～15:26:07 | 回報：拔掉時主螢幕正常；接回後 DELL 約 6 秒恢復 | 15:25:55.9 DELL 宿主 462336 移除，只剩主螢幕宿主 265396（DPI 144），維持「Live metrics」且沒有重建。屬部分斷線，只顯示仍連接的已選目標，沒有補到其他螢幕。15:26:04.3 接回後建立新宿主 131518（DPI 96），經「正在載入主題」「恢復中」，於 15:26:07.3 轉為「Live metrics」，宿主建立後約 3 秒完成。隔離 `settings.json` 最後修改時間仍為 14:20:35，拔插期間沒有改寫保存的目標 | PASS |
| S8-1 GUI 匯入主題 | 15:30:43 | 回報：在管理視窗選擇 `RC11 測試主題.dmt` 匯入成功，清單出現「RC11 測試主題」，沒有錯誤 | 測試主題由 SDK `dashboard` 範例複製並改 id 為 `rc11-test-theme`、名稱為「RC11 測試主題」，以 `scripts/package-theme.ps1` 封裝（7591 bytes，SHA-256 `2C3287D1DBB11E18F471473C8BA9BDC6A63CCA41948A659AEFFF8775DC32173E`），放在非 Temp 目錄。匯入後隔離資料出現 `themes\rc11-test-theme@1.0.0\`，含 index.html、main.js、style.css、theme.json、desktop-monitor-sdk.js、mock-host.js，時間 15:30:43 | PASS |
| 觀察：拔插時的列舉退化 | （推定 S7 期間） | — | `management.log` 僅有一行「螢幕列舉暫時失敗，保留可用結果：無法取得螢幕 DPI，未套用錯誤縮放。」，符合票 12 的保留上次結果行為，宿主沒有中斷。日誌每行沒有時間戳記，只能依內容推定是 S7 拔插瞬間；事後對照不便，列為改善建議 | 觀察（非驗收項） |
| S8-2 切換到匯入主題 | 15:32:03～15:32:05 | 回報：兩個螢幕都換成新主題，完整沒有裁切，數字有更新 | 15:32:03.7 兩個宿主依序重新載入（LoadEpoch 12／13，HWND 不變），15:32:04.9 標題轉為「RC11 測試主題 — 恢復中」，15:32:05.8 兩者轉為「RC11 測試主題 — Live metrics」，約 2 秒完成。15:32:04 保存 `settings.json`，`theme=rc11-test-theme@1.0.0`。之後 MetricsTick 持續前進 | PASS |
| S8-3 移除使用中主題（含取消） | 15:33:34～15:33:35 | 回報：確認視窗按「取消」後主題仍在；再按確認後從清單消失；桌布換回 Minimal，沒有黑屏 | 取消時宿主與設定都沒有變動。確認移除後，隔離 `themes\` 目錄已沒有 `rc11-test-theme@1.0.0`；15:33:34.7 保存 `settings.json`，`theme=minimal`。兩個宿主重新載入（LoadEpoch 14／15，HWND 不變），15:33:35.6 轉為「Minimal Monitor — Live metrics」，不到 1 秒 | PASS |
| S8-4 重新匯入同一主題 | 15:34:48 | 回報：重新匯入成功，清單再次出現，沒有錯誤 | 隔離 `themes\rc11-test-theme@1.0.0\` 於 15:34:48～49 重新建立，檔案齊全。保存的主題仍為 `minimal`，兩個宿主沒有被重新載入（LoadEpoch 14／15 不變），持續「Live metrics」 | PASS |
| **S8 小結** | | 匯入、切換、取消／確認移除、重新匯入 | 全部經由真實 GUI 與檔案選擇對話框完成，隔離資料與宿主狀態一致 | **PASS** |
| S9 關閉管理視窗與系統匣叫回 | 15:36～15:38 | 回報：按 X 後桌布繼續顯示；從系統匣點開只有一個管理視窗，再點也沒有開出第二個 | 檢查時仍只有原程序 PID 62112（沒有多開或重啟），只有一個 `DrillPaperManagementWindow`（HWND 659890，檢查當下已隱藏），另有系統匣通知與電源事件的隱藏視窗各一。兩個桌布宿主持續「Live metrics」 | PASS |
| S10 真實 Explorer 重啟（第 1 次，使用者授權並自行操作） | 15:39:09～15:39:13 | 回報：經工作管理員重新啟動 Windows 檔案總管後，工作列與圖示都回來，桌布也恢復 | 新 explorer PID 54808 建立於 15:39:09。15:39:09.8 舊宿主隨 WorkerW 消失（n=0）；15:39:10.1～10.3 在新桌面層重建兩個宿主（HWND 201186 DPI 144、197204 DPI 96，LoadEpoch 16／17），15:39:12.9 兩者轉為「Live metrics」，距 Explorer 啟動約 3.8 秒。DrillPaper 仍是原程序 PID 62112，沒有崩潰或重啟。15:39:15～15:39:28 短暫 `obscured`（推定為前景的工作管理員等視窗），之後恢復 | PASS（1/3） |
| **S10 小結** | | 使用者決策：真實 Explorer 重啟做 1 次就夠，不再補第 2、3 次 | 1 次真實重啟在約 3.8 秒內恢復雙目標，程序沒有中斷 | **PARTIAL（1/3，使用者決策不補做）** |
| S11 管理視窗跨 DPI 移動 | 15:43 | 回報：拖到 DELL（100%）大小正常、文字清楚；拖回主螢幕（150%）也正常 | 拖回主螢幕後，以 per-monitor 感知方式量測，用戶區為 1200×900 px、DPI 144，等於 800×600 DIP，可見。DELL 上的實體尺寸沒有在當下量測，由使用者目視確認；同版本 CTest「Management client stays 800 by 600 logical pixels on connected monitors」已在兩個螢幕以原生方式驗證 | PASS |
| S12 螢幕關閉時啟動（票 10 交接） | — | 使用者決策：此情境需要在未鎖定狀態下人為關屏，與 S4 同屬人為繞行情境，略過 | 未執行 | NOT RUN（使用者決策略過，不列入本輪驗收條件） |
| S13 手動暫停與真實鎖定交錯（09-D2 流程） | 15:44:49～15:45:29 | 回報：解鎖後維持暫停；按「繼續」後兩個螢幕都恢復更新 | 15:44:49 第一次手動暫停，15:44:59 繼續（使用者先試按一次）。15:45:02.9 再次手動暫停，兩個宿主 MetricsTick 停在 20035765。15:45:05.6 真實鎖定，15:45:24.8 解鎖，解鎖後仍維持暫停，MetricsTick 不變。15:45:29.7 按「繼續」後兩個宿主轉為「Live metrics」且 MetricsTick 前進。手動暫停優先於自動恢復，符合系統匣票 01 政策；09-D2 的同類流程在真實事件下沒有重現 | PASS |
| 觀察：手動暫停的標題文字 | — | — | 手動暫停時宿主標題顯示「display-off — 已暫停」，而非「手動暫停」。這是 `ManagedPlayback::EffectiveState` 在 paused 時回傳 DisplayOff 的既有設計（票 10 已記錄），行為正確，但標題用語容易和真實關屏混淆，列為改善建議 | 觀察（非驗收項） |
