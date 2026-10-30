# RC 05 兩軸審查

依 implement 明確要求套用 code-review skill，由 Standards／Spec 兩個平行子代理唯讀審查。固定基準 `2a69ed18a649770359c03b76b1503cfd51262a0c` 已解析，commit list 為空；為遵守本票一次 commit 要求，使用 `git diff 2a69ed18a649770359c03b76b1503cfd51262a0c` 加未追蹤檔案，審查尚未提交工作樹。未先提交以製造非空三點 diff。

## Standards

原 finding 1 項：兩個觀測工具的 Resolve-Path／GetFullPath／New-Item 在錯誤處理範圍外，必填路徑不存在時顯示英文原始錯誤與程式位置，違反友善繁中 fail-fast 規則。已先執行兩項 CLI 契約測試得到 Red 2/2，再補入口捕捉、詳細日誌與繁中提示，Green 2/2。工具測試不啟動 EXE。另採納子程序空集合／部分身分未知不能宣稱清理 PASS 的建議。

複查未解決 **0**。新函數有繁中 Google style 說明；WebView2 探針在 UI 執行緒、持有 lifetime token，未跨越既有架構。三個 PS 腳本保留 UTF-8 BOM；沒有基線 smell 需列為問題。

## Spec

原 finding 3 項：自訂迴圈初始化若失敗可被 Minimal 冒充通過；所有宿主斷言接受空集合；renderer 故障注入只驗 browser 的 CIM snapshot 而未固定 browser 實體。

已分別要求自訂主題及同一 load 的迴圈前第二次訂閱標記、預期宿主數量、先持有 browser handle 並驗證精確建立時間／路徑，且每次注入前檢查 browser 未退出。子代理複查未解決 **0**，未發現範圍擴張或產品契約錯誤。

fixture 第三輪身分工具錯誤與完整整合結果由主代理另外保留，不把無限迴圈局部成功誤寫為該輪全綠。真實 OS／人工 NOT RUN 與 RC gate 仍須傳遞。

初次 findings：Standards 1、Spec 3；修正後未解決：Standards 0、Spec 0。實際驗證及最後結論以 REPORT 為準。
