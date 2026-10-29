# 管理功能剩餘驗收續作

日期：2026-10-29。承接已確認的三階段 spec 與 `488a832`，分支 `feature/tray-management`，不合併 main。

## 範圍與方法

- 沿用原生 Win32／WebView2 整合 seam，先增加可失敗的實際行為測試；只有重現缺陷才做最小修正。
- 補每次來源載入的 localStorage／sessionStorage／Cookie 隔離，包含共同父網域 Cookie 的負面案例。
- 補 WebRTC 的 UDP/STUN 接收端，以獨立 UDP 正向控制確認接收端可用，再比對網路開關及重啟期間收件。
- 續驗 worker、額外權限及 URI scheme；具體覆蓋與未執行範圍依結果記錄，不推論完整沙箱。
- 重測最終版本的管理／復原；鍵盤、縮放與真正 Explorer 的像素確認由人工補充，Computer Use 管道仍為 `os error 2`，不將原生命令注入視為真正點擊。
- 每個修正階段更新 STATUS，使用 commit-msg skill 產生繁中訊息後 commit＋push。完整回歸在本輪實作完成後執行，CI 對應實際提交。

原持續桌布 PID 83428 已核對為 `persistent-readiness-20261029-120049/binary/DrillPaper.exe`，固定 a241856 副本，保持運作。人工鍵盤／版面測試另用隔離固定副本 PID 90952，受測 hash `F0238D6151CF4FC812F94483D99F40AE869D675DA2CF308C201D959B5D6EB757`，不與後續修正版混用。

## 結果

### 空白錯誤頁與擴充安全矩陣

新增 worker／儲存測試後，原探針停在外部導覽後。先後移除 service／shared／dedicated worker、改事件確認、改非同步函數，以及暫時於 NavigationStarting 取消後 Stop，均未建立完整通過；沒有以這些嘗試改寫成 PASS。隔離 CDP 證明已提交 `chrome-error://chromewebdata/`，unreachableUrl 為 loopback navigate endpoint，body 空白。CDP 證據來自暫態 Stop 嘗試 hash FB7418…，該改動已撤回。此時原生標題仍可保留舊的 Live metrics，因此不能用標題／metrics tick 單獨判定畫面存活。

獨立最小 Red：DF658C… 固定副本、security-z-navigation，先完成一次訂閱，worker 遭拒再嘗試外部導覽，第二次訂閱不成立。新增失敗 NavigationCompleted／實際 Source 的可信 Minimal 回復後，同案例及完整安全腳本 PASS，session security-ddad2d5848c94edfb672e3d87d1ff809，EXE hash `8AACD05B50BEDF89E2F191B14986E3A1AB380A60B075C0CA5097DDAE539176D1`。ADR 0004 明列新行為及保存偏好不變。

同一輪亦 PASS：IndexedDB、Cache Storage（當前來源讀寫正向控制與每次載入隔離）；host-only Cookie；Dedicated／Shared／ServiceWorker；camera／microphone 權限狀態 denied；STUN UDP 與 TURN-TCP、WSS 只有接收端的原生控制各一筆，無主題收件。HTTP／HTTPS 開關、其他既有負面與兩種重啟通過。navigation-{red,green}.log、navigation-result.json、navigation-{stun,tcp,requests}.jsonl 保存結果；權限查詢不等於所有設備呼叫已測。

完整 DNS／preconnect、TURN-UDP／TLS、其他 Runtime、舊頁面訊息競態等仍 NOT RUN。後續人工與回歸另記，不解除 RC gate。

### WebRTC／STUN

Red：舊固定副本 F0238D…，security-f52a3c6928d94e519a0561ebf9857e1b，網路關閉時仍有三筆真正 STUN UDP；獨立 UdpClient 控制封包另有一筆，見 webrtc-red-packets.jsonl。新增宿主 Connection-Allowlist 後，hash `DF658C57DA4EFAE79CAF7F6CFB6A4E88EA97A1B9AAD2D3CE356799994D0FC7B1`，同測試 PASS，security-a51c31974b1046a0a4f0114a5c78db5b。off→on→off 與管理／獨立重啟期間僅控制封包一筆、主題 UDP 0；既有 HTTP／HTTPS 及其他負面通過。

初版探針假設必須拋出 SecurityError，造成一輪修正版無 UDP 但仍 FAIL。實際政策可允許物件建立而禁止 ICE，因此修正測試判定並以原產品重新證實收件斷言會失敗。保留 webrtc-exception-assumption.log。這是測試校正，不把錯誤斷言視為產品缺陷。

此證據涵蓋本機 WebView2 Runtime 155.0.4283.62、loopback STUN；TURN、完整 DNS／preconnect、其他介面／proxy 與其他 Runtime 尚未由此驗證。ADR 0003 明列政策及限制，A12 與 RC gate 保留。

### 父網域 Cookie

Red：只新增儲存行為測試，舊產品於 allowNetwork=true 第二次載入未能訂閱，exit 1；見 storage-red.log，session security-817687856ec948dfa4c8bcf5939e2d92。移至各自可註冊網域後，同一測試 PASS，session security-59a3f05723ca4f3abcc2080c1f1255a5，hash `8F3DB185176D5A2BCE9DDF445D63D8016DC281B260510AAF2C2A7B5D48BA4CAB`。目前 host-only Cookie 有讀寫正向控制，localStorage／sessionStorage 與父網域 Cookie 在後續來源未沿用。

範圍是每次載入的隔離，不代表整個 storage 矩陣。IndexedDB／Cache Storage 與舊頁面訊息競態仍 NOT RUN，接續補驗。

### 人工鍵盤／唯一視窗

使用者原文：「操作皆正常 但無法縮放因此未測試縮放」。對應 PID 90952 的提問範圍：Tab／Shift+Tab 走遍控制項、空白鍵切換智慧休眠、取消還原草稿、重複系統匣操作只有一個視窗。因此上述操作 PASS（人工）；DPI／Windows 縮放矩陣 NOT RUN，固定視窗沒有拖曳調整大小功能。不將此結果套用到未測的產品 hash 或不同組態。
