# RC 08：工作樹兩軸審查

固定點 `676bb473efeca65614fddb40d98e3c88c302494b` 已解析且等於 HEAD，`git log <base>..HEAD --oneline` 為空。本票一次提交前審查 `git diff HEAD` 加全部 untracked 新增檔；不能用空的三點 commit diff 取代工作樹。兩軸由獨立唯讀子代理執行，沒有執行產品／測試。規範來源：使用者提供與 repository 的 AGENTS.md、handoff、ARCHITECTURE；需求來源：票08、spec的2026-10-30防毒決策及使用者本輪續作指示。無另一本CODING_STANDARDS／CONTRIBUTING／CLAUDE。

## Standards

初審兩項硬性問題：

1. PS入口已委派CMD，但缺CMD未列必要檔，可能成功返回而無法啟動。已補必填檢查，公開入口負面測試 `missing-cmd-red.log` → `missing-cmd-green.log`；最終包 `launcher-trial6.log` 通過。
2. 新交付工具在finally寫結果未捕捉證據失敗。已補 `EVIDENCE_FAILED`、保留原結果／詳細寫入錯誤的備援日誌及繁中stderr；依既有作者工具模式，語法檢查通過。沒有宣稱實際磁碟滿／ACL故障注入已跑，該項NOT RUN，避免在現用資料盤製造故障。

複查新增一項：CMD測試器的ReadLineAsync逾時錯誤字串讀取未完成Task.Result，可能破壞有界等待；已改成逾時立即throw、只有完成後才讀Result。代理再次唯讀確認修正，未解決0。未另列smell建議。

## Spec

初審一項P2：雙擊CMD失敗立即關窗，無法閱讀繁中提示／依賴網址，不符票08「fail-fast並顯示友善錯誤」。已補預設失敗pause、使用者按鍵後exit1，`-CheckOnly`仍非互動exit1。新增真CMD公開入口測試，以缺主題fixture驗證繁中錯誤／待輸入與退出碼；真正Red `cmd-message-red2.log` → `cmd-message-green.log`，最終包 `cmd-message-trial6.log`通過。最初`cmd-message-red.log`只是工具錯用UTF8解碼OEM輸出，不當產品Red。

因包內資產修正，保留trial.5的ZIP／metadata／原始測試及審查前報告，另產生trial.6。`package-delta-trial5-to6.json`證實只有PS／CMD／README三檔異動、其他52檔相同；同EXE與主題SDK hash沿用作者匯入移除證據合理，入口以新包重驗。Spec代理複查未解決0，無scope creep。人工／真正乾淨機器NOT RUN、刪除被工具政策BLOCKED與08-D1／原FAIL均明列，不把候選包當RC。

保存Preview後新宿主的額外ready／JS回應等待另由兩軸唯讀複查；代理補提宿主總數與記錄同一HWND的精度建議亦採納並唯讀確認；最終unique-ready兩輪PASS、四次exit0與24個當下核實WebView2退出。原兩次trial.6的CIM→handle競態失敗永久保留，不改成PASS、不當08-D1。最終整合結果及適用範圍以REPORT與原始result為準。

審查統計：Standards初審2＋複查新增1，皆修正，未解決0；Spec初審1，已修正，未解決0。唯一commit依commit-msg技能在最終暫存差異產生，不合併main／不公開發布。
