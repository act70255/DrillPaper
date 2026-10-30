# 雙目標受控鎖定往返後解除手動暫停未恢復推送

Status: open
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

- 2026-10-30 09 交接：trial.7 EXE SHA `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`，產品來源 `676bb473efeca65614fddb40d98e3c88c302494b`；Windows 11 26200.8737／WebView2 156.0.4314.50、雙 1920×1080 DPI144／96。`test-multi-monitor.ps1 -DesktopPowerRecovery` 到 smart-sleep-enabled 及 manual-pause-survives-controlled-lock 已記錄；再傳管理 20002，16:09:44.853+08 以「宿主沒有繼續推送新的指標」失敗，兩目標 MetricsTick 均 1580423640、HealthTick 1580423843，標題仍 display-off／已暫停。沒有實際 OS 電源事件的同步證據，不能認定根因或冒充真實鎖定驗收。
- 原日誌、phases／failure、命令及退出紀錄見 `docs/acceptance/2026-10-30/rc-regression/`。可讀 Apex One BM 日誌當時 hash 與 before 相同，觀測不完整，不推定無防毒介入或把未知原因標 BLOCKED。後續尚未到達的擴充故障／無限迴圈／父視窗案例 NOT RUN；基本矩陣另記結果，不覆蓋此 FAIL。
