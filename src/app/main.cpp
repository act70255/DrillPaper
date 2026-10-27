#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

namespace {
constexpr wchar_t kWindowClass[] = L"DesktopMonitorPreviewWindow";
constexpr wchar_t kWindowTitle[] = L"DesktopMonitor Preview";

LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_PAINT: {
        PAINTSTRUCT paint{};
        const HDC dc = BeginPaint(window, &paint);
        RECT client{};
        GetClientRect(window, &client);

        HBRUSH background = CreateSolidBrush(RGB(20, 28, 40));
        FillRect(dc, &client, background);
        DeleteObject(background);

        SetBkMode(dc, TRANSPARENT);
        SetTextColor(dc, RGB(235, 240, 248));
        DrawTextW(dc, L"DesktopMonitor Preview", -1, &client,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE);

        RECT marker{client.left + 24, client.top + 24, client.left + 48, client.top + 48};
        HBRUSH accent = CreateSolidBrush(RGB(66, 190, 150));
        FillRect(dc, &marker, accent);
        DeleteObject(accent);

        EndPaint(window, &paint);
        return 0;
    }
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(window, message, wParam, lParam);
    }
}
} // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int showCommand) {
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    WNDCLASSW windowClass{};
    windowClass.lpfnWndProc = WindowProcedure;
    windowClass.hInstance = instance;
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    windowClass.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    windowClass.lpszClassName = kWindowClass;
    if (RegisterClassW(&windowClass) == 0) {
        return static_cast<int>(GetLastError());
    }

    HWND window = CreateWindowExW(
        0, kWindowClass, kWindowTitle, WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 760, 480,
        nullptr, nullptr, instance, nullptr);
    if (window == nullptr) {
        return static_cast<int>(GetLastError());
    }

    ShowWindow(window, showCommand);
    UpdateWindow(window);

    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    return static_cast<int>(message.wParam);
}
