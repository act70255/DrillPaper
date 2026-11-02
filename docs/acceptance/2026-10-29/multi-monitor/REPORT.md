# RC 01 多螢幕實作與驗證

日期：2026-10-29。基準 `7806266a3af4d89bfe8ec787cf3ecd1b31c6a1e6`，分支 `feature/rc-01-multi-monitor`。本票一次提交，提交訊息見 STATUS 與 Git 歷史。

受測 Release EXE SHA-256：`CE7223F45B2EE7BE94E4C1EDD0F71BF107D2290C4ABA9A7E30F69D5320028774`。所有最終原生結果 JSON 均記錄同一 hash。Windows 11 Pro 25H2 build 26200.8737、x64、WebView2 155.0.4283.62；C++20／MSVC／SDK 1.0.2478.35。

## 實作與範圍

- QueryDisplayConfig／DisplayConfigGetDeviceInfo 取得穩定 monitorDevicePath、friendly name、source 群組，幾何與 DPI 留在 platform/windows。
- SettingsStore schema 2 原子保存目標；schema 1／首次解析為當時主螢幕。任何模式均不可保存空目標；重複／非法／過量／超過 64 KiB 設定拒絕且保留原檔。
- 每個有效區域各有 HWND、controller、附掛重試及載入復原狀態。Win32 轉換螢幕實體矩形至 WorkerW client 座標，WebView2 使用 raw pixel bounds 與明確 rasterization scale；Preview 只有一個視窗。
- 部分斷線不補位，全部斷線暫用主螢幕且提示、不保存 fallback；接回自動恢復，clone 去重。全域主題、網路、快照、暫停／電源／退出廣播，來源及載入世代各自隔離。
- 原生管理提供螢幕勾選草稿、取消與保存。暫用 600×600 邏輯版面，02 再完成固定 800×600；150% PNG 底部按鈕可見，過長裝置路徑顯示截斷是 02 的版面注意事項。

技術政策與人工清單：[MULTI_MONITOR.md](../../../MULTI_MONITOR.md)。未加入逐屏不同主題或跨屏拼接；未改既有主題權限。

## TDD 與審查

1. 保存目標 round trip：先 FAIL（目標讀回遺失），實作 schema 2 後 PASS。
2. 目標解析：先 FAIL（沒有有效目標），最小解析後 PASS；clone 案例先 FAIL（同區域重複索引），去重後 PASS。兩案例 13 assertions。
3. 超大設定：先 FAIL（Save 不拋錯），加入序列化大小限制後 PASS；空 Preview 目標先 FAIL，再統一禁止保存空目標。Settings 最終 5 cases／29 assertions，含既有損毀／原子失敗保護，不虛構既有保護的 Red。
4. 原生復原回歸：三次 renderer crash 後重新選 Dashboard，再注入第四次；修正前錯誤回復 Minimal（[red](renderer-red.json)），改走重設額度的 LoadTheme 後 PASS（[result](renderer-recovery-result.json)）。自動 Recover 仍保留累計上限。
5. code-review 的 Standards／Spec 各自平行審查；管理可達性、復原額度、錯誤轉碼邊界、函數註解、設定容量與測試 oracle 等 finding 已處理。只讀複查兩軸未解決 finding 均 0。

## 可重現命令與結果

在 repository 根目錄執行；本票只跑相關測試。

```powershell
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests DrillPaperSettingsTests DrillPaperMonitorIntegrationTests DrillPaperWindowsHostIntegrationTests --parallel 8
ctest --test-dir build/windows-msvc-release -C Release -R 'Monitor selection|Clone targets|Settings |Invalid settings|Invalid monitor|Monitor target|Desktop recovery|Manual pause|Protocol v1|Sampling worker|Power state|Sampling scheduler|Snapshot coalescing|Desktop fallback|Connected monitors' --output-on-failure
build/windows-msvc-release/Release/DrillPaperMonitorIntegrationTests.exe '[monitors]'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-multi-monitor.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-management-shell.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Desktop
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-webview2-security.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -DestroyParent -ParentExit crash -NoRecoveryNotification -RecoveryCycles 2
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-renderer-recovery.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -Crashes 4 -ReselectBeforeFinal
```

| 範圍 | 結果與證據 |
| --- | --- |
| Release 相關 targets 編譯／型別檢查 | PASS，[build.log](build.log) |
| 相關 CTest | PASS 25/25，[related-ctest.log](related-ctest.log)；完整套件 NOT RUN，依使用者要求留 09 收尾 |
| 實際螢幕列舉 | PASS，BOE target `(0,0)–(1920,1080)`／DPI 144／primary，DELL E2425HS `(1920,0)–(3840,1080)`／DPI 96；完整 ID 與群組見 [monitors.log](monitors.log) |
| 雙選／單選／取消／保存重啟 | PASS；獨立 EnumDisplayMonitors oracle 核對宿主數量及完整實體矩形，並以原設定重啟；[結果](multi-monitor-result.json)、[各階段 HWND](phases.json) |
| Minimal／Dashboard／逐屏 DPI | PASS（原生／協定）；每屏獨立握手，實際 JS innerWidth×devicePixelRatio 與 innerHeight×devicePixelRatio 均為 1920×1080，scale 1.5／1；[viewports](viewports.json)。人工桌面像素 NOT RUN |
| 跨宿主通知／單目標故障 | PASS（受控原生通知）；其他宿主世代無法觸發本目標復原，符合目前世代的單目標故障僅改該宿主，另一宿主世代不變 |
| 多宿主來源與全域網路 | PASS；每個主題在來源儲存正向寫入，下次不得讀到舊值；HTTP off→on→off 的接收端實收為 0→2→0，兩個不同 origin；[HTTP 原始收件](multi-monitor-http.jsonl)。握手需探針本身成功，Minimal 不可冒充 |
| 全部目標未連接 | PASS（保存離線 ID 的原生情境）；只在主屏建立一個宿主、提示精確文案、保存檔 hash 不變。實體拔插／接回 NOT RUN；政策解析含部分斷線與返回目標測試 |
| 全部宿主的跨程序父視窗崩潰 | PASS（fixture）；雙屏全部重建並重新握手，矩形保持正確；不是 Explorer 重啟證據，見 phases 的 all-targets-parent-crash-recovery |
| 單屏復原／renderer 復原 | PASS；無通知父程序 crash 2 次、renderer 4 次且選題重設額度；[桌面結果](desktop-recovery-result.json)、[renderer 結果](renderer-recovery-result.json) |
| 管理／暫停／模式／退出 | PASS；唯一管理視窗重開 5 次、所有目標暫停與 Preview／桌布往返、取消保存及重啟；多屏流程已觀察 19 個子程序退出，詳細 [管理結果](management-result.json)、[PNG](management.png) |
| 既有 WebView2 安全相關回歸 | PASS（腳本所列邊界）；HTTP／HTTPS、off→on→off、來源儲存、worker、導覽復原、WebRTC／preconnect、權限與子程序清理；[security-result](security-result.json)。不代表完整沙箱／所有網路邊界 |

## 執行中校正與限制

- 初版多屏測試套用 UI 預設時重新啟用智慧休眠，握手等待逾時；固定測試電源前提後重跑成功，未將該次當 PASS。CLI 啟動偏好在 UI 的既有語意已保留。
- 管理／安全舊腳本原先在通知視窗出現後立即快取尚未建立的宿主；改為等待宿主。安全導覽 probe 增加可識別的顯示名稱，並不分大小寫辨識 Minimal，避免顯示名稱誤判；未放寬流量及探針完成條件。
- 新 PowerShell 腳本使用 UTF-8 BOM，供 Windows PowerShell 5 正確解析繁體中文。開發中的 parser／oracle 失敗不計入最終 PASS。
- 當前原持續桌布仍為 PID 83428、固定 a241856 副本；受測 app、資料及 profile 均隔離。未重啟 Explorer、未關閉或替換該程序。

## NOT RUN 與後續

- 人工桌面畫面與完整圖示／工作列／系統匣互動：使用者指定人工項先留待後續；原生與 DOM 尺寸證據不代替像素觀察。
- 真正新版 Explorer 重啟：依指示不操作；只有 fixture 與受控訊息，不沿用舊產品 hash 的人工 PASS。
- 實體拔插／接回、主螢幕變更、負座標、不同解析度、clone 及其他 DPI／Windows／Runtime：本票未改顯示設定，只有目前雙屏實機及純政策案例；依 MULTI_MONITOR 人工清單補驗。
- 真實鎖定／睡眠／喚醒、NVIDIA、乾淨使用者環境、長時間資源量測、完整安全矩陣：屬後續票及人工矩陣，本票未執行。
- 完整產品測試套件／CI／打包：NOT RUN，留本批收尾及各自票處理。02 處理最終 800×600 版面與長裝置名稱呈現；本票不產 ZIP、不合併 main、不放行 RC。
