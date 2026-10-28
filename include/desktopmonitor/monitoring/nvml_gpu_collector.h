#pragma once

#include "desktopmonitor/core/metrics_snapshot.h"

namespace desktopmonitor::monitoring {

class NvmlGpuCollector final {
public:
    NvmlGpuCollector();
    ~NvmlGpuCollector();

    NvmlGpuCollector(const NvmlGpuCollector&) = delete;
    NvmlGpuCollector& operator=(const NvmlGpuCollector&) = delete;

    core::MetricValue ReadGpuUtilization();

private:
    void* library_ = nullptr;
    void* deviceCountFunction_ = nullptr;
    void* deviceHandleFunction_ = nullptr;
    void* utilizationFunction_ = nullptr;
    void* shutdownFunction_ = nullptr;
    bool initialized_ = false;
};

} // namespace desktopmonitor::monitoring
