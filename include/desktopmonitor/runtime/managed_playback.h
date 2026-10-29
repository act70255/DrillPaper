#pragma once
#include "desktopmonitor/runtime/power_state_machine.h"

namespace desktopmonitor::runtime {
class ManagedPlayback final {
public:
    /** 設定本工作階段的手動暫停。
     * Args:
     *     paused: 是否暫停。
     */
    void SetPaused(bool paused) { paused_ = paused; }
    /** 取得手動暫停狀態。
     * Returns:
     *     使用者是否要求暫停。
     */
    bool Paused() const { return paused_; }
    /** 決定 renderer 有效狀態。
     * Args:
     *     power: 最新電源政策。
     *     smartSleep: 是否啟用智慧休眠。
     * Returns:
     *     由手動暫停與電源政策合成的狀態。
     */
    PowerState EffectiveState(PowerState power, bool smartSleep) const {
        if (paused_) return PowerState::DisplayOff;
        return smartSleep ? power : PowerState::Active;
    }
    /** 決定背景採樣間隔。
     * Args:
     *     powerInterval: 最新電源政策間隔。
     *     smartSleep: 是否啟用智慧休眠。
     * Returns:
     *     毫秒間隔，零表示停止採樣。
     */
    unsigned SamplingInterval(unsigned powerInterval, bool smartSleep) const {
        if (paused_) return 0;
        return smartSleep ? powerInterval : 1000;
    }
private:
    bool paused_ = false;
};
} // namespace desktopmonitor::runtime
