#include <catch2/catch_test_macros.hpp>

#include "desktopmonitor/runtime/desktop_recovery_retry.h"

TEST_CASE("Desktop recovery waits for Shell readiness with a bounded retry budget", "[runtime][desktop-retry]") {
    desktopmonitor::runtime::DesktopRecoveryRetry retry;
    REQUIRE(retry.CanAttempt(100));
    REQUIRE(retry.RecordFailure(100));
    REQUIRE(retry.Pending());
    REQUIRE_FALSE(retry.CanAttempt(1099));
    REQUIRE(retry.CanAttempt(1100));
    for (unsigned attempt = 1; attempt < 10; ++attempt) {
        REQUIRE(retry.CanAttempt(100 + attempt * 1000));
        REQUIRE(retry.RecordFailure(100 + attempt * 1000) == (attempt < 9));
    }
    REQUIRE_FALSE(retry.Pending());
    REQUIRE_FALSE(retry.CanAttempt(60000));
    retry.Reset();
    REQUIRE(retry.CanAttempt(60001));
    REQUIRE(retry.RecordFailure(60001));
    REQUIRE(retry.Pending());
}
