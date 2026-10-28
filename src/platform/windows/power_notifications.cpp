#include "desktopmonitor/platform/windows/power_notifications.h"
#include <wtsapi32.h>
#include <cstring>
#include <utility>

namespace desktopmonitor::platform::windows {
bool PowerNotifications::Initialize(Notify notify) {
    Shutdown();
    notify_ = std::move(notify);
    WNDCLASSW cls{};
    cls.lpfnWndProc = WindowProcedure;
    cls.hInstance = GetModuleHandleW(nullptr);
    cls.lpszClassName = L"DrillPaperPowerEvents";
    if (RegisterClassW(&cls) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
        error_ = GetLastError();
        return false;
    }
    window_ = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, cls.lpszClassName, L"", WS_POPUP,
        0,0,0,0,nullptr,nullptr,cls.hInstance,this);
    if (window_ == nullptr) { error_ = GetLastError(); return false; }
    sessions_ = WTSRegisterSessionNotification(window_, NOTIFY_FOR_THIS_SESSION) != FALSE;
    if (!sessions_) { error_ = GetLastError(); Shutdown(); return false; }
    power_ = RegisterPowerSettingNotification(window_, &GUID_CONSOLE_DISPLAY_STATE, DEVICE_NOTIFY_WINDOW_HANDLE);
    if (power_ == nullptr) { error_ = GetLastError(); Shutdown(); return false; }
    error_ = ERROR_SUCCESS;
    return true;
}

LRESULT CALLBACK PowerNotifications::WindowProcedure(HWND window, UINT message, WPARAM value, LPARAM data) {
    if (message == WM_NCCREATE) {
        const auto* create = reinterpret_cast<const CREATESTRUCTW*>(data);
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(create->lpCreateParams));
    }
    auto* self = reinterpret_cast<PowerNotifications*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    if (self != nullptr && self->notify_) {
        try {
            if (message == WM_WTSSESSION_CHANGE) {
                if (value == WTS_SESSION_LOCK) self->notify_(PowerEvent::Locked);
                else if (value == WTS_SESSION_UNLOCK) self->notify_(PowerEvent::Unlocked);
                return 0;
            }
            if (message == WM_POWERBROADCAST) {
                if (value == PBT_APMSUSPEND) self->notify_(PowerEvent::SystemSuspend);
                else if (value == PBT_APMRESUMEAUTOMATIC || value == PBT_APMRESUMESUSPEND) self->notify_(PowerEvent::SystemResume);
                else if (value == PBT_POWERSETTINGCHANGE && data != 0) {
                    const auto* setting = reinterpret_cast<const POWERBROADCAST_SETTING*>(data);
                    if (IsEqualGUID(setting->PowerSetting, GUID_CONSOLE_DISPLAY_STATE) && setting->DataLength >= sizeof(DWORD)) {
                        DWORD state = 0;
                        std::memcpy(&state, setting->Data, sizeof(state));
                        self->notify_(state == 0 ? PowerEvent::DisplayOff : PowerEvent::DisplayOn);
                    }
                }
                return TRUE;
            }
        } catch (...) { OutputDebugStringW(L"處理電源／工作階段事件失敗。\n"); }
    }
    if (message == WM_NCDESTROY) SetWindowLongPtrW(window, GWLP_USERDATA, 0);
    return DefWindowProcW(window, message, value, data);
}

void PowerNotifications::Shutdown() {
    notify_ = {};
    if (power_ != nullptr) { UnregisterPowerSettingNotification(power_); power_ = nullptr; }
    if (sessions_ && window_ != nullptr) WTSUnRegisterSessionNotification(window_);
    sessions_ = false;
    if (window_ != nullptr) { DestroyWindow(window_); window_ = nullptr; }
}

bool PowerNotifications::ForegroundIsFullscreen(HWND appWindow) {
    HWND foreground = GetForegroundWindow();
    if (foreground == nullptr || foreground == appWindow || IsIconic(foreground)) return false;
    wchar_t name[64]{};
    GetClassNameW(foreground, name, 64);
    if (wcscmp(name, L"Progman") == 0 || wcscmp(name, L"WorkerW") == 0 || wcscmp(name, L"Shell_TrayWnd") == 0) return false;
    RECT bounds{};
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    if (!GetWindowRect(foreground, &bounds) || !GetMonitorInfoW(MonitorFromWindow(foreground, MONITOR_DEFAULTTONULL), &monitor)) return false;
    return bounds.left <= monitor.rcMonitor.left && bounds.top <= monitor.rcMonitor.top &&
           bounds.right >= monitor.rcMonitor.right && bounds.bottom >= monitor.rcMonitor.bottom;
}
}
