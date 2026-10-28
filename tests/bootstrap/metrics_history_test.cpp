#include "desktopmonitor/runtime/metrics_history.h"

using desktopmonitor::core::MetricsSnapshot;
using desktopmonitor::runtime::MetricsHistory;

extern "C" int _fltused = 0;

extern "C" int TestEntry() {
    static MetricsHistory history;
    for (unsigned __int64 value = 0; value < 121; ++value) {
        MetricsSnapshot snapshot{};
        snapshot.timestampUnixMilliseconds = value;
        history.Push(snapshot);
    }
    if (history.Size() != 120 || history.Capacity() != 120) {
        return 1;
    }

    MetricsSnapshot oldest{};
    MetricsSnapshot newest{};
    if (!history.TryGetOldest(0, &oldest) || oldest.timestampUnixMilliseconds != 1) {
        return 2;
    }
    if (!history.TryGetOldest(119, &newest) || newest.timestampUnixMilliseconds != 120) {
        return 3;
    }
    return 0;
}
