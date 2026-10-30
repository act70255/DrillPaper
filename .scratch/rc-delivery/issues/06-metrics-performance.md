# 硬體讀值與效能省電

Status: resolved
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

- 2026-10-30 完成可執行驗證／報告：產品來源 `c244682`、EXE `25316B…6D26D`，沒有修改產品src/include。新增原生精度探針、非Temp／Node直接啟動的循序程序樹量測、分析與圖表工具；兩軸審查修正證據覆寫、缺失樣本／GPU歸屬與錯開窗口，分析及入口回歸Red→Green，相關CTest18/18＋螢幕1/1、工具12/12、語法／建置PASS。完整證據、命令、工具版本差異、原始失敗與圖表見 `docs/acceptance/2026-10-30/metrics-performance/REPORT.md`。
- 實測：Minimal單目標1805.80秒／282筆；Dashboard單目標603.49／95、Minimal雙目標602.01／92、Dashboard雙目標603.59／97、Dashboard雙目標暫停603.81／98。Active CPU平均0.178～0.324%、p95<=0.528%，達預定門檻；長測Private Bytes中位數+14.17MiB／斜率+0.569MiB/min，仍有上升，不宣稱無洩漏。暫停CPU平均0.0372%，較同主題雙目標Active下降86.82%，推送／JS觀察變化皆0、有效GPU engine全0。三組共3筆缺失資源／6個無效CPU區間已排除，資料完整性PARTIAL；不是偽造零資源。
- 硬體：三種負載各30同期窗口，CPU／RAM／disk counter／實體網路自然流量均達預定容差，最大雙端點skew23.99ms，NVIDIA 90筆unavailable/null不算NVML實讀PASS。五次正式退出均0，33個已觀察核實子程序退出。原持續桌布path／精確建立時間／hash未變、收尾唯一app；未重啟Explorer。Apex One可讀日誌fingerprint未變，未觀察新增攔截，非完整防毒觀測。
- 傳遞08／09：A05／A13仍PARTIAL；真正鎖定／關屏／睡眠／全螢幕、NVIDIA實讀與錯誤、網路高流量／介面消失、實際collector逐次呼叫頻率、其他OS／Runtime／硬體、100次熱切換／更長soak及探針獨立因果增量均NOT RUN，原因與操作清單見 `MANUAL_CHECKLIST.md`。本票resolved僅表示可執行範圍與交接完成，不解除03歷史FAIL或RC gate。完成時更新STATUS，commit-msg產生繁中訊息後本票一次commit並push本分支，無合併／公開發布。

- 2026-10-30 執行前定義：base `c244682`，從目前 HEAD 建 `feature/rc-06-metrics-performance`；05 resolved，硬體／runtime 公開 seam 與原生整合沿用。純驗證未發現回歸不虛構 Red；若回歸成立才補失敗案例並最小修正。本票單次 commit＋push，完整套件留 09。
- 量測計畫：隔離非 Temp 使用者繁中／空白副本、Node 直接啟動，原持續桌布只核對 path／建立時間／hash。循序執行 Minimal 單目標 Active 1800 秒、Dashboard 單目標 Active 600 秒、Minimal 雙目標 Active 600 秒、Dashboard 雙目標 Active 600 秒、Dashboard 雙目標手動暫停 600 秒；每組先暖機 60 秒，CSV 首末單調時間跨度達門檻才完成。Active 固定關閉智慧休眠以隔離前景覆蓋，記錄有效政策，手動暫停使用正式管理命令；不冒充真正鎖定／關屏。每 5 秒保存已驗證程序身分、CPU 累積時間、Private Bytes／WS、handles／threads、GPU engine 計數器、各宿主 MetricsTick／HealthTick／load／ready／caption；程序變動區間 CPU 不作有效差值，不把缺失當 0。單一連續實例至少 1800 秒 memory trend。
- 預定判準：Active 合計 CPU 平均 <= 1%、p95 <= 3%（整機邏輯 CPU 容量）；1800 秒 Minimal 的末 300 秒／首 300 秒 Private Bytes 中位數差 <= 32 MiB，OLS 成長 <= 1 MiB/min，handles／threads 中位數增量各 <= 10；超出先調查，不以此保證無洩漏。Active 每宿主 MetricsTick 觀測速率 0.7～1.2 Hz、JS 回應 0.12～0.25 Hz，epoch 不變；手動暫停暖機後兩者不前進且所有宿主已暫停，CPU 平均應低於同主題雙目標 Active（GPU 只提供可取得的對照，並非功率量測）。不同版本健康探針的獨立因果增量 NOT RUN，本票只量測含探針版本的總成本。
- 硬體精度方法／容差（先定義）：Windows 公開 collector，1 秒同期窗口，基線／單執行緒 CPU 負載／64 MiB 記憶體＋本機檔案寫入各 30 個區間。CPU 以 PDH Processor(_Total) % Processor Time 比較、平均絕對差 <= 5 百分點；RAM 以 GetPerformanceInfo physical pages 比較、total <= 1 page、used 平均絕對差 <= 64 MiB；磁碟以獨立 PDH PhysicalDisk(_Total) % Disk Time query 比較、平均絕對差 <= 5 百分點；網路以各硬體介面的 GetIfEntry2 octets／單調時間差比較，平均絕對差 <= max(64 KiB/s, 參考平均的 10%)。記錄每次 collector／參考讀取的時間偏差；>100 ms 的區間不硬判精度。網路沒有可控實體 peer 時僅驗自然流量，飽和／高流量與拔線另列 NOT RUN。同 counter 不等於獨立儀器校準，disk 是 counter 契約比較而非工作管理員 Active Time。NVIDIA 缺設備、真正 OS／人工項附清單，不中斷。
- 量測前技術細化：資源原始檔採 JSONL（保留逐程序、GPU engine 與宿主狀態），分析另輸出 CSV。MetricsTick／HealthTick 是最後成功推送／JS 回應時間戳，以 100 ms 觀察變化次數，不把毫秒時間差當次數；前述 Hz 門檻指觀察到的推送／JS 回應，與實際 collector 呼叫分列。設定的 Active worker 間隔 1000 ms、手動暫停 0；app 沒有公開逐次 collector 計數，實際呼叫頻率直接觀測 NOT RUN，公開 SamplingWorker／故障／bounded 契約另跑相關測試。速率精度比較要求窗口兩端皆 <=100 ms，暖機端點也記 skew；不能取得足夠同期窗口時記 PARTIAL，不放寬容差。缺失樣本排除並明列數量，不將其資源合計當成下降。

- 2026-10-29：既有 343 筆／1804.606 秒觀測保留，不當作未做過長測；本票要求的新版本與對照矩陣 NOT RUN。
