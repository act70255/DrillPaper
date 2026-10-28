#include "desktopmonitor/web/webview2_host.h"

#include <windows.h>
#include <wrl.h>

#include <algorithm>
#include <filesystem>
#include <iterator>
#include <string>
#include <string_view>
#include <vector>

#include "desktopmonitor/web/protocol_v1.h"

namespace desktopmonitor::web {
namespace {
using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

constexpr UINT kWebViewFailureMessage = WM_APP + 0x31;
constexpr std::size_t kMaximumHistory = 120;
constexpr unsigned __int64 kWindowsToUnixEpoch100ns = 116444736000000000ULL;

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

bool IsLocalThemeUrl(PCWSTR url, const std::wstring& origin) {
    if (url == nullptr || origin.empty()) {
        return false;
    }
    return _wcsnicmp(url, origin.c_str(), origin.size()) == 0;
}

/** 為每次主題載入產生獨立來源，避免舊頁面訊息及儲存跨主題重用。
 * Returns:
 *     GUID DNS 主機名稱；失敗時為空字串。
 */
std::wstring NewThemeHost() {
    GUID id{};
    wchar_t text[40]{};
    if (FAILED(CoCreateGuid(&id)) || StringFromGUID2(id, text, 40) == 0) return {};
    return L"theme-" + std::wstring(text + 1, 36) + L".drillpaper.local";
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

HRESULT WebView2Host::Initialize(HWND parentWindow, const std::wstring& themeDirectory,
                                 const std::wstring& themeName) {
    if (parentWindow == nullptr || !IsWindow(parentWindow) || themeDirectory.empty() ||
        themeName.empty()) {
        return E_INVALIDARG;
    }
    parentWindow_ = parentWindow;
    themeName_ = themeName;
    hostName_ = NewThemeHost();
    if (hostName_.empty()) return E_FAIL;
    hostOrigin_ = L"https://" + hostName_ + L"/";

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
            [this, themeDirectory](HRESULT result, ICoreWebView2Environment* environment) -> HRESULT {
                if (FAILED(result) || environment == nullptr) {
                    ReportFailure(FAILED(result) ? result : E_FAIL);
                    return S_OK;
                }
                environment_ = environment;
                const HRESULT controllerResult = environment_->CreateCoreWebView2Controller(
                    parentWindow_,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [this, themeDirectory](HRESULT createResult,
                                               ICoreWebView2Controller* controller) -> HRESULT {
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
                            result = webview3->SetVirtualHostNameToFolderMapping(
                                hostName_.c_str(), themeDirectory.c_str(),
                                COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS);
                            if (FAILED(result)) {
                                ReportFailure(result);
                                return S_OK;
                            }

                            ComPtr<ICoreWebView2Settings> settings;
                            result = webview_->get_Settings(&settings);
                            if (SUCCEEDED(result) && settings != nullptr) {
                                result = settings->put_IsWebMessageEnabled(TRUE);
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
                                        [this](ICoreWebView2*,
                                               ICoreWebView2WebResourceRequestedEventArgs* args) -> HRESULT {
                                            if (args == nullptr) return E_INVALIDARG;
                                            ComPtr<ICoreWebView2WebResourceRequest> request;
                                            HRESULT requestResult = args->get_Request(&request);
                                            if (FAILED(requestResult) || request == nullptr) return S_OK;
                                            LPWSTR uri = nullptr;
                                            requestResult = request->get_Uri(&uri);
                                            if (FAILED(requestResult) || uri == nullptr) return S_OK;
                                            const bool allowed = IsLocalThemeUrl(uri, hostOrigin_);
                                            CoTaskMemFree(uri);
                                            if (allowed) return S_OK;

                                            ComPtr<ICoreWebView2WebResourceResponse> response;
                                            requestResult = environment_->CreateWebResourceResponse(
                                                nullptr, 403, L"Forbidden", nullptr, &response);
                                            if (SUCCEEDED(requestResult) && response != nullptr) {
                                                return args->put_Response(response.Get());
                                            }
                                            return requestResult;
                                        }).Get(), &webResourceRequestedToken_);
                            }
                            if (SUCCEEDED(result)) {
                                result = webview_->add_NavigationStarting(
                                    Callback<ICoreWebView2NavigationStartingEventHandler>(
                                        [this](ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT {
                                            if (args == nullptr) return E_INVALIDARG;
                                            LPWSTR uri = nullptr;
                                            const HRESULT uriResult = args->get_Uri(&uri);
                                            if (FAILED(uriResult) || uri == nullptr) return S_OK;
                                            const bool allowed = IsLocalThemeUrl(uri, hostOrigin_);
                                            CoTaskMemFree(uri);
                                            return allowed ? S_OK : args->put_Cancel(TRUE);
                                        }).Get(), &navigationStartingToken_);
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
                                        [this](ICoreWebView2*, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
                                            OnMessage(args);
                                            return S_OK;
                                        }).Get(), &webMessageReceivedToken_);
                            }
                            if (FAILED(result)) {
                                ReportFailure(result);
                                return S_OK;
                            }
                            Resize();
                            return webview_->Navigate((hostOrigin_ + L"index.html").c_str());
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
    ComPtr<ICoreWebView2_3> webview3;
    HRESULT result = webview_.As(&webview3);
    if (FAILED(result)) return result;
    result = webview3->SetVirtualHostNameToFolderMapping(nextHost.c_str(), themeDirectory.c_str(),
        COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_DENY_CORS);
    if (FAILED(result)) return result;
    const auto oldHost = hostName_;
    const auto oldOrigin = hostOrigin_;
    const auto oldName = themeName_;
    webview_->Stop();
    hostName_ = nextHost;
    hostOrigin_ = L"https://" + nextHost + L"/";
    themeName_ = themeName;
    handshakeComplete_ = false;
    subscribed_ = false;
    lastBroadcastTick_ = 0;
    updateIntervalMilliseconds_ = 1000;
    result = webview_->Navigate((hostOrigin_ + entry).c_str());
    if (FAILED(result)) {
        webview3->ClearVirtualHostNameToFolderMapping(nextHost.c_str());
        hostName_ = oldHost;
        hostOrigin_ = oldOrigin;
        themeName_ = oldName;
        return result;
    }
    webview3->ClearVirtualHostNameToFolderMapping(oldHost.c_str());
    SetWindowTextW(parentWindow_, (L"DrillPaper Preview — " + themeName_ + L" — 載入中").c_str());
    return S_OK;
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
    if (!handshakeComplete_ || !subscribed_) {
        return;
    }
    const unsigned __int64 now = GetTickCount64();
    if (now < lastBroadcastTick_ || now - lastBroadcastTick_ < updateIntervalMilliseconds_) {
        return;
    }
    lastBroadcastTick_ = now;
    PostJson(SerializeMetricsSnapshotMessage(snapshot, "metrics.changed", nullptr));
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
        updateIntervalMilliseconds_ = parsed.message.intervalMilliseconds;
        lastBroadcastTick_ = 0;
        PostJson(SerializeMetricsSnapshotMessage(currentSnapshot_, "metrics.changed", nullptr));
        const std::wstring title = L"DrillPaper Preview — " + themeName_ + L" — Live metrics";
        SetWindowTextW(parentWindow_, title.c_str());
        break;
    }
    case ClientMessageType::Unsubscribe:
        subscribed_ = false;
        break;
    }
}

void WebView2Host::SendReady() {
    constexpr std::string_view payload =
        R"({"hostVersion":"0.1.0-dev","capabilities":["cpu","gpu","memory","disk","network","clock"],"state":"active","limits":{"history":120,"messageBytes":65536}})";
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
    if (webview_ != nullptr) {
        if (webMessageReceivedToken_.value != 0) webview_->remove_WebMessageReceived(webMessageReceivedToken_);
        if (navigationStartingToken_.value != 0) webview_->remove_NavigationStarting(navigationStartingToken_);
        if (webResourceRequestedToken_.value != 0) webview_->remove_WebResourceRequested(webResourceRequestedToken_);
        if (newWindowRequestedToken_.value != 0) webview_->remove_NewWindowRequested(newWindowRequestedToken_);
    }
    if (controller_ != nullptr) {
        controller_->Close();
    }
    webview_.Reset();
    controller_.Reset();
    environment_.Reset();
    parentWindow_ = nullptr;
    handshakeComplete_ = false;
    subscribed_ = false;
}

} // namespace desktopmonitor::web
