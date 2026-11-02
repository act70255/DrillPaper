# 切換工具修正紀錄

第一輪一次性工具錯把 LoadEpoch 與 ReadyEpoch 視為相同計數器。src/web/webview2_host.cpp 的 Subscribe 分支獨立遞增 nextReady，LoadEpoch 則是載入世代；前置觀測已顯示 load=6/7、ready=1/2。第一輪單次 Dashboard 切換在錯誤條件下逾時，不能當作產品缺陷或正式 100 次切換的失敗次數。原腳本、命令、JSONL、診斷及正常退出證據保留於 tooling-first-run 與 run-switches.ps1。

run-switches-v2.ps1 分別要求每宿主 load > 前值、ready > 前值、HealthTick > 前值，主題正確且可見／已附掛，再觀察 MetricsTick 相對新世代首次值繼續前進。等待上限仍是原定 20 秒。這是公開 seam 的正確解讀，不變更產品、不放寬效能容差。REQUEST.md 所寫「新 load=ready」是本工具錯誤假設，以上述分別前進條件更正。

首次產生腳本前，字串模板因 PowerShell 插值造成 IndexOf 起點為負而失敗；當時未啟動產品、未產出腳本。switch-template.ps1 記錄後續成功的生成模板。
