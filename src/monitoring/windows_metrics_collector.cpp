#include <windows.h>
#include <ws2def.h>
#include <ws2ipdef.h>
#include <iphlpapi.h>
#include <netioapi.h>
#include <pdh.h>
#include <pdhmsg.h>

#include "desktopmonitor/monitoring/windows_metrics_collector.h"
#include "desktopmonitor/monitoring/network_rate.h"

namespace desktopmonitor::monitoring {
namespace {
using desktopmonitor::core::MakeAvailable;
using desktopmonitor::core::MakeError;
using desktopmonitor::core::MakeUnavailable;
using desktopmonitor::core::MetricUnit;

constexpr unsigned __int64 kWindowsToUnixEpoch100ns = 116444736000000000ULL;

unsigned __int64 CurrentUnixTimeMilliseconds() {
    FILETIME time{};
    GetSystemTimeAsFileTime(&time);
    ULARGE_INTEGER ticks{};
    ticks.LowPart = time.dwLowDateTime;
    ticks.HighPart = time.dwHighDateTime;
    if (ticks.QuadPart < kWindowsToUnixEpoch100ns) {
        return 0;
    }
    return (ticks.QuadPart - kWindowsToUnixEpoch100ns) / 10000ULL;
}

CpuTimes ToCpuTimes(const FILETIME& idle, const FILETIME& kernel, const FILETIME& user) {
    ULARGE_INTEGER idleTicks{};
    idleTicks.LowPart = idle.dwLowDateTime;
    idleTicks.HighPart = idle.dwHighDateTime;
    ULARGE_INTEGER kernelTicks{};
    kernelTicks.LowPart = kernel.dwLowDateTime;
    kernelTicks.HighPart = kernel.dwHighDateTime;
    ULARGE_INTEGER userTicks{};
    userTicks.LowPart = user.dwLowDateTime;
    userTicks.HighPart = user.dwHighDateTime;
    return {idleTicks.QuadPart, kernelTicks.QuadPart, userTicks.QuadPart};
}

core::MetricValue ReadCpu(CpuUsageCalculator& calculator) {
    FILETIME idle{};
    FILETIME kernel{};
    FILETIME user{};
    if (!GetSystemTimes(&idle, &kernel, &user)) {
        return MakeError(MetricUnit::Percent);
    }

    const CpuUsageReading reading = calculator.Sample(ToCpuTimes(idle, kernel, user));
    if (reading.available) {
        return MakeAvailable(reading.percent, MetricUnit::Percent);
    }
    if (reading.quality == CpuUsageQuality::InvalidCounters) {
        return MakeError(MetricUnit::Percent);
    }
    return MakeUnavailable(MetricUnit::Percent);
}

void ReadMemory(core::MetricValue* used, core::MetricValue* total) {
    if (used == nullptr || total == nullptr) {
        return;
    }
    MEMORYSTATUSEX status{};
    status.dwLength = sizeof(status);
    if (!GlobalMemoryStatusEx(&status) || status.ullTotalPhys == 0 ||
        status.ullTotalPhys < status.ullAvailPhys) {
        *used = MakeError(MetricUnit::Bytes);
        *total = MakeError(MetricUnit::Bytes);
        return;
    }
    *used = MakeAvailable(static_cast<double>(status.ullTotalPhys - status.ullAvailPhys),
                          MetricUnit::Bytes);
    *total = MakeAvailable(static_cast<double>(status.ullTotalPhys), MetricUnit::Bytes);
}

enum class NetworkReadResult {
    Available,
    NoPhysicalInterface,
    Error
};

NetworkReadResult ReadNetworkTotals(NetworkByteCounter* receiveBytes,
                                    NetworkByteCounter* transmitBytes) {
    PMIB_IF_TABLE2 table = nullptr;
    if (receiveBytes == nullptr || transmitBytes == nullptr || GetIfTable2(&table) != NO_ERROR ||
        table == nullptr) {
        return NetworkReadResult::Error;
    }

    NetworkByteCounter receive = 0;
    NetworkByteCounter transmit = 0;
    bool hasInterface = false;
    const NetworkByteCounter maximum = ~static_cast<NetworkByteCounter>(0);
    for (ULONG index = 0; index < table->NumEntries; ++index) {
        const MIB_IF_ROW2& row = table->Table[index];
        if (row.Type == IF_TYPE_SOFTWARE_LOOPBACK || row.OperStatus != IfOperStatusUp ||
            row.InterfaceAndOperStatusFlags.HardwareInterface == FALSE) {
            continue;
        }

        hasInterface = true;
        if (row.InOctets > maximum - receive || row.OutOctets > maximum - transmit) {
            FreeMibTable(table);
            return NetworkReadResult::Error;
        }
        receive += row.InOctets;
        transmit += row.OutOctets;
    }
    FreeMibTable(table);
    if (!hasInterface) {
        return NetworkReadResult::NoPhysicalInterface;
    }

    *receiveBytes = receive;
    *transmitBytes = transmit;
    return NetworkReadResult::Available;
}

core::MetricValue ReadDiskActivity(void* query, void* counter) {
    if (query == nullptr || counter == nullptr) {
        return MakeUnavailable(MetricUnit::Percent);
    }
    const PDH_HQUERY pdhQuery = static_cast<PDH_HQUERY>(query);
    const PDH_HCOUNTER pdhCounter = static_cast<PDH_HCOUNTER>(counter);
    if (PdhCollectQueryData(pdhQuery) != ERROR_SUCCESS) {
        return MakeError(MetricUnit::Percent);
    }

    PDH_FMT_COUNTERVALUE value{};
    DWORD counterType = 0;
    const PDH_STATUS status = PdhGetFormattedCounterValue(
        pdhCounter, PDH_FMT_DOUBLE, &counterType, &value);
    if (status != ERROR_SUCCESS) {
        return MakeError(MetricUnit::Percent);
    }
    if ((value.CStatus != PDH_CSTATUS_VALID_DATA && value.CStatus != PDH_CSTATUS_NEW_DATA) ||
        value.doubleValue < 0.0 || value.doubleValue > 100.0) {
        return MakeUnavailable(MetricUnit::Percent);
    }
    return MakeAvailable(value.doubleValue, MetricUnit::Percent);
}
} // namespace

WindowsMetricsCollector::WindowsMetricsCollector() {
    PDH_HQUERY query = nullptr;
    PDH_HCOUNTER counter = nullptr;
    if (PdhOpenQueryW(nullptr, 0, &query) != ERROR_SUCCESS) {
        return;
    }
    if (PdhAddEnglishCounterW(query, L"\\PhysicalDisk(_Total)\\% Disk Time", 0, &counter) !=
        ERROR_SUCCESS) {
        PdhCloseQuery(query);
        return;
    }
    PdhCollectQueryData(query);
    diskQuery_ = query;
    diskCounter_ = counter;
}

WindowsMetricsCollector::~WindowsMetricsCollector() {
    if (diskQuery_ != nullptr) {
        PdhCloseQuery(static_cast<PDH_HQUERY>(diskQuery_));
    }
}

void WindowsMetricsCollector::Collect(core::MetricsSnapshot& snapshot) {
    snapshot.timestampUnixMilliseconds = CurrentUnixTimeMilliseconds();
    snapshot.cpuUsage = ReadCpu(cpuUsage_);
    ReadMemory(&snapshot.memoryUsedBytes, &snapshot.memoryTotalBytes);
    snapshot.gpuUsage = gpuUsage_.ReadGpuUtilization();
    snapshot.diskActivityPercent = ReadDiskActivity(diskQuery_, diskCounter_);

    NetworkByteCounter receiveBytes = 0;
    NetworkByteCounter transmitBytes = 0;
    const NetworkReadResult readResult = ReadNetworkTotals(&receiveBytes, &transmitBytes);
    if (readResult == NetworkReadResult::Error) {
        hasNetworkBaseline_ = false;
        snapshot.networkReceiveBytesPerSecond = MakeError(core::MetricUnit::BytesPerSecond);
        snapshot.networkTransmitBytesPerSecond = MakeError(core::MetricUnit::BytesPerSecond);
        return;
    }
    if (readResult == NetworkReadResult::NoPhysicalInterface) {
        hasNetworkBaseline_ = false;
        snapshot.networkReceiveBytesPerSecond = MakeUnavailable(core::MetricUnit::BytesPerSecond);
        snapshot.networkTransmitBytesPerSecond = MakeUnavailable(core::MetricUnit::BytesPerSecond);
        return;
    }

    const unsigned __int64 now = GetTickCount64();
    if (!hasNetworkBaseline_) {
        previousReceiveBytes_ = receiveBytes;
        previousTransmitBytes_ = transmitBytes;
        previousNetworkTick_ = now;
        hasNetworkBaseline_ = true;
        snapshot.networkReceiveBytesPerSecond = MakeUnavailable(core::MetricUnit::BytesPerSecond);
        snapshot.networkTransmitBytesPerSecond = MakeUnavailable(core::MetricUnit::BytesPerSecond);
        return;
    }

    const NetworkRate receiveRate = CalculateNetworkRate(
        previousReceiveBytes_, receiveBytes, now - previousNetworkTick_);
    const NetworkRate transmitRate = CalculateNetworkRate(
        previousTransmitBytes_, transmitBytes, now - previousNetworkTick_);
    previousReceiveBytes_ = receiveBytes;
    previousTransmitBytes_ = transmitBytes;
    previousNetworkTick_ = now;

    snapshot.networkReceiveBytesPerSecond = receiveRate.available
        ? MakeAvailable(receiveRate.bytesPerSecond, core::MetricUnit::BytesPerSecond)
        : MakeUnavailable(core::MetricUnit::BytesPerSecond);
    snapshot.networkTransmitBytesPerSecond = transmitRate.available
        ? MakeAvailable(transmitRate.bytesPerSecond, core::MetricUnit::BytesPerSecond)
        : MakeUnavailable(core::MetricUnit::BytesPerSecond);
}

} // namespace desktopmonitor::monitoring
