# Issue tracker：本機 Markdown

本專案的議題與規格以 Markdown 檔案記錄於 `.scratch/`。

## 慣例

- 每個功能使用一個目錄：`.scratch/<feature-slug>/`
- 規格檔為 `.scratch/<feature-slug>/spec.md`
- 每張實作 issue 各自存成 `.scratch/<feature-slug>/issues/<NN>-<slug>.md`；從 `01` 開始編號，不合併成單一 tickets 檔案
- 每個 issue 檔案開頭附近以 `Status:` 記錄 triage 狀態；角色名稱見 `triage-labels.md`
- 在檔案底部以 `## Comments` 區段追加留言與討論紀錄

## 技能要求「發布到 issue tracker」時

在 `.scratch/<feature-slug>/` 建立新檔案；必要時一併建立目錄。

## 技能要求「取得相關 ticket」時

讀取引用的檔案路徑。使用者通常會直接提供路徑或 issue 編號。

## Wayfinding 工作流程

供 `/wayfinder` 使用。**地圖**是每張 ticket 各有一個子檔案的文件。

- **地圖**：`.scratch/<effort>/map.md`，內容包含 Notes、Decisions-so-far 與 Fog。
- **子 ticket**：`.scratch/<effort>/issues/NN-<slug>.md`，從 `01` 開始編號，問題寫在本文。以 `Type:` 記錄 ticket 類型（`research`／`prototype`／`grilling`／`task`），以 `Status:` 記錄 `claimed`／`resolved`。
- **阻擋關係**：在檔案開頭附近使用 `Blocked by: NN, NN`。列出的檔案全部為 `resolved` 時，ticket 才解除阻擋。
- **待處理項目**：掃描 `.scratch/<effort>/issues/`，找出狀態為 open、未被阻擋且尚未認領的檔案；優先處理編號最小者。
- **認領**：開始工作前先將 `Status:` 設為 `claimed` 並儲存。
- **解決**：在 `## Answer` 區段追加答案，將 `Status:` 設為 `resolved`，再把脈絡指標（gist + link）追加至 `map.md` 的 Decisions-so-far。
