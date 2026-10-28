#pragma once

#include "desktopmonitor/core/metrics_snapshot.h"
#include "desktopmonitor/runtime/ring_buffer.h"

namespace desktopmonitor::runtime {

using MetricsHistory = RingBuffer<core::MetricsSnapshot, 120>;

} // namespace desktopmonitor::runtime
