#include "desktopmonitor/platform/windows/monitor_info.h"
#include <shellscalingapi.h>
#include <algorithm>
#include <stdexcept>

namespace desktopmonitor::platform::windows {
namespace {
/** 將 Windows 裝置識別轉成可保存的 UTF-8。
 * Args:
 *     text: 非空裝置路徑。
 * Returns:
 *     小寫 UTF-8 識別。
 */
std::string DeviceId(std::wstring text) {
    CharLowerBuffW(text.data(), static_cast<DWORD>(text.size()));
    const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.c_str(), -1, nullptr, 0, nullptr, nullptr);
    if (size <= 1) throw std::runtime_error("無法取得螢幕的穩定識別。");
    std::string bytes(size, '\0');
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.c_str(), -1, bytes.data(), size, nullptr, nullptr);
    bytes.pop_back();
    return bytes;
}
struct DesktopArea { std::wstring device; HMONITOR monitor; MONITORINFOEXW info; };
/** 收集目前桌面 source 對應的原生監視器。
 * Args:
 *     monitor: Windows 列舉的監視器。
 *     data: 接收桌面區域的容器。
 * Returns:
 *     列舉是否可繼續。
 */
BOOL CALLBACK CollectArea(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
    MONITORINFOEXW info{};
    info.cbSize = sizeof(info);
    if (!GetMonitorInfoW(monitor, &info)) return FALSE;
    reinterpret_cast<std::vector<DesktopArea>*>(data)->push_back({info.szDevice, monitor, info});
    return TRUE;
}
}

std::vector<MonitorInfo> EnumerateMonitors() {
    std::vector<DISPLAYCONFIG_PATH_INFO> paths;
    std::vector<DISPLAYCONFIG_MODE_INFO> modes;
    LONG status = ERROR_INSUFFICIENT_BUFFER;
    for (int attempt = 0; attempt < 4 && status == ERROR_INSUFFICIENT_BUFFER; ++attempt) {
        UINT pathCount = 0, modeCount = 0;
        status = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &pathCount, &modeCount);
        if (status != ERROR_SUCCESS) break;
        paths.resize(pathCount); modes.resize(modeCount);
        status = QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &pathCount, paths.data(), &modeCount, modes.data(), nullptr);
        if (status == ERROR_SUCCESS) { paths.resize(pathCount); modes.resize(modeCount); }
    }
    if (status != ERROR_SUCCESS) throw std::runtime_error("無法列舉螢幕拓樸，Windows 代碼：" + std::to_string(status));
    std::vector<DesktopArea> areas;
    if (!EnumDisplayMonitors(nullptr, nullptr, CollectArea, reinterpret_cast<LPARAM>(&areas)))
        throw std::runtime_error("無法取得螢幕桌面區域。");
    std::vector<MonitorInfo> result;
    for (const auto& path : paths) {
        DISPLAYCONFIG_TARGET_DEVICE_NAME target{};
        target.header = {DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME, sizeof(target), path.targetInfo.adapterId, path.targetInfo.id};
        DISPLAYCONFIG_SOURCE_DEVICE_NAME source{};
        source.header = {DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME, sizeof(source), path.sourceInfo.adapterId, path.sourceInfo.id};
        if (DisplayConfigGetDeviceInfo(&target.header) != ERROR_SUCCESS ||
            DisplayConfigGetDeviceInfo(&source.header) != ERROR_SUCCESS || target.monitorDevicePath[0] == L'\0')
            throw std::runtime_error("螢幕缺少穩定裝置識別，未猜測或變更套用目標。");
        const auto area = std::find_if(areas.begin(), areas.end(), [&](const auto& entry) { return entry.device == source.viewGdiDeviceName; });
        if (area == areas.end()) throw std::runtime_error("無法將螢幕裝置對應至桌面區域。");
        UINT dpiX = 0, dpiY = 0;
        if (FAILED(GetDpiForMonitor(area->monitor, MDT_EFFECTIVE_DPI, &dpiX, &dpiY)) || dpiX == 0)
            throw std::runtime_error("無法取得螢幕 DPI，未套用錯誤縮放。");
        const auto group = std::to_string(path.sourceInfo.adapterId.HighPart) + ":" +
            std::to_string(path.sourceInfo.adapterId.LowPart) + ":" + std::to_string(path.sourceInfo.id);
        result.push_back({{DeviceId(target.monitorDevicePath), group, (area->info.dwFlags & MONITORINFOF_PRIMARY) != 0},
            target.monitorFriendlyDeviceName[0] ? target.monitorFriendlyDeviceName : target.monitorDevicePath, area->info.rcMonitor, dpiX});
    }
    if (result.empty()) throw std::runtime_error("目前沒有可辨識的螢幕，請確認顯示設定。");
    std::sort(result.begin(), result.end(), [](const auto& a, const auto& b) { return a.target.id < b.target.id; });
    return result;
}
} // namespace desktopmonitor::platform::windows
