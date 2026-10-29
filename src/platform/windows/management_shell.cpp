#include "desktopmonitor/platform/windows/management_shell.h"
#include <windowsx.h>
#include <algorithm>
#include <array>
#include <commdlg.h>
#include <stdexcept>
#include <commctrl.h>

namespace desktopmonitor::platform::windows {
namespace {
constexpr wchar_t kClass[] = L"DrillPaperManagementWindow";
constexpr UINT kStatus = 20100;
constexpr UINT kThemeList = 20101;
constexpr UINT kModeList = 20102;
constexpr UINT kSmartSleep = 20103;
struct Control { UINT id; const wchar_t* cls; const wchar_t* label; int x; int y; int width; int height; DWORD style; };
constexpr std::array<Control, 20> kControls{{
    {kStatus, L"STATIC", L"正在初始化…", 20, 12, 560, 92, SS_LEFT},
    {kManagePause, L"BUTTON", L"暫停桌布", 20, 112, 180, 32, BS_PUSHBUTTON},
    {kManageDesktop, L"BUTTON", L"桌布模式", 210, 112, 180, 32, BS_PUSHBUTTON},
    {kManagePreview, L"BUTTON", L"預覽模式", 400, 112, 180, 32, BS_PUSHBUTTON},
    {20104, L"STATIC", L"主題（名稱／版本）：", 20, 152, 560, 24, SS_LEFT},
    {kThemeList, L"LISTBOX", L"", 20, 176, 560, 56, LBS_NOTIFY | WS_BORDER | WS_VSCROLL},
    {kManageThemePreview, L"BUTTON", L"預覽所選主題", 20, 240, 180, 32, BS_PUSHBUTTON},
    {kManageThemeApply, L"BUTTON", L"套用為桌布", 210, 240, 180, 32, BS_PUSHBUTTON},
    {kManageImport, L"BUTTON", L"匯入 .dmt…", 400, 240, 180, 32, BS_PUSHBUTTON},
    {kManageRemove, L"BUTTON", L"移除所選主題…", 20, 280, 180, 32, BS_PUSHBUTTON},
    {kManageRefresh, L"BUTTON", L"重新整理主題", 210, 280, 180, 32, BS_PUSHBUTTON},
    {kManageLogs, L"BUTTON", L"開啟日誌", 400, 280, 180, 32, BS_PUSHBUTTON},
    {20105, L"STATIC", L"保存的顯示模式：", 20, 324, 150, 26, SS_LEFT},
    {kModeList, L"COMBOBOX", L"", 190, 320, 200, 120, CBS_DROPDOWNLIST | WS_VSCROLL},
    {kSmartSleep, L"BUTTON", L"啟用智慧休眠（全螢幕／鎖定／顯示器關閉）", 20, 360, 560, 28, BS_AUTOCHECKBOX},
    {20106, L"BUTTON", L"允許主題連網（HTTP／HTTPS，所有網域）", 20, 392, 560, 24, BS_AUTOCHECKBOX},
    {20107, L"STATIC", L"套用螢幕（可勾選多個；桌布至少一個）：", 20, 426, 560, 24, SS_LEFT},
    {20108, WC_LISTVIEWW, L"", 20, 452, 560, 80, LVS_REPORT | LVS_NOCOLUMNHEADER | LVS_SINGLESEL | WS_BORDER},
    {kManageApply, L"BUTTON", L"套用並儲存設定", 20, 548, 180, 32, BS_PUSHBUTTON},
    {kManageCancel, L"BUTTON", L"取消設定變更", 210, 548, 180, 32, BS_PUSHBUTTON}
}};
}

ManagementShell::~ManagementShell() { Shutdown(); }

bool ManagementShell::Initialize(HWND owner, std::function<void(UINT)> command) {
    INITCOMMONCONTROLSEX controls{sizeof(controls), ICC_LISTVIEW_CLASSES};
    if (!InitCommonControlsEx(&controls)) return false;
    owner_ = owner;
    command_ = std::move(command);
    WNDCLASSW cls{};
    cls.hInstance = GetModuleHandleW(nullptr);
    cls.lpfnWndProc = Procedure;
    cls.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    cls.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    cls.lpszClassName = kClass;
    if (RegisterClassW(&cls) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return false;
    const auto dpi = GetDpiForSystem();
    RECT bounds{0, 0, MulDiv(600, dpi, 96), MulDiv(600, dpi, 96)};
    AdjustWindowRectExForDpi(&bounds, WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX, FALSE, WS_EX_APPWINDOW, dpi);
    window_ = CreateWindowExW(WS_EX_APPWINDOW, kClass, L"DrillPaper 管理",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
        CW_USEDEFAULT, CW_USEDEFAULT, bounds.right - bounds.left, bounds.bottom - bounds.top,
        nullptr, nullptr, cls.hInstance, this);
    if (!window_) return false;
    icon_ = CreateTrayIcon();
    if (!icon_) { Shutdown(); return false; }
    SendMessageW(window_, WM_SETICON, ICON_SMALL, reinterpret_cast<LPARAM>(icon_));
    SendMessageW(window_, WM_SETICON, ICON_BIG, reinterpret_cast<LPARAM>(icon_));
    Tick();
    return true;
}

HICON ManagementShell::CreateTrayIcon() {
    const int size = GetSystemMetricsForDpi(SM_CXSMICON, GetDpiForWindow(window_));
    HDC dc = CreateCompatibleDC(nullptr);
    if (!dc) return nullptr;
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = size;
    info.bmiHeader.biHeight = -size;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    void* bits = nullptr;
    HBITMAP color = CreateDIBSection(dc, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
    HBITMAP mask = CreateBitmap(size, size, 1, 1, nullptr);
    HICON result = nullptr;
    if (color && mask && bits) {
        auto old = SelectObject(dc, color);
        RECT rect{0, 0, size, size};
        HBRUSH background = CreateSolidBrush(RGB(20, 35, 48));
        FillRect(dc, &rect, background);
        DeleteObject(background);
        HBRUSH accent = CreateSolidBrush(RGB(66, 210, 170));
        for (int bar = 0; bar < 3; ++bar) {
            RECT column{size * (3 + bar * 4) / 16, size * (10 - bar * 3) / 16,
                        size * (6 + bar * 4) / 16, size * 13 / 16};
            FillRect(dc, &column, accent);
        }
        DeleteObject(accent);
        auto pixels = static_cast<DWORD*>(bits);
        for (int index = 0; index < size * size; ++index) pixels[index] |= 0xff000000;
        SelectObject(dc, mask);
        PatBlt(dc, 0, 0, size, size, BLACKNESS);
        SelectObject(dc, old);
        ICONINFO iconInfo{TRUE, 0, 0, mask, color};
        result = CreateIconIndirect(&iconInfo);
    }
    if (color) DeleteObject(color);
    if (mask) DeleteObject(mask);
    DeleteDC(dc);
    return result;
}

void ManagementShell::Show() {
    if (!window_) return;
    ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
    SetForegroundWindow(window_);
}

void ManagementShell::Update(const std::wstring& theme, const std::wstring& status, bool paused, bool desktop) {
    theme_ = theme;
    status_ = status;
    paused_ = paused;
    desktop_ = desktop;
    if (!window_) return;
    std::wstring text = L"目前主題：" + theme_ + L"\r\n顯示模式：" +
        (desktop_ ? L"桌布" : L"預覽") + L"\r\n" + status_;
    if (!present_) text += L"\r\n系統匣尚未就緒，可由此視窗繼續操作。";
    SetDlgItemTextW(window_, kStatus, text.c_str());
    SetDlgItemTextW(window_, kManagePause, paused_ ? L"繼續桌布" : L"暫停桌布");
    EnableWindow(GetDlgItem(window_, kManageDesktop), !desktop_);
    EnableWindow(GetDlgItem(window_, kManagePreview), desktop_);
}

void ManagementShell::Tick(bool shellRestarted) {
    if (!owner_ || !icon_) return;
    if (shellRestarted) {
        present_ = false;
        retry_.Reset();
        RemovePropW(owner_, L"DrillPaper.TrayRegistered");
    }
    NOTIFYICONDATAW data{};
    data.cbSize = sizeof(data);
    data.hWnd = owner_;
    data.uID = 1;
    data.uCallbackMessage = kTrayCallbackMessage;
    data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP;
    data.hIcon = icon_;
    const auto tip = (L"DrillPaper · " + theme_ + L" · " + status_).substr(0, 127);
    wcsncpy_s(data.szTip, tip.c_str(), _TRUNCATE);
    if (!present_) {
        if (!retry_.CanAttempt(GetTickCount64())) return;
        // 相同 owner 與 ID 先移除，連續 TaskbarCreated 也不建立重複入口。
        Shell_NotifyIconW(NIM_DELETE, &data);
        if (Shell_NotifyIconW(NIM_ADD, &data)) {
            present_ = true;
            retry_.Reset();
            data.uVersion = NOTIFYICON_VERSION_4;
            version4_ = Shell_NotifyIconW(NIM_SETVERSION, &data) != FALSE;
            SetPropW(owner_, L"DrillPaper.TrayRegistered", reinterpret_cast<HANDLE>(1));
            lastTip_ = tip;
            Update(theme_, status_, paused_, desktop_);
        } else {
            retry_.RecordFailure(GetTickCount64());
            OutputDebugStringW(L"無法加入系統匣圖示，保留管理視窗並有界重試。\n");
            Update(theme_, status_, paused_, desktop_);
            // 保留可見入口；後續重試不持續搶焦點。
            if (!IsWindowVisible(window_)) ShowWindow(window_, SW_SHOWNOACTIVATE);
        }
    } else if (lastTip_ != tip) {
        if (Shell_NotifyIconW(NIM_MODIFY, &data)) lastTip_ = tip;
    }
}

void ManagementShell::OnTrayCallback(WPARAM, LPARAM data) {
    if (version4_ && HIWORD(data) != 1) return;
    const auto event = version4_ ? LOWORD(data) : static_cast<UINT>(data);
    if (event == WM_LBUTTONUP || event == WM_LBUTTONDBLCLK || event == NIN_SELECT || event == NIN_KEYSELECT) Show();
    else if (event == WM_CONTEXTMENU || event == WM_RBUTTONUP) ShowMenu();
}

void ManagementShell::ShowMenu() {
    HMENU menu = CreatePopupMenu();
    if (!menu) return;
    AppendMenuW(menu, MF_STRING, kManageOpen, L"開啟管理介面");
    AppendMenuW(menu, MF_STRING, kManagePause, paused_ ? L"繼續桌布" : L"暫停桌布");
    AppendMenuW(menu, MF_STRING | (desktop_ ? MF_CHECKED : 0), kManageDesktop, L"桌布模式");
    AppendMenuW(menu, MF_STRING | (!desktop_ ? MF_CHECKED : 0), kManagePreview, L"預覽模式");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, 10001, L"主題：Minimal");
    AppendMenuW(menu, MF_STRING, 10002, L"主題：Dashboard");
    for (std::size_t index = 2; index < themes_.size(); ++index)
        AppendMenuW(menu, MF_STRING, 11000 + index - 2, themes_[index].label.c_str());
    AppendMenuW(menu, MF_STRING, kManageOpen, L"設定…");
    AppendMenuW(menu, MF_STRING, kManageLogs, L"開啟日誌資料夾");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, kManageExit, L"結束 DrillPaper");
    POINT cursor{};
    GetCursorPos(&cursor);
    SetForegroundWindow(owner_);
    const auto command = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
        cursor.x, cursor.y, 0, owner_, nullptr);
    DestroyMenu(menu);
    PostMessageW(owner_, WM_NULL, 0, 0);
    if (command == kManageOpen) Show();
    else if (command && command_) command_(command);
    NOTIFYICONDATAW data{};
    data.cbSize = sizeof(data);
    data.hWnd = owner_;
    data.uID = 1;
    Shell_NotifyIconW(NIM_SETFOCUS, &data);
}

void ManagementShell::Layout() {
    if (!window_) return;
    const auto dpi = GetDpiForWindow(window_);
    if (font_) DeleteObject(font_);
    font_ = CreateFontW(-MulDiv(10, dpi, 72), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Segoe UI");
    const auto scale = [dpi](int value) { return MulDiv(value, dpi, 96); };
    RECT client{};
    GetClientRect(window_, &client);
    const int width = MulDiv(client.right, 96, dpi);
    for (const auto& item : kControls) {
        const HWND control = GetDlgItem(window_, item.id);
        SendMessageW(control, WM_SETFONT, reinterpret_cast<WPARAM>(font_), TRUE);
        const bool column = item.width == 180;
        const int x = column ? 20 + (item.x - 20) / 190 * ((width - 40) / 3) : item.x;
        const int itemWidth = column ? (width - 52) / 3 : item.width == 560 ? width - 40 : item.width;
        MoveWindow(control, scale(x), scale(item.y), scale(itemWidth), scale(item.height), TRUE);
    }
    const HWND exit = GetDlgItem(window_, kManageExit);
    SendMessageW(exit, WM_SETFONT, reinterpret_cast<WPARAM>(font_), TRUE);
    MoveWindow(exit, scale(20 + 2 * ((width - 40) / 3)), scale(548), scale((width - 52) / 3), scale(32), TRUE);
    ListView_SetColumnWidth(GetDlgItem(window_, 20108), 0, scale(width - 64));
}

LRESULT CALLBACK ManagementShell::Procedure(HWND window, UINT message, WPARAM value, LPARAM data) {
    auto self = reinterpret_cast<ManagementShell*>(GetWindowLongPtrW(window, GWLP_USERDATA));
    if (message == WM_NCCREATE) {
        self = static_cast<ManagementShell*>(reinterpret_cast<CREATESTRUCTW*>(data)->lpCreateParams);
        self->window_ = window;
        SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    }
    if (!self) return DefWindowProcW(window, message, value, data);
    switch (message) {
    case WM_CREATE: {
        for (const auto& item : kControls) {
            if (!CreateWindowExW(0, item.cls, item.label, WS_CHILD | WS_VISIBLE | item.style |
                (std::wstring(item.cls) == L"STATIC" ? 0 : WS_TABSTOP), 0, 0, 0, 0, window,
                reinterpret_cast<HMENU>(static_cast<UINT_PTR>(item.id)), GetModuleHandleW(nullptr), nullptr)) return -1;
        }
        SendDlgItemMessageW(window, kModeList, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"桌布"));
        SendDlgItemMessageW(window, kModeList, CB_ADDSTRING, 0, reinterpret_cast<LPARAM>(L"預覽"));
        const auto monitors = GetDlgItem(window, 20108);
        ListView_SetExtendedListViewStyle(monitors, LVS_EX_CHECKBOXES | LVS_EX_FULLROWSELECT | LVS_EX_DOUBLEBUFFER);
        LVCOLUMNW column{}; column.mask = LVCF_WIDTH; column.cx = 540;
        ListView_InsertColumn(monitors, 0, &column);
        if (!CreateWindowExW(0, L"BUTTON", L"結束 DrillPaper", WS_CHILD | WS_VISIBLE | WS_TABSTOP,
            0, 0, 0, 0, window, reinterpret_cast<HMENU>(static_cast<UINT_PTR>(kManageExit)), GetModuleHandleW(nullptr), nullptr)) return -1;
        self->Layout();
        return 0;
    }
    case WM_SIZE: self->Layout(); return 0;
    case WM_DPICHANGED: {
        const auto rect = reinterpret_cast<RECT*>(data);
        SetWindowPos(window, nullptr, rect->left, rect->top, rect->right - rect->left, rect->bottom - rect->top,
            SWP_NOZORDER | SWP_NOACTIVATE);
        self->Layout();
        return 0;
    }
    case WM_COMMAND:
        if (LOWORD(value) == kThemeList) {
            const auto selected = SendDlgItemMessageW(window, kThemeList, LB_GETCURSEL, 0, 0);
            const bool removable = selected >= 0 && static_cast<std::size_t>(selected) < self->themes_.size() && !self->themes_[selected].builtin;
            EnableWindow(GetDlgItem(window, kManageRemove), removable);
        } else if (self->command_) self->command_(LOWORD(value));
        return 0;
    case WM_CLOSE:
        if (self->present_) ShowWindow(window, SW_HIDE);
        else self->Update(self->theme_, self->status_, self->paused_, self->desktop_);
        return 0;
    case WM_NCDESTROY:
        self->window_ = nullptr;
        SetWindowLongPtrW(window, GWLP_USERDATA, 0);
        break;
    }
    return DefWindowProcW(window, message, value, data);
}

void ManagementShell::SetThemes(std::vector<ManagementTheme> themes) {
    const auto selected = Preferences().theme;
    themes_ = std::move(themes);
    SendDlgItemMessageW(window_, kThemeList, LB_RESETCONTENT, 0, 0);
    for (std::size_t index = 0; index < themes_.size(); ++index) {
        SendDlgItemMessageW(window_, kThemeList, LB_ADDSTRING, 0, reinterpret_cast<LPARAM>(themes_[index].label.c_str()));
        if (themes_[index].key == selected) SendDlgItemMessageW(window_, kThemeList, LB_SETCURSEL, index, 0);
    }
    if (SendDlgItemMessageW(window_, kThemeList, LB_GETCURSEL, 0, 0) == LB_ERR)
        SendDlgItemMessageW(window_, kThemeList, LB_SETCURSEL, 0, 0);
    SendMessageW(window_, WM_COMMAND, MAKEWPARAM(kThemeList, LBN_SELCHANGE), 0);
}

void ManagementShell::SetPreferences(const app::AppSettings& settings) {
    preferences_ = settings;
    for (std::size_t index = 0; index < monitors_.size(); ++index)
        ListView_SetCheckState(GetDlgItem(window_, 20108), static_cast<int>(index), settings.monitorTargets &&
            std::find(settings.monitorTargets->begin(), settings.monitorTargets->end(), monitors_[index].id) != settings.monitorTargets->end());
    for (std::size_t index = 0; index < themes_.size(); ++index)
        if (themes_[index].key == settings.theme) SendDlgItemMessageW(window_, kThemeList, LB_SETCURSEL, index, 0);
    SendDlgItemMessageW(window_, kModeList, CB_SETCURSEL, settings.desktop ? 0 : 1, 0);
    SendDlgItemMessageW(window_, kSmartSleep, BM_SETCHECK, settings.smartSleep ? BST_CHECKED : BST_UNCHECKED, 0);
    SendDlgItemMessageW(window_, 20106, BM_SETCHECK, settings.allowNetwork ? BST_CHECKED : BST_UNCHECKED, 0);
    SendMessageW(window_, WM_COMMAND, MAKEWPARAM(kThemeList, LBN_SELCHANGE), 0);
}

app::AppSettings ManagementShell::Preferences() const {
    auto result = preferences_;
    result.monitorTargets = std::vector<std::string>{};
    for (std::size_t index = 0; index < monitors_.size(); ++index)
        if (ListView_GetCheckState(GetDlgItem(window_, 20108), static_cast<int>(index)))
            result.monitorTargets->push_back(monitors_[index].id);
    const auto selected = SendDlgItemMessageW(window_, kThemeList, LB_GETCURSEL, 0, 0);
    if (selected >= 0 && static_cast<std::size_t>(selected) < themes_.size()) result.theme = themes_[selected].key;
    result.desktop = SendDlgItemMessageW(window_, kModeList, CB_GETCURSEL, 0, 0) == 0;
    result.smartSleep = SendDlgItemMessageW(window_, kSmartSleep, BM_GETCHECK, 0, 0) == BST_CHECKED;
    result.allowNetwork = SendDlgItemMessageW(window_, 20106, BM_GETCHECK, 0, 0) == BST_CHECKED;
    return result;
}

void ManagementShell::SetMonitors(std::vector<ManagementMonitor> monitors) {
    const auto draft = monitors_.empty() ? preferences_ : Preferences();
    // 拔線或尚未套用的離線選擇仍保留在草稿清單。
    if (draft.monitorTargets) for (const auto& id : *draft.monitorTargets)
        if (std::none_of(monitors.begin(), monitors.end(), [&](const auto& item) { return item.id == id; })) {
            const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, id.data(), static_cast<int>(id.size()), nullptr, 0);
            std::wstring label(length > 0 ? length : 0, L'\0');
            if (length > 0) MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, id.data(), static_cast<int>(id.size()), label.data(), length);
            monitors.push_back({id, label + L"（未連接）"});
        }
    monitors_ = std::move(monitors);
    const auto list = GetDlgItem(window_, 20108);
    ListView_DeleteAllItems(list);
    for (std::size_t index = 0; index < monitors_.size(); ++index) {
        LVITEMW item{}; item.mask = LVIF_TEXT; item.iItem = static_cast<int>(index); item.pszText = monitors_[index].label.data();
        ListView_InsertItem(list, &item);
        ListView_SetCheckState(list, static_cast<int>(index), draft.monitorTargets &&
            std::find(draft.monitorTargets->begin(), draft.monitorTargets->end(), monitors_[index].id) != draft.monitorTargets->end());
    }
}

std::filesystem::path ManagementShell::PickPackage() const {
    std::array<wchar_t, 32768> path{};
    OPENFILENAMEW dialog{};
    dialog.lStructSize = sizeof(dialog);
    dialog.hwndOwner = window_;
    dialog.lpstrFilter = L"DrillPaper 主題 (*.dmt)\0*.dmt\0\0";
    dialog.lpstrFile = path.data();
    dialog.nMaxFile = static_cast<DWORD>(path.size());
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
    if (GetOpenFileNameW(&dialog)) return path.data();
    if (CommDlgExtendedError() != 0) throw std::runtime_error("無法開啟主題檔案選擇器。");
    return {};
}

bool ManagementShell::ConfirmRemoval() const {
    return MessageBoxW(window_, L"確定要移除所選的使用者主題版本？使用中的主題會先切換至 Minimal。",
        L"移除主題", MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2) == IDYES;
}

bool ManagementShell::Translate(MSG* message) {
    return message && window_ && (message->hwnd == window_ || IsChild(window_, message->hwnd)) &&
        IsDialogMessageW(window_, message) != FALSE;
}

void ManagementShell::Shutdown() {
    if (owner_) {
        NOTIFYICONDATAW data{};
        data.cbSize = sizeof(data);
        data.hWnd = owner_;
        data.uID = 1;
        Shell_NotifyIconW(NIM_DELETE, &data);
        RemovePropW(owner_, L"DrillPaper.TrayRegistered");
    }
    owner_ = nullptr;
    present_ = false;
    if (window_) DestroyWindow(window_);
    if (font_) { DeleteObject(font_); font_ = nullptr; }
    if (icon_) { DestroyIcon(icon_); icon_ = nullptr; }
}

} // namespace desktopmonitor::platform::windows
