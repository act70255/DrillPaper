#include "desktopmonitor/monitoring/network_rate.h"

using desktopmonitor::monitoring::CalculateNetworkRate;
using desktopmonitor::monitoring::NetworkRateQuality;

extern "C" int _fltused = 0;

extern "C" int TestEntry() {
    const auto knownInterval = CalculateNetworkRate(1000, 6000, 2500);
    if (!knownInterval.available || knownInterval.quality != NetworkRateQuality::Available ||
        knownInterval.bytesPerSecond < 1999.99 || knownInterval.bytesPerSecond > 2000.01) {
        return 1;
    }

    const auto idleInterface = CalculateNetworkRate(7000, 7000, 1000);
    if (!idleInterface.available || idleInterface.bytesPerSecond != 0.0) {
        return 2;
    }

    const auto reset = CalculateNetworkRate(5000, 1200, 1000);
    if (reset.available || reset.quality != NetworkRateQuality::CounterReset) {
        return 3;
    }

    const auto noInterval = CalculateNetworkRate(5000, 6000, 0);
    if (noInterval.available || noInterval.quality != NetworkRateQuality::NoInterval) {
        return 4;
    }
    return 0;
}
