#include <catch2/catch_test_macros.hpp>
#include <windows.h>
#include <string>

#include "desktopmonitor/platform/windows/desktop_host.h"

namespace {
struct WindowsFixture {
    DPI_AWARENESS_CONTEXT previousDpi = nullptr;
    HWND parent = nullptr;
    HWND preview = nullptr;

    /** 建立測試專屬的父子視窗，不接觸 Explorer。 */
    WindowsFixture() {
        previousDpi = SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
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
        if (previousDpi != nullptr) SetThreadDpiAwarenessContext(previousDpi);
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

TEST_CASE("Live Shell attachment uses the Explorer wallpaper layer", "[integration][shell-live]") {
    WindowsFixture fixture;
    REQUIRE(IsWindow(fixture.preview));
    desktopmonitor::platform::windows::Win32DesktopHost host;
    host.RestorePreview(fixture.preview);
    desktopmonitor::platform::windows::DesktopAttachFailure failure{};
    const bool attached = host.TryAttach(fixture.preview, &failure);
    INFO("DesktopAttachFailure=" << static_cast<int>(failure));
    REQUIRE(attached);
    const HWND wallpaper = GetParent(fixture.preview);
    REQUIRE(IsWindow(wallpaper));
    DWORD shellProcess = 0;
    DWORD wallpaperProcess = 0;
    GetWindowThreadProcessId(GetShellWindow(), &shellProcess);
    GetWindowThreadProcessId(wallpaper, &wallpaperProcess);
    REQUIRE(shellProcess != 0);
    REQUIRE(wallpaperProcess == shellProcess);
    wchar_t className[256]{};
    GetClassNameW(wallpaper, className, 256);
    REQUIRE(std::wstring(className) == L"WorkerW");
    REQUIRE(FindWindowExW(wallpaper, nullptr, L"SHELLDLL_DefView", nullptr) == nullptr);
    REQUIRE((GetWindowLongPtrW(fixture.preview, GWL_STYLE) & WS_CHILD) != 0);
    const auto extended = GetWindowLongPtrW(fixture.preview, GWL_EXSTYLE);
    REQUIRE((extended & WS_EX_NOACTIVATE) != 0);
    REQUIRE((extended & WS_EX_TOOLWINDOW) != 0);
    RECT childBounds{};
    RECT parentBounds{};
    REQUIRE(GetWindowRect(fixture.preview, &childBounds));
    REQUIRE(GetClientRect(wallpaper, &parentBounds));
    REQUIRE(childBounds.right - childBounds.left == parentBounds.right - parentBounds.left);
    REQUIRE(childBounds.bottom - childBounds.top == parentBounds.bottom - parentBounds.top);
    host.RestorePreview(fixture.preview);
    REQUIRE(GetParent(fixture.preview) == nullptr);
}
