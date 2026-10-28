#pragma once

#include <string>
#include <vector>
#include <memory>

#include <windows.h>
#include <wrl/client.h>
#include <WebView2.h>

#include "desktopmonitor/core/metrics_snapshot.h"
#include "desktopmonitor/web/protocol_v1.h"
#include "desktopmonitor/runtime/power_state_machine.h"

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
    /** 在既有 controller 載入另一個已驗證的主題。
     * Args:
     *     themeDirectory: 主題資產目錄。
     *     themeName: 顯示名稱。
     *     entry: 已驗證的相對 HTML 入口。
     * Returns:
     *     導覽啟動結果；初始 controller 尚未建立時為 E_PENDING。
     */
    HRESULT LoadTheme(const std::wstring& themeDirectory, const std::wstring& themeName,
                      const std::wstring& entry = L"index.html");
    /** 回報目前主題是否完成握手與訂閱。
     * Returns:
     *     通訊流程已就緒時為 true。
     */
    bool IsReady() const { return handshakeComplete_ && subscribed_; }
    /** 依 runtime 狀態隱藏／暫停或恢復 renderer；只能由 UI 執行緒呼叫。
     * Args:
     *     state: 已由 runtime 決定的電源狀態。
     * Returns:
     *     WebView2 API 的啟動結果；非暫停成功保證。
     */
    HRESULT SetRuntimeState(runtime::PowerState state);

private:
    void OnMessage(ICoreWebView2WebMessageReceivedEventArgs* args);
    void SendReady();
    void SendError(ProtocolError error, const char* requestId);
    HRESULT PostJson(const std::string& json);
    void ReportFailure(HRESULT error);
    /** 更新可觀察的宿主狀態標題。 */
    void UpdateCaption();

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
    std::wstring hostName_;
    std::wstring hostOrigin_;
    unsigned int updateIntervalMilliseconds_ = 1000;
    unsigned __int64 lastBroadcastTick_ = 0;
    bool handshakeComplete_ = false;
    bool subscribed_ = false;
    runtime::PowerState state_ = runtime::PowerState::Active;
    bool suspended_ = false;
    bool suspendPending_ = false;
    bool resumeSnapshotPending_ = false;
    unsigned long long runtimeEpoch_ = 0;
    std::shared_ptr<bool> lifetime_ = std::make_shared<bool>(true);
};

} // namespace desktopmonitor::web
