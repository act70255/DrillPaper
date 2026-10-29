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
    /** 將宿主附掛並限制在指定實體螢幕矩形。
     * Args:
     *     window: 本程序的宿主視窗。
     *     bounds: 螢幕實體座標，不是跨屏畫布。
     *     failure: 附掛錯誤接收位置。
     * Returns:
     *     附掛與定位皆成功時為 true。
     */
    bool TryAttach(HWND window, const RECT& bounds, DesktopAttachFailure* failure);
    void RestorePreview(HWND window) override;

private:
    HWND wallpaperLayer_ = nullptr;
};

} // namespace desktopmonitor::platform::windows
