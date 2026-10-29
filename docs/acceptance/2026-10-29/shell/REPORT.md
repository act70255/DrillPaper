# Windows 11 桌布附掛與受控重掛

2026-10-29，Windows 11 Pro 25H2 build 26200.8737、x64 Release、150% 縮放環境。範圍是原生 Shell 與程序整合，沒有像素畫面證據。

## 問題與修正

1. 原始實機測試回報 `DesktopAttachFailure=3`，見 `red.txt`。單改建立訊息後仍失敗；inventory 顯示新建 WorkerW 是 Progman 的子視窗。加入子層搜尋，並以真正 Shell 的 PID 檢查視窗身分，不只比對類別名稱。
2. 完整 app 解除自身視窗附掛，再定向送出 TaskbarCreated 後回報 `DesktopAttachFailure=4`，見 `before-setparent-fix.json`。SetParent 非空回傳值代表成功，原先只看 LastError 的判斷會誤報；修正後相同測試通過。
3. 初期觀測混用實體與 DPI 虛擬座標，出現 3840×1080 對 2560×720 的假尺寸差異。觀測器在單一 native 呼叫內切換 Per-Monitor V2 並還原原 context；測試視窗也使用產品相同 DPI context。這是測試量測修正，不當成產品畫面缺陷。

## 實測

```powershell
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperWindowsHostIntegrationTests --parallel 8
& build/windows-msvc-release/Release/DrillPaperWindowsHostIntegrationTests.exe '[shell-live],[desktop]'
ctest --test-dir build/windows-msvc-release -C Release -R 'Desktop fallback' --output-on-failure
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -RecoveryCycles 5
```

- 原生視窗 2 案例／22 斷言全通過，輸出 `green.txt`。
- app 初次 SDK 握手成功；桌布父視窗由 Shell PID 31956 持有，類別 WorkerW，app 填滿其 3840×1080 用戶區。
- 5 次測試均先只解除受測 app 自己的附掛，再只向其通知視窗送訊息；同一 app PID／HWND 的附掛世代由 1 增至 6，不能以舊狀態誤判復原。
- 正常 WM_CLOSE、退出碼 0、6 個已觀察 WebView2 子程序全退出，見 `app-controlled.json`；受測版本見 `sha256.txt`。

這裡的 `ActualExplorerRestart=false` 是刻意保留的範圍標記。測試沒有終止使用者 Explorer，也沒有把通知注入寫成真正程序重啟通過。圖示點擊、背景選取、工作列、Alt+Tab、焦點與視覺顯示仍需人工實機檢查；其他 Windows builds／顯示配置亦未由本結果建立支援聲明。程式維持 `--experimental-desktop` opt-in。

## 參考

- [Microsoft GetShellWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getshellwindow)：真正 Shell 桌面視窗入口。
- [Microsoft SetParent](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setparent)：回傳值、樣式與 DPI 語意。
- [Lively 的原生桌面整合原始碼](https://github.com/rocksdanister/lively/blob/core-separation/src/Lively/Lively/Core/WinDesktopCore.cs)：查證新版 raised desktop 的實際階層與訊息用法；沒有新增 Lively 依賴或複製其實作。

WorkerW 與 0x052C 屬相容性技巧，不是 Microsoft 穩定的桌布宿主 API，仍須保留實機版本矩陣與 fallback。
