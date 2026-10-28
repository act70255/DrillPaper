# Runtime 背景採樣與生命週期驗收

日期：2026-10-28。分支 `feature/runtime-lifecycle`，承接主題平台 commit `66edcbb`。本階段未解除發行閘門。

## 實作邊界

- `runtime/SamplingWorker` 使用條件變數等待與單一背景執行緒；採集及發送 callback 不持有工作者鎖。0 間隔暫停，設定變更即刻生效，不追趕過期採樣；Stop 等待 callback 返回。同步硬體 API 本身沒有被強制取消，未驗證 vendor API 永久卡住的退出上限。
- 原生 UI 不再同步呼叫 Windows collector。快照經既有 SRW mailbox latest-wins 傳送，附設定世代；UI 拒絕先前狀態排隊中的舊資料，恢復時重設差分基準並發送完整快照。
- `platform/windows/PowerNotifications` 擁有獨立隱藏視窗，註冊 WTS 工作階段與顯示器電源通知；App 將有限事件交給既有 PowerStateMachine。前景全螢幕有 1 秒防抖，非安全邊界。`--no-smart-sleep` 可停用節能政策供除錯。
- WebView2 在 UI 執行緒執行 hide→TrySuspend、Resume→visible。暫停標題只有在 `get_IsSuspended` 成功查得 true 後成立；非同步初始化／暫停 callback 使用 lifetime token，過期狀態 callback 以 runtimeEpoch 判斷並回 UI 迴圈套用最新政策。無法確認暫停時維持低頻退化，不宣稱成功。
- 背景採集失敗會停止該工作者、記錄詳情並透過原生視窗顯示友善訊息；建立工作者失敗在入口 composition 範圍內處理，不外拋原始 C++ 錯誤。真實硬體失敗注入仍未完成。

## Red／Green

1. 背景採樣起始測試先 FAIL（2 秒內沒有資料），實作後通過。
2. 舊 app 沒有 Windows 電源事件宿主，生命週期整合先 FAIL，接線後一般 5 次受控工作階段測試通過。
3. 嚴格比對 `IsSuspended` 時，快速往返重現 locked 但未暫停。最小負載不需一般循環，50 次快速往返即可重現；見 [失敗紀錄](suspend-race-before-fix.json)。先前 TrySuspend 可被中間的 Resume 取消，晚到 callback 不代表最新 locked 狀態仍已暫停。新增狀態世代判斷，返回 UI 迴圈重新套用最新狀態；並在初始 Navigate 後套用電源政策，避免 Navigate 自動恢復後留在錯誤狀態。
4. 回跑最小負載及原先 5 輪＋50 次快速往返＋暫停期間關閉，均通過。沒有放寬成「不崩潰」或只看 callback 的 isSuccessful。

WebView2 的可見性前提、best-effort 暫停及部分 API 自動恢復行為見 [Microsoft ICoreWebView2_3 文件](https://learn.microsoft.com/en-us/microsoft-edge/webview2/reference/win32/icorewebview2_3?view=webview2-1.0.2478.35)。產品的成功範圍以下列本機實測為限。

## 本機結果

| 範圍 | 結果／證據 |
| --- | --- |
| C++ 建置 | PASS，見 [build.log](build.log)；Runtime 核心測試及產品 target 使用 MSVC UTF-8 編譯 |
| Worker 公開行為 | 4 個案例／21 項斷言通過：採集與 callback 不在呼叫執行緒、暫停停止、即時恢復且重設基準、錯誤通知、舊世代 in-flight 資料拒絕 |
| 完整回歸 | 最後 CTest 27/27（25.24 秒）、SDK 18/18、封裝正負及重封測試 PASS，exit 0，見 [regression-final.log](regression-final.log)；初次回歸亦通過，見 [regression.log](regression.log) |
| 受控 Windows／WebView2 整合 | 最新測試 5 次往返、50 次快速往返、暫停請求期間正常關閉，PASS，見 [lifecycle-controlled.log](lifecycle-controlled.log)。實際呼叫 TrySuspend／Resume、查詢 IsSuspended，但工作階段事件是測試訊息，不冒充實際 OS 鎖定 |
| 實機資料與無 NVML 退化 | PASS：實際 EXE 不帶 mock，以安裝的探針主題讀取 SDK 快照；只有 CPU available 且 0–100、RAM 合理正值、GPU unavailable/null/percent 才訂閱並完成宿主 ready 標記。見 [live-metrics-gpu/summary.json](live-metrics-gpu/summary.json) 及可重現腳本 `scripts/test-theme-switch.ps1 -LiveMetrics -ExpectGpuUnavailable` |
| 使用者真實鎖定／解鎖 | 使用者明確回報 5 次均恢復更新、可正常關閉；agent 亦確認該測試 PID 已退出。見 [manual-session.json](manual-session.json)。人工受測 EXE SHA-256 為 `FD162E408FC3D2EEC878735C037E9E4CAAAAA19F2F674E76D5D7E912B09EB42E`，不冒充其他版本的人工證據 |
| 最近編譯 EXE | SHA-256 `0015E2FD2F58CA792A7C98F4E8020CC6E5C64E8A5CAB23B0383784BCF7D77EB9`，額外保守處理查詢失敗及工作者建立失敗；另跑受控回歸 |
| 權限 | 工具父程序提升權限檢查為 false，未使用 RunAs；PE manifest 為 asInvoker/uiAccess=false，見 [app.manifest](app.manifest)。不等於乾淨使用者安裝驗收 |

可重現：

```powershell
cmake --build --preset windows-msvc-release --parallel 8
.\scripts\test.ps1 -Configuration Release
.\scripts\test-runtime-lifecycle.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Cycles 5 -Rapid -CloseWhileSuspending
.\scripts\test-theme-switch.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Cycles 2 -LiveMetrics -ExpectGpuUnavailable
```

## 尚未驗收

真實顯示器電源關閉／待機喚醒、全螢幕及多螢幕矩陣、renderer/Explorer crash recovery、安全負面網路／下載／權限、長時間效能、乾淨安裝與 CI，均保留未驗收；不得由本次單元測試或受控事件推出通過。GPU 的 unavailable 契約已確認，不表示支援 Intel GPU 使用率或核對所有硬體讀值精度。
