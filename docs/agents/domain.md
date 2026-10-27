# Domain 文件

說明工程技能探索程式碼時，如何使用本專案的 domain 文件。

## 探索前先讀取

- 根目錄的 **`GLOSSARY.md`**，或
- 若根目錄存在 **`GLOSSARY-MAP.md`**，讀取它指向各 context 的 `GLOSSARY.md`，並閱讀與目前主題相關的文件。
- **`docs/adr/`**：閱讀與目前工作區域相關的 ADR。多 context 專案也要檢查 `src/<context>/docs/adr/` 中的 context 專屬決策。

若上述檔案不存在，直接繼續，不需特別指出，也不要預先建議新增。`/domain-modeling` 技能會在實際確認術語或決策時才建立這些文件。

## 檔案布局

單一 context 專案（多數專案適用）：

```text
/
├── GLOSSARY.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多 context 專案（根目錄有 `GLOSSARY-MAP.md`）：

```text
/
├── GLOSSARY-MAP.md
├── docs/adr/                          ← 全系統決策
└── src/
    ├── ordering/
    │   ├── GLOSSARY.md
    │   └── docs/adr/                  ← context 專屬決策
    └── billing/
        ├── GLOSSARY.md
        └── docs/adr/
```

## 使用 glossary 中的詞彙

在 issue 標題、重構提案、假設或測試名稱中提及 domain 概念時，使用 `GLOSSARY.md` 定義的術語。不要改用 glossary 明確排除的同義詞。

若需要的概念尚未列入 glossary，請確認是否使用了專案實際採用的詞彙；若詞彙確有缺口，記錄此情況，交由 `/domain-modeling` 處理。

## 標示與 ADR 的衝突

若輸出內容與既有 ADR 矛盾，請明確指出，不要默默覆寫。例如：

> _與 ADR-0007（event-sourced orders）相衝突；但值得重新討論，因為……_
