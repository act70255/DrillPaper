#pragma once
#include <filesystem>
#include <string>
#include <optional>
#include <vector>

namespace desktopmonitor::app {
struct AppSettings {
    std::string theme = "minimal";
    bool desktop = true;
    bool smartSleep = true;
    bool allowNetwork = false;
    std::optional<std::vector<std::string>> monitorTargets;
    bool operator==(const AppSettings&) const = default;
};

class SettingsStore final {
public:
    /** 指定設定檔位置。
     * Args:
     *     file: 必須為絕對路徑。
     */
    explicit SettingsStore(std::filesystem::path file) : file_(std::move(file)) {}
    /** 讀取並驗證設定，首次尚無檔案時採用產品預設偏好。
     * Returns:
     *     有效偏好；資源或內容錯誤拋出友善錯誤。
     */
    AppSettings Load() const;
    /** 原子保存有效設定；既有損毀檔不覆寫。
     * Args:
     *     settings: 要保存的完整偏好。
     */
    void Save(const AppSettings& settings) const;
private:
    std::filesystem::path file_;
};
} // namespace desktopmonitor::app
