# 多螢幕套用管理

Status: implemented
Type: task
原討論編號：1
Blocked by: 無

## Scope

依 [本輪規格](../spec.md) 與 [多螢幕規格](../../multi-monitor/spec.md)，提供目標螢幕清單、套用／取消／保存與每屏完整的同一主題。原生螢幕識別／幾何留在 platform/windows，主題與網路政策沿用現有邊界。

先調查現有 host／renderer ownership，記錄螢幕穩定識別、首次及舊設定遷移預設、目標全斷線／空選擇、斷線重連、鏡像顯示的政策與可測案例，再做程式。未連接目標不得靜默套到未選螢幕；不擅自加入逐屏主題、跨屏拼接或不同網路權限。

## Acceptance

- 列出可辨識的目前螢幕，至少能選一個或多個；套用、取消、重新開管理視窗與重啟後的有效目標一致。保存沿用版本化／原子寫入，損毀與失敗有友善回饋。
- 單選、雙選及取消其中一個：每個選中目標各自顯示完整 Minimal／Dashboard，未選螢幕保留原桌面，不截成大畫布片段。
- 覆蓋主螢幕變更、負座標、不同解析度／DPI與拔插；已選目標重連按文件政策恢復，沒有多餘宿主或錯誤套用。受硬體限制的配置逐項 NOT RUN。
- 真正 Explorer 重啟後所有已選目標恢復、持續更新，圖示／工作列／系統匣可用；原生訊息與人工畫面證據分開。
- 主題切換、暫停／繼續、模式切換、正式退出涵蓋所有目標；舊 callback／錯誤頁及單目標失敗不越權影響管理，已觀察子程序正常清理。
- 設定與 runtime 公開契約做相關 TDD；多宿主的來源／世代／訊息隔離與全域網路偏好回歸，不用單元測試宣稱桌面畫面 PASS。
- 留下實測螢幕配置、各目標 HWND／附掛／握手、截圖或人工結果與版本。02 再完成最終 800×600 版面。

## Comments

- 2026-10-29 Codex 實作結案：從目前 HEAD `7806266` 建立 `feature/rc-01-multi-monitor`，未發現既有決策與現況衝突。技術規劃與公開 seam 先記錄於 `docs/MULTI_MONITOR.md`，再實作 QueryDisplayConfig 穩定 target ID、schema 2 原子保存、首次／舊版主屏遷移、斷線清單及 fallback、clone 去重、各區域獨立 HWND／WebView2／DPI／復原與全域命令廣播。未納入逐屏不同主題或跨屏拼接。
- 2026-10-29 驗證：相關 CTest 25/25、Settings 5 cases／29 assertions、Runtime 目標解析 2 cases／13 assertions。先取得保存遺失、目標解析、clone 重複、超大設定、空 Preview 目標及選題復原額度的失敗證據，再修正；既有原子／損毀保護不虛構 Red。Release 相關 targets 建置成功，Standards／Spec 各自審查及複查均無未解決 finding。
- 2026-10-29 原生自動驗證：Windows 11 26200.8737、WebView2 155.0.4283.62、兩個 1920×1080、DPI 144／96。單／雙選與取消、原設定雙屏重啟、完整矩形與 DOM viewport、各目標握手、來源／世代及單故障隔離、HTTP off→on→off、全斷線提示且不改設定、暫停／模式往返與已觀察子程序退出均 PASS（程序／協定範圍）。雙屏 fixture 父程序 crash 全部重建、單屏無通知父視窗 crash 2 次與 renderer 4 次含重新選題額度亦 PASS。EXE SHA-256 `CE7223F45B2EE7BE94E4C1EDD0F71BF107D2290C4ABA9A7E30F69D5320028774`；命令與證據見 `docs/acceptance/2026-10-29/multi-monitor/REPORT.md`。
- 2026-10-29 NOT RUN：真正新版 Explorer、人工桌面畫面／互動、實體拔插與接回、主屏變更、負座標／不同解析度／clone 實機，以及真實電源／其他硬體／環境；依已確認指示留下 `docs/MULTI_MONITOR.md` 人工清單，不阻斷本票。完整套件、CI、打包未跑，留後續票及 09 收尾；未以單元／fixture 宣稱 GUI PASS，RC gate 保留。原持續 PID 83428 固定 a241856 副本未關閉或替換。
- 2026-10-29 其他票範圍：02 完成最終固定 800×600 設定版面；本票先用可操作的 600×600。150% 管理 PNG 底部按鈕可見，但無 friendly name 的超長裝置路徑列會截斷，請 02 一併整理標籤資訊。其餘後續票不在本次實作範圍。
- 2026-10-29 提交：依使用者要求，本票只 commit 一次並 push `origin/feature/rc-01-multi-monitor`，不合併 main；提交訊息由 commit-msg skill 依實際差異產生。

- 2026-10-29：依使用者已指定的「選目標、每屏完整一份」建立。實作與全部驗收 NOT RUN；技術政策調查屬本票第一步。
- 2026-10-29 決策（使用者確認）：首次啟動或舊版 settings.json（無目標欄位）遷移時，預設目標只有「主螢幕」。
- 2026-10-29 決策（使用者確認）：已勾選目標全部未連接時，暫時改在目前主螢幕顯示，並在管理介面明確提示「已選螢幕皆未連接，暫時顯示於主螢幕」；不寫回保存的目標，原目標任一接回後自動改回原目標。只有「全部斷線」才 fallback；部分斷線時只顯示仍連接的已選目標，不補到未選螢幕。
- 2026-10-29 調查結論（Claude，派工前）：現有 composition 只有單一桌布 HWND／WebView2Host，附掛後拉滿整個 WorkerW client（等於跨螢幕大畫布），需改為每個有效目標一個宿主 HWND＋controller，各自定位到該螢幕在 WorkerW client 座標中的矩形；全域主題、網路政策、快照、暫停／電源政策套用到所有宿主。Preview 模式維持單一視窗。實作時一併處理以下技術方向，若與程式現況衝突則停止回報：
  - 螢幕穩定識別：以 QueryDisplayConfig／DisplayConfigGetDeviceInfo 的 target `monitorDevicePath` 為保存 ID，顯示名稱用 friendly name；`\\.\DISPLAYn` 只作執行期對應，不保存。
  - 空選擇：桌布模式至少需一個目標，空選擇不可保存並給友善提示。
  - 斷線重連：保存的未連接目標保留在設定中，清單標示「未連接」且可取消勾選；接回後依上方政策自動恢復。
  - 鏡像（clone）：同一桌面區域只建立一個宿主；鏡像群組任一 target 被勾選即顯示於該區域（實體鏡像必然兩屏同畫面），清單須標示鏡像關係。
  - 逐屏 DPI：子視窗跨程序附掛不保證收到 WM_DPICHANGED，WebView2 需依該螢幕 DPI 明確設定 rasterization scale；監看 WM_DISPLAYCHANGE／裝置變更重新列舉並重建／移除宿主。
- 2026-10-29 決策（使用者確認）：本批 01～09 交由 Codex CLI 依序實作；需要人工操作或看畫面的實機項目（真正 Explorer 重啟、拔插、鎖定／睡眠、NVIDIA、乾淨使用者環境、人工畫面）先完成可自動執行部分，其餘標 NOT RUN 並附人工操作清單，不中斷流程。不重啟 Explorer、不關閉／替換原持續桌布。
