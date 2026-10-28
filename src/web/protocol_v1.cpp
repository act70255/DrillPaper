#include "desktopmonitor/web/protocol_v1.h"

#include <algorithm>
#include <array>
#include <charconv>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <limits>
#include <string>
#include <utility>
#include <vector>

namespace desktopmonitor::web {
namespace {
using desktopmonitor::core::MetricQuality;
using desktopmonitor::core::MetricUnit;
using desktopmonitor::core::MetricValue;

void AppendJsonString(std::string& output, std::string_view value) {
    constexpr char hex[] = "0123456789abcdef";
    output.push_back('"');
    for (const unsigned char character : value) {
        switch (character) {
        case '"': output.append("\\\""); break;
        case '\\': output.append("\\\\"); break;
        case '\b': output.append("\\b"); break;
        case '\f': output.append("\\f"); break;
        case '\n': output.append("\\n"); break;
        case '\r': output.append("\\r"); break;
        case '\t': output.append("\\t"); break;
        default:
            if (character < 0x20) {
                output.append("\\u00");
                output.push_back(hex[(character >> 4) & 0x0f]);
                output.push_back(hex[character & 0x0f]);
            } else {
                output.push_back(static_cast<char>(character));
            }
            break;
        }
    }
    output.push_back('"');
}

void AppendFixed(std::string& output, unsigned int value, unsigned int width) {
    std::array<char, 10> digits{};
    for (unsigned int index = 0; index < width; ++index) {
        digits[width - index - 1] = static_cast<char>('0' + (value % 10));
        value /= 10;
    }
    output.append(digits.data(), width);
}

std::string Timestamp(unsigned __int64 unixMilliseconds) {
    using namespace std::chrono;
    constexpr unsigned __int64 kMaximumRfc3339Milliseconds = 253402300799999ULL;
    const auto bounded = std::min(unixMilliseconds, kMaximumRfc3339Milliseconds);
    const sys_time<milliseconds> instant{std::chrono::milliseconds{bounded}};
    const auto dayPoint = floor<days>(instant);
    const year_month_day date{sys_days{dayPoint}};
    const hh_mm_ss time{instant - dayPoint};

    std::string output;
    output.reserve(24);
    AppendFixed(output, static_cast<unsigned int>(static_cast<int>(date.year())), 4);
    output.push_back('-');
    AppendFixed(output, static_cast<unsigned int>(static_cast<unsigned int>(date.month())), 2);
    output.push_back('-');
    AppendFixed(output, static_cast<unsigned int>(static_cast<unsigned int>(date.day())), 2);
    output.push_back('T');
    AppendFixed(output, static_cast<unsigned int>(time.hours().count()), 2);
    output.push_back(':');
    AppendFixed(output, static_cast<unsigned int>(time.minutes().count()), 2);
    output.push_back(':');
    AppendFixed(output, static_cast<unsigned int>(time.seconds().count()), 2);
    output.push_back('.');
    AppendFixed(output, static_cast<unsigned int>(time.subseconds().count()), 3);
    output.push_back('Z');
    return output;
}

const char* UnitName(MetricUnit unit) {
    switch (unit) {
    case MetricUnit::Percent: return "percent";
    case MetricUnit::Bytes: return "bytes";
    case MetricUnit::BytesPerSecond: return "bytes_per_second";
    case MetricUnit::Celsius: return "celsius";
    }
    return "percent";
}

const char* QualityName(MetricQuality quality) {
    switch (quality) {
    case MetricQuality::Available: return "available";
    case MetricQuality::Unavailable: return "unavailable";
    case MetricQuality::Stale: return "stale";
    case MetricQuality::Error: return "error";
    }
    return "error";
}

enum class JsonKind : unsigned char { Object, Array, String, Number, Boolean, Null };

struct JsonValue final {
    JsonKind kind = JsonKind::Null;
    std::string scalar;
    std::vector<std::pair<std::string, JsonValue>> properties;
    std::vector<JsonValue> elements;
};

bool IsValidUtf8(std::string_view text) {
    for (std::size_t index = 0; index < text.size();) {
        const unsigned char first = static_cast<unsigned char>(text[index]);
        if (first <= 0x7f) {
            ++index;
            continue;
        }

        unsigned int continuationCount = 0;
        std::uint32_t codePoint = 0;
        if (first >= 0xc2 && first <= 0xdf) {
            continuationCount = 1;
            codePoint = first & 0x1f;
        } else if (first >= 0xe0 && first <= 0xef) {
            continuationCount = 2;
            codePoint = first & 0x0f;
        } else if (first >= 0xf0 && first <= 0xf4) {
            continuationCount = 3;
            codePoint = first & 0x07;
        } else {
            return false;
        }
        if (index + continuationCount >= text.size()) {
            return false;
        }
        for (unsigned int offset = 1; offset <= continuationCount; ++offset) {
            const unsigned char next = static_cast<unsigned char>(text[index + offset]);
            if ((next & 0xc0) != 0x80) {
                return false;
            }
            codePoint = (codePoint << 6) | (next & 0x3f);
        }
        if ((continuationCount == 1 && codePoint < 0x80) ||
            (continuationCount == 2 && codePoint < 0x800) ||
            (continuationCount == 3 && codePoint < 0x10000) ||
            (codePoint >= 0xd800 && codePoint <= 0xdfff) || codePoint > 0x10ffff) {
            return false;
        }
        index += continuationCount + 1;
    }
    return true;
}

void AppendUtf8(std::string& output, std::uint32_t codePoint) {
    if (codePoint <= 0x7f) {
        output.push_back(static_cast<char>(codePoint));
    } else if (codePoint <= 0x7ff) {
        output.push_back(static_cast<char>(0xc0 | (codePoint >> 6)));
        output.push_back(static_cast<char>(0x80 | (codePoint & 0x3f)));
    } else if (codePoint <= 0xffff) {
        output.push_back(static_cast<char>(0xe0 | (codePoint >> 12)));
        output.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | (codePoint & 0x3f)));
    } else {
        output.push_back(static_cast<char>(0xf0 | (codePoint >> 18)));
        output.push_back(static_cast<char>(0x80 | ((codePoint >> 12) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | ((codePoint >> 6) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | (codePoint & 0x3f)));
    }
}

class JsonParser final {
public:
    explicit JsonParser(std::string_view input) : input_(input) {}

    bool Parse(JsonValue* value) {
        if (value == nullptr || !ParseValue(value, 0)) {
            return false;
        }
        SkipWhitespace();
        return position_ == input_.size();
    }

private:
    static constexpr unsigned int kMaximumDepth = 16;
    static constexpr std::size_t kMaximumValues = 4096;

    void SkipWhitespace() {
        while (position_ < input_.size()) {
            const char character = input_[position_];
            if (character != ' ' && character != '\t' && character != '\r' && character != '\n') {
                break;
            }
            ++position_;
        }
    }

    bool ParseValue(JsonValue* value, unsigned int depth) {
        if (value == nullptr || depth > kMaximumDepth || ++valueCount_ > kMaximumValues) {
            return false;
        }
        SkipWhitespace();
        if (position_ >= input_.size()) {
            return false;
        }
        switch (input_[position_]) {
        case '{': return ParseObject(value, depth);
        case '[': return ParseArray(value, depth);
        case '"':
            value->kind = JsonKind::String;
            return ParseString(&value->scalar);
        case 't':
            value->kind = JsonKind::Boolean;
            return ConsumeLiteral("true", &value->scalar);
        case 'f':
            value->kind = JsonKind::Boolean;
            return ConsumeLiteral("false", &value->scalar);
        case 'n':
            value->kind = JsonKind::Null;
            return ConsumeLiteral("null", &value->scalar);
        default:
            value->kind = JsonKind::Number;
            return ParseNumber(&value->scalar);
        }
    }

    bool ParseObject(JsonValue* value, unsigned int depth) {
        value->kind = JsonKind::Object;
        ++position_;
        SkipWhitespace();
        if (Consume('}')) {
            return true;
        }
        while (position_ < input_.size()) {
            std::string name;
            if (!ParseString(&name)) {
                return false;
            }
            for (const auto& property : value->properties) {
                if (property.first == name) {
                    return false;
                }
            }
            SkipWhitespace();
            if (!Consume(':')) {
                return false;
            }
            JsonValue child{};
            if (!ParseValue(&child, depth + 1)) {
                return false;
            }
            value->properties.emplace_back(std::move(name), std::move(child));
            SkipWhitespace();
            if (Consume('}')) {
                return true;
            }
            if (!Consume(',')) {
                return false;
            }
            SkipWhitespace();
        }
        return false;
    }

    bool ParseArray(JsonValue* value, unsigned int depth) {
        value->kind = JsonKind::Array;
        ++position_;
        SkipWhitespace();
        if (Consume(']')) {
            return true;
        }
        while (position_ < input_.size()) {
            JsonValue child{};
            if (!ParseValue(&child, depth + 1)) {
                return false;
            }
            value->elements.push_back(std::move(child));
            SkipWhitespace();
            if (Consume(']')) {
                return true;
            }
            if (!Consume(',')) {
                return false;
            }
            SkipWhitespace();
        }
        return false;
    }

    bool ParseString(std::string* output) {
        if (output == nullptr || !Consume('"')) {
            return false;
        }
        while (position_ < input_.size()) {
            const unsigned char character = static_cast<unsigned char>(input_[position_++]);
            if (character == '"') {
                return IsValidUtf8(*output);
            }
            if (character < 0x20) {
                return false;
            }
            if (character != '\\') {
                output->push_back(static_cast<char>(character));
                continue;
            }
            if (position_ >= input_.size()) {
                return false;
            }
            const char escaped = input_[position_++];
            switch (escaped) {
            case '"': output->push_back('"'); break;
            case '\\': output->push_back('\\'); break;
            case '/': output->push_back('/'); break;
            case 'b': output->push_back('\b'); break;
            case 'f': output->push_back('\f'); break;
            case 'n': output->push_back('\n'); break;
            case 'r': output->push_back('\r'); break;
            case 't': output->push_back('\t'); break;
            case 'u': {
                std::uint32_t codePoint = 0;
                if (!ParseHexCodeUnit(&codePoint)) {
                    return false;
                }
                if (codePoint >= 0xd800 && codePoint <= 0xdbff) {
                    if (position_ + 2 > input_.size() || input_[position_] != '\\' ||
                        input_[position_ + 1] != 'u') {
                        return false;
                    }
                    position_ += 2;
                    std::uint32_t lowSurrogate = 0;
                    if (!ParseHexCodeUnit(&lowSurrogate) || lowSurrogate < 0xdc00 ||
                        lowSurrogate > 0xdfff) {
                        return false;
                    }
                    codePoint = 0x10000 + ((codePoint - 0xd800) << 10) +
                                (lowSurrogate - 0xdc00);
                } else if (codePoint >= 0xdc00 && codePoint <= 0xdfff) {
                    return false;
                }
                AppendUtf8(*output, codePoint);
                break;
            }
            default: return false;
            }
        }
        return false;
    }

    bool ParseHexCodeUnit(std::uint32_t* value) {
        if (value == nullptr || input_.size() - position_ < 4) {
            return false;
        }
        std::uint32_t codePoint = 0;
        for (unsigned int index = 0; index < 4; ++index) {
            const char character = input_[position_++];
            unsigned int digit = 0;
            if (character >= '0' && character <= '9') digit = static_cast<unsigned int>(character - '0');
            else if (character >= 'a' && character <= 'f') digit = static_cast<unsigned int>(character - 'a' + 10);
            else if (character >= 'A' && character <= 'F') digit = static_cast<unsigned int>(character - 'A' + 10);
            else return false;
            codePoint = (codePoint << 4) | digit;
        }
        *value = codePoint;
        return true;
    }

    bool ParseNumber(std::string* output) {
        const std::size_t begin = position_;
        if (position_ < input_.size() && input_[position_] == '-') {
            ++position_;
        }
        if (position_ >= input_.size()) {
            return false;
        }
        if (input_[position_] == '0') {
            ++position_;
            if (position_ < input_.size() && input_[position_] >= '0' && input_[position_] <= '9') {
                return false;
            }
        } else if (input_[position_] >= '1' && input_[position_] <= '9') {
            while (position_ < input_.size() && input_[position_] >= '0' && input_[position_] <= '9') {
                ++position_;
            }
        } else {
            return false;
        }
        if (position_ < input_.size() && input_[position_] == '.') {
            ++position_;
            const std::size_t fraction = position_;
            while (position_ < input_.size() && input_[position_] >= '0' && input_[position_] <= '9') {
                ++position_;
            }
            if (fraction == position_) {
                return false;
            }
        }
        if (position_ < input_.size() && (input_[position_] == 'e' || input_[position_] == 'E')) {
            ++position_;
            if (position_ < input_.size() && (input_[position_] == '+' || input_[position_] == '-')) {
                ++position_;
            }
            const std::size_t exponent = position_;
            while (position_ < input_.size() && input_[position_] >= '0' && input_[position_] <= '9') {
                ++position_;
            }
            if (exponent == position_) {
                return false;
            }
        }
        output->assign(input_.substr(begin, position_ - begin));
        return true;
    }

    bool ConsumeLiteral(std::string_view literal, std::string* output) {
        if (input_.substr(position_, literal.size()) != literal) {
            return false;
        }
        position_ += literal.size();
        output->assign(literal);
        return true;
    }

    bool Consume(char expected) {
        if (position_ >= input_.size() || input_[position_] != expected) {
            return false;
        }
        ++position_;
        return true;
    }

    std::string_view input_;
    std::size_t position_ = 0;
    std::size_t valueCount_ = 0;
};

const JsonValue* FindProperty(const JsonValue& object, std::string_view name) {
    if (object.kind != JsonKind::Object) {
        return nullptr;
    }
    for (const auto& property : object.properties) {
        if (property.first == name) {
            return &property.second;
        }
    }
    return nullptr;
}

bool HasOnlyProperties(const JsonValue& object, std::initializer_list<std::string_view> allowed) {
    if (object.kind != JsonKind::Object) {
        return false;
    }
    for (const auto& property : object.properties) {
        if (std::find(allowed.begin(), allowed.end(), property.first) == allowed.end()) {
            return false;
        }
    }
    return true;
}

bool GetString(const JsonValue* value, std::string* output) {
    if (value == nullptr || value->kind != JsonKind::String || output == nullptr) {
        return false;
    }
    *output = value->scalar;
    return true;
}

bool GetUnsignedInteger(const JsonValue* value, unsigned int* output) {
    if (value == nullptr || value->kind != JsonKind::Number || output == nullptr ||
        value->scalar.empty() || value->scalar.front() == '-') {
        return false;
    }
    unsigned int parsed = 0;
    const auto result = std::from_chars(value->scalar.data(),
                                        value->scalar.data() + value->scalar.size(), parsed);
    if (result.ec != std::errc{} || result.ptr != value->scalar.data() + value->scalar.size()) {
        return false;
    }
    *output = parsed;
    return true;
}

bool IsUtcTimestamp(std::string_view timestamp) {
    if (timestamp.size() < 20 || timestamp[4] != '-' || timestamp[7] != '-' ||
        timestamp[10] != 'T' || timestamp[13] != ':' || timestamp[16] != ':') {
        return false;
    }
    auto readDigits = [timestamp](std::size_t offset, std::size_t count, unsigned int* value) {
        if (value == nullptr || offset + count > timestamp.size()) {
            return false;
        }
        unsigned int result = 0;
        for (std::size_t index = 0; index < count; ++index) {
            const char digit = timestamp[offset + index];
            if (digit < '0' || digit > '9') {
                return false;
            }
            result = result * 10 + static_cast<unsigned int>(digit - '0');
        }
        *value = result;
        return true;
    };
    unsigned int yearValue = 0, monthValue = 0, dayValue = 0;
    unsigned int hourValue = 0, minuteValue = 0, secondValue = 0;
    if (!readDigits(0, 4, &yearValue) || !readDigits(5, 2, &monthValue) ||
        !readDigits(8, 2, &dayValue) || !readDigits(11, 2, &hourValue) ||
        !readDigits(14, 2, &minuteValue) || !readDigits(17, 2, &secondValue) ||
        hourValue > 23 || minuteValue > 59 || secondValue > 59) {
        return false;
    }
    using namespace std::chrono;
    const year_month_day date{year{static_cast<int>(yearValue)}, month{monthValue}, day{dayValue}};
    if (!date.ok()) {
        return false;
    }
    std::size_t position = 19;
    if (position < timestamp.size() && timestamp[position] == '.') {
        ++position;
        const std::size_t fractionBegin = position;
        while (position < timestamp.size() && timestamp[position] >= '0' && timestamp[position] <= '9') {
            ++position;
        }
        if (position - fractionBegin == 0 || position - fractionBegin > 9) {
            return false;
        }
    }
    return position + 1 == timestamp.size() && timestamp[position] == 'Z';
}

bool IsRequestId(const JsonValue* value, std::string* output) {
    return GetString(value, output) && !output->empty() && output->size() <= 128;
}

void AppendMetricNumber(std::string& output, const MetricValue& metric) {
    if (!metric.hasValue || !std::isfinite(metric.value)) {
        output.append("null");
        return;
    }

    std::array<char, 64> buffer{};
    const auto result = std::to_chars(buffer.data(), buffer.data() + buffer.size(),
                                      metric.value, std::chars_format::general,
                                      std::numeric_limits<double>::max_digits10);
    if (result.ec != std::errc{}) {
        output.append("null");
        return;
    }
    output.append(buffer.data(), result.ptr);
}

void AppendMetricValue(std::string& output, const MetricValue& metric) {
    output.append("{\"value\":");
    AppendMetricNumber(output, metric);
    output.append(",\"unit\":\"");
    output.append(UnitName(metric.unit));
    output.append("\",\"quality\":\"");
    output.append(QualityName(metric.quality));
    output.append("\"}");
}

void AppendMemoryValue(std::string& output, const MetricValue& metric) {
    if (!metric.hasValue || !std::isfinite(metric.value)) {
        output.append("null");
        return;
    }
    AppendMetricNumber(output, metric);
}

void AppendSnapshotFields(std::string& output, const core::MetricsSnapshot& snapshot) {
    output.append("\"cpu\":{\"usage\":");
    AppendMetricValue(output, snapshot.cpuUsage);
    output.append("},\"gpu\":{\"usage\":");
    AppendMetricValue(output, snapshot.gpuUsage);
    output.append("},\"memory\":{\"usedBytes\":");
    AppendMemoryValue(output, snapshot.memoryUsedBytes);
    output.append(",\"totalBytes\":");
    AppendMemoryValue(output, snapshot.memoryTotalBytes);
    output.append("},\"disk\":{\"activityPercent\":");
    AppendMetricValue(output, snapshot.diskActivityPercent);
    output.append("},\"network\":{\"rxBytesPerSec\":");
    AppendMetricValue(output, snapshot.networkReceiveBytesPerSecond);
    output.append(",\"txBytesPerSec\":");
    AppendMetricValue(output, snapshot.networkTransmitBytesPerSecond);
    output.push_back('}');
}

std::string SnapshotPayload(const core::MetricsSnapshot& snapshot) {
    std::string output;
    output.reserve(640);
    output.push_back('{');
    AppendSnapshotFields(output, snapshot);
    output.push_back('}');
    return output;
}

std::string HistorySnapshot(const core::MetricsSnapshot& snapshot) {
    std::string output;
    output.reserve(672);
    output.append("{\"timestamp\":");
    AppendJsonString(output, Timestamp(snapshot.timestampUnixMilliseconds));
    output.push_back(',');
    AppendSnapshotFields(output, snapshot);
    output.push_back('}');
    return output;
}
} // namespace

std::string SerializeMetricsSnapshotMessage(const core::MetricsSnapshot& snapshot,
                                            std::string_view type,
                                            const char* requestId) {
    return SerializeProtocolMessage(type, snapshot.timestampUnixMilliseconds, requestId,
                                    SnapshotPayload(snapshot));
}

std::string SerializeProtocolMessage(std::string_view type,
                                     unsigned __int64 timestampUnixMilliseconds,
                                     const char* requestId,
                                     std::string_view payloadJson) {
    std::string output;
    output.reserve(payloadJson.size() + type.size() + 128);
    output.append("{\"apiVersion\":\"1\",\"type\":");
    AppendJsonString(output, type);
    output.append(",\"requestId\":");
    if (requestId == nullptr) {
        output.append("null");
    } else {
        AppendJsonString(output, requestId);
    }
    output.append(",\"timestamp\":");
    AppendJsonString(output, Timestamp(timestampUnixMilliseconds));
    output.append(",\"payload\":");
    output.append(payloadJson);
    output.push_back('}');
    return output;
}

std::string SerializeMetricsHistoryMessage(std::span<const core::MetricsSnapshot> snapshots,
                                           unsigned __int64 timestampUnixMilliseconds,
                                           const char* requestId) {
    constexpr std::size_t kMaximumHistory = 120;
    const std::size_t firstIndex = snapshots.size() > kMaximumHistory
        ? snapshots.size() - kMaximumHistory
        : 0;
    std::string payload;
    payload.reserve((snapshots.size() - firstIndex) * 672 + 16);
    payload.append("{\"snapshots\":[");
    for (std::size_t index = firstIndex; index < snapshots.size(); ++index) {
        if (index > firstIndex) {
            payload.push_back(',');
        }
        payload.append(HistorySnapshot(snapshots[index]));
    }
    payload.append("]}");
    return SerializeProtocolMessage("metrics.history", timestampUnixMilliseconds, requestId, payload);
}

ProtocolParseResult ParseClientMessage(std::string_view utf8Json) {
    constexpr std::size_t kMaximumMessageBytes = 64 * 1024;
    if (utf8Json.size() > kMaximumMessageBytes) {
        return {ProtocolError::PayloadTooLarge, {}};
    }

    JsonValue root{};
    JsonParser parser{utf8Json};
    if (!parser.Parse(&root) || root.kind != JsonKind::Object ||
        !HasOnlyProperties(root, {"apiVersion", "type", "requestId", "timestamp", "payload"})) {
        return {ProtocolError::InvalidJson, {}};
    }

    std::string apiVersion;
    std::string type;
    std::string timestamp;
    const JsonValue* requestIdValue = FindProperty(root, "requestId");
    const JsonValue* payload = FindProperty(root, "payload");
    ClientMessage message{};
    const bool hasNullRequestId = requestIdValue != nullptr && requestIdValue->kind == JsonKind::Null;
    if (!hasNullRequestId && !IsRequestId(requestIdValue, &message.requestId)) {
        return {ProtocolError::InvalidEnvelope, std::move(message)};
    }
    if (!GetString(FindProperty(root, "apiVersion"), &apiVersion) ||
        !GetString(FindProperty(root, "type"), &type) ||
        !GetString(FindProperty(root, "timestamp"), &timestamp) ||
        !IsUtcTimestamp(timestamp) || payload == nullptr || payload->kind != JsonKind::Object ||
        requestIdValue == nullptr) {
        return {ProtocolError::InvalidEnvelope, std::move(message)};
    }
    if (apiVersion != "1") {
        return {ProtocolError::UnsupportedApiVersion, std::move(message)};
    }

    if (type == "theme.hello") {
        std::string sdkVersion;
        if (!hasNullRequestId || !HasOnlyProperties(*payload, {"sdkVersion"}) ||
            !GetString(FindProperty(*payload, "sdkVersion"), &sdkVersion) || sdkVersion.empty()) {
            return {ProtocolError::InvalidPayload, std::move(message)};
        }
        message.type = ClientMessageType::Hello;
        return {ProtocolError::None, std::move(message)};
    }
    if (type == "metrics.getSnapshot") {
        if (hasNullRequestId || !HasOnlyProperties(*payload, {})) {
            return {ProtocolError::InvalidPayload, std::move(message)};
        }
        message.type = ClientMessageType::GetSnapshot;
        return {ProtocolError::None, std::move(message)};
    }
    if (type == "metrics.getHistory") {
        const JsonValue* limitValue = FindProperty(*payload, "limit");
        if (hasNullRequestId || !HasOnlyProperties(*payload, {"limit"}) ||
            !GetUnsignedInteger(limitValue, &message.historyLimit) ||
            message.historyLimit < 1 || message.historyLimit > 120) {
            return {ProtocolError::InvalidPayload, std::move(message)};
        }
        message.type = ClientMessageType::GetHistory;
        return {ProtocolError::None, std::move(message)};
    }
    if (type == "metrics.subscribe") {
        const JsonValue* metricsValue = FindProperty(*payload, "metrics");
        const JsonValue* intervalValue = FindProperty(*payload, "intervalMs");
        if (!hasNullRequestId || !HasOnlyProperties(*payload, {"metrics", "intervalMs"}) ||
            metricsValue == nullptr || metricsValue->kind != JsonKind::Array ||
            !GetUnsignedInteger(intervalValue, &message.intervalMilliseconds) ||
            message.intervalMilliseconds < 1000 || message.intervalMilliseconds > 60000) {
            return {ProtocolError::InvalidPayload, std::move(message)};
        }
        static constexpr std::array<std::string_view, 6> allowedMetrics{
            "cpu", "gpu", "memory", "disk", "network", "clock"};
        for (const JsonValue& metricValue : metricsValue->elements) {
            std::string metric;
            if (!GetString(&metricValue, &metric)) {
                return {ProtocolError::InvalidPayload, std::move(message)};
            }
            if (std::find(allowedMetrics.begin(), allowedMetrics.end(), metric) == allowedMetrics.end() ||
                std::find(message.metrics.begin(), message.metrics.end(), metric) != message.metrics.end()) {
                continue;
            }
            message.metrics.push_back(std::move(metric));
        }
        message.type = ClientMessageType::Subscribe;
        return {ProtocolError::None, std::move(message)};
    }
    if (type == "metrics.unsubscribe") {
        if (!hasNullRequestId || !HasOnlyProperties(*payload, {})) {
            return {ProtocolError::InvalidPayload, std::move(message)};
        }
        message.type = ClientMessageType::Unsubscribe;
        return {ProtocolError::None, std::move(message)};
    }
    return {ProtocolError::UnsupportedMessage, std::move(message)};
}

} // namespace desktopmonitor::web
