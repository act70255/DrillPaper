# 必要功能、試用打包與 RC 驗收工作規格

Status: planned
Approval: 使用者確認工作順序後，於 2026-10-29 指示「建立ticket」；本輪建立工作規格，不開始產品實作。
日期：2026-10-29
基準：main b4616ec；本文件分支 feature/rc-delivery-plan。

## 目標與順序

先完成多螢幕與固定設定版面，再產出可實際試用的 app 套件。之後補驗收與修正，重新打包並評估 RC。第 7 項拆成首次試用打包 7A 與交付收尾 7B，沿用同一套打包流程。

| 執行順序／票號 | 原討論編號 | 工作 | 前置票 |
| --- | --- | --- | --- |
| [01](issues/01-multi-monitor.md) | 1 | 多螢幕套用管理 | 無 |
| [02](issues/02-fixed-settings-window.md) | 2 | 固定 800×600 設定視窗 | 01 |
| [03](issues/03-trial-package.md) | 7A | 首次可攜式試用包 | 02 |
| [04](issues/04-security-matrix.md) | 3 | 網路與安全剩餘矩陣 | 03 |
| [05](issues/05-desktop-power-recovery.md) | 4 | 桌面互動與電源復原 | 04 |
| [06](issues/06-metrics-performance.md) | 5 | 硬體讀值與效能省電 | 05 |
| [07](issues/07-theme-author-flow.md) | 6 | 第三方主題作者流程 | 06 |
| [08](issues/08-delivery-finalization.md) | 7B | 交付收尾與重新打包 | 07 |
| [09](issues/09-rc-regression.md) | 8 | RC 整合回歸與放行判定 | 01～08 |

01～09 是本目錄的 ticket 編號，避免把原討論的 7A／7B 和執行順序混淆。依序執行；前置票完成所列範圍並留下結果後才處理下一票。驗證票即使已完成可執行部分，NOT RUN／BLOCKED 及未結缺陷仍須傳遞到 08／09，不自動視為 RC 通過。

## 已確認的產品範圍

- 多螢幕是必要完整性功能：可勾選一個或多個目標，每個選中螢幕各顯示一份完整的同一全域主題，未選螢幕保留 Windows 桌布。沿用 [多螢幕 spec](../multi-monitor/spec.md)，不做跨螢幕拼接或逐螢幕不同主題。
- 設定視窗採固定 800×600 用戶區邏輯尺寸（100% Windows 縮放基準，標題列及邊框另計）；不提供自由調整大小。仍需基本 Windows DPI 適配與控制項可達性，桌布的逐螢幕尺寸／DPI 正確性保留。
- 7A 交付標示為試用版的 app ZIP，包含必要程式／資產與說明，驗證解壓後基本操作。7B 納入驗收修正、乾淨一般使用者交付與移除流程；09 才判定 RC。
- 開機啟動、主題編輯器、商城及其他未指定擴充不在本輪。

## 共通實作與驗收紀律

- 每張票開始前讀取 AGENTS、handoff、架構與相關 STATUS；以獨立 feature／bugfix 分支實作。技術細節先調查並補入所屬票，不重問已確認的整體範圍。
- Status 初始為 open，開始時改 in-progress，實作票完成改 implemented，純驗證票完成所列執行與報告改 resolved；未完成的驗收項維持明確結果。Blocked by 使用本目錄票號，只有前置工作實際完成才解除。
- 可公開測試的行為遵循 TDD，先保留失敗行為測試再做最小修正；既有保護通過時不虛構 Red。原生 Win32／WebView2、硬體及人工畫面使用實機驗收，不能由單元測試推論。
- 驗證票發現票內缺陷，先補回歸再修正；其他票範圍的問題記入 Comments 並連結追蹤，不默默擴張範圍。
- 證據記錄來源 commit、EXE／套件 SHA-256、Windows／WebView2／硬體／顯示配置、命令、結果及日誌。PASS、FAIL、PARTIAL、NOT RUN／BLOCKED 分開，後兩者必須有原因與下一步。
- 保留已完成的管理三階段、指定安全負面與新版 Explorer 人工 PASS 的版本化證據；新行為變動時做相關回歸，不把舊 hash 結果套到新版本。
- 實機前核對原持續桌布程序路徑與建立時間；歷史 PID 83428 為固定 a241856 副本，PID 可能重用。未獲另行授權不關閉／替換；測試使用隔離副本與資料，清理只針對已確認身分的測試程序。
- 每階段完成後更新所屬 ticket Comments／Status 與 docs/STATUS.md，使用 commit-msg skill 產生繁中 Conventional Commit，立即 commit＋push；本次建立 tickets 不授權自動合併 main 或公開發布。
- 決策（使用者確認，2026-10-29）：01～09 交由 Codex CLI 依序實作，每票完成即 commit＋push。需要人工操作或看畫面的實機項目（真正 Explorer 重啟、拔插螢幕、鎖定／睡眠、NVIDIA、乾淨使用者環境、人工畫面確認）先完成可自動執行部分，其餘標 NOT RUN 並附人工操作清單，不中斷流程；不重啟 Explorer、不關閉／替換原持續桌布。
- 決策（使用者確認，2026-10-30）：03 發現的「預設智慧休眠下啟動未握手」缺陷延到 05 修正；7A 試用入口暫時預設關閉智慧休眠並列為已知限制，08 須回到產品預設行為重驗。
- 決策（使用者確認，2026-10-30）：本機有 Trend Micro Apex One，會攔截從 %TEMP% 經 PowerShell 啟動的未簽章 EXE。04～09 的實機／套件測試改解壓到非 Temp 的使用者目錄（例如 `%USERPROFILE%\DrillPaperTests\<含空白與繁中的子目錄>`），能直接執行或用 cmd／Start-Process 啟動時不包 PowerShell；每次攔截記錄產品、規則名稱、時間與受影響項目，受攔截影響的項目標 BLOCKED 而非 FAIL。不修改防毒設定。
- 開發中只跑相關測試；整體完成後在 09 完整回歸。7A 前須通過 01／02 的相關測試及套件基本檢查，不必等到 3～6 全部驗收才首次打包。

## 目前基準與證據

- 管理功能及後續安全修正已整合 main；本輪基準 b4616ec 的產品程式仍為 62f01ab 所列版本，不是全新驗收通過的 RC。
- [剩餘工作分類](../../docs/REMAINING_WORK.md)、[總交接／A01～A16](../../docs/FINAL_HANDOFF.md)、[最新管理驗收範圍](../../docs/acceptance/2026-10-29/management/REMAINING.md) 是各票的缺口依據。
- 本輪所有產品、GUI、多螢幕、打包、硬體與安全驗收均 NOT RUN（僅建立 tickets）。未產出試用包，未解除 RC gate。
