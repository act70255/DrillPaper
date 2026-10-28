#pragma once

#include "desktopmonitor/core/metrics_snapshot.h"

namespace desktopmonitor::runtime {

class MetricChangeDetector final {
public:
    bool HasMeaningfulChange(const core::MetricValue& previous,
                             const core::MetricValue& current,
                             double threshold) const {
        if (previous.unit != current.unit || previous.quality != current.quality ||
            previous.hasValue != current.hasValue) {
            return true;
        }
        if (!current.hasValue) {
            return false;
        }

        double difference = current.value - previous.value;
        if (difference < 0.0) {
            difference = -difference;
        }
        if (threshold <= 0.0) {
            return difference > 0.0;
        }
        return difference >= threshold;
    }
};

} // namespace desktopmonitor::runtime
