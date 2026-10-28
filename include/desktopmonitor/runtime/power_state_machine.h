#pragma once

namespace desktopmonitor::runtime {

enum class PowerState : unsigned char {
    Active,
    Obscured,
    Locked,
    DisplayOff,
    Recovering
};

class PowerStateMachine final {
public:
    PowerState State() const {
        if (recovering_) {
            return PowerState::Recovering;
        }
        if (displayOff_) {
            return PowerState::DisplayOff;
        }
        if (locked_) {
            return PowerState::Locked;
        }
        return obscured_ ? PowerState::Obscured : PowerState::Active;
    }

    unsigned int SamplingIntervalMilliseconds() const {
        switch (State()) {
        case PowerState::Active: return 1000;
        case PowerState::Obscured: return 5000;
        case PowerState::Locked: return 15000;
        case PowerState::DisplayOff: return 0;
        case PowerState::Recovering: return 1000;
        }
        return 0;
    }

    bool RendererShouldBeVisible() const { return State() == PowerState::Active; }
    bool TrySuspendIsUseful() const { return State() != PowerState::Active; }
    bool RequiresFullSnapshot() const { return fullSnapshotRequired_; }

    void ObserveObscured(bool obscured, unsigned __int64 nowMilliseconds,
                         unsigned __int64 debounceMilliseconds) {
        if (obscured == obscured_) {
            hasPendingObscured_ = false;
            return;
        }

        if (!hasPendingObscured_ || pendingObscured_ != obscured ||
            nowMilliseconds < pendingSinceMilliseconds_) {
            pendingObscured_ = obscured;
            pendingSinceMilliseconds_ = nowMilliseconds;
            hasPendingObscured_ = true;
            if (debounceMilliseconds != 0) {
                return;
            }
        } else if (nowMilliseconds - pendingSinceMilliseconds_ < debounceMilliseconds) {
            return;
        }

        const PowerState previous = State();
        obscured_ = pendingObscured_;
        hasPendingObscured_ = false;
        MarkResumeIfNeeded(previous);
    }

    void SetLocked(bool locked) {
        const PowerState previous = State();
        locked_ = locked;
        MarkResumeIfNeeded(previous);
    }

    void SetDisplayOff(bool displayOff) {
        const PowerState previous = State();
        displayOff_ = displayOff;
        MarkResumeIfNeeded(previous);
    }

    void BeginRecovery() { recovering_ = true; }

    void FinishRecovery() {
        const PowerState previous = State();
        recovering_ = false;
        MarkResumeIfNeeded(previous);
    }

    void MarkFullSnapshotDelivered() { fullSnapshotRequired_ = false; }

private:
    void MarkResumeIfNeeded(PowerState previous) {
        if (previous != PowerState::Active && State() == PowerState::Active) {
            fullSnapshotRequired_ = true;
        }
    }

    bool obscured_ = false;
    bool locked_ = false;
    bool displayOff_ = false;
    bool recovering_ = false;
    bool fullSnapshotRequired_ = false;
    bool hasPendingObscured_ = false;
    bool pendingObscured_ = false;
    unsigned __int64 pendingSinceMilliseconds_ = 0;
};

} // namespace desktopmonitor::runtime
