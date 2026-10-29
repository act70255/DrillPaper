#pragma once
#include <windows.h>
#include <string>
#include <vector>
#include "desktopmonitor/runtime/monitor_targets.h"

namespace desktopmonitor::platform::windows {
struct MonitorInfo {
    runtime::MonitorTarget target;
    std::wstring name;
    RECT bounds{};
    UINT dpi = 96;
    /** 比較會影響清單或定位的完整螢幕配置。
     * Args:
     *     other: 另一次列舉的目標。
     * Returns:
     *     配置完全相同時為 true。
     */
    bool operator==(const MonitorInfo& other) const {
        return target.id == other.target.id && target.area == other.target.area &&
            target.primary == other.target.primary && name == other.name && EqualRect(&bounds, &other.bounds) && dpi == other.dpi;
    }
};
/** 列舉可穩定辨識的 active target、桌面幾何及有效 DPI。
 * Returns:
 *     目前連接的 target，clone 共用 area；API 失敗時拋出繁體中文錯誤。
 */
std::vector<MonitorInfo> EnumerateMonitors();
} // namespace desktopmonitor::platform::windows
