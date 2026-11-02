# 雙目標受控鎖定往返後解除手動暫停未恢復推送

Status: in-progress
Type: bug
Owner: James（原生 runtime／測試維護）
Blocked by: 無；由 09 發現並交接，不在本輪推測性修改產品

## Scope

診斷 RC 09 的 09-D2。保留 FAIL 與必要 A08 gate，區分產品、測試工具與實際 OS 電源環境，不把標題推論成已知道根因。

## Acceptance

- 從 09 原始命令、trial.7 ZIP／EXE hash、Windows／Runtime／雙目標 DPI 與隔離資料重現；產品實測循序執行，原持續桌布與 Explorer 不動。
- 記錄手動暫停／恢復命令、受控 WTS 7／8 通知、實際電源／工作階段、各宿主有效政策、MetricsTick／HealthTick／世代與防毒時間線。
- 取得可重現失敗回歸後才最小修正；若是工具或環境因素同樣保留原 FAIL，證明新情境及原斷言等價，不放寬期限、不強迫喚醒真正螢幕。
- 重驗雙目標手動暫停、受控鎖定／恢復、renderer／browser 故障交錯、有界退化、無限迴圈；真正 OS 及人工矩陣仍需獨立證據。
- 產品變更須新版本重包，重驗產品預設啟動／保存 Preview／退出與受影響範圍；所有必要 gate 完成前拒絕 RC。

## Comments

- 2026-11-02 決策（使用者確認）：09:14～09:16 兩輪的 `display-off` 時段，使用者不確定當時螢幕是否關閉／鎖定。依使用者指示重試重現：重跑前與失敗當下以只讀方式同步記錄真實螢幕電源（console display state）與工作階段鎖定狀態，不強制喚醒螢幕、不改電源設定；原判準與期限不放寬。若螢幕實際開啟仍被判 `display-off`，或 `display-off` 下啟動未完成 WebView2 握手，記為獨立待診斷缺陷並先留可重現回歸，再依 TDD 處理；若根因牽涉暫停／鎖定／恢復優先權政策而無既有決策，停止並回報選項。

- 2026-11-02 同步OS重試，停止未提交：沿用指定分支／HEAD `40e007f`，全新非Temp使用者目錄，先trial.7（EXE993FD4…97DA，09:37～09:43），再成功建置目前HEAD Release（EXE8E8953…214A，09:44～09:50），兩輪原 `test-multi-monitor.ps1 -DesktopPowerRecovery` 均完整PASS／exit0。原鏈智慧休眠→手動暫停→受控WTS7／8→17秒→解除後新MetricsTick／HealthTick通過；renderer／browser交錯、8輪有界退化、JS無限迴圈約91.09／92.04秒退Minimal、父fixture／模式／離線暫用與各19個已觀察子程序退出均通過。不是原09-D2根因修復，歷史FAIL／A08 gate保留。
- 只讀觀測：獨立訂閱console display初始／後續通知及查詢WTS，09:36:47～09:50:20共5263筆，console全部on、session1全部active／unlocked；未喚醒／改電源／操作真實鎖定。手動暫停時的display-off為既有合成有效政策（系統匣票01已確認暫停優先），解除後恢復；未取得非手動暫停錯判或真實display-off啟動未握手的失敗。真實display-off啟動本輪NOT RUN，不能以on情境排除上一輪症狀。兩輪無failure.json，失敗當下擷取路徑未觸發。原09 Runtime為.50，本輪實際browser為.58，未切換、不歸因。
- 停止前提：本輪兩版本到達並通過原鏈，但未取得可重現失敗，依使用者前提規則不進入診斷／TDD修正、不commit／push；Status維持in-progress，不解除gate。原始證據／命令／hash／OS樣本與限制見全新[REPORT](../../../docs/acceptance/2026-11-02/controlled-resume-retry-093410/REPORT.md)，原目錄未覆寫。原桌布83428身分前後一致、收尾唯一app、隔離程序無殘留；Apex One可讀BM前中後指紋不變，沒有已證實攔截、不宣稱完整防毒觀測。產品由Node直接啟動、實測循序、未重啟Explorer。單元／全套／CI／新包／獨立交付矩陣／code-review／commit-msg均NOT RUN（未取得失敗且停止；全套留收尾）；後續原Runtime獨立環境與真正OS／畫面項見[人工清單](../../../docs/acceptance/2026-11-02/controlled-resume-retry-093410/MANUAL_CHECKLIST.md)。

- 2026-11-02 停止未提交：從指定HEAD `a3c183f` 建立 `feature/rc-10-controlled-resume-regression`。先核實09 trial.7 ZIP／EXE hash並用原 `test-multi-monitor.ps1 -DesktopPowerRecovery`，再成功建置目前HEAD Release並用新隔離副本循序執行。trial.7在開啟智慧休眠後第一個新指標斷言失敗（09:14:34、兩宿主display-off／已暫停、Tick／Health0）；HEAD在同段更早的握手等待失敗（09:16:25、display-off／低頻模式、Ready0、Tick／Health0）。兩者都尚未到達擴充段手動暫停／WTS往返，**沒有重現原09-D2觸發鏈**，依使用者前提不成立停止規則，不診斷、不改產品／測試／政策、不commit／push；Status維持in-progress。HEAD初次隔離副本漏WebView2Loader.dll造成匯入前退出3221225781，補齊DLL後以新目錄執行，原準備失敗另留證據。
- 本輪已安裝Runtime156.0.4314.58（09為.50），雙1920×1080／DPI144與96；非Temp使用者目錄／隔離資料、Node直接啟動。可讀Apex One日誌前中後41998bytes／11-01 09:42:36／SHA E39585…5F81不變，未觀察新增攔截非完整觀測，不推測防毒根因或把未知FAIL改BLOCKED。原桌布83428身分／hash不變，收尾唯一app、本票profile WebView2無殘留，未重啟Explorer或替換桌布。
- 需求、原命令／hash／原始失敗／退出／環境及續作選項見[REPORT](../../../docs/acceptance/2026-11-02/controlled-resume/REPORT.md)。下一步需確認在目前Runtime先補只讀同步OS電源／工作階段與有效政策觀測，或於原Runtime獨立環境重現；不改本機Runtime、不決定政策優先權、不解除09-D2／A08 gate。原鏈及後段故障／有界／無限迴圈、單元／完整套件／CI／重包／code-review／commit-msg皆NOT RUN（停止於前置失敗；全套另依指示留收尾），人工項見[清單](../../../docs/acceptance/2026-11-02/controlled-resume/MANUAL_CHECKLIST.md)。

- 2026-10-30 09 交接：trial.7 EXE SHA `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`，產品來源 `676bb473efeca65614fddb40d98e3c88c302494b`；Windows 11 26200.8737／WebView2 156.0.4314.50、雙 1920×1080 DPI144／96。`test-multi-monitor.ps1 -DesktopPowerRecovery` 到 smart-sleep-enabled 及 manual-pause-survives-controlled-lock 已記錄；再傳管理 20002，16:09:44.853+08 以「宿主沒有繼續推送新的指標」失敗，兩目標 MetricsTick 均 1580423640、HealthTick 1580423843，標題仍 display-off／已暫停。沒有實際 OS 電源事件的同步證據，不能認定根因或冒充真實鎖定驗收。
- 原日誌、phases／failure、命令及退出紀錄見 `docs/acceptance/2026-10-30/rc-regression/`。可讀 Apex One BM 日誌當時 hash 與 before 相同，觀測不完整，不推定無防毒介入或把未知原因標 BLOCKED。後續尚未到達的擴充故障／無限迴圈／父視窗案例 NOT RUN；基本矩陣另記結果，不覆蓋此 FAIL。
