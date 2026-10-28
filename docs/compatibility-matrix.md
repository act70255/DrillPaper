# Windows 相容性矩陣

只有完成 GUI 證據的組態才能標為支援。

## 已決定的首版目標範圍（尚未驗收）

- Windows 10/11 x64；桌布目標涵蓋所有已連接螢幕。
- GPU 指標以選配的 NVIDIA NVML 為首版實作範圍；其他 GPU 的核心體驗仍須運作，未支援指標回報 `unavailable`。
- 規格範圍不代表相容性驗收。多螢幕、混合 DPI、熱插拔與 Windows 11 都必須實際測試後才能標記支援。

| 作業系統/build | 架構 | 顯示器 | 桌面附掛 | Preview | Explorer 復原 | 證據 |
| --- | --- | ---: | --- | --- | --- | --- |
| Windows 10 Pro 19045 | x64 | 單一測試環境；多螢幕未測 | NOT RUN | PARTIAL | NOT RUN | Release app 編譯、CLI 與 WebView2 protocol smoke 通過；無視覺檢查；沒有 Shell attach/Explorer recovery 結果 |
| Windows 11 | x64 | 全連接螢幕（目標；未測） | NOT RUN | NOT RUN | NOT RUN | 沒有 Windows 11 測試環境 |
