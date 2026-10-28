#pragma once

#include <string>
#include <vector>

#include <windows.h>
#include <wrl/client.h>
#include <WebView2.h>

#include "desktopmonitor/core/metrics_snapshot.h"
#include "desktopmonitor/web/protocol_v1.h"

namespace desktopmonitor::web {

class WebView2Host final {
public:
    WebView2Host() = default;
    ~WebView2Host();

    WebView2Host(const WebView2Host&) = delete;
    WebView2Host& operator=(const WebView2Host&) = delete;

    HRESULT Initialize(HWND parentWindow, const std::wstring& themeDirectory,
                       const std::wstring& themeName);
    void Resize();
    void SetSnapshot(const core::MetricsSnapshot& snapshot);
    void Shutdown();

private:
    void OnMessage(ICoreWebView2WebMessageReceivedEventArgs* args);
    void SendReady();
    void SendError(ProtocolError error, const char* requestId);
    HRESULT PostJson(const std::string& json);
    void ReportFailure(HRESULT error);

    HWND parentWindow_ = nullptr;
    Microsoft::WRL::ComPtr<ICoreWebView2Environment> environment_;
    Microsoft::WRL::ComPtr<ICoreWebView2Controller> controller_;
    Microsoft::WRL::ComPtr<ICoreWebView2> webview_;
    EventRegistrationToken navigationStartingToken_{};
    EventRegistrationToken webMessageReceivedToken_{};
    EventRegistrationToken webResourceRequestedToken_{};
    EventRegistrationToken newWindowRequestedToken_{};
    core::MetricsSnapshot currentSnapshot_{};
    std::vector<core::MetricsSnapshot> history_;
    std::wstring themeName_;
    unsigned int updateIntervalMilliseconds_ = 1000;
    unsigned __int64 lastBroadcastTick_ = 0;
    bool handshakeComplete_ = false;
    bool subscribed_ = false;
};

} // namespace desktopmonitor::web
