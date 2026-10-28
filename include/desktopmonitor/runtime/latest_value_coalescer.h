#pragma once

namespace desktopmonitor::runtime {

// Single-thread value semantics; use the Windows mailbox below for cross-thread delivery.
template <typename T>
class LatestValueCoalescer final {
public:
    void Publish(const T& value) {
        latest_ = value;
        pending_ = true;
    }

    bool TryTake(T* value) {
        if (!pending_ || value == nullptr) {
            return false;
        }
        *value = latest_;
        pending_ = false;
        return true;
    }

    unsigned int PendingCount() const { return pending_ ? 1U : 0U; }

private:
    T latest_{};
    bool pending_ = false;
};

} // namespace desktopmonitor::runtime
