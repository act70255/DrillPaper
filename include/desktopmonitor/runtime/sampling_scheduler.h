#pragma once

namespace desktopmonitor::runtime {

class SamplingScheduler final {
public:
    void Configure(unsigned int intervalMilliseconds, unsigned __int64 nowMilliseconds,
                   bool sampleImmediately) {
        intervalMilliseconds_ = intervalMilliseconds;
        hasSchedule_ = true;
        if (intervalMilliseconds_ == 0) {
            nextDueMilliseconds_ = 0;
            return;
        }
        nextDueMilliseconds_ = sampleImmediately
            ? nowMilliseconds
            : nowMilliseconds + intervalMilliseconds_;
    }

    bool IsDue(unsigned __int64 nowMilliseconds) const {
        return intervalMilliseconds_ != 0 &&
               (!hasSchedule_ || nowMilliseconds >= nextDueMilliseconds_);
    }

    void MarkSampled(unsigned __int64 nowMilliseconds) {
        if (intervalMilliseconds_ == 0) {
            return;
        }
        hasSchedule_ = true;
        nextDueMilliseconds_ = nowMilliseconds + intervalMilliseconds_;
    }

    unsigned int IntervalMilliseconds() const { return intervalMilliseconds_; }

private:
    unsigned int intervalMilliseconds_ = 0;
    unsigned __int64 nextDueMilliseconds_ = 0;
    bool hasSchedule_ = false;
};

} // namespace desktopmonitor::runtime
