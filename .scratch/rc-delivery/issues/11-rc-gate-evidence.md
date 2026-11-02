# 補齊 RC 必要實機、環境與 CI 證據

Status: resolved
Type: task
Owner: James（發行維護者）
Blocked by: 10 及必要驗證環境

## Scope

承接 09-G1～G6；不是公開發布授權。09 完成可執行回歸及拒絕放行判定，不等於本票必要證據已具備。

## Acceptance

- 依 `docs/acceptance/2026-10-30/rc-regression/GATES.md` 與 `MANUAL_CHECKLIST.md`，逐項固定版本／環境／命令／證據、owner／下一步；其他版本的 PASS 不代替候選重測。
- 對 feature 分支取得精確 SHA 的 Windows configure／build／實際測試數／app artifact，及 gate 拒絕時無正式 RC artifact 的證據；skipped 不當 PASS，不合併 main、不建立 release／tag。
- 在合適機器補真正桌面／Explorer／電源／多目標拔插、完整安全、NVIDIA／長期效能與獨立作者 GUI；Explorer 操作另行授權，不關閉原持續桌布。
- 補真正乾淨無工具一般使用者、缺 Runtime／CRT、更新／回復／移除與資料保留／主動清除；不變更現用機防毒或依賴，每次攔截記錄並列 BLOCKED。
- 09-D2 修正回歸及所有必要 gate 通過後才重新做 RC 判定；03／08-D1／09-D2 原始 FAIL 永久保留。試用包不是正式 RC。

## Comments

- 2026-11-02 結案（決策（使用者確認））：本輪可執行範圍與報告已完成，總結見 `docs/acceptance/2026-11-02/rc-gate-evidence/REPORT.md`。G1 CI PASS；G2 互動實機大部分 PASS（S6 與 S10 為 PARTIAL，S4、S5、S12 依決策 NOT RUN）；09-D2 交錯流程 PASS；G4 效能 PASS（資料完整性 PARTIAL）；G3、G6 的部分項目為 NOT RUN 或 BLOCKED，NVIDIA 與獨立作者為 BLOCKED。**RC 判定：使用者以發行維護者身分決定有條件放行**，接受報告中的已知限制清單；不建立 tag／release、不發布，`package.ps1` 的正式 RC blocker 沒有修改。剩餘項目與改善建議轉由票 16 追蹤。另記：2026-11-02 使用者決定經 PR #1（merge commit 62b89b8）把票 01～10、12～15 合併至 main；合併不等於發布。

- 2026-11-02 效能收尾（僅分析既有證據）：trial.8 正式 100 次雙目標切換失敗 0，平均 7.0157 秒／中位數 7.1727 秒／p95 7.6997 秒／最慢 8.3072 秒；200 筆資源完整，Private Bytes 前後 +40.5781 MiB（非穩態切換，不套用長測門檻）。soak 實際 `--management --preview --no-smart-sleep`、兩個 Minimal 宿主／兩個 renderer，最終 535 筆、3149.0732 秒（52 分 29 秒；約 51 分鐘決定收尾後仍有落盤資料，與前條 521 筆中途值不同）。依使用者確認 30 分鐘門檻及 06 容差記效能 PASS：Private Bytes 首末 300 秒中位數 280.8711→287.5039 MiB（+6.6328），OLS +0.126741 MiB/min；handles 3784→3786（+2）、threads 189→187（-2）；CPU 平均 0.297195%、p95 0.548208%（14 核）。資料完整性 PARTIAL：1 筆短命程序漏讀，排除該筆資源及相鄰 2 個 CPU 區間；已核實 8 程序組成變化 0，不代表捕捉全部短命程序。同期 OS 皆 unlocked/on。約 51 分鐘提早收尾、preview／禁智慧休眠及有限觀測限制明列，不宣稱無洩漏；Claude 的 taskkill /T 是收尾操作失誤而非產品崩潰，長測正式退出／正常清理 NOT RUN。NVIDIA BLOCKED、真實節能及其他硬體／Runtime NOT RUN，其他 gate 與 Status 不變。報告、每 10 分鐘中位數、06 對照、原始 ZIP 與逐檔 SHA-256 見 `docs/acceptance/2026-11-02/rc-gate-evidence/performance/REPORT.md`；離線分析測試 12/12 PASS，未啟動產品實測、未修改產品。本次依指定分支單次 commit／push，不合併 main、不建 release／tag。

- 2026-11-02 決策（使用者確認）：使用者看過中途數據後，同意若資源變化不大，就把長測門檻降為 30 分鐘並提早收尾。Claude 在約 51 分鐘時計算的中途數據（521 筆、程序組成 0 變化）如下，皆符合 06 判準：Private Bytes 末 5 分鐘減首 5 分鐘中位數 +5.32 MiB（≤32）、OLS 斜率 0.119 MiB/min（≤1）、handles 3784→3786、threads 189→186（≤10）、CPU 平均 0.296%、p95 0.549%（14 邏輯核）。100 次切換 failures=0。收尾時 Claude 用 `taskkill /T` 停止 Codex，連帶強制終止了長測腳本、Node 啟動器與測試程式 PID 57672，沒有先送正式結束命令（kManageExit）。這是收尾操作失誤，不是產品崩潰；收尾後 DrillPaper 與該設定檔的 WebView2 子程序都是 0，Apex One `AEGIS_BM.log` 未變。長測是 `--management --preview --no-smart-sleep` 模式（Codex 為隔離前景覆蓋所設），報告須明寫。長測的正式退出不計入本次證據，標 NOT RUN。

- 2026-11-02 決策（使用者確認）：產品尚未發布，不處理跨版「更新／回復（升級、降版）」情境，記為不適用本輪（NOT RUN）。本輪只再執行效能項：在本機對 trial.8 候選版做 100 次主題切換與約 2 小時 soak，追蹤記憶體趨勢（09-G4），交由 Codex。移除／資料保留與主動清除、安全剩餘矩陣（09-G3）本輪不執行，記為 NOT RUN（使用者決策）。

- 2026-11-02 決策（使用者確認）：目前沒有乾淨一般使用者機器或 VM，09-G6 的乾淨環境、缺 WebView2 Runtime／VC++ CRT 驗證標 BLOCKED（缺乾淨環境），附人工清單待有機器再補；不在現用機移除依賴。NVIDIA 實讀（本機只有 Intel 內顯）與獨立主題作者（沒有第二位作者）也標 BLOCKED，留待有硬體或人力時再補。

- 2026-11-02 決策（使用者確認）：票 10 交接的「真實螢幕關閉時以產品預設啟動，螢幕恢復後是否握手」需在未鎖定狀態下人為關屏，與 S4 同屬人為繞行情境，使用者決定略過；記為 NOT RUN，本輪不列為完成驗收的條件。交接的第 (2) 項（鎖定、關屏往返後雙目標恢復）已由 S3 的 5 次真實鎖定、其中 2 次真實關屏取得證據；手動暫停與真實鎖定交錯已由 S13 驗證為 PASS；待機沒有執行（使用者決策略過）。

- 2026-11-02 決策（使用者確認）：使用者授權並自行執行 1 次真實 Explorer 重啟（PASS，約 3.8 秒恢復雙目標），認為 1 次已足夠，不補做人工清單要求的第 2、3 次；記為 PARTIAL（1/3）。

- 2026-11-02 S6 發現（使用者接受為已知限制）：單一螢幕被全螢幕視窗覆蓋時，智慧休眠的 `obscured` 會讓所有宿主一起暫停並隱藏 WebView2，沒被覆蓋的螢幕也會露出 Windows 原桌布；與 handoff 第 213 行「對應顯示器被全螢幕程式遮蔽」的逐顯示器政策不一致。使用者表示可以接受，記為 PARTIAL／已知限制；是否另開票改為逐顯示器判斷待使用者決定。

- 2026-11-02 決策（使用者確認）：待機／喚醒情境使用者平常用不到，記為 NOT RUN 並註記，本輪不列為完成驗收的條件。

- 2026-11-02 決策（使用者確認）：「未鎖定狀態下人為強制關屏／開屏至少 5 次」屬人為繞行情境，使用者的實際使用情境不會遇到；記為 NOT RUN 並註記，本輪不列為完成驗收的條件。鎖定期間的真實關屏恢復已在 S3 取得 2 次證據（見 `docs/acceptance/2026-11-02/rc-gate-evidence/INTERACTIVE.md`）。

- 2026-11-02 決策（使用者確認）：GitHub 只允許對預設分支已有的 workflow 使用 `workflow_dispatch`，而 `trial.yml` 尚未在 main，故在本分支為 `trial.yml` 加上 `push: branches: ['feature/rc-*']`，未指定版本時用 `0.1.0-trial.ci.<run_number>`；手動觸發保留。不合併 main。互動實機測試一次只指示使用者一項動作，等使用者回報後才進行下一項。

- 2026-11-02 決策（使用者確認）：本票分三段進行，分支 `feature/rc-11-gate-evidence`（base `f735510`，含 12～15 與 10）。(1) 自動：Claude 對本分支觸發既有 `windows.yml`（含 `build_release_candidate=true`，驗證 gate 拒絕時無 RC artifact）與 `trial.yml`，核對精確 SHA／測試數／app artifact；可自動化的效能與安全項交給 Codex。(2) 互動實機：需要人手或真實 OS 事件的項目由使用者在本機一步一步操作；每步前 Claude 先啟動只讀觀測（console display state、工作階段鎖定、各宿主 MetricsTick／HealthTick 等），使用者回報後由 Claude 驗證記錄、判定 PASS／FAIL／BLOCKED 並更新報告與票，每步完成即 commit＋push。(3) 需額外資源：Explorer 真正重啟須使用者當次另行授權；乾淨機器／VM、NVIDIA、獨立作者若無資源則標 BLOCKED／NOT RUN 並註明原因。不合併 main、不建立 release／tag、不修改防毒、不關閉／替換原持續桌布。

- 2026-11-02 10 交接：09-D2 已記「未重現，疑似環境」並結案（證據 docs/acceptance/2026-11-02/controlled-resume*/）。本票需補真實 OS 證據：(1) 真實螢幕關閉（console display off）時以產品預設（智慧休眠開啟）啟動，螢幕恢復後是否完成 WebView2 握手並更新；(2) 真正鎖定／解鎖、關屏、待機往返後雙目標恢復推送，含手動暫停交錯。皆需同步記錄 console display state 與工作階段鎖定狀態。

- 2026-10-30：09 查得最新 CI 40849189915 為舊 main `b4616ec`，CTest33／SDK18 通過、RC job skipped，artifact 只有兩個 SDK .dmt 範例，不是目前產品來源的 app CI。最終來源 CI／乾淨使用者、真實 OS／硬體及人工證據缺口見 09 報告。下一步在 09 分支推送後依既有 workflow 查驗，不以本機綠燈取代缺證。
