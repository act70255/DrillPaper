#include <catch2/catch_test_macros.hpp>
#include "desktopmonitor/runtime/monitor_targets.h"

TEST_CASE("Unidentified monitor temporarily applies every connected area and restores saved targets", "[runtime][monitors]") {
    using namespace desktopmonitor::runtime;
    const std::vector<std::string> saved{"left"};
    const std::vector<MonitorTarget> degraded{{"left", "left-area", true}, {"", "right-area", false}, {"clone", "right-area", false}};
    REQUIRE(ResolveMonitorTargets(saved, degraded).areas == std::vector<std::size_t>{0, 1});
    REQUIRE(ResolveMonitorTargets(saved, degraded).unidentifiedFallback);
    REQUIRE_FALSE(ResolveMonitorTargets(saved, degraded).primaryFallback);
    REQUIRE(ResolveMonitorTargets({}, degraded).areas == std::vector<std::size_t>{0, 1});
    REQUIRE(saved == std::vector<std::string>{"left"});
    REQUIRE(ResolveMonitorTargets(saved, {{"left", "left-area", true}, {"right", "right-area", false}}).areas == std::vector<std::size_t>{0});
    REQUIRE_FALSE(ResolveMonitorTargets(saved, {{"left", "left-area", true}}).unidentifiedFallback);
}

TEST_CASE("Monitor selection uses only connected selected areas and restores returning targets", "[runtime][monitors]") {
    using namespace desktopmonitor::runtime;
    const std::vector<MonitorTarget> connected{{"left", "area-left", false}, {"main", "area-main", true}};
    REQUIRE(ResolveMonitorTargets({"left"}, connected).areas == std::vector<std::size_t>{0});
    REQUIRE(ResolveMonitorTargets({"left", "main"}, connected).areas == std::vector<std::size_t>{0, 1});
    const auto partial = ResolveMonitorTargets({"left", "offline"}, connected);
    REQUIRE(partial.areas == std::vector<std::size_t>{0});
    REQUIRE_FALSE(partial.primaryFallback);
    const auto offline = ResolveMonitorTargets({"offline"}, connected);
    REQUIRE(offline.areas == std::vector<std::size_t>{1});
    REQUIRE(offline.primaryFallback);
    REQUIRE(ResolveMonitorTargets({"offline"}, {{"offline", "area-new", false}, {"main", "area-main", true}}).areas == std::vector<std::size_t>{0});
}

TEST_CASE("Clone targets share one renderer area and empty selection never falls back", "[runtime][monitors]") {
    using namespace desktopmonitor::runtime;
    const std::vector<MonitorTarget> clone{{"a", "clone", true}, {"b", "clone", true}, {"c", "other", false}};
    REQUIRE(ResolveMonitorTargets({"a", "b", "c"}, clone).areas == std::vector<std::size_t>{0, 2});
    REQUIRE(ResolveMonitorTargets({"b"}, clone).areas == std::vector<std::size_t>{1});
    REQUIRE(ResolveMonitorTargets({}, clone).areas.empty());
    REQUIRE_FALSE(ResolveMonitorTargets({}, clone).primaryFallback);
    REQUIRE(ResolveMonitorTargets({"lost"}, {{"new-primary", "area", true}}).primaryFallback);
    REQUIRE(ResolveMonitorTargets({"lost"}, {}).areas.empty());
}
