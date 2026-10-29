#pragma once

#include <windows.h>
#include <shellapi.h>
#include <functional>
#include <string>
#include <vector>
#include "desktopmonitor/app/settings_store.h"
#include "desktopmonitor/runtime/desktop_recovery_retry.h"

namespace desktopmonitor::platform::windows {

inline constexpr UINT kTrayCallbackMessage = WM_APP + 0x40;
inline constexpr UINT kManageOpen = 20001;
inline constexpr UINT kManagePause = 20002;
inline constexpr UINT kManageDesktop = 20003;
inline constexpr UINT kManagePreview = 20004;
inline constexpr UINT kManageLogs = 20005;
inline constexpr UINT kManageExit = 20006;
inline constexpr UINT kManageApply = 20010;
inline constexpr UINT kManageCancel = 20011;
inline constexpr UINT kManageThemePreview = 20012;
inline constexpr UINT kManageThemeApply = 20013;
inline constexpr UINT kManageImport = 20014;
inline constexpr UINT kManageRemove = 20015;
inline constexpr UINT kManageRefresh = 20016;
struct ManagementTheme { std::string key; std::wstring label; bool builtin = false; };

class ManagementShell final {
public:
    /** 釋放圖示與管理視窗。 */
    ~ManagementShell();
    /** 建立唯一的可信管理視窗及系統匣圖示。
     * Args:
     *     owner: 不附掛 Explorer 的通知視窗。
     *     command: UI 執行緒上的原生管理命令接收端。
     * Returns:
     *     管理視窗建立成功時為 true；圖示失敗仍保留視窗入口。
     */
    bool Initialize(HWND owner, std::function<void(UINT)> command);
    /** 開啟或帶回同一管理視窗。 */
    void Show();
    /** 更新目前有效狀態及選單。
     * Args:
     *     theme: 目前主題名稱。
     *     status: 目前有效狀態與錯誤資訊。
     *     paused: 是否手動暫停。
     *     desktop: 是否使用桌布模式。
     */
    void Update(const std::wstring& theme, const std::wstring& status, bool paused, bool desktop);
    /** 嘗試恢復系統匣，最多十次且間隔至少一秒。
     * Args:
     *     shellRestarted: 是否收到工作列重建通知。
     */
    void Tick(bool shellRestarted = false);
    /** 處理 Shell 的圖示滑鼠與鍵盤通知。
     * Args:
     *     value: Shell 提供的通知參數。
     *     data: Shell 提供的通知事件及圖示 ID。
     */
    void OnTrayCallback(WPARAM value, LPARAM data);
    /** 移除圖示並關閉管理視窗；可重複呼叫。 */
    void Shutdown();
    /** 更新已驗證的主題清單，保留草稿選擇。
     * Args:
     *     themes: 內建及已安裝的合法主題。
     */
    void SetThemes(std::vector<ManagementTheme> themes);
    /** 將有效設定放入可取消的編輯控制項。
     * Args:
     *     settings: 目前有效設定。
     */
    void SetPreferences(const app::AppSettings& settings);
    /** 讀取使用者草稿，不套用或保存。
     * Returns:
     *     草稿設定。
     */
    app::AppSettings Preferences() const;
    /** 讓原生檔案選擇器取得匯入包。
     * Returns:
     *     選擇的路徑，取消時為空。
     */
    std::filesystem::path PickPackage() const;
    /** 確認移除所選的使用者主題。
     * Returns:
     *     使用者明確同意時為 true。
     */
    bool ConfirmRemoval() const;
    /** 處理管理視窗的 Tab／方向鍵導覽。
     * Args:
     *     message: 目前 UI 訊息。
     * Returns:
     *     已處理管理視窗訊息時為 true。
     */
    bool Translate(MSG* message);

private:
    /** 管理視窗的原生訊息入口。
     * Args:
     *     window: 管理視窗。
     *     message: Windows 訊息。
     *     value: 訊息參數。
     *     data: 訊息資料。
     * Returns:
     *     Windows 訊息處理結果。
     */
    static LRESULT CALLBACK Procedure(HWND window, UINT message, WPARAM value, LPARAM data);
    /** 依目前 DPI 排列可信原生控制項。 */
    void Layout();
    /** 建立右鍵快捷選單。 */
    void ShowMenu();
    /** 依目前螢幕 DPI 建立可辨識的圖示。
     * Returns:
     *     擁有的新圖示，失敗時為空值。
     */
    HICON CreateTrayIcon();
    HWND owner_ = nullptr;
    HWND window_ = nullptr;
    HFONT font_ = nullptr;
    HICON icon_ = nullptr;
    std::function<void(UINT)> command_;
    runtime::DesktopRecoveryRetry retry_;
    std::wstring theme_;
    std::wstring status_;
    std::wstring lastTip_;
    bool paused_ = false;
    bool desktop_ = false;
    bool present_ = false;
    bool version4_ = false;
    std::vector<ManagementTheme> themes_;
    app::AppSettings preferences_;
};

} // namespace desktopmonitor::platform::windows
