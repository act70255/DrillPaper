# RC 有條件放行後的剩餘證據與改善

Status: open
Type: task
Owner: James（發行維護者）
Blocked by: 必要驗證環境（乾淨機器／VM、NVIDIA 硬體、獨立作者）

## Scope

承接票 11 有條件放行後尚未取得證據的項目，以及驗證中發現的改善建議。有條件放行的判定與限制清單見 `docs/acceptance/2026-11-02/rc-gate-evidence/REPORT.md`。補到證據的項目更新該限制清單；若出現 FAIL，重新評估放行判定。

## Acceptance

- **BLOCKED，需要環境或人力**
  - 乾淨一般使用者 Windows（沒有來源樹、MSVC、Node、Python），驗證套件自足、兩個主題、匯入／移除、保存／取消／重啟、正式退出。
  - 在可還原 VM 中，缺 WebView2 Runtime 與 VC++ CRT 時的友善錯誤與官方取得方式。
  - NVIDIA／NVML 的真實讀值、缺庫與 API 失敗、unavailable 顯示。
  - 獨立主題作者依 SDK 文件建立主題，使用 MockHost，並在真實 GUI 完成匯入與完整版面確認。
- **NOT RUN，使用者決策本輪略過，有需要時補**
  - 09-G3 安全剩餘矩陣：完整 DNS／所有介面、TURN-UDP／TLS、proxy、外部 URI handler、其他 Runtime、舊 controller COM 回呼競態。接收端、副作用與正向控制都要有。
  - 免安裝 ZIP 的實際移除、設定／主題／日誌保留與主動清除（資料備份後在明確邊界刪除）。
  - 真實 Explorer 重啟補到 3 次；待機／喚醒；未鎖定關屏 5 次；關屏時啟動後握手。
  - 長測：正式桌布模式加上智慧休眠的更長 soak、真實節能對照、高網路流量與介面消失、其他硬體與 Runtime。
- **改善建議，可另開實作票**
  - 智慧休眠的 `obscured` 改為逐顯示器判斷，只暫停被全螢幕覆蓋的螢幕，以符合 handoff 第 213 行（目前所有螢幕一起暫停）。
  - 管理日誌每行加上時間戳記。
  - 手動暫停時的標題文字改為「手動暫停」，避免與真實關屏混淆。
  - 決定是否以及如何移除 `scripts/package.ps1` 寫死的 readiness blocker，以便產出正式 RC 產物（簽章、發布另行決策）。
  - 封裝工具相對輸出路徑以 .NET 工作目錄解析的問題（票 15 發現）。

## Comments

- 2026-11-02 決策（使用者確認）：票 11 結案並以本票追蹤剩餘項目；RC 判定為有條件放行，接受 `rc-gate-evidence/REPORT.md` 的已知限制清單；不自動發布、不建立 tag／release。
