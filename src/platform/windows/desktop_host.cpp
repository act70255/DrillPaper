#include "desktopmonitor/platform/windows/desktop_host.h"

namespace desktopmonitor::platform::windows {
namespace {
constexpr UINT kSpawnWorkerWindowsMessage = 0x052C;
constexpr wchar_t kProgramManagerClass[] = L"Progman";
constexpr wchar_t kIconViewClass[] = L"SHELLDLL_DefView";
constexpr wchar_t kWorkerClass[] = L"WorkerW";

struct ShellWindows {
    DWORD shellProcess = 0;
    HWND iconHost = nullptr;
    HWND iconView = nullptr;
    HWND wallpaperLayer = nullptr;
};

/** 確認視窗由本次 Shell 程序持有。
 * Args:
 *     window: 待確認的原生視窗。
 *     shellProcess: 由 GetShellWindow 取得的非零程序識別碼。
 * Returns:
 *     視窗仍有效且所屬程序符合時為 true。
 */
bool IsShellWindow(HWND window, DWORD shellProcess) {
    DWORD process = 0;
    return shellProcess != 0 && IsWindow(window) &&
           GetWindowThreadProcessId(window, &process) != 0 && process == shellProcess;
}

BOOL CALLBACK FindShellWindows(HWND candidate, LPARAM parameter) {
    auto* found = reinterpret_cast<ShellWindows*>(parameter);
    if (!IsShellWindow(candidate, found->shellProcess)) return TRUE;
    HWND iconView = FindWindowExW(candidate, nullptr, kIconViewClass, nullptr);
    if (!IsShellWindow(iconView, found->shellProcess)) {
        return TRUE;
    }

    found->iconHost = candidate;
    found->iconView = iconView;
    found->wallpaperLayer = FindWindowExW(nullptr, candidate, kWorkerClass, nullptr);
    while (found->wallpaperLayer != nullptr &&
           !IsShellWindow(found->wallpaperLayer, found->shellProcess)) {
        found->wallpaperLayer = FindWindowExW(nullptr, found->wallpaperLayer, kWorkerClass, nullptr);
    }
    return found->wallpaperLayer == nullptr;
}

ShellWindows LocateShellWindows(HWND programManager) {
    ShellWindows found{};
    GetWindowThreadProcessId(programManager, &found.shellProcess);
    if (!IsShellWindow(programManager, found.shellProcess)) {
        return found;
    }

    DWORD_PTR ignoredResult = 0;
    SendMessageTimeoutW(programManager, kSpawnWorkerWindowsMessage, 0xD, 1,
                        SMTO_ABORTIFHUNG, 1000, &ignoredResult);
    EnumWindows(FindShellWindows, reinterpret_cast<LPARAM>(&found));
    // 新版 Shell 將桌布層放在 Progman 內，位於圖示檢視的後方。
    if (found.iconHost == programManager &&
        (GetWindowLongPtrW(programManager, GWL_EXSTYLE) & WS_EX_NOREDIRECTIONBITMAP) != 0) {
        HWND child = FindWindowExW(programManager, nullptr, kWorkerClass, nullptr);
        if (IsShellWindow(child, found.shellProcess) &&
            FindWindowExW(child, nullptr, kIconViewClass, nullptr) == nullptr) {
            found.wallpaperLayer = child;
        }
    }
    if (found.iconView == nullptr || !IsWindow(found.iconView)) {
        found.iconHost = nullptr;
        found.iconView = nullptr;
        found.wallpaperLayer = nullptr;
    }
    if (!IsShellWindow(found.wallpaperLayer, found.shellProcess) ||
        FindWindowExW(found.wallpaperLayer, nullptr, kIconViewClass, nullptr) != nullptr) {
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

bool Win32DesktopHost::IsCurrentThreadWindow(HWND window) const {
    DWORD process = 0;
    return window && GetWindowThreadProcessId(window, &process) == GetCurrentThreadId() &&
        process == GetCurrentProcessId();
}

bool Win32DesktopHost::IsAttached(HWND window) const {
    DWORD parentProcess = 0, shellProcess = 0;
    const HWND parent = GetParent(window);
    GetWindowThreadProcessId(parent, &parentProcess);
    GetWindowThreadProcessId(GetShellWindow(), &shellProcess);
    return parent && shellProcess && parentProcess == shellProcess;
}

void Win32DesktopHost::RecordAttachment(HWND window, ULONG_PTR epoch, UINT dpi) const {
    SetPropW(window, L"DrillPaper.DesktopEpoch", reinterpret_cast<HANDLE>(epoch));
    RemovePropW(window, L"DrillPaper.DesktopFailure");
    SetPropW(window, L"DrillPaper.TargetDpi", reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(dpi)));
}

void Win32DesktopHost::RecordAttachmentFailure(HWND window, DesktopAttachFailure failure) const {
    SetPropW(window, L"DrillPaper.DesktopFailure", reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(failure)));
}

bool Win32DesktopHost::TryAttach(HWND window, DesktopAttachFailure* failure) {
    RECT bounds{GetSystemMetrics(SM_XVIRTUALSCREEN), GetSystemMetrics(SM_YVIRTUALSCREEN),
        GetSystemMetrics(SM_XVIRTUALSCREEN) + GetSystemMetrics(SM_CXVIRTUALSCREEN),
        GetSystemMetrics(SM_YVIRTUALSCREEN) + GetSystemMetrics(SM_CYVIRTUALSCREEN)};
    return TryAttach(window, bounds, failure);
}

bool Win32DesktopHost::TryAttach(HWND window, const RECT& bounds, DesktopAttachFailure* failure) {
    if (failure != nullptr) {
        *failure = DesktopAttachFailure::None;
    }
    if (!IsWindow(window)) {
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::ParentWindowFailed;
        }
        return false;
    }

    HWND programManager = GetShellWindow();
    wchar_t shellClass[256]{};
    if (!IsWindow(programManager) || GetClassNameW(programManager, shellClass, 256) == 0 ||
        lstrcmpW(shellClass, kProgramManagerClass) != 0) {
        if (failure != nullptr) {
            *failure = DesktopAttachFailure::ProgramManagerNotFound;
        }
        return false;
    }

    ShellWindows shell = LocateShellWindows(programManager);
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
    const HWND previousParent = SetParent(window, shell.wallpaperLayer);
    if (previousParent == nullptr && GetLastError() != ERROR_SUCCESS) {
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
    RECT local = bounds;
    SetLastError(ERROR_SUCCESS);
    const auto mapped = MapWindowPoints(nullptr, shell.wallpaperLayer, reinterpret_cast<POINT*>(&local), 2);
    if ((mapped == 0 && GetLastError() != ERROR_SUCCESS) ||
        !GetClientRect(shell.wallpaperLayer, &parentBounds) || bounds.right <= bounds.left || bounds.bottom <= bounds.top ||
        local.left < parentBounds.left || local.top < parentBounds.top || local.right > parentBounds.right || local.bottom > parentBounds.bottom ||
        !SetWindowPos(window, HWND_BOTTOM, local.left, local.top,
                      local.right - local.left, local.bottom - local.top,
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
