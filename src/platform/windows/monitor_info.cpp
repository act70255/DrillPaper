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
/** 以本次桌面矩形建立區域鍵，絕不作為保存的裝置 ID。
 * Args:
 *     bounds: 實體桌面矩形。
 * Returns:
 *     相同矩形共用的暫時區域鍵。
 */
std::string AreaKey(const RECT& bounds) {
    return std::to_string(bounds.left) + ":" + std::to_string(bounds.top) + ":" +
        std::to_string(bounds.right) + ":" + std::to_string(bounds.bottom);
}
/** 建立含實體尺寸與有效 DPI 的未辨識項目。
 * Args:
 *     area: 原生桌面區域。
 *     error: 識別失敗的詳細原因。
 * Returns:
 *     不含可保存 ID 的項目。
 */
MonitorInfo Unidentified(const DesktopArea& area, const std::string& error) {
    UINT dpiX = 0, dpiY = 0;
    if (FAILED(GetDpiForMonitor(area.monitor, MDT_EFFECTIVE_DPI, &dpiX, &dpiY)) || dpiX == 0)
        throw std::runtime_error("無法取得螢幕 DPI，未套用錯誤縮放。");
    return {{"", AreaKey(area.info.rcMonitor), (area.info.dwFlags & MONITORINFOF_PRIMARY) != 0},
        L"無法辨識", area.info.rcMonitor, dpiX, error};
}
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

MonitorInfo PrimaryMonitorFallback() {
    const auto monitor = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
    MONITORINFOEXW info{}; info.cbSize = sizeof(info);
    if (!monitor || !GetMonitorInfoW(monitor, &info)) throw std::runtime_error("無法讀取退化用主螢幕桌面區域。");
    return Unidentified({info.szDevice, monitor, info}, "首次列舉失敗，暫時使用主螢幕；未產生穩定 ID。");
}

std::vector<MonitorInfo> EnumerateMonitors(MonitorDeviceInfoReader readDeviceInfo) {
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
    bool unmapped = false;
    for (const auto& path : paths) {
        DISPLAYCONFIG_TARGET_DEVICE_NAME target{};
        target.header = {DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME, sizeof(target), path.targetInfo.adapterId, path.targetInfo.id};
        DISPLAYCONFIG_SOURCE_DEVICE_NAME source{};
        source.header = {DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME, sizeof(source), path.sourceInfo.adapterId, path.sourceInfo.id};
        const auto targetStatus = readDeviceInfo(&target.header);
        const auto sourceStatus = readDeviceInfo(&source.header);
        auto area = std::find_if(areas.begin(), areas.end(), [&](const auto& entry) {
            return sourceStatus == ERROR_SUCCESS && source.viewGdiDeviceName[0] && entry.device == source.viewGdiDeviceName;
        });
        // 名稱失敗時，只用 source mode 定位矩形，不推斷穩定識別。
        if (area == areas.end() && path.sourceInfo.modeInfoIdx < modes.size()) {
            const auto& mode = modes[path.sourceInfo.modeInfoIdx];
            if (mode.infoType == DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE && mode.id == path.sourceInfo.id &&
                mode.adapterId.HighPart == path.sourceInfo.adapterId.HighPart && mode.adapterId.LowPart == path.sourceInfo.adapterId.LowPart) {
                const auto& sourceMode = mode.sourceMode;
                area = std::find_if(areas.begin(), areas.end(), [&](const auto& entry) {
                    const auto& rect = entry.info.rcMonitor;
                    return rect.left == sourceMode.position.x && rect.top == sourceMode.position.y &&
                        rect.right - rect.left == static_cast<LONG>(sourceMode.width) && rect.bottom - rect.top == static_cast<LONG>(sourceMode.height);
                });
            }
        }
        if (area == areas.end()) { unmapped = true; continue; }
        auto monitor = Unidentified(*area, "螢幕識別失敗：target=" + std::to_string(path.targetInfo.id) +
            "，target Windows 代碼=" + std::to_string(targetStatus) + "，source Windows 代碼=" + std::to_string(sourceStatus) +
            "，裝置路徑空白=" + std::to_string(target.monitorDevicePath[0] == L'\0') +
            "，source 名稱空白=" + std::to_string(source.viewGdiDeviceName[0] == L'\0'));
        if (targetStatus == ERROR_SUCCESS && sourceStatus == ERROR_SUCCESS && target.monitorDevicePath[0] && source.viewGdiDeviceName[0]) {
            try {
                monitor.target.id = DeviceId(target.monitorDevicePath);
                monitor.name = target.monitorFriendlyDeviceName[0] ? target.monitorFriendlyDeviceName : target.monitorDevicePath;
                monitor.identificationError.clear();
            } catch (const std::exception& error) { monitor.identificationError += "；" + std::string(error.what()); }
        }
        result.push_back(std::move(monitor));
    }
    // 未能對應的 active path 也必須觸發退化；保守列出各區域的未辨識項目，clone 仍由 area 去重。
    for (const auto& area : areas)
        if (unmapped || std::none_of(result.begin(), result.end(), [&](const auto& m) { return m.target.area == AreaKey(area.info.rcMonitor); }))
            result.push_back(Unidentified(area, "active path 無法對應桌面區域，未推斷裝置識別。"));
    if (result.empty()) throw std::runtime_error("目前沒有可用的桌面區域，請確認顯示設定。");
    std::sort(result.begin(), result.end(), [](const auto& a, const auto& b) { return a.target.id < b.target.id; });
    return result;
}
} // namespace desktopmonitor::platform::windows
