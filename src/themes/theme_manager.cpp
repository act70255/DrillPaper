#include "desktopmonitor/themes/theme_manager.h"

#include <windows.h>
#include <nlohmann/json.hpp>
#include <miniz.h>
#include <algorithm>
#include <fstream>
#include <random>
#include <regex>
#include <set>
#include <stdexcept>
#include <vector>

namespace desktopmonitor::themes {
namespace {
namespace fs = std::filesystem;
constexpr std::uintmax_t kFileLimit = 10U * 1024U * 1024U;
constexpr std::uintmax_t kTotalLimit = 50U * 1024U * 1024U;

/** 計算已由 JSON parser 驗證的 UTF-8 字串字元數。
 * Args:
 *     value: 合法 UTF-8 字串。
 * Returns:
 *     Unicode 碼點數，不以 UTF-8 位元組數代替字元數。
 */
std::size_t CharacterCount(const std::string& value) {
    return static_cast<std::size_t>(std::count_if(value.begin(), value.end(),
        [](unsigned char character) { return (character & 0xc0U) != 0x80U; }));
}

/** 確認路徑組件可安全用於 Windows 主題目錄。 */
bool SafePath(const std::string& path) {
    if (path.empty() || path.size() > 240 || path.front() == '/' ||
        path.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/") != std::string::npos) return false;
    static const std::regex reserved(R"(^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$)", std::regex::icase);
    std::size_t start = 0;
    while (start < path.size()) {
        const auto end = path.find('/', start);
        const auto part = path.substr(start, end == std::string::npos ? end : end - start);
        if (part.empty() || part == "." || part == ".." || part.back() == '.' || std::regex_match(part, reserved)) return false;
        if (end == std::string::npos) break;
        start = end + 1;
        if (start == path.size()) return false;
    }
    return true;
}

/** 解壓經限額與路徑檢查的 ZIP 到私有暫存目錄。
 * Args:
 *     source: .dmt 檔案。
 *     destination: 本次新建的空白暫存目錄。
 * Throws:
 *     std::runtime_error: 路徑、配額、壓縮資料或寫入不合法。
 */
void ExtractPackage(const fs::path& source, const fs::path& destination) {
    const auto size = fs::file_size(source);
    if (size == 0 || size > kTotalLimit) throw std::runtime_error("主題壓縮檔超過 50 MiB 或為空。");
    std::ifstream input(source, std::ios::binary);
    std::vector<char> compressed(static_cast<std::size_t>(size));
    if (!input.read(compressed.data(), static_cast<std::streamsize>(compressed.size())) || input.peek() != EOF)
        throw std::runtime_error("無法完整讀取主題壓縮檔。");
    mz_zip_archive archive{};
    if (!mz_zip_reader_init_mem(&archive, compressed.data(), compressed.size(), 0))
        throw std::runtime_error("主題不是有效的 ZIP 壓縮檔。");
    try {
        struct Entry { mz_uint index; std::string name; std::size_t size; bool directory; };
        std::vector<Entry> entries;
        std::set<std::string> names;
        std::uintmax_t total = 0;
        unsigned files = 0;
        const auto count = mz_zip_reader_get_num_files(&archive);
        if (count == 0 || count > 512) throw std::runtime_error("主題 ZIP 項目數超出限制。");
        // 先檢查全部 central directory，不依賴 miniz 自動選擇解壓路徑。
        for (mz_uint index = 0; index < count; ++index) {
            mz_zip_archive_file_stat stat{};
            const auto length = mz_zip_reader_get_filename(&archive, index, nullptr, 0);
            if (!mz_zip_reader_file_stat(&archive, index, &stat) || length < 2 || length > 242 ||
                stat.m_is_encrypted || !stat.m_is_supported)
                throw std::runtime_error("主題 ZIP 項目不支援或名稱不合法。");
            std::vector<char> buffer(length);
            if (mz_zip_reader_get_filename(&archive, index, buffer.data(), length) != length)
                throw std::runtime_error("無法讀取 ZIP 路徑。");
            std::string name(buffer.data(), length - 1);
            if (stat.m_is_directory && name.ends_with('/')) name.pop_back();
            auto folded = name;
            std::transform(folded.begin(), folded.end(), folded.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
            const auto unixType = (stat.m_external_attr >> 16) & 0xf000U;
            if (!SafePath(name) || !names.insert(folded).second || (stat.m_external_attr & FILE_ATTRIBUTE_REPARSE_POINT) ||
                (unixType != 0 && unixType != 0x8000U && unixType != 0x4000U))
                throw std::runtime_error("主題 ZIP 含危險路徑、重複名稱或不允許的連結。");
            if (!stat.m_is_directory) {
                total += stat.m_uncomp_size;
                if (++files > 256 || stat.m_uncomp_size > kFileLimit || total > kTotalLimit ||
                    (name == "theme.json" && stat.m_uncomp_size > 256U * 1024U))
                    throw std::runtime_error("主題 ZIP 解壓配額超出限制。");
            } else if (stat.m_uncomp_size != 0) {
                throw std::runtime_error("ZIP 目錄不得包含資料。");
            }
            entries.push_back({index, name, static_cast<std::size_t>(stat.m_uncomp_size), stat.m_is_directory != 0});
        }
        for (const auto& entry : entries) {
            const auto path = destination / entry.name;
            if (entry.directory) { fs::create_directories(path); continue; }
            std::vector<char> bytes(std::max<std::size_t>(1, entry.size));
            // 固定大小的目的緩衝區與 miniz CRC 檢查，避免信任壓縮資料的展開長度。
            if (!mz_zip_reader_extract_to_mem(&archive, entry.index, bytes.data(), entry.size, 0))
                throw std::runtime_error("主題 ZIP 資料或 CRC 驗證失敗。");
            fs::create_directories(path.parent_path());
            std::ofstream output(path, std::ios::binary);
            if (!output.write(bytes.data(), static_cast<std::streamsize>(entry.size)))
                throw std::runtime_error("無法寫入主題暫存檔案。");
            output.close();
            if (!output) throw std::runtime_error("無法完成主題暫存檔案寫入。");
        }
    } catch (...) { mz_zip_reader_end(&archive); throw; }
    mz_zip_reader_end(&archive);
}

/** 驗證目錄及其所有資產；失敗時回傳明確錯誤。 */
ThemeInfo ReadDirectory(const fs::path& source) {
    auto reject = [] { throw std::runtime_error("主題內容不合法或超出限制。"); };
    const auto rootAttributes = GetFileAttributesW(source.c_str());
    if (rootAttributes == INVALID_FILE_ATTRIBUTES || !(rootAttributes & FILE_ATTRIBUTE_DIRECTORY) ||
        (rootAttributes & FILE_ATTRIBUTE_REPARSE_POINT)) reject();
    std::set<std::string> names;
    std::set<std::string> assets;
    std::uintmax_t total = 0;
    unsigned count = 0;
    const std::set<std::string> extensions = {".html", ".css", ".js", ".json", ".png", ".jpg", ".jpeg", ".webp", ".ico", ".woff", ".woff2"};
    for (const auto& item : fs::recursive_directory_iterator(source)) {
        const auto relative = item.path().lexically_relative(source).generic_string();
        if (!SafePath(relative)) reject();
        auto folded = relative;
        std::transform(folded.begin(), folded.end(), folded.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        if (!names.insert(folded).second) reject();
        const auto attributes = GetFileAttributesW(item.path().c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_REPARSE_POINT)) reject();
        if (item.is_directory()) continue;
        if (!item.is_regular_file() || ++count > 256) reject();
        const auto size = item.file_size();
        total += size;
        auto extension = item.path().extension().string();
        std::transform(extension.begin(), extension.end(), extension.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        if (size > kFileLimit || total > kTotalLimit || !extensions.contains(extension)) reject();
        assets.insert(relative);
    }
    const auto manifestPath = source / "theme.json";
    if (!assets.contains("theme.json") || fs::file_size(manifestPath) > 256U * 1024U) reject();
    std::ifstream stream(manifestPath, std::ios::binary);
    auto manifest = nlohmann::json::parse(stream, nullptr, false);
    if (manifest.is_discarded() || !manifest.is_object() || manifest.size() != 9) reject();
    for (const auto* key : {"id", "name", "version", "apiVersion", "entry", "author", "description"}) {
        if (!manifest.contains(key) || !manifest[key].is_string()) reject();
    }
    const auto id = manifest["id"].get<std::string>();
    const auto name = manifest["name"].get<std::string>();
    const auto version = manifest["version"].get<std::string>();
    const auto entry = manifest["entry"].get<std::string>();
    static const std::regex idPattern("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$");
    static const std::regex versionPattern(R"(^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$)");
    const auto author = manifest["author"].get<std::string>();
    const auto description = manifest["description"].get<std::string>();
    if (id.size() > 63 || !std::regex_match(id, idPattern) || !SafePath(id) || name.empty() || CharacterCount(name) > 100 ||
        author.empty() || CharacterCount(author) > 200 || CharacterCount(description) > 1000 || !std::regex_match(version, versionPattern) ||
        manifest["apiVersion"] != "1" || !SafePath(entry) || !entry.ends_with(".html") || !assets.contains(entry) ||
        !manifest.contains("capabilities") || !manifest["capabilities"].is_array() ||
        !manifest.contains("permissions") || !manifest["permissions"].is_array() || !manifest["permissions"].empty()) reject();
    std::set<std::string> capabilities;
    const std::set<std::string> allowed = {"cpu", "gpu", "memory", "disk", "network", "clock"};
    for (const auto& value : manifest["capabilities"]) {
        if (!value.is_string()) reject();
        const auto capability = value.get<std::string>();
        if (!allowed.contains(capability) || !capabilities.insert(capability).second) reject();
    }
    return {id, name, version, entry, source};
}
}

ThemeManager::ThemeManager(fs::path root) : root_(std::move(root)) {
    if (root_.empty()) throw std::runtime_error("未設定主題安裝目錄。");
}

ThemeInfo ThemeManager::ValidateDirectory(const fs::path& source) { return ReadDirectory(source); }

ThemeInfo ThemeManager::Install(const fs::path& source) {
    const bool package = fs::is_regular_file(source);
    if (package && source.extension() != ".dmt") throw std::runtime_error("主題壓縮檔必須使用 .dmt 副檔名。");
    if (!package) ReadDirectory(source);
    const auto sourcePath = fs::weakly_canonical(source).wstring();
    auto rootPath = fs::weakly_canonical(root_).wstring();
    std::replace(rootPath.begin(), rootPath.end(), L'/', L'\\');
    const bool same = CompareStringOrdinal(sourcePath.c_str(), static_cast<int>(sourcePath.size()),
        rootPath.c_str(), static_cast<int>(rootPath.size()), TRUE) == CSTR_EQUAL;
    const bool inside = rootPath.size() > sourcePath.size() && rootPath[sourcePath.size()] == L'\\' &&
        CompareStringOrdinal(sourcePath.c_str(), static_cast<int>(sourcePath.size()),
            rootPath.c_str(), static_cast<int>(sourcePath.size()), TRUE) == CSTR_EQUAL;
    if (same || inside) throw std::runtime_error("主題安裝目錄不可位於來源目錄內。");
    auto ancestor = fs::absolute(root_).lexically_normal();
    while (!ancestor.empty()) {
        const auto attributes = GetFileAttributesW(ancestor.c_str());
        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
            throw std::runtime_error("主題安裝目錄不得經過重新解析點。");
        const auto parent = ancestor.parent_path();
        if (parent == ancestor) break;
        ancestor = parent;
    }
    fs::create_directories(root_);
    const auto staging = root_ / (".staging-" + std::to_string(std::random_device{}()) + "-" + std::to_string(std::random_device{}()));
    if (!fs::create_directory(staging)) throw std::runtime_error("無法建立主題暫存目錄。");
    try {
        if (package) ExtractPackage(source, staging);
        else fs::copy(source, staging, fs::copy_options::recursive);
        const auto stagedInfo = ReadDirectory(staging);
        const auto finalPath = root_ / (stagedInfo.id + "@" + stagedInfo.version);
        if (fs::exists(finalPath)) throw std::runtime_error("此主題版本已安裝。");
        fs::rename(staging, finalPath);
        auto installed = stagedInfo;
        installed.directory = finalPath;
        return installed;
    } catch (...) {
        std::error_code ignored;
        fs::remove_all(staging, ignored);
        throw;
    }
}

std::vector<ThemeInfo> ThemeManager::List() const {
    std::vector<ThemeInfo> result;
    if (!fs::exists(root_)) return result;
    for (const auto& item : fs::directory_iterator(root_)) {
        if (item.path().filename().wstring().starts_with(L".staging-")) continue;
        try {
            auto info = ReadDirectory(item.path());
            if (item.path().filename().string() == info.id + "@" + info.version) result.push_back(std::move(info));
        } catch (const std::exception&) { }
    }
    return result;
}
} // namespace desktopmonitor::themes
