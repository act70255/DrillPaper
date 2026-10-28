#include <windows.h>

#include <array>
#include <cstdint>
#include <filesystem>
#include <memory>
#include <string>

#include "desktopmonitor/monitoring/windows_metrics_collector.h"
#include "desktopmonitor/platform/windows/desktop_host.h"
#include "desktopmonitor/web/webview2_host.h"

namespace {
constexpr wchar_t kWindowClass[] = L"DrillPaperPreviewWindow";
constexpr wchar_t kNotificationClass[] = L"DrillPaperShellNotifications";
constexpr wchar_t kWindowTitle[] = L"DrillPaper Preview";
constexpr wchar_t kExperimentalWindowTitle[] = L"DrillPaper Shell Host POC — Experimental";
constexpr UINT_PTR kMetricsTimer = 1;
constexpr UINT kWebViewFailedMessage = WM_APP + 0x31;
constexpr wchar_t kApplicationVersion[] = L"0.1.0-dev";
const wchar_t* gStatusText = L"Starting the local WebView2 preview…";
desktopmonitor::platform::windows::Win32DesktopHost* gDesktopHost = nullptr;
std::unique_ptr<desktopmonitor::monitoring::WindowsMetricsCollector> gMetricsCollector;
std::unique_ptr<desktopmonitor::web::WebView2Host> gWebViewHost;
desktopmonitor::core::MetricsSnapshot gLatestSnapshot{};
HWND gWallpaperWindow = nullptr;
bool gExperimentalDesktop = false;
bool gMockMetrics = false;
UINT gTaskbarCreatedMessage = 0;

unsigned __int64 CurrentUnixTimeMilliseconds() {
    constexpr unsigned __int64 kWindowsToUnixEpoch100ns = 116444736000000000ULL;
    FILETIME fileTime{};
    GetSystemTimeAsFileTime(&fileTime);
    ULARGE_INTEGER ticks{};
    ticks.LowPart = fileTime.dwLowDateTime;
    ticks.HighPart = fileTime.dwHighDateTime;
    return ticks.QuadPart < kWindowsToUnixEpoch100ns
        ? 0
        : (ticks.QuadPart - kWindowsToUnixEpoch100ns) / 10000ULL;
}

desktopmonitor::core::MetricsSnapshot MakeMockSnapshot() {
    using desktopmonitor::core::MakeAvailable;
    using desktopmonitor::core::MakeUnavailable;
    using desktopmonitor::core::MetricUnit;
    desktopmonitor::core::MetricsSnapshot snapshot{};
    snapshot.timestampUnixMilliseconds = CurrentUnixTimeMilliseconds();
    snapshot.cpuUsage = MakeAvailable(24.5, MetricUnit::Percent);
    snapshot.gpuUsage = MakeUnavailable(MetricUnit::Percent);
    snapshot.memoryUsedBytes = MakeAvailable(8.0 * 1024.0 * 1024.0 * 1024.0, MetricUnit::Bytes);
    snapshot.memoryTotalBytes = MakeAvailable(16.0 * 1024.0 * 1024.0 * 1024.0, MetricUnit::Bytes);
    snapshot.diskActivityPercent = MakeAvailable(3.0, MetricUnit::Percent);
    snapshot.networkReceiveBytesPerSecond = MakeAvailable(128.0 * 1024.0, MetricUnit::BytesPerSecond);
    snapshot.networkTransmitBytesPerSecond = MakeAvailable(32.0 * 1024.0, MetricUnit::BytesPerSecond);
    return snapshot;
}

bool WriteCommandOutput(const std::wstring& text) {
    bool attachedHere = false;
    if (GetConsoleWindow() == nullptr) {
        attachedHere = AttachConsole(ATTACH_PARENT_PROCESS) != FALSE;
    }
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD written = 0;
    if (GetConsoleWindow() != nullptr && output != nullptr && output != INVALID_HANDLE_VALUE &&
        WriteConsoleW(output, text.c_str(), static_cast<DWORD>(text.size()), &written, nullptr)) {
        if (attachedHere) FreeConsole();
        return true;
    }
    if (attachedHere) FreeConsole();
    return false;
}

void RunVersion() {
    const std::wstring text = std::wstring(L"DrillPaper ") + kApplicationVersion + L"\r\n";
    if (!WriteCommandOutput(text)) {
        OutputDebugStringW(text.c_str());
    }
}

void RunDiagnostics() {
    SYSTEM_INFO systemInfo{};
    GetNativeSystemInfo(&systemInfo);
    std::wstring message = L"DrillPaper ";
    message.append(kApplicationVersion);
    message.append(L"\r\nArchitecture: ");
    message.append(systemInfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_AMD64
        ? L"x64" : L"other");
    message.append(L"\r\nWebView2 Runtime: ");
    LPWSTR browserVersion = nullptr;
    if (SUCCEEDED(GetAvailableCoreWebView2BrowserVersionString(nullptr, &browserVersion)) &&
        browserVersion != nullptr) {
        message.append(browserVersion);
        CoTaskMemFree(browserVersion);
    } else {
        message.append(L"not detected");
    }
    if (!WriteCommandOutput(message)) {
        MessageBoxW(nullptr, message.c_str(), L"DrillPaper diagnostics", MB_OK | MB_ICONINFORMATION);
    }
}

void ReportAttachFailure(desktopmonitor::platform::windows::DesktopAttachFailure failure) {
    using desktopmonitor::platform::windows::DesktopAttachFailure;
    switch (failure) {
    case DesktopAttachFailure::ProgramManagerNotFound:
        gStatusText = L"Program Manager window not found; showing Preview.";
        break;
    case DesktopAttachFailure::IconHostNotFound:
        gStatusText = L"Desktop icon host not found; showing Preview.";
        break;
    case DesktopAttachFailure::WallpaperLayerNotFound:
        gStatusText = L"No verified WorkerW layer found; showing Preview.";
        break;
    case DesktopAttachFailure::WindowPlacementFailed:
        gStatusText = L"Shell host bounds are unsuitable; showing Preview.";
        break;
    case DesktopAttachFailure::ParentWindowFailed:
        gStatusText = L"Could not attach to the Shell host; showing Preview.";
        break;
    case DesktopAttachFailure::None:
        gStatusText = L"Shell attachment failed; showing Preview.";
        break;
    }
    OutputDebugStringW(gStatusText);
    OutputDebugStringW(L"\n");
}

bool HasFlag(const wchar_t* commandLine, const wchar_t* flag) {
    if (commandLine == nullptr || flag == nullptr) {
        return false;
    }
    for (const wchar_t* current = commandLine; *current != L'\0'; ++current) {
        if (current != commandLine && current[-1] != L' ' && current[-1] != L'\t') {
            continue;
        }
        const wchar_t* text = current;
        const wchar_t* wanted = flag;
        while (*text != L'\0' && *wanted != L'\0' && *text == *wanted) {
            ++text;
            ++wanted;
        }
        if (*wanted == L'\0' && (*text == L'\0' || *text == L' ' || *text == L'\t')) {
            return true;
        }
    }
    return false;
}

void RecoverDesktopHost() {
    if (!gExperimentalDesktop || gDesktopHost == nullptr || !IsWindow(gWallpaperWindow)) {
        return;
    }

    desktopmonitor::platform::windows::DesktopAttachFailure failure{};
    if (gDesktopHost->TryAttach(gWallpaperWindow, &failure)) {
        gStatusText = L"Shell change detected. Attachment retried; GUI verification is still required.";
        SetWindowTextW(gWallpaperWindow, kExperimentalWindowTitle);
    } else {
        gDesktopHost->RestorePreview(gWallpaperWindow);
        gExperimentalDesktop = false;
        ReportAttachFailure(failure);
        SetWindowTextW(gWallpaperWindow, kWindowTitle);
    }
    InvalidateRect(gWallpaperWindow, nullptr, TRUE);
}

LRESULT CALLBACK NotificationProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    if ((message == gTaskbarCreatedMessage && gTaskbarCreatedMessage != 0) ||
        message == WM_DISPLAYCHANGE) {
        RecoverDesktopHost();
        return 0;
    }
    return DefWindowProcW(window, message, wParam, lParam);
}

LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_SIZE:
        if (gWebViewHost != nullptr) {
            gWebViewHost->Resize();
        }
        return 0;
    case WM_TIMER:
        if (wParam == kMetricsTimer) {
            if (gMockMetrics) {
                gLatestSnapshot = MakeMockSnapshot();
            } else if (gMetricsCollector != nullptr) {
                gMetricsCollector->Collect(gLatestSnapshot);
            }
            if (gWebViewHost != nullptr) {
                gWebViewHost->SetSnapshot(gLatestSnapshot);
            }
        }
        return 0;
    case kWebViewFailedMessage:
        gStatusText = L"WebView2 is unavailable. The native Preview fallback remains active.";
        OutputDebugStringW(gStatusText);
        OutputDebugStringW(L"\n");
        InvalidateRect(window, nullptr, TRUE);
        return 0;
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
        RECT heading = client;
        heading.bottom -= 48;
        DrawTextW(dc, L"DrillPaper Preview", -1, &heading,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        RECT status = client;
        status.top = status.bottom - 48;
        DrawTextW(dc, gStatusText, -1, &status,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE);

        RECT marker{client.left + 24, client.top + 24, client.left + 48, client.top + 48};
        HBRUSH accent = CreateSolidBrush(RGB(66, 190, 150));
        FillRect(dc, &marker, accent);
        DeleteObject(accent);

        EndPaint(window, &paint);
        return 0;
    }
    case WM_NCHITTEST:
        if (gExperimentalDesktop) {
            return HTTRANSPARENT;
        }
        break;
    case WM_DESTROY:
        KillTimer(window, kMetricsTimer);
        if (gWebViewHost != nullptr) {
            gWebViewHost->Shutdown();
        }
        gMetricsCollector.reset();
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(window, message, wParam, lParam);
    }
    return DefWindowProcW(window, message, wParam, lParam);
}
} // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR commandLine, int showCommand) {
    if (HasFlag(commandLine, L"--version")) {
        RunVersion();
        return 0;
    }
    if (HasFlag(commandLine, L"--diagnostics")) {
        RunDiagnostics();
        return 0;
    }

    const bool forcePreview = HasFlag(commandLine, L"--preview");
    gMockMetrics = HasFlag(commandLine, L"--mock-metrics");
    const bool dashboardTheme = HasFlag(commandLine, L"--theme=dashboard");
    const std::wstring themeName = dashboardTheme ? L"dashboard" : L"minimal";
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
    gWallpaperWindow = window;

    const HRESULT apartmentResult = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool comInitialized = SUCCEEDED(apartmentResult);
    if (!comInitialized) {
        gStatusText = L"COM initialization failed. The native Preview fallback remains active.";
    } else {
        if (gMockMetrics) {
            gLatestSnapshot = MakeMockSnapshot();
        } else {
            gMetricsCollector = std::make_unique<desktopmonitor::monitoring::WindowsMetricsCollector>();
            gMetricsCollector->Collect(gLatestSnapshot);
        }
        gWebViewHost = std::make_unique<desktopmonitor::web::WebView2Host>();

        std::array<wchar_t, 32768> executablePath{};
        const DWORD executableLength = GetModuleFileNameW(
            nullptr, executablePath.data(), static_cast<DWORD>(executablePath.size()));
        if (executableLength == 0 || executableLength >= executablePath.size()) {
            gStatusText = L"Could not locate Preview theme assets. The native Preview fallback remains active.";
            gWebViewHost.reset();
        } else {
            const std::filesystem::path themeDirectory =
                std::filesystem::path(executablePath.data()).parent_path() /
                L"resources" / L"themes" / themeName;
            const HRESULT webViewResult = gWebViewHost->Initialize(
                window, themeDirectory.wstring(), themeName);
            if (FAILED(webViewResult)) {
                gStatusText = L"WebView2 failed to initialize. The native Preview fallback remains active.";
                OutputDebugStringW(gStatusText);
                OutputDebugStringW(L"\n");
                gWebViewHost.reset();
            } else {
                gWebViewHost->SetSnapshot(gLatestSnapshot);
            }
        }
        SetTimer(window, kMetricsTimer, 1000, nullptr);
    }

    desktopmonitor::platform::windows::Win32DesktopHost desktopHost;
    gExperimentalDesktop = HasFlag(commandLine, L"--experimental-desktop") &&
                           !forcePreview && !gMockMetrics;
    if (gExperimentalDesktop) {
        gDesktopHost = &desktopHost;
        gTaskbarCreatedMessage = RegisterWindowMessageW(L"TaskbarCreated");
        WNDCLASSW notificationClass{};
        notificationClass.lpfnWndProc = NotificationProcedure;
        notificationClass.hInstance = instance;
        notificationClass.lpszClassName = kNotificationClass;
        const bool classReady = RegisterClassW(&notificationClass) != 0;
        HWND notificationWindow = classReady
            ? CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kNotificationClass, L"",
                              WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, instance, nullptr)
            : nullptr;
        if (notificationWindow == nullptr || gTaskbarCreatedMessage == 0) {
            gExperimentalDesktop = false;
            gDesktopHost = nullptr;
            gStatusText = L"Could not create the Shell recovery listener. Showing Preview.";
        } else {
            desktopmonitor::platform::windows::DesktopAttachFailure failure{};
            if (desktopHost.TryAttach(window, &failure)) {
                gStatusText = L"Shell layer found. Icon, focus, z-order, and recovery checks are still required.";
                SetWindowTextW(window, kExperimentalWindowTitle);
            } else {
                desktopHost.RestorePreview(window);
                gExperimentalDesktop = false;
                ReportAttachFailure(failure);
                SetWindowTextW(window, kWindowTitle);
            }
        }
    }

    ShowWindow(window, showCommand);
    UpdateWindow(window);

    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    gWebViewHost.reset();
    if (comInitialized) {
        CoUninitialize();
    }
    return static_cast<int>(message.wParam);
}
