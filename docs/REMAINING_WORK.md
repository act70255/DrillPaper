# 剩餘工作分類

更新：2026-10-30。RC 09 完成整合回歸及**拒絕放行**判定；實測狀態與證據以 FINAL_HANDOFF.md、STATUS.md 及 [09 gate 清單](acceptance/2026-10-30/rc-regression/GATES.md)為準。

原 [01～09 工作票](../.scratch/rc-delivery/spec.md)的可執行範圍及報告完成，不表示必要 gate 通過。09 發現雙目標受控鎖定往返後解除手動暫停未恢復推送（09-D2 FAIL），交[票 10](../.scratch/rc-delivery/issues/10-controlled-resume-regression.md)診斷；CI／人工／硬體／乾淨機器等必要證據交[票 11](../.scratch/rc-delivery/issues/11-rc-gate-evidence.md)，有 owner／下一步。trial.6 不變，trial.7 依已確認條件移除入口繞行後仍只供受限試用，不是 RC。

## 必要的完整性功能

| 項目 | 必要性與目前狀態 |
| --- | --- |
| 多螢幕支援 | 01 已實作勾選目標、每屏完整同一主題、獨立 DPI／宿主、斷線與重連政策。雙屏原生／協定／完整 viewport 驗證完成；人工畫面、真正新版 Explorer、實體拔插與其他配置仍 NOT RUN，見 [報告](acceptance/2026-10-29/multi-monitor/REPORT.md)。 |
| App 交付流程 | 可攜式 app 套件與一般使用者安裝／啟動／退出／移除流程收尾，完成乾淨環境驗證後才能評估 RC。 |

多螢幕的必要性及「選擇目標、每屏完整一份」呈現方式已由使用者指定。RC 01 的調查與政策見 [MULTI_MONITOR](MULTI_MONITOR.md)；原單一 3840×1080 桌布層與舊版 Explorer 結果，不代替新版多宿主人工驗收。

02 已完成固定 800×600 邏輯用戶區與 100%／150% 原生尺寸、版面及相關回歸；人工輸入、確認視窗與其他環境仍依 [報告](acceptance/2026-10-29/fixed-settings/REPORT.md)／[人工清單](FIXED_SETTINGS_WINDOW.md) 補驗。逐螢幕不同主題／其他獨立設定仍不在本版範圍。

## 驗證

- 桌面互動、顯示與 Windows／WebView2 相容性；多螢幕測試須配合上列必要功能完成。
- 網路／安全、權限／設備 API、URI scheme 與舊頁面競態的未測矩陣。
- 真實顯示器關閉、待機／喚醒、全螢幕與故障交錯，以及無回應 renderer 復原。
- 硬體讀值精度、NVIDIA／NVML、長期資源與省電效能對照。
- TypeScript compiler 與完整第三方主題作者流程。
- 安裝／移除與乾淨一般使用者環境驗收。

驗證若找出缺陷，另列相應實作修正；未測不代表功能必然缺失，也不標記 PASS。詳細 NOT RUN／PARTIAL 仍見驗收總表。

## 補充功能

選配開機啟動、更細的管理設定、主題編輯器等後續擴充另列需求。多螢幕支援不歸入此類；必要的安全、省電及相容性工作也不因尚未驗證而改為選配。

工作分類與必要性決策階段未改程式或顯示配置，產品／GUI／多螢幕測試均 NOT RUN。後續使用者已授權將完成分支整合 main；此清單的未完成項目及 RC gate 保留，不因合併視為完成或發行。
