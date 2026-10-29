#include <catch2/catch_test_macros.hpp>
#include "desktopmonitor/runtime/managed_playback.h"

TEST_CASE("Manual pause survives power changes and resumes the current policy", "[runtime][management]") {
    using namespace desktopmonitor::runtime;
    ManagedPlayback playback;
    REQUIRE(playback.EffectiveState(PowerState::Active, true) == PowerState::Active);
    playback.SetPaused(true);
    REQUIRE(playback.EffectiveState(PowerState::Active, true) == PowerState::DisplayOff);
    REQUIRE(playback.SamplingInterval(5000, true) == 0);
    REQUIRE(playback.EffectiveState(PowerState::Active, false) == PowerState::DisplayOff);
    playback.SetPaused(false);
    REQUIRE(playback.EffectiveState(PowerState::Locked, true) == PowerState::Locked);
    REQUIRE(playback.SamplingInterval(15000, true) == 15000);
    REQUIRE(playback.EffectiveState(PowerState::Locked, false) == PowerState::Active);
    REQUIRE(playback.SamplingInterval(15000, false) == 1000);
}
