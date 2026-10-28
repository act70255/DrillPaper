#include <catch2/catch_test_macros.hpp>
#include <catch2/catch_approx.hpp>

#include "desktopmonitor/core/metrics_snapshot.h"
#include "desktopmonitor/monitoring/cpu_usage.h"
#include "desktopmonitor/monitoring/network_rate.h"
#include "desktopmonitor/runtime/change_detector.h"
#include "desktopmonitor/runtime/latest_value_coalescer.h"
#include "desktopmonitor/runtime/metrics_history.h"
#include "desktopmonitor/runtime/power_state_machine.h"
#include "desktopmonitor/runtime/sampling_scheduler.h"

using desktopmonitor::core::MakeAvailable;
using desktopmonitor::core::MetricQuality;
using desktopmonitor::core::MetricUnit;
using desktopmonitor::core::MetricsSnapshot;
using desktopmonitor::monitoring::CalculateNetworkRate;
using desktopmonitor::monitoring::CpuTimes;
using desktopmonitor::monitoring::CpuUsageCalculator;
using desktopmonitor::monitoring::CpuUsageQuality;
using desktopmonitor::monitoring::NetworkRateQuality;
using desktopmonitor::runtime::LatestValueCoalescer;
using desktopmonitor::runtime::MetricChangeDetector;
using desktopmonitor::runtime::MetricsHistory;
using desktopmonitor::runtime::PowerState;
using desktopmonitor::runtime::PowerStateMachine;
using desktopmonitor::runtime::SamplingScheduler;

TEST_CASE("CPU sampling marks the first reading as warm-up", "[metrics][cpu]") {
    CpuUsageCalculator calculator;
    const auto first = calculator.Sample(CpuTimes{100, 200, 300});

    CHECK_FALSE(first.available);
    CHECK(first.quality == CpuUsageQuality::Warmup);
}

TEST_CASE("CPU sampling derives busy time from GetSystemTimes deltas", "[metrics][cpu]") {
    CpuUsageCalculator calculator;
    calculator.Sample(CpuTimes{100, 200, 300});

    const auto reading = calculator.Sample(CpuTimes{110, 240, 360});

    REQUIRE(reading.available);
    CHECK(reading.percent == Catch::Approx(90.0));
}

TEST_CASE("CPU sampling resets its baseline after counters decrease", "[metrics][cpu]") {
    CpuUsageCalculator calculator;
    calculator.Sample(CpuTimes{100, 200, 300});
    calculator.Sample(CpuTimes{110, 240, 360});

    const auto reset = calculator.Sample(CpuTimes{2, 4, 6});
    const auto next = calculator.Sample(CpuTimes{3, 8, 16});

    CHECK_FALSE(reset.available);
    CHECK(reset.quality == CpuUsageQuality::CounterReset);
    REQUIRE(next.available);
    CHECK(next.percent == Catch::Approx(92.857142857).epsilon(0.0001));
}

TEST_CASE("A real zero metric differs from an unavailable metric", "[metrics][contract]") {
    const auto zero = MakeAvailable(0.0, MetricUnit::Percent);
    const MetricsSnapshot snapshot{};

    CHECK(zero.hasValue);
    CHECK(zero.quality == MetricQuality::Available);
    CHECK(zero.value == 0.0);
    CHECK_FALSE(snapshot.gpuUsage.hasValue);
    CHECK(snapshot.gpuUsage.quality == MetricQuality::Unavailable);
}

TEST_CASE("Snapshot units describe byte counts and byte rates", "[metrics][contract]") {
    const MetricsSnapshot snapshot{};

    CHECK(snapshot.memoryUsedBytes.unit == MetricUnit::Bytes);
    CHECK(snapshot.memoryTotalBytes.unit == MetricUnit::Bytes);
    CHECK(snapshot.networkReceiveBytesPerSecond.unit == MetricUnit::BytesPerSecond);
    CHECK(snapshot.networkTransmitBytesPerSecond.unit == MetricUnit::BytesPerSecond);
}

TEST_CASE("Network rate uses monotonic counter deltas and elapsed time", "[metrics][network]") {
    const auto reading = CalculateNetworkRate(1000, 6000, 2500);

    REQUIRE(reading.available);
    CHECK(reading.quality == NetworkRateQuality::Available);
    CHECK(reading.bytesPerSecond == Catch::Approx(2000.0));
}

TEST_CASE("An idle network interface is a valid zero rate", "[metrics][network]") {
    const auto reading = CalculateNetworkRate(7000, 7000, 1000);

    REQUIRE(reading.available);
    CHECK(reading.bytesPerSecond == 0.0);
}

TEST_CASE("Network rate rejects resets and zero-length intervals", "[metrics][network]") {
    const auto reset = CalculateNetworkRate(5000, 1200, 1000);
    const auto noInterval = CalculateNetworkRate(5000, 6000, 0);

    CHECK_FALSE(reset.available);
    CHECK(reset.quality == NetworkRateQuality::CounterReset);
    CHECK_FALSE(noInterval.available);
    CHECK(noInterval.quality == NetworkRateQuality::NoInterval);
}

TEST_CASE("Metrics history retains only the newest 120 snapshots", "[runtime][history]") {
    MetricsHistory history;
    for (unsigned __int64 value = 0; value < 121; ++value) {
        MetricsSnapshot snapshot{};
        snapshot.timestampUnixMilliseconds = value;
        history.Push(snapshot);
    }

    REQUIRE(history.Size() == 120);
    MetricsSnapshot oldest{};
    MetricsSnapshot newest{};
    REQUIRE(history.TryGetOldest(0, &oldest));
    REQUIRE(history.TryGetOldest(119, &newest));
    CHECK(oldest.timestampUnixMilliseconds == 1);
    CHECK(newest.timestampUnixMilliseconds == 120);
}

TEST_CASE("Snapshot coalescing keeps one latest pending value", "[runtime][coalescer]") {
    LatestValueCoalescer<MetricsSnapshot> queue;
    MetricsSnapshot older{};
    older.timestampUnixMilliseconds = 1;
    MetricsSnapshot latest{};
    latest.timestampUnixMilliseconds = 2;
    queue.Publish(older);
    queue.Publish(latest);

    CHECK(queue.PendingCount() == 1);
    MetricsSnapshot delivered{};
    REQUIRE(queue.TryTake(&delivered));
    CHECK(delivered.timestampUnixMilliseconds == 2);
    CHECK_FALSE(queue.TryTake(&delivered));
}

TEST_CASE("Metric change detection uses units, quality, and a numeric threshold", "[runtime][change]") {
    MetricChangeDetector detector;
    const auto previous = MakeAvailable(50.0, MetricUnit::Percent);

    CHECK_FALSE(detector.HasMeaningfulChange(previous,
        MakeAvailable(50.4, MetricUnit::Percent), 1.0));
    CHECK(detector.HasMeaningfulChange(previous,
        MakeAvailable(51.0, MetricUnit::Percent), 1.0));
    CHECK(detector.HasMeaningfulChange(previous,
        desktopmonitor::core::MakeUnavailable(MetricUnit::Percent), 1.0));
}

TEST_CASE("Power state transitions debounce obscured changes and request fresh data on resume", "[runtime][power]") {
    PowerStateMachine machine;
    CHECK(machine.State() == PowerState::Active);
    machine.ObserveObscured(true, 100, 250);
    machine.ObserveObscured(true, 350, 250);
    CHECK(machine.State() == PowerState::Obscured);
    CHECK(machine.SamplingIntervalMilliseconds() == 5000);
    machine.SetLocked(true);
    CHECK(machine.State() == PowerState::Locked);
    machine.SetDisplayOff(true);
    CHECK(machine.State() == PowerState::DisplayOff);
    CHECK(machine.SamplingIntervalMilliseconds() == 0);
    machine.SetDisplayOff(false);
    machine.SetLocked(false);
    machine.ObserveObscured(false, 400, 250);
    machine.ObserveObscured(false, 650, 250);
    CHECK(machine.State() == PowerState::Active);
    CHECK(machine.RequiresFullSnapshot());
}

TEST_CASE("Sampling scheduler pauses and resumes without catch-up loops", "[runtime][scheduler]") {
    SamplingScheduler scheduler;
    scheduler.Configure(1000, 0, true);
    CHECK(scheduler.IsDue(0));
    scheduler.MarkSampled(0);
    CHECK_FALSE(scheduler.IsDue(999));
    CHECK(scheduler.IsDue(1000));
    scheduler.Configure(0, 1000, false);
    CHECK_FALSE(scheduler.IsDue(100000));
    scheduler.Configure(1000, 50000, true);
    CHECK(scheduler.IsDue(50000));
    scheduler.MarkSampled(70000);
    CHECK_FALSE(scheduler.IsDue(70999));
    CHECK(scheduler.IsDue(71000));
}
