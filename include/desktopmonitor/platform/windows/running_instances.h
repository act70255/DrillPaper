#pragma once

#include <windows.h>
#include <chrono>
#include <cstddef>
#include <string>

namespace desktopmonitor::platform::windows {

/** 要求其他執行中實例正式結束的結果。 */
struct InstanceExitResult {
    /** 找到、且已送出正式結束命令的實例數。 */
    std::size_t requested = 0;
    /** 等待期限到時仍未結束的實例數。 */
    std::size_t remaining = 0;
};

/** 要求與指定執行檔同一路徑的其他 DrillPaper 實例正式結束，並等待它們退出。
 *
 * 只處理擁有管理視窗（`DrillPaperManagementWindow`）且映像路徑與 `executablePath` 相同的程序，
 * 對其送出與「結束 DrillPaper」按鈕相同的命令；其他路徑的實例（例如另一份解壓副本）不受影響。
 * 供安裝程式在覆蓋安裝或解除安裝前呼叫，避免強制終止。
 *
 * Args:
 *     executablePath: 要關閉之實例的完整 EXE 路徑。
 *     selfProcessId: 呼叫端自己的程序 ID，永遠不會被要求結束。
 *     timeout: 等待所有實例退出的上限。
 *
 * Returns:
 *     送出命令與逾時仍存活的實例數。
 */
InstanceExitResult RequestExitOfInstances(const std::wstring& executablePath, DWORD selfProcessId,
                                          std::chrono::milliseconds timeout);

}  // namespace desktopmonitor::platform::windows
