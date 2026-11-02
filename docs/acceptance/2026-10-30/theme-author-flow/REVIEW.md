# RC 07 兩軸審查

使用 `code-review` skill。固定點 `1636972a570431a0feaa9070978b2503441aa3b9`；因使用者要求本票最後單次 commit，審查的是 `git diff <base>` 工作樹，新檔透過 `git add -N` 納入，當時 commit list 為空。Standards 與 Spec 由兩個獨立子代理平行執行，未修改檔案。

## Standards

初審 2 項需修正，smell 判斷 0：

- `scripts/test-sdk-package.ps1`：新增 USERPROFILE 檢查與目錄建立位於 try 外，且入口沒有友善 catch。違反通用 AGENTS「fail-fast 放錯誤處理範圍、顯示友善提示而非 traceback」。
- `scripts/test-theme-author-flow.ps1`：退出前先觀測子程序，觀測失敗可能阻斷正式退出並漏釋放已取得 handle。違反 handoff 的安全關閉／資源釋放要求。

主代理修正後，子代理複查：**未解決 finding 0，smell 判斷 0**。SDK 必填設定／目錄檢查進入友善錯誤處理；子程序觀測失敗不再阻止正式退出，持有 handle 由 finally 釋放。缺 USERPROFILE 負面入口、正常整合及受控 CIM 觀測失敗證據與修正一致；觀測失敗仍標 CLEANUP_FAILED，app 正式退出碼 0。

補驗：`sdk-missing-profile.log`（exit1、無原始堆疊）；`sdk-zip-review-test.log`（相關 ZIP 測試 PASS）；`cleanup-review/result.json`（正常整合／清理 PASS）；`cleanup-observation-fault/result.json`（只在清理查詢受控模擬 OS CIM 不可用，工具 exit1／CLEANUP_FAILED，app／launcher正式exit0，不宣稱子程序完整觀測）。收尾另以真實 CIM 確認該隔離 profile 無殘留。未加入產品測試開關。

## Spec

**0 項需修正**。固定 compiler 正負驗證、乾淨 SDK ZIP 作者流程、正式工具打包、Preview／雙目標協定與 DOM、禁止 TS／宣告匯入及指定安全邊界有對應證據，未見範圍擴張。GUI 確認、人工版面及其他環境依法記 NOT RUN，A10 PARTIAL／RC gate 保留，符合使用者例外決策。

兩軸最終未解決 finding 各 0；完整套件留 09，沒有以審查替代人工或 RC。
