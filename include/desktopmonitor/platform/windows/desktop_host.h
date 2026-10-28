#pragma once

#include <windows.h>

namespace desktopmonitor::platform::windows {

enum class DesktopAttachFailure {
    None,
    ProgramManagerNotFound,
    IconHostNotFound,
    WallpaperLayerNotFound,
    ParentWindowFailed,
    WindowPlacementFailed
};

class IDesktopHost {
public:
    virtual ~IDesktopHost() = default;
    virtual bool TryAttach(HWND window, DesktopAttachFailure* failure) = 0;
    virtual void RestorePreview(HWND window) = 0;
};

class Win32DesktopHost final : public IDesktopHost {
public:
    bool TryAttach(HWND window, DesktopAttachFailure* failure) override;
    void RestorePreview(HWND window) override;

private:
    HWND wallpaperLayer_ = nullptr;
};

} // namespace desktopmonitor::platform::windows
