# RC 09 兩軸審查

固定基準 `d60816aff6e99ad1a3624075a74016909f76fa4d`。使用者要求本票最後唯一 commit，審查時 `git log d60816a..HEAD` 為空；審查差異為 `git diff --cached d60816a --`，收尾複查亦讀 `git diff HEAD` 及新具名證據。依 implement 明確要求的 code-review 技能，兩個僅讀子代理平行審查 Standards／Spec，沒有執行產品、測試、修改或提交。

## Standards

初審硬性違規1項（P2）：`scripts/test-theme-cli.ps1` 新必填 USERPROFILE 檢查及目錄建立在入口 try 之前；缺設定／路徑不可寫會直接拋出錯誤，違反開發指引「fail-fast 檢查要放在程式入口既有的錯誤處理範圍內」及友善提示／詳細日誌要求。Smell baseline 0項。

修正：初始化移入 try；測試與清理錯誤均保留詳細日誌、顯示繁中提示並非零退出。公開入口先用PS啟動後移除USERPROFILE，取得實際腳本Red，再Green；斷言stderr沒有CategoryInfo等原始堆疊、詳細日誌實際記錄缺設定原因。最初在PS宿主啟動前清空USERPROFILE造成宿主失敗的日誌保留，但不當腳本Red。

代理另補充新 EvidenceDirectory 可重用既有資料的疑慮：安全入口新增存在即拒絕、友善catch與日誌；公開sentinel保留測試Red→Green。沒有放寬原安全斷言，正常新目錄安全矩陣另重驗。

複查：CLI初始化已納入入口處理、詳細日誌／繁中提示／非零退出完整，安全入口拒絕既有證據，兩項公開入口測試充分；**未解決0、無額外實質問題**。

## Spec

初審1項（P2）：Acceptance要求「最終來源執行Release configure／build、完整scripts/test.ps1」；原15:50完整輪之後變更了SDK封裝包含的安全文件，不能當最終暫存內容的完整證據。

修正：原輪保留為開發完整基線；審查修正收斂，凍結程式與SDK封裝輸入後，在16:39:34～16:42:41實際再跑公開封裝鏈。最終Release configure／build、CTest43/43（38.96秒）、SDK四組18/18、新工具6/6、各完整腳本均通過，SDK重封SHA `E44D5CC58EEB8FC3B6C1C6C37B9942119F55FA9988C5BD241B20FD1EFE98ED19`；正式gate預期exit1且無ZIP。REPORT對應final證據，原基線不覆寫。

複查：原P2缺口已解決；新增證據目錄拒覆寫處理沒有放寬原斷言，無新增Spec finding。**未解決0**。既有09-D2 FAIL、人工／CI缺證與拒絕放行並非待推測性修正的程式finding，按使用者授權保留並追蹤。

Standards：初1項P2、最終未解決0（另1項入口疑慮已修正、smell0）；Spec：初1項P2、最終未解決0。兩軸分開，不以任一軸抵銷另一軸或產品gate。
