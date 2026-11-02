#include <catch2/catch_test_macros.hpp>
#include "desktopmonitor/platform/windows/monitor_info.h"
#include <iostream>
#include <set>

TEST_CASE("Monitor inventory survives initial and later enumeration failure without losing saved topology", "[integration][monitors]") {
    using namespace desktopmonitor::platform::windows;
    bool fail = true;
    const MonitorInfo primary{{"", "primary-area", true}, L"無法辨識", {0, 0, 1920, 1080}, 144};
    const std::vector<MonitorInfo> connected{{{"left", "left-area", true}, L"左", {0, 0, 1920, 1080}, 144},
        {{"right", "right-area", false}, L"右", {1920, 0, 3840, 1080}, 96}};
    MonitorInventory inventory([&] {
        if (fail) throw std::runtime_error("QueryDisplayConfig 失敗，Windows 代碼：31");
        return connected;
    }, [&] { return primary; });
    REQUIRE(inventory.Refresh());
    REQUIRE(inventory.Monitors() == std::vector<MonitorInfo>{primary});
    REQUIRE(inventory.Error().find("31") != std::string::npos);
    fail = false;
    REQUIRE(inventory.Refresh());
    REQUIRE(inventory.Monitors() == connected);
    REQUIRE(inventory.Error().empty());
    fail = true;
    REQUIRE_FALSE(inventory.Refresh());
    REQUIRE(inventory.Monitors() == connected);
    REQUIRE_FALSE(inventory.Error().empty());
    fail = false;
    REQUIRE_FALSE(inventory.Refresh());
    REQUIRE(inventory.Error().empty());
}

TEST_CASE("Monitor enumeration preserves desktop geometry when one identity lookup fails", "[integration][monitors]") {
    using namespace desktopmonitor::platform::windows;
    const auto baseline = EnumerateMonitors();
    for (int scenario = 0; scenario < 5; ++scenario) {
        const auto failure = scenario == 1 || scenario == 3 ? DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME : DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
        bool injected = false;
        const auto monitors = EnumerateMonitors([&](auto header) -> LONG {
            if ((!injected || scenario == 4) && header->type == failure) {
                injected = true;
                if (scenario < 2 || scenario == 4) return ERROR_GEN_FAILURE;
                const auto status = DisplayConfigGetDeviceInfo(header);
                if (header->type == DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME)
                    reinterpret_cast<DISPLAYCONFIG_TARGET_DEVICE_NAME*>(header)->monitorDevicePath[0] = L'\0';
                else reinterpret_cast<DISPLAYCONFIG_SOURCE_DEVICE_NAME*>(header)->viewGdiDeviceName[0] = L'\0';
                return status;
            }
            return DisplayConfigGetDeviceInfo(header);
        });
        REQUIRE(injected);
        REQUIRE_FALSE(monitors.empty());
        REQUIRE(std::any_of(monitors.begin(), monitors.end(), [](const auto& monitor) { return monitor.target.id.empty(); }));
        for (const auto& original : baseline) {
            REQUIRE(std::any_of(monitors.begin(), monitors.end(), [&](const auto& monitor) {
                return EqualRect(&original.bounds, &monitor.bounds) && original.dpi == monitor.dpi;
            }));
        }
        if (failure == DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME && baseline.size() > 1 && scenario != 4)
            REQUIRE(std::count_if(monitors.begin(), monitors.end(), [](const auto& m) { return !m.target.id.empty(); }) >= 1);
        if (scenario == 4) REQUIRE(std::all_of(monitors.begin(), monitors.end(), [](const auto& m) { return m.target.id.empty(); }));
    }
}

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
