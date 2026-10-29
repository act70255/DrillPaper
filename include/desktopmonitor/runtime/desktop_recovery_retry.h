#pragma once

#include <cstdint>

namespace desktopmonitor::runtime {

class DesktopRecoveryRetry final {
public:
    /** 判斷目前是否可嘗試附掛。
     * Args:
     *     nowMilliseconds: 呼叫者提供的單調遞增毫秒。
     * Returns:
     *     可以嘗試時為 true。
     */
    bool CanAttempt(std::uint64_t nowMilliseconds) const {
        return failures_ < 10 && (failures_ == 0 || nowMilliseconds >= nextAttempt_);
    }

    /** 記錄失敗並決定是否排定下一次嘗試。
     * Args:
     *     nowMilliseconds: 本次失敗的單調遞增毫秒。
     * Returns:
     *     排定重試時為 true；已達上限時為 false。
     */
    bool RecordFailure(std::uint64_t nowMilliseconds) {
        if (!CanAttempt(nowMilliseconds)) return Pending();
        ++failures_;
        nextAttempt_ = nowMilliseconds + 1000;
        return Pending();
    }

    /** 回報是否有待執行的重試。
     * Returns:
     *     有待執行重試時為 true。
     */
    bool Pending() const { return failures_ > 0 && failures_ < 10; }

    /** 成功附掛後，重設下一次事件的重試額度。 */
    void Reset() { failures_ = 0; nextAttempt_ = 0; }

private:
    unsigned failures_ = 0;
    std::uint64_t nextAttempt_ = 0;
};

} // namespace desktopmonitor::runtime
