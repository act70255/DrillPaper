# 票 11／09-G4 效能既有證據收尾

**效能門檻 PASS（依使用者確認的 30 分鐘門檻與 06 容差）；資料完整性 PARTIAL；長測正式退出 NOT RUN。** 本輪只分析既有資料，沒有啟動產品實測、修改產品程式或重判 RC。票 11 `Status: open` 保持不變，其他必要 gate 仍未完成。

## 決策、版本與來源

票 11 最新「決策（使用者確認）」授權將長測門檻降至 1800 秒，約 51 分鐘時提早收尾。收尾時 Claude 執行 `taskkill /T` 停止 Codex，連帶強制終止長測腳本、Node 啟動器及測試程式 PID 57672；這是收尾操作失誤，**不是產品崩潰**。沒有先送正式結束命令 `kManageExit`，正式退出／正常子程序清理不計入證據，標 **NOT RUN**。使用者回報收尾後產品及該 profile 子程序為 0，只是強制終止後的狀態，不能當作正常清理 PASS。

原 [REQUEST.md](REQUEST.md) 的 7200 秒及原 [switch-summary.json](switches/switch-summary.json) 中的舊文字是執行歷史；本次依最新確認決策收尾，見 [分析需求](REQUEST-analysis-20261102.md)。沒有達成兩小時長測，也沒有補跑。

- 工作分支 `feature/rc-11-gate-evidence`，本輪開始 HEAD `23ba5efce199136c5bbfc87efbb2d58b379bcfcb`。
- 候選 trial.8，產品來源 `ae1c5e05e5562cd0297bcf22abf2e06b3749836f`。ZIP SHA-256 `63A98B5B20F23F9470C2EFEA2DDBC0311ED2EE03EDFFC95AA0021221D73ACD53`，EXE SHA-256 `7444C1D946F9AF31B2C3EE37D8B12DB3F3BBEBE67F9707ACE16B338C20131C52`。沿用 [session.json](session.json) 與 [archive-verification.log](archive-verification.log) 的先前驗證，本輪不重啟或重包。
- 原始根目錄 `%USERPROFILE%\DrillPaperTests\RC11 效能 20261102-160037\`，正式切換為 `switches-formal/`，長測為 `soak/samples.jsonl`，同期 OS 證據為 `os-state.jsonl`。
- 環境依 [environment.json](environment.json)：Windows 11 專業版 26200、Core Ultra 7 155U、14 邏輯處理器、Intel Graphics 32.0.101.8860；原始程序路徑顯示實際 WebView2 Runtime **156.0.4314.58**。Node 24.17.0、PowerShell 7.6.3。不是獨占或乾淨測試機。

Nowledge MCP `thread_search` 以 `RC11 效能 30 分鐘 51 taskkill` 搜尋，定位前輪 `codex-01a19b43-8d3c-7022-ad4d-17d473c6fa4b` 與 06 `codex-01a18adc-ca7f-7ba2-87b9-01db0ee602d3`；只用於定位，判定依本票決策與原始檔，不以舊摘要代替最終樣本。

## 方法與長測模式限制

長測實際啟動參數為 **`--management --preview --no-smart-sleep`**，由原始 `soak/launch-7ac20600a9774ce984d90e7fc01c11b2.json` 證實。採 `MinimalMulti` 設定流程，所有 535 筆皆記錄 **兩個 Minimal Monitor 宿主、兩個 renderer**，不是單目標。腳本另選桌布模式及兩個目標，但 launch 保留 preview 旗標、raw caption 亦為 Preview；這是該特定組合的成本觀測，不能外推一般預設桌布、智慧休眠、前景遮蔽或實體畫面驗收。沒有重新執行設定驗證，缺失的收尾 metadata 不補造。

既有腳本設定暖機 60 秒；launch 16:25:18 到第一筆 16:26:40 的間隔包括設定與暖機，不當作正式樣本跨度。正式長度以 `samples.seconds` 首末差計算。完整資源樣本才納入 Private Bytes／Working Set／handles／threads；CPU 區間要求兩端完整、相同 PID＋建立時間且累積 CPU 非負。CPU = 各程序累積 CPU 秒差 ÷ 單調時間差 ÷ 14 × 100，平均採有效區間時間加權，p95 為區間值 nearest-rank；不是全機 CPU 或瓦數。

首末 300 秒窗口以全部原始序列首末時間定位，各取完整樣本中位數；OLS 使用全部完整資源樣本的 Private Bytes 對單調時間回歸，換算 MiB/min。每 10 分鐘中位數以第一筆為零點，採 `[起點, 終點)` 分箱，尾段不足 10 分鐘另列。沿用 06 分析函數，另逐程序獨立重算 CPU 並核對；沒有把不完整讀值補零。Working Set 相加可能重複共享頁，不等於獨占實體 RAM。

## 100 次主題切換

**PASS：正式 100 次、失敗 0 次**。雙目標 Minimal 起始，Dashboard／Minimal 交替，最後為 Minimal。每次分別核對 LoadEpoch 與 ReadyEpoch 前進、正確主題、可見／有 parent、新 HealthTick 及新世代後 MetricsTick 前進；沒有假設 LoadEpoch 等於 ReadyEpoch。等待上限 20 秒不變，獨立逐筆複核不符 0。

| 耗時指標 | 秒 |
| --- | ---: |
| 最短 | 6.0765 |
| 平均 | 7.0157 |
| 中位數 | 7.1727 |
| p95 | 7.6997 |
| 最慢 | 8.3072 |

正式資源觀測 16:07:18.897～16:21:55.301（UTC+8），共 200 筆 before／after，皆完整、skipped 0，逐筆程序數均 8。重新核算的耗時與既有 `switch-summary.json` 相符，200 筆資源逐欄與 `switch-resources.csv` 相符，見 [切換分析](switch-analysis-20261102.json)。

| 合計資源 | 第 1 次前 | 第 100 次後 | 差值 |
| --- | ---: | ---: | ---: |
| Private Bytes MiB | 267.3242 | 307.9023 | +40.5781 |
| Working Set MiB | 519.5625 | 564.4219 | +44.8594 |
| Handles | 3750 | 3699 | -51 |
| Threads | 197 | 171 | -26 |

renderer 隨切題替換，因此這些是非穩態前後值，不把 +40.58 MiB 套入穩態長測的 +32 MiB 門檻，也不宣稱無洩漏。正式切換腳本記錄 `exitCode=0`、已觀察子程序 survivors 為空；此情境退出證據與被強制終止的 soak 分開，不外推所有取樣間短命程序均被追蹤。

早期 `switches/` 的一次逾時是工具把兩種 epoch 當同一計數器，完整保留於 ZIP，見 [TOOLING.md](TOOLING.md)。它不計入正式 100 次失敗數，也不當作產品缺陷；原始工具及修正版均保留。

## 長測：最終 535 筆，而非中途 521 筆

正式原始時間 2026-11-02 **16:26:40.721～17:19:09.815（UTC+8）**，單調時間跨度 **3149.0732 秒＝52 分 29.07 秒**。約 51 分鐘時決定收尾後，落盤資料仍有增加；本報告用全部最終 535 筆，故與票中 521 筆／+5.32 MiB／0.119 MiB/min 中途值不同。這是同一輪的最終重算，不是補跑或新增產品實測；約 51 分鐘提早收尾的決策仍保留，並未觀測兩小時。

| 06 判準（本次長度採使用者決策） | 最終觀測 | 判定 |
| --- | ---: | --- |
| 原始跨度 ≥1800 秒 | 3149.0732 秒 | PASS |
| Private Bytes 末／首 300 秒中位數差 ≤32 MiB | 280.8711→287.5039，+6.6328 MiB | PASS |
| Private Bytes OLS ≤1 MiB/min | +0.126741 MiB/min | PASS |
| Handles 首末窗口中位數增量 ≤10 | 3784→3786，+2 | PASS |
| Threads 首末窗口中位數增量 ≤10 | 189→187，-2 | PASS |
| CPU 時間加權平均 ≤1% | 0.297195% | PASS |
| CPU 區間 p95 ≤3% | 0.548208% | PASS |

Private Bytes 平均 284.8026 MiB，Working Set 平均 497.4221 MiB；首末單筆 Private Bytes 275.0547→291.5742 MiB，與窗口中位數有別。每宿主 MetricsTick 觀察頻率皆 0.979018 Hz，HealthTick 為 0.198789／0.198471 Hz，符合 06 的 0.7～1.2／0.12～0.25 Hz；所有已記錄主題、雙宿主、visible、各自固定 load／ready 均符合，未以兩個 epoch 相等作條件。這是原生屬性觀測，不代表逐次 collector API 呼叫或人眼畫面。

資料品質為 **PARTIAL**：535 筆全部可解析，534 筆完整。16:33:48.726（單調時間 429.1639 秒）列舉後無法讀取短命 PID 65640，原始錯誤意義為「找不到該程序識別碼的程序」，保留英文 raw；排除該筆資源及相鄰 2 個 CPU 區間，剩 **532 個有效 CPU 區間**。首末窗口各 51 筆完整資源。平均樣本間隔 5.8971 秒、最大 6.2838 秒，超過 10 秒間隔 0；沒有固定序號可證明取樣間完全無遺漏。

所有成功核實的快照均為同一組 **8 個程序、身分／角色／parent／path 組成變化 0**：app PID 57672、browser 64660、crashpad 67392、GPU process 51268、utility 60008／62524、renderer 64040／64832。未核實的短命 PID 另列，不能將「已核實組成不變」寫成從無任何短命程序。缺失不構成產品崩潰證據。

| 自首筆起的區間（分鐘） | 完整資源筆數 | Private Bytes 中位數 MiB | Working Set 中位數 MiB | Handles 中位數 | Threads 中位數 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0～10 | 101 | 279.9102 | 531.1484 | 3781 | 189 |
| 10～20 | 101 | 281.8359 | 533.5781 | 3774 | 187 |
| 20～30 | 102 | 292.2168 | 543.0859 | 3769.5 | 184 |
| 30～40 | 103 | 283.3008 | 451.9883 | 3764 | 183 |
| 40～50 | 101 | 284.9766 | 440.2070 | 3786 | 187 |
| 50～52.4846（不足 10 分鐘） | 26 | 289.6055 | 435.5820 | 3786 | 187 |

同期 [OS 分析](os-analysis-20261102.json) 含 23,429 筆，皆 unlocked／console display on，最大相鄰間隔 293 ms；535 個資源樣本對齊前一 OS 樣本最大落後 215 ms，無超過 1 秒或未知狀態。這只支持該觀測時段的 OS 狀態，不代表真實節能對照。Intel GPU engine 可歸屬 535 筆、未知 PID 實例 0，engine sum 平均 0.330746%；不是 NVIDIA 實讀、整卡使用率或功耗。

## 與 06 比較

對照 [06 REPORT](../../../2026-10-30/metrics-performance/REPORT.md) 及其原始 summary；06 產品 EXE 為 `25316B…D26D`、Runtime 156.0.4314.50，本輪為 trial.8／.58。同機但不同版本、Runtime、時長及背景活動，以下是描述性比較，不能宣稱效能改善的因果關係。

| 指標 | 06 Minimal 單目標長測 | 06 Minimal 雙目標短測 | 本輪 Minimal 雙目標 |
| --- | ---: | ---: | ---: |
| 跨度秒／原始筆數 | 1805.8009／282 | 602.0127／92 | 3149.0732／535 |
| 已核實程序數 | 7 | 8 | 8 |
| 缺失資源／排除 CPU 區間 | 1／2 | 1／2 | 1／2 |
| CPU 平均／p95 % | 0.177952／0.297583 | 0.324148／0.527093 | 0.297195／0.548208 |
| Private Bytes 平均 MiB | 234.1155 | 280.4252 | 284.8026 |
| 首末 300 秒中位數差 MiB | +14.1680 | +2.2715 | +6.6328 |
| OLS MiB/min | +0.568658 | +1.086109 | +0.126741 |
| Handles／threads 窗口增量 | -9／-4 | -19／-3 | +2／-2 |

06 的長測資源門檻原套於 1800 秒 Minimal 單目標，雙目標只有約 10 分鐘，不因其短測斜率 >1 就補判當年 FAIL。本輪依新決策將同一容差用於本次 30 分鐘以上雙目標觀測。兩次長測皆存在缺失資料、正斜率與有限時長；本輪只有約 52.5 分鐘，**不能宣稱無洩漏或長期成長有界**。

## 尚未執行與阻擋

- 長測正式管理退出／正常 WebView2 清理：**NOT RUN**，因收尾操作以 `taskkill /T` 強制終止，不重跑補證。
- 原計畫 7200 秒／兩小時 soak：**NOT RUN**，使用者確認降為 30 分鐘並提早收尾。
- 真實智慧休眠、鎖定／關屏／待機節能對照與瓦數：**NOT RUN**，本次固定 `--no-smart-sleep` 且只分析現存 Active 資料。06 手動暫停結果不代替真實 OS 節能。
- NVIDIA NVML 實讀與故障：**BLOCKED**，本機只有 Intel 內顯。
- 其他硬體／Windows／Runtime：**NOT RUN**，沒有相應環境與資料；乾淨一般使用者／缺 Runtime、CRT：**BLOCKED**，缺乾淨機或 VM。
- 其他安全、獨立作者 GUI、移除／資料清理與更新回復：本輪 **NOT RUN** 或沿用票中 **BLOCKED**／不適用決策，沒有重跑其他 gate、修改票 Status 或重判 RC。
- 產品 build、完整 CTest／SDK／型別檢查／CI、TDD：**NOT RUN**，本輪無產品或 SDK 變更，且使用者只授權既有資料分析。未虛構產品 Red；以下離線分析測試不當作產品實機驗收。

既有 Apex One 記錄：226 筆 periodic 指紋與 before／between 同為 41,998 bytes、SHA-256 `E395850C13B01016BAEFBB4CADFE7846032D34768953B97E9037F2FBB3765F81`，最後 periodic 為 17:20:04（UTC+8）。沒有觀察到此可讀日誌變化；不是完整防毒監控，也未推定強制終止由防毒造成。本輪沒有重新讀取或修改防毒設定。

## 封存、重算與驗證

[原始 ZIP](raw-evidence-20261102-final.zip) 共 **22 entries／1,009,439 bytes**，SHA-256 **`71B2E521875EB925CEA3E7B1E297BAFCA49B350892F853624B77BBAC96FB5D9D`**。包括原始 os-state、observer、正式切換、soak 與早期工具失敗資料，排除 appdata／WebView2 profile、candidate 二進位及 scratch 暫存。每個來源檔與 ZIP entry 的長度、SHA-256 逐一核對，詳見 [manifest](raw-evidence-20261102-final.manifest.json)。來源檔與本輪開始時 25 個 [既有頂層工作樹證據雜湊](existing-evidence-hashes-20261102.json) 均未改變。先前未提交的工具、REQUEST、console 與防毒檔原樣納入本次提交；不覆寫歷史結果。

衍生資料：[soak 摘要](soak-analysis-20261102.json)、[完整資源 CSV](soak-resources-20261102.csv)、[切換摘要](switch-analysis-20261102.json)、[OS 摘要](os-analysis-20261102.json)。缺少的 `soak/result.json`／exit.json 保持缺少，未合成收集完成或退出 PASS 的 metadata。

本輪離線執行命令（根目錄為 repository）：

```powershell
node docs/acceptance/2026-11-02/rc-gate-evidence/performance/analyze-existing-20261102.mjs "$env:USERPROFILE\DrillPaperTests\RC11 效能 20261102-160037" docs/acceptance/2026-11-02/rc-gate-evidence/performance
pwsh -NoProfile -File docs/acceptance/2026-11-02/rc-gate-evidence/performance/archive-existing-20261102.ps1 -SourceRoot "$env:USERPROFILE\DrillPaperTests\RC11 效能 20261102-160037" -OutputDirectory docs/acceptance/2026-11-02/rc-gate-evidence/performance
node --test tests/metrics-performance-analysis.test.mjs
node --check docs/acceptance/2026-11-02/rc-gate-evidence/performance/analyze-existing-20261102.mjs
git diff --cached --check
git diff --cached --check -- '*.md' '*.mjs' '*.ps1' '*.json' '*.jsonl' '*.csv'
```

分析／封存命令 exit 0；既有分析器相關測試 **12/12 PASS**（只含離線數據與拒絕既有目錄的入口檢查，未啟動產品）；新工具的 Node／PowerShell 語法與繁中錯誤路徑檢查 PASS，詳見 [錯誤路徑驗證](error-path-validation-20261102.json)。暫存全檔空白檢查在原始診斷日誌有檔尾空行告警，依不可覆寫證據要求保留；文件／工具／JSON／CSV 篩選檢查 PASS，不將全檔檢查寫為 PASS。封存工具初次 stdout 的 Select-Object 對 ordered dictionary 顯示 null，實際 manifest 已正確寫入；另以 ConvertFrom-Json 讀回並核對上列 archive／entries／hash，沒有把該顯示結果當封存證據。其後只修正顯示與錯誤提示，沒有重封 ZIP。重算工具採新檔排他建立，請先將原始 ZIP 解壓至新目錄並以另一個包含 environment.json 的新輸出目錄重算，避免覆寫。

本次依 implement／code-review 以開始 HEAD 對工作樹作 Standards／Spec 兩軸唯讀審查，結果見 [REVIEW](REVIEW-analysis-20261102.md)。票 Comments／docs/STATUS.md 同次更新；使用 commit-msg 依實際暫存差異產生繁中 Conventional Commit，僅 commit 一次並 push 本分支，實際 hash 以 Git 記錄為準。不合併 main、不建 release／tag。
