// 測試替身：只建立與產品同類別名稱的隱藏管理視窗，收到正式結束命令時退出。
// 帶 --ignore-exit 時忽略命令，用來驗證逾時；30 秒安全計時器避免殘留。
#include <windows.h>
#include <cwchar>

namespace {

constexpr UINT kManageExit = 20006;
constexpr UINT_PTR kSafetyTimer = 1;
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
    if (message == WM_COMMAND && LOWORD(value) == kManageExit && HIWORD(value) == BN_CLICKED && !gIgnoreExit) {
        PostQuitMessage(0);
        return 0;
    }
    if (message == WM_TIMER && value == kSafetyTimer) { PostQuitMessage(3); return 0; }
    return DefWindowProcW(window, message, value, data);
}

}  // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR commandLine, int) {
    gIgnoreExit = std::wcsstr(commandLine, L"--ignore-exit") != nullptr;
    WNDCLASSW type{};
    type.lpfnWndProc = FixtureProc;
    type.hInstance = instance;
    type.lpszClassName = L"DrillPaperManagementWindow";
    if (!RegisterClassW(&type)) return 2;
    const HWND window = CreateWindowExW(0, type.lpszClassName, L"DrillPaper 管理", WS_OVERLAPPEDWINDOW,
                                        0, 0, 100, 100, nullptr, nullptr, instance, nullptr);
    if (!window) return 2;
    SetTimer(window, kSafetyTimer, 30000, nullptr);
    MSG message;
    while (GetMessageW(&message, nullptr, 0, 0) > 0) { TranslateMessage(&message); DispatchMessageW(&message); }
    return static_cast<int>(message.wParam);
}
