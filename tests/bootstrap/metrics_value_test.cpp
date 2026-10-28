#include "desktopmonitor/core/metrics_snapshot.h"

using desktopmonitor::core::MakeAvailable;
using desktopmonitor::core::MakeUnavailable;
using desktopmonitor::core::MetricQuality;
using desktopmonitor::core::MetricUnit;
using desktopmonitor::core::MetricsSnapshot;

extern "C" int _fltused = 0;

extern "C" int TestEntry() {
    const auto realZero = MakeAvailable(0.0, MetricUnit::Percent);
    if (!realZero.hasValue || realZero.quality != MetricQuality::Available ||
        realZero.unit != MetricUnit::Percent || realZero.value != 0.0) {
        return 1;
    }

    const auto missingGpu = MakeUnavailable(MetricUnit::Percent);
    if (missingGpu.hasValue || missingGpu.quality != MetricQuality::Unavailable ||
        missingGpu.unit != MetricUnit::Percent) {
        return 2;
    }

    const MetricsSnapshot initial{};
    if (initial.cpuUsage.hasValue || initial.cpuUsage.quality != MetricQuality::Unavailable ||
        initial.cpuUsage.unit != MetricUnit::Percent) {
        return 3;
    }
    if (initial.memoryUsedBytes.unit != MetricUnit::Bytes ||
        initial.networkReceiveBytesPerSecond.unit != MetricUnit::BytesPerSecond ||
        initial.networkTransmitBytesPerSecond.unit != MetricUnit::BytesPerSecond) {
        return 4;
    }
    return 0;
}
