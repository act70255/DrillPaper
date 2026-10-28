#pragma once

namespace desktopmonitor::core {

enum class MetricUnit : unsigned char {
    Percent,
    Bytes,
    BytesPerSecond,
    Celsius
};

enum class MetricQuality : unsigned char {
    Available,
    Unavailable,
    Stale,
    Error
};

struct MetricValue {
    double value = 0.0;
    MetricUnit unit = MetricUnit::Percent;
    MetricQuality quality = MetricQuality::Unavailable;
    bool hasValue = false;
};

constexpr MetricValue MakeAvailable(double value, MetricUnit unit) {
    return {value, unit, MetricQuality::Available, true};
}

constexpr MetricValue MakeStale(double value, MetricUnit unit) {
    return {value, unit, MetricQuality::Stale, true};
}

constexpr MetricValue MakeUnavailable(MetricUnit unit) {
    return {0.0, unit, MetricQuality::Unavailable, false};
}

constexpr MetricValue MakeError(MetricUnit unit) {
    return {0.0, unit, MetricQuality::Error, false};
}

struct MetricsSnapshot {
    unsigned __int64 timestampUnixMilliseconds = 0;
    MetricValue cpuUsage = MakeUnavailable(MetricUnit::Percent);
    MetricValue gpuUsage = MakeUnavailable(MetricUnit::Percent);
    MetricValue memoryUsedBytes = MakeUnavailable(MetricUnit::Bytes);
    MetricValue memoryTotalBytes = MakeUnavailable(MetricUnit::Bytes);
    MetricValue diskActivityPercent = MakeUnavailable(MetricUnit::Percent);
    MetricValue networkReceiveBytesPerSecond = MakeUnavailable(MetricUnit::BytesPerSecond);
    MetricValue networkTransmitBytesPerSecond = MakeUnavailable(MetricUnit::BytesPerSecond);
};

} // namespace desktopmonitor::core
