# RC 13 需求與方案

已確認票：`.scratch/rc-delivery/issues/13-empty-selection-notice.md`，標題「空選擇的友善提示與 Preview 範圍」。從 HEAD `c8b9b0a` 建立 `feature/rc-13-empty-selection-notice`；票 12 已 implemented。

現況核對：ApplyPreferences 不分模式拒絕空陣列，HandleCommand 將例外改成通用提示；SettingsStore 也拒絕 Preview 空陣列，既有測試明列此舊行為。票 13 明確授權更改該行為，非決策衝突。

- 桌布草稿空選擇在任何有效狀態、主題、宿主或檔案變動前拒絕；預期驗證錯誤以具體繁中提示顯示並記日誌，非預期錯誤保留詳細日誌與通用提示。
- Preview 可暫時套用、保存與重新載入空目標，schema 2 保持陣列格式；未解析首次目標也可保存成 Preview 空陣列。切回桌布模式才拒絕，原 Preview／設定不變。
- 審查補出的同票邊界：已保存空選擇 Preview 後，CLI `--experimental-desktop` 也必須在既有啟動錯誤邊界內友善拒絕，不能留下零宿主背景程序。首次未解析偏好的主螢幕遷移不變。
- 實測補出的同票根因：管理視窗原先把狀態文字框的焦點／文字通知也轉成管理命令，清除驗證提示。以公開原生訊息 seam 先 Red，再僅轉送操作命令的 BN_CLICKED；草稿／文字／焦點通知不轉送，實際按鈕仍送一次。清單標籤同步寫明「桌布至少一個」。
- 沿已確認 AppSettings／SettingsStore 與原生管理命令／有效狀態 seam 做逐步 Red→Green。原生測試觀察訊息框、管理狀態、設定 hash、宿主 HWND／幾何／世代及握手；不以 API 證據宣稱人眼可讀。
- 只跑設定、目標解析及原生管理相關測試，完整套件留收尾。產品實測循序，資料及副本在非 Temp 使用者繁中空白目錄，Node 直接啟動；每次防毒攔截記產品／規則／時間／受影響項並標 BLOCKED，不改防毒。
- 人工畫面與其他 DPI／OS 缺口標 NOT RUN 並附清單；不重啟 Explorer、不關閉或替換原桌布 PID 83428，不合併 main、不發布。完成後更新票與 STATUS，審查、用 commit-msg 產生訊息，一次 commit＋push。
