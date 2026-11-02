#include <catch2/catch_test_macros.hpp>
#include "desktopmonitor/platform/windows/running_instances.h"
#include <filesystem>
#include <string>

namespace {

namespace fs = std::filesystem;
using namespace std::chrono_literals;

/** 測試用的替身程序：複製到指定路徑後啟動，並等待其管理視窗出現。 */
class FixtureProcess {
public:
    /** 啟動替身。
     * Args:
     *     source: 建置出的替身 EXE。
     *     target: 複製後的執行路徑（用來模擬不同安裝位置）。
     *     arguments: 額外命令列參數。
     */
    FixtureProcess(const fs::path& source, const fs::path& target, const std::wstring& arguments) : path_(target) {
        fs::create_directories(target.parent_path());
        fs::copy_file(source, target, fs::copy_options::overwrite_existing);
        std::wstring line = L"\"" + target.wstring() + L"\" " + arguments;
        STARTUPINFOW startup{sizeof(startup)};
        REQUIRE(CreateProcessW(target.c_str(), line.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup, &info_));
        CloseHandle(info_.hThread);
        WaitForInputIdle(info_.hProcess, 5000);
        for (int attempt = 0; attempt < 100 && !HasWindow(); ++attempt) Sleep(50);
        REQUIRE(HasWindow());
    }
    FixtureProcess(const FixtureProcess&) = delete;
    FixtureProcess& operator=(const FixtureProcess&) = delete;
    ~FixtureProcess() {
        if (WaitForSingleObject(info_.hProcess, 0) == WAIT_TIMEOUT) TerminateProcess(info_.hProcess, 9);
        CloseHandle(info_.hProcess);
    }
    /** Returns: 替身是否已結束。 */
    bool Exited(DWORD wait = 0) const { return WaitForSingleObject(info_.hProcess, wait) == WAIT_OBJECT_0; }
    /** Returns: 替身的結束碼。 */
    DWORD ExitCode() const { DWORD code = 0; GetExitCodeProcess(info_.hProcess, &code); return code; }
    /** Returns: 替身執行路徑。 */
    const fs::path& Path() const { return path_; }

private:
    bool HasWindow() const {
        struct Search { DWORD pid; bool found; } search{info_.dwProcessId, false};
        EnumWindows([](HWND window, LPARAM data) -> BOOL {
            auto* state = reinterpret_cast<Search*>(data);
            DWORD pid = 0;
            GetWindowThreadProcessId(window, &pid);
            wchar_t name[64]{};
            GetClassNameW(window, name, 64);
            if (pid == state->pid && std::wstring(name) == L"DrillPaperManagementWindow") { state->found = true; return FALSE; }
            return TRUE;
        }, reinterpret_cast<LPARAM>(&search));
        return search.found;
    }
    fs::path path_;
    PROCESS_INFORMATION info_{};
};

/** Returns: 本次測試專用的工作目錄（位於 TEMP；完整測試會把 TEMP 導向非 Temp 目錄）。 */
fs::path Workspace() {
    const auto root = fs::temp_directory_path() / (L"DrillPaperExitTest-" + std::to_wstring(GetCurrentProcessId()));
    fs::create_directories(root);
    return root;
}

/** Returns: 與測試 EXE 同目錄的替身 EXE。 */
fs::path FixtureSource() {
    wchar_t self[MAX_PATH]{};
    GetModuleFileNameW(nullptr, self, MAX_PATH);
    return fs::path(self).parent_path() / L"DrillPaperExitInstanceFixture.exe";
}

}  // namespace

TEST_CASE("Exit request closes running instances of the same executable through the formal exit command", "[integration][instances]") {
    using desktopmonitor::platform::windows::RequestExitOfInstances;
    const auto root = Workspace();
    FixtureProcess installed(FixtureSource(), root / L"安裝 路徑" / L"DrillPaper.exe", L"");
    FixtureProcess other(FixtureSource(), root / L"另一份 解壓" / L"DrillPaper.exe", L"");

    const auto result = RequestExitOfInstances(installed.Path().wstring(), GetCurrentProcessId(), 5000ms);

    REQUIRE(result.requested == 1);
    REQUIRE(result.remaining == 0);
    REQUIRE(installed.Exited(1000));
    REQUIRE(installed.ExitCode() == 0);
    REQUIRE_FALSE(other.Exited());
}

TEST_CASE("Exit request reports instances that do not exit before the timeout", "[integration][instances]") {
    using desktopmonitor::platform::windows::RequestExitOfInstances;
    const auto root = Workspace();
    FixtureProcess stubborn(FixtureSource(), root / L"不回應" / L"DrillPaper.exe", L"--ignore-exit");

    const auto result = RequestExitOfInstances(stubborn.Path().wstring(), GetCurrentProcessId(), 500ms);

    REQUIRE(result.requested == 1);
    REQUIRE(result.remaining == 1);
    REQUIRE_FALSE(stubborn.Exited());
}

TEST_CASE("Exit request with no running instance returns immediately", "[integration][instances]") {
    using desktopmonitor::platform::windows::RequestExitOfInstances;
    const auto result = RequestExitOfInstances((Workspace() / L"沒有執行" / L"DrillPaper.exe").wstring(), GetCurrentProcessId(), 5000ms);
    REQUIRE(result.requested == 0);
    REQUIRE(result.remaining == 0);
}
