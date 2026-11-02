#include <catch2/catch_test_macros.hpp>
#include <filesystem>
#include <fstream>
#include <chrono>
#include <utility>
#include <vector>
#include <miniz.h>
#include "desktopmonitor/themes/theme_manager.h"
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <winioctl.h>
#include <cstring>

namespace {
struct JunctionFixture {
    std::filesystem::path link;
    /** 建立本測試專屬的 NTFS junction，不需要符號連結權限。
     * Args:
     *     path: 尚不存在的連結目錄。
     *     destination: 本測試擁有的外部目錄。
     */
    JunctionFixture(std::filesystem::path path, const std::filesystem::path& destination) : link(std::move(path)) {
        std::filesystem::create_directories(link);
        HANDLE handle = CreateFileW(link.c_str(), GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
            FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_BACKUP_SEMANTICS, nullptr);
        if (handle == INVALID_HANDLE_VALUE) throw std::runtime_error("無法開啟測試 junction。");
        struct MountPoint {
            DWORD tag;
            WORD length, reserved, substituteOffset, substituteLength, printOffset, printLength;
            wchar_t paths[4096];
        } data{};
        const auto print = std::filesystem::absolute(destination).wstring();
        const auto substitute = L"\\??\\" + print;
        if (substitute.size() + print.size() + 2 > std::size(data.paths)) {
            CloseHandle(handle);
            throw std::runtime_error("測試 junction 路徑太長。");
        }
        data.tag = IO_REPARSE_TAG_MOUNT_POINT;
        data.substituteLength = static_cast<WORD>(substitute.size() * sizeof(wchar_t));
        data.printOffset = data.substituteLength + sizeof(wchar_t);
        data.printLength = static_cast<WORD>(print.size() * sizeof(wchar_t));
        data.length = static_cast<WORD>(8 + data.printOffset + data.printLength + sizeof(wchar_t));
        std::memcpy(data.paths, substitute.c_str(), data.substituteLength + sizeof(wchar_t));
        std::memcpy(reinterpret_cast<BYTE*>(data.paths) + data.printOffset, print.c_str(), data.printLength + sizeof(wchar_t));
        DWORD returned = 0;
        const bool created = DeviceIoControl(handle, FSCTL_SET_REPARSE_POINT, &data, data.length + 8, nullptr, 0, &returned, nullptr) != FALSE;
        CloseHandle(handle);
        if (!created) throw std::runtime_error("無法建立真正的測試 junction。");
    }
    /** 只移除 junction 本身，保留目標內容，避免測試清理穿越。 */
    ~JunctionFixture() { RemoveDirectoryW(link.c_str()); }
};
struct ThemeFixture {
    std::filesystem::path root = std::filesystem::temp_directory_path() /
        ("DrillPaperThemeTest-" + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
    /** 建立獨立、有效的主題測試來源。 */
    ThemeFixture() {
        std::filesystem::create_directories(root / "source");
        std::ofstream(root / "source/index.html") << "<!doctype html><title>測試</title>";
        std::ofstream(root / "source/theme.json") << R"({"id":"test-theme","name":"測試主題","version":"1.0.0","apiVersion":"1","entry":"index.html","author":"測試","description":"","capabilities":["cpu"],"permissions":[]})";
    }
    /** 移除由本 fixture 建立的隔離目錄。 */
    ~ThemeFixture() { std::error_code error; std::filesystem::remove_all(root, error); }
    /** 以公開 ZIP 寫入 API 建立壓縮測試包。
     * Args:
     *     extras: 額外原始 ZIP 名稱與資料，可用於負面案例。
     * Returns:
     *     包含 fixture 來源檔案的 .dmt 路徑。
     */
    std::filesystem::path Package(const std::vector<std::pair<std::string, std::string>>& extras = {}) const {
        mz_zip_archive archive{};
        if (!mz_zip_writer_init_heap(&archive, 0, 0)) throw std::runtime_error("無法建立測試 ZIP。");
        for (const auto& file : std::filesystem::recursive_directory_iterator(root / "source")) {
            if (!file.is_regular_file()) continue;
            std::ifstream input(file.path(), std::ios::binary);
            const std::string bytes((std::istreambuf_iterator<char>(input)), {});
            const auto name = file.path().lexically_relative(root / "source").generic_string();
            if (!mz_zip_writer_add_mem(&archive, name.c_str(), bytes.data(), bytes.size(), MZ_BEST_COMPRESSION)) {
                mz_zip_writer_end(&archive);
                throw std::runtime_error("無法寫入測試 ZIP。");
            }
        }
        for (const auto& [name, data] : extras) {
            if (!mz_zip_writer_add_mem(&archive, name.c_str(), data.data(), data.size(), MZ_BEST_COMPRESSION)) {
                mz_zip_writer_end(&archive);
                throw std::runtime_error("無法寫入負面測試 ZIP。");
            }
        }
        void* bytes = nullptr;
        size_t size = 0;
        const bool ready = mz_zip_writer_finalize_heap_archive(&archive, &bytes, &size) != 0;
        mz_zip_writer_end(&archive);
        if (!ready) throw std::runtime_error("無法完成測試 ZIP。");
        const auto path = root / "theme.dmt";
        std::ofstream(path, std::ios::binary).write(static_cast<const char*>(bytes), static_cast<std::streamsize>(size));
        mz_free(bytes);
        return path;
    }
};
}

TEST_CASE("DMT import validates and installs compressed theme assets", "[themes][zip]") {
    ThemeFixture fixture;
    desktopmonitor::themes::ThemeManager manager(fixture.root / L"已安裝主題");
    const auto package = fixture.root / L"測試主題.dmt";
    std::filesystem::rename(fixture.Package(), package);
    const auto installed = manager.Install(package);
    REQUIRE(installed.id == "test-theme");
    REQUIRE(std::filesystem::is_regular_file(installed.directory / "index.html"));
    REQUIRE(manager.List().size() == 1);
}

TEST_CASE("Only the selected installed theme version can be removed", "[themes][remove]") {
    ThemeFixture fixture;
    desktopmonitor::themes::ThemeManager manager(fixture.root / "installed");
    const auto installed = manager.Install(fixture.Package());
    manager.Remove(installed.id, installed.version);
    REQUIRE(manager.List().empty());
    REQUIRE(std::filesystem::exists(fixture.root / "source/index.html"));
    REQUIRE_THROWS(manager.Remove("../source", "1.0.0"));
    REQUIRE_THROWS(manager.Remove("minimal", "1.0.0"));
    const auto reinstalled = manager.Install(fixture.root / "theme.dmt");
    REQUIRE(reinstalled.id == installed.id);
    REQUIRE(reinstalled.version == installed.version);
    REQUIRE(manager.List().size() == 1);
}

TEST_CASE("Removal rejects real junctions and preserves their external targets", "[themes][remove][junction]") {
    ThemeFixture fixture;
    const auto outside = fixture.root / "outside";
    const auto externalTheme = outside / "test-theme@1.0.0";
    std::filesystem::create_directories(outside);
    std::filesystem::copy(fixture.root / "source", externalTheme, std::filesystem::copy_options::recursive);
    std::ofstream(outside / "keep.js") << "外部資料必須保留";
    desktopmonitor::themes::ThemeManager manager(fixture.root / "installed");
    auto link = fixture.root / "installed";
    auto destination = outside;
    SECTION("installation root junction") {}
    SECTION("selected version junction") {
        std::filesystem::create_directory(link);
        link /= "test-theme@1.0.0";
        destination = externalTheme;
    }
    SECTION("nested asset junction") {
        const auto installed = manager.Install(fixture.Package());
        link = installed.directory / "assets";
    }
    JunctionFixture junction(link, destination);
    REQUIRE((GetFileAttributesW(link.c_str()) & FILE_ATTRIBUTE_REPARSE_POINT) != 0);
    REQUIRE_THROWS(manager.Remove("test-theme", "1.0.0"));
    REQUIRE(std::filesystem::is_regular_file(externalTheme / "index.html"));
    REQUIRE(std::filesystem::is_regular_file(outside / "keep.js"));
}

TEST_CASE("DMT rejection preserves the installation boundary", "[themes][zip][security]") {
    ThemeFixture fixture;
    std::vector<std::pair<std::string, std::string>> extras;
    bool symbolicLink = false;
    bool corruptArchive = false;
    bool absolutePath = false;
    bool crcMismatch = false;
    SECTION("parent traversal") { extras.emplace_back("../escape.js", "bad"); }
    SECTION("absolute path") { extras.emplace_back("Xescape.js", "bad"); absolutePath = true; }
    SECTION("alternate stream") { extras.emplace_back("index.html:extra.js", "bad"); }
    SECTION("case collision") { extras.emplace_back("INDEX.HTML", "bad"); }
    SECTION("forbidden executable") { extras.emplace_back("payload.exe", "bad"); }
    SECTION("TypeScript source") { extras.emplace_back("main.ts", "export {}"); }
    SECTION("TypeScript declaration") { extras.emplace_back("desktop-monitor-sdk.d.ts", "export {}"); }
    SECTION("single file quota") { extras.emplace_back("large.js", std::string(10 * 1024 * 1024 + 1, 'x')); }
    SECTION("file count quota") {
        for (int index = 0; index < 255; ++index) extras.emplace_back("file" + std::to_string(index) + ".js", "x");
    }
    SECTION("total extraction quota") {
        for (int index = 0; index < 6; ++index) extras.emplace_back("large" + std::to_string(index) + ".js", std::string(9 * 1024 * 1024, 'x'));
    }
    SECTION("symlink attributes") { symbolicLink = true; }
    SECTION("truncated archive") { corruptArchive = true; }
    SECTION("CRC mismatch") { crcMismatch = true; }
    SECTION("unsupported manifest API") {
        std::ifstream input(fixture.root / "source/theme.json");
        std::string manifest((std::istreambuf_iterator<char>(input)), {});
        input.close();
        const auto position = manifest.find("\"apiVersion\":\"1\"");
        REQUIRE(position != std::string::npos);
        manifest.replace(position, std::string("\"apiVersion\":\"1\"").size(), "\"apiVersion\":\"99\"");
        std::ofstream(fixture.root / "source/theme.json") << manifest;
    }
    const auto package = fixture.Package(extras);
    if (absolutePath) {
        // miniz writer 本身拒絕絕對路徑；在相同長度的 header 名稱上改寫，測試 reader 邊界。
        std::ifstream input(package, std::ios::binary);
        std::string data((std::istreambuf_iterator<char>(input)), {});
        input.close();
        std::size_t offset = 0;
        unsigned replacements = 0;
        while ((offset = data.find("Xescape.js", offset)) != std::string::npos) {
            data[offset++] = '/';
            ++replacements;
        }
        REQUIRE(replacements == 2);
        std::ofstream(package, std::ios::binary).write(data.data(), static_cast<std::streamsize>(data.size()));
    }
    if (symbolicLink || crcMismatch) {
        std::ifstream input(package, std::ios::binary);
        std::string data((std::istreambuf_iterator<char>(input)), {});
        input.close();
        const auto central = data.find(std::string("PK\x01\x02", 4));
        REQUIRE(central != std::string::npos);
        // ZIP central directory 的 external attributes 高 16 位指定 Unix symlink。
        if (symbolicLink) {
            const unsigned attributes = 0xa1ff0000U;
            for (unsigned byte = 0; byte < 4; ++byte) data[central + 38 + byte] = static_cast<char>((attributes >> (byte * 8)) & 0xff);
        }
        if (crcMismatch) data[central + 16] ^= 1;
        std::ofstream(package, std::ios::binary).write(data.data(), static_cast<std::streamsize>(data.size()));
    }
    if (corruptArchive) std::filesystem::resize_file(package, 15);
    desktopmonitor::themes::ThemeManager manager(fixture.root / "installed");
    REQUIRE_THROWS(manager.Install(package));
    REQUIRE(manager.List().empty());
    REQUIRE_FALSE(std::filesystem::exists(fixture.root / "escape.js"));
    if (std::filesystem::exists(fixture.root / "installed")) {
        REQUIRE(std::filesystem::is_empty(fixture.root / "installed"));
    }
}

TEST_CASE("原生主題安裝後可列舉並讀取入口", "[themes]") {
    ThemeFixture fixture;
    desktopmonitor::themes::ThemeManager manager(fixture.root / "installed");
    const auto installed = manager.Install(fixture.root / "source");
    REQUIRE(installed.id == "test-theme");
    REQUIRE(installed.name == "測試主題");
    REQUIRE(std::filesystem::is_regular_file(installed.directory / installed.entry));
    REQUIRE(manager.List().size() == 1);
}

TEST_CASE("主題不能安裝到自己的子目錄", "[themes]") {
    ThemeFixture fixture;
    desktopmonitor::themes::ThemeManager manager(fixture.root / "source/installed");
    REQUIRE_THROWS(manager.Install(fixture.root / "source"));
    REQUIRE_FALSE(std::filesystem::exists(fixture.root / "source/installed"));
}

TEST_CASE("Theme names longer than the manifest limit are rejected", "[themes][acceptance]") {
    ThemeFixture fixture;
    std::ifstream input(fixture.root / "source/theme.json");
    std::string manifest((std::istreambuf_iterator<char>(input)), {});
    input.close();
    const auto nameStart = manifest.find("測試主題");
    REQUIRE(nameStart != std::string::npos);
    manifest.replace(nameStart, std::string("測試主題").size(), std::string(101, 'a'));
    std::ofstream(fixture.root / "source/theme.json") << manifest;
    REQUIRE_THROWS(desktopmonitor::themes::ThemeManager::ValidateDirectory(fixture.root / "source"));
}

TEST_CASE("Unicode theme names use characters rather than UTF-8 bytes", "[themes][acceptance]") {
    ThemeFixture fixture;
    std::ifstream input(fixture.root / "source/theme.json");
    std::string manifest((std::istreambuf_iterator<char>(input)), {});
    input.close();
    std::string name;
    for (int index = 0; index < 100; ++index) name += "題";
    const auto nameStart = manifest.find("測試主題");
    REQUIRE(nameStart != std::string::npos);
    manifest.replace(nameStart, std::string("測試主題").size(), name);
    std::ofstream(fixture.root / "source/theme.json") << manifest;
    REQUIRE(desktopmonitor::themes::ThemeManager::ValidateDirectory(fixture.root / "source").name == name);
}

TEST_CASE("Forbidden assets cannot leave an installed theme", "[themes][acceptance]") {
    ThemeFixture fixture;
    std::ofstream(fixture.root / "source/payload.exe") << "forbidden";
    desktopmonitor::themes::ThemeManager manager(fixture.root / "installed");
    REQUIRE_THROWS(manager.Install(fixture.root / "source"));
    REQUIRE(manager.List().empty());
    REQUIRE_FALSE(std::filesystem::exists(fixture.root / "installed"));
}

TEST_CASE("Installing the same theme version preserves the original assets", "[themes][acceptance]") {
    ThemeFixture fixture;
    desktopmonitor::themes::ThemeManager manager(fixture.root / "installed");
    const auto installed = manager.Install(fixture.root / "source");
    std::ifstream beforeInput(installed.directory / installed.entry);
    const std::string before((std::istreambuf_iterator<char>(beforeInput)), {});
    beforeInput.close();
    std::ofstream(fixture.root / "source/index.html") << "replacement";
    REQUIRE_THROWS(manager.Install(fixture.root / "source"));
    std::ifstream afterInput(installed.directory / installed.entry);
    const std::string after((std::istreambuf_iterator<char>(afterInput)), {});
    REQUIRE(after == before);
    REQUIRE(manager.List().size() == 1);
}
