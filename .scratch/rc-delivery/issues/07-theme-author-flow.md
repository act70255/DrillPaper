# 第三方主題作者完整流程

Status: implemented
Type: task
原討論編號：6
Blocked by: 06

## Scope

補 A10 的 TypeScript compiler 與第三方作者端到端流程；從文件／SDK 開始建立新主題，編譯為離線靜態資產、打包 .dmt、匯入並於 Preview／多目標桌布運作。作者建置工具不成為一般使用者的 app runtime 依賴。

## Acceptance

- 在乾淨作者目錄依文件取得 SDK／宣告／範例，以明確版本 TypeScript compiler 編譯，驗證正確用法與預期型別錯誤；不能以 Node 測試通過取代編譯驗證。
- 使用作者自行產出的靜態檔與 manifest 經正式工具打包、驗證、GUI 匯入／確認，無需開發來源樹或放寬匯入副檔名政策。
- 在 Preview 與每個已選目標收到版本化握手、mock／實際 metrics，正確顯示 unavailable／單位／更新；同一主題能在不同目標完整排版。
- 覆蓋 API 版本不相容、非法套件、切換／重新匯入／移除及必要錯誤提示；第三方內容不能執行原生管理命令或繞過網路政策。
- 對 SDK／protocol 缺陷先 TDD 再修正；更新會阻擋作者完成流程的文件，保存 compiler 命令／版本、樣本來源與套件 hash、實機結果及 NOT RUN。
- SDK ZIP 與作者工具驗證結果獨立記錄，不替代 app 的 08 交付與 09 RC。

## Comments

- 2026-10-30 完成可執行範圍：固定 TypeScript 5.9.3 的作者範本／lockfile、SDK ZIP 獨立還原編譯與正式包內工具打包 PASS。先取得 MockHost 宣告 TS7016、limits 宣告 TS2339 與 MockHost ready 契約失敗，再最小修正；SDK18/18、compiler 正確用法及四種預期型別錯誤、相關原生CTest8/8＋螢幕1/1、TS／宣告禁止與移除再重匯入契約 PASS。原生產品 C++ 未改，完整套件留09。
- 實機：作者原包 Preview mock、派生驗收包 Preview live／雙目標 live、正式匯入／同版拒絕／作者→Minimal→作者／APIv2與三種HTML管理命令拒絕／HTTP off零收件及on正向控制 PASS。最終 Preview兩份＋雙目標四份接收報告確認連續訂閱更新DOM，主內容未超viewport；不能代替人工像素／桌面互動。所有七個成功情境正式退出0；保留工具字串誤判與live warm-up探針失敗，不當產品FAIL或防毒介入。完整來源／hash、命令、紀錄見 `docs/acceptance/2026-10-30/theme-author-flow/REPORT.md`。
- SDK ZIP `1.0.0-rc3.author.1`（非app交付）64,412bytes，SHA `376906271C8FBF0E3EDAFC9E8662E4C32524AA7974685AD7ED05DE6FF623A0C8`；作者DMT 7,162bytes，SHA `82BF38D3743A3F6ADCBFCC31D754B5E776D3A3B815DFB7F49A47F83C7CEE8546`，最終乾淨作者重建相同。EXE沿用 `25316B…6D26D`。防毒／原持續桌布核對見報告；不改防毒、不重啟Explorer、不操作原桌布。
- 傳遞08／09：A10仍PARTIAL；GUI匯入／移除確認與重匯入人工畫面、各目標完整視覺、獨立瀏覽器MockHost／乾淨一般使用者／無Node機器、其他OS／Runtime／硬體與完整安全矩陣NOT RUN，附 `MANUAL_CHECKLIST.md`；不解除03歷史FAIL或RC gate。SDK ZIP／作者工具證據獨立於app交付。code-review與單次commit＋push依本票使用者指示收尾，hash以本分支Git記錄為準。
- 2026-10-30 收尾審查：Standards兩項工具入口／清理問題修正，複查0；Spec0。缺USERPROFILE與受控CIM觀測失敗補驗，後者工具CLEANUP_FAILED但app正式exit0，不當產品FAIL或觀測PASS；正常作者整合及SDK ZIP重驗PASS。原持續桌布path／UtcTicks／hash與防毒可讀日誌fingerprint相同、收尾唯一app，Node接收端已清理。完整報告／REVIEW保存所有限制。

- 2026-10-30 執行計畫：base `1636972a570431a0feaa9070978b2503441aa3b9`，分支 `feature/rc-07-theme-author-flow`；06 resolved。沿用公開 SDK／protocol、ThemeManager／封裝 seam，先跑固定 TypeScript compiler 的正負案例，再對票內缺陷 Red→Green。新增可從 SDK ZIP 複製的作者範本，原始碼／宣告與 dist 靜態資產分離，正式 packager／validator 不放寬副檔名；以非 Temp 使用者隔離副本、Node 直接啟動驗 Preview mock／live 及所有選取目標、切換／重匯入／移除與指定安全邊界。人工 GUI 匯入確認／版面與真正 OS 事件 NOT RUN 附清單；不動原持續桌布、不重啟 Explorer。只跑相關測試，SDK ZIP 與 app 交付分記，完成後唯一 commit＋push；衝突或前提不成立則停止不提交。

- 2026-10-29：既有 SDK 18/18 與 ZIP 還原證據保留，本票 compiler／完整作者實測 NOT RUN。
