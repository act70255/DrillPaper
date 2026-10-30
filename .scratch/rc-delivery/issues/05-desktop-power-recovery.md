# 桌面互動與電源復原

Status: open
Type: task
原討論編號：4
Blocked by: 04

## Scope

在多螢幕版本補 A03／A04／A08 的剩餘桌面、電源與故障交錯驗收，包含無回應 renderer；不將舊單螢幕 Explorer 人工 PASS 誤寫為未通過或已涵蓋新配置。

## Acceptance

- 先記錄螢幕／DPI／Windows 組態與有效智慧休眠政策；桌面圖示、工作列、Alt+Tab、焦點及虛擬桌面逐項檢查，桌布不搶焦點或留下多餘可切換視窗。
- 補多目標的混合 DPI／解析度與拔插；管理視窗固定大小不免除桌布幾何驗收，Windows／Runtime 未測配置明列 NOT RUN。
- 真正鎖定／解鎖、顯示器關閉、待機／喚醒、全螢幕與多螢幕部分覆蓋按既定政策驗證；受控訊息／暫停迴圈不得代替真正 OS 事件。
- 新版真正 Explorer 重啟後，各目標畫面與更新恢復、圖示／工作列可用，另以真正系統匣點擊確認管理入口與唯一視窗；人工結果與原生註冊證據分開。
- 無限迴圈／無回應、renderer／browser 故障與電源／Explorer 交錯，有界復原或友善退化；不能只以舊 metrics 標題宣稱畫面存活。
- 暫停／繼續與正式退出涵蓋所有宿主，觀測子程序建立時間／handle 避免 PID 重用誤殺；不關閉或替換原持續桌布。
- 修正先做可重現回歸，留下環境、時序、程序／畫面及退出證據；不可執行的真實事件附原因並傳遞至 RC gate。

## Comments

- 2026-10-29：舊 a241856 與新版 62f01ab 的特定 Explorer PASS 保留，本票針對新多螢幕與未覆蓋情境；新版本測試 NOT RUN。
- 2026-10-30 決策（使用者確認）：本票承接 03 發現的啟動缺陷——預設智慧休眠開啟時，`DrillPaper.exe --management --preview` 以全新隔離 LOCALAPPDATA 啟動 30 秒後 ReadyEpoch=0（未握手）；取消智慧休眠並套用後可握手，根因未定。證據見 docs/acceptance/2026-10-29/trial-package/REPORT.md 與 default-startup-failure.log。本票須先留下可重現的失敗回歸，再診斷根因並最小修正，智慧休眠產品預設維持開啟；修正後通知 08 讓試用／交付入口回到預設行為。
