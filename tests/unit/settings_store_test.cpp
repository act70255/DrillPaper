#include <catch2/catch_test_macros.hpp>
#include "desktopmonitor/app/settings_store.h"
#include <windows.h>
#include <fstream>
#include <chrono>

TEST_CASE("Settings preserve the chosen theme mode and sleep preference", "[settings]") {
    const auto root = std::filesystem::temp_directory_path() /
        ("DrillPaper-settings-" + std::to_string(GetCurrentProcessId()));
    std::filesystem::create_directories(root);
    const auto file = root / "settings.json";
    std::filesystem::remove(file);
    desktopmonitor::app::SettingsStore store(file);
    auto chosen = store.Load();
    REQUIRE(chosen.smartSleep);
    REQUIRE_FALSE(chosen.allowNetwork);
    chosen.theme = "dashboard";
    chosen.desktop = false;
    chosen.smartSleep = false;
    store.Save(chosen);
    REQUIRE(store.Load() == chosen);
    std::filesystem::remove_all(root);
}

TEST_CASE("Invalid settings and failed atomic replacement preserve existing preferences", "[settings][security]") {
    using namespace desktopmonitor::app;
    const auto root = std::filesystem::temp_directory_path() /
        ("DrillPaper-settings-boundary-" + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
    std::filesystem::create_directories(root);
    const auto file = root / "settings.json";
    SettingsStore store(file);
    AppSettings chosen;
    chosen.theme = "dashboard";
    store.Save(chosen);
    SECTION("relative path fails fast") { REQUIRE_THROWS(SettingsStore("settings.json").Load()); }
    SECTION("invalid theme cannot replace a valid file") {
        auto invalid = chosen;
        invalid.theme = "../outside";
        REQUIRE_THROWS(store.Save(invalid));
        REQUIRE(store.Load() == chosen);
    }
    SECTION("corrupt JSON is not silently replaced") {
        std::ofstream(file) << "{broken";
        REQUIRE_THROWS(store.Load());
        REQUIRE_THROWS(store.Save(chosen));
        std::ifstream input(file);
        const std::string bytes((std::istreambuf_iterator<char>(input)), {});
        REQUIRE(bytes == "{broken");
    }
    SECTION("unsupported schema cannot be loaded") {
        std::ofstream(file) << R"({"schemaVersion":99,"theme":"minimal","displayMode":"desktop","smartSleep":true,"allowNetwork":false})";
        REQUIRE_THROWS(store.Load());
    }
    SECTION("failed replacement retains valid original and cleans staging") {
        HANDLE locked = CreateFileW(file.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
        REQUIRE(locked != INVALID_HANDLE_VALUE);
        auto changed = chosen;
        changed.smartSleep = false;
        const bool failed = [&] { try { store.Save(changed); return false; } catch (...) { return true; } }();
        CloseHandle(locked);
        REQUIRE(failed);
        REQUIRE(store.Load() == chosen);
        REQUIRE(std::distance(std::filesystem::directory_iterator(root), std::filesystem::directory_iterator{}) == 1);
    }
    std::filesystem::remove_all(root);
}

TEST_CASE("Settings accept installed theme identifiers supported by the manifest", "[settings]") {
    using namespace desktopmonitor::app;
    const auto root = std::filesystem::temp_directory_path() / ("DrillPaper-settings-semver-" + std::to_string(GetCurrentProcessId()));
    SettingsStore store(root / "settings.json");
    AppSettings chosen;
    chosen.theme = "1-theme@1.0.0-rc.1+build.2";
    store.Save(chosen);
    REQUIRE(store.Load() == chosen);
    std::filesystem::remove_all(root);
}
