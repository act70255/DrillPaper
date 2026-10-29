# Windows 相容性矩陣

只有完成 GUI 證據的組態才能標為支援。

2026-10-29 續驗：Windows 11 26200 的真正 Shell 附掛、3840×1080 用戶區及 5 次受控重掛已通過原生整合；桌面附掛狀態更新為 PARTIAL。真正 Explorer 重啟與圖示／工作列／焦點畫面仍 NOT RUN，見 [shell/REPORT.md](acceptance/2026-10-29/shell/REPORT.md)。下表先前 NOT RUN 為上一輪狀態，不表示本輪 GUI 已完成。

## 已決定的首版目標範圍（尚未驗收）

- Windows 10/11 x64；桌布目標涵蓋所有已連接螢幕。
- GPU 指標以選配的 NVIDIA NVML 為首版實作範圍；其他 GPU 的核心體驗仍須運作，未支援指標回報 `unavailable`。
- 規格範圍不代表相容性驗收。多螢幕、混合 DPI、熱插拔與 Windows 11 都必須實際測試後才能標記支援。

| 作業系統/build | 架構 | 顯示器 | 桌面附掛 | Preview | Explorer 復原 | 證據 |
| --- | --- | ---: | --- | --- | --- | --- |
| Windows 10 Pro 19045 | x64 | 單一測試環境；多螢幕未測 | NOT RUN | PARTIAL | NOT RUN | Release app 編譯、CLI 與 WebView2 protocol smoke 通過；無視覺檢查；沒有 Shell attach/Explorer recovery 結果 |
| Windows 11 Pro 25H2 26200.8737 | x64 | 顯示配置整體未驗證 | NOT RUN | PARTIAL（操作與鎖定恢復人工通過） | NOT RUN | 完整回歸 27/27、SDK 18/18；Dashboard／Minimal 基本操作、真實鎖定／解鎖 5 次由使用者確認。原生 ZIP、熱切換、受控暫停／恢復及 GPU unavailable SDK 探針通過。硬體精度、display-off、完整版面／多螢幕仍待驗，見 acceptance/2026-10-28/runtime/REPORT.md |
