#include <catch2/catch_test_macros.hpp>
#include <windows.h>

#include "desktopmonitor/platform/windows/desktop_host.h"

namespace {
struct WindowsFixture {
    HWND parent = nullptr;
    HWND preview = nullptr;

    /** 建立測試專屬的父子視窗，不接觸 Explorer。 */
    WindowsFixture() {
        parent = CreateWindowExW(0, L"STATIC", L"DrillPaper parent fixture",
                                WS_OVERLAPPEDWINDOW, 0, 0, 400, 300,
                                nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
        preview = CreateWindowExW(WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW, L"STATIC",
                                 L"DrillPaper preview fixture", WS_CHILD, 0, 0, 100, 100,
                                 parent, nullptr, GetModuleHandleW(nullptr), nullptr);
    }
    /** 只銷毀 fixture 擁有的視窗。 */
    ~WindowsFixture() {
        if (IsWindow(preview)) DestroyWindow(preview);
        if (IsWindow(parent)) DestroyWindow(parent);
    }
};
} // namespace

TEST_CASE("Desktop fallback restores a normal top-level preview", "[integration][desktop]") {
    WindowsFixture fixture;
    REQUIRE(IsWindow(fixture.parent));
    REQUIRE(IsWindow(fixture.preview));
    desktopmonitor::platform::windows::Win32DesktopHost host;
    host.RestorePreview(fixture.preview);
    REQUIRE(GetParent(fixture.preview) == nullptr);
    const auto style = GetWindowLongPtrW(fixture.preview, GWL_STYLE);
    const auto extended = GetWindowLongPtrW(fixture.preview, GWL_EXSTYLE);
    REQUIRE((style & WS_CHILD) == 0);
    REQUIRE((style & WS_OVERLAPPEDWINDOW) == WS_OVERLAPPEDWINDOW);
    REQUIRE((extended & WS_EX_NOACTIVATE) == 0);
    REQUIRE((extended & WS_EX_TOOLWINDOW) == 0);
}
