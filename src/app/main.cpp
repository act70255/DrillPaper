#include <windows.h>

#include <array>
#include <cstdint>
#include <filesystem>
#include <memory>
#include <string>
#include <fstream>
#include <stdexcept>
#include <algorithm>

#include "desktopmonitor/monitoring/windows_metrics_collector.h"
#include "desktopmonitor/app/theme_commands.h"
#include "desktopmonitor/themes/theme_manager.h"
#include "desktopmonitor/runtime/sampling_worker.h"
#include "desktopmonitor/runtime/desktop_recovery_retry.h"
#include "desktopmonitor/runtime/managed_playback.h"
#include "desktopmonitor/platform/windows/management_shell.h"
#include "desktopmonitor/runtime/windows_snapshot_mailbox.h"
#include "desktopmonitor/platform/windows/power_notifications.h"
#include "desktopmonitor/platform/windows/desktop_host.h"
#include "desktopmonitor/web/webview2_host.h"

namespace {
constexpr wchar_t kWindowClass[] = L"DrillPaperPreviewWindow";
constexpr wchar_t kNotificationClass[] = L"DrillPaperShellNotifications";
constexpr wchar_t kWindowTitle[] = L"DrillPaper Preview";
constexpr wchar_t kExperimentalWindowTitle[] = L"DrillPaper Shell Host POC — Experimental";
constexpr UINT_PTR kMetricsTimer = 1;
constexpr UINT_PTR kDesktopWatchdogTimer = 2;
constexpr UINT kShellRecoveryMessage = WM_APP + 0x39;
constexpr UINT kMinimalThemeCommand = 10001;
constexpr UINT kDashboardThemeCommand = 10002;
constexpr UINT kRefreshThemesCommand = 10003;
constexpr UINT kInstalledThemeCommand = 11000;
HMENU gThemeMenu = nullptr;
std::vector<desktopmonitor::themes::ThemeInfo> gInstalledThemes;
unsigned __int64 gThemeLoadStarted = 0;
bool gThemeFallbackAttempted = false;
constexpr UINT kWebViewFailedMessage = WM_APP + 0x31;
constexpr UINT kSnapshotReadyMessage = WM_APP + 0x34;
constexpr UINT kSamplingFailedMessage = WM_APP + 0x35;
constexpr UINT kRuntimeStateRefreshMessage = WM_APP + 0x36;
constexpr UINT kRendererFailedMessage = WM_APP + 0x38;
constexpr wchar_t kApplicationVersion[] = L"0.1.0-dev";
const wchar_t* gStatusText = L"Starting the local WebView2 preview…";
desktopmonitor::platform::windows::Win32DesktopHost* gDesktopHost = nullptr;
std::unique_ptr<desktopmonitor::runtime::SamplingWorker> gSamplingWorker;
struct UiSnapshot { desktopmonitor::core::MetricsSnapshot snapshot; unsigned long long generation = 0; };
desktopmonitor::runtime::WindowsSnapshotMailbox<UiSnapshot> gSnapshotMailbox;
unsigned long long gSamplingGeneration = 0;
std::unique_ptr<desktopmonitor::platform::windows::PowerNotifications> gPowerNotifications;
desktopmonitor::runtime::PowerStateMachine gPowerState;
desktopmonitor::runtime::PowerState gAppliedPowerState = desktopmonitor::runtime::PowerState::Active;
bool gRuntimePolicyInitialized = false;
bool gSmartSleep = true;
std::unique_ptr<desktopmonitor::web::WebView2Host> gWebViewHost;
desktopmonitor::core::MetricsSnapshot gLatestSnapshot{};
HWND gWallpaperWindow = nullptr;
bool gExperimentalDesktop = false;
bool gMockMetrics = false;
UINT gTaskbarCreatedMessage = 0;
ULONG_PTR gDesktopEpoch = 0;
HWND gNotificationWindow = nullptr;
HWND gLostWallpaperWindow = nullptr;
bool gClosing = false;
bool gDesktopRecoveryInProgress = false;
desktopmonitor::runtime::DesktopRecoveryRetry gDesktopRetry;
desktopmonitor::runtime::ManagedPlayback gPlayback;
std::unique_ptr<desktopmonitor::platform::windows::ManagementShell> gManagement;
bool gManaged = false;
std::wstring gCurrentTheme = L"minimal";
std::string gCurrentThemeKey = "minimal";
desktopmonitor::app::AppSettings gSettings;
std::unique_ptr<desktopmonitor::app::SettingsStore> gSettingsStore;
std::wstring gManagementNotice;
void HandleManagementCommand(UINT command);
void UpdateManagement();
void RefreshThemeMenu();
void ApplySelectedPreferences(const desktopmonitor::app::AppSettings& settings, bool persist);
HWND CreatePreviewWindow(HINSTANCE instance);
LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam);

/** 確認宿主仍由目前 UI 執行緒持有，避免失效 HWND 被其他視窗重用。
 * Args:
 *     window: 記錄中的宿主控制代碼。
 * Returns:
 *     程序、執行緒與視窗類別均符合時為 true。
 */
bool IsOwnedWallpaperWindow(HWND window) {
    DWORD process = 0;
    wchar_t className[256]{};
    return window != nullptr && GetWindowThreadProcessId(window, &process) == GetCurrentThreadId() &&
           process == GetCurrentProcessId() && GetClassNameW(window, className, 256) != 0 &&
           lstrcmpW(className, kWindowClass) == 0;
}

/** 記錄成功的桌面附掛世代，供原生整合診斷辨識重掛。
 * Args:
 *     window: 受本程序管理的桌布視窗。
 */
void RecordDesktopAttachment(HWND window) {
    SetPropW(window, L"DrillPaper.DesktopEpoch", reinterpret_cast<HANDLE>(++gDesktopEpoch));
    RemovePropW(window, L"DrillPaper.DesktopFailure");
}

unsigned __int64 CurrentUnixTimeMilliseconds() {
    constexpr unsigned __int64 kWindowsToUnixEpoch100ns = 116444736000000000ULL;
    FILETIME fileTime{};
    GetSystemTimeAsFileTime(&fileTime);
    ULARGE_INTEGER ticks{};
    ticks.LowPart = fileTime.dwLowDateTime;
    ticks.HighPart = fileTime.dwHighDateTime;
    return ticks.QuadPart < kWindowsToUnixEpoch100ns
        ? 0
        : (ticks.QuadPart - kWindowsToUnixEpoch100ns) / 10000ULL;
}

desktopmonitor::core::MetricsSnapshot MakeMockSnapshot() {
    using desktopmonitor::core::MakeAvailable;
    using desktopmonitor::core::MakeUnavailable;
    using desktopmonitor::core::MetricUnit;
    desktopmonitor::core::MetricsSnapshot snapshot{};
    snapshot.timestampUnixMilliseconds = CurrentUnixTimeMilliseconds();
    snapshot.cpuUsage = MakeAvailable(24.5, MetricUnit::Percent);
    snapshot.gpuUsage = MakeUnavailable(MetricUnit::Percent);
    snapshot.memoryUsedBytes = MakeAvailable(8.0 * 1024.0 * 1024.0 * 1024.0, MetricUnit::Bytes);
    snapshot.memoryTotalBytes = MakeAvailable(16.0 * 1024.0 * 1024.0 * 1024.0, MetricUnit::Bytes);
    snapshot.diskActivityPercent = MakeAvailable(3.0, MetricUnit::Percent);
    snapshot.networkReceiveBytesPerSecond = MakeAvailable(128.0 * 1024.0, MetricUnit::BytesPerSecond);
    snapshot.networkTransmitBytesPerSecond = MakeAvailable(32.0 * 1024.0, MetricUnit::BytesPerSecond);
    return snapshot;
}

bool WriteCommandOutput(const std::wstring& text) {
    bool attachedHere = false;
    if (GetConsoleWindow() == nullptr) {
        attachedHere = AttachConsole(ATTACH_PARENT_PROCESS) != FALSE;
    }
    HANDLE output = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD written = 0;
    if (GetConsoleWindow() != nullptr && output != nullptr && output != INVALID_HANDLE_VALUE &&
        WriteConsoleW(output, text.c_str(), static_cast<DWORD>(text.size()), &written, nullptr)) {
        if (attachedHere) FreeConsole();
        return true;
    }
    if (attachedHere) FreeConsole();
    return false;
}

void RunVersion() {
    const std::wstring text = std::wstring(L"DrillPaper ") + kApplicationVersion + L"\r\n";
    if (!WriteCommandOutput(text)) {
        OutputDebugStringW(text.c_str());
    }
}

void RunDiagnostics() {
    SYSTEM_INFO systemInfo{};
    GetNativeSystemInfo(&systemInfo);
    std::wstring message = L"DrillPaper ";
    message.append(kApplicationVersion);
    message.append(L"\r\nArchitecture: ");
    message.append(systemInfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_AMD64
        ? L"x64" : L"other");
    message.append(L"\r\nWebView2 Runtime: ");
    LPWSTR browserVersion = nullptr;
    if (SUCCEEDED(GetAvailableCoreWebView2BrowserVersionString(nullptr, &browserVersion)) &&
        browserVersion != nullptr) {
        message.append(browserVersion);
        CoTaskMemFree(browserVersion);
    } else {
        message.append(L"not detected");
    }
    if (!WriteCommandOutput(message)) {
        MessageBoxW(nullptr, message.c_str(), L"DrillPaper diagnostics", MB_OK | MB_ICONINFORMATION);
    }
}

void ReportAttachFailure(desktopmonitor::platform::windows::DesktopAttachFailure failure) {
    SetPropW(gWallpaperWindow, L"DrillPaper.DesktopFailure",
             reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(failure)));
    using desktopmonitor::platform::windows::DesktopAttachFailure;
    switch (failure) {
    case DesktopAttachFailure::ProgramManagerNotFound:
        gStatusText = L"Program Manager window not found; showing Preview.";
        break;
    case DesktopAttachFailure::IconHostNotFound:
        gStatusText = L"Desktop icon host not found; showing Preview.";
        break;
    case DesktopAttachFailure::WallpaperLayerNotFound:
        gStatusText = L"No verified WorkerW layer found; showing Preview.";
        break;
    case DesktopAttachFailure::WindowPlacementFailed:
        gStatusText = L"Shell host bounds are unsuitable; showing Preview.";
        break;
    case DesktopAttachFailure::ParentWindowFailed:
        gStatusText = L"Could not attach to the Shell host; showing Preview.";
        break;
    case DesktopAttachFailure::None:
        gStatusText = L"Shell attachment failed; showing Preview.";
        break;
    }
    OutputDebugStringW(gStatusText);
    OutputDebugStringW(L"\n");
}

bool HasFlag(const wchar_t* commandLine, const wchar_t* flag) {
    if (commandLine == nullptr || flag == nullptr) {
        return false;
    }
    for (const wchar_t* current = commandLine; *current != L'\0'; ++current) {
        if (current != commandLine && current[-1] != L' ' && current[-1] != L'\t') {
            continue;
        }
        const wchar_t* text = current;
        const wchar_t* wanted = flag;
        while (*text != L'\0' && *wanted != L'\0' && *text == *wanted) {
            ++text;
            ++wanted;
        }
        if (*wanted == L'\0' && (*text == L'\0' || *text == L' ' || *text == L'\t')) {
            return true;
        }
    }
    return false;
}

/** 將 runtime 政策接到背景採樣與 UI adapter；僅於 UI 執行緒執行。 */
void ApplyRuntimePolicy() {
    const auto state = gPlayback.EffectiveState(gPowerState.State(), gSmartSleep);
    if (gRuntimePolicyInitialized && state == gAppliedPowerState) return;
    const bool reset = !gRuntimePolicyInitialized || gPowerState.RequiresFullSnapshot() ||
        (gAppliedPowerState != desktopmonitor::runtime::PowerState::Active && state == desktopmonitor::runtime::PowerState::Active);
    gRuntimePolicyInitialized = true;
    gAppliedPowerState = state;
    if (gSamplingWorker != nullptr) {
        const auto interval = gPlayback.SamplingInterval(gPowerState.SamplingIntervalMilliseconds(), gSmartSleep);
        gSamplingGeneration = gSamplingWorker->Configure(interval, reset);
    }
    if (gWebViewHost != nullptr && FAILED(gWebViewHost->SetRuntimeState(state)))
        OutputDebugStringW(L"WebView2 電源策略未完整套用，保留降低採樣的退化策略。\n");
}

void RecoverDesktopHost() {
    if (!gExperimentalDesktop || gDesktopHost == nullptr || gClosing || gDesktopRecoveryInProgress ||
        !gDesktopRetry.CanAttempt(GetTickCount64())) {
        return;
    }
    gDesktopRecoveryInProgress = true;
    try {
        if (!IsOwnedWallpaperWindow(gWallpaperWindow)) {
            if (gWebViewHost != nullptr) gWebViewHost->Shutdown();
            if (IsOwnedWallpaperWindow(gLostWallpaperWindow)) DestroyWindow(gLostWallpaperWindow);
            gLostWallpaperWindow = nullptr;
            if (CreatePreviewWindow(GetModuleHandleW(nullptr)) == nullptr)
                throw std::runtime_error("無法重建原生宿主視窗。");
            if (gWebViewHost != nullptr) {
                const HRESULT result = gWebViewHost->RecreateForWindow(gWallpaperWindow);
                if (FAILED(result)) {
                    gWebViewHost->Shutdown();
                    gStatusText = L"主題渲染重建失敗，保留原生預覽。";
                } else {
                    gWebViewHost->SetSnapshot(gLatestSnapshot);
                    gThemeLoadStarted = GetTickCount64();
                }
            }
            SetTimer(gWallpaperWindow, kMetricsTimer, 1000, nullptr);
        }
        desktopmonitor::platform::windows::DesktopAttachFailure failure{};
        if (gDesktopHost->TryAttach(gWallpaperWindow, &failure)) {
            gDesktopRetry.Reset();
            RecordDesktopAttachment(gWallpaperWindow);
            gStatusText = L"桌面宿主已重建並附掛；畫面仍需實機確認。";
            SetWindowTextW(gWallpaperWindow, kExperimentalWindowTitle);
        } else {
            gDesktopHost->RestorePreview(gWallpaperWindow);
            ReportAttachFailure(failure);
            if (gDesktopRetry.RecordFailure(GetTickCount64())) {
                gStatusText = L"桌面尚未就緒，正在等待並重新附掛。";
                SetWindowTextW(gWallpaperWindow, L"DrillPaper — 正在重新連接桌面");
                ShowWindow(gWallpaperWindow, SW_HIDE);
            } else {
                gExperimentalDesktop = false;
                SetWindowTextW(gWallpaperWindow, kWindowTitle);
            }
        }
        if (!gDesktopRetry.Pending() && !gPlayback.Paused()) ShowWindow(gWallpaperWindow, SW_SHOWNOACTIVATE);
        InvalidateRect(gWallpaperWindow, nullptr, TRUE);
    } catch (const std::exception& error) {
        OutputDebugStringA(error.what());
        gExperimentalDesktop = false;
        gClosing = true;
        MessageBoxW(gNotificationWindow, L"無法重建監控視窗，請重新啟動 DrillPaper。", L"DrillPaper", MB_OK | MB_ICONERROR);
        PostQuitMessage(1);
    }
    gDesktopRecoveryInProgress = false;
}

/** 在穩定的 UI 通知端接收最新樣本，即使桌布 HWND 暫時不存在。
 * Returns:
 *     無；有效樣本更新全域快照，視窗存在時才轉交 renderer。
 */
void ConsumeLatestSnapshot() {
    UiSnapshot reading;
    if (gSnapshotMailbox.TryTake(&reading) && reading.generation == gSamplingGeneration) {
        gLatestSnapshot = reading.snapshot;
        if (gWebViewHost != nullptr && IsOwnedWallpaperWindow(gWallpaperWindow)) {
            gWebViewHost->SetSnapshot(gLatestSnapshot);
            if (gPowerState.State() == desktopmonitor::runtime::PowerState::Active) gPowerState.MarkFullSnapshotDelivered();
        }
    }
}

LRESULT CALLBACK NotificationProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    if (message == desktopmonitor::platform::windows::kTrayCallbackMessage && gManagement) {
        gManagement->OnTrayCallback(wParam, lParam);
        return 0;
    }
    if (message == WM_COMMAND && gManaged) { HandleManagementCommand(LOWORD(wParam)); return 0; }
    if (gManagement && message == gTaskbarCreatedMessage && gTaskbarCreatedMessage != 0) gManagement->Tick(true);
    if (message == WM_TIMER && wParam == kDesktopWatchdogTimer) {
        if (gManagement) { UpdateManagement(); gManagement->Tick(); }
    }
    if (message == kSnapshotReadyMessage) { ConsumeLatestSnapshot(); return 0; }
    if (message == kSamplingFailedMessage)
        return WindowProcedure(IsOwnedWallpaperWindow(gWallpaperWindow) ? gWallpaperWindow : window, message, wParam, lParam);
    if ((message == gTaskbarCreatedMessage && gTaskbarCreatedMessage != 0) ||
        message == WM_DISPLAYCHANGE || message == kShellRecoveryMessage ||
        (message == WM_TIMER && wParam == kDesktopWatchdogTimer &&
         (!IsOwnedWallpaperWindow(gWallpaperWindow) || gDesktopRetry.Pending()))) {
        RecoverDesktopHost();
        return 0;
    }
    return DefWindowProcW(window, message, wParam, lParam);
}

/** 以原生功能表切換可信的內建主題。
 * Args:
 *     name: 已固定為 minimal 或 dashboard 的名稱。
 * Returns:
 *     已啟動導覽時為 true。
 */
bool SwitchBuiltinTheme(const std::wstring& name) {
    if (gWebViewHost == nullptr) return false;
    std::array<wchar_t, 32768> executable{};
    const auto length = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
    if (length == 0 || length >= executable.size()) return false;
    const auto directory = std::filesystem::path(executable.data()).parent_path() / L"resources/themes" / name;
    const HRESULT result = gWebViewHost->LoadTheme(directory.wstring(), name);
    if (FAILED(result)) {
        OutputDebugStringW(L"無法切換內建主題；原生預覽視窗仍可關閉。\n");
        return false;
    }
    gThemeLoadStarted = GetTickCount64();
    gCurrentTheme = name;
    gCurrentThemeKey = name == L"dashboard" ? "dashboard" : "minimal";
    UpdateManagement();
    return true;
}

/** 將有效執行狀態同步至可信管理介面。
 * Returns:
 *     無；不改變採樣與 renderer 狀態。
 */
void UpdateManagement() {
    if (!gManagement) return;
    std::wstring status;
    if (gPlayback.Paused()) status = L"已手動暫停；繼續後依目前電源狀態恢復。";
    else if (gDesktopRetry.Pending()) status = L"正在等待桌面就緒並重新連接…";
    else if (gAppliedPowerState != desktopmonitor::runtime::PowerState::Active) status = L"智慧休眠已降低或暫停更新。";
    else if (gWebViewHost && gWebViewHost->IsReady()) status = L"運作中；主題已連線。";
    else status = gStatusText;
    if (!gManagementNotice.empty()) status += L"\r\n" + gManagementNotice;
    gManagement->Update(gCurrentTheme, status, gPlayback.Paused(), gExperimentalDesktop);
}

/** 將已驗證 UTF-8 顯示文字轉為原生文字。
 * Args:
 *     text: UTF-8 字串。
 * Returns:
 *     UTF-16 字串，無效輸入拋錯。
 */
std::wstring NativeText(const std::string& text) {
    const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
    if (length <= 0) throw std::runtime_error("主題顯示文字不是有效的 UTF-8。");
    std::wstring result(length, L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), length);
    return result;
}

/** 解析主題識別，僅接受內建或已驗證安裝版本。
 * Args:
 *     key: 內建名稱或 id@version。
 * Returns:
 *     主題的完整驗證資訊。
 */
desktopmonitor::themes::ThemeInfo ResolveTheme(const std::string& key) {
    if (key == "minimal" || key == "dashboard") {
        std::array<wchar_t, 32768> executable{};
        const auto length = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
        if (length == 0 || length >= executable.size()) throw std::runtime_error("無法尋找內建主題資產。");
        const auto directory = std::filesystem::path(executable.data()).parent_path() / L"resources/themes" / key;
        // 內建資產由建置提供，包含 SDK 型別宣告；第三方匯入仍走完整 package 驗證。
        if (!std::filesystem::is_regular_file(directory / L"index.html"))
            throw std::runtime_error("內建主題缺少必要的 index.html 資產。");
        return {key, key == "minimal" ? "Minimal Monitor" : "Dashboard", "1.0.0", "index.html", directory};
    }
    const auto installed = desktopmonitor::themes::ThemeManager(desktopmonitor::app::ThemeStoreDirectory()).List();
    const auto found = std::find_if(installed.begin(), installed.end(), [&key](const auto& theme) { return theme.id + "@" + theme.version == key; });
    if (found == installed.end()) throw std::runtime_error("所選或已保存的主題版本不存在或損毀，請重新匯入或選擇內建主題。");
    return *found;
}

/** 切換原生宿主模式，失敗由呼叫端顯示錯誤。
 * Args:
 *     desktop: 是否要求桌布模式。
 */
void SetDisplayMode(bool desktop) {
    gDesktopRetry.Reset();
    if (!IsOwnedWallpaperWindow(gWallpaperWindow)) {
        gExperimentalDesktop = true;
        RecoverDesktopHost();
    }
    if (!IsOwnedWallpaperWindow(gWallpaperWindow)) throw std::runtime_error("監控視窗尚未恢復。");
    gExperimentalDesktop = desktop;
    if (desktop) RecoverDesktopHost();
    else {
        gDesktopRetry.Reset();
        gDesktopHost->RestorePreview(gWallpaperWindow);
        SetWindowTextW(gWallpaperWindow, kWindowTitle);
        ShowWindow(gWallpaperWindow, gPlayback.Paused() ? SW_HIDE : SW_SHOWNOACTIVATE);
    }
}

/** 套用主題、電源與模式；有保存要求時完成後才顯示成功。
 * Args:
 *     settings: 有效設定草稿。
 *     persist: 是否明確保存使用者偏好。
 */
void ApplySelectedPreferences(const desktopmonitor::app::AppSettings& settings, bool persist) {
    const auto info = ResolveTheme(settings.theme);
    if (!gWebViewHost) throw std::runtime_error("主題引擎尚未可用，未保存設定。");
    if (FAILED(gWebViewHost->LoadTheme(info.directory.wstring(), NativeText(info.name), std::filesystem::path(info.entry).wstring())))
        throw std::runtime_error("無法開始載入所選主題，未保存設定。");
    gCurrentTheme = NativeText(info.name) + L" · " + NativeText(info.version);
    gCurrentThemeKey = settings.theme;
    gThemeLoadStarted = GetTickCount64();
    gThemeFallbackAttempted = false;
    gSmartSleep = settings.smartSleep;
    gRuntimePolicyInitialized = false;
    ApplyRuntimePolicy();
    SetDisplayMode(settings.desktop);
    if (persist) {
        if (!gSettingsStore) throw std::runtime_error("設定儲存位置尚未初始化。");
        try { gSettingsStore->Save(settings); }
        catch (...) {
            gManagementNotice = L"目前已套用操作，但設定未儲存；重啟後仍使用上次偏好。";
            throw;
        }
        gSettings = settings;
        gManagementNotice = L"設定已儲存；主題畫面仍須等待載入完成。";
        gManagement->SetPreferences(gSettings);
    } else gManagementNotice = L"暫時預覽，尚未儲存設定。";
}

/** 處理可信原生管理命令，錯誤留在 UI 邊界。
 * Args:
 *     command: 系統匣或管理視窗送出的命令。
 */
void HandleManagementCommand(UINT command) {
    using namespace desktopmonitor::platform::windows;
    gManagementNotice.clear();
    try {
        if (command == kManageOpen) { if (gManagement) gManagement->Show(); }
        else if (command == kManageApply) ApplySelectedPreferences(gManagement->Preferences(), true);
        else if (command == kManageCancel) {
            gManagement->SetPreferences(gSettings);
            gManagementNotice = L"已取消尚未套用的設定變更。";
        } else if (command == kManageThemeApply || command == kManageThemePreview) {
            auto draft = gManagement->Preferences();
            draft.desktop = command == kManageThemeApply;
            ApplySelectedPreferences(draft, command == kManageThemeApply);
        } else if (command == kManageRefresh) RefreshThemeMenu();
        else if (command == kManageImport) {
            const auto package = gManagement->PickPackage();
            if (!package.empty()) {
                desktopmonitor::themes::ThemeManager(desktopmonitor::app::ThemeStoreDirectory()).Install(package);
                RefreshThemeMenu();
                gManagementNotice = L"主題已匯入，請從清單預覽或套用。";
            }
        } else if (command == kManageRemove) {
            const auto key = gManagement->Preferences().theme;
            if (key == "minimal" || key == "dashboard") throw std::runtime_error("內建主題不可移除。");
            const auto info = ResolveTheme(key);
            if (gManagement->ConfirmRemoval()) {
                if (key == gCurrentThemeKey || key == gSettings.theme) {
                    auto replacement = gSettings;
                    replacement.theme = "minimal";
                    ApplySelectedPreferences(replacement, true);
                    // 關閉舊 controller 後才移除資產，避免仍在離開中的頁面持有原主題。
                    if (FAILED(gWebViewHost->RecreateForWindow(gWallpaperWindow)))
                        throw std::runtime_error("無法關閉並重建主題引擎，未移除主題資產。");
                }
                desktopmonitor::themes::ThemeManager(desktopmonitor::app::ThemeStoreDirectory()).Remove(info.id, info.version);
                RefreshThemeMenu();
                gManagementNotice = L"已移除所選主題版本。";
            }
        }
        else if (command == kManageExit) { gClosing = true; PostQuitMessage(0); }
        else if (command == kManagePause) {
            gPlayback.SetPaused(!gPlayback.Paused());
            if (IsOwnedWallpaperWindow(gWallpaperWindow))
                ShowWindow(gWallpaperWindow, gPlayback.Paused() || gDesktopRetry.Pending() ? SW_HIDE : SW_SHOWNOACTIVATE);
            ApplyRuntimePolicy();
        } else if (command == kManageDesktop || command == kManagePreview) {
            SetDisplayMode(command == kManageDesktop);
        } else if (command == kManageLogs) {
            const auto logs = desktopmonitor::app::ThemeStoreDirectory().parent_path() / L"logs";
            std::filesystem::create_directories(logs);
            if (reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", logs.c_str(), nullptr, nullptr, SW_SHOWNORMAL)) <= 32)
                throw std::runtime_error("無法開啟日誌資料夾。");
        } else if (IsOwnedWallpaperWindow(gWallpaperWindow)) {
            WindowProcedure(gWallpaperWindow, WM_COMMAND, command, 0);
        }
    } catch (const std::exception& error) {
        OutputDebugStringA(error.what());
        try {
            const auto logs = desktopmonitor::app::ThemeStoreDirectory().parent_path() / L"logs";
            std::filesystem::create_directories(logs);
            std::ofstream(logs / L"management.log", std::ios::binary | std::ios::app) << error.what() << '\n';
        } catch (...) { OutputDebugStringW(L"無法記錄管理命令錯誤。\n"); }
        if (gManagementNotice.empty()) gManagementNotice = L"操作失敗；請查看日誌。";
        MessageBoxW(nullptr, L"無法完成管理操作，請查看日誌後重試。", L"DrillPaper", MB_OK | MB_ICONWARNING);
    }
    UpdateManagement();
}

/** 重新列舉合法安裝版本並更新原生功能表。 */
void RefreshThemeMenu() {
    desktopmonitor::themes::ThemeManager manager(desktopmonitor::app::ThemeStoreDirectory());
    gInstalledThemes = manager.List();
    while (GetMenuItemCount(gThemeMenu) > 0) DeleteMenu(gThemeMenu, 0, MF_BYPOSITION);
    AppendMenuW(gThemeMenu, MF_STRING, kMinimalThemeCommand, L"Minimal");
    AppendMenuW(gThemeMenu, MF_STRING, kDashboardThemeCommand, L"Dashboard");
    AppendMenuW(gThemeMenu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(gThemeMenu, MF_STRING, kRefreshThemesCommand, L"重新整理已安裝主題");
    for (std::size_t index = 0; index < gInstalledThemes.size(); ++index) {
        const auto& info = gInstalledThemes[index];
        const auto label = info.id + "@" + info.version;
        const std::wstring wide(label.begin(), label.end());
        AppendMenuW(gThemeMenu, MF_STRING, kInstalledThemeCommand + index, wide.c_str());
    }
    DrawMenuBar(gWallpaperWindow);
    if (gManagement) {
        std::vector<desktopmonitor::platform::windows::ManagementTheme> themes{
            {"minimal", L"Minimal · 1.0.0（內建）", true}, {"dashboard", L"Dashboard · 1.0.0（內建）", true}};
        for (const auto& info : gInstalledThemes)
            themes.push_back({info.id + "@" + info.version, NativeText(info.name) + L" · " + NativeText(info.version), false});
        gManagement->SetThemes(std::move(themes));
    }
}

/** 建立可獨立顯示或附掛桌面的宿主與原生主題功能表。
 * Args:
 *     instance: 應用程式實例。
 * Returns:
 *     新視窗；Win32 建立失敗回傳空值，主題設定失敗會拋例外。
 */
HWND CreatePreviewWindow(HINSTANCE instance) {
    HWND window = CreateWindowExW(0, kWindowClass, kWindowTitle, WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 760, 480, nullptr, nullptr, instance, nullptr);
    if (window == nullptr) return nullptr;
    gWallpaperWindow = window;
    HMENU menu = CreateMenu();
    gThemeMenu = CreatePopupMenu();
    if (menu == nullptr || gThemeMenu == nullptr) {
        if (menu != nullptr) DestroyMenu(menu);
        if (gThemeMenu != nullptr) DestroyMenu(gThemeMenu);
        DestroyWindow(window);
        throw std::runtime_error("無法建立主題功能表。");
    }
    AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(gThemeMenu), L"主題");
    SetMenu(window, menu);
    try { RefreshThemeMenu(); }
    catch (...) { DestroyWindow(window); throw; }
    return window;
}

LRESULT CALLBACK WindowProcedure(HWND window, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case kRendererFailedMessage:
        if (gWebViewHost != nullptr && gWebViewHost->LoadEpoch() == static_cast<unsigned long long>(wParam)) {
            SetWindowTextW(window, L"DrillPaper — 正在恢復主題");
            try {
                if (SUCCEEDED(gWebViewHost->Recover())) {
                    gThemeLoadStarted = GetTickCount64();
                } else if (!gThemeFallbackAttempted) {
                    gThemeFallbackAttempted = true;
                    if (!SwitchBuiltinTheme(L"minimal")) {
                        gWebViewHost->Shutdown();
                        gStatusText = L"主題渲染無法恢復，請關閉後重新啟動。";
                        SetWindowTextW(window, L"DrillPaper — 原生預覽（渲染已停止）");
                    }
                } else {
                    gWebViewHost->Shutdown();
                    gStatusText = L"渲染器已達自動復原上限，請關閉後重新啟動。";
                    SetWindowTextW(window, L"DrillPaper — 原生預覽（渲染已停止）");
                }
            } catch (const std::exception&) {
                gWebViewHost->Shutdown();
                gStatusText = L"主題復原失敗，請關閉後重新啟動。";
                SetWindowTextW(window, L"DrillPaper — 原生預覽（渲染已停止）");
            }
            InvalidateRect(window, nullptr, TRUE);
        }
        return 0;
    case kRuntimeStateRefreshMessage:
        if (gWebViewHost != nullptr) gWebViewHost->SetRuntimeState(gAppliedPowerState);
        return 0;
    case kSnapshotReadyMessage: {
        ConsumeLatestSnapshot();
        return 0;
    }
    case kSamplingFailedMessage:
        SetWindowTextW(window, L"DrillPaper — 採樣已停止");
        MessageBoxW(window, L"系統指標採樣失敗，已停止採樣。請查看日誌後重新啟動。", L"DrillPaper", MB_OK | MB_ICONWARNING);
        return 0;
    case WM_COMMAND:
        if (LOWORD(wParam) == kRefreshThemesCommand ||
            (LOWORD(wParam) >= kInstalledThemeCommand && LOWORD(wParam) - kInstalledThemeCommand < gInstalledThemes.size())) {
            try {
                if (LOWORD(wParam) == kRefreshThemesCommand) RefreshThemeMenu();
                else if (gWebViewHost != nullptr) {
                    const auto info = desktopmonitor::themes::ThemeManager::ValidateDirectory(
                        gInstalledThemes[LOWORD(wParam) - kInstalledThemeCommand].directory);
                    const std::wstring name(info.id.begin(), info.id.end());
                    if (SUCCEEDED(gWebViewHost->LoadTheme(info.directory.wstring(), name, std::filesystem::path(info.entry).wstring()))) {
                        gCurrentTheme = name;
                        gCurrentThemeKey = info.id + "@" + info.version;
                        gThemeLoadStarted = GetTickCount64();
                        gThemeFallbackAttempted = false;
                    }
                }
            } catch (const std::exception&) {
                MessageBoxW(window, L"無法載入或列舉主題，請確認安裝資料完整，或改用內建主題。", L"DrillPaper", MB_OK | MB_ICONWARNING);
            }
            return 0;
        }
        if (LOWORD(wParam) == kMinimalThemeCommand || LOWORD(wParam) == kDashboardThemeCommand) {
            gThemeFallbackAttempted = false;
            try {
                SwitchBuiltinTheme(LOWORD(wParam) == kDashboardThemeCommand ? L"dashboard" : L"minimal");
            } catch (const std::exception&) {
                OutputDebugStringW(L"主題切換發生錯誤。\n");
            }
            return 0;
        }
        break;
    case WM_SIZE:
        if (gWebViewHost != nullptr) {
            gWebViewHost->Resize();
        }
        return 0;
    case WM_TIMER:
        if (wParam == kMetricsTimer) {
            if (gSmartSleep) {
                gPowerState.ObserveObscured(desktopmonitor::platform::windows::PowerNotifications::ForegroundIsFullscreen(window), GetTickCount64(), 1000);
                ApplyRuntimePolicy();
            }
            if (gThemeLoadStarted != 0 && gWebViewHost != nullptr) {
                if (gWebViewHost->IsReady()) gThemeLoadStarted = 0;
                else if (gAppliedPowerState != desktopmonitor::runtime::PowerState::Active) gThemeLoadStarted = GetTickCount64();
                else if (GetTickCount64() - gThemeLoadStarted >= 20000) {
                    gThemeLoadStarted = 0;
                    if (!gThemeFallbackAttempted) {
                        gThemeFallbackAttempted = true;
                        try { SwitchBuiltinTheme(L"minimal"); } catch (const std::exception&) { }
                    } else {
                        gStatusText = L"主題載入失敗，請重新選擇內建主題或關閉視窗。";
                        OutputDebugStringW(gStatusText);
                    }
                }
            }
        }
        return 0;
    case kWebViewFailedMessage:
        gStatusText = L"WebView2 is unavailable. The native Preview fallback remains active.";
        OutputDebugStringW(gStatusText);
        OutputDebugStringW(L"\n");
        InvalidateRect(window, nullptr, TRUE);
        return 0;
    case WM_PAINT: {
        PAINTSTRUCT paint{};
        const HDC dc = BeginPaint(window, &paint);
        RECT client{};
        GetClientRect(window, &client);

        HBRUSH background = CreateSolidBrush(RGB(20, 28, 40));
        FillRect(dc, &client, background);
        DeleteObject(background);

        SetBkMode(dc, TRANSPARENT);
        SetTextColor(dc, RGB(235, 240, 248));
        RECT heading = client;
        heading.bottom -= 48;
        DrawTextW(dc, L"DrillPaper Preview", -1, &heading,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        RECT status = client;
        status.top = status.bottom - 48;
        DrawTextW(dc, gStatusText, -1, &status,
                  DT_CENTER | DT_VCENTER | DT_SINGLELINE);

        RECT marker{client.left + 24, client.top + 24, client.left + 48, client.top + 48};
        HBRUSH accent = CreateSolidBrush(RGB(66, 190, 150));
        FillRect(dc, &marker, accent);
        DeleteObject(accent);

        EndPaint(window, &paint);
        return 0;
    }
    case WM_NCHITTEST:
        if (gExperimentalDesktop) {
            return HTTRANSPARENT;
        }
        break;
    case WM_CLOSE:
        if (gManaged) {
            if (!gPlayback.Paused()) HandleManagementCommand(desktopmonitor::platform::windows::kManagePause);
            return 0;
        }
        gClosing = true;
        DestroyWindow(window);
        return 0;
    case WM_DESTROY:
        RemovePropW(window, L"DrillPaper.DesktopEpoch");
        RemovePropW(window, L"DrillPaper.DesktopFailure");
        KillTimer(window, kMetricsTimer);
        if (gExperimentalDesktop && !gClosing) {
            if (window == gWallpaperWindow) gWallpaperWindow = nullptr;
            if (!gDesktopRecoveryInProgress) {
                gLostWallpaperWindow = window;
                PostMessageW(gNotificationWindow, kShellRecoveryMessage, 0, 0);
            }
            return 0;
        }
        if (gSamplingWorker != nullptr) {
            gSamplingWorker->Stop();
            gSamplingWorker.reset();
        }
        gPowerNotifications.reset();
        if (gWebViewHost != nullptr) {
            gWebViewHost->Shutdown();
        }
        PostQuitMessage(0);
        return 0;
    default:
        return DefWindowProcW(window, message, wParam, lParam);
    }
    return DefWindowProcW(window, message, wParam, lParam);
}
} // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR commandLine, int showCommand) {
    if (const auto result = desktopmonitor::app::RunThemeCommand()) return *result;
    if (HasFlag(commandLine, L"--version")) {
        RunVersion();
        return 0;
    }
    if (HasFlag(commandLine, L"--diagnostics")) {
        RunDiagnostics();
        return 0;
    }

    const bool forcePreview = HasFlag(commandLine, L"--preview");
    gManaged = HasFlag(commandLine, L"--management") ||
        (!forcePreview && !HasFlag(commandLine, L"--experimental-desktop"));
    gMockMetrics = HasFlag(commandLine, L"--mock-metrics");
    gSmartSleep = !HasFlag(commandLine, L"--no-smart-sleep");
    try {
        if (gManaged) {
            gSettingsStore = std::make_unique<desktopmonitor::app::SettingsStore>(
                desktopmonitor::app::ThemeStoreDirectory().parent_path() / L"settings.json");
            gSettings = gSettingsStore->Load();
        } else gSettings.desktop = false;
        if (forcePreview || gMockMetrics) gSettings.desktop = false;
        if (HasFlag(commandLine, L"--experimental-desktop") && !forcePreview && !gMockMetrics) gSettings.desktop = true;
        if (HasFlag(commandLine, L"--no-smart-sleep")) gSettings.smartSleep = false;
        if (HasFlag(commandLine, L"--theme=dashboard")) gSettings.theme = "dashboard";
        else if (HasFlag(commandLine, L"--theme=minimal")) gSettings.theme = "minimal";
        gSmartSleep = gSettings.smartSleep;
    } catch (const std::exception& error) {
        OutputDebugStringA(error.what());
        try {
            const auto logs = desktopmonitor::app::ThemeStoreDirectory().parent_path() / L"logs";
            std::filesystem::create_directories(logs);
            std::ofstream(logs / L"settings.log", std::ios::binary | std::ios::app) << error.what() << '\n';
        } catch (...) { OutputDebugStringW(L"無法記錄設定讀取錯誤。\n"); }
        MessageBoxW(nullptr, L"無法讀取設定或必要的 LOCALAPPDATA 路徑，請備份並檢查 settings.json；未覆蓋原檔。", L"DrillPaper", MB_OK | MB_ICONERROR);
        return 1;
    }
    const std::wstring themeName(gSettings.theme.begin(), gSettings.theme.end());
    gCurrentTheme = themeName;
    gCurrentThemeKey = gSettings.theme;
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    WNDCLASSW windowClass{};
    windowClass.lpfnWndProc = WindowProcedure;
    windowClass.hInstance = instance;
    windowClass.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    windowClass.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    windowClass.lpszClassName = kWindowClass;
    if (RegisterClassW(&windowClass) == 0) {
        return static_cast<int>(GetLastError());
    }

    HWND window = nullptr;
    try { window = CreatePreviewWindow(instance); }
    catch (const std::exception& error) {
        OutputDebugStringA(error.what());
        MessageBoxW(nullptr, L"無法初始化監控視窗或主題目錄，請確認 LOCALAPPDATA 與系統資源。", L"DrillPaper", MB_OK | MB_ICONERROR);
        return 1;
    }
    if (window == nullptr) return 1;
    gTaskbarCreatedMessage = RegisterWindowMessageW(L"TaskbarCreated");
    WNDCLASSW notificationClass{};
    notificationClass.lpfnWndProc = NotificationProcedure;
    notificationClass.hInstance = instance;
    notificationClass.lpszClassName = kNotificationClass;
    const bool notificationReady = RegisterClassW(&notificationClass) != 0;
    const HWND notificationWindow = notificationReady
        ? CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kNotificationClass, L"",
                         WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, instance, nullptr)
        : nullptr;
    if (notificationWindow == nullptr || gTaskbarCreatedMessage == 0) {
        MessageBoxW(window, L"無法建立背景通知視窗，請重新啟動 DrillPaper。", L"DrillPaper", MB_OK | MB_ICONERROR);
        DestroyWindow(window);
        return 1;
    }
    gNotificationWindow = notificationWindow;
    if (gManaged) {
        gManagement = std::make_unique<desktopmonitor::platform::windows::ManagementShell>();
        if (!gManagement->Initialize(notificationWindow, HandleManagementCommand)) {
            MessageBoxW(window, L"無法建立管理介面，請確認系統資源後重新啟動。", L"DrillPaper", MB_OK | MB_ICONERROR);
            gManagement.reset();
            gClosing = true;
            DestroyWindow(window);
            DestroyWindow(notificationWindow);
            return 1;
        }
        try { RefreshThemeMenu(); gManagement->SetPreferences(gSettings); }
        catch (const std::exception& error) {
            OutputDebugStringA(error.what());
            MessageBoxW(window, L"無法列舉已安裝主題，請確認資料目錄。", L"DrillPaper", MB_OK | MB_ICONERROR);
            gManagement.reset(); gClosing = true;
            DestroyWindow(window); DestroyWindow(notificationWindow); return 1;
        }
    }

    const HRESULT apartmentResult = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool comInitialized = SUCCEEDED(apartmentResult);
    if (!comInitialized) {
        gStatusText = L"COM initialization failed. The native Preview fallback remains active.";
    } else {
        if (gMockMetrics) {
            gLatestSnapshot = MakeMockSnapshot();
        }
        gWebViewHost = std::make_unique<desktopmonitor::web::WebView2Host>();

        std::array<wchar_t, 32768> executablePath{};
        const DWORD executableLength = GetModuleFileNameW(
            nullptr, executablePath.data(), static_cast<DWORD>(executablePath.size()));
        if (executableLength == 0 || executableLength >= executablePath.size()) {
            gStatusText = L"Could not locate Preview theme assets. The native Preview fallback remains active.";
            gWebViewHost.reset();
        } else {
            desktopmonitor::themes::ThemeInfo initialTheme;
            try { initialTheme = ResolveTheme(gSettings.theme); }
            catch (const std::exception& error) {
                OutputDebugStringA(error.what());
                MessageBoxW(window, L"無法載入所選主題，請確認安裝資料；可用 --theme=minimal 指定內建主題。", L"DrillPaper", MB_OK | MB_ICONERROR);
                gManagement.reset(); gClosing = true;
                DestroyWindow(window); DestroyWindow(notificationWindow); CoUninitialize(); return 1;
            }
            const HRESULT webViewResult = gWebViewHost->Initialize(
                window, initialTheme.directory.wstring(), themeName, std::filesystem::path(initialTheme.entry).wstring());
            if (FAILED(webViewResult)) {
                gStatusText = L"WebView2 failed to initialize. The native Preview fallback remains active.";
                OutputDebugStringW(gStatusText);
                OutputDebugStringW(L"\n");
                gWebViewHost.reset();
            } else {
                gWebViewHost->SetSnapshot(gLatestSnapshot);
            }
        }
        try {
        gSamplingWorker = std::make_unique<desktopmonitor::runtime::SamplingWorker>(
            [mock = gMockMetrics, collector = std::shared_ptr<desktopmonitor::monitoring::WindowsMetricsCollector>()](bool reset) mutable {
                if (mock) return MakeMockSnapshot();
                if (reset || !collector) collector = std::make_shared<desktopmonitor::monitoring::WindowsMetricsCollector>();
                desktopmonitor::core::MetricsSnapshot snapshot;
                collector->Collect(snapshot);
                return snapshot;
            },
            [notificationWindow](const auto& snapshot, unsigned long long generation) {
                if (gSnapshotMailbox.Publish(UiSnapshot{snapshot, generation}) && !PostMessageW(notificationWindow, kSnapshotReadyMessage, 0, 0))
                    gSnapshotMailbox.NotificationPostFailed();
            },
            [notificationWindow](std::exception_ptr error) {
                try {
                    try { std::rethrow_exception(error); }
                    catch (const std::exception& detail) {
                        const auto logs = desktopmonitor::app::ThemeStoreDirectory().parent_path() / L"logs";
                        std::filesystem::create_directories(logs);
                        std::ofstream(logs / L"sampling.log", std::ios::binary | std::ios::app) << detail.what() << '\n';
                    }
                } catch (...) { OutputDebugStringW(L"無法記錄採樣失敗詳情。\n"); }
                PostMessageW(notificationWindow, kSamplingFailedMessage, 0, 0);
            });
        } catch (const std::exception& error) {
            OutputDebugStringA(error.what());
            MessageBoxW(window, L"無法啟動背景採樣工作者，請確認系統資源後重新啟動。", L"DrillPaper", MB_OK | MB_ICONERROR);
            if (gWebViewHost != nullptr) { gWebViewHost->Shutdown(); gWebViewHost.reset(); }
            DestroyWindow(window);
            if (comInitialized) CoUninitialize();
            return 1;
        }
        SetTimer(window, kMetricsTimer, 1000, nullptr);
    }

    gPowerNotifications = std::make_unique<desktopmonitor::platform::windows::PowerNotifications>();
    if (!gPowerNotifications->Initialize([](auto event) {
        using desktopmonitor::platform::windows::PowerEvent;
        switch (event) {
        case PowerEvent::Locked: gPowerState.SetLocked(true); break;
        case PowerEvent::Unlocked: gPowerState.SetLocked(false); break;
        case PowerEvent::DisplayOff:
        case PowerEvent::SystemSuspend: gPowerState.SetDisplayOff(true); break;
        case PowerEvent::DisplayOn:
        case PowerEvent::SystemResume: gPowerState.SetDisplayOff(false); break;
        }
        ApplyRuntimePolicy();
    })) {
        const auto error = gPowerNotifications->LastError();
        OutputDebugStringW((L"無法註冊電源通知，Win32 代碼：" + std::to_wstring(error) + L"\n").c_str());
        gSmartSleep = false;
        MessageBoxW(window, L"無法註冊工作階段或電源通知，智慧休眠已停用。基本 Preview 可繼續使用。", L"DrillPaper", MB_OK | MB_ICONWARNING);
    }
    ApplyRuntimePolicy();

    desktopmonitor::platform::windows::Win32DesktopHost desktopHost;
    gDesktopHost = &desktopHost;
    gExperimentalDesktop = gSettings.desktop;
    if (gExperimentalDesktop) {
        SetTimer(notificationWindow, kDesktopWatchdogTimer, 1000, nullptr);
        RecoverDesktopHost();
    }

    if (!gDesktopRetry.Pending()) ShowWindow(window, showCommand);
    UpdateWindow(window);
    if (gManaged) {
        SetTimer(notificationWindow, kDesktopWatchdogTimer, 1000, nullptr);
        UpdateManagement();
        if (HasFlag(commandLine, L"--management")) gManagement->Show();
    }

    MSG message{};
    while (GetMessageW(&message, nullptr, 0, 0) > 0) {
        if (gManagement && gManagement->Translate(&message)) continue;
        TranslateMessage(&message);
        DispatchMessageW(&message);
    }
    gClosing = true;
    if (gSamplingWorker != nullptr) { gSamplingWorker->Stop(); gSamplingWorker.reset(); }
    gPowerNotifications.reset();
    gManagement.reset();
    gWebViewHost.reset();
    if (IsOwnedWallpaperWindow(gWallpaperWindow)) DestroyWindow(gWallpaperWindow);
    if (IsWindow(gNotificationWindow)) DestroyWindow(gNotificationWindow);
    if (comInitialized) {
        CoUninitialize();
    }
    return static_cast<int>(message.wParam);
}
