#pragma once
#include <string>
#include <vector>
#include <algorithm>

namespace desktopmonitor::runtime {
struct MonitorTarget {
    // 空 ID 明確表示無法辨識；area 只供本次拓樸定位，不得保存。
    std::string id;
    std::string area;
    bool primary = false;
};
struct MonitorSelection {
    std::vector<std::size_t> areas;
    bool primaryFallback = false;
    bool unidentifiedFallback = false;
};
/** 解析目前可顯示的目標；幾何與原生裝置讀取由平台層負責。
 * Args:
 *     selected: 保存的穩定目標 ID。
 *     connected: 目前連接的目標與桌面區域。
 * Returns:
 *     每個有效區域的一個代表索引及暫用主螢幕狀態。
 */
inline MonitorSelection ResolveMonitorTargets(const std::vector<std::string>& selected,
    const std::vector<MonitorTarget>& connected) {
    MonitorSelection result;
    result.unidentifiedFallback = std::any_of(connected.begin(), connected.end(), [](const auto& target) { return target.id.empty(); });
    for (std::size_t index = 0; index < connected.size(); ++index)
        if ((result.unidentifiedFallback || std::find(selected.begin(), selected.end(), connected[index].id) != selected.end()) &&
            std::none_of(result.areas.begin(), result.areas.end(), [&](auto chosen) { return connected[chosen].area == connected[index].area; }))
            result.areas.push_back(index);
    if (result.areas.empty() && !selected.empty()) {
        const auto primary = std::find_if(connected.begin(), connected.end(), [](const auto& target) { return target.primary; });
        if (primary != connected.end()) {
            result.areas.push_back(static_cast<std::size_t>(primary - connected.begin()));
            result.primaryFallback = true;
        }
    }
    return result;
}
} // namespace desktopmonitor::runtime
