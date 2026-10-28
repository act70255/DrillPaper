# Preview 回復樣式驗證

Windows 11 25H2 build 26200、MSVC x64 Release。測試建立本程序專用的原生父子視窗，初始 child 帶有 `WS_EX_NOACTIVATE` 及 `WS_EX_TOOLWINDOW`，呼叫 `RestorePreview` 後檢查實際 Win32 parent、style 及 extended style。

修正前執行 `DrillPaperWindowsHostIntegrationTests.exe '[desktop]'`，1 案例失敗，6 斷言中 5 通過；不可啟用位元仍為 `134217728 (0x08000000)`。修正後 1 案例／7 斷言全通過，兩項桌布專用 extended styles 均已清除。

命令：

```powershell
cmake --build --preset windows-msvc-release --target DrillPaperWindowsHostIntegrationTests DrillPaper --parallel 8
ctest --test-dir build/windows-msvc-release -C Release -R 'Desktop fallback' --output-on-failure
& build/windows-msvc-release/Release/DrillPaperWindowsHostIntegrationTests.exe '[desktop]'
```

最終輸出保存在 `green.txt`，受測 EXE 的 SHA-256 保存在 `sha256.txt`。這是原生視窗整合測試，沒有操作 Explorer；真正附掛、圖示與工作列互動、重啟回復及像素畫面均 NOT RUN，不由本項結果推論整體桌布功能驗收通過。
