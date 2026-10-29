# DrillPaper 驗收交接

更新：2026-10-29。這份總表整合目前證據；先前 Windows 10 工具鏈與早期限制保留在 STATUS 歷史，不再作為目前工作樹狀態。

**整體 MVP 尚未驗收通過，app RC 不可發行。** 本機與乾淨 CI 的建置／自動測試已通過，Preview 基本操作與修正版的真正 Explorer 重啟復原也已由使用者確認；完整桌面互動、瀏覽器安全政策、部分省電情境與乾淨安裝仍有實作或驗證缺口。

2026-10-29 console 交接：使用者已確認 [.scratch/tray-management/spec.md](../.scratch/tray-management/spec.md) 完整三階段範圍。分支 `feature/tray-management`；階段 1 系統匣／生命週期已推送 `7622045`，階段 2 主題／設定實作與相關檢查已完成，仍有原生人工驗收，見 [PHASE2.md](acceptance/2026-10-29/management/PHASE2.md)。已恢復續作；階段 3 網路開關、首次提示與真實 WebView2 指定負面測試通過，見 [PHASE3.md](acceptance/2026-10-29/management/PHASE3.md)。接續原生互動與收尾驗收，不再要求範圍確認。新管理版本完整本機回歸 CTest 33/33／SDK 18/18 已通過；本次 CI 接續觸發，舊版 CI 不外推，見 [續驗報告](acceptance/2026-10-29/management/FOLLOWUP.md)。持續桌布 PID 83428 保持原固定副本，勿關閉。

## A01–A16

| ID | 目前結果 | 證據與界線 |
| --- | --- | --- |
| A01 | PASS（開發環境） | Windows 11 x64 Release 建置與啟動；乾淨 windows-2022 CI configure／build 通過。其他桌面 builds 不由此建立支援聲明。 |
| A02 | PASS（基本 Preview） | 使用者回報 Dashboard mock 數值正確、Minimal 即時更新、縮放及關閉正常；Dashboard 實機更新與 CPU 圖表亦確認。完整版面／DPI 矩陣仍未做。 |
| A03 | PARTIAL | 真正 Shell 的 WorkerW 附掛、3840×1080 用戶區及正確樣式已通過原生整合。圖示、工作列、Alt+Tab、焦點與像素畫面待人工檢查。 |
| A04 | PASS（本機 Windows 11 本次情境） | `a241856` 加入等待 Shell 就緒的有界重試後，使用者確認真正重啟 Explorer 後桌布恢復且持續更新；原生觀測新 Shell／HWND／握手與指標亦吻合。測試為 Dashboard／no-smart-sleep，其他組態與電源交錯未驗。見 shell-readiness/REPORT.md。新版管理 3871e72 真正重啟的原生附掛／指標／圖示註冊另通過，像素人工結論 NOT RUN，見 management/FOLLOWUP.md。 |
| A05 | PARTIAL | typed readings、warm-up 與單位測試通過；Intel／無 NVML 的 GPU unavailable 契約已實機確認。硬體精度與 NVIDIA 實讀矩陣未完成。 |
| A06 | PASS（採樣解耦） | SamplingWorker 在背景執行緒採集、條件等待／停止／重設基準及失敗回報，UI 只接收最新快照；worker 與 app 整合已有驗證。 |
| A07 | PASS（有界資料結構） | 有界 history／queue、latest-wins mailbox 及設定世代拒絕舊樣本已有測試；不代表瀏覽器長期記憶體無洩漏。 |
| A08 | PARTIAL | 受控暫停／恢復、50 次快速競態與使用者真實鎖定／解鎖 5 次通過。真實 display-off／待機、完整全螢幕／多螢幕未完成。 |
| A09 | PASS（協定與基本操作） | 兩個內建主題、原生功能表熱切換、100／300 次協定切換及損壞主題回復有證據；不推論每次切換的像素畫面或無資源成長。 |
| A10 | PARTIAL | JS SDK／宣告／MockHost／文件、Node 18/18、SDK ZIP 解壓重測與重封一致通過；TypeScript compiler 與完整第三方作者流程未實測。 |
| A11 | PASS（原生匯入邊界）；管理 UI 人工待驗 | `.dmt`／目錄 CLI 匯入、路徑／配額／CRC／連結／manifest 驗證、staging／原子安裝與 rollback 已驗證。圖形化匯入／移除及設定持久化已實作；保存／取消／重啟與移除真實 junction 負面通過，檔案選擇器／確認待人工。套件驗證不等於瀏覽器沙箱。 |
| A12 | PARTIAL／發行阻擋 | 全域 HTTP／HTTPS、首次提示與宿主 CSP 已接入；指定真實 WebView2 請求、WebSocket／框架／導覽／下載／通知與定位負面通過，見 PHASE3.md。WebRTC、完整 DNS／egress、跨主題 storage 等未驗，不得宣稱完整沙箱。 |
| A13 | PARTIAL | 含 WebView2 的 343 筆／1804.606 秒觀測與正常清理已有報告；版本、主題、GPU engine、display-off 等對照與長期資源成長判定未完成。 |
| A14 | PARTIAL | 最新 GitHub Windows runner CTest 29/29、Node 18/18、SDK 還原及封裝 artifact 通過；同一 commit 首次因測試腳本逾時，重跑成功並保留失敗紀錄。app RC gate 保持阻擋，乾淨一般使用者安裝／解除安裝未做。 |
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
- A12：指定 HTTP／HTTPS、WS／WSS 等真實通訊負面與開關已通過；補完整 egress／WebRTC／DNS、跨主題 storage 及其他權限矩陣，仍不宣稱完整沙箱。
- 復原：無限迴圈／unresponsive、故障與電源交錯、Explorer 生命週期仍需測試。
- 完成省電與效能矩陣後，修正並驗證可攜式 app 套件、乾淨使用者安裝／啟動／退出／移除，再評估 RC gate。SDK ZIP 與單獨 EXE 均不當作 app RC。

每階段完成後更新 STATUS、以繁體中文 Conventional Commit 提交並 push 對應分支；本次沒有合併至 main，也沒有公開發布。
