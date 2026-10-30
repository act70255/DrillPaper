#pragma once
#include <windows.h>
#include <string>
#include <vector>
#include <functional>
#include <stdexcept>
#include "desktopmonitor/runtime/monitor_targets.h"

namespace desktopmonitor::platform::windows {
struct MonitorInfo {
    runtime::MonitorTarget target;
    std::wstring name;
    RECT bounds{};
    UINT dpi = 96;
    std::string identificationError;
    /** 比較會影響清單或定位的完整螢幕配置。
     * Args:
     *     other: 另一次列舉的目標。
     * Returns:
     *     配置完全相同時為 true。
     */
    bool operator==(const MonitorInfo& other) const {
        return target.id == other.target.id && target.area == other.target.area &&
            target.primary == other.target.primary && name == other.name && EqualRect(&bounds, &other.bounds) && dpi == other.dpi &&
            identificationError == other.identificationError;
    }
};
/** 列舉 active target、桌面幾何及有效 DPI，識別失敗者使用空 ID。
 * Args:
 *     readDeviceInfo: Windows 裝置名稱讀取邊界，可注入故障。
 * Returns:
 *     目前連接的 target，clone 共用 area；API 失敗時拋出繁體中文錯誤。
 */
using MonitorDeviceInfoReader = std::function<LONG(DISPLAYCONFIG_DEVICE_INFO_HEADER*)>;
std::vector<MonitorInfo> EnumerateMonitors(MonitorDeviceInfoReader readDeviceInfo = DisplayConfigGetDeviceInfo);
/** 在拓樸列舉不可用時讀取原生主螢幕，絕不產生穩定 ID。
 * Returns:
 *     主螢幕矩形與有效 DPI。
 */
MonitorInfo PrimaryMonitorFallback();

class MonitorInventory final {
public:
    /** 指定原生列舉及首次失敗的主螢幕讀取邊界。
     * Args:
     *     enumerate: 目前完整連接資訊。
     *     primary: 首次列舉失敗時的原生主螢幕。
     */
    explicit MonitorInventory(std::function<std::vector<MonitorInfo>()> enumerate = [] { return EnumerateMonitors(); },
        std::function<MonitorInfo()> primary = PrimaryMonitorFallback)
        : enumerate_(std::move(enumerate)), primary_(std::move(primary)) {}
    /** 更新清單，列舉失敗時保留舊結果或首次主螢幕退化。
     * Returns:
     *     清單內容改變時為 true。
     */
    bool Refresh() {
        try {
            auto next = enumerate_();
            if (next.empty()) throw std::runtime_error("列舉未回傳任何桌面區域。");
            const bool changed = next != monitors_;
            monitors_ = std::move(next);
            successful_ = true;
            error_.clear();
            return changed;
        } catch (const std::exception& error) {
            error_ = error.what();
            if (!monitors_.empty()) return false;
            monitors_.push_back(primary_());
            return true;
        }
    }
    /** 取得最近可用清單。
     * Returns:
     *     成功列舉或首次退化的清單。
     */
    const std::vector<MonitorInfo>& Monitors() const { return monitors_; }
    /** 取得最近列舉失敗詳情，恢復成功後清空。
     * Returns:
     *     可供本機日誌記錄的詳細錯誤。
     */
    const std::string& Error() const { return error_; }
    /** 判斷是否尚未取得成功拓樸，只能使用主螢幕退化。
     * Returns:
     *     首次退化清單仍在使用中時為 true。
     */
    bool PrimaryFallback() const { return !successful_ && !monitors_.empty(); }
private:
    std::function<std::vector<MonitorInfo>()> enumerate_;
    std::function<MonitorInfo()> primary_;
    std::vector<MonitorInfo> monitors_;
    std::string error_;
    bool successful_ = false;
};
} // namespace desktopmonitor::platform::windows
