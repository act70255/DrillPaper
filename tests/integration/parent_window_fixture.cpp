#include <windows.h>
#include <shellapi.h>

#include <cstdint>
#include <filesystem>
#include <fstream>

namespace {
/** 接收測試專屬父視窗的關閉訊息。
 * Args:
 *     window: 本 fixture 的視窗。
 *     message: Win32 訊息。
 *     wParam: 訊息參數。
 *     lParam: 訊息參數。
 * Returns:
 *     Win32 訊息處理結果。
 */
LRESULT CALLBACK FixtureProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    if (message == WM_DESTROY) { PostQuitMessage(0); return 0; }
    return DefWindowProcW(window, message, wParam, lParam);
}
} // namespace

/** 建立隔離的跨程序父視窗，讓整合測試銷毀它而不重啟使用者 Explorer。
 * Args:
 *     instance: 測試程序實例。
 * Returns:
 *     成功正常關閉為 0，建立或寫入失敗為非零。
 */
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    int count = 0;
    auto** arguments = CommandLineToArgvW(GetCommandLineW(), &count);
    if (arguments == nullptr || count != 2) { if (arguments) LocalFree(arguments); return 2; }
    const std::filesystem::path readyPath(arguments[1]);
    LocalFree(arguments);
    WNDCLASSW definition{};
    definition.lpfnWndProc = FixtureProcedure;
    definition.hInstance = instance;
    definition.lpszClassName = L"DrillPaperParentFixture";
    if (RegisterClassW(&definition) == 0) return 3;
    HWND window = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        definition.lpszClassName, L"DrillPaper parent fixture", WS_POPUP,
        0, 0, GetSystemMetrics(SM_CXVIRTUALSCREEN), GetSystemMetrics(SM_CYVIRTUALSCREEN),
        nullptr, nullptr, instance, nullptr);
    if (window == nullptr) return 4;
    {
        std::ofstream ready(readyPath, std::ios::binary);
        ready << reinterpret_cast<std::uintptr_t>(window);
        ready.flush();
        if (!ready) { DestroyWindow(window); return 5; }
    }
    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) DispatchMessageW(&message);
    return static_cast<int>(message.wParam);
}
