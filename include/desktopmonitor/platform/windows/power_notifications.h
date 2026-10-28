#pragma once
#include <windows.h>
#include <functional>

namespace desktopmonitor::platform::windows {
enum class PowerEvent { Locked, Unlocked, DisplayOff, DisplayOn, SystemSuspend, SystemResume };
class PowerNotifications final {
public:
    /** 建立尚未註冊的通知監聽器。 */
    PowerNotifications() = default;
    PowerNotifications(const PowerNotifications&) = delete;
    PowerNotifications& operator=(const PowerNotifications&) = delete;
    using Notify = std::function<void(PowerEvent)>;
    /** 在 UI 執行緒建立獨立通知視窗並註冊 Windows 事件。
     * Args:
     *     notify: 在 UI 執行緒呼叫的事件接收器。
     * Returns:
     *     工作階段與顯示器電源通知皆註冊成功時為 true。
     */
    bool Initialize(Notify notify);
    /** 注銷事件與通知視窗。 */
    void Shutdown();
    /** 回收通知資源。 */
    ~PowerNotifications() { Shutdown(); }
    /** 取得最近一次初始化失敗的 Win32 代碼。
     * Returns:
     *     Win32 錯誤碼。
     */
    DWORD LastError() const { return error_; }
    /** 檢查前景視窗是否覆蓋其所在的整個顯示器。
     * Args:
     *     appWindow: 必須排除的 app 自身視窗。
     * Returns:
     *     非 Shell 的其他視窗覆蓋整個顯示器時為 true。
     */
    static bool ForegroundIsFullscreen(HWND appWindow);
private:
    /** 將原生訊息轉成有限的電源事件。
     * Args:
     *     window: 通知視窗。
     *     message: Windows 訊息種類。
     *     value: 工作階段或電源事件代碼。
     *     data: Windows 提供的事件資料。
     * Returns:
     *     Win32 訊息處理結果。
     */
    static LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM value, LPARAM data);
    HWND window_ = nullptr;
    HPOWERNOTIFY power_ = nullptr;
    bool sessions_ = false;
    DWORD error_ = 0;
    Notify notify_;
};
}
