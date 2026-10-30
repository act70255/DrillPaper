# 08 交付候選包 → 09 人工清單

版本0.1.0-trial.6；產品commit676bb473efeca65614fddb40d98e3c88c302494b，EXE／ZIP hash見REPORT／package-trial6-metadata.json。本機隔離自動驗證不等於乾淨機器。各項記日期、操作者、提交／hash、Windows build、Runtime、權限、螢幕與DPI、防毒完整產品／版本、結果及證據；有攔截逐次記時間／規則／hash／影響步驟並列BLOCKED，不停用防毒。除另列BLOCKED外，以下均 **NOT RUN**，原因是需要人工、另一機器或真正OS／硬體事件。

1. **真正乾淨一般使用者機器**：無來源樹、Visual Studio、Node、Python。由可信來源取得ZIP與獨立SHA，解壓非Temp繁中空白目錄，核對55檔清單與manifest後雙擊CMD；一般使用者啟動、不提升權限。補完整防毒build及介入紀錄。
2. **缺依賴實機**：在專用映像分別驗VC++缺失／過舊及WebView2缺失；不解除現用主機依賴。入口應繁中fail-fast與官方取得方式，不下載／自動安裝；準備依賴後再驗。直接EXE的Windows loader錯誤不算入口提示PASS。
3. **GUI及版面**：真實點擊管理、系統匣、桌面圖示／工作列／Alt+Tab／Win+D／焦點、虛擬桌面、Tab順序與800×600捲動。查看Minimal／Dashboard完整數值、unavailable與持續畫面；握手及MetricsTick不能代替人眼版面／頁面回應。
4. **主題及偏好**：GUI選檔匯入可信DMT，真實點擊取消／確認移除、同版重匯入；已自動驗證原生移除確認與CLI，但選檔及人手操作仍未驗。保存主題／Preview／網路／螢幕、取消草稿、正式退出及同CMD重啟；不要把CLI或原生訊息代替所有GUI步驟。
5. **顯示與OS**：其他Windows／Runtime／混合DPI／解析度、多目標、部分與全部離線、恢復／拔插；離線選擇不寫回。Explorer重啟、鎖定／關屏／睡眠／喚醒與故障交錯須另約專用環境並另獲授權；本票禁止重啟Explorer、關閉／替換原持續桌布。
6. **ZIP移除：trial.5 BLOCKED（工具政策）；trial.6 NOT RUN（同政策限制）**：審查前trial.5解壓目錄仍為 `C:/Users/James/DrillPaperTests/交付收尾 含空白/final-trial-5`。自動核准兩次拒絕刪除，尚未實際移除。人工先確認此目錄的app與WebView2已退出，再僅刪此解壓目錄；核對隔離資料的settings／themes／logs仍在且hash同data-before-removal.json。ZIP本身保留；最新trial.6解壓在同根目錄的final-trial-6，因相同政策未再嘗試刪除，需獨立人工驗證。資料根目錄是另一個final-author-1/appdata/DrillPaper與final-entry-1/round-N/appdata/DrillPaper，不可誤動原持續桌布資料。
7. **主動清除資料／更新／回復**：用專用資料複本，退出後備份整個根目錄，確認無其他DrillPaper使用，再明確刪除該複本的DrillPaper子目錄；旁放無關marker，確認未受影響。不要刪其他帳號或原資料。測新版解壓新目錄、hash核對、退出舊版、啟動新版、退出新版後回復舊版與資料備份；禁止運行中覆寫或兩版共用資料。沒有安裝器，不宣稱安裝器／解除安裝通過。
8. **08-D1／休眠與RC gate**：09承接保存Preview後退出超15秒觀測缺陷及繞行移除；本票依確認決策不再追。原第2輪FAIL、03歷史FAIL保留；不要直接移除`--no-smart-sleep`或以本輪繞行PASS放行。04安全PARTIAL、06記憶體上升／缺失與NVIDIA／真實電源、07獨立作者及人眼版面仍待完成。09跑完整測試、核對乾淨Windows CI及實際最終套件、更新A01～A16；必要gate未過即拒絕RC。產品變動須新版本重包與相關重測，不合併main或公開發布。
