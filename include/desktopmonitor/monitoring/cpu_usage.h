#pragma once

namespace desktopmonitor::monitoring {

using CpuCounter = unsigned __int64;

struct CpuTimes {
    CpuCounter idle;
    CpuCounter kernel;
    CpuCounter user;
};

enum class CpuUsageQuality : unsigned char {
    Available,
    Warmup,
    CounterReset,
    NoInterval,
    InvalidCounters
};

struct CpuUsageReading {
    double percent;
    bool available;
    CpuUsageQuality quality;
};

class CpuUsageCalculator final {
public:
    CpuUsageReading Sample(CpuTimes current) {
        if (!hasBaseline_) {
            baseline_ = current;
            hasBaseline_ = true;
            return {0.0, false, CpuUsageQuality::Warmup};
        }

        const CpuTimes previous = baseline_;
        baseline_ = current;
        if (current.idle < previous.idle || current.kernel < previous.kernel ||
            current.user < previous.user) {
            return {0.0, false, CpuUsageQuality::CounterReset};
        }

        const CpuCounter idleDelta = current.idle - previous.idle;
        const CpuCounter kernelDelta = current.kernel - previous.kernel;
        const CpuCounter userDelta = current.user - previous.user;
        if (kernelDelta < idleDelta) {
            return {0.0, false, CpuUsageQuality::InvalidCounters};
        }

        const double total = static_cast<double>(kernelDelta) + static_cast<double>(userDelta);
        if (total <= 0.0) {
            return {0.0, false, CpuUsageQuality::NoInterval};
        }

        const double idle = static_cast<double>(idleDelta);
        const double busy = total - idle;
        if (busy < 0.0 || busy > total) {
            return {0.0, false, CpuUsageQuality::InvalidCounters};
        }

        return {(busy / total) * 100.0, true, CpuUsageQuality::Available};
    }

    void Reset() {
        hasBaseline_ = false;
        baseline_ = {0, 0, 0};
    }

private:
    CpuTimes baseline_{0, 0, 0};
    bool hasBaseline_ = false;
};

} // namespace desktopmonitor::monitoring
