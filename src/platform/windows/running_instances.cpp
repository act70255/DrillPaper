#include "desktopmonitor/platform/windows/running_instances.h"

#include "desktopmonitor/platform/windows/management_shell.h"
#include <vector>

namespace desktopmonitor::platform::windows {
namespace {

/** 列舉時收集的目標程序。 */
struct ExitSearch {
    const std::wstring* executablePath;
    DWORD selfProcessId;
    std::vector<DWORD> processIds;
    std::vector<HWND> windows;
};

/** 取得程序的完整映像路徑。
 * Args:
 *     process: 至少具有 PROCESS_QUERY_LIMITED_INFORMATION 權限的程序 handle。
 * Returns:
 *     完整 EXE 路徑；查詢失敗時為空字串。
 */
std::wstring ImagePath(HANDLE process) {
    std::wstring buffer(32768, L'\0');
    DWORD size = static_cast<DWORD>(buffer.size());
    if (!QueryFullProcessImageNameW(process, 0, buffer.data(), &size)) return {};
    buffer.resize(size);
    return buffer;
}

/** 以不分大小寫的序數比較兩個 Windows 路徑。
 * Args:
 *     left: 第一個路徑。
 *     right: 第二個路徑。
 * Returns:
 *     兩者是否指向相同字串路徑。
 */
bool SamePath(const std::wstring& left, const std::wstring& right) {
    return CompareStringOrdinal(left.c_str(), static_cast<int>(left.size()), right.c_str(), static_cast<int>(right.size()), TRUE) == CSTR_EQUAL;
}

/** EnumWindows 回呼：挑出同路徑、非自己的 DrillPaper 管理視窗。
 * Args:
 *     window: 頂層視窗。
 *     data: ExitSearch 指標。
 * Returns:
 *     TRUE 以繼續列舉。
 */
BOOL CALLBACK CollectManagementWindow(HWND window, LPARAM data) {
    auto* search = reinterpret_cast<ExitSearch*>(data);
    wchar_t name[64]{};
    if (GetClassNameW(window, name, 64) == 0 || std::wstring(name) != L"DrillPaperManagementWindow") return TRUE;
    DWORD processId = 0;
    GetWindowThreadProcessId(window, &processId);
    if (processId == 0 || processId == search->selfProcessId) return TRUE;
    const HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
    if (!process) return TRUE;
    const bool match = SamePath(ImagePath(process), *search->executablePath);
    CloseHandle(process);
    if (match) { search->processIds.push_back(processId); search->windows.push_back(window); }
    return TRUE;
}

}  // namespace

InstanceExitResult RequestExitOfInstances(const std::wstring& executablePath, DWORD selfProcessId,
                                          std::chrono::milliseconds timeout) {
    ExitSearch search{&executablePath, selfProcessId, {}, {}};
    EnumWindows(CollectManagementWindow, reinterpret_cast<LPARAM>(&search));
    InstanceExitResult result;
    std::vector<HANDLE> waits;
    for (std::size_t index = 0; index < search.processIds.size(); ++index) {
        // 先取得同步 handle 再送命令，避免程序在兩者之間結束後 PID 被重用。
        const HANDLE process = OpenProcess(SYNCHRONIZE, FALSE, search.processIds[index]);
        if (!process) continue;
        if (PostMessageW(search.windows[index], WM_COMMAND, MAKEWPARAM(kManageExit, BN_CLICKED), 0)) {
            ++result.requested;
            waits.push_back(process);
        } else {
            CloseHandle(process);
        }
    }
    const auto deadline = GetTickCount64() + static_cast<ULONGLONG>(timeout.count());
    for (const HANDLE process : waits) {
        const auto now = GetTickCount64();
        const DWORD left = now >= deadline ? 0 : static_cast<DWORD>(deadline - now);
        if (WaitForSingleObject(process, left) != WAIT_OBJECT_0) ++result.remaining;
        CloseHandle(process);
    }
    return result;
}

}  // namespace desktopmonitor::platform::windows
