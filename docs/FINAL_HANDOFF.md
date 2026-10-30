# DrillPaper 驗收交接

更新：2026-10-30，RC 09。**拒絕 RC 放行；沒有合併 main、公開發布、release 或 tag。** 01／02／03／07／08 的 implemented 與 04／05／06／09 的 resolved 只表示各票可執行範圍及交接完成，不代表所有組態通過。完整版本、命令、證據與限制見 [RC 09 報告](acceptance/2026-10-30/rc-regression/REPORT.md)、[必要 gate 與 owner／下一步](acceptance/2026-10-30/rc-regression/GATES.md)及[人工清單](acceptance/2026-10-30/rc-regression/MANUAL_CHECKLIST.md)。

## 來源與套件

- 本票沿用 `feature/rc-09-regression`，base `d60816aff6e99ad1a3624075a74016909f76fa4d`；產品 C++／SDK 來源與 `676bb473efeca65614fddb40d98e3c88c302494b` 相同。新增測試啟動／隔離與觀測工具，移除新入口繞行；未做推測性產品修正。
- 08 原候選 `artifacts/DrillPaper-0.1.0-trial.6-win-x64-unsigned.zip` 保留不變，SHA-256 `FC08E190ACF481696F560CB7136478D9CF6E9DADF45E6EEF505CD62EB9EFF8A5`，入口仍關閉智慧休眠。
- 09 後續試用包 `artifacts/DrillPaper-0.1.0-trial.7-win-x64-unsigned.zip`，472507 bytes，SHA-256 `87FE10E27EB016D144F8C775BEEA4C81C724BD513BDDE61DE9F866465FDBC29D`；EXE 兩包均為 `993FD429AB8DCCC29A296651A9CA2E5DFAFE143C536871AEA69149BE0C2897DA`，NotSigned。53 檔相同，只改 CMD／README，另更新 manifest。產品／SDK 固定來源與本票工具逐檔 hash 分記，不宣稱位元可重現。
- 依票 08 已確認的本機多輪條件，以 trial.6 產品預設各三輪驗「不等待新 Preview 就緒即退出」及「保存後待握手／JS 回應」，全部通過後移除新入口 `--no-smart-sleep`。trial.7 真正 CMD 入口再驗三輪、六次退出通過。03／08-D1 歷史 FAIL 保留；本輪未重現不等於根因已修復或真實節能通過。保存為關閉的既有偏好不自動改寫。
- 本機最終 Release 建置 EXE 為 `25316B5067076749295B62DB557748B6DC2D88C4069CFBBE4C48E93269F6D26D`；編譯來源相同，獨立 archive 建置 EXE 的 hash 不同。完整 CTest 使用本機建置；候選整合使用 ZIP 內 EXE，兩者不混稱同一位元組。

## A01–A16

| ID | 本輪結果 | 證據及界線 |
| --- | --- | --- |
| A01 | PASS（本機建置／啟動） | Release configure／build、43/43 CTest 與候選包啟動；對應最終來源的乾淨 CI 缺證另列 A14。 |
| A02 | PARTIAL | 兩主題握手、保存／重啟與既有基本 Preview 人工證據保留；候選完整像素／DPI／獨立 MockHost 人工畫面 NOT RUN。 |
| A03 | PARTIAL | 候選首次唯一主螢幕完整 1920×1080 原生附掛；圖示／工作列／Alt+Tab／焦點／虛擬桌面及其他組態仍需人工。 |
| A04 | PARTIAL（候選） | 新多宿主 fixture 回復不能當真正 Explorer；歷史 a241856／62f01ab 的真正重啟人工 PASS 保留於原報告，本輪不重啟 Explorer。 |
| A05 | PARTIAL | 最終來源 collector 契約與本機 API CTest 通過；06 三負載各 30 同期窗口在原版本達容差，NVIDIA／高流量／介面消失等缺證。 |
| A06 | PASS（公開契約） | 背景 worker、停止／失敗／重設與 latest-wins 的最終來源測試通過，不外推逐次實機採集頻率。 |
| A07 | PASS（有界資料結構） | history／queue／mailbox／世代契約通過；不表示 WebView2 長期記憶體無洩漏。 |
| A08 | FAIL／PARTIAL | 09-D2：雙目標受控鎖定往返後解除手動暫停未恢復推送，原因未定，票 10 承接。產品預設多輪握手／保存／退出通過，03 FAIL 保留；真正 OS 事件與完整節能矩陣 NOT RUN。 |
| A09 | PASS（已測協定／原生流程） | 兩個內建主題、Dashboard 握手與既有熱切換／可信回復證據；完整人眼與候選 100 次切題長期資源另列缺口。 |
| A10 | PARTIAL | SDK 18/18、固定 TypeScript 5.9.3 正負 compiler／獨立作者建置與封裝；GUI、獨立作者及完整畫面仍缺證。 |
| A11 | PASS（公開驗證／CLI 範圍） | 最終 ThemeManager 與候選原六項 CLI 斷言、配額／路徑／manifest／junction；真實 GUI 操作及各 DPI 不由此建立。 |
| A12 | PARTIAL／必要 gate | Settings8 修正與指定安全證據保留；完整 DNS／TURN／proxy／handler／Runtime／真實舊 COM 競態不足，不宣稱沙箱或全程序零外連。 |
| A13 | PARTIAL／必要 gate | 06 五組共 664 筆、1805.80 秒長測及有限門檻通過，但有 3 筆資源缺失與記憶體上升；候選更長 soak／100 次切題／真實節能不足，不宣稱無洩漏。 |
| A14 | PARTIAL／必要 gate | 本機完整測試及試用 ZIP 清單／hash 通過，正式封裝 gate 阻擋；既有 CI 只對應舊 main、RC job skipped，最終來源 CI／app artifact 及真正乾淨機器 NOT RUN。 |
| A15 | PASS（文件範圍） | 安裝／使用／功能、作者工具、授權、安全、相容性、限制與本輪判定已整理；不是發行公告。 |
| A16 | PASS（交接範圍） | 逐項版本／命令／證據／未執行原因、owner／下一步及人工清單明列；原失敗不改寫。 |

## 重現建置、測試與 gate

本機 Windows 11 Pro 25H2 build 26200.8737、MSVC 19.44.35217、Windows SDK 10.0.26100、CMake 3.31.6、WebView2 SDK 1.0.2478.35／Runtime 156.0.4314.50、Intel Graphics、雙 1920×1080（DPI 144／96），有 Apex One／來源樹／開發工具，不是真正乾淨一般使用者環境。PATH 的 CMake Python 啟動器失效，本輪使用既有套件內原生 cmake.exe／ctest.exe，沒有改系統安裝。

```powershell
$env:PATH = 'C:/Users/James/AppData/Roaming/uv/tools/cmake/Lib/site-packages/cmake/data/bin;' + $env:PATH
cmake --preset windows-msvc-release
cmake --build --preset windows-msvc-release --config Release
pwsh -NoProfile -File scripts/test.ps1 -Configuration Release
ctest --preset windows-msvc-release -N
# 以下會再次建置／執行完整測試，再於必要發行 gate 拒絕產包。
pwsh -NoProfile -File scripts/package.ps1 -Configuration Release -Version 0.1.0-rc1
```

本輪完整套件由最後一條公開封裝入口實際呼叫 build.ps1／test.ps1：CTest **43/43**；SDK **18/18**，封裝鏈重複執行共四組 18/18（非 72 個獨立案例）；新啟動／隔離及入口契約 **6/6**。其他既有工具測試另跑 **17/17**。環境拒絕 CIM、取樣器完整／提前退出／未知 PID、主題 9 個正負與封裝情境、隔離變異 oracle、SDK ZIP 重封一致與解壓後兩主題驗證通過。正式 package exit 1 為預期 gate 拒絕，指定目的地未產生 ZIP。完整測試的 TEMP／TMP 及獨立 CTest 指向非 Temp 使用者繁中空白目錄；主題 CLI 由 Node 直接啟動，六項原斷言及 15 秒期限保留。

## 受限試用與作者流程

完整解壓核實的試用 ZIP 到非 Temp 使用者目錄，依包內 README 安裝已存在的 VC++ v14 x64／WebView2 Evergreen 依賴或向 IT 取得；不自動下載、提升權限或更改防毒。由 CMD 執行 Start-DrillPaper.cmd，首次只在主螢幕顯示 Minimal；保存 Preview 後相同入口重啟仍為 Preview。資料位於 LOCALAPPDATA/DrillPaper，免安裝 ZIP 不是完全隨身資料模式。更新／回復先正常退出、備份隔離資料與舊 ZIP；主動移除資料須明確選擇，真正乾淨機器流程仍 NOT RUN。詳細見 [試用流程](TRIAL_PACKAGE.md)及[使用手冊](USER_GUIDE.md)。

第三方主題僅匯入信任內容。複製包內 sdk/author-starter，依 README 執行 npm ci、configure、check、build，只把 dist 經包內 package-theme.ps1 打成 .dmt；工具固定 TypeScript 5.9.3，Node／compiler 不是產品 runtime 依賴。CLI 匯入 .dmt、管理視窗切換／移除，SDK 與 MockHost 詳見 [theme-sdk](theme-sdk.md)。

## 保留的版本化證據與決策

- 01 `0c97d4f` 多螢幕、02 `e6aa20e` 固定版面、03 `d64a11b` 試用包；[多目標](acceptance/2026-10-29/multi-monitor/REPORT.md)、[固定設定](acceptance/2026-10-29/fixed-settings/REPORT.md)、[03 歷史 FAIL](acceptance/2026-10-29/trial-package/REPORT.md)。
- 04 `2a69ed1` SmartScreen／安全、05 `c244682` 無回應主題有界回復、06 `1636972` 效能及硬體觀測、07 `f295106` SDK；[安全](acceptance/2026-10-30/security-matrix/REPORT.md)、[桌面電源](acceptance/2026-10-30/desktop-power-recovery/REPORT.md)、[效能](acceptance/2026-10-30/metrics-performance/REPORT.md)、[作者](acceptance/2026-10-30/theme-author-flow/REPORT.md)。
- 08 `d60816a` trial.6；[交付報告](acceptance/2026-10-30/delivery-final/REPORT.md)與[08-D1 原失敗](acceptance/2026-10-30/delivery/REPORT.md)。其他 hash 的結果不冒稱在候選重做。
- [ADR 0001–0005](adr/)記錄宿主回應、獨立來源、Connection-Allowlist、可信導覽回復及關閉 SmartScreen 信譽檢查的取捨。自有產品沒有遙測功能；WebView2 WPAD／Edge ECS 仍可能背景連網，完整沙箱未證實。
- 第一方 Apache-2.0；nlohmann-json 3.11.3、miniz 3.0.2、WebView2 SDK 1.0.2478.35 與第三方 notices／授權依原清單。完整 Evergreen／系統 CRT／NVML 不隨包散布，NotSigned 不冒稱簽章完成。
- 效能觀測包含 app＋已核實 WebView2 子程序；硬體使用公開 collector 與同機系統參考，非獨立儀器校準。[相容性](compatibility-matrix.md)、[安全限制](theme-security.md)、[效能方法](performance.md)及人工清單保留未測範圍。

原持續桌布 PID 83428 的固定 a241856 副本以路徑、UtcTicks 639288432499803524 及 hash 核對，沒有關閉／替換；未重啟 Explorer。只清理已確認身分的測試實例。
