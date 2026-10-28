#include "desktopmonitor/monitoring/cpu_usage.h"

using desktopmonitor::monitoring::CpuTimes;
using desktopmonitor::monitoring::CpuUsageCalculator;
using desktopmonitor::monitoring::CpuUsageQuality;

extern "C" int _fltused = 0;

extern "C" int TestEntry() {
    CpuUsageCalculator calculator;

    const auto first = calculator.Sample(CpuTimes{100, 200, 300});
    if (first.available || first.quality != CpuUsageQuality::Warmup) {
        return 1;
    }

    const auto knownInterval = calculator.Sample(CpuTimes{110, 240, 360});
    if (!knownInterval.available || knownInterval.quality != CpuUsageQuality::Available ||
        knownInterval.percent < 89.999 || knownInterval.percent > 90.001) {
        return 2;
    }

    const auto reset = calculator.Sample(CpuTimes{2, 4, 6});
    if (reset.available || reset.quality != CpuUsageQuality::CounterReset) {
        return 3;
    }

    const auto afterReset = calculator.Sample(CpuTimes{3, 8, 16});
    if (!afterReset.available || afterReset.percent < 92.85 || afterReset.percent > 92.86) {
        return 4;
    }

    const auto noInterval = calculator.Sample(CpuTimes{3, 8, 16});
    if (noInterval.available || noInterval.quality != CpuUsageQuality::NoInterval) {
        return 5;
    }

    const auto inconsistentCounters = calculator.Sample(CpuTimes{4, 8, 17});
    if (inconsistentCounters.available ||
        inconsistentCounters.quality != CpuUsageQuality::InvalidCounters) {
        return 6;
    }

    return 0;
}
