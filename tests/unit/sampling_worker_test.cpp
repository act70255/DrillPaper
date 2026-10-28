#include <catch2/catch_test_macros.hpp>
#include <future>
#include <atomic>
#include <thread>
#include "desktopmonitor/runtime/sampling_worker.h"

TEST_CASE("Sampling worker collects outside the caller thread and stops while paused", "[runtime][worker]") {
    std::promise<std::pair<unsigned long long, std::thread::id>> promise;
    std::promise<std::thread::id> collectorPromise;
    auto collectorThread = collectorPromise.get_future();
    auto result = promise.get_future();
    std::atomic<bool> delivered = false;
    desktopmonitor::runtime::SamplingWorker worker(
        [&](bool) {
            collectorPromise.set_value(std::this_thread::get_id());
            desktopmonitor::core::MetricsSnapshot snapshot;
            snapshot.timestampUnixMilliseconds = 7;
            return snapshot;
        },
        [&](const auto& snapshot, auto) {
            if (!delivered.exchange(true)) promise.set_value({snapshot.timestampUnixMilliseconds, std::this_thread::get_id()});
        });
    worker.Configure(60000, true);
    REQUIRE(result.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
    const auto reading = result.get();
    REQUIRE(reading.first == 7);
    REQUIRE(reading.second != std::this_thread::get_id());
    REQUIRE(collectorThread.wait_for(std::chrono::seconds(0)) == std::future_status::ready);
    REQUIRE(collectorThread.get() != std::this_thread::get_id());
    worker.Configure(0, false);
    worker.Stop();
}

TEST_CASE("Sampling worker resumes immediately with a fresh baseline", "[runtime][worker]") {
    std::promise<desktopmonitor::core::MetricsSnapshot> firstPromise;
    std::promise<std::pair<desktopmonitor::core::MetricsSnapshot, unsigned long long>> resumedPromise;
    auto first = firstPromise.get_future();
    auto resumed = resumedPromise.get_future();
    std::atomic<unsigned> collected = 0;
    unsigned published = 0;
    desktopmonitor::runtime::SamplingWorker worker(
        [&](bool reset) {
            desktopmonitor::core::MetricsSnapshot snapshot;
            snapshot.timestampUnixMilliseconds = ++collected;
            snapshot.cpuUsage = desktopmonitor::core::MakeAvailable(reset ? 1.0 : 0.0, desktopmonitor::core::MetricUnit::Percent);
            return snapshot;
        }, [&](const auto& snapshot, unsigned long long generation) {
            if (++published == 1) firstPromise.set_value(snapshot);
            else if (published == 2) resumedPromise.set_value({snapshot, generation});
        });
    REQUIRE(worker.Configure(60000, true) == 1);
    REQUIRE(first.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
    REQUIRE(first.get().cpuUsage.value == 1.0);
    worker.Configure(0, false);
    REQUIRE(worker.Configure(60000, true) == 3);
    REQUIRE(resumed.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
    const auto reading = resumed.get();
    REQUIRE(reading.first.timestampUnixMilliseconds == 2);
    REQUIRE(reading.first.cpuUsage.value == 1.0);
    REQUIRE(reading.second == 3);
    worker.Stop();
}

TEST_CASE("Sampling worker reports collector failure without terminating the process", "[runtime][worker]") {
    std::promise<bool> failurePromise;
    auto failed = failurePromise.get_future();
    std::atomic<unsigned> published = 0;
    desktopmonitor::runtime::SamplingWorker worker(
        [](bool) -> desktopmonitor::core::MetricsSnapshot { throw std::runtime_error("測試採集失敗"); },
        [&](const auto&, auto) { ++published; },
        [&](std::exception_ptr error) { failurePromise.set_value(error != nullptr); });
    worker.Configure(1, true);
    REQUIRE(failed.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
    REQUIRE(failed.get());
    worker.Stop();
    REQUIRE(published == 0);
}

TEST_CASE("Sampling worker discards an in-flight snapshot from the previous generation", "[runtime][worker]") {
    std::promise<void> enteredPromise;
    std::promise<void> releasePromise;
    auto entered = enteredPromise.get_future();
    auto release = releasePromise.get_future().share();
    std::promise<std::pair<unsigned long long, unsigned long long>> deliveredPromise;
    auto delivered = deliveredPromise.get_future();
    std::atomic<unsigned> collected = 0;
    std::atomic<bool> published = false;
    desktopmonitor::runtime::SamplingWorker worker(
        [&](bool) {
            const auto value = ++collected;
            if (value == 1) {
                enteredPromise.set_value();
                release.wait_for(std::chrono::seconds(2));
            }
            desktopmonitor::core::MetricsSnapshot snapshot;
            snapshot.timestampUnixMilliseconds = value;
            return snapshot;
        }, [&](const auto& snapshot, unsigned long long generation) {
            if (!published.exchange(true)) deliveredPromise.set_value({snapshot.timestampUnixMilliseconds, generation});
        });
    worker.Configure(60000, true);
    REQUIRE(entered.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
    worker.Configure(0, false);
    REQUIRE(worker.Configure(60000, true) == 3);
    releasePromise.set_value();
    REQUIRE(delivered.wait_for(std::chrono::seconds(2)) == std::future_status::ready);
    const auto sample = delivered.get();
    REQUIRE(sample.first == 2);
    REQUIRE(sample.second == 3);
    worker.Stop();
}
