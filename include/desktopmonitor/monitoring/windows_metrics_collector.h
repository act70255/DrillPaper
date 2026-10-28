#pragma once

#include "desktopmonitor/core/metrics_snapshot.h"
#include "desktopmonitor/monitoring/cpu_usage.h"
#include "desktopmonitor/monitoring/nvml_gpu_collector.h"
#include "desktopmonitor/monitoring/network_rate.h"

namespace desktopmonitor::monitoring {

class WindowsMetricsCollector final {
public:
    WindowsMetricsCollector();
    ~WindowsMetricsCollector();

    WindowsMetricsCollector(const WindowsMetricsCollector&) = delete;
    WindowsMetricsCollector& operator=(const WindowsMetricsCollector&) = delete;

    void Collect(core::MetricsSnapshot& snapshot);

private:
    CpuUsageCalculator cpuUsage_;
    NvmlGpuCollector gpuUsage_;
    void* diskQuery_ = nullptr;
    void* diskCounter_ = nullptr;
    NetworkByteCounter previousReceiveBytes_ = 0;
    NetworkByteCounter previousTransmitBytes_ = 0;
    unsigned __int64 previousNetworkTick_ = 0;
    bool hasNetworkBaseline_ = false;
};

} // namespace desktopmonitor::monitoring
