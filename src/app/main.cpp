#include <windows.h>
#include <array>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>
#include "desktopmonitor/app/theme_commands.h"
#include "desktopmonitor/monitoring/windows_metrics_collector.h"
#include "desktopmonitor/platform/windows/desktop_host.h"
#include "desktopmonitor/platform/windows/management_shell.h"
#include "desktopmonitor/platform/windows/monitor_info.h"
#include "desktopmonitor/platform/windows/power_notifications.h"
#include "desktopmonitor/runtime/managed_playback.h"
#include "desktopmonitor/runtime/windows_snapshot_mailbox.h"
#include "desktopmonitor/runtime/sampling_worker.h"
#include "desktopmonitor/themes/theme_manager.h"
#include "desktopmonitor/web/webview2_host.h"

namespace {
namespace win = desktopmonitor::platform::windows;
namespace runtime = desktopmonitor::runtime;
namespace app = desktopmonitor::app;
constexpr wchar_t kWindowClass[] = L"DrillPaperPreviewWindow";
constexpr wchar_t kNotificationClass[] = L"DrillPaperShellNotifications";
constexpr wchar_t kApplicationVersion[] = L"0.1.0-dev";
constexpr UINT kSnapshotReady = WM_APP + 0x34;
constexpr UINT kSamplingFailed = WM_APP + 0x35;
constexpr UINT kReconcile = WM_APP + 0x39;
constexpr UINT_PTR kTick = 2;

struct Surface {
    std::string area;
    RECT bounds{};
    UINT dpi = 96;
    HWND window = nullptr;
    win::Win32DesktopHost desktop;
    desktopmonitor::web::WebView2Host renderer;
    runtime::DesktopRecoveryRetry retry;
    bool attached = false;
    bool fallback = false;
    bool stopped = false;
    unsigned long long loadStarted = 0;
};
struct UiSnapshot { desktopmonitor::core::MetricsSnapshot snapshot; unsigned long long generation = 0; };
std::vector<std::unique_ptr<Surface>> gSurfaces;
win::MonitorInventory gMonitorInventory;
const auto& gMonitors = gMonitorInventory.Monitors();
std::unique_ptr<runtime::SamplingWorker> gWorker;
std::unique_ptr<win::PowerNotifications> gPower;
std::unique_ptr<win::ManagementShell> gManagement;
std::unique_ptr<app::SettingsStore> gStore;
runtime::WindowsSnapshotMailbox<UiSnapshot> gMailbox;
runtime::PowerStateMachine gPowerState;
runtime::ManagedPlayback gPlayback;
runtime::PowerState gAppliedState = runtime::PowerState::Active;
bool gPolicyInitialized = false;
unsigned long long gSamplingGeneration = 0;
desktopmonitor::core::MetricsSnapshot gLatestSnapshot{};
app::AppSettings gSaved;
app::AppSettings gEffective;
std::string gCurrentThemeKey = "minimal";
std::wstring gCurrentTheme = L"Minimal";
std::wstring gNotice;
HWND gNotification = nullptr;
UINT gTaskbarCreated = 0;
bool gClosing = false;
bool gChangingSurfaces = false;
bool gManaged = false;
bool gMockMetrics = false;
bool gPrimaryFallback = false;
bool gUnidentifiedFallback = false;
ULONG_PTR gDesktopEpoch = 0;
std::vector<desktopmonitor::themes::ThemeInfo> gInstalledThemes;
void UpdateSurfaceMenu(Surface& surface);

/** 取得協定快照使用的 Unix 毫秒時間。
 * Returns:
 *     目前 UTC 的 Unix 毫秒。
 */
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

/** 建立 SDK 展示用的有界固定指標。
 * Returns:
 *     含目前時間的 mock 快照。
 */
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

/** 將 CLI 訊息寫入目前主控台。
 * Args:
 *     text: 要輸出的原生文字。
 * Returns:
 *     寫入成功時為 true。
 */
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

/** 輸出目前應用程式版本。 */
void RunVersion() {
    const std::wstring text = std::wstring(L"DrillPaper ") + kApplicationVersion + L"\r\n";
    if (!WriteCommandOutput(text)) {
        OutputDebugStringW(text.c_str());
    }
}

/** 顯示原生架構及實際 WebView2 Runtime 版本。 */
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


/** 比對獨立 CLI 選項，避免接受其他參數的子字串。
 * Args:
 *     commandLine: Windows 提供的命令列。
 *     flag: 完整選項文字。
 * Returns:
 *     存在完整選項時為 true。
 */
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



/** 將預期錯誤寫入本機日誌。
 * Args:
 *     error: 含上下文的錯誤。
 */
void LogError(const std::string& error) {
    OutputDebugStringA((error + "\n").c_str());
    try {
        const auto logs = app::ThemeStoreDirectory().parent_path() / L"logs";
        std::filesystem::create_directories(logs);
        std::ofstream(logs / L"management.log", std::ios::binary | std::ios::app) << error << '\n';
    } catch (...) { OutputDebugStringW(L"無法寫入錯誤日誌。\n"); }
}

/** 驗證視窗仍由目前 UI 執行緒及目標持有。
 * Args:
 *     surface: 欲檢查的目標。
 * Returns:
 *     HWND 與所有權均有效時為 true。
 */
bool OwnsWindow(const Surface& surface) {
    return surface.desktop.IsCurrentThreadWindow(surface.window) &&
        reinterpret_cast<Surface*>(GetWindowLongPtrW(surface.window, GWLP_USERDATA)) == &surface;
}

/** 將每個目標的有效狀態呈現於唯一可信管理入口。 */
void UpdateManagement() {
    if (!gManagement) return;
    const auto ready = std::count_if(gSurfaces.begin(), gSurfaces.end(), [](const auto& surface) { return surface->renderer.IsReady(); });
    std::wstring status = gPlayback.Paused() ? L"已手動暫停。" :
        gAppliedState != runtime::PowerState::Active ? L"智慧休眠中。" : L"運作中。";
    status += L"主題已連線 " + std::to_wstring(ready) + L"／" + std::to_wstring(gSurfaces.size()) + L" 個目標。";
    if (gPrimaryFallback && gEffective.desktop) status += L"\r\n已選螢幕皆未連接，暫時顯示於主螢幕";
    if (gUnidentifiedFallback && gEffective.desktop) status += L"\r\n有螢幕無法辨識，暫時套用到所有螢幕";
    if (!gMonitorInventory.Error().empty()) status += gMonitorInventory.PrimaryFallback()
        ? L"\r\n螢幕列舉暫時失敗，暫用主螢幕；稍後自動重試，未變更保存目標。"
        : L"\r\n螢幕列舉暫時失敗，保留上次成功結果；稍後自動重試。";
    if (std::any_of(gSurfaces.begin(), gSurfaces.end(), [](const auto& s) { return s->retry.Pending(); })) status += L"\r\n正在等待桌面就緒並重新連接…";
    if (!gNotice.empty()) status += L"\r\n" + gNotice;
    gManagement->Update(gCurrentTheme, status, gPlayback.Paused(), gEffective.desktop);
}

/** 更新螢幕標籤、鏡像關係與保存但未連接的項目。 */
void UpdateMonitorList() {
    if (!gManagement) return;
    std::vector<win::ManagementMonitor> choices;
    for (std::size_t index = 0; index < gMonitors.size(); ++index) {
        const auto& monitor = gMonitors[index];
        auto label = std::to_wstring(index + 1) + L". " + monitor.name + L" · " +
            std::to_wstring(monitor.bounds.right - monitor.bounds.left) + L"×" +
            std::to_wstring(monitor.bounds.bottom - monitor.bounds.top) + L" · " + std::to_wstring(monitor.dpi * 100 / 96) + L"%";
        if (monitor.target.primary) label += L"（主螢幕）";
        if (std::count_if(gMonitors.begin(), gMonitors.end(), [&](const auto& other) { return other.target.area == monitor.target.area; }) > 1)
            label += L"（鏡像 " + NativeText(monitor.target.area) + L"）";
        choices.push_back({monitor.target.id, std::move(label)});
    }
    if (gSaved.monitorTargets) for (const auto& id : *gSaved.monitorTargets)
        if (std::none_of(choices.begin(), choices.end(), [&](const auto& choice) { return choice.id == id; }))
            choices.push_back({id, NativeText(id) + L"（未連接）"});
    gManagement->SetMonitors(std::move(choices));
}

/** 在局部錯誤邊界更新螢幕快取，確保 reconcile 與 renderer tick 繼續。 */
void RefreshMonitors() {
    // 獨立 Preview 的啟動與 tick 不讀取螢幕拓樸。
    if (!gEffective.desktop && !gManagement) return;
    const bool changed = gMonitorInventory.Refresh();
    if (!gMonitorInventory.Error().empty()) LogError("螢幕列舉暫時失敗，保留可用結果：" + gMonitorInventory.Error());
    bool resolvedDefault = false;
    if (!gSaved.monitorTargets) {
        const auto primary = std::find_if(gMonitors.begin(), gMonitors.end(), [](const auto& monitor) {
            return monitor.target.primary && !monitor.target.id.empty();
        });
        if (primary != gMonitors.end()) {
            gSaved.monitorTargets = std::vector<std::string>{primary->target.id};
            if (!gEffective.monitorTargets) gEffective.monitorTargets = gSaved.monitorTargets;
            resolvedDefault = true;
        }
    }
    if (changed || resolvedDefault) {
        UpdateMonitorList();
        if (resolvedDefault && gManagement) gManagement->SetPreferences(gSaved);
        for (auto& surface : gSurfaces) surface->retry.Reset();
        for (const auto& monitor : gMonitors) if (!monitor.identificationError.empty())
            LogError(monitor.identificationError + "，區域=" + monitor.target.area + "，DPI=" + std::to_string(monitor.dpi));
    }
}

/** 更新主題清單，來源一律經 ThemeManager 驗證。 */
void RefreshThemes() {
    gInstalledThemes = desktopmonitor::themes::ThemeManager(app::ThemeStoreDirectory()).List();
    for (auto& surface : gSurfaces) UpdateSurfaceMenu(*surface);
    if (!gManagement) return;
    std::vector<win::ManagementTheme> themes{{"minimal", L"Minimal · 1.0.0（內建）", true}, {"dashboard", L"Dashboard · 1.0.0（內建）", true}};
    for (const auto& info : gInstalledThemes)
        themes.push_back({info.id + "@" + info.version, NativeText(info.name) + L" · " + NativeText(info.version), false});
    gManagement->SetThemes(std::move(themes));
}

/** 將全域暫停及電源政策套用到所有 renderer 與唯一採集工作者。 */
void ApplyRuntimePolicy() {
    const auto state = gPlayback.EffectiveState(gPowerState.State(), gEffective.smartSleep);
    const bool changed = !gPolicyInitialized || state != gAppliedState;
    if (changed) {
        const bool reset = !gPolicyInitialized || gPowerState.RequiresFullSnapshot() || state == runtime::PowerState::Active;
        gAppliedState = state;
        gPolicyInitialized = true;
        if (gWorker) gSamplingGeneration = gWorker->Configure(gPlayback.SamplingInterval(gPowerState.SamplingIntervalMilliseconds(), gEffective.smartSleep), reset);
    }
    for (auto& surface : gSurfaces) {
        if (changed && FAILED(surface->renderer.SetRuntimeState(state))) LogError("目標 renderer 未完整套用電源政策。");
        if (OwnsWindow(*surface)) ShowWindow(surface->window,
            gPlayback.Paused() || (gEffective.desktop && !surface->attached) ? SW_HIDE : SW_SHOWNOACTIVATE);
    }
}

/** 在單一目標載入指定主題。
 * Args:
 *     surface: 目前 UI 執行緒持有的目標。
 *     key: 全域或安全復原主題。
 */
void LoadSurfaceTheme(Surface& surface, const std::string& key) {
    const auto info = ResolveTheme(key);
    surface.renderer.SetNetworkEnabled(gEffective.allowNetwork);
    if (FAILED(surface.renderer.LoadTheme(info.directory.wstring(), NativeText(info.name), std::filesystem::path(info.entry).wstring(), surface.window)))
        throw std::runtime_error("無法初始化目標主題引擎。");
    surface.stopped = false;
    surface.renderer.SetSnapshot(gLatestSnapshot);
    surface.renderer.SetRuntimeState(gAppliedState);
    surface.loadStarted = GetTickCount64();
}

/** 僅在失敗目標嘗試一次可信 Minimal，保留原偏好及管理入口。
 * Args:
 *     surface: 失敗目標。
 */
void FallbackSurface(Surface& surface) {
    try {
        if (surface.fallback || gCurrentThemeKey == "minimal") throw std::runtime_error("目標的可信復原主題亦無法使用。");
        surface.fallback = true;
        LoadSurfaceTheme(surface, "minimal");
        gNotice = L"部分目標已回復 Minimal；保存的偏好未變更。";
    } catch (const std::exception& error) {
        LogError(error.what());
        surface.renderer.Shutdown(); surface.stopped = true; surface.loadStarted = 0;
        SetWindowTextW(surface.window, L"DrillPaper — 此目標渲染已停止，請從管理介面重新套用");
        gNotice = L"部分目標渲染已停止，請重新套用主題或查看日誌。";
    }
    UpdateManagement();
}

LRESULT CALLBACK SurfaceProcedure(HWND window, UINT message, WPARAM value, LPARAM data);

/** 保留獨立 Preview 的既有內建及已安裝主題入口。
 * Args:
 *     surface: Preview 目標，桌布目標不建立功能表。
 */
void UpdateSurfaceMenu(Surface& surface) {
    if (surface.area != "preview" || !OwnsWindow(surface)) return;
    HMENU menu = CreateMenu(), themes = CreatePopupMenu();
    if (!menu || !themes) {
        if (menu) DestroyMenu(menu);
        if (themes) DestroyMenu(themes);
        throw std::runtime_error("無法建立預覽主題功能表。");
    }
    AppendMenuW(themes, MF_STRING, 10001, L"Minimal");
    AppendMenuW(themes, MF_STRING, 10002, L"Dashboard");
    AppendMenuW(themes, MF_STRING, 10003, L"重新整理已安裝主題");
    for (std::size_t index = 0; index < gInstalledThemes.size(); ++index) {
        const auto label = NativeText(gInstalledThemes[index].id + "@" + gInstalledThemes[index].version);
        AppendMenuW(themes, MF_STRING, 11000 + index, label.c_str());
    }
    AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(themes), L"主題");
    const auto previous = GetMenu(surface.window);
    SetMenu(surface.window, menu);
    if (previous) DestroyMenu(previous);
    DrawMenuBar(surface.window);
}

/** 建立單一目標 HWND，renderer 只綁定這個視窗。
 * Args:
 *     surface: 穩定配置的目標所有權物件。
 */
void CreateSurfaceWindow(Surface& surface) {
    surface.window = CreateWindowExW(0, kWindowClass, L"DrillPaper — 正在載入主題", WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, 760, 480, nullptr, nullptr, GetModuleHandleW(nullptr), &surface);
    if (!surface.window) throw std::runtime_error("無法建立目標宿主視窗。");
    UpdateSurfaceMenu(surface);
}

/** 銷毀本程序擁有的目標，先撤銷所有 callback。
 * Args:
 *     surface: 要移除的目標。
 */
void DestroySurface(Surface& surface) {
    surface.renderer.Shutdown();
    if (OwnsWindow(surface)) DestroyWindow(surface.window);
    surface.window = nullptr;
}

/** 比對有效目標，只重建失效或新增的視窗並各自附掛。 */
void ReconcileSurfaces() {
    if (gClosing || gChangingSurfaces) return;
    gChangingSurfaces = true;
    try {
        std::vector<win::MonitorInfo> desired;
        if (gEffective.desktop) {
            std::vector<runtime::MonitorTarget> connected;
            for (const auto& monitor : gMonitors) connected.push_back(monitor.target);
            const auto selection = runtime::ResolveMonitorTargets(gEffective.monitorTargets.value_or(std::vector<std::string>{}), connected);
            gPrimaryFallback = selection.primaryFallback;
            gUnidentifiedFallback = selection.unidentifiedFallback;
            for (const auto index : selection.areas) desired.push_back(gMonitors[index]);
        } else { gPrimaryFallback = false; gUnidentifiedFallback = false; desired.push_back({{"", "preview", true}, L"Preview", {}, 96}); }
        for (auto it = gSurfaces.begin(); it != gSurfaces.end();) {
            if (std::none_of(desired.begin(), desired.end(), [&](const auto& monitor) { return monitor.target.area == (*it)->area; })) {
                DestroySurface(**it); it = gSurfaces.erase(it);
            } else ++it;
        }
        for (const auto& monitor : desired) {
            auto found = std::find_if(gSurfaces.begin(), gSurfaces.end(), [&](const auto& surface) { return surface->area == monitor.target.area; });
            if (found == gSurfaces.end()) {
                auto surface = std::make_unique<Surface>(); surface->area = monitor.target.area;
                gSurfaces.push_back(std::move(surface)); found = gSurfaces.end() - 1;
            }
            auto& surface = **found;
            const bool geometryChanged = !EqualRect(&surface.bounds, &monitor.bounds) || surface.dpi != monitor.dpi;
            surface.bounds = monitor.bounds; surface.dpi = monitor.dpi;
            if (!OwnsWindow(surface)) {
                surface.renderer.Shutdown(); surface.window = nullptr; CreateSurfaceWindow(surface);
                surface.renderer.SetRasterizationScale(gEffective.desktop ? surface.dpi / 96.0 : 0);
                try { LoadSurfaceTheme(surface, surface.fallback ? "minimal" : gCurrentThemeKey); }
                catch (const std::exception& error) { LogError(error.what()); FallbackSurface(surface); }
                surface.attached = false; surface.retry.Reset();
            }
            if (!gEffective.desktop) continue;
            if (geometryChanged) surface.retry.Reset();
            if (geometryChanged || !surface.desktop.IsAttached(surface.window)) surface.attached = false;
            if (!surface.attached && surface.retry.CanAttempt(GetTickCount64())) {
                win::DesktopAttachFailure failure{};
                surface.attached = surface.desktop.TryAttach(surface.window, surface.bounds, &failure);
                if (surface.attached) {
                    surface.retry.Reset();
                    surface.desktop.RecordAttachment(surface.window, ++gDesktopEpoch, surface.dpi);
                } else {
                    ShowWindow(surface.window, SW_HIDE);
                    surface.desktop.RecordAttachmentFailure(surface.window, failure);
                    surface.retry.RecordFailure(GetTickCount64());
                    LogError("目標桌面附掛失敗，代碼：" + std::to_string(static_cast<int>(failure)));
                    gNotice = L"部分桌面尚未附掛；可由管理介面切換預覽或重試桌布模式。";
                }
            }
            if (FAILED(surface.renderer.SetRasterizationScale(surface.dpi / 96.0))) {
                LogError("無法套用目標 DPI，已停止此目標的渲染。"); surface.renderer.Shutdown(); surface.stopped = true;
            }
            surface.renderer.Resize();
        }
        ApplyRuntimePolicy();
    } catch (...) { gChangingSurfaces = false; throw; }
    gChangingSurfaces = false; UpdateManagement();
}

/** 在副作用前驗證桌布目標；首次未解析偏好留給既有主螢幕遷移。
 * Args:
 *     settings: 要套用或啟動的偏好。
 *     requireResolved: 保存時必須已解析桌布目標。
 */
void ValidateDesktopSelection(const app::AppSettings& settings, bool requireResolved) {
    if (settings.desktop && (settings.monitorTargets ? settings.monitorTargets->empty() : requireResolved))
        throw app::SettingsValidationError("桌布模式至少需選擇一個目標螢幕。");
}

/** 套用完整草稿，保存成功才更新保存偏好。
 * Args:
 *     settings: 使用者明確套用的草稿。
 *     persist: 是否保存至版本化設定。
 */
void ApplyPreferences(const app::AppSettings& settings, bool persist) {
    ValidateDesktopSelection(settings, persist);
    const auto info = ResolveTheme(settings.theme);
    gEffective = settings; gCurrentThemeKey = settings.theme; gCurrentTheme = NativeText(info.name) + L" · " + NativeText(info.version);
    RefreshMonitors();
    gPolicyInitialized = false;
    for (auto& surface : gSurfaces) surface->retry.Reset();
    ReconcileSurfaces();
    for (auto& surface : gSurfaces) {
        surface->fallback = false;
        try { LoadSurfaceTheme(*surface, settings.theme); }
        catch (const std::exception& error) { LogError(error.what()); FallbackSurface(*surface); }
    }
    if (persist) {
        try { gStore->Save(settings); }
        catch (...) { gNotice = L"目前已套用操作，但設定未儲存；重啟後仍使用上次偏好。"; throw; }
        gSaved = settings; gNotice = L"設定已儲存；各目標仍須等待主題載入完成。";
        if (gManagement) gManagement->SetPreferences(gSaved);
    } else gNotice = L"已暫時套用；保存的偏好未變更。";
    ApplyRuntimePolicy();
}

/** 處理可信原生管理命令，HTML 不接觸此入口。
 * Args:
 *     command: 原生 UI 或功能表命令。
 */
void HandleCommand(UINT command) {
    gNotice.clear();
    try {
        if (command == win::kManageOpen) { if (gManagement) gManagement->Show(); }
        else if (command == win::kManageApply) ApplyPreferences(gManagement->Preferences(), true);
        else if (command == win::kManageCancel) { gManagement->SetPreferences(gSaved); gNotice = L"已取消尚未套用的設定變更。"; }
        else if (command == win::kManageThemeApply || command == win::kManageThemePreview) {
            auto draft = gManagement->Preferences(); draft.desktop = command == win::kManageThemeApply;
            ApplyPreferences(draft, command == win::kManageThemeApply);
        } else if (command == win::kManageRefresh || command == 10003) { RefreshThemes(); RefreshMonitors(); UpdateMonitorList(); }
        else if (command == win::kManageImport) {
            const auto package = gManagement->PickPackage();
            if (!package.empty()) { desktopmonitor::themes::ThemeManager(app::ThemeStoreDirectory()).Install(package); RefreshThemes(); gNotice = L"主題已匯入。"; }
        } else if (command == win::kManageRemove) {
            const auto key = gManagement->Preferences().theme;
            if (key == "minimal" || key == "dashboard") throw std::runtime_error("內建主題不可移除。");
            const auto info = ResolveTheme(key);
            if (gManagement->ConfirmRemoval()) {
                if (key == gCurrentThemeKey || key == gSaved.theme) { auto replacement = gEffective; replacement.theme = "minimal"; ApplyPreferences(replacement, true); }
                desktopmonitor::themes::ThemeManager(app::ThemeStoreDirectory()).Remove(info.id, info.version); RefreshThemes();
            }
        } else if (command == win::kManagePause) { gPlayback.SetPaused(!gPlayback.Paused()); ApplyRuntimePolicy(); }
        else if (command == win::kManageDesktop || command == win::kManagePreview) {
            auto settings = gEffective; settings.desktop = command == win::kManageDesktop; ApplyPreferences(settings, false);
        } else if (command == win::kManageExit) { gClosing = true; PostQuitMessage(0); }
        else if (command == win::kManageLogs) {
            const auto logs = app::ThemeStoreDirectory().parent_path() / L"logs"; std::filesystem::create_directories(logs);
            if (reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", logs.c_str(), nullptr, nullptr, SW_SHOWNORMAL)) <= 32) throw std::runtime_error("無法開啟日誌資料夾。");
        } else if (command == 10001 || command == 10002 || (command >= 11000 && command - 11000 < gInstalledThemes.size())) {
            auto settings = gEffective;
            settings.theme = command == 10001 ? "minimal" : command == 10002 ? "dashboard" : gInstalledThemes[command - 11000].id + "@" + gInstalledThemes[command - 11000].version;
            ApplyPreferences(settings, false);
        }
    } catch (const app::SettingsValidationError& error) {
        LogError(error.what()); gNotice = NativeText(error.what());
        MessageBoxW(nullptr, gNotice.c_str(), L"DrillPaper", MB_OK | MB_ICONWARNING);
    } catch (const std::exception& error) {
        LogError(error.what()); if (gNotice.empty()) gNotice = L"無法完成管理操作，請查看日誌後重試。";
        MessageBoxW(nullptr, gNotice.c_str(), L"DrillPaper", MB_OK | MB_ICONWARNING);
    }
    UpdateManagement();
}

/** 僅處理 HWND 綁定目標與目前載入世代的訊息。
 * Args:
 *     window: 接收訊息的 HWND。
 *     message: Windows 或可信 adapter 訊息。
 *     value: 訊息參數或載入世代。
 *     data: 訊息參數或載入世代。
 * Returns:
 *     原生處理結果。
 */
LRESULT CALLBACK SurfaceProcedure(HWND window, UINT message, WPARAM value, LPARAM data) {
    auto surface = reinterpret_cast<Surface*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
        surface = static_cast<Surface*>(reinterpret_cast<CREATESTRUCTW*>(data)->lpCreateParams);
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(surface)); surface->window = window;
    }
    if (!surface) return DefWindowProcW(window, message, value, data);
    const auto epoch = surface->renderer.LoadEpoch();
    switch (message) {
    case WM_APP + 0x42: if (epoch == value) FallbackSurface(*surface); return 0;
    case WM_APP + 0x38:
        if (epoch == value) {
            LogError("WebView2 目標程序故障或無回應；載入世代=" + std::to_string(epoch) + "; 類型=" + std::to_string(data));
            try {
                if (SUCCEEDED(surface->renderer.Recover())) surface->loadStarted = GetTickCount64(); else FallbackSurface(*surface);
            } catch (const std::exception& error) { LogError(error.what()); FallbackSurface(*surface); }
        } return 0;
    case WM_APP + 0x31:
        if (epoch == static_cast<unsigned long long>(data)) { LogError("WebView2 初始化失敗，代碼：" + std::to_string(value)); FallbackSurface(*surface); } return 0;
    case WM_APP + 0x36: if (epoch == static_cast<unsigned long long>(data)) surface->renderer.SetRuntimeState(gAppliedState); return 0;
    case WM_APP + 0x41:
        if (epoch == static_cast<unsigned long long>(data)) {
            gNotice = L"主題的 HTTP／HTTPS 外連已封鎖。如需連網，請前往設定開啟主題網路；目前仍維持封鎖。";
            UpdateManagement(); if (gManagement) gManagement->Show();
        } return 0;
    case WM_COMMAND: HandleCommand(LOWORD(value)); return 0;
    case WM_SIZE: surface->renderer.Resize(); return 0;
    case WM_DPICHANGED:
        if (gEffective.desktop) PostMessageW(gNotification, kReconcile, 0, 0);
        else {
            const auto rect = reinterpret_cast<RECT*>(data);
            SetWindowPos(window, nullptr, rect->left, rect->top, rect->right - rect->left, rect->bottom - rect->top, SWP_NOZORDER | SWP_NOACTIVATE);
            surface->renderer.Resize();
        } return 0;
    case WM_NCHITTEST: if (gEffective.desktop) return HTTRANSPARENT; break;
    case WM_CLOSE:
        if (gManaged) { if (!gPlayback.Paused()) HandleCommand(win::kManagePause); }
        else { gClosing = true; PostQuitMessage(0); } return 0;
    case WM_DESTROY:
        surface->renderer.Shutdown();
        surface->attached = false;
        if (!gClosing && !gChangingSurfaces) PostMessageW(gNotification, kReconcile, 0, 0);
        return 0;
    case WM_NCDESTROY: surface->window = nullptr; SetWindowLongPtrW(window, GWLP_USERDATA, 0); break;
    }
    return DefWindowProcW(window, message, value, data);
}

/** 從穩定 HWND 驅動拓樸、採樣、Shell 復原與管理。
 * Args:
 *     window: 不附掛 Explorer 的通知視窗。
 *     message: 原生訊息。
 *     value: 原生訊息參數。
 *     data: 原生訊息參數。
 * Returns:
 *     原生處理結果。
 */
LRESULT CALLBACK NotificationProcedure(HWND window, UINT message, WPARAM value, LPARAM data) {
    try {
        if (message == win::kTrayCallbackMessage && gManagement) { gManagement->OnTrayCallback(value, data); return 0; }
        if (message == WM_COMMAND) { HandleCommand(LOWORD(value)); return 0; }
        if (message == kSnapshotReady) {
            UiSnapshot reading;
            if (gMailbox.TryTake(&reading) && reading.generation == gSamplingGeneration) {
                gLatestSnapshot = reading.snapshot;
                for (auto& surface : gSurfaces) if (OwnsWindow(*surface)) surface->renderer.SetSnapshot(gLatestSnapshot);
                if (gPowerState.State() == runtime::PowerState::Active) gPowerState.MarkFullSnapshotDelivered();
            } return 0;
        }
        if (message == kSamplingFailed) { gNotice = L"系統指標採樣已停止，請查看日誌後重新啟動。"; UpdateManagement(); return 0; }
        if (message == gTaskbarCreated && gTaskbarCreated) {
            if (gManagement) gManagement->Tick(true);
            for (auto& surface : gSurfaces) { surface->attached = false; surface->retry.Reset(); }
        }
        if (message == WM_DISPLAYCHANGE || message == WM_DEVICECHANGE || message == kReconcile ||
            (message == gTaskbarCreated && gTaskbarCreated) || (message == WM_TIMER && value == kTick)) {
            RefreshMonitors();
            ReconcileSurfaces();
            if (gEffective.smartSleep && !gSurfaces.empty()) {
                gPowerState.ObserveObscured(win::PowerNotifications::ForegroundIsFullscreen(gSurfaces.front()->window), GetTickCount64(), 1000); ApplyRuntimePolicy();
            }
            for (auto& surface : gSurfaces) {
                surface->renderer.CheckResponsiveness();
                if (!surface->loadStarted) continue;
                if (surface->renderer.IsReady()) surface->loadStarted = 0;
                else if (gAppliedState != runtime::PowerState::Active) surface->loadStarted = GetTickCount64();
                else if (GetTickCount64() - surface->loadStarted >= 20000) FallbackSurface(*surface);
            }
            UpdateManagement(); if (gManagement) gManagement->Tick(); return 0;
        }
    } catch (const std::exception& error) { LogError(error.what()); gNotice = L"無法更新目標螢幕，請查看日誌並確認顯示配置。"; UpdateManagement(); }
    return DefWindowProcW(window, message, value, data);
}
} // namespace

/** 於友善錯誤邊界內建立及清理 Windows 目標。
 * Args:
 *     instance: Windows 應用程式實例。
 *     commandLine: 啟動選項。
 * Returns:
 *     正常退出為 0，初始化或執行失敗為非零。
 */
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR commandLine, int) {
    if (const auto result = app::RunThemeCommand()) return *result;
    if (HasFlag(commandLine, L"--version")) { RunVersion(); return 0; }
    if (HasFlag(commandLine, L"--diagnostics")) { RunDiagnostics(); return 0; }
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    bool comInitialized = false;
    int result = 1;
    try {
        const bool forcePreview = HasFlag(commandLine, L"--preview");
        gManaged = HasFlag(commandLine, L"--management") || (!forcePreview && !HasFlag(commandLine, L"--experimental-desktop"));
        gMockMetrics = HasFlag(commandLine, L"--mock-metrics");
        gStore = std::make_unique<app::SettingsStore>(app::ThemeStoreDirectory().parent_path() / L"settings.json");
        gSaved = gStore->Load();
        gEffective = gSaved;
        if (forcePreview || gMockMetrics) gEffective.desktop = false;
        if (HasFlag(commandLine, L"--experimental-desktop") && !forcePreview && !gMockMetrics) gEffective.desktop = true;
        ValidateDesktopSelection(gEffective, false);
        if (HasFlag(commandLine, L"--no-smart-sleep")) gEffective.smartSleep = false;
        if (HasFlag(commandLine, L"--theme=dashboard")) gEffective.theme = "dashboard";
        else if (HasFlag(commandLine, L"--theme=minimal")) gEffective.theme = "minimal";
        // 沿用原啟動選項的 UI 草稿語意；未明確保存時不寫回設定檔。
        gSaved = gEffective;
        gCurrentThemeKey = gEffective.theme; gCurrentTheme = NativeText(ResolveTheme(gCurrentThemeKey).name);
        if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) throw std::runtime_error("無法初始化 COM 主題引擎。");
        comInitialized = true;
        WNDCLASSW cls{}; cls.hInstance = instance; cls.lpfnWndProc = SurfaceProcedure;
        cls.hCursor = LoadCursorW(nullptr, IDC_ARROW); cls.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1); cls.lpszClassName = kWindowClass;
        if (!RegisterClassW(&cls)) throw std::runtime_error("無法註冊宿主視窗。");
        cls.lpfnWndProc = NotificationProcedure; cls.lpszClassName = kNotificationClass;
        if (!RegisterClassW(&cls)) throw std::runtime_error("無法註冊通知視窗。");
        gNotification = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, kNotificationClass, L"", WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, instance, nullptr);
        gTaskbarCreated = RegisterWindowMessageW(L"TaskbarCreated");
        if (!gNotification || !gTaskbarCreated) throw std::runtime_error("無法建立背景通知入口。");
        if (gManaged) {
            gManagement = std::make_unique<win::ManagementShell>();
            if (!gManagement->Initialize(gNotification, HandleCommand)) throw std::runtime_error("無法建立管理介面。");
            RefreshThemes(); UpdateMonitorList(); gManagement->SetPreferences(gSaved);
        } else RefreshThemes();
        RefreshMonitors();
        if (gMockMetrics) gLatestSnapshot = MakeMockSnapshot();
        ReconcileSurfaces();
        gWorker = std::make_unique<runtime::SamplingWorker>(
            [collector = std::shared_ptr<desktopmonitor::monitoring::WindowsMetricsCollector>()](bool reset) mutable {
                if (gMockMetrics) return MakeMockSnapshot();
                if (reset || !collector) collector = std::make_shared<desktopmonitor::monitoring::WindowsMetricsCollector>();
                desktopmonitor::core::MetricsSnapshot snapshot; collector->Collect(snapshot); return snapshot;
            },
            [](const auto& snapshot, unsigned long long generation) {
                if (gMailbox.Publish(UiSnapshot{snapshot, generation}) && !PostMessageW(gNotification, kSnapshotReady, 0, 0)) gMailbox.NotificationPostFailed();
            },
            [](std::exception_ptr error) { try { std::rethrow_exception(error); } catch (const std::exception& detail) { LogError(detail.what()); } PostMessageW(gNotification, kSamplingFailed, 0, 0); });
        gPower = std::make_unique<win::PowerNotifications>();
        if (!gPower->Initialize([](auto event) {
            switch (event) {
            case win::PowerEvent::Locked: gPowerState.SetLocked(true); break;
            case win::PowerEvent::Unlocked: gPowerState.SetLocked(false); break;
            case win::PowerEvent::DisplayOff: case win::PowerEvent::SystemSuspend: gPowerState.SetDisplayOff(true); break;
            case win::PowerEvent::DisplayOn: case win::PowerEvent::SystemResume: gPowerState.SetDisplayOff(false); break;
            } ApplyRuntimePolicy();
        })) { gEffective.smartSleep = false; LogError("無法註冊電源通知，智慧休眠已停用。"); gNotice = L"無法註冊電源通知，智慧休眠已停用。"; }
        gPolicyInitialized = false; ApplyRuntimePolicy();
        if (!SetTimer(gNotification, kTick, 1000, nullptr)) throw std::runtime_error("無法建立背景生命週期計時器。");
        UpdateManagement(); if (gManagement && HasFlag(commandLine, L"--management")) gManagement->Show();
        MSG message{}; BOOL received = 0;
        while ((received = GetMessageW(&message, nullptr, 0, 0)) > 0) {
            if (gManagement && gManagement->Translate(&message)) continue;
            TranslateMessage(&message); DispatchMessageW(&message);
        }
        result = received == -1 ? 1 : static_cast<int>(message.wParam);
    } catch (const app::SettingsValidationError& error) {
        LogError(error.what()); MessageBoxW(nullptr, NativeText(error.what()).c_str(), L"DrillPaper", MB_OK | MB_ICONWARNING);
    } catch (const std::exception& error) { LogError(error.what()); MessageBoxW(nullptr, L"無法初始化 DrillPaper，請查看日誌，並檢查設定檔、主題資產與顯示配置。原設定未被覆蓋。", L"DrillPaper", MB_OK | MB_ICONERROR); }
    gClosing = true;
    if (gWorker) { gWorker->Stop(); gWorker.reset(); }
    gPower.reset(); gManagement.reset();
    for (auto& surface : gSurfaces) DestroySurface(*surface);
    gSurfaces.clear(); if (gNotification) DestroyWindow(gNotification);
    if (comInitialized) CoUninitialize();
    return result;
}
