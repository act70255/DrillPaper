#include "desktopmonitor/runtime/sampling_scheduler.h"

using desktopmonitor::runtime::SamplingScheduler;

extern "C" int TestEntry() {
    SamplingScheduler scheduler;
    scheduler.Configure(1000, 0, true);
    if (!scheduler.IsDue(0)) {
        return 1;
    }
    scheduler.MarkSampled(0);
    if (scheduler.IsDue(999) || !scheduler.IsDue(1000)) {
        return 2;
    }

    scheduler.Configure(5000, 1000, false);
    if (scheduler.IsDue(5999) || !scheduler.IsDue(6000)) {
        return 3;
    }

    scheduler.Configure(0, 6000, false);
    if (scheduler.IsDue(1000000)) {
        return 4;
    }

    scheduler.Configure(1000, 10000, true);
    if (!scheduler.IsDue(10000)) {
        return 5;
    }
    scheduler.MarkSampled(50000);
    if (scheduler.IsDue(50999) || !scheduler.IsDue(51000)) {
        return 6;
    }
    return 0;
}
