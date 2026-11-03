#include "desktopmonitor/platform/windows/running_instances.h"

#include "desktopmonitor/platform/windows/management_shell.h"
#include <tlhelp32.h>
#include <vector>

namespace desktopmonitor::platform::windows {
namespace {

/** Windows 長路徑上限（含結尾 NUL）。 */
constexpr DWORD kLongPathCapacity = 32768;

/** 同路徑的執行中程序；handle 從確認路徑起持有到等待結束，避免 PID 重用。 */
struct Candidate {
    DWORD processId = 0;
    HANDLE process = nullptr;
    HWND managementWindow = nullptr;
};

/** 取得程序的完整映像路徑。
 * Args:
 *     process: 至少具有 PROCESS_QUERY_LIMITED_INFORMATION 權限的程序 handle。
 * Returns:
 *     完整 EXE 路徑；查詢失敗時為空字串。
 */
std::wstring ImagePath(HANDLE process) {
    std::wstring buffer(kLongPathCapacity, L'\0');
    DWORD size = kLongPathCapacity;
    if (!QueryFullProcessImageNameW(process, 0, buffer.data(), &size)) return {};
    buffer.resize(size);
    return buffer;
}

/** 以不分大小寫的序數比較兩個 Windows 路徑。
 * Args:
 *     left: 第一個路徑。
 *     right: 第二個路徑。
 * Returns:
 *     兩者是否為相同字串路徑。
 */
bool SamePath(const std::wstring& left, const std::wstring& right) {
    return !left.empty() &&
           CompareStringOrdinal(left.c_str(), static_cast<int>(left.size()), right.c_str(), static_cast<int>(right.size()), TRUE) == CSTR_EQUAL;
}

/** 以程序快照找出映像路徑相同、且不是自己的程序。
 * Args:
 *     executablePath: 目標 EXE 完整路徑。
 *     selfProcessId: 呼叫端程序 ID。
 * Returns:
 *     持有 handle 的同路徑程序；無法開啟或確認路徑的程序不列入（無法判定是否為目標）。
 */
std::vector<Candidate> FindSamePathProcesses(const std::wstring& executablePath, DWORD selfProcessId) {
    std::vector<Candidate> candidates;
    const HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return candidates;
    PROCESSENTRY32W entry{sizeof(entry)};
    for (BOOL more = Process32FirstW(snapshot, &entry); more; more = Process32NextW(snapshot, &entry)) {
        if (entry.th32ProcessID == 0 || entry.th32ProcessID == selfProcessId) continue;
        const HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | SYNCHRONIZE, FALSE, entry.th32ProcessID);
        if (!process) continue;
        if (SamePath(ImagePath(process), executablePath) && WaitForSingleObject(process, 0) == WAIT_TIMEOUT) {
            candidates.push_back({entry.th32ProcessID, process, nullptr});
        } else {
            CloseHandle(process);
        }
    }
    CloseHandle(snapshot);
    return candidates;
}

/** EnumWindows 回呼：為候選程序配對其管理視窗。
 * Args:
 *     window: 頂層視窗。
 *     data: std::vector<Candidate> 指標。
 * Returns:
 *     TRUE 以繼續列舉。
 */
BOOL CALLBACK MatchManagementWindow(HWND window, LPARAM data) {
    auto* candidates = reinterpret_cast<std::vector<Candidate>*>(data);
    wchar_t name[64]{};
    if (GetClassNameW(window, name, 64) == 0 || std::wstring(name) != kManagementWindowClass) return TRUE;
    DWORD processId = 0;
    GetWindowThreadProcessId(window, &processId);
    for (auto& candidate : *candidates) {
        if (candidate.processId == processId && !candidate.managementWindow) candidate.managementWindow = window;
    }
    return TRUE;
}

}  // namespace

std::wstring CurrentExecutablePath() {
    std::wstring path(kLongPathCapacity, L'\0');
    const DWORD length = GetModuleFileNameW(nullptr, path.data(), kLongPathCapacity);
    if (length == 0 || length >= kLongPathCapacity) return {};
    path.resize(length);
    return path;
}

InstanceExitResult RequestExitOfInstances(const std::wstring& executablePath, DWORD selfProcessId,
                                          std::chrono::milliseconds timeout) {
    auto candidates = FindSamePathProcesses(executablePath, selfProcessId);
    EnumWindows(MatchManagementWindow, reinterpret_cast<LPARAM>(&candidates));
    InstanceExitResult result;
    std::vector<HANDLE> waits;
    for (const auto& candidate : candidates) {
        if (!candidate.managementWindow) {
            ++result.unreachable;
            CloseHandle(candidate.process);
        } else if (PostMessageW(candidate.managementWindow, WM_COMMAND, MAKEWPARAM(kManageExit, BN_CLICKED), 0)) {
            ++result.requested;
            waits.push_back(candidate.process);
        } else {
            // 例如 UIPI 阻擋對較高權限實例送訊息：無法正式結束，不能回報成功。
            ++result.remaining;
            CloseHandle(candidate.process);
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
