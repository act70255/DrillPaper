// 僅測試目標編譯此入口；產品不提供故障注入選項。
#define wWinMain DrillPaperProductMain
#include "../../src/app/main.cpp"
#undef wWinMain
#include <set>

namespace {
std::string testCase;
std::vector<win::MonitorInfo> baseline;
int phase = 0;
int reads = 0;
bool passed = false;
unsigned long long phaseStarted = 0;
unsigned long long metricsBefore = 0;
std::ofstream evidence;
std::vector<std::string> selected;

/** 尋找本次程序的原生視窗，不操作其他桌布。
 * Args:
 *     name: 公開視窗類別。
 * Returns:
 *     依 HWND 去重的本程序視窗。
 */
std::vector<HWND> FindWindows(const wchar_t* name) {
    struct Search { const wchar_t* name; std::set<HWND> windows; } search{name, {}};
    const auto collect = [](HWND window, LPARAM data) -> BOOL {
        auto& state = *reinterpret_cast<Search*>(data);
        DWORD process = 0; GetWindowThreadProcessId(window, &process);
        wchar_t cls[128]{}; GetClassNameW(window, cls, 128);
        if (process == GetCurrentProcessId() && std::wstring(cls) == state.name) state.windows.insert(window);
        return TRUE;
    };
    struct Walk { Search* search; WNDENUMPROC collect; } walk{&search, collect};
    EnumWindows([](HWND window, LPARAM data) -> BOOL {
        auto& state = *reinterpret_cast<Walk*>(data);
        state.collect(window, reinterpret_cast<LPARAM>(state.search));
        EnumChildWindows(window, state.collect, reinterpret_cast<LPARAM>(state.search));
        return TRUE;
    }, reinterpret_cast<LPARAM>(&walk));
    return {search.windows.begin(), search.windows.end()};
}

/** 讀取管理介面的公開狀態文字。
 * Returns:
 *     目前狀態，尚未建立時為空。
 */
std::wstring StatusText() {
    const auto windows = FindWindows(L"DrillPaperManagementWindow");
    if (windows.empty()) return {};
    wchar_t text[4096]{}; GetWindowTextW(GetDlgItem(windows.front(), 20100), text, 4096);
    return text;
}

/** 結束本次測試，保留原始觀測並走產品正式退出命令。
 * Args:
 *     success: 是否通過全部斷言。
 *     reason: 繁體中文結果。
 */
void Finish(bool success, const char* reason) {
    passed = success;
    evidence << (success ? "PASS " : "FAIL ") << reason << "，列舉次數=" << reads << '\n'; evidence.flush();
    const auto notifications = FindWindows(L"DrillPaperShellNotifications");
    if (!notifications.empty()) SendMessageW(notifications.front(), WM_COMMAND, win::kManageExit, 0);
    else PostQuitMessage(1);
}

/** 在公開 HWND／設定 seam 觀測握手、幾何、提示及恢復，不讀取 app 私有狀態。
 * Args:
 *     timer: 本 fixture 計時器識別。
 */
void CALLBACK Observe(HWND, UINT, UINT_PTR timer, DWORD) {
    try {
        if (GetTickCount64() - phaseStarted > 35000) { KillTimer(nullptr, timer); Finish(false, "原期限內未達目標數量／握手／恢復"); return; }
        const auto surfaces = FindWindows(L"DrillPaperPreviewWindow");
        const auto status = StatusText();
        std::set<std::string> areas;
        for (const auto& monitor : baseline) areas.insert(monitor.target.area);
        const bool preview = testCase == "preview";
        const std::size_t expected = preview || testCase == "initial-failure" || phase == 2 ? 1 : areas.size();
        if (surfaces.size() != expected) return;
        for (const auto window : surfaces) {
            if (!GetPropW(window, L"DrillPaper.ReadyEpoch") || !GetPropW(window, L"DrillPaper.MetricsTick")) return;
            if (!preview && !GetPropW(window, L"DrillPaper.DesktopEpoch")) return;
        }
        if (GetTickCount64() - phaseStarted < 2200) return;
        const auto settings = app::SettingsStore(app::ThemeStoreDirectory().parent_path() / L"settings.json").Load();
        if (!preview && settings.monitorTargets.value_or(std::vector<std::string>{}) != selected)
            throw std::runtime_error("暫時退化改寫保存目標。");
        if (preview) {
            if (reads != 0) throw std::runtime_error("獨立 Preview 仍依賴螢幕列舉。");
            KillTimer(nullptr, timer); Finish(true, "Preview 完成握手及指標更新，未呼叫故障列舉器"); return;
        }
        if (phase == 0) {
            if (status.find(L"有螢幕無法辨識，暫時套用到所有螢幕") == std::wstring::npos) return;
            if (testCase == "initial-failure" && status.find(L"暫用主螢幕") == std::wstring::npos) return;
            for (const auto window : surfaces) {
                RECT rect{}; GetWindowRect(window, &rect);
                const auto dpi = reinterpret_cast<ULONG_PTR>(GetPropW(window, L"DrillPaper.TargetDpi"));
                if (std::none_of(baseline.begin(), baseline.end(), [&](const auto& m) { return EqualRect(&m.bounds, &rect) && m.dpi == dpi; }))
                    throw std::runtime_error("退化宿主矩形或逐屏 DPI 與原生 oracle 不符。");
                evidence << "宿主=" << window << "，矩形=" << rect.left << ',' << rect.top << ',' << rect.right << ',' << rect.bottom << "，DPI=" << dpi << '\n';
            }
            metricsBefore = GetTickCount64();
            phase = testCase == "initial-failure" ? 2 : 1;
        } else if (phase == 1) {
            if (status.find(L"保留上次成功結果") == std::wstring::npos) return;
            for (const auto window : surfaces)
                if (reinterpret_cast<ULONG_PTR>(GetPropW(window, L"DrillPaper.MetricsTick")) <= metricsBefore) return;
            phase = 2;
        } else {
            if (status.find(L"無法辨識") != std::wstring::npos || status.find(L"列舉暫時失敗") != std::wstring::npos) return;
            const auto notification = FindWindows(L"DrillPaperShellNotifications").front();
            SendMessageW(notification, WM_COMMAND, win::kManageApply, 0);
            const auto saved = app::SettingsStore(app::ThemeStoreDirectory().parent_path() / L"settings.json").Load();
            const auto primary = std::find_if(baseline.begin(), baseline.end(), [](const auto& m) { return m.target.primary; });
            const auto expectedSaved = selected.empty() ? std::vector<std::string>{primary->target.id} : selected;
            if (saved.monitorTargets != expectedSaved) throw std::runtime_error("恢復後保存目標不是原選擇或首次主螢幕。");
            KillTimer(nullptr, timer); Finish(true, "退化／列舉失敗快取／指標持續更新／恢復與保存通過"); return;
        }
        evidence << "進入階段=" << phase << "，列舉次數=" << reads << '\n'; evidence.flush();
        phaseStarted = GetTickCount64();
    } catch (const std::exception& error) { KillTimer(nullptr, timer); Finish(false, error.what()); }
}
}

/** 注入 Windows 列舉邊界後執行相同產品入口；只用於隔離實機測試。
 * Args:
 *     instance: Windows 實例。
 * Returns:
 *     全部公開行為通過為 0，其他為 1。
 */
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    try {
        wchar_t scenario[64]{};
        const auto size = GetEnvironmentVariableW(L"DRILLPAPER_MONITOR_CASE", scenario, 64);
        if (!size || size >= 64) throw std::runtime_error("測試情境設定缺失或過長。");
        if (std::wstring(scenario) == L"preview") testCase = "preview";
        else if (std::wstring(scenario) == L"initial-failure") testCase = "initial-failure";
        else if (std::wstring(scenario) == L"degrade") testCase = "degrade";
        else throw std::runtime_error("測試情境設定不在允許清單內。");
        const auto previous = SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        baseline = win::EnumerateMonitors();
        if (previous) SetThreadDpiAwarenessContext(previous);
        if (baseline.empty()) throw std::runtime_error("缺少原生顯示器 oracle。");
        const auto directory = app::ThemeStoreDirectory().parent_path();
        std::filesystem::create_directories(directory);
        evidence.open(directory / L"rc12-fixture.log", std::ios::binary);
        if (!evidence) throw std::runtime_error("無法建立測試證據。");
        if (testCase == "degrade") {
            const auto primary = std::find_if(baseline.begin(), baseline.end(), [](const auto& m) { return m.target.primary; });
            selected = {primary->target.id};
            app::AppSettings settings; settings.monitorTargets = selected; settings.smartSleep = false;
            app::SettingsStore(directory / L"settings.json").Save(settings);
        }
        gMonitorInventory = win::MonitorInventory([] {
            ++reads;
            if (testCase == "preview" || (testCase == "initial-failure" && phase == 0) || phase == 1)
                throw std::runtime_error("fixture QueryDisplayConfig 失敗，Windows 代碼：31");
            auto monitors = baseline;
            if (testCase == "degrade" && phase == 0) {
                monitors.back().target.id.clear(); monitors.back().name = L"無法辨識";
                monitors.back().identificationError = "fixture 裝置識別不可用。";
            }
            return monitors;
        });
        phaseStarted = GetTickCount64();
        const auto timer = SetTimer(nullptr, 0, 200, Observe);
        if (!timer) throw std::runtime_error("無法建立觀測計時器。");
        wchar_t preview[] = L"--preview --no-smart-sleep";
        wchar_t desktop[] = L"--management --no-smart-sleep";
        const auto result = DrillPaperProductMain(instance, nullptr, testCase == "preview" ? preview : desktop, SW_HIDE);
        KillTimer(nullptr, timer);
        return passed && result == 0 ? 0 : 1;
    } catch (const std::exception& error) { OutputDebugStringA(error.what()); return 1; }
}
