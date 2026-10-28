#include "desktopmonitor/platform/windows/desktop_host.h"

namespace desktopmonitor::platform::windows {
namespace {
constexpr UINT kSpawnWorkerWindowsMessage = 0x052C;
constexpr wchar_t kProgramManagerClass[] = L"Progman";
constexpr wchar_t kIconViewClass[] = L"SHELLDLL_DefView";
constexpr wchar_t kWorkerClass[] = L"WorkerW";

struct ShellWindows {
    HWND iconHost = nullptr;
    HWND iconView = nullptr;
    HWND wallpaperLayer = nullptr;
};

BOOL CALLBACK FindShellWindows(HWND candidate, LPARAM parameter) {
    auto* found = reinterpret_cast<ShellWindows*>(parameter);
    HWND iconView = FindWindowExW(candidate, nullptr, kIconViewClass, nullptr);
    if (iconView == nullptr) {
        return TRUE;
    }

    found->iconHost = candidate;
    found->iconView = iconView;
    found->wallpaperLayer = FindWindowExW(nullptr, candidate, kWorkerClass, nullptr);
    return found->wallpaperLayer == nullptr;
}

ShellWindows LocateShellWindows() {
    ShellWindows found{};
    HWND programManager = FindWindowW(kProgramManagerClass, nullptr);
    if (programManager == nullptr) {
        return found;
    }

    DWORD_PTR ignoredResult = 0;
    SendMessageTimeoutW(programManager, kSpawnWorkerWindowsMessage, 0, 0,
                        SMTO_ABORTIFHUNG, 1000, &ignoredResult);
    EnumWindows(FindShellWindows, reinterpret_cast<LPARAM>(&found));
    if (found.iconView == nullptr || !IsWindow(found.iconView)) {
        found.iconHost = nullptr;
        found.iconView = nullptr;
        found.wallpaperLayer = nullptr;
    }
    if (found.wallpaperLayer != nullptr && !IsWindow(found.wallpaperLayer)) {
        found.wallpaperLayer = nullptr;
    }
    return found;
}

bool SetWindowStyle(HWND window, LONG_PTR style) {
    SetLastError(ERROR_SUCCESS);
    const LONG_PTR previous = SetWindowLongPtrW(window, GWL_STYLE, style);
    return previous != 0 || GetLastError() == ERROR_SUCCESS;
}
} // namespace

bool Win32DesktopHost::TryAttach(HWND window, DesktopAttachFailure* failure) {
    if (failure != nullptr) {
        *failure = DesktopAttachFailure::None;
    }
    if (!IsWindow(window)) {
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::ParentWindowFailed;
        }
        return false;
    }

    HWND programManager = FindWindowW(kProgramManagerClass, nullptr);
    if (programManager == nullptr) {
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::ProgramManagerNotFound;
        }
        return false;
    }

    ShellWindows shell = LocateShellWindows();
    if (shell.iconView == nullptr) {
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::IconHostNotFound;
        }
        return false;
    }
    if (shell.wallpaperLayer == nullptr) {
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::WallpaperLayerNotFound;
        }
        return false;
    }

    SetLastError(ERROR_SUCCESS);
    SetParent(window, shell.wallpaperLayer);
    if (GetLastError() != ERROR_SUCCESS) {
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::ParentWindowFailed;
        }
        return false;
    }

    const LONG_PTR style = GetWindowLongPtrW(window, GWL_STYLE);
    if (!SetWindowStyle(window, (style & ~WS_OVERLAPPEDWINDOW & ~WS_POPUP) | WS_CHILD)) {
        SetParent(window, nullptr);
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::ParentWindowFailed;
        }
        return false;
    }

    RECT parentBounds{};
    if (!GetClientRect(shell.wallpaperLayer, &parentBounds) ||
        parentBounds.right - parentBounds.left < GetSystemMetrics(SM_CXSCREEN) ||
        parentBounds.bottom - parentBounds.top < GetSystemMetrics(SM_CYSCREEN) ||
        !SetWindowPos(window, HWND_BOTTOM, parentBounds.left, parentBounds.top,
                      parentBounds.right - parentBounds.left,
                      parentBounds.bottom - parentBounds.top,
                      SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_SHOWWINDOW)) {
        RestorePreview(window);
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::WindowPlacementFailed;
        }
        return false;
    }

    SetWindowLongPtrW(window, GWL_EXSTYLE,
                      GetWindowLongPtrW(window, GWL_EXSTYLE) | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW);
    wallpaperLayer_ = shell.wallpaperLayer;
    return true;
}

void Win32DesktopHost::RestorePreview(HWND window) {
    if (!IsWindow(window)) {
        wallpaperLayer_ = nullptr;
        return;
    }

    SetParent(window, nullptr);
    const LONG_PTR style = GetWindowLongPtrW(window, GWL_STYLE);
    SetWindowStyle(window, (style & ~WS_CHILD) | WS_OVERLAPPEDWINDOW | WS_VISIBLE);
    const LONG_PTR extendedStyle = GetWindowLongPtrW(window, GWL_EXSTYLE);
    SetWindowLongPtrW(window, GWL_EXSTYLE,
                      extendedStyle & ~WS_EX_NOACTIVATE & ~WS_EX_TOOLWINDOW);
    SetWindowPos(window, HWND_TOP, 0, 0, 760, 480,
                 SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
    wallpaperLayer_ = nullptr;
}

} // namespace desktopmonitor::platform::windows
