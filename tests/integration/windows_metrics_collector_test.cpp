#include <catch2/catch_test_macros.hpp>

#include <windows.h>

#include "desktopmonitor/core/metrics_snapshot.h"
#include "desktopmonitor/monitoring/windows_metrics_collector.h"

using desktopmonitor::core::MetricQuality;
using desktopmonitor::core::MetricUnit;
using desktopmonitor::core::MetricsSnapshot;
using desktopmonitor::monitoring::WindowsMetricsCollector;

TEST_CASE("Windows metrics collector reports typed readings and warms up CPU/network rates",
          "[integration][metrics]") {
    WindowsMetricsCollector collector;
    MetricsSnapshot first{};
    collector.Collect(first);

    REQUIRE(first.timestampUnixMilliseconds > 0);
    CHECK(first.cpuUsage.unit == MetricUnit::Percent);
    CHECK_FALSE(first.cpuUsage.hasValue);
    CHECK(first.memoryUsedBytes.unit == MetricUnit::Bytes);
    CHECK(first.memoryTotalBytes.unit == MetricUnit::Bytes);
    REQUIRE(first.memoryTotalBytes.quality == MetricQuality::Available);
    CHECK(first.memoryTotalBytes.value > 0.0);
    CHECK(first.memoryUsedBytes.quality == MetricQuality::Available);
    CHECK(first.memoryUsedBytes.value <= first.memoryTotalBytes.value);
    CHECK(first.gpuUsage.unit == MetricUnit::Percent);
    CHECK(first.diskActivityPercent.unit == MetricUnit::Percent);
    CHECK(first.networkReceiveBytesPerSecond.unit == MetricUnit::BytesPerSecond);
    CHECK(first.networkTransmitBytesPerSecond.unit == MetricUnit::BytesPerSecond);
    CHECK_FALSE(first.networkReceiveBytesPerSecond.hasValue);
    CHECK_FALSE(first.networkTransmitBytesPerSecond.hasValue);

    Sleep(100);
    MetricsSnapshot second{};
    collector.Collect(second);

    CHECK(second.timestampUnixMilliseconds >= first.timestampUnixMilliseconds);
    REQUIRE(second.cpuUsage.quality == MetricQuality::Available);
    CHECK(second.cpuUsage.value >= 0.0);
    CHECK(second.cpuUsage.value <= 100.0);
    CHECK(second.networkReceiveBytesPerSecond.unit == MetricUnit::BytesPerSecond);
    CHECK(second.networkTransmitBytesPerSecond.unit == MetricUnit::BytesPerSecond);
    if (second.networkReceiveBytesPerSecond.hasValue) {
        CHECK(second.networkReceiveBytesPerSecond.value >= 0.0);
    }
    if (second.networkTransmitBytesPerSecond.hasValue) {
        CHECK(second.networkTransmitBytesPerSecond.value >= 0.0);
    }
}
