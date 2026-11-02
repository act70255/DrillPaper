#include "desktopmonitor/app/settings_store.h"
#include <windows.h>
#include <objbase.h>
#include <nlohmann/json.hpp>
#include <fstream>
#include <regex>
#include <stdexcept>
#include <algorithm>

namespace desktopmonitor::app {
namespace {
/** 拒絕相對路徑、重新解析點與非一般檔案。
 * Args:
 *     file: 設定檔位置。
 */
void ValidateLocation(const std::filesystem::path& file) {
    if (!file.is_absolute() || file.filename().empty()) throw std::runtime_error("設定檔必須使用完整絕對路徑。");
    auto current = file.lexically_normal();
    while (!current.empty()) {
        const auto attributes = GetFileAttributesW(current.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES) {
            const auto error = GetLastError();
            if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PATH_NOT_FOUND)
                throw std::runtime_error("無法檢查設定檔路徑或權限。");
        } else if (attributes & FILE_ATTRIBUTE_REPARSE_POINT)
            throw std::runtime_error("設定檔路徑不得經過重新解析點。");
        else if (current == file && (attributes & FILE_ATTRIBUTE_DIRECTORY))
            throw std::runtime_error("設定檔位置是資料夾，無法讀寫。");
        const auto parent = current.parent_path();
        if (parent == current) break;
        current = parent;
    }
}

/** 驗證可保存的主題識別與選項。
 * Args:
 *     settings: 完整偏好。
 */
void Validate(const AppSettings& settings) {
    static const std::regex theme(R"((minimal|dashboard|[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?@(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?))");
    if (settings.theme.size() > 240 || !std::regex_match(settings.theme, theme))
        throw std::runtime_error("設定中的主題識別不合法。");
    if (settings.monitorTargets) {
        const auto& targets = *settings.monitorTargets;
        if (targets.size() > 64 || (settings.desktop && targets.empty()))
            throw std::runtime_error("桌布至少需選擇一個螢幕，且目標不可超過 64 個。");
        for (std::size_t index = 0; index < targets.size(); ++index) {
            const auto& id = targets[index];
            if (id.empty() || id.size() > 2048 || id.find_first_of("\r\n\t") != std::string::npos ||
                id.find('\0') != std::string::npos ||
                std::find(targets.begin(), targets.begin() + index, id) != targets.begin() + index)
                throw std::runtime_error("螢幕目標識別不合法或重複。");
        }
    }
}
}

AppSettings SettingsStore::Load() const {
    ValidateLocation(file_);
    if (!std::filesystem::exists(file_)) return {};
    try {
        if (std::filesystem::file_size(file_) > 65536) throw std::runtime_error("設定檔超過大小限制。");
        std::ifstream stream(file_, std::ios::binary);
        if (!stream) throw std::runtime_error("無法開啟設定檔。");
        const auto json = nlohmann::json::parse(stream);
        if (!json.is_object() || !json.at("schemaVersion").is_number_integer() ||
            (json.at("schemaVersion") != 1 && json.at("schemaVersion") != 2) ||
            !json.at("theme").is_string() || !json.at("displayMode").is_string() ||
            !json.at("smartSleep").is_boolean() || !json.at("allowNetwork").is_boolean())
            throw std::runtime_error("設定檔版本或欄位不合法。");
        const auto mode = json.at("displayMode").get<std::string>();
        if (mode != "desktop" && mode != "preview") throw std::runtime_error("設定的顯示模式不合法。");
        AppSettings result{json.at("theme").get<std::string>(), mode == "desktop",
            json.at("smartSleep").get<bool>(), json.at("allowNetwork").get<bool>()};
        if (json.at("schemaVersion") == 2) {
            const auto& targets = json.at("monitorTargets");
            if (!targets.is_array()) throw std::runtime_error("螢幕目標欄位必須是陣列。");
            result.monitorTargets = targets.get<std::vector<std::string>>();
        }
        Validate(result);
        return result;
    } catch (const nlohmann::json::exception&) {
        throw std::runtime_error("設定檔損毀或缺少必要欄位，請備份後修正；未覆蓋原檔。");
    }
}

void SettingsStore::Save(const AppSettings& settings) const {
    Validate(settings);
    if (settings.desktop && !settings.monitorTargets) throw std::runtime_error("尚未解析首次或舊版設定的主螢幕目標，未保存設定。");
    // 已存在的損毀設定必須明確處理，不能在保存時靜默覆蓋。
    Load();
    const nlohmann::json json{{"schemaVersion", 2}, {"theme", settings.theme},
        {"monitorTargets", settings.monitorTargets.value_or(std::vector<std::string>{})},
        {"displayMode", settings.desktop ? "desktop" : "preview"},
        {"smartSleep", settings.smartSleep}, {"allowNetwork", settings.allowNetwork}};
    const auto bytes = json.dump(2) + "\n";
    if (bytes.size() > 65536) throw std::runtime_error("設定內容超過 64 KiB，未取代原設定。");
    std::filesystem::create_directories(file_.parent_path());
    ValidateLocation(file_);
    GUID guid{};
    if (FAILED(CoCreateGuid(&guid))) throw std::runtime_error("無法建立設定暫存識別。");
    wchar_t identifier[40]{};
    StringFromGUID2(guid, identifier, 40);
    const auto temporary = file_.parent_path() / (std::wstring(L".settings-") + identifier + L".tmp");
    HANDLE handle = CreateFileW(temporary.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
    if (handle == INVALID_HANDLE_VALUE) throw std::runtime_error("無法建立設定暫存檔，請確認資料目錄權限。");
    try {
        DWORD written = 0;
        if (!WriteFile(handle, bytes.data(), static_cast<DWORD>(bytes.size()), &written, nullptr) ||
            written != bytes.size() || !FlushFileBuffers(handle)) throw std::runtime_error("設定寫入未完成，未取代原檔。");
        CloseHandle(handle);
        handle = INVALID_HANDLE_VALUE;
        ValidateLocation(file_);
        if (!MoveFileExW(temporary.c_str(), file_.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
            throw std::runtime_error("無法原子保存設定，原檔已保留。");
    } catch (...) {
        if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle);
        DeleteFileW(temporary.c_str());
        throw;
    }
}
} // namespace desktopmonitor::app
