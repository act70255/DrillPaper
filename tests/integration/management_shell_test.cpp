#include <catch2/catch_test_macros.hpp>
#include <catch2/catch_session.hpp>
#include <windows.h>
#include <commctrl.h>
#include <objidl.h>
#include <gdiplus.h>
#include <dwmapi.h>
#include <array>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

#include "desktopmonitor/platform/windows/management_shell.h"

/** 在與產品一致的逐螢幕 DPI 模式啟動原生整合測試。
 * Args:
 *     argc: 命令列參數數量。
 *     argv: Catch2 測試選擇參數。
 * Returns:
 *     測試退出碼；DPI 初始化失敗時為 1。
 */
int main(int argc, char* argv[]) {
    if (!SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) {
        std::cerr << "無法初始化測試的逐螢幕 DPI 模式。\n";
        return 1;
    }
    return Catch::Session().run(argc, argv);
}

namespace {
namespace win = desktopmonitor::platform::windows;

struct ManagementFixture {
    DPI_AWARENESS_CONTEXT previous = SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    HWND owner = nullptr;
    HWND manager = nullptr;
    win::ManagementShell shell;

    /** 建立本測試擁有的原生管理視窗，不附掛或重啟 Explorer。 */
    ManagementFixture() {
        owner = CreateWindowExW(0, L"STATIC", L"設定視窗測試通知入口", WS_OVERLAPPED,
            0, 0, 1, 1, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
        REQUIRE(owner);
        REQUIRE(shell.Initialize(owner, [](UINT) {}));
        EnumThreadWindows(GetCurrentThreadId(), [](HWND window, LPARAM data) -> BOOL {
            wchar_t name[128]{};
            GetClassNameW(window, name, 128);
            if (std::wstring(name) == L"DrillPaperManagementWindow") *reinterpret_cast<HWND*>(data) = window;
            return TRUE;
        }, reinterpret_cast<LPARAM>(&manager));
        REQUIRE(manager);
    }

    /** 僅清理 fixture 自己的視窗與系統匣，還原執行緒 DPI。 */
    ~ManagementFixture() {
        shell.Shutdown();
        if (owner) DestroyWindow(owner);
        if (previous) SetThreadDpiAwarenessContext(previous);
    }
};

struct CaptureResources {
    ULONG_PTR token = 0;
    HDC screen = nullptr;
    HDC memory = nullptr;
    HBITMAP bitmap = nullptr;
    HGDIOBJ previous = nullptr;

    /** 即使測試斷言拋出，也還原及釋放本次擷取持有的原生資源。 */
    ~CaptureResources() {
        if (previous && memory) SelectObject(memory, previous);
        if (bitmap) DeleteObject(bitmap);
        if (memory) DeleteDC(memory);
        if (screen) ReleaseDC(nullptr, screen);
        if (token) Gdiplus::GdiplusShutdown(token);
    }
};

/** 將受測原生管理視窗保存為 PNG，僅於明確指定證據目錄時輸出。
 * Args:
 *     window: fixture 自己擁有的管理視窗。
 *     name: 本次畫面名稱。
 */
void Capture(HWND window, const std::wstring& name) {
    wchar_t directory[32768]{};
    const auto length = GetEnvironmentVariableW(L"DRILLPAPER_SETTINGS_EVIDENCE", directory, 32768);
    if (length == 0) return;
    REQUIRE(length < 32768);
    MSG message{};
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    RedrawWindow(window, nullptr, nullptr, RDW_INVALIDATE | RDW_ALLCHILDREN | RDW_FRAME | RDW_UPDATENOW);
    DwmFlush();
    CaptureResources resources;
    Gdiplus::GdiplusStartupInput input;
    REQUIRE(Gdiplus::GdiplusStartup(&resources.token, &input, nullptr) == Gdiplus::Ok);
    RECT bounds{};
    REQUIRE(GetWindowRect(window, &bounds));
    resources.screen = GetDC(nullptr);
    REQUIRE(resources.screen);
    resources.memory = CreateCompatibleDC(resources.screen);
    REQUIRE(resources.memory);
    resources.bitmap = CreateCompatibleBitmap(resources.screen, bounds.right - bounds.left, bounds.bottom - bounds.top);
    REQUIRE(resources.bitmap);
    resources.previous = SelectObject(resources.memory, resources.bitmap);
    REQUIRE(resources.previous);
    SendMessageW(window, WM_PRINT, reinterpret_cast<WPARAM>(resources.memory), PRF_CLIENT | PRF_NONCLIENT | PRF_CHILDREN | PRF_ERASEBKGND);
    SelectObject(resources.memory, resources.previous);
    resources.previous = nullptr;
    const CLSID png{0x557cf406, 0x1a04, 0x11d3, {0x9a, 0x73, 0x00, 0x00, 0xf8, 0x1e, 0xf3, 0x2e}};
    {
        Gdiplus::Bitmap image(resources.bitmap, nullptr);
        REQUIRE(image.Save((std::filesystem::path(directory) / (name + L".png")).c_str(), &png, nullptr) == Gdiplus::Ok);
    }
}

/** 將受控鍵盤訊息經產品的公開訊息翻譯入口處理。
 * Args:
 *     shell: 原生管理介面。
 *     key: 虛擬按鍵。
 *     message: 按下或放開訊息。
 */
void Key(win::ManagementShell& shell, WPARAM key, UINT message = WM_KEYDOWN) {
    MSG input{};
    input.hwnd = GetFocus(); input.message = message; input.wParam = key;
    if (!shell.Translate(&input)) DispatchMessageW(&input);
}
}

TEST_CASE("Management client stays 800 by 600 logical pixels on connected monitors", "[integration][management]") {
    ManagementFixture fixture;
    std::vector<RECT> monitors;
    EnumDisplayMonitors(nullptr, nullptr, [](HMONITOR, HDC, LPRECT bounds, LPARAM data) -> BOOL {
        reinterpret_cast<std::vector<RECT>*>(data)->push_back(*bounds);
        return TRUE;
    }, reinterpret_cast<LPARAM>(&monitors));
    REQUIRE_FALSE(monitors.empty());
    for (const auto& monitor : monitors) {
        SetWindowPos(fixture.manager, nullptr, monitor.left + 10, monitor.top + 10, 0, 0,
            SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        RECT client{};
        REQUIRE(GetClientRect(fixture.manager, &client));
        const auto dpi = GetDpiForWindow(fixture.manager);
        INFO("實測 DPI=" << dpi);
        REQUIRE(client.right == MulDiv(800, dpi, 96));
        REQUIRE(client.bottom == MulDiv(600, dpi, 96));
    }
}

TEST_CASE("Management unidentified monitors cannot be checked or returned for saving", "[integration][management]") {
    ManagementFixture fixture;
    desktopmonitor::app::AppSettings saved;
    saved.monitorTargets = std::vector<std::string>{"known"};
    fixture.shell.SetMonitors({{"known", L"可辨識"}, {"", L"無法辨識"}});
    fixture.shell.SetPreferences(saved);
    const auto list = GetDlgItem(fixture.manager, 20108);
    ListView_SetCheckState(list, 1, TRUE);
    REQUIRE_FALSE(ListView_GetCheckState(list, 1));
    REQUIRE(fixture.shell.Preferences().monitorTargets == saved.monitorTargets);
    ListView_SetItemState(list, 1, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED);
    SetFocus(list);
    Key(fixture.shell, VK_SPACE);
    Key(fixture.shell, VK_SPACE, WM_KEYUP);
    REQUIRE_FALSE(ListView_GetCheckState(list, 1));
    fixture.shell.SetMonitors({{"known", L"可辨識"}, {"recovered", L"恢復辨識"}});
    ListView_SetCheckState(list, 1, TRUE);
    REQUIRE(fixture.shell.Preferences().monitorTargets == std::vector<std::string>{"known", "recovered"});
}

TEST_CASE("Management refuses maximize and arbitrary resizing", "[integration][management]") {
    ManagementFixture fixture;
    SendMessageW(fixture.manager, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
    REQUIRE_FALSE(IsZoomed(fixture.manager));
    SetWindowPos(fixture.manager, nullptr, 0, 0, 400, 300, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    RECT client{};
    REQUIRE(GetClientRect(fixture.manager, &client));
    const auto dpi = GetDpiForWindow(fixture.manager);
    REQUIRE(client.right == MulDiv(800, dpi, 96));
    REQUIRE(client.bottom == MulDiv(600, dpi, 96));
}

TEST_CASE("Management long messages and monitor identities remain readable and scrollable", "[integration][management]") {
    ManagementFixture fixture;
    std::wstring message;
    for (int index = 0; index < 40; ++index) message += L"較長的繁體中文錯誤：請查看完整日誌並確認目標設定。\r\n";
    fixture.shell.Update(L"測試主題", message, false, false);
    const auto status = GetDlgItem(fixture.manager, 20100);
    SendMessageW(status, EM_LINESCROLL, 0, 20);
    REQUIRE(SendMessageW(status, EM_GETFIRSTVISIBLELINE, 0, 0) > 0);
    const auto line = SendMessageW(status, EM_GETFIRSTVISIBLELINE, 0, 0);
    fixture.shell.Update(L"測試主題", message, false, false);
    REQUIRE(SendMessageW(status, EM_GETFIRSTVISIBLELINE, 0, 0) == line);

    const std::string identity = "offline-monitor-" + std::string(300, 'x');
    std::vector<win::ManagementMonitor> monitors;
    for (int index = 0; index < 24; ++index)
        monitors.push_back({index == 23 ? identity : "monitor-" + std::to_string(index),
            L"較長的螢幕名稱與完整裝置識別（未連接）" + std::to_wstring(index)});
    fixture.shell.SetMonitors(std::move(monitors));
    const auto list = GetDlgItem(fixture.manager, 20108);
    ListView_SetItemState(list, 23, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED);
    REQUIRE(ListView_EnsureVisible(list, 23, FALSE));
    REQUIRE(ListView_GetTopIndex(list) > 0);
    const auto detail = GetDlgItem(fixture.manager, 20109);
    REQUIRE(detail);
    std::wstring text(GetWindowTextLengthW(detail) + 1, L'\0');
    GetWindowTextW(detail, text.data(), static_cast<int>(text.size()));
    REQUIRE(text.find(std::wstring(identity.begin(), identity.end())) != std::wstring::npos);
    fixture.shell.Show();
    std::vector<RECT> areas;
    EnumDisplayMonitors(nullptr, nullptr, [](HMONITOR, HDC, LPRECT bounds, LPARAM data) -> BOOL {
        reinterpret_cast<std::vector<RECT>*>(data)->push_back(*bounds);
        return TRUE;
    }, reinterpret_cast<LPARAM>(&areas));
    for (const auto& area : areas) {
        SetWindowPos(fixture.manager, nullptr, area.left + 10, area.top + 10, 0, 0,
            SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        Capture(fixture.manager, L"long-text-" + std::to_wstring(GetDpiForWindow(fixture.manager)));
    }
}

TEST_CASE("Management replaces unnamed device paths without losing monitor metadata", "[integration][management]") {
    ManagementFixture fixture;
    fixture.shell.SetMonitors({{"\\\\?\\display#panel#id", L"1. \\\\?\\DISPLAY#PANEL#ID · 1920×1080 · 150%（主螢幕）"}});
    wchar_t label[512]{};
    ListView_GetItemText(GetDlgItem(fixture.manager, 20108), 0, 0, label, 512);
    REQUIRE(std::wstring(label).find(L"DISPLAY#") == std::wstring::npos);
    REQUIRE(std::wstring(label).find(L"1920×1080 · 150%（主螢幕）") != std::wstring::npos);
}

TEST_CASE("Management layout and keyboard navigation stay reachable at connected DPI", "[integration][management]") {
    ManagementFixture fixture;
    fixture.shell.SetThemes({{"minimal", L"Minimal · 1.0.0（內建）", true},
        {"long-theme", std::wstring(100, L'題') + L" · 1.0.0", false}});
    fixture.shell.SetMonitors({{"monitor-a", L"1. 內建顯示器 · 1920×1080 · 150%（主螢幕）"},
        {"monitor-b", L"2. 外接顯示器 · 1920×1080 · 100%"}});
    desktopmonitor::app::AppSettings saved;
    saved.monitorTargets = std::vector<std::string>{"monitor-a"};
    fixture.shell.SetPreferences(saved);
    fixture.shell.Show();
    REQUIRE(GetFocus() == GetDlgItem(fixture.manager, 20100));
    const std::array<UINT, 18> tabOrder{20100, 20002, 20003, 20101, 20012, 20013,
        20014, 20016, 20005, 20108, 20109, 20102, 20103, 20106, 20010, 20011, 20006, 20100};
    // 目前已為預覽模式且內建主題不可移除，Tab 應跳過這兩個停用按鈕。
    for (std::size_t index = 1; index < tabOrder.size(); ++index) {
        Key(fixture.shell, VK_TAB);
        REQUIRE(GetDlgCtrlID(GetFocus()) == static_cast<int>(tabOrder[index]));
    }
    std::array<BYTE, 256> original{};
    REQUIRE(GetKeyboardState(original.data()));
    auto shifted = original;
    shifted[VK_SHIFT] = 0x80;
    REQUIRE(SetKeyboardState(shifted.data()));
    Key(fixture.shell, VK_TAB);
    SetKeyboardState(original.data());
    REQUIRE(GetDlgCtrlID(GetFocus()) == 20006);
    SetFocus(GetDlgItem(fixture.manager, 20103));
    const bool before = fixture.shell.Preferences().smartSleep;
    Key(fixture.shell, VK_SPACE);
    Key(fixture.shell, VK_SPACE, WM_KEYUP);
    REQUIRE(fixture.shell.Preferences().smartSleep != before);
    SetFocus(GetDlgItem(fixture.manager, 20108));
    ListView_SetItemState(GetFocus(), 0, LVIS_FOCUSED | LVIS_SELECTED, LVIS_FOCUSED | LVIS_SELECTED);
    Key(fixture.shell, VK_SPACE);
    REQUIRE(fixture.shell.Preferences().monitorTargets->empty());
    fixture.shell.SetPreferences(saved);
    REQUIRE(fixture.shell.Preferences().monitorTargets == saved.monitorTargets);

    std::vector<RECT> monitors;
    EnumDisplayMonitors(nullptr, nullptr, [](HMONITOR, HDC, LPRECT bounds, LPARAM data) -> BOOL {
        reinterpret_cast<std::vector<RECT>*>(data)->push_back(*bounds);
        return TRUE;
    }, reinterpret_cast<LPARAM>(&monitors));
    for (const auto& monitor : monitors) {
        SetWindowPos(fixture.manager, nullptr, monitor.left + 10, monitor.top + 10, 0, 0,
            SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
        RECT client{};
        REQUIRE(GetClientRect(fixture.manager, &client));
        const auto dpi = GetDpiForWindow(fixture.manager);
        std::cout << "DPI=" << dpi << " client=" << client.right << 'x' << client.bottom << '\n';
        std::vector<RECT> controls;
        for (auto child = GetWindow(fixture.manager, GW_CHILD); child; child = GetWindow(child, GW_HWNDNEXT)) {
            RECT rect{};
            REQUIRE(GetWindowRect(child, &rect));
            MapWindowPoints(nullptr, fixture.manager, reinterpret_cast<POINT*>(&rect), 2);
            REQUIRE(rect.left >= 0);
            REQUIRE(rect.top >= 0);
            REQUIRE(rect.right <= client.right);
            REQUIRE(rect.bottom <= client.bottom);
            for (const auto& other : controls) {
                RECT overlap{};
                REQUIRE_FALSE(IntersectRect(&overlap, &rect, &other));
            }
            controls.push_back(rect);
        }
        fixture.shell.Update(L"Minimal · 1.0.0", L"運作中。\r\n已選螢幕皆未連接，暫時顯示於主螢幕", false, false);
        SetFocus(GetDlgItem(fixture.manager, 20010));
        UpdateWindow(fixture.manager);
        Capture(fixture.manager, L"fixture-" + std::to_wstring(dpi));
        REQUIRE(SendDlgItemMessageW(fixture.manager, 20101, LB_GETHORIZONTALEXTENT, 0, 0) > MulDiv(360, dpi, 96));
    }
}
