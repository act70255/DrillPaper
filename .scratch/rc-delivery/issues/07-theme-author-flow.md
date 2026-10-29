# 第三方主題作者完整流程

Status: open
Type: task
原討論編號：6
Blocked by: 06

## Scope

補 A10 的 TypeScript compiler 與第三方作者端到端流程；從文件／SDK 開始建立新主題，編譯為離線靜態資產、打包 .dmt、匯入並於 Preview／多目標桌布運作。作者建置工具不成為一般使用者的 app runtime 依賴。

## Acceptance

- 在乾淨作者目錄依文件取得 SDK／宣告／範例，以明確版本 TypeScript compiler 編譯，驗證正確用法與預期型別錯誤；不能以 Node 測試通過取代編譯驗證。
- 使用作者自行產出的靜態檔與 manifest 經正式工具打包、驗證、GUI 匯入／確認，無需開發來源樹或放寬匯入副檔名政策。
- 在 Preview 與每個已選目標收到版本化握手、mock／實際 metrics，正確顯示 unavailable／單位／更新；同一主題能在不同目標完整排版。
- 覆蓋 API 版本不相容、非法套件、切換／重新匯入／移除及必要錯誤提示；第三方內容不能執行原生管理命令或繞過網路政策。
- 對 SDK／protocol 缺陷先 TDD 再修正；更新會阻擋作者完成流程的文件，保存 compiler 命令／版本、樣本來源與套件 hash、實機結果及 NOT RUN。
- SDK ZIP 與作者工具驗證結果獨立記錄，不替代 app 的 08 交付與 09 RC。

## Comments

- 2026-10-29：既有 SDK 18/18 與 ZIP 還原證據保留，本票 compiler／完整作者實測 NOT RUN。
