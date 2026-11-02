# RC 11 證據補齊與放行判定

日期：2026-11-02。分支 `feature/rc-11-gate-evidence`。候選版為 trial.8（來源 `ae1c5e05e5562cd0297bcf22abf2e06b3749836f`，ZIP SHA-256 `63A98B5B20F23F9470C2EFEA2DDBC0311ED2EE03EDFFC95AA0021221D73ACD53`，EXE SHA-256 `7444C1D946F9AF31B2C3EE37D8B12DB3F3BBEBE67F9707ACE16B338C20131C52`）。CI 試用產物 trial.ci.7（`c6951cf`）與 trial.8 的產品來源相同。

## 判定：有條件放行（使用者以發行維護者身分接受下列限制）

依票 11 原規則，所有必要 gate 通過後才重新做 RC 判定。本輪仍有 BLOCKED／NOT RUN 的必要 gate，**使用者以發行維護者（James）身分決定有條件放行**，接受下方限制清單為已知限制。

這不是發布：沒有建立 tag／release，沒有簽章，也沒有公開散布。`scripts/package.ps1` 的正式 RC 打包仍保留寫死的 readiness blocker（CI run 41396242703 已證實它會拒絕），本輪沒有修改，也沒有產出正式 RC 產物；要產出須另行決策（見票 16）。03／08-D1／09-D2 的原始 FAIL 永久保留。

## Gate 結果

| Gate | 本輪結果 | 證據 |
| --- | --- | --- |
| 09-G1／A14 CI | **PASS**：精確 SHA 的 Windows configure／build／CTest 53/53；gate 拒絕時沒有 RC 產物；試用產物由 CI 從精確 SHA 乾淨建置並驗證 | [CI.md](CI.md) |
| 09-G2／A03、A04、A08 桌面、電源、拔插、Explorer | **PASS**（大部分）。**PARTIAL** 兩項：S6 全螢幕全域暫停；S10 Explorer 重啟 1/3。**NOT RUN**（使用者決策略過）三項：S4、S5、S12 | [INTERACTIVE.md](INTERACTIVE.md) |
| 09-D2／A08 | 真實鎖定加手動暫停交錯 **PASS**（S13）；票 10 已記為未重現 | INTERACTIVE.md S13 |
| 09-G3／A12 安全剩餘矩陣 | **NOT RUN**（使用者決策本輪不做） | — |
| 09-G4／A05、A13 效能 | 100 次切換 **PASS**（失敗 0）；雙目標長測 52.5 分鐘依使用者決策的 30 分鐘門檻 **PASS**；資料完整性 **PARTIAL**（1 筆漏讀）；長測正式退出 **NOT RUN**（收尾操作失誤）；NVIDIA **BLOCKED** | [performance/REPORT.md](performance/REPORT.md) |
| 09-G5／A02、A10、A11 GUI 與作者 | 真實 GUI 匯入／切換／取消與確認移除／重新匯入 **PASS**（S8）；獨立作者 **BLOCKED** | INTERACTIVE.md S8 |
| 09-G6／A14 交付 | 乾淨機器與缺 Runtime／CRT **BLOCKED**；跨版更新／回復不適用（尚未發布）；移除／資料保留與主動清除 **NOT RUN**（使用者決策） | — |

## 已知限制清單（有條件放行的前提）

1. 全螢幕覆蓋單一螢幕時，所有螢幕一起暫停並露出 Windows 原桌布，與 handoff 的逐顯示器政策不一致（S6）。
2. 未簽章 EXE 可能被企業防毒攔截或警告；需確認來源 hash 並向 IT 申請例外。
3. WebView2 仍有 WPAD／Edge ECS 背景流量；不宣稱整個程序零外連或完整沙箱。
4. 只在本機驗證：Windows 11 25H2 26200.8737、WebView2 156.0.4314.58、Intel 內顯、雙 1920×1080（DPI 144／96）。其他 Windows／Runtime／硬體、NVIDIA、乾淨使用者環境都沒有驗證。
5. Explorer 真實重啟只驗 1 次；待機／喚醒、未鎖定關屏、關屏時啟動都沒有驗證。
6. 長測只有約 52 分鐘，而且是 Preview＋關閉智慧休眠模式；不宣稱沒有記憶體洩漏。
7. 安全剩餘邊界（完整 DNS、TURN、proxy、外部 URI handler、其他 Runtime、COM 競態）沒有驗證。
8. 免安裝 ZIP 的實際移除、資料保留與主動清除沒有驗證；沒有安裝器。
9. 管理日誌沒有時間戳記；手動暫停時標題顯示「display-off」，容易與真實關屏混淆（改善建議）。

剩餘項目由票 16 追蹤。
