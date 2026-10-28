#pragma once
#include <optional>
#include <filesystem>

namespace desktopmonitor::app {
/** 處理獨立的原生主題管理 CLI。
 * Returns:
 *     未選擇主題 CLI 時為空；其餘回傳程序退出碼。
 */
std::optional<int> RunThemeCommand();
/** 取得必要設定指定的使用者主題目錄。
 * Returns:
 *     LOCALAPPDATA 下的 DrillPaper/themes。
 * Throws:
 *     std::runtime_error: 必要設定缺失或無法讀取。
 */
std::filesystem::path ThemeStoreDirectory();
}
