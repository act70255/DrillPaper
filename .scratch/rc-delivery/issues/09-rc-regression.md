# RC 整合回歸與放行判定

Status: open
Type: task
原討論編號：8
Blocked by: 01, 02, 03, 04, 05, 06, 07, 08

## Scope

對 08 提供的實際候選套件完成整體回歸與 A01～A16 判定；核對來源、CI、套件及各實機證據的版本一致性。判定可放行與實際公開發布分開，本票不授權自動發布或合併 main。

## Acceptance

- 核對 01～08 的 Status／Comments、遺留缺陷與不可測環境；未結問題有 owner／下一步與 gate 影響，不將 implemented／resolved 當作所有組態 PASS。
- 最終來源執行 Release configure／build、完整 scripts/test.ps1、CTest／SDK／封裝相關檢查；檢查測試確實被執行，記錄實際數量，不預設永遠是 33／18。
- 核對對應提交的乾淨 Windows CI，包含依賴還原、建置、測試及 app artifact；檢查 gate 失敗能阻止正式 RC，不能把 skipped 當 PASS。
- 對 08 的解壓套件執行整合冒煙與必要原生／人工回歸；03～08 的結果若產品版本不同，明示差異並重測受影響範圍。
- 更新 A01～A16、STATUS、FINAL_HANDOFF、相容性／安全與已知限制文件，將 PASS／FAIL／PARTIAL／NOT RUN／BLOCKED 對應到版本／環境／命令／證據。
- 必要功能與 gate 有 FAIL 或尚缺必要證據時明確拒絕放行並建立追蹤；先前試用包仍只能按限制試用，不以文件或 CI 綠燈取代實機證據。
- 所有必要 gate 通過時才記錄 RC 可交付判定、候選 commit／ZIP hash、限制與後續發布步驟。程序清理只針對已確認的測試實例，原持續桌布保持不動。

## Comments

- 2026-10-30 06傳遞：06 resolved只代表可執行矩陣與報告完成，非A05／A13全部PASS。五組664筆（3筆資源／6個CPU區間排除），長測1805.80秒、暫停相對同主題雙目標CPU下降86.82%；硬體三負載各30同期窗口達容差。NVIDIA、真正Locked／DisplayOff／睡眠／全螢幕、高流量／介面消失、逐次collector頻率、其他環境、更長soak／100次切題與探針因果增量仍NOT RUN，見 `docs/acceptance/2026-10-30/metrics-performance/REPORT.md` 與人工清單。只跑相關CTest18＋1及工具12；完整套件／CI／候選包仍由本票收尾。保留3筆缺失、記憶體上升及03歷史FAIL，不因06結案放行。

- 2026-10-30 03 傳遞：**預設智慧休眠啟動＝FAIL**，根因未定，05 負責失敗回歸／診斷／最小修正；08 必須移除 7A 的 `--no-smart-sleep` 繞行並以產品預設重包重驗。03 關閉智慧休眠的入口驗收只適用試用包，不代表產品預設或 RC gate 通過。核對 05／08 對應版本及新證據前持續列 gate，原失敗見 `docs/acceptance/2026-10-29/trial-package/REPORT.md`。
- 2026-10-29：首次打包不代表本票完成；完整回歸／CI／最終套件與放行判定 NOT RUN。
