# 空選擇的友善提示與 Preview 範圍

Status: implemented
Type: bug
Blocked by: 無

## Scope

修正整體 code review 規格面第 2 項。01 決策：「空選擇：桌布模式至少需一個目標，空選擇不可保存並給友善提示。」目前 `ApplyPreferences` 擋下空選擇時拋出的「桌布模式至少需選擇一個目標螢幕。」（`src/app/main.cpp:477-478`）據 review 只進日誌，`HandleCommand` 的例外處理改顯示通用訊息「無法完成管理操作，請查看日誌後重試。」（約 `main.cpp:571-573`），使用者看不到原因；且 Preview 模式的套用也被同一規則擋下，超出決策範圍。

## Acceptance

- 先確認現況（review 結果需自行核對），以可測 seam 寫失敗行為測試：桌布模式空選擇套用／保存被拒時，管理介面顯示明確的繁中提示（說明至少需選一個螢幕），設定檔不變、目前有效目標不變。
- 預期的驗證錯誤與非預期錯誤分開：預期錯誤顯示具體提示並寫日誌，非預期錯誤仍顯示通用訊息並寫詳細日誌。
- Preview 模式不要求目標選擇：空選擇時可套用／保存 Preview 相關設定；切回桌布模式時才要求至少一個目標。
- 相關管理視窗原生測試（固定 800×600、長訊息可讀）維持通過。

## Comments

- 2026-10-30 完成：桌布空選擇在副作用前拒絕，具型別預期驗證錯誤顯示具體繁中訊息並記日誌，非預期錯誤仍通用提示／詳細日誌。Preview 可暫時預覽、保存空陣列與未解析首次目標及重啟；CLI 強制桌布也於既有啟動 try 內先驗證，空選擇友善退出 1，不改設定。
- 實測補出管理文字／焦點通知被誤轉成操作，清掉提示；公開原生 seam Red 後，修正為只轉送操作命令 BN_CLICKED，實際按鈕仍只送一次，標籤明確限「桌布至少一個」。同票提示需求範圍，沒有決策衝突；票 14～15／09-D2 等範圍未擴張處理。
- 驗證：設定空 Preview、首次未解析保存、具體提示、CLI 覆寫與原生通知各有 Red→Green。最終 Release 建置 PASS，相關 CTest **16/16 PASS**（2.92 秒，固定 800×600／長訊息／鍵盤等原生案例保留），PS7 parser／證據拒覆寫 PASS。最終隔離 EXE 原生命令／設定 hash／有效宿主不變、非預期錯誤、Preview 保存／CLI 拒絕／重啟／選回桌布全 PASS；兩次 exit 0、CLI 預期 exit 1，12 個當下觀察 WebView2 子程序退出。完整套件／SDK／CI／封裝依指示 NOT RUN，留收尾。
- 證據：`docs/acceptance/2026-10-30/empty-selection/REPORT.md`、`REVIEW.md`、`MANUAL_CHECKLIST.md`，最終產品 SHA `D586024E37062325B39527A1E5B711E359AFC83343AFCCEA2A159928E5059721`。前輪工具失敗與管理狀態 FAIL 原樣保留，沒有用後輪 PASS 覆寫。Standards 0／Spec 初 1 項 CLI 缺口修正後 0；人工畫面與其他環境 NOT RUN 並附清單。
- 安全／交付：產品測試循序、非 Temp 使用者目錄、Node 直接啟動；Apex One 可讀日誌前後 hash／時間不變，未觀察新增攔截不等於完整觀測，無已證實防毒 BLOCKED。原持續桌布 83428 的 path／UTC ticks／hash 不變，收尾唯一 app，無 RC13 profile WebView2 殘留；未重啟 Explorer、未關閉／替換原桌布。更新 STATUS 後依 commit-msg 產生訊息，本票一次 commit＋push `feature/rc-13-empty-selection-notice`，不合併 main、不公開發布、不解除 RC gate。

- 2026-10-30 開始：從 HEAD `c8b9b0a` 建立 `feature/rc-13-empty-selection-notice`，票 12 已 implemented。核對 ApplyPreferences／HandleCommand／SettingsStore 舊行為與票內前提一致；需求及方案記於 `docs/acceptance/2026-10-30/empty-selection/REQUEST.md`。僅跑相關測試，完整套件留收尾。

- 2026-10-30 決策（使用者確認）：依整體 code review 開單，交由 Codex 於 12 之後處理；每票完成即 commit＋push，不合併 main。
