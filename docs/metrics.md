# 指標與採集器定義

## Snapshot 契約

`MetricValue` 含單位、品質與 `hasValue`。有效讀到零時 `hasValue=true` 且品質為 `Available`；感測器無讀值時 `hasValue=false` 且品質為 `Unavailable`。bytes 總量/速率使用 `bytes`、`bytes_per_second`；CPU、GPU、磁碟活動使用 `percent`。

`MetricsSnapshot` 是可複製的純值。採集器填入新的 snapshot；完成的 snapshot 應視為不可變。時間戳記是 UTC Unix milliseconds。網路速率用單調遞增的 `GetTickCount64` 計時，牆上時鐘調整不會改變速率差值。

## 原生採集器設計

- CPU：`GetSystemTimes` 差值。Kernel counter 包含 idle，因此 busy 百分比為 `(kernelDelta + userDelta - idleDelta) / (kernelDelta + userDelta) * 100`。第一次讀值、counter reset 或零間隔不產生假數字；純差值計算器已有可執行 MSVC bootstrap 測試。
- Memory：`GlobalMemoryStatusEx`；已用實體記憶體為 `ullTotalPhys - ullAvailPhys`，總量為 `ullTotalPhys`。兩值來自同一次 API 呼叫。
- Network：彙總 `GetIfTable2` 回傳的啟用硬體介面 bytes，排除軟體 loopback。使用 byte counter 差值除以 `GetTickCount64` 經過的 milliseconds 計算速率。沒有介面、第一次採樣、counter reset、零間隔都不回報可用讀值。
- Disk：PDH `\\PhysicalDisk(_Total)\\% Disk Time`，使用 `PdhAddEnglishCounterW` 保持 counter 名稱跨語系一致。單位是實體磁碟彙總的忙碌百分比；無法建立 counter 或讀值無效時保持 unavailable。
- GPU：選用動態 NVML adapter 讀取第一張可存取的 NVIDIA 裝置。缺 NVML 或沒有可存取裝置時回報 unavailable；不打包供應商 DLL。`nvidia-smi` 成功不代表這個 adapter 已通過測試。

## 驗證證據界線

RC06已新增三種負載各30個同期窗口，CPU／RAM／實體網路自然流量及PDH磁碟counter均達事先定義的單位／容差。參考API、原始讀值、skew、負載、工具版本與限制見 [RC06報告](acceptance/2026-10-30/metrics-performance/REPORT.md)。這是同機OS來源交叉核對，非獨立儀器校準；網路高流量／介面消失及NVIDIA仍NOT RUN，不能因unavailable契約或Intel GPU Engine可讀而判NVML通過。下列21/21為舊版本歷史範圍，不取代新證據。

CTest 21/21 已由 MSVC 19.41.34120/CMake Release build 實際執行。Windows collectors integration test 呼叫本機 CPU/RAM/Network/Disk API，檢查 typed readings 及 CPU/network warm-up。這只證明 API 有回報合法型別/品質並通過該整合測試，沒有以獨立工具或受控 workload 核對數值精度；GPU/NVML adapter 尚無產品硬體測試。WebView2 smoke 僅驗證 snapshot protocol 流程，不作為指標正確性證據。

## 官方 API 參考

- Microsoft [`GetSystemTimes`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getsystemtimes)：kernel time 包含 idle time。
- Microsoft [`MEMORYSTATUSEX`](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex)：實體記憶體欄位的單位是 bytes。
- Microsoft [`GetIfTable2`](https://learn.microsoft.com/en-us/windows/win32/api/netioapi/nf-netioapi-getiftable2)：記憶體透過 `FreeMibTable` 釋放。
- Microsoft [`PdhAddEnglishCounterW`](https://learn.microsoft.com/en-us/windows/win32/api/pdh/nf-pdh-pdhaddenglishcounterw)：提供跨語系 counter 名稱；[`Collecting Performance Data`](https://learn.microsoft.com/en-us/windows/win32/perfctrs/collecting-performance-data) 說明 rate counter 需要多次採樣。
- NVIDIA [NVML API Reference](https://docs.nvidia.com/deploy/nvml-api/nvml-api-reference.html)：Windows library 路徑與裝置查詢方法。
- Microsoft [`LoadLibraryEx`](https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-loadlibraryexa)：說明 NVML loader 使用的 `LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR` 與 `LOAD_LIBRARY_SEARCH_SYSTEM32`。
