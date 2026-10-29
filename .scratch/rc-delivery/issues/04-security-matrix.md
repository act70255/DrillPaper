# 網路與安全剩餘矩陣

Status: open
Type: task
原討論編號：3
Blocked by: 03

## Scope

依 [最新安全證據](../../../docs/acceptance/2026-10-29/management/REMAINING.md) 與 ADR 0001～0004 補未驗邊界，尤其 01 的多宿主／載入世代隔離。既有 allowNetwork 已接 host，不重做成只有欄位的開關，也不宣稱完整沙箱。

## Acceptance

- 先建立有界矩陣，列出可聲明支援的 Windows／WebView2 Runtime、HTTP／HTTPS 開關 off→on→off、管理／獨立重啟及多目標；逐項結果對應實際版本。
- 補 DNS／TLS preconnect／推測連線及瀏覽器背景流量觀測；TURN-UDP／TLS、其他網路介面／proxy 若無環境則 NOT RUN，清楚區分主題與瀏覽器自身流量。
- 補設備／權限實際呼叫、URI scheme／外部 handler、框架／彈窗／下載及拒絕導覽後存活或可信回復；權限狀態 denied 不代替實際 API 行為。
- 快速切換、停用目標、退出或重建後，舊頁面／controller 訊息不能更新新世代或執行管理命令；來源、cookie／儲存與多目標隔離按原政策驗證。
- 拒絕案例有接收端或可觀察副作用及正向控制，不只看 JS 例外或標題。若 Runtime 不執行必要宿主政策，判定失敗並修正或明列不支援，不能照常宣稱封鎖。
- 重現的票內缺陷先留下失敗測試，再最小修正並跑相關回歸；沒有實測的瀏覽器／OS escape 邊界維持 NOT RUN，不以套件驗證等同沙箱。
- 結果記錄是否影響 03 試用限制、08 包內容與 09 gate；安全 FAIL／NOT RUN 不因本票報告完成自動解除。

## Comments

- 2026-10-29：先前 HTTP／HTTPS、WS／WSS、STUN／TURN-TCP、單一 preconnect、worker／儲存與導覽復原的指定 PASS 保留。新增矩陣 NOT RUN。
