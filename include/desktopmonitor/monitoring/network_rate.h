#pragma once

namespace desktopmonitor::monitoring {

using NetworkByteCounter = unsigned __int64;

enum class NetworkRateQuality : unsigned char {
    Available,
    CounterReset,
    NoInterval
};

struct NetworkRate {
    double bytesPerSecond;
    bool available;
    NetworkRateQuality quality;
};

inline NetworkRate CalculateNetworkRate(NetworkByteCounter previousBytes,
                                        NetworkByteCounter currentBytes,
                                        unsigned __int64 elapsedMilliseconds) {
    if (currentBytes < previousBytes) {
        return {0.0, false, NetworkRateQuality::CounterReset};
    }
    if (elapsedMilliseconds == 0) {
        return {0.0, false, NetworkRateQuality::NoInterval};
    }

    const NetworkByteCounter difference = currentBytes - previousBytes;
    const double bytesPerSecond =
        static_cast<double>(difference) * 1000.0 / static_cast<double>(elapsedMilliseconds);
    return {bytesPerSecond, true, NetworkRateQuality::Available};
}

} // namespace desktopmonitor::monitoring
