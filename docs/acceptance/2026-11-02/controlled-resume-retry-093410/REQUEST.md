# RC 10 同步 OS 狀態重試需求

- 沿用 `feature/rc-10-controlled-resume-regression`，來源 HEAD `40e007f`；不覆寫上一輪證據。
- 依票最新已確認決策，先 trial.7，再目前 HEAD Release，循序執行原 `test-multi-monitor.ps1 -DesktopPowerRecovery`，不改 35 秒等待與 17 秒暫停觀察。
- 測試前啟動獨立只讀觀測器：`PowerSettingRegisterNotification(GUID_CONSOLE_DISPLAY_STATE)` 取得初始及後續 console display state；`WTSQuerySessionInformationW(WTSSessionInfoEx)` 查詢目前工作階段鎖定／連線旗標。週期記錄兩者與宿主公開 HWND 屬性／標題；發現 failure.json 時立即追加取樣。
- 觀測器不送電源／輸入／工作階段訊息，不呼叫防休眠 API，不改電源設定。觀測是 Windows 回報的 console 狀態，不能推論個別螢幕硬體的實際像素。
- EXE 與資料放全新非 Temp 使用者目錄，產品由既有 Node launcher 直接啟動。核實原桌布 PID 83428 身分；只讀記錄可讀防毒日誌指紋及實際攔截，受攔截項標 BLOCKED。
- 取得原鏈等價失敗才診斷；螢幕開啟卻 display-off、或 display-off 下 WebView2 未握手分開列缺陷，先留回歸再依 TDD 最小修正。測試 seam 沿用已確認 runtime／protocol 與 Windows 整合入口。
- 若再次因真正 console 關閉無法到達原鏈，或出現政策未定／決策衝突／前提不成立，即停止產品工作、不 commit，記錄原因；不視為產品 PASS 或 FAIL。
- 只跑相關測試，完整套件留收尾；人工矩陣 NOT RUN 並附清單。完成時依 implement 使用 code-review，更新票與 STATUS，再以 commit-msg 產生訊息 commit／push；不合併 main、不公開發布。

## 觀測 API 依據

- [PowerSettingRegisterNotification](https://learn.microsoft.com/en-us/windows/win32/api/powersetting/nf-powersetting-powersettingregisternotification)：訂閱後回呼目前值，之後變更持續回報。
- [Power Setting GUIDs](https://learn.microsoft.com/en-us/windows/win32/power/power-setting-guids)：console display 0=off、1=on、2=dim。
- [WTSINFOEX_LEVEL1_W](https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/ns-wtsapi32-wtsinfoex_level1_w)：Windows 11 鎖定旗標 0=locked、1=unlocked。
