#pragma once

#include <string>
#include <string_view>
#include <span>
#include <vector>

#include "desktopmonitor/core/metrics_snapshot.h"

namespace desktopmonitor::web {

enum class ClientMessageType : unsigned char {
    Hello,
    GetSnapshot,
    GetHistory,
    Subscribe,
    Unsubscribe
};

enum class ProtocolError : unsigned char {
    None,
    PayloadTooLarge,
    InvalidJson,
    InvalidEnvelope,
    UnsupportedApiVersion,
    UnsupportedMessage,
    InvalidPayload
};

struct ClientMessage final {
    ClientMessageType type = ClientMessageType::Hello;
    std::string requestId;
    unsigned int historyLimit = 0;
    unsigned int intervalMilliseconds = 1000;
    std::vector<std::string> metrics;
};

struct ProtocolParseResult final {
    ProtocolError error = ProtocolError::None;
    ClientMessage message{};
};

std::string SerializeMetricsSnapshotMessage(const core::MetricsSnapshot& snapshot,
                                            std::string_view type,
                                            const char* requestId);
std::string SerializeProtocolMessage(std::string_view type,
                                     unsigned __int64 timestampUnixMilliseconds,
                                     const char* requestId,
                                     std::string_view payloadJson);
std::string SerializeMetricsHistoryMessage(std::span<const core::MetricsSnapshot> snapshots,
                                           unsigned __int64 timestampUnixMilliseconds,
                                           const char* requestId);
ProtocolParseResult ParseClientMessage(std::string_view utf8Json);

} // namespace desktopmonitor::web
