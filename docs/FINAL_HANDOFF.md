# DrillPaper 驗收交接

更新：2026-10-29。這份總表整合目前證據；先前 Windows 10 工具鏈與早期限制保留在 STATUS 歷史，不再作為目前工作樹狀態。

後續工作已拆成 [9 張本機 Markdown tickets](../.scratch/rc-delivery/spec.md)：多螢幕 → 固定 800×600 設定介面 → 首次試用打包（7A）→ 安全／桌面電源／硬體效能／作者流程 → 交付重新打包（7B）→ RC 回歸。01／02 已實作並完成可自動執行驗證，03～09 仍 open；人工矩陣與 RC gate 保留。不自動合併 main 或公開發布。

RC 02 管理用戶區在 100%／150% 實測為 800×600／1200×900；原生版面、長文字／識別捲動、受控鍵盤訊息、設定及多螢幕／網路回歸通過。人工鍵盤、系統匣點擊、匯入／移除確認及小工作區實機仍 NOT RUN；證據種類、Runtime 156.0.4314.50 與精確 hash 見 [報告](acceptance/2026-10-29/fixed-settings/REPORT.md)，操作清單見 [設定視窗需求](FIXED_SETTINGS_WINDOW.md)。

main 歷史整合狀態：使用者已授權將完成分支合併 main，main 從 5697bf7 快轉至 feature/tray-management 的 bec20d4，涵蓋當時功能／修正分支歷史。下文先前「未合併／不合併 main」為當時紀錄。當次多螢幕仍 planned；RC 01 的新實作留在自己的功能分支，未合併 main，RC gate 保留。

main 整合提交 0f548ae 的 [CI 40848448010](https://github.com/act70255/DrillPaper/actions/runs/40848448010) 已通過 CTest 33/33／SDK 18/18、SDK 還原與封裝，RC job skipped。metadata／節錄保存於 acceptance/2026-10-29/main-integration/；此後的結果文件提交不變更產品。

剩餘工作依「驗證／必要完整性功能／補充功能」分類，見 [工作清單](REMAINING_WORK.md)。多螢幕已完成 RC 01 的程式與自動驗證，並未完成所有人工相容性驗收。

RC 01 的兩個 1920×1080 目標（150%／100%）已有獨立 HWND、精確螢幕矩形、WebView2 握手與完整 viewport、設定重啟、多宿主來源隔離及 HTTP off→on→off 證據。人工畫面、真正新版 Explorer 重啟、實體拔插、負座標／不同解析度／clone 實機仍 NOT RUN；見 [本票報告](acceptance/2026-10-29/multi-monitor/REPORT.md) 與 [政策／人工清單](MULTI_MONITOR.md)。

本輪最新：產品 62f01ab，新增獨立可註冊來源隔離 Cookie、Connection-Allowlist 阻止 WebRTC，並回復遭政策拒絕的空白錯誤頁。本機完整 CTest 33/33／SDK 18/18、原生回歸與 [CI 40839289477](https://github.com/act70255/DrillPaper/actions/runs/40839289477) 通過；新版真正 Explorer 的畫面恢復／持續更新／圖示與工作列由使用者確認 PASS。鍵盤／取消／唯一視窗亦有前版人工結果。精確 hash、最終 preconnect／儲存／worker／TURN-TCP 範圍與剩餘 NOT RUN 見 [剩餘續驗](acceptance/2026-10-29/management/REMAINING.md)。原持續桌布 PID 83428 保持固定 a241856 副本，未關閉或替換。

含新增測試的 6672610 亦通過 [CI 40840814142](https://github.com/act70255/DrillPaper/actions/runs/40840814142)，CTest 33/33／SDK 18/18，RC job skipped。其後文件結案不改產品；未合併 main，未發行。

**整體 MVP 尚未驗收通過，app RC 不可發行。** 本機與乾淨 CI 的建置／自動測試已通過，Preview 基本操作與修正版的真正 Explorer 重啟復原也已由使用者確認；完整桌面互動、瀏覽器安全政策、部分省電情境與乾淨安裝仍有實作或驗證缺口。

管理功能較早收尾：三階段均已實作並推送 feature/tray-management，未合併 main。63e86ff 的 CI 40832496506 與人工匯入／移除等歷史證據保留於 [前次續驗報告](acceptance/2026-10-29/management/FOLLOWUP.md)，各 hash 不混用。新版 Explorer 像素與鍵盤已由上列本輪結果補足；完整 DPI 與其他未測矩陣仍保留，不能宣稱完整沙箱或 RC 通過。

## A01–A16

| ID | 目前結果 | 證據與界線 |
| --- | --- | --- |
| A01 | PASS（開發環境） | Windows 11 x64 Release 建置與啟動；乾淨 windows-2022 CI configure／build 通過。其他桌面 builds 不由此建立支援聲明。 |
| A02 | PASS（基本 Preview） | 使用者回報 Dashboard mock 數值正確、Minimal 即時更新、縮放及關閉正常；Dashboard 實機更新與 CPU 圖表亦確認。完整版面／DPI 矩陣仍未做。 |
| A03 | PARTIAL | 真正 Shell WorkerW 附掛、3840×1080 用戶區及樣式有原生證據；本輪新版畫面、圖示與工作列可用已獲人工確認。完整 Alt+Tab／焦點／虛擬桌面／其他組態仍未驗。 |
| A04 | PASS（本機 Windows 11 本次情境） | 原固定 a241856 的人工 PASS 保留。新版管理 62f01ab 另完成真正 Explorer 重啟：同 app、新 HWND／Shell／握手／指標／圖示註冊，使用者確認畫面恢復、持續更新、圖示與工作列可用；Dashboard mock／no-smart-sleep，僅隔離 h1 增加識別。其他組態與電源交錯未驗，見 management/REMAINING.md。 |
| A05 | PARTIAL | typed readings、warm-up 與單位測試通過；Intel／無 NVML 的 GPU unavailable 契約已實機確認。硬體精度與 NVIDIA 實讀矩陣未完成。 |
| A06 | PASS（採樣解耦） | SamplingWorker 在背景執行緒採集、條件等待／停止／重設基準及失敗回報，UI 只接收最新快照；worker 與 app 整合已有驗證。 |
| A07 | PASS（有界資料結構） | 有界 history／queue、latest-wins mailbox 及設定世代拒絕舊樣本已有測試；不代表瀏覽器長期記憶體無洩漏。 |
| A08 | PARTIAL | 受控暫停／恢復、50 次快速競態與使用者真實鎖定／解鎖 5 次通過。真實 display-off／待機、完整全螢幕／多螢幕未完成。 |
| A09 | PASS（協定與基本操作） | 兩個內建主題、原生功能表熱切換、100／300 次協定切換及損壞主題回復有證據；不推論每次切換的像素畫面或無資源成長。 |
| A10 | PARTIAL | JS SDK／宣告／MockHost／文件、Node 18/18、SDK ZIP 解壓重測與重封一致通過；TypeScript compiler 與完整第三方作者流程未實測。 |
| A11 | PASS（已測匯入與管理流程） | `.dmt`／目錄 CLI 匯入、路徑／配額／CRC／連結／manifest 驗證、staging／原子安裝與 rollback 已驗證。圖形化匯入／移除及設定持久化已實作；保存／取消／重啟與移除真實 junction 負面通過，使用者已回報圖形化匯入正常與移除測試完成，移除後隔離目錄不存在；各步細節與完整 DPI／鍵盤仍分開記錄。套件驗證不等於瀏覽器沙箱。 |
| A12 | PARTIAL／發行阻擋 | HTTP／HTTPS 開關、首次提示、CSP／Connection-Allowlist、WS／WSS、STUN／TURN-TCP、單一 loopback preconnect、框架／導覽回復／下載／通知／定位、worker 與載入儲存隔離均有列明證據。完整 DNS／egress、其他 TURN／Runtime／權限設備 API／scheme／舊頁面競態仍未驗，不宣稱完整沙箱；見 management/REMAINING.md。 |
| A13 | PARTIAL | 含 WebView2 的 343 筆／1804.606 秒觀測與正常清理已有報告；版本、主題、GPU engine、display-off 等對照與長期資源成長判定未完成。 |
| A14 | PARTIAL | 最新產品程式 62f01ab 的 GitHub Windows runner 40839289477 通過 CTest 33/33、Node 18/18、SDK 還原及封裝 artifact。歷史失敗／重跑紀錄保留；app RC gate 阻擋，乾淨一般使用者安裝／解除安裝未做。 |
| A15 | PASS（原型文件） | README、使用、SDK／protocol、安全、指標、相容性、授權與已知限制均有說明；安裝器流程尚無已驗收產品可供測試。 |
| A16 | PASS（交接範圍） | 本表、STATUS 及逐次報告分開保存實測、人工回報、未執行與缺口；不把受控訊息寫成真正 Explorer 重啟。 |

## 建置與自動測試

目前本機：Windows 11 Pro 25H2 build 26200.8737、MSVC 19.44、Windows SDK 10.0.26100、CMake 3.31.6、WebView2 SDK 1.0.2478.35。詳細環境與 SDK 固定雜湊還原方法見 [ENVIRONMENT.md](ENVIRONMENT.md)。不需要系統管理員權限執行基本功能。

```powershell
cd 'C:\WorkSpace\-James\DrillPaper'
cmake --preset windows-msvc-release
cmake --build --preset windows-msvc-release --parallel 8
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1 -Configuration Release
```

本機 Windows PowerShell 5.1 已修正處理器型別與壓縮組件載入問題；目前完整套件含負面測試判斷的隔離變異回歸。實機 `[shell-live]` 不納入無互動 CTest，需要明確執行。

CI 的 [run 40801528098](https://github.com/act70255/DrillPaper/actions/runs/40801528098) 對 commit `9888aaf` 實測通過；含負面測試判斷修正的 `7902c02` 亦在 [run 40803087109](https://github.com/act70255/DrillPaper/actions/runs/40803087109) 通過，見 [CI 報告](acceptance/2026-10-29/ci/REPORT.md)。各 run 保留自己的受測版本。

## 啟動與人工實機驗收

一般 Preview，可正常用視窗關閉按鈕退出：

```powershell
& 'C:\WorkSpace\-James\DrillPaper\build\windows-msvc-release\Release\DrillPaper.exe' --preview --theme=dashboard
```

桌布及 Explorer 觀測建議使用完整路徑，避免 PowerShell 位於 System32 時找不到相對路徑：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\WorkSpace\-James\DrillPaper\scripts\test-desktop-host.ps1" -ApplicationPath "C:\WorkSpace\-James\DrillPaper\build\windows-msvc-release\Release\DrillPaper.exe" -RecoveryCycles 1 -ObserveExplorerRestart -ObservationSeconds 900
```

看到「桌面實機觀測已就緒」後，顯示桌面檢查圖示、工作列、Alt+Tab 與數值更新；再由使用者在工作管理員重新啟動 Windows 檔案總管。腳本不會終止 Explorer，會觀察 Shell PID 改變及新附掛世代，成功後再保留 30 秒供人工觀察，最後正常關閉並保存 `artifacts/acceptance/desktop-*/summary.json`。未執行重啟或未取得結果時不能算通過。此腳本用 `--no-smart-sleep` 隔離其他政策，不能同時當作 Smart Sleep 驗證。

2026-10-29 09:31–09:46 首次觀測未觸發真正重啟；第二次 09:54 啟動後，使用者於 09:57 重啟 Explorer 並回報桌布消失。原生診斷證實原 HWND 已被銷毀，A04 判為 FAIL，見 STATUS 及 `acceptance/2026-10-29/explorer-failure/`。Windows Computer Use 原生管道不存在，無可靠截圖，畫面以使用者回報為準。

## 證據與接續工作

- 最新 A04 結案：[Shell 就緒等待與真正 Explorer 重啟報告](acceptance/2026-10-29/shell-readiness/REPORT.md)。使用者確認畫面恢復、持續更新，原生前後比對亦通過；先前失敗保留為歷史。

- [Shell 附掛／受控重掛](acceptance/2026-10-29/shell/REPORT.md)：`90c34d4`，修正新版子 WorkerW 與 SetParent 殘留錯誤碼誤判。
- [主題平台](acceptance/2026-10-28/theme-platform/REPORT.md)、[Runtime](acceptance/2026-10-28/runtime/REPORT.md)、[renderer／browser 復原](acceptance/2026-10-28/recovery/REPORT.md)、[長時間觀測](acceptance/2026-10-28/long-observation/REPORT.md)。
- [負面測試判斷](acceptance/2026-10-29/theme-oracle/REPORT.md)：隔離副本故意移除路徑檢查時，測試現在能正確失敗；正式 validator 未放寬。
- A04 已於本機 a241856 真正重啟情境通過；接續補 A03 完整桌面互動及其他組態，失敗時以實際程序／畫面證據建立回歸。
- A12：已補 STUN／TURN-TCP、單一 preconnect、儲存及 worker；繼續補完整 egress／DNS、其他 TURN／Runtime／權限設備 API／scheme 與舊頁面競態，仍不宣稱完整沙箱。
- 復原：無限迴圈／unresponsive、故障與電源交錯、Explorer 生命週期仍需測試。
- 完成省電與效能矩陣後，修正並驗證可攜式 app 套件、乾淨使用者安裝／啟動／退出／移除，再評估 RC gate。SDK ZIP 與單獨 EXE 均不當作 app RC。

每階段完成後更新 STATUS、以繁體中文 Conventional Commit 提交並 push 對應分支；本次沒有合併至 main，也沒有公開發布。
