#include <catch2/catch_test_macros.hpp>
#include "desktopmonitor/platform/windows/management_shell.h"
#include "desktopmonitor/platform/windows/running_instances.h"
#include <filesystem>
#include <string>

namespace {

namespace fs = std::filesystem;
namespace win = desktopmonitor::platform::windows;
using namespace std::chrono_literals;

/** 測試用的替身程序：複製到指定路徑後啟動，需要時等待其管理視窗出現。 */
class FixtureProcess {
public:
    /** 啟動替身。
     * Args:
     *     source: 建置出的替身 EXE。
     *     target: 複製後的執行路徑（用來模擬不同安裝位置）。
     *     arguments: 額外命令列參數。
     *     expectWindow: 是否等待管理視窗出現（--no-window 模式為 false）。
     */
    FixtureProcess(const fs::path& source, const fs::path& target, const std::wstring& arguments, bool expectWindow = true)
        : path_(target) {
        fs::create_directories(target.parent_path());
        fs::copy_file(source, target, fs::copy_options::overwrite_existing);
        std::wstring line = L"\"" + target.wstring() + L"\" " + arguments;
        STARTUPINFOW startup{sizeof(startup)};
        REQUIRE(CreateProcessW(target.c_str(), line.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup, &info_));
        CloseHandle(info_.hThread);
        if (!expectWindow) { Sleep(200); return; }
        WaitForInputIdle(info_.hProcess, 5000);
        for (int attempt = 0; attempt < 100 && !HasWindow(); ++attempt) Sleep(50);
        REQUIRE(HasWindow());
    }
    FixtureProcess(const FixtureProcess&) = delete;
    FixtureProcess& operator=(const FixtureProcess&) = delete;
    ~FixtureProcess() {
        if (WaitForSingleObject(info_.hProcess, 0) == WAIT_TIMEOUT) {
            TerminateProcess(info_.hProcess, 9);
            WaitForSingleObject(info_.hProcess, 5000);
        }
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
            if (pid == state->pid && std::wstring(name) == win::kManagementWindowClass) { state->found = true; return FALSE; }
            return TRUE;
        }, reinterpret_cast<LPARAM>(&search));
        return search.found;
    }
    fs::path path_;
    PROCESS_INFORMATION info_{};
};

/** 測試結束時刪除的工作目錄，建在測試 EXE 旁的建置目錄，不使用 %TEMP%。 */
class Workspace {
public:
    Workspace() {
        wchar_t self[MAX_PATH]{};
        GetModuleFileNameW(nullptr, self, MAX_PATH);
        root_ = fs::path(self).parent_path() / (L"running-instances-test-" + std::to_wstring(GetCurrentProcessId()));
        fs::create_directories(root_);
    }
    Workspace(const Workspace&) = delete;
    Workspace& operator=(const Workspace&) = delete;
    ~Workspace() { std::error_code ignored; fs::remove_all(root_, ignored); }
    /** Returns: 工作目錄下的子路徑。 */
    fs::path operator/(const std::wstring& child) const { return root_ / child; }

private:
    fs::path root_;
};

/** Returns: 與測試 EXE 同目錄的替身 EXE。 */
fs::path FixtureSource() {
    wchar_t self[MAX_PATH]{};
    GetModuleFileNameW(nullptr, self, MAX_PATH);
    return fs::path(self).parent_path() / L"DrillPaperExitInstanceFixture.exe";
}

}  // namespace

TEST_CASE("Exit request closes running instances of the same executable through the formal exit command", "[integration][instances]") {
    const Workspace workspace;
    {
        FixtureProcess installed(FixtureSource(), workspace / L"安裝 路徑" / L"DrillPaper.exe", L"");
        FixtureProcess other(FixtureSource(), workspace / L"另一份 解壓" / L"DrillPaper.exe", L"");

        const auto result = win::RequestExitOfInstances(installed.Path().wstring(), GetCurrentProcessId(), 5000ms);

        REQUIRE(result.requested == 1);
        REQUIRE(result.remaining == 0);
        REQUIRE(result.unreachable == 0);
        REQUIRE(result.AllExited());
        REQUIRE(installed.Exited(1000));
        REQUIRE(installed.ExitCode() == 0);
        REQUIRE_FALSE(other.Exited());
    }
}

TEST_CASE("Exit request reports instances that do not exit before the timeout", "[integration][instances]") {
    const Workspace workspace;
    {
        FixtureProcess stubborn(FixtureSource(), workspace / L"不回應" / L"DrillPaper.exe", L"--ignore-exit");

        const auto result = win::RequestExitOfInstances(stubborn.Path().wstring(), GetCurrentProcessId(), 500ms);

        REQUIRE(result.requested == 1);
        REQUIRE(result.remaining == 1);
        REQUIRE_FALSE(result.AllExited());
        REQUIRE_FALSE(stubborn.Exited());
    }
}

TEST_CASE("Exit request reports same-path instances without a management window instead of claiming success", "[integration][instances]") {
    const Workspace workspace;
    {
        FixtureProcess preview(FixtureSource(), workspace / L"預覽 模式" / L"DrillPaper.exe", L"--no-window", false);

        const auto result = win::RequestExitOfInstances(preview.Path().wstring(), GetCurrentProcessId(), 500ms);

        REQUIRE(result.requested == 0);
        REQUIRE(result.unreachable == 1);
        REQUIRE_FALSE(result.AllExited());
        REQUIRE_FALSE(preview.Exited());
    }
}

TEST_CASE("Exit request with no running instance returns immediately", "[integration][instances]") {
    const Workspace workspace;
    const auto result = win::RequestExitOfInstances((workspace / L"沒有執行" / L"DrillPaper.exe").wstring(), GetCurrentProcessId(), 5000ms);
    REQUIRE(result.requested == 0);
    REQUIRE(result.AllExited());
}

TEST_CASE("Current executable path is the full path of this test binary", "[integration][instances]") {
    const auto path = win::CurrentExecutablePath();
    REQUIRE_FALSE(path.empty());
    REQUIRE(fs::path(path).filename() == L"DrillPaperRunningInstancesIntegrationTests.exe");
}
