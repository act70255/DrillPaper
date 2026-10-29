# Windows 相容性矩陣

只有完成 GUI 證據的組態才能標為支援。

2026-10-29 最新續驗：a241856 已由使用者與原生觀測確認真正 Explorer 重啟後桌布恢復且持續更新，A04 在本機 Dashboard／no-smart-sleep 情境 PASS。圖示／工作列／Alt+Tab／焦點完整檢查仍待驗。見 [shell-readiness/REPORT.md](acceptance/2026-10-29/shell-readiness/REPORT.md)。

## 已決定的首版目標範圍（尚未驗收）

- Windows 10/11 x64；可從已連接螢幕中勾選套用目標，每個目標各顯示一份完整的同一主題，未選螢幕保留 Windows 桌布。跨螢幕拼接／延展不納入本版。
- 使用者於 2026-10-29 明確將多螢幕支援列為必要完整性功能，需先調查／補齊實作，再做實機驗收；不只是一項待測相容性，也不是補充選配。分類與待具體化範圍見 [剩餘工作](REMAINING_WORK.md)。
- GPU 指標以選配的 NVIDIA NVML 為首版實作範圍；其他 GPU 的核心體驗仍須運作，未支援指標回報 `unavailable`。
- 規格範圍不代表相容性驗收。多螢幕、混合 DPI、熱插拔與 Windows 11 都必須實際測試後才能標記支援。

| 作業系統/build | 架構 | 顯示器 | 桌面附掛 | Preview | Explorer 復原 | 證據 |
| --- | --- | ---: | --- | --- | --- | --- |
| Windows 10 Pro 19045 | x64 | 單一測試環境；多螢幕未測 | NOT RUN | PARTIAL | NOT RUN | Release app 編譯、CLI 與 WebView2 protocol smoke 通過；無視覺檢查；沒有 Shell attach/Explorer recovery 結果 |
| Windows 11 Pro 25H2 26200.8737 | x64 | 3840×1080 桌布層；顯示配置整體未驗證 | PARTIAL（原生附掛／5 次受控重掛通過） | PARTIAL（基本操作與鎖定恢復人工通過） | PASS（a241856 本機 Dashboard／no-smart-sleep） | CTest 29/29、SDK 18/18；使用者與原生觀測確認真實重啟後桌布恢復且持續更新，見 acceptance/2026-10-29/shell-readiness/REPORT.md；完整桌面互動、硬體精度、display-off／多螢幕仍待驗 |
