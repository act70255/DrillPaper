# ADR 0006：靜態連結 C/C++ 執行環境（/MT）

日期：2026-11-03。狀態：使用者已確認（票 17 決策 1），已採用並驗證。

## 問題與決策

原本 app 以 `/MD` 動態連結 CRT，需要使用者電腦已安裝 Microsoft Visual C++ 2015-2022 x64 可轉散發套件；試用入口因此要檢查 VC++ 版本，缺少時提示使用者另行安裝。票 17 要做使用者層級、不需管理員權限的安裝檔，而 VC++ 可轉散發套件的安裝需要管理員權限，兩者衝突。

決策：全專案（含 FetchContent 相依與測試）以 `CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded$<$<CONFIG:Debug>:Debug>` 靜態連結 CRT，app 不再依賴 VC++ 可轉散發套件或 UCRT DLL。

## 考慮過的替代方案

- **安裝檔隨附 VC++ 可轉散發套件**：需要管理員權限，違反「使用者層級、免提權」；安裝檔多約 25 MB。
- **維持 /MD，只檢查並提示**：使用者在缺依賴時要自行找管理員安裝，交付體驗差，且無法保證乾淨環境可用。

## 取捨

- EXE 由 694,272 bytes（trial.8，/MD）增為 943,616 bytes（trial.11，/MT），約多 244 KB；CRT 安全更新改為需要重新建置 app，不再隨 Windows Update 更新系統 CRT。
- 所有靜態連結的元件必須使用同一種 runtime，否則連結失敗（LNK2038）；以全域設定統一處理。
- `WebView2Loader.dll` 是 Microsoft 提供的元件，本身只匯入 KERNEL32，不受影響。

## 驗證與把關

- `scripts/check-pe-imports.mjs` 解析 PE 一般與 delay-load 匯入表，發現 VCRUNTIME／MSVCP／CONCRT／VCOMP／api-ms-win-crt-*／ucrtbase 即失敗。
- CTest `DrillPaperStaticCrt` 檢查 `DrillPaper.exe` 與 `WebView2Loader.dll`；`build-trial.ps1` 封裝前也執行同一檢查，fail-fast。
- 改動前以 /MD 的 EXE 取得 Red（匯入 MSVCP140、VCRUNTIME140／140_1 與 9 個 api-ms-win-crt-*），改動後 Green；完整測試套件通過。證據見 `docs/acceptance/2026-11-02/installer/REPORT.md`。
