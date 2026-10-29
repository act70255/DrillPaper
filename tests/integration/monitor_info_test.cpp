#include <catch2/catch_test_macros.hpp>
#include "desktopmonitor/platform/windows/monitor_info.h"
#include <iostream>
#include <set>

TEST_CASE("Connected monitors expose stable target identities and physical desktop rectangles", "[integration][monitors]") {
    const auto previous = SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    const auto monitors = desktopmonitor::platform::windows::EnumerateMonitors();
    REQUIRE_FALSE(monitors.empty());
    std::set<std::string> identifiers;
    unsigned primaries = 0;
    for (const auto& monitor : monitors) {
        INFO(monitor.target.id);
        REQUIRE(identifiers.insert(monitor.target.id).second);
        REQUIRE(monitor.target.id.find("display#") != std::string::npos);
        REQUIRE(monitor.bounds.right > monitor.bounds.left);
        REQUIRE(monitor.bounds.bottom > monitor.bounds.top);
        REQUIRE(monitor.dpi > 0);
        if (monitor.target.primary) ++primaries;
        std::cout << monitor.target.id << " area=" << monitor.target.area << " primary=" << monitor.target.primary <<
            " rect=" << monitor.bounds.left << ',' << monitor.bounds.top << ',' << monitor.bounds.right << ',' << monitor.bounds.bottom <<
            " dpi=" << monitor.dpi << '\n';
    }
    REQUIRE(primaries > 0);
    if (previous) SetThreadDpiAwarenessContext(previous);
}
