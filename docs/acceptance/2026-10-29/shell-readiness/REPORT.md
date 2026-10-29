# Explorer 啟動時序與有界重掛

## 真正重啟結果

舊修正 `f2cff39` 的持續觀測 app PID 70156 在使用者真正重啟 Explorer 後沒有退出，握手由 1 增為 2，bridge metrics tick 也持續增加。但新的 HWND 14162818 父視窗為空，尺寸 760×480，且 DesktopFailure=1（Shell 管理視窗未就緒）。這證明視窗／renderer 重建有效，桌布重掛則因一次失敗就放棄而退回 Preview。

`before.json`、`after.json` 與 `failure.json` 保留這次原生觀測；沒有像素畫面證據，不將 Preview 等同桌布恢復。

## 修正與測試

重試決策置於純 runtime `DesktopRecoveryRetry`，以明確傳入的單調毫秒測試。失敗後至少等待一秒，最多十次，成功後重設下一次事件的額度。Win32 composition 依此延後附掛；等待期間保留採集及 renderer，但隱藏暫態 Preview，最終失敗才顯示可操作的 Preview。

```powershell
cmake --build --preset windows-msvc-release --target DrillPaper DrillPaperTests --parallel 8
& build/windows-msvc-release/Release/DrillPaperTests.exe '[desktop-retry]'
powershell -NoProfile -File scripts/test.ps1 -Configuration Release
powershell -NoProfile -File scripts/test-desktop-host.ps1 -ApplicationPath build/windows-msvc-release/Release/DrillPaper.exe -RecoveryCycles 3 -DestroyParent -ParentExit crash -NoRecoveryNotification -TimeoutSeconds 30
```

- `red.log`／`green.log`：新增公開 runtime 時序契約先失敗，再通過 28 斷言。
- `full.log`：本機 CTest 29/29、SDK 18/18 及工具檢查通過。
- `parent-crash.json`：3 次隔離父程序崩潰，沒有發送復原通知；新握手及至少兩次新的 bridge metrics tick 通過，正常退出 0，已觀察子程序全退出。
- 此 fixture 沒有銷毀真正 Shell，不證明 Shell 尚未就緒時的桌面整合；真正重啟需再用新版本確認。

新 EXE SHA-256：`3C7AB52489325D2F8473DF1E9FC7C0DE38AA3AB95FF6A691A36B27AC99315BCE`。

## 真正 Explorer 重啟結案

使用者於本輪確認：「可以了 有恢復並持續更新」。同一 app PID 83428，Shell 988→50496、HWND 688652446→1183238，新父視窗屬於目前 Shell 且為 WorkerW。握手世代 1→2、附掛世代 1→3、失敗碼 0、尺寸 3840×1080；相隔約兩秒的 metrics tick 1481971265→1481973328。

`actual-before.json`／`actual-after.json` 保存原生前後比對，`actual-session.json` 記錄來源版本與 hash，`user-confirmation.json` 記錄人工畫面確認。A04 對本機 Windows 11 25H2、Dashboard、no-smart-sleep 情境標為 PASS。這不外推至 Smart Sleep 與復原交錯、其他 Windows 或顯示配置；A03 完整桌面操作及整體 RC 仍有其他未完成項目。

[CI run 40815261057](https://github.com/act70255/DrillPaper/actions/runs/40815261057) 同一 commit 第 2 次通過 CTest 29/29、SDK 18/18 與其餘 job。第 1 次的負面測試判斷腳本在 60 秒逾時，根因未定，沒有變更程式便重跑成功。兩次紀錄皆保存為 `ci-attempt1-failed.log`、`ci-attempt2.json`／`.log`，不隱藏此次測試工具的偶發問題。
