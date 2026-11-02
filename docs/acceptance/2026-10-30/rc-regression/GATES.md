# RC 拒絕放行追蹤

本票完成的是整合回歸與放行判定。必要證據不足時結果為 **拒絕放行**；不合併 main、不建立 tag／release、不公開發布。歷史 FAIL 不改寫。後續每個 gate 須在明確版本與環境補證後才重新判定。

| ID／影響 | 目前結果與依據 | Owner | 下一步 |
| --- | --- | --- | --- |
| 09-G1／A14 | NOT RUN：最終來源及候選包無相符乾淨 Windows CI；查得最新 run 40849189915 是舊 main b4616ec，RC job skipped、只有 SDK 範例 artifact | James（CI／發行維護者） | push 本票後對 feature 分支觸發既有 Windows／trial workflow，核對精確 SHA、依賴還原、建置、實際測試數及 app artifact；另驗正式 gate 失敗無 RC artifact。不得合併 main 或建 release／tag |
| 09-G2／A03、A04、A08 | PARTIAL／NOT RUN：候選原生幾何與受控回復不等於新版真正桌面／Explorer／電源／拔插 | James（Windows 實機驗證） | 依人工清單於合適測試機補真實事件及人眼結果；Explorer 操作另行授權，原持續桌布保持不動 |
| 09-D2／A08，必要 FAIL | trial.7 雙目標擴充回歸：受控鎖定往返後解除手動暫停，兩宿主在原期限內沒有新 MetricsTick，標題仍 display-off／已暫停；原因未定 | James（原生 runtime／測試維護） | 見追蹤票 10；先收實際 OS 電源與有效手動／省電狀態、管理命令及通知時間線，區分產品／工具／環境，再補可重現回歸與最小修正；不放寬期限 |
| 09-G3／A12 | PARTIAL：指定安全與零 SmartScreen POST 不涵蓋完整 DNS、TURN、proxy、handler、其他 Runtime 與真實舊 COM 競態 | James（安全驗證） | 補接收端／正向控制及其他 Runtime 的版本化矩陣；保留 WPAD／Edge ECS 背景流量限制，不宣稱沙箱或全程序零外連 |
| 09-G4／A05、A13 | PARTIAL／NOT RUN：06 有有限長測及同期硬體資料，仍有 3 筆資源缺失、Private Bytes 上升；候選長期／真實節能及 NVIDIA 不足 | James（硬體／效能驗證） | 補 NVIDIA、真實 Locked／DisplayOff、高流量／介面消失、逐次採集、100 次切題與更長 soak；沿用原容差並記缺失，不宣稱無洩漏 |
| 09-G5／A02、A10、A11 | PARTIAL：SDK／CLI／受控原生操作不等於獨立作者、人手 GUI 及各目標完整像素版面 | James（主題／GUI 驗收） | 由獨立作者及人工依清單完成 MockHost、選檔／確認／取消／重匯入、縮放及完整主題畫面 |
| 09-G6／A14 | NOT RUN：真正乾淨無工具帳號、真實缺依賴、更新／回復、實際移除及主動資料清除缺證；08 原移除政策 BLOCKED 保留 | James（交付驗證） | 在獨立乾淨 Windows／可還原 VM 驗套件自足與資料保留／備份／回復；不在現用機刪依賴或原桌布資料 |
| 09-D1／08-D1 殘留風險 | 歷史 FAIL 保留；本機產品預設三輪不等待新 Preview 就緒的退出情境未重現，未做產品根因修正 | James（後續回歸維護） | 繼續保留 15 秒退出 gate；再現時先收精確時間線／程序及防毒證據並補 Red→Green，不以稍後 exit 0 覆蓋失敗 |

09-D1 的未重現不是根因結案；繞行移除僅依票 08 已確認的本機多輪條件。trial.6 保留不變，trial.7 仍只供受限試用；新 09-D2 FAIL 及 09-G1～G6 缺證持續阻止 RC。剩餘證據統一追蹤於票 11，不因 09 resolved 自動解除。
