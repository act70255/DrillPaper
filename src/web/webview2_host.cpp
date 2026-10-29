#include "desktopmonitor/web/webview2_host.h"

#include <windows.h>
#include <wrl.h>

#include <algorithm>
#include <filesystem>
#include <iterator>
#include <string>
#include <string_view>
#include <vector>
#include <fstream>
#include <shlwapi.h>

#include "desktopmonitor/web/protocol_v1.h"

namespace desktopmonitor::web {
namespace {
using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

constexpr UINT kWebViewFailureMessage = WM_APP + 0x31;
constexpr UINT kRuntimeStateRefreshMessage = WM_APP + 0x36;
constexpr UINT kRendererFailedMessage = WM_APP + 0x38;
constexpr UINT kNetworkBlockedMessage = WM_APP + 0x41;
constexpr std::size_t kMaximumHistory = 120;
constexpr unsigned __int64 kWindowsToUnixEpoch100ns = 116444736000000000ULL;

/** 將已確認的 runtime 狀態轉成協定名稱。
 * Args:
 *     state: 電源狀態。
 * Returns:
 *     穩定的協定狀態名稱。
 */
const char* StateName(runtime::PowerState state) {
    switch (state) {
    case runtime::PowerState::Active: return "active";
    case runtime::PowerState::Obscured: return "obscured";
    case runtime::PowerState::Locked: return "locked";
    case runtime::PowerState::DisplayOff: return "display-off";
    case runtime::PowerState::Recovering: return "recovering";
    }
    return "recovering";
}

unsigned __int64 CurrentUnixTimeMilliseconds() {
    FILETIME fileTime{};
    GetSystemTimeAsFileTime(&fileTime);
    ULARGE_INTEGER ticks{};
    ticks.LowPart = fileTime.dwLowDateTime;
    ticks.HighPart = fileTime.dwHighDateTime;
    if (ticks.QuadPart < kWindowsToUnixEpoch100ns) {
        return 0;
    }
    return (ticks.QuadPart - kWindowsToUnixEpoch100ns) / 10000ULL;
}

/** 確認 URI 屬於目前主題的完整來源。
 * Args:
 *     url: 待檢查的 URI。
 *     origin: 含結尾斜線的允許來源。
 * Returns:
 *     來源符合時為 true。
 */
bool IsLocalThemeUrl(PCWSTR url, const std::wstring& origin) {
    if (url == nullptr || origin.empty()) {
        return false;
    }
    return _wcsnicmp(url, origin.c_str(), origin.size()) == 0;
}

/** 只將保留 DNS 主機視為主題來源，不以路徑或查詢文字判斷。
 * Args:
 *     uri: WebView2 已正規化的 HTTP／HTTPS URI。
 * Returns:
 *     authority 中的主機屬於保留命名空間時為 true。
 */
bool IsReservedThemeHost(std::wstring_view uri) {
    const auto scheme = uri.find(L"://");
    if (scheme == std::wstring_view::npos) return false;
    auto authority = uri.substr(scheme + 3);
    authority = authority.substr(0, authority.find_first_of(L"/?#"));
    const auto credentials = authority.rfind(L'@');
    if (credentials != std::wstring_view::npos) authority.remove_prefix(credentials + 1);
    // IPv6 的 authority 以左括號開頭，不會屬於此 DNS 命名空間。
    if (authority.starts_with(L"[")) return false;
    authority = authority.substr(0, authority.find(L':'));
    if (authority.ends_with(L".")) authority.remove_suffix(1);
    for (const std::wstring_view suffix : {L".drillpaper.local", L".invalid"}) {
        if (authority.size() >= suffix.size() &&
            _wcsnicmp(authority.data() + authority.size() - suffix.size(), suffix.data(), suffix.size()) == 0)
            return true;
    }
    return false;
}

/** 建立由宿主強制的 CSP，禁止框架、worker、物件與非 HTTP 通訊。
 * Args:
 *     enabled: 是否允許 HTTP／HTTPS 資源。
 *     origin: 目前主題的獨立 HTTPS 來源。
 * Returns:
 *     完整回應標頭。
 */
std::wstring SecurityHeaders(bool enabled, const std::wstring& origin) {
    const std::wstring remote = enabled ? L" http: https:" : L"";
    return L"Content-Security-Policy: default-src 'none'; script-src 'self' 'unsafe-inline'" + remote +
        L"; style-src 'self' 'unsafe-inline'" + remote + L"; img-src 'self'" + remote +
        L"; font-src 'self'" + remote + L"; media-src 'self'" + remote +
        L"; connect-src " + (enabled ? std::wstring(L"http: https:") : origin) +
        L"; frame-src 'none'; child-src 'none'; worker-src 'none'; object-src 'none'; "
        L"base-uri 'none'; form-action 'none'; frame-ancestors 'none';\r\n"
        L"X-Content-Type-Options: nosniff\r\nCache-Control: no-store\r\n"
        L"X-DNS-Prefetch-Control: off\r\nReferrer-Policy: no-referrer\r\n"
        L"Permissions-Policy: camera=(), microphone=(), geolocation=(), usb=(), serial=(), hid=()\r\n";
}

/** 解析主題內相對 URL，只允許一般檔案且拒絕重新解析點。
 * Args:
 *     relative: 不含來源的 URL 路徑。
 *     root: 已驗證資產目錄。
 * Returns:
 *     安全的一般檔案位置；不合法時拋出例外。
 */
std::filesystem::path ThemeAssetPath(std::wstring relative, const std::wstring& root) {
    relative = relative.substr(0, relative.find_first_of(L"?#"));
    // URL 使用 UTF-8 百分比編碼；禁止再次解碼，以免雙重編碼穿越。
    std::string encoded;
    const int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, relative.data(),
        static_cast<int>(relative.size()), nullptr, 0, nullptr, nullptr);
    if (length <= 0) throw std::runtime_error("主題資產路徑不合法。");
    encoded.resize(length);
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, relative.data(), static_cast<int>(relative.size()), encoded.data(), length, nullptr, nullptr);
    std::string decoded;
    for (std::size_t index = 0; index < encoded.size(); ++index) {
        if (encoded[index] != '%') { decoded += encoded[index]; continue; }
        if (index + 2 >= encoded.size()) throw std::runtime_error("資產 URL 編碼不完整。");
        const auto digit = [](char value) -> int {
            if (value >= '0' && value <= '9') return value - '0';
            if (value >= 'A' && value <= 'F') return value - 'A' + 10;
            if (value >= 'a' && value <= 'f') return value - 'a' + 10;
            return -1;
        };
        const int high = digit(encoded[index + 1]), low = digit(encoded[index + 2]);
        if (high < 0 || low < 0) throw std::runtime_error("資產 URL 編碼不合法。");
        decoded += static_cast<char>(high * 16 + low);
        index += 2;
    }
    std::wstring wide;
    const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, decoded.data(), static_cast<int>(decoded.size()), nullptr, 0);
    if (count <= 0) throw std::runtime_error("資產路徑不是有效 UTF-8。");
    wide.resize(count);
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, decoded.data(), static_cast<int>(decoded.size()), wide.data(), count);
    for (wchar_t value : wide) {
        if (value < 32 || std::wstring_view(L"\\:%<>\"|?*").find(value) != std::wstring_view::npos)
            throw std::runtime_error("資產路徑含有不允許的字元。");
    }
    std::filesystem::path result(root);
    for (const auto& part : std::filesystem::path(wide)) {
        const auto name = part.wstring();
        if (name.empty() || name == L"." || name == L".." || name.back() == L'.' || name.back() == L' ' || part.has_root_path())
            throw std::runtime_error("資產路徑超出主題邊界。");
        result /= part;
    }
    auto current = result;
    while (!current.empty()) {
        const auto attributes = GetFileAttributesW(current.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES || (attributes & FILE_ATTRIBUTE_REPARSE_POINT))
            throw std::runtime_error("資產不存在或路徑經過重新解析點。");
        const auto parent = current.parent_path();
        if (parent == current) break;
        current = parent;
    }
    if (!std::filesystem::is_regular_file(result) || std::filesystem::file_size(result) > 10 * 1024 * 1024)
        throw std::runtime_error("資產不是一般檔案或超過大小上限。");
    return result;
}

/** 依受支援的靜態資產副檔名提供 MIME，其他內容不作為主動程式執行。
 * Args:
 *     file: 已驗證的檔案。
 * Returns:
 *     MIME 類型。
 */
const wchar_t* AssetMime(const std::filesystem::path& file) {
    auto extension = file.extension().wstring();
    std::transform(extension.begin(), extension.end(), extension.begin(), towlower);
    if (extension == L".html") return L"text/html; charset=utf-8";
    if (extension == L".js" || extension == L".mjs") return L"text/javascript; charset=utf-8";
    if (extension == L".css") return L"text/css; charset=utf-8";
    if (extension == L".json") return L"application/json";
    if (extension == L".svg") return L"image/svg+xml";
    if (extension == L".png") return L"image/png";
    if (extension == L".jpg" || extension == L".jpeg") return L"image/jpeg";
    if (extension == L".gif") return L"image/gif";
    if (extension == L".webp") return L"image/webp";
    if (extension == L".woff2") return L"font/woff2";
    if (extension == L".woff") return L"font/woff";
    return L"application/octet-stream";
}

/** 為每次主題載入產生獨立來源，避免舊頁面訊息及儲存跨主題重用。
 * Returns:
 *     GUID DNS 主機名稱；失敗時為空字串。
 */
std::wstring NewThemeHost() {
    GUID id{};
    wchar_t text[40]{};
    if (FAILED(CoCreateGuid(&id)) || StringFromGUID2(id, text, 40) == 0) return {};
    // 每次載入使用不同的可註冊網域；避免共同父網域 Cookie 跨主題共享。
    return L"drillpaper-theme-" + std::wstring(text + 1, 36) + L".invalid";
}

bool Utf8ToWide(std::string_view input, std::wstring* output) {
    if (output == nullptr || input.size() > static_cast<std::size_t>(INT_MAX)) {
        return false;
    }
    if (input.empty()) {
        output->clear();
        return true;
    }
    const int required = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                              input.data(), static_cast<int>(input.size()),
                                              nullptr, 0);
    if (required <= 0) {
        return false;
    }
    output->resize(static_cast<std::size_t>(required));
    return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                               input.data(), static_cast<int>(input.size()),
                               output->data(), required) == required;
}

bool WideToUtf8(PCWSTR input, std::string* output) {
    if (input == nullptr || output == nullptr) {
        return false;
    }
    const std::size_t length = wcsnlen_s(input, 65537);
    if (length > 65536 || length > static_cast<std::size_t>(INT_MAX)) {
        return false;
    }
    if (length == 0) {
        output->clear();
        return true;
    }
    const int required = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                                              input, static_cast<int>(length),
                                              nullptr, 0, nullptr, nullptr);
    if (required <= 0 || required > 64 * 1024) {
        return false;
    }
    output->resize(static_cast<std::size_t>(required));
    return WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
                               input, static_cast<int>(length), output->data(), required,
                               nullptr, nullptr) == required;
}

const char* ErrorCode(ProtocolError error) {
    switch (error) {
    case ProtocolError::PayloadTooLarge:
    case ProtocolError::InvalidJson:
    case ProtocolError::InvalidEnvelope: return "invalid-envelope";
    case ProtocolError::UnsupportedApiVersion: return "unsupported-api-version";
    case ProtocolError::UnsupportedMessage: return "unsupported-message";
    case ProtocolError::InvalidPayload: return "invalid-payload";
    case ProtocolError::None: return "internal-error";
    }
    return "internal-error";
}

const char* ErrorText(ProtocolError error) {
    switch (error) {
    case ProtocolError::PayloadTooLarge: return "The message exceeds the protocol size limit.";
    case ProtocolError::InvalidJson:
    case ProtocolError::InvalidEnvelope: return "The host rejected the message envelope.";
    case ProtocolError::UnsupportedApiVersion: return "The message uses an unsupported API version.";
    case ProtocolError::UnsupportedMessage: return "The host does not support this message type.";
    case ProtocolError::InvalidPayload: return "The host rejected the message payload.";
    case ProtocolError::None: return "An internal host error occurred.";
    }
    return "An internal host error occurred.";
}
} // namespace

WebView2Host::~WebView2Host() {
    Shutdown();
}

void WebView2Host::NotifyNetworkBlocked() {
    if (networkPolicy_.Evaluate(runtime::ThemeRequestKind::ExternalHttps) ==
        runtime::ThemeNetworkAction::BlockAndPromptSettings) {
        SetPropW(parentWindow_, L"DrillPaper.NetworkPrompt", reinterpret_cast<HANDLE>(1));
        PostMessageW(parentWindow_, kNetworkBlockedMessage, 0, 0);
    }
}

HRESULT WebView2Host::OnResourceRequested(ICoreWebView2WebResourceRequestedEventArgs* args) {
    ComPtr<ICoreWebView2WebResourceRequest> request;
    LPWSTR rawUri = nullptr;
    std::wstring uri;
    if (SUCCEEDED(args->get_Request(&request)) && request && SUCCEEDED(request->get_Uri(&rawUri)) && rawUri)
        uri = rawUri;
    CoTaskMemFree(rawUri);
    const bool local = IsLocalThemeUrl(uri.c_str(), hostOrigin_);
    const bool http = uri.starts_with(L"http://") || uri.starts_with(L"https://");
    COREWEBVIEW2_WEB_RESOURCE_CONTEXT context{};
    const bool hasContext = SUCCEEDED(args->get_ResourceContext(&context));
    if (!local && http && !IsReservedThemeHost(uri) &&
        hasContext && context != COREWEBVIEW2_WEB_RESOURCE_CONTEXT_DOCUMENT) {
        if (networkPolicy_.ExternalRequestsEnabled()) return S_OK;
        NotifyNetworkBlocked();
    }
    ComPtr<IStream> body;
    int status = 403;
    auto headers = SecurityHeaders(networkPolicy_.ExternalRequestsEnabled(), hostOrigin_);
    if (local && request) {
        try {
            LPWSTR method = nullptr;
            const HRESULT methodResult = request->get_Method(&method);
            const bool get = SUCCEEDED(methodResult) && method && wcscmp(method, L"GET") == 0;
            CoTaskMemFree(method);
            if (!get) throw std::runtime_error("主題資產僅允許 GET。");
            const auto file = ThemeAssetPath(uri.substr(hostOrigin_.size()), themeDirectory_);
            std::ifstream input(file, std::ios::binary);
            if (!input) throw std::runtime_error("無法讀取主題資產。");
            const auto size = std::filesystem::file_size(file);
            if (size > 10 * 1024 * 1024) throw std::runtime_error("資產超過大小上限。");
            std::string bytes(static_cast<std::size_t>(size), '\0');
            if (!input.read(bytes.data(), static_cast<std::streamsize>(bytes.size())) || input.peek() != EOF)
                throw std::runtime_error("資產讀取失敗或讀取期間遭修改。");
            body.Attach(SHCreateMemStream(reinterpret_cast<const BYTE*>(bytes.data()), static_cast<UINT>(bytes.size())));
            if (!body) throw std::runtime_error("無法建立資產回應。");
            headers += std::wstring(L"Content-Type: ") + AssetMime(file) + L"\r\n";
            status = 200;
        } catch (const std::exception& error) {
            OutputDebugStringA(error.what());
            status = 404;
        }
    }
    ComPtr<ICoreWebView2WebResourceResponse> response;
    HRESULT result = environment_->CreateWebResourceResponse(body.Get(), status,
        status == 200 ? L"OK" : L"Blocked", headers.c_str(), &response);
    if (SUCCEEDED(result)) result = args->put_Response(response.Get());
    if (FAILED(result)) { webview_->Stop(); ReportFailure(result); }
    return result;
}

HRESULT WebView2Host::Initialize(HWND parentWindow, const std::wstring& themeDirectory,
                                 const std::wstring& themeName, const std::wstring& entry) {
    if (parentWindow == nullptr || !IsWindow(parentWindow) || themeDirectory.empty() ||
        themeName.empty() || entry.empty()) {
        return E_INVALIDARG;
    }
    parentWindow_ = parentWindow;
    themeName_ = themeName;
    themeDirectory_ = themeDirectory;
    themeEntry_ = entry;
    ++loadEpoch_;
    hostName_ = NewThemeHost();
    if (hostName_.empty()) return E_FAIL;
    hostOrigin_ = L"https://" + hostName_ + L"/";
    lifetime_ = std::make_shared<bool>(true);

    wchar_t localAppData[MAX_PATH]{};
    const DWORD localAppDataLength = GetEnvironmentVariableW(
        L"LOCALAPPDATA", localAppData, static_cast<DWORD>(std::size(localAppData)));
    if (localAppDataLength == 0 || localAppDataLength >= std::size(localAppData)) {
        return HRESULT_FROM_WIN32(GetLastError() == ERROR_SUCCESS ? ERROR_PATH_NOT_FOUND : GetLastError());
    }
    const std::filesystem::path userDataPath =
        std::filesystem::path(localAppData) / L"DrillPaper" / L"WebView2";
    std::error_code fileError;
    std::filesystem::create_directories(userDataPath, fileError);
    if (fileError) {
        return HRESULT_FROM_WIN32(static_cast<DWORD>(fileError.value()));
    }

    return CreateCoreWebView2EnvironmentWithOptions(
        nullptr, userDataPath.c_str(), nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [this, themeDirectory, lifetime = lifetime_](HRESULT result, ICoreWebView2Environment* environment) -> HRESULT {
                if (!*lifetime) return S_OK;
                if (FAILED(result) || environment == nullptr) {
                    ReportFailure(FAILED(result) ? result : E_FAIL);
                    return S_OK;
                }
                environment_ = environment;
                const HRESULT controllerResult = environment_->CreateCoreWebView2Controller(
                    parentWindow_,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [this, themeDirectory, lifetime](HRESULT createResult,
                                               ICoreWebView2Controller* controller) -> HRESULT {
                            if (!*lifetime) return S_OK;
                            if (FAILED(createResult) || controller == nullptr) {
                                ReportFailure(FAILED(createResult) ? createResult : E_FAIL);
                                return S_OK;
                            }
                            controller_ = controller;
                            HRESULT result = controller_->get_CoreWebView2(&webview_);
                            if (FAILED(result) || webview_ == nullptr) {
                                ReportFailure(FAILED(result) ? result : E_FAIL);
                                return S_OK;
                            }

                            ComPtr<ICoreWebView2_3> webview3;
                            result = webview_.As(&webview3);
                            if (FAILED(result)) {
                                ReportFailure(result);
                                return S_OK;
                            }
                            ComPtr<ICoreWebView2Settings> settings;
                            result = webview_->get_Settings(&settings);
                            if (SUCCEEDED(result) && settings != nullptr) {
                                result = settings->put_IsWebMessageEnabled(TRUE);
                                if (SUCCEEDED(result)) result = settings->put_AreHostObjectsAllowed(FALSE);
                                if (SUCCEEDED(result)) result = settings->put_AreDevToolsEnabled(FALSE);
                                if (SUCCEEDED(result)) result = settings->put_AreDefaultContextMenusEnabled(FALSE);
                                if (SUCCEEDED(result)) result = settings->put_AreDefaultScriptDialogsEnabled(FALSE);
                            }
                            if (FAILED(result)) {
                                ReportFailure(result);
                                return S_OK;
                            }

                            result = webview_->AddWebResourceRequestedFilter(
                                L"*", COREWEBVIEW2_WEB_RESOURCE_CONTEXT_ALL);
                            if (SUCCEEDED(result)) {
                                result = webview_->add_WebResourceRequested(
                                    Callback<ICoreWebView2WebResourceRequestedEventHandler>(
                                        [this, lifetime](ICoreWebView2*,
                                               ICoreWebView2WebResourceRequestedEventArgs* args) -> HRESULT {
                                            if (!*lifetime) return E_ABORT;
                                            if (args == nullptr) return E_INVALIDARG;
                                            return OnResourceRequested(args);
                                        }).Get(), &webResourceRequestedToken_);
                            }
                            if (SUCCEEDED(result)) {
                                result = webview_->add_NavigationStarting(
                                    Callback<ICoreWebView2NavigationStartingEventHandler>(
                                        [this, lifetime](ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                                            if (args == nullptr) return E_INVALIDARG;
                                            if (!*lifetime) return args->put_Cancel(TRUE);
                                            LPWSTR uri = nullptr;
                                            const HRESULT uriResult = args->get_Uri(&uri);
                                            if (FAILED(uriResult) || uri == nullptr) return args->put_Cancel(TRUE);
                                            const bool allowed = IsLocalThemeUrl(uri, hostOrigin_);
                                            CoTaskMemFree(uri);
                                            return allowed ? S_OK : args->put_Cancel(TRUE);
                                        }).Get(), &navigationStartingToken_);
                            }
                            if (SUCCEEDED(result)) {
                                result = webview_->add_FrameNavigationStarting(
                                    Callback<ICoreWebView2NavigationStartingEventHandler>(
                                        [](ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                                            return args ? args->put_Cancel(TRUE) : E_INVALIDARG;
                                        }).Get(), &frameNavigationToken_);
                            }
                            if (SUCCEEDED(result)) {
                                result = webview_->add_PermissionRequested(
                                    Callback<ICoreWebView2PermissionRequestedEventHandler>(
                                        [](ICoreWebView2*, ICoreWebView2PermissionRequestedEventArgs* args) -> HRESULT {
                                            return args ? args->put_State(COREWEBVIEW2_PERMISSION_STATE_DENY) : E_INVALIDARG;
                                        }).Get(), &permissionToken_);
                            }
                            if (SUCCEEDED(result)) {
                                ComPtr<ICoreWebView2_4> webview4;
                                result = webview_.As(&webview4);
                                if (SUCCEEDED(result)) result = webview4->add_DownloadStarting(
                                    Callback<ICoreWebView2DownloadStartingEventHandler>(
                                        [this, lifetime](ICoreWebView2*, ICoreWebView2DownloadStartingEventArgs* args) -> HRESULT {
                                            if (!args) return E_INVALIDARG;
                                            if (*lifetime) SetPropW(parentWindow_, L"DrillPaper.DownloadBlocked", reinterpret_cast<HANDLE>(1));
                                            args->put_Handled(TRUE);
                                            return args->put_Cancel(TRUE);
                                        }).Get(), &downloadToken_);
                            }
                            if (SUCCEEDED(result)) {
                                result = webview_->add_NewWindowRequested(
                                    Callback<ICoreWebView2NewWindowRequestedEventHandler>(
                                        [](ICoreWebView2*, ICoreWebView2NewWindowRequestedEventArgs* args) -> HRESULT {
                                            return args == nullptr ? E_INVALIDARG : args->put_Handled(TRUE);
                                        }).Get(), &newWindowRequestedToken_);
                            }
                            if (SUCCEEDED(result)) {
                                result = webview_->add_WebMessageReceived(
                                    Callback<ICoreWebView2WebMessageReceivedEventHandler>(
                                        [this, lifetime](ICoreWebView2*, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
                                            if (!*lifetime) return S_OK;
                                            OnMessage(args);
                                            return S_OK;
                                        }).Get(), &webMessageReceivedToken_);
                            }
                            if (SUCCEEDED(result)) {
                                result = webview_->add_ProcessFailed(
                                    Callback<ICoreWebView2ProcessFailedEventHandler>(
                                        [this, lifetime](ICoreWebView2*, ICoreWebView2ProcessFailedEventArgs* args) -> HRESULT {
                                            if (!*lifetime || args == nullptr) return S_OK;
                                            COREWEBVIEW2_PROCESS_FAILED_KIND kind{};
                                            if (SUCCEEDED(args->get_ProcessFailedKind(&kind)) &&
                                                (kind == COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED ||
                                                 kind == COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_EXITED ||
                                                 kind == COREWEBVIEW2_PROCESS_FAILED_KIND_RENDER_PROCESS_UNRESPONSIVE)) {
                                                PostMessageW(parentWindow_, kRendererFailedMessage,
                                                    static_cast<WPARAM>(loadEpoch_), static_cast<LPARAM>(kind));
                                            }
                                            return S_OK;
                                        }).Get(), &processFailedToken_);
                            }
                            if (FAILED(result)) {
                                ReportFailure(result);
                                return S_OK;
                            }
                            Resize();
                            // 等待固定通知程式註冊完成才導覽，避免首個 CSP 封鎖早於監聽器。
                            const HRESULT registration = webview_->AddScriptToExecuteOnDocumentCreated(
                                LR"JS(addEventListener('securitypolicyviolation', event => {
                                    if (/^https?:/i.test(event.blockedURI))
                                        chrome.webview.postMessage({drillpaperNetworkBlocked:true});
                                });)JS",
                                Callback<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>(
                                    [this, lifetime](HRESULT registered, PCWSTR) -> HRESULT {
                                        if (!*lifetime) return S_OK;
                                        if (FAILED(registered)) { ReportFailure(registered); return S_OK; }
                                        const HRESULT navigate = webview_->Navigate((hostOrigin_ + themeEntry_).c_str());
                                        if (SUCCEEDED(navigate)) SetRuntimeState(state_);
                                        else ReportFailure(navigate);
                                        return S_OK;
                                    }).Get());
                            if (FAILED(registration)) ReportFailure(registration);
                            return S_OK;
                        }).Get());
                if (FAILED(controllerResult)) {
                    ReportFailure(controllerResult);
                }
                return S_OK;
            }).Get());
}

HRESULT WebView2Host::LoadTheme(const std::wstring& themeDirectory, const std::wstring& themeName,
                              const std::wstring& entry) {
    if (webview_ == nullptr || controller_ == nullptr) return E_PENDING;
    if (themeDirectory.empty() || themeName.empty() || entry.empty()) return E_INVALIDARG;
    const auto nextHost = NewThemeHost();
    if (nextHost.empty()) return E_FAIL;
    const auto oldHost = hostName_;
    const auto oldOrigin = hostOrigin_;
    const auto oldName = themeName_;
    const auto oldDirectory = themeDirectory_;
    webview_->Stop();
    hostName_ = nextHost;
    hostOrigin_ = L"https://" + nextHost + L"/";
    themeName_ = themeName;
    themeDirectory_ = themeDirectory;
    handshakeComplete_ = false;
    subscribed_ = false;
    lastBroadcastTick_ = 0;
    updateIntervalMilliseconds_ = 1000;
    const HRESULT result = webview_->Navigate((hostOrigin_ + entry).c_str());
    if (FAILED(result)) {
        hostName_ = oldHost;
        hostOrigin_ = oldOrigin;
        themeName_ = oldName;
        themeDirectory_ = oldDirectory;
        return result;
    }
    themeDirectory_ = themeDirectory;
    themeEntry_ = entry;
    ++loadEpoch_;
    recoveryAttempts_ = 0;
    SetWindowTextW(parentWindow_, (L"DrillPaper Preview — " + themeName_ + L" — 載入中").c_str());
    if (state_ != runtime::PowerState::Active) {
        suspended_ = false;
        SetRuntimeState(state_);
    }
    return S_OK;
}

HRESULT WebView2Host::Recover() {
    if (parentWindow_ == nullptr || !IsWindow(parentWindow_) || recoveryAttempts_ >= 3)
        return HRESULT_FROM_WIN32(ERROR_RETRY);
    ++recoveryAttempts_;
    const HWND parent = parentWindow_;
    const auto directory = themeDirectory_;
    const auto name = themeName_;
    const auto entry = themeEntry_;
    Shutdown();
    return Initialize(parent, directory, name, entry);
}

HRESULT WebView2Host::RecreateForWindow(HWND parentWindow) {
    if (!IsWindow(parentWindow)) return E_INVALIDARG;
    const auto directory = themeDirectory_;
    const auto name = themeName_;
    const auto entry = themeEntry_;
    Shutdown();
    return Initialize(parentWindow, directory, name, entry);
}

HRESULT WebView2Host::SetRuntimeState(runtime::PowerState state) {
    const auto previous = state_;
    const auto epoch = ++runtimeEpoch_;
    state_ = state;
    const bool active = state == runtime::PowerState::Active;
    if (controller_ == nullptr || webview_ == nullptr) return S_OK;
    ComPtr<ICoreWebView2_3> webview3;
    HRESULT result = webview_.As(&webview3);
    if (FAILED(result)) return result;
    if (active) {
        result = webview3->Resume();
        suspended_ = false;
        resumeSnapshotPending_ = resumeSnapshotPending_ || previous != runtime::PowerState::Active;
        controller_->put_IsVisible(TRUE);
    }
    if (handshakeComplete_ && !suspended_) {
        const std::string payload = std::string("{\"state\":\"") + StateName(state_) + "\"}";
        PostJson(SerializeProtocolMessage("host.stateChanged", CurrentUnixTimeMilliseconds(), nullptr, payload));
    }
    if (!active) {
        controller_->put_IsVisible(FALSE);
        if (!suspended_ && !suspendPending_) {
            suspendPending_ = true;
            result = webview3->TrySuspend(Callback<ICoreWebView2TrySuspendCompletedHandler>(
                [this, lifetime = lifetime_, epoch](HRESULT error, BOOL success) -> HRESULT {
                    if (!*lifetime) return S_OK;
                    suspendPending_ = false;
                    suspended_ = SUCCEEDED(error) && success;
                    if (state_ != runtime::PowerState::Active && epoch != runtimeEpoch_) {
                        // 過期的暫停可能已被 Resume 取消；返回 UI 迴圈後重套最新狀態。
                        suspended_ = false;
                        PostMessageW(parentWindow_, kRuntimeStateRefreshMessage, 0, 0);
                        return S_OK;
                    }
                    if (state_ == runtime::PowerState::Active && webview_ != nullptr) {
                        ComPtr<ICoreWebView2_3> current;
                        if (SUCCEEDED(webview_.As(&current))) current->Resume();
                        suspended_ = false;
                        resumeSnapshotPending_ = true;
                    } else if (webview_ != nullptr) {
                        suspended_ = false;
                        ComPtr<ICoreWebView2_3> current;
                        BOOL actual = FALSE;
                        if (SUCCEEDED(webview_.As(&current)) && SUCCEEDED(current->get_IsSuspended(&actual)))
                            suspended_ = actual != FALSE;
                    }
                    UpdateCaption();
                    return S_OK;
                }).Get());
            if (FAILED(result)) suspendPending_ = false;
        }
    }
    UpdateCaption();
    return result;
}

void WebView2Host::UpdateCaption() {
    if (!IsReady() || parentWindow_ == nullptr) return;
    std::wstring suffix;
    if (state_ == runtime::PowerState::Active) suffix = resumeSnapshotPending_ ? L"恢復中" : L"Live metrics";
    else {
        const std::string name = StateName(state_);
        suffix.assign(name.begin(), name.end());
        suffix += suspended_ ? L" — 已暫停" : L" — 低頻模式";
    }
    SetWindowTextW(parentWindow_, (L"DrillPaper Preview — " + themeName_ + L" — " + suffix).c_str());
}

void WebView2Host::Resize() {
    if (controller_ == nullptr || parentWindow_ == nullptr) {
        return;
    }
    RECT bounds{};
    if (GetClientRect(parentWindow_, &bounds)) {
        controller_->put_Bounds(bounds);
    }
}

void WebView2Host::SetSnapshot(const core::MetricsSnapshot& snapshot) {
    currentSnapshot_ = snapshot;
    history_.push_back(snapshot);
    if (history_.size() > kMaximumHistory) {
        history_.erase(history_.begin());
    }
    if (!handshakeComplete_ || !subscribed_ || state_ != runtime::PowerState::Active) {
        return;
    }
    if (resumeSnapshotPending_) {
        PostJson(SerializeMetricsSnapshotMessage(snapshot, "metrics.snapshot", nullptr));
        if (SUCCEEDED(PostJson(SerializeMetricsSnapshotMessage(snapshot, "metrics.changed", nullptr))))
            SetPropW(parentWindow_, L"DrillPaper.MetricsTick", reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(GetTickCount64())));
        resumeSnapshotPending_ = false;
        lastBroadcastTick_ = GetTickCount64();
        UpdateCaption();
        return;
    }
    const unsigned __int64 now = GetTickCount64();
    if (now < lastBroadcastTick_ || now - lastBroadcastTick_ < updateIntervalMilliseconds_) {
        return;
    }
    lastBroadcastTick_ = now;
    if (SUCCEEDED(PostJson(SerializeMetricsSnapshotMessage(snapshot, "metrics.changed", nullptr))))
        SetPropW(parentWindow_, L"DrillPaper.MetricsTick", reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(now)));
}

void WebView2Host::OnMessage(ICoreWebView2WebMessageReceivedEventArgs* args) {
    if (args == nullptr || webview_ == nullptr) {
        return;
    }
    LPWSTR source = nullptr;
    if (FAILED(args->get_Source(&source)) || source == nullptr) {
        return;
    }
    const bool trustedSource = IsLocalThemeUrl(source, hostOrigin_);
    CoTaskMemFree(source);
    if (!trustedSource) {
        return;
    }

    LPWSTR jsonWide = nullptr;
    if (FAILED(args->get_WebMessageAsJson(&jsonWide)) || jsonWide == nullptr) {
        SendError(ProtocolError::InvalidJson, nullptr);
        return;
    }
    std::string json;
    const bool converted = WideToUtf8(jsonWide, &json);
    CoTaskMemFree(jsonWide);
    if (!converted) {
        SendError(ProtocolError::PayloadTooLarge, nullptr);
        return;
    }
    if (json == R"({"drillpaperNetworkBlocked":true})") {
        NotifyNetworkBlocked();
        return;
    }

    const ProtocolParseResult parsed = ParseClientMessage(json);
    if (parsed.error != ProtocolError::None) {
        SendError(parsed.error, parsed.message.requestId.empty() ? nullptr : parsed.message.requestId.c_str());
        return;
    }
    const char* requestId = parsed.message.requestId.empty() ? nullptr : parsed.message.requestId.c_str();
    switch (parsed.message.type) {
    case ClientMessageType::Hello:
        handshakeComplete_ = true;
        SendReady();
        break;
    case ClientMessageType::GetSnapshot:
        if (!handshakeComplete_) {
            SendError(ProtocolError::InvalidEnvelope, requestId);
            return;
        }
        PostJson(SerializeMetricsSnapshotMessage(currentSnapshot_, "metrics.snapshot", requestId));
        break;
    case ClientMessageType::GetHistory: {
        if (!handshakeComplete_) {
            SendError(ProtocolError::InvalidEnvelope, requestId);
            return;
        }
        const std::size_t count = std::min<std::size_t>(parsed.message.historyLimit, history_.size());
        const std::size_t first = history_.size() - count;
        const core::MetricsSnapshot* selectedData = count == 0 ? nullptr : history_.data() + first;
        const std::span<const core::MetricsSnapshot> selected{selectedData, count};
        PostJson(SerializeMetricsHistoryMessage(selected, CurrentUnixTimeMilliseconds(), requestId));
        break;
    }
    case ClientMessageType::Subscribe: {
        if (!handshakeComplete_) {
            SendError(ProtocolError::InvalidEnvelope, nullptr);
            return;
        }
        subscribed_ = true;
        // 原生診斷屬性只在真正訂閱後前進，供整合測試辨認新的握手。
        SetPropW(parentWindow_, L"DrillPaper.ReadyEpoch", reinterpret_cast<HANDLE>(static_cast<ULONG_PTR>(++readySequence_)));
        updateIntervalMilliseconds_ = parsed.message.intervalMilliseconds;
        lastBroadcastTick_ = 0;
        PostJson(SerializeMetricsSnapshotMessage(currentSnapshot_, "metrics.changed", nullptr));
        UpdateCaption();
        break;
    }
    case ClientMessageType::Unsubscribe:
        subscribed_ = false;
        break;
    }
}

void WebView2Host::SendReady() {
    const std::string payload =
        std::string(R"({"hostVersion":"0.1.0-dev","capabilities":["cpu","gpu","memory","disk","network","clock"],"state":")") +
        StateName(state_) + R"(","limits":{"history":120,"messageBytes":65536}})";
    if (SUCCEEDED(PostJson(SerializeProtocolMessage(
            "host.ready", CurrentUnixTimeMilliseconds(), nullptr, payload)))) {
        const std::wstring title = L"DrillPaper Preview — " + themeName_ + L" — WebView2 ready";
        SetWindowTextW(parentWindow_, title.c_str());
    }
}

void WebView2Host::SendError(ProtocolError error, const char* requestId) {
    std::string payload = "{\"code\":\"";
    payload.append(ErrorCode(error));
    payload.append("\",\"message\":\"");
    payload.append(ErrorText(error));
    payload.append("\"}");
    PostJson(SerializeProtocolMessage("host.error", CurrentUnixTimeMilliseconds(), requestId, payload));
}

HRESULT WebView2Host::PostJson(const std::string& json) {
    if (webview_ == nullptr) {
        return E_UNEXPECTED;
    }
    std::wstring wideJson;
    if (!Utf8ToWide(json, &wideJson)) {
        ReportFailure(HRESULT_FROM_WIN32(ERROR_NO_UNICODE_TRANSLATION));
        return HRESULT_FROM_WIN32(ERROR_NO_UNICODE_TRANSLATION);
    }
    const HRESULT result = webview_->PostWebMessageAsJson(wideJson.c_str());
    if (FAILED(result)) {
        ReportFailure(result);
    }
    return result;
}

void WebView2Host::ReportFailure(HRESULT error) {
    if (parentWindow_ != nullptr && IsWindow(parentWindow_)) {
        PostMessageW(parentWindow_, kWebViewFailureMessage, static_cast<WPARAM>(error), 0);
    }
}

void WebView2Host::Shutdown() {
    *lifetime_ = false;
    if (parentWindow_ != nullptr) RemovePropW(parentWindow_, L"DrillPaper.ReadyEpoch");
    if (parentWindow_ != nullptr) RemovePropW(parentWindow_, L"DrillPaper.MetricsTick");
    if (webview_ != nullptr) {
        if (webMessageReceivedToken_.value != 0) webview_->remove_WebMessageReceived(webMessageReceivedToken_);
        if (navigationStartingToken_.value != 0) webview_->remove_NavigationStarting(navigationStartingToken_);
        if (webResourceRequestedToken_.value != 0) webview_->remove_WebResourceRequested(webResourceRequestedToken_);
        if (newWindowRequestedToken_.value != 0) webview_->remove_NewWindowRequested(newWindowRequestedToken_);
        if (processFailedToken_.value != 0) webview_->remove_ProcessFailed(processFailedToken_);
        if (frameNavigationToken_.value != 0) webview_->remove_FrameNavigationStarting(frameNavigationToken_);
        if (permissionToken_.value != 0) webview_->remove_PermissionRequested(permissionToken_);
        ComPtr<ICoreWebView2_4> webview4;
        if (downloadToken_.value != 0 && SUCCEEDED(webview_.As(&webview4))) webview4->remove_DownloadStarting(downloadToken_);
    }
    if (controller_ != nullptr) {
        controller_->Close();
    }
    webview_.Reset();
    controller_.Reset();
    environment_.Reset();
    navigationStartingToken_ = {};
    webMessageReceivedToken_ = {};
    webResourceRequestedToken_ = {};
    newWindowRequestedToken_ = {};
    processFailedToken_ = {};
    frameNavigationToken_ = {};
    permissionToken_ = {};
    downloadToken_ = {};
    parentWindow_ = nullptr;
    handshakeComplete_ = false;
    subscribed_ = false;
    suspended_ = false;
    suspendPending_ = false;
    resumeSnapshotPending_ = true;
}

} // namespace desktopmonitor::web
