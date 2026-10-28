#include "desktopmonitor/runtime/change_detector.h"
#include "desktopmonitor/runtime/latest_value_coalescer.h"

using desktopmonitor::core::MakeAvailable;
using desktopmonitor::core::MakeUnavailable;
using desktopmonitor::core::MetricUnit;
using desktopmonitor::core::MetricsSnapshot;
using desktopmonitor::runtime::LatestValueCoalescer;
using desktopmonitor::runtime::MetricChangeDetector;

extern "C" int _fltused = 0;

extern "C" int TestEntry() {
    MetricChangeDetector detector;
    const auto previous = MakeAvailable(50.0, MetricUnit::Percent);
    if (detector.HasMeaningfulChange(previous, MakeAvailable(50.4, MetricUnit::Percent), 1.0)) {
        return 1;
    }
    if (!detector.HasMeaningfulChange(previous, MakeAvailable(51.0, MetricUnit::Percent), 1.0)) {
        return 2;
    }
    if (!detector.HasMeaningfulChange(previous, MakeUnavailable(MetricUnit::Percent), 1.0)) {
        return 3;
    }

    LatestValueCoalescer<MetricsSnapshot> queue;
    MetricsSnapshot first{};
    first.cpuUsage = MakeAvailable(10.0, MetricUnit::Percent);
    MetricsSnapshot latest{};
    latest.cpuUsage = MakeAvailable(70.0, MetricUnit::Percent);
    queue.Publish(first);
    queue.Publish(latest);
    if (queue.PendingCount() != 1) {
        return 4;
    }
    MetricsSnapshot delivered{};
    if (!queue.TryTake(&delivered) || delivered.cpuUsage.value != 70.0) {
        return 5;
    }
    if (queue.PendingCount() != 0 || queue.TryTake(&delivered)) {
        return 6;
    }
    return 0;
}
