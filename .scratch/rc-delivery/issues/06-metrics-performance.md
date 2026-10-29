# 硬體讀值與效能省電

Status: open
Type: task
原討論編號：5
Blocked by: 05

## Scope

補 A05／A13 的硬體精度、NVIDIA／NVML、長期資源與省電對照；涵蓋多目標增加的 WebView2 成本，維持採集／runtime／renderer 分離、有界佇列及低頻更新。

## Acceptance

- 先定義比較工具、採樣窗口、容差與負載；CPU、RAM、網路及磁碟的單位／精度以同期系統參考交叉檢查，不能對不同時間點數字硬判一致。
- NVIDIA 可用環境驗證 NVML 實讀及缺失／權限／裝置消失等錯誤；無設備時記 NOT RUN，既有 unavailable 契約不代表 NVIDIA 實讀通過，不以 0 掩蓋失敗。
- 比較 Minimal／Dashboard、單目標／多目標、運作／暫停／鎖定／真正關屏等狀態；記錄 app 與已確認 WebView2 程序的 CPU、記憶體、handles／threads、GPU engine／活動及採樣頻率。
- 依 handoff 效能目標事先記錄時長／暖機／取樣方式與判定門檻；保留時間序列、環境及版本，不以單一瞬間或舊 30 分鐘紀錄宣稱新版本無洩漏。
- 量測過程不自行喚醒螢幕而改變待測狀態；無法觀察的項目附限制。採集故障不阻塞 UI，不破壞 bounded／latest-wins 行為。
- 發現回歸先補失敗行為測試或可重現性能案例，再修正及重測相應對照；硬體受限與未達門檻傳遞 08／09。

## Comments

- 2026-10-29：既有 343 筆／1804.606 秒觀測保留，不當作未做過長測；本票要求的新版本與對照矩陣 NOT RUN。
