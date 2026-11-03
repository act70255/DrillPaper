#pragma once

#include <windows.h>
#include <chrono>
#include <cstddef>
#include <string>

namespace desktopmonitor::platform::windows {

/** 要求其他執行中實例正式結束的結果。 */
struct InstanceExitResult {
    /** 找到管理視窗、且已送出正式結束命令的實例數。 */
    std::size_t requested = 0;
    /** 已送出命令但在期限內仍未結束，或命令送不出去的實例數。 */
    std::size_t remaining = 0;
    /** 同路徑但沒有管理視窗（例如以 --preview 啟動）而無法正式結束的實例數。 */
    std::size_t unreachable = 0;

    /** Returns: 是否已沒有任何同路徑實例在執行。 */
    [[nodiscard]] bool AllExited() const { return remaining == 0 && unreachable == 0; }
};

/** 取得目前程序的完整 EXE 路徑。
 *
 * Returns:
 *     完整路徑；查詢失敗時為空字串。
 */
std::wstring CurrentExecutablePath();

/** 要求與指定執行檔同一路徑的其他 DrillPaper 實例正式結束，並等待它們退出。
 *
 * 以程序快照找出映像路徑與 `executablePath` 相同的所有程序（不分大小寫），對擁有管理視窗
 * （`kManagementWindowClass`）者送出與「結束 DrillPaper」按鈕相同的命令；沒有管理視窗者無法正式結束，
 * 計入 `unreachable`，絕不強制終止。其他路徑的實例（例如另一份解壓副本）不受影響。
 * 每個程序只開一次 handle 並持有到等待結束，避免 PID 被重用時誤判。
 *
 * Args:
 *     executablePath: 要關閉之實例的完整 EXE 路徑。
 *     selfProcessId: 呼叫端自己的程序 ID，永遠不會被要求結束。
 *     timeout: 等待已送出命令的實例退出的上限。
 *
 * Returns:
 *     送出命令、逾時或無法結束的實例數。
 */
InstanceExitResult RequestExitOfInstances(const std::wstring& executablePath, DWORD selfProcessId,
                                          std::chrono::milliseconds timeout);

}  // namespace desktopmonitor::platform::windows
