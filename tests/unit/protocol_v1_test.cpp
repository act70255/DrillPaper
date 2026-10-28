#include <catch2/catch_test_macros.hpp>

#include <array>
#include <string>

#include "desktopmonitor/core/metrics_snapshot.h"
#include "desktopmonitor/web/protocol_v1.h"

using desktopmonitor::core::MakeAvailable;
using desktopmonitor::core::MakeUnavailable;
using desktopmonitor::core::MetricUnit;
using desktopmonitor::core::MetricsSnapshot;
using desktopmonitor::web::SerializeMetricsSnapshotMessage;
using desktopmonitor::web::ClientMessageType;
using desktopmonitor::web::ParseClientMessage;
using desktopmonitor::web::ProtocolError;
using desktopmonitor::web::SerializeMetricsHistoryMessage;
using desktopmonitor::web::SerializeProtocolMessage;

TEST_CASE("Protocol v1 serializes a complete snapshot with units and UTC timestamp",
          "[protocol]") {
    MetricsSnapshot snapshot{};
    snapshot.timestampUnixMilliseconds = 1234;
    snapshot.cpuUsage = MakeAvailable(12.5, MetricUnit::Percent);
    snapshot.memoryUsedBytes = MakeAvailable(200.0, MetricUnit::Bytes);
    snapshot.memoryTotalBytes = MakeAvailable(1024.0, MetricUnit::Bytes);
    snapshot.diskActivityPercent = MakeAvailable(3.0, MetricUnit::Percent);
    snapshot.networkReceiveBytesPerSecond =
        MakeAvailable(4096.0, MetricUnit::BytesPerSecond);
    snapshot.networkTransmitBytesPerSecond = MakeUnavailable(MetricUnit::BytesPerSecond);

    CHECK(SerializeMetricsSnapshotMessage(snapshot, "metrics.snapshot", nullptr) ==
          R"({"apiVersion":"1","type":"metrics.snapshot","requestId":null,"timestamp":"1970-01-01T00:00:01.234Z","payload":{"cpu":{"usage":{"value":12.5,"unit":"percent","quality":"available"}},"gpu":{"usage":{"value":null,"unit":"percent","quality":"unavailable"}},"memory":{"usedBytes":200,"totalBytes":1024},"disk":{"activityPercent":{"value":3,"unit":"percent","quality":"available"}},"network":{"rxBytesPerSec":{"value":4096,"unit":"bytes_per_second","quality":"available"},"txBytesPerSec":{"value":null,"unit":"bytes_per_second","quality":"unavailable"}}}})");
}

TEST_CASE("Protocol v1 echoes request identifiers and serializes unavailable memory as null",
          "[protocol]") {
    MetricsSnapshot snapshot{};
    snapshot.timestampUnixMilliseconds = 0;

    CHECK(SerializeMetricsSnapshotMessage(snapshot, "metrics.snapshot", "request-7") ==
          R"({"apiVersion":"1","type":"metrics.snapshot","requestId":"request-7","timestamp":"1970-01-01T00:00:00.000Z","payload":{"cpu":{"usage":{"value":null,"unit":"percent","quality":"unavailable"}},"gpu":{"usage":{"value":null,"unit":"percent","quality":"unavailable"}},"memory":{"usedBytes":null,"totalBytes":null},"disk":{"activityPercent":{"value":null,"unit":"percent","quality":"unavailable"}},"network":{"rxBytesPerSec":{"value":null,"unit":"bytes_per_second","quality":"unavailable"},"txBytesPerSec":{"value":null,"unit":"bytes_per_second","quality":"unavailable"}}}})");
}

TEST_CASE("Protocol v1 parses bounded history requests and preserves request IDs", "[protocol]") {
    const auto result = ParseClientMessage(
        R"({"apiVersion":"1","type":"metrics.getHistory","requestId":"dm-7","timestamp":"2026-10-28T01:02:03.004Z","payload":{"limit":12}})");

    REQUIRE(result.error == ProtocolError::None);
    CHECK(result.message.type == ClientMessageType::GetHistory);
    CHECK(result.message.requestId == "dm-7");
    CHECK(result.message.historyLimit == 12);
}

TEST_CASE("Protocol v1 rejects invalid envelopes, unsupported versions, and oversized messages",
          "[protocol]") {
    const auto wrongVersion = ParseClientMessage(
        R"({"apiVersion":"2","type":"metrics.getSnapshot","requestId":"dm-7","timestamp":"2026-10-28T01:02:03Z","payload":{}})");
    CHECK(wrongVersion.error == ProtocolError::UnsupportedApiVersion);
    CHECK(wrongVersion.message.requestId == "dm-7");

    const auto invalidLimit = ParseClientMessage(
        R"({"apiVersion":"1","type":"metrics.getHistory","requestId":"dm-8","timestamp":"2026-10-28T01:02:03Z","payload":{"limit":121}})");
    CHECK(invalidLimit.error == ProtocolError::InvalidPayload);
    CHECK(invalidLimit.message.requestId == "dm-8");

    const std::string oversized(65 * 1024, ' ');
    CHECK(ParseClientMessage(oversized).error == ProtocolError::PayloadTooLarge);
}

TEST_CASE("Protocol v1 subscription removes unknown and duplicate metric names", "[protocol]") {
    const auto result = ParseClientMessage(
        R"({"apiVersion":"1","type":"metrics.subscribe","requestId":null,"timestamp":"2026-10-28T01:02:03Z","payload":{"metrics":["cpu","memory","cpu","unknown"],"intervalMs":2500}})");

    REQUIRE(result.error == ProtocolError::None);
    REQUIRE(result.message.type == ClientMessageType::Subscribe);
    CHECK(result.message.intervalMilliseconds == 2500);
    CHECK(result.message.metrics == std::vector<std::string>{"cpu", "memory"});
}

TEST_CASE("Protocol v1 serializes control envelopes without changing their payload",
          "[protocol]") {
    CHECK(SerializeProtocolMessage("host.ready", 0, nullptr, R"({"state":"active"})") ==
          R"({"apiVersion":"1","type":"host.ready","requestId":null,"timestamp":"1970-01-01T00:00:00.000Z","payload":{"state":"active"}})");
}

TEST_CASE("Protocol v1 history snapshots carry their own timestamps",
          "[protocol]") {
    MetricsSnapshot snapshot{};
    snapshot.timestampUnixMilliseconds = 1234;
    snapshot.cpuUsage = MakeAvailable(12.5, MetricUnit::Percent);

    const std::array<MetricsSnapshot, 1> snapshots{snapshot};
    const std::string message = SerializeMetricsHistoryMessage(snapshots, 2000, "dm-9");
    CHECK(message.find("\"snapshots\":[{\"timestamp\":\"1970-01-01T00:00:01.234Z\",\"cpu\":{\"usage\":{\"value\":12.5") != std::string::npos);
    CHECK(message.find("\"requestId\":\"dm-9\"") != std::string::npos);
}
