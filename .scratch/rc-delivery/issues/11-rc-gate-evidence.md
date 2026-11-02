# 補齊 RC 必要實機、環境與 CI 證據

Status: open
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

- 2026-11-02 決策（使用者確認）：待機／喚醒情境使用者平常用不到，記為 NOT RUN 並註記，本輪不列為完成驗收的條件。

- 2026-11-02 決策（使用者確認）：「未鎖定狀態下人為強制關屏／開屏至少 5 次」屬人為繞行情境，使用者的實際使用情境不會遇到；記為 NOT RUN 並註記，本輪不列為完成驗收的條件。鎖定期間的真實關屏恢復已在 S3 取得 2 次證據（見 `docs/acceptance/2026-11-02/rc-gate-evidence/INTERACTIVE.md`）。

- 2026-11-02 決策（使用者確認）：GitHub 只允許對預設分支已有的 workflow 使用 `workflow_dispatch`，而 `trial.yml` 尚未在 main，故在本分支為 `trial.yml` 加上 `push: branches: ['feature/rc-*']`，未指定版本時用 `0.1.0-trial.ci.<run_number>`；手動觸發保留。不合併 main。互動實機測試一次只指示使用者一項動作，等使用者回報後才進行下一項。

- 2026-11-02 決策（使用者確認）：本票分三段進行，分支 `feature/rc-11-gate-evidence`（base `f735510`，含 12～15 與 10）。(1) 自動：Claude 對本分支觸發既有 `windows.yml`（含 `build_release_candidate=true`，驗證 gate 拒絕時無 RC artifact）與 `trial.yml`，核對精確 SHA／測試數／app artifact；可自動化的效能與安全項交給 Codex。(2) 互動實機：需要人手或真實 OS 事件的項目由使用者在本機一步一步操作；每步前 Claude 先啟動只讀觀測（console display state、工作階段鎖定、各宿主 MetricsTick／HealthTick 等），使用者回報後由 Claude 驗證記錄、判定 PASS／FAIL／BLOCKED 並更新報告與票，每步完成即 commit＋push。(3) 需額外資源：Explorer 真正重啟須使用者當次另行授權；乾淨機器／VM、NVIDIA、獨立作者若無資源則標 BLOCKED／NOT RUN 並註明原因。不合併 main、不建立 release／tag、不修改防毒、不關閉／替換原持續桌布。

- 2026-11-02 10 交接：09-D2 已記「未重現，疑似環境」並結案（證據 docs/acceptance/2026-11-02/controlled-resume*/）。本票需補真實 OS 證據：(1) 真實螢幕關閉（console display off）時以產品預設（智慧休眠開啟）啟動，螢幕恢復後是否完成 WebView2 握手並更新；(2) 真正鎖定／解鎖、關屏、待機往返後雙目標恢復推送，含手動暫停交錯。皆需同步記錄 console display state 與工作階段鎖定狀態。

- 2026-10-30：09 查得最新 CI 40849189915 為舊 main `b4616ec`，CTest33／SDK18 通過、RC job skipped，artifact 只有兩個 SDK .dmt 範例，不是目前產品來源的 app CI。最終來源 CI／乾淨使用者、真實 OS／硬體及人工證據缺口見 09 報告。下一步在 09 分支推送後依既有 workflow 查驗，不以本機綠燈取代缺證。
