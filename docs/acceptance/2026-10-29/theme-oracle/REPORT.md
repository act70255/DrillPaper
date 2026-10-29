# 主題負面測試判斷驗證

測試腳本原先把「預期拒絕卻被接受」的 throw 放在 validator 拒絕例外的同一個 try/catch，因而吞掉自己的失敗斷言。

實際實驗只複製 scripts 與 SDK 到 GUID 暫存目錄，移除隔離 validator 副本的單一路徑檢查；主 repository 的正式 validator 雜湊與內容未修改。這是測試判斷的變異驗證，不是放寬產品規則。

- 修正前：隔離測試退出碼 0，`traversal.dmt` 被標為 PASS，變異存活。見 `before/summary.json` 與 `before/stdout.txt`。
- 修正後：隔離測試在 `traversal.dmt` 退出碼 1，變異被抓到；外層檢查同時確認合法案例先通過，避免把組件缺失等其他失敗誤當成功。見 `after/`。
- 正式 validator 回歸：合法包與 SDK 範例通過；路徑穿越、重複大小寫、不允許副檔名、API 不符、單檔超額均由 validator 本身拒絕。

```powershell
powershell -NoProfile -File scripts/test-theme-negative-oracle.ps1
powershell -NoProfile -File scripts/test-theme-package.ps1
```

這使封裝負面回歸有能力抓到規則退化，不取代原生 `.dmt` 測試或瀏覽器安全整合。後者仍以 STATUS 的實際範圍為準。
