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
    /** 確認視窗仍屬於目前程序的 UI 執行緒。
     * Args:
     *     window: 待驗證的宿主視窗。
     * Returns:
     *     HWND 非空且程序與執行緒皆符合時為 true。
     */
    bool IsCurrentThreadWindow(HWND window) const;
    /** 依現有父視窗與 Shell 程序識別判斷是否仍附掛。
     * Args:
     *     window: 待檢查的宿主視窗。
     * Returns:
     *     父視窗存在且所屬程序為目前非零 Shell 程序時為 true。
     */
    bool IsAttached(HWND window) const;
    /** 發布附掛成功診斷，保持既有原生屬性契約。
     * Args:
     *     window: 已附掛的宿主視窗。
     *     epoch: app 分配的全程序附掛成功世代。
     *     dpi: 目標螢幕的 DPI。
     */
    void RecordAttachment(HWND window, ULONG_PTR epoch, UINT dpi) const;
    /** 發布失敗原因，保留先前成功的世代與 DPI。
     * Args:
     *     window: 附掛失敗的宿主視窗。
     *     failure: 本次附掛的錯誤代碼。
     */
    void RecordAttachmentFailure(HWND window, DesktopAttachFailure failure) const;
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
