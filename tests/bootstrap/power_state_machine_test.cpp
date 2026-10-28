#include "desktopmonitor/runtime/power_state_machine.h"

using desktopmonitor::runtime::PowerState;
using desktopmonitor::runtime::PowerStateMachine;

extern "C" int TestEntry() {
    PowerStateMachine machine;
    if (machine.State() != PowerState::Active || machine.SamplingIntervalMilliseconds() != 1000) {
        return 1;
    }

    machine.ObserveObscured(true, 100, 250);
    if (machine.State() != PowerState::Active) {
        return 2;
    }
    machine.ObserveObscured(true, 349, 250);
    if (machine.State() != PowerState::Active) {
        return 3;
    }
    machine.ObserveObscured(true, 350, 250);
    if (machine.State() != PowerState::Obscured || machine.RendererShouldBeVisible() ||
        machine.SamplingIntervalMilliseconds() != 5000) {
        return 4;
    }

    machine.SetLocked(true);
    if (machine.State() != PowerState::Locked || machine.SamplingIntervalMilliseconds() != 15000) {
        return 5;
    }
    machine.SetDisplayOff(true);
    if (machine.State() != PowerState::DisplayOff || machine.SamplingIntervalMilliseconds() != 0) {
        return 6;
    }
    machine.SetDisplayOff(false);
    machine.SetLocked(false);
    if (machine.State() != PowerState::Obscured) {
        return 7;
    }

    machine.ObserveObscured(false, 400, 250);
    machine.ObserveObscured(false, 650, 250);
    if (machine.State() != PowerState::Active || !machine.RequiresFullSnapshot()) {
        return 8;
    }
    machine.MarkFullSnapshotDelivered();
    if (machine.RequiresFullSnapshot()) {
        return 9;
    }

    machine.BeginRecovery();
    if (machine.State() != PowerState::Recovering) {
        return 10;
    }
    machine.FinishRecovery();
    if (machine.State() != PowerState::Active || !machine.RequiresFullSnapshot()) {
        return 11;
    }
    return 0;
}
