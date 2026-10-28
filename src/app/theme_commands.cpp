#include "desktopmonitor/app/theme_commands.h"
#include "desktopmonitor/themes/theme_manager.h"
#include <windows.h>
#include <shellapi.h>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace desktopmonitor::app {
namespace {
/** 將 UTF-8 命令輸出寫至主控台或重新導向的管道。
 * Args:
 *     text: UTF-8 訊息。
 *     error: 是否使用錯誤輸出。
 */
void WriteOutput(const std::string& text, bool error = false) {
    HANDLE output = GetStdHandle(error ? STD_ERROR_HANDLE : STD_OUTPUT_HANDLE);
    const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
    std::wstring wide;
    if (length > 0) {
        wide.resize(length);
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), wide.data(), length);
    }
    if (output == nullptr || output == INVALID_HANDLE_VALUE) {
        AttachConsole(ATTACH_PARENT_PROCESS);
        output = GetStdHandle(error ? STD_ERROR_HANDLE : STD_OUTPUT_HANDLE);
    }
    DWORD mode = 0;
    DWORD written = 0;
    if (output != nullptr && output != INVALID_HANDLE_VALUE) {
        if (GetConsoleMode(output, &mode)) WriteConsoleW(output, wide.data(), static_cast<DWORD>(wide.size()), &written, nullptr);
        else WriteFile(output, text.data(), static_cast<DWORD>(text.size()), &written, nullptr);
    }
    if (error && !wide.empty()) OutputDebugStringW(wide.c_str());
}
}

std::filesystem::path ThemeStoreDirectory() {
    const DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", nullptr, 0);
    if (length < 2) throw std::runtime_error("缺少必要設定 LOCALAPPDATA，無法決定主題資料目錄。");
    std::wstring root(length, L'\0');
    const DWORD copied = GetEnvironmentVariableW(L"LOCALAPPDATA", root.data(), length);
    if (copied == 0 || copied >= length) throw std::runtime_error("無法讀取 LOCALAPPDATA。");
    root.resize(copied);
    const auto store = std::filesystem::path(root) / L"DrillPaper/themes";
    auto ancestor = std::filesystem::absolute(store).lexically_normal();
    while (!ancestor.empty()) {
        const auto attributes = GetFileAttributesW(ancestor.c_str());
        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
            throw std::runtime_error("主題資料目錄不得經過重新解析點，未寫入安裝或日誌資料。");
        const auto parent = ancestor.parent_path();
        if (parent == ancestor) break;
        ancestor = parent;
    }
    return store;
}

std::optional<int> RunThemeCommand() {
    int count = 0;
    LPWSTR* raw = CommandLineToArgvW(GetCommandLineW(), &count);
    if (raw == nullptr) return std::nullopt;
    std::vector<std::wstring> arguments;
    for (int index = 0; index < count; ++index) arguments.emplace_back(raw[index]);
    LocalFree(raw);
    const bool importing = std::find(arguments.begin(), arguments.end(), L"--import-theme") != arguments.end();
    const bool listing = std::find(arguments.begin(), arguments.end(), L"--list-themes") != arguments.end();
    if (!importing && !listing) return std::nullopt;
    std::filesystem::path dataRoot;
    try {
        if ((importing && listing) || (importing && (arguments.size() != 3 || arguments[1] != L"--import-theme")) ||
            (listing && (arguments.size() != 2 || arguments[1] != L"--list-themes")))
            throw std::runtime_error("用法：DrillPaper.exe --import-theme <路徑> 或 --list-themes。");
        const auto store = ThemeStoreDirectory();
        dataRoot = store.parent_path();
        themes::ThemeManager manager(store);
        if (importing) {
            const auto info = manager.Install(std::filesystem::path(arguments[2]));
            WriteOutput("已安裝主題：" + info.id + "@" + info.version + "\n");
        } else {
            for (const auto& info : manager.List()) WriteOutput(info.id + "@" + info.version + "\n");
        }
        return 0;
    } catch (const std::exception& error) {
        // 日誌失敗不掩蓋原始操作的退出碼；stderr 仍保留錯誤詳情。
        if (!dataRoot.empty()) {
            try {
                std::filesystem::create_directories(dataRoot / L"logs");
                std::ofstream(dataRoot / L"logs/theme-commands.log", std::ios::binary | std::ios::app) << error.what() << '\n';
            } catch (const std::exception&) { }
        }
        const auto* fileError = dynamic_cast<const std::filesystem::filesystem_error*>(&error);
        WriteOutput(fileError != nullptr
            ? "主題檔案操作失敗，請確認路徑與資料目錄權限；詳細內容已記錄。\n"
            : std::string("主題操作失敗：") + error.what() + "\n", true);
        return 1;
    }
}
}
