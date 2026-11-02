#include <windows.h>
#include <ws2def.h>
#include <ws2ipdef.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <psapi.h>
#include <nlohmann/json.hpp>
#include <atomic>
#include <chrono>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <vector>
#include "desktopmonitor/monitoring/windows_metrics_collector.h"

namespace {
using Json = nlohmann::json;
using Clock = std::chrono::steady_clock;

/** 保留品質與單位，未取得讀值時輸出 null。
 * Args:
 *     metric: 公開 collector 的單一指標。
 * Returns:
 *     不混淆 unavailable 與真正零的 JSON。
 */
Json Metric(const desktopmonitor::core::MetricValue& metric) {
    return {{"value", metric.hasValue ? Json(metric.value) : Json(nullptr)},
            {"hasValue", metric.hasValue}, {"quality", static_cast<int>(metric.quality)},
            {"unit", static_cast<int>(metric.unit)}};
}

/** 讀取獨立 PDH query 的格式化數值，失敗保留原始狀態。
 * Args:
 *     counter: 參考 counter handle。
 * Returns:
 *     數值或 null，以及 PDH 狀態。
 */
Json Counter(PDH_HCOUNTER counter) {
    PDH_FMT_COUNTERVALUE value{};
    const auto status = PdhGetFormattedCounterValue(counter, PDH_FMT_DOUBLE, nullptr, &value);
    const bool valid = status == ERROR_SUCCESS &&
        (value.CStatus == PDH_CSTATUS_VALID_DATA || value.CStatus == PDH_CSTATUS_NEW_DATA);
    return {{"value", valid ? Json(value.doubleValue) : Json(nullptr)},
            {"status", status}, {"counterStatus", value.CStatus}};
}

/** 以逐介面 API 讀取啟用硬體網卡，與產品彙總 API 交叉核對。
 * Returns:
 *     實體介面身分與累積 octets；沒有設備或查詢錯誤明確標記。
 */
Json Network() {
    PMIB_IF_TABLE2 table = nullptr;
    const auto status = GetIfTable2(&table);
    if (status != NO_ERROR || !table) return {{"status", status}, {"interfaces", Json::array()}};
    Json rows = Json::array();
    for (ULONG index = 0; index < table->NumEntries; ++index) {
        MIB_IF_ROW2 row{};
        row.InterfaceLuid = table->Table[index].InterfaceLuid;
        const auto readStatus = GetIfEntry2(&row);
        if (readStatus != NO_ERROR) {
            rows.push_back({{"luid", row.InterfaceLuid.Value}, {"status", readStatus}});
        } else if (row.Type != IF_TYPE_SOFTWARE_LOOPBACK && row.OperStatus == IfOperStatusUp &&
                   row.InterfaceAndOperStatusFlags.HardwareInterface) {
            rows.push_back({{"luid", row.InterfaceLuid.Value}, {"status", readStatus},
                {"receive", row.InOctets}, {"transmit", row.OutOctets}});
        }
    }
    FreeMibTable(table);
    return {{"status", status}, {"tick", GetTickCount64()}, {"interfaces", rows}};
}

/** 執行有界的同期硬體觀測，僅寫入明確指定的新檔案。
 * Args:
 *     output: 不可已存在的 JSONL 證據檔。
 * Returns:
 *     完整收集回傳 0；精度由獨立分析判定，不假冒測試 PASS。
 */
int Observe(const std::filesystem::path& output) {
    if (!output.is_absolute() || std::filesystem::exists(output))
        throw std::runtime_error("證據必須是尚不存在的完整絕對路徑。");
    std::ofstream stream(output, std::ios::binary);
    if (!stream) throw std::runtime_error("無法建立硬體精度證據。");
    PDH_HQUERY query = nullptr;
    PDH_HCOUNTER cpu = nullptr, disk = nullptr;
    if (PdhOpenQueryW(nullptr, 0, &query) != ERROR_SUCCESS)
        throw std::runtime_error("無法建立系統參考計數器查詢。");
    try {
        if (PdhAddEnglishCounterW(query, L"\\Processor(_Total)\\% Processor Time", 0, &cpu) != ERROR_SUCCESS ||
            PdhAddEnglishCounterW(query, L"\\PhysicalDisk(_Total)\\% Disk Time", 0, &disk) != ERROR_SUCCESS)
            throw std::runtime_error("無法建立 CPU／磁碟參考計數器。");
        desktopmonitor::monitoring::WindowsMetricsCollector collector;
        desktopmonitor::core::MetricsSnapshot snapshot{};
        const auto start = Clock::now();
        const auto scratch = output.parent_path() / L"accuracy-workload.bin";
        if (std::filesystem::exists(scratch)) throw std::runtime_error("負載檔已存在，拒絕覆寫。");
        for (int phase = 0; phase < 3; ++phase) {
            std::vector<char> memory;
            std::ofstream load;
            if (phase == 2) {
                memory.resize(64 * 1024 * 1024, 0x5a);
                load.open(scratch, std::ios::binary);
                if (!load) throw std::runtime_error("無法建立受控磁碟負載。");
                load.write(memory.data(), static_cast<std::streamsize>(memory.size()));
                load.flush();
            }
            std::jthread busy([phase](std::stop_token stop) {
                if (phase != 1) return;
                while (!stop.stop_requested()) {
                    std::atomic_signal_fence(std::memory_order_seq_cst);
                }
            });
            // 先完成 provider／介面冷啟動；正式基準仍記錄雙端點 skew。
            collector.Collect(snapshot);
            if (PdhCollectQueryData(query) != ERROR_SUCCESS) throw std::runtime_error("參考計數器預備採集失敗。");
            Network();
            std::this_thread::sleep_for(std::chrono::seconds(1));
            const auto baselineStart = Clock::now();
            collector.Collect(snapshot);
            if (PdhCollectQueryData(query) != ERROR_SUCCESS) throw std::runtime_error("參考計數器暖機失敗。");
            const auto baselineNetwork = Network();
            const auto baselineSkew = std::chrono::duration<double, std::milli>(Clock::now() - baselineStart).count();
            stream << Json{{"phase", phase}, {"baseline", true}, {"skewMilliseconds", baselineSkew}, {"network", baselineNetwork}}.dump() << '\n';
            for (int index = 0; index < 30; ++index) {
                std::this_thread::sleep_for(std::chrono::seconds(1));
                if (phase == 2) {
                    load.seekp((index % 32) * 2 * 1024 * 1024);
                    load.write(memory.data(), 2 * 1024 * 1024); load.flush();
                    if (!load) throw std::runtime_error("受控磁碟負載寫入失敗。");
                }
                const auto before = Clock::now();
                collector.Collect(snapshot);
                const auto collected = Clock::now();
                const auto queryStatus = PdhCollectQueryData(query);
                PERFORMANCE_INFORMATION info{}; info.cb = sizeof(info);
                const bool memoryValid = GetPerformanceInfo(&info, sizeof(info)) != FALSE;
                auto network = Network();
                const auto after = Clock::now();
                Json row{{"phase", phase}, {"sample", index}, {"utcMilliseconds", snapshot.timestampUnixMilliseconds},
                    {"seconds", std::chrono::duration<double>(after - start).count()},
                    {"collectorMilliseconds", std::chrono::duration<double, std::milli>(collected - before).count()},
                    {"skewMilliseconds", std::chrono::duration<double, std::milli>(after - before).count()},
                    {"cpu", Metric(snapshot.cpuUsage)}, {"memoryUsed", Metric(snapshot.memoryUsedBytes)},
                    {"memoryTotal", Metric(snapshot.memoryTotalBytes)}, {"disk", Metric(snapshot.diskActivityPercent)},
                    {"receive", Metric(snapshot.networkReceiveBytesPerSecond)}, {"transmit", Metric(snapshot.networkTransmitBytesPerSecond)},
                    {"gpu", Metric(snapshot.gpuUsage)}, {"referenceQueryStatus", queryStatus},
                    {"referenceCpu", Counter(cpu)}, {"referenceDisk", Counter(disk)}, {"referenceNetwork", network},
                    {"referenceMemory", {{"valid", memoryValid}, {"pageSize", info.PageSize},
                        {"total", info.PhysicalTotal * info.PageSize},
                        {"used", (info.PhysicalTotal - info.PhysicalAvailable) * info.PageSize}}}};
                stream << row.dump() << '\n'; stream.flush();
                if (!stream) throw std::runtime_error("硬體證據寫入失敗。");
            }
            busy.request_stop();
            if (load.is_open()) load.close();
        }
        PdhCloseQuery(query);
        std::filesystem::remove(scratch);
        return 0;
    } catch (...) { PdhCloseQuery(query); throw; }
}
}

/** 硬體驗收工具入口，將錯誤轉為繁中提示及詳細日誌。
 * Args:
 *     argc: 引數數量。
 *     argv: 輸出證據絕對路徑。
 * Returns:
 *     0 表示收集完成，1 表示工具未完成。
 */
int wmain(int argc, wchar_t** argv) {
    try {
        SetConsoleOutputCP(CP_UTF8);
        if (argc != 2) throw std::runtime_error("必須指定硬體精度 JSONL 證據的完整路徑。");
        return Observe(std::filesystem::path(argv[1]));
    } catch (const std::exception& error) {
        bool recorded = false;
        try {
            if (argc == 2) {
                const std::filesystem::path output(argv[1]);
                const std::filesystem::path diagnostic(output.wstring() + L".failure.log");
                if (output.is_absolute() && !std::filesystem::exists(diagnostic)) {
                    std::ofstream log(diagnostic, std::ios::binary);
                    log << error.what() << '\n';
                    recorded = static_cast<bool>(log);
                }
            }
        } catch (...) { }
        std::cerr << "錯誤：硬體精度觀測未完成，請指定新的完整輸出路徑並確認系統計數器可用。"
                  << (recorded ? "詳細原因已記錄於同路徑的 .failure.log。" : "未能建立新的詳細日誌。") << '\n';
        return 1;
    }
}
