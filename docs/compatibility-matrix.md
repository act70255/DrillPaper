# Windows 相容性矩陣

只有完成 GUI 證據的組態才能標為支援。

## 已決定的首版目標範圍（尚未驗收）

- Windows 10/11 x64；桌布目標涵蓋所有已連接螢幕。
- GPU 指標以選配的 NVIDIA NVML 為首版實作範圍；其他 GPU 的核心體驗仍須運作，未支援指標回報 `unavailable`。
- 規格範圍不代表相容性驗收。多螢幕、混合 DPI、熱插拔與 Windows 11 都必須實際測試後才能標記支援。

| 作業系統/build | 架構 | 顯示器 | 桌面附掛 | Preview | Explorer 復原 | 證據 |
| --- | --- | ---: | --- | --- | --- | --- |
| Windows 10 Pro 19045 | x64 | 單一測試環境；多螢幕未測 | NOT RUN | PARTIAL | NOT RUN | Release app 編譯、CLI 與 WebView2 protocol smoke 通過；無視覺檢查；沒有 Shell attach/Explorer recovery 結果 |
| Windows 11 Pro 25H2 26200.8737 | x64 | 顯示配置整體未驗證 | NOT RUN | PARTIAL（基本操作人工通過） | NOT RUN | 2026-10-28 Release build、CTest 22/22、SDK 18/18 及封裝工具通過；Dashboard mock 文字／數值、Minimal 實機數值／時間更新、Minimal 縮放與正常關閉均由使用者確認。Dashboard 個別版面、硬體精度及其他整合仍待驗證。見 acceptance/2026-10-28/REPORT.md |
