// 測試替身：只建立與產品同類別名稱的隱藏管理視窗，收到正式結束命令時退出。
// 帶 --ignore-exit 時忽略命令，用來驗證逾時；帶 --no-window 時不建立管理視窗，模擬以 --preview 啟動的實例。
// 30 秒安全計時器避免殘留。
#include "desktopmonitor/platform/windows/management_shell.h"
#include <windows.h>
#include <cwchar>

namespace {

namespace win = desktopmonitor::platform::windows;
constexpr UINT_PTR kSafetyTimer = 1;
constexpr UINT kSafetyMilliseconds = 30000;
bool gIgnoreExit = false;

/** 處理替身管理視窗的訊息。
 * Args:
 *     window: 視窗。
 *     message: 訊息。
 *     value: WPARAM。
 *     data: LPARAM。
 * Returns:
 *     訊息處理結果。
 */
LRESULT CALLBACK FixtureProc(HWND window, UINT message, WPARAM value, LPARAM data) {
    if (message == WM_COMMAND && LOWORD(value) == win::kManageExit && HIWORD(value) == BN_CLICKED && !gIgnoreExit) {
        PostQuitMessage(0);
        return 0;
    }
    if (message == WM_TIMER && value == kSafetyTimer) { PostQuitMessage(3); return 0; }
    return DefWindowProcW(window, message, value, data);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR commandLine, int) {
    if (std::wcsstr(commandLine, L"--no-window") != nullptr) {
        Sleep(kSafetyMilliseconds);
        return 3;
    }
    gIgnoreExit = std::wcsstr(commandLine, L"--ignore-exit") != nullptr;
    WNDCLASSW type{};
    type.lpfnWndProc = FixtureProc;
    type.hInstance = instance;
    type.lpszClassName = win::kManagementWindowClass;
    if (!RegisterClassW(&type)) return 2;
    const HWND window = CreateWindowExW(0, type.lpszClassName, L"DrillPaper 管理", WS_OVERLAPPEDWINDOW,
                                        0, 0, 100, 100, nullptr, nullptr, instance, nullptr);
    if (!window) return 2;
    SetTimer(window, kSafetyTimer, kSafetyMilliseconds, nullptr);
    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) { TranslateMessage(&message); DispatchMessageW(&message); }
    return static_cast<int>(message.wParam);
}
