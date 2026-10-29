#pragma once

#include <filesystem>
#include <string>
#include <vector>

namespace desktopmonitor::themes {

struct ThemeInfo {
    std::string id;
    std::string name;
    std::string version;
    std::string entry;
    std::filesystem::path directory;
};

class ThemeManager final {
public:
    /** 建立以指定目錄為界的主題管理器。
     * Args:
     *     root: 使用者主題安裝目錄，不可為空。
     */
    explicit ThemeManager(std::filesystem::path root);
    /** 驗證並原子安裝主題；相同 ID 與版本禁止覆蓋。
     * Args:
     *     source: 主題資料夾或 .dmt ZIP 檔案。
     * Returns:
     *     已安裝主題的資訊。
     * Throws:
     *     std::runtime_error: 主題不合法或無法安裝。
     */
    ThemeInfo Install(const std::filesystem::path& source);
    /** 列出已驗證的已安裝版本。
     * Returns:
     *     安裝資訊；損壞或暫存目錄不列入。
     */
    std::vector<ThemeInfo> List() const;
    /** 移除安裝目錄內的指定版本，不接受任意檔案路徑。
     * Args:
     *     id: 已安裝主題 ID。
     *     version: 已安裝版本。
     */
    void Remove(const std::string& id, const std::string& version);
    /** 驗證完整主題資料夾與配額。
     * Args:
     *     source: 主題資料夾。
     * Returns:
     *     合法 manifest 與入口資訊。
     */
    static ThemeInfo ValidateDirectory(const std::filesystem::path& source);
private:
    std::filesystem::path root_;
};
} // namespace desktopmonitor::themes
