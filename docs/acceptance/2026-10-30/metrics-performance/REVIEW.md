# RC 06 兩軸審查

依 implement 要求使用 code-review 技能。固定基準 `c244682204bc3a85b50cd46e15bc50e066eea3b7`；本票規定完成後只提交一次，因此審查當下 HEAD 仍是基準，採 `git diff c244682 --`（新增工具先 `git add -N`）檢查工作樹，未用空的 three-dot diff 冒充完成審查。`git log c244682..HEAD --oneline` 當時為空。

Standards／Spec 由兩個獨立 sub-agent 平行唯讀審查，不操作正在量測的程序，不另執行測試。規範來源是 AGENTS.md、使用者開發規範、handoff 及架構；Spec 來源是 RC-06 ticket／rc-delivery spec。量測結果文件完成後須再複查。

## Standards

初審3項，已修正：

1. 入口拒絕既有證據目錄後 finally 仍可能覆寫 result.json。新增 `createdSession`，僅本次成功建立的目錄可寫結果。入口回歸先 Red，再 Green；另發現 CP950 console 輸出，固定 UTF-8。見 tools-red／tools-red-overwrite／tools-green.log。
2. 不完整程序樣本仍參與記憶體／handles／threads 趨勢，會把漏讀視為下降。改排除 `complete=false`，記排除數與有效資源跨度。Red 的錯誤斜率 -1MiB/min，修正後對已知完整資料為 +2MiB/min；見 analysis-red7／green7.log。
3. GPU PID 篩選含尚未核實的 selected。採樣器依成功讀值、持有實體 handle 且尚未退出的程序篩選；分析器再次拒絕原始樣本以外 PID。已知樣本原誤算93%，修正後3%；見 analysis-red9／green9.log。

工具複查：未解決阻擋0。另低優先防禦建議為清理與結果寫入加獨立錯誤處理，已補友善提示／best-effort證據與非零退出，不強制終止任何程序。原始資料不被分析器修改，summary／CSV是可重算衍生檔。

## Spec

初審3項，已修正：

1. 不完整資源統計掩蓋成長，修正同上。
2. 速率比較只檢查當前端點skew，會把前筆錯開的窗口誤當同期。原生probe補暖機端點skew，CPU／disk／network皆檢查雙端點。先Red（錯誤計入1筆）再Green（0筆），見 analysis-red8／green8.log。
3. GPU歸屬未核實，修正同上。

工具複查：未解決0。另確認文件區分設定間隔、推送／JS觀察頻率與實際collector呼叫未觀測；Dashboard有效主題由逐宿主caption／visible／播放狀態判定，不能用切題前保存的settings.theme推論。原長測早期runner差異保留並由最終分析器逐筆核對。

## 最終結果複查

Standards結案複查：未解決0。五組摘要／結果、664筆、90硬體窗口、退出及原桌布資料與報告一致；保留缺失、記憶體上升、非獨占環境與NOT RUN，沒有誇稱無洩漏、NVIDIA實讀或完整省電驗收。繪圖及原生探針符合繁中／UTF-8／Google docstring與友善錯誤規範。

Spec結案複查：未解決0。1805.80秒長測、四組逾600秒、3筆資源／6個CPU區間排除、33個已核實子程序退出與90個同期窗口均與證據一致；工具版本／頻率限制、A05／A13 PARTIAL、人工清單及08／09交接完整，原桌布及防毒fingerprint一致。

兩軸皆只讀，沒有重跑測試或操作程序。本次審查不是RC放行；最終總數Standards0、Spec0。
