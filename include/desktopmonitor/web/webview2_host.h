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
#include "desktopmonitor/runtime/theme_network_policy.h"

namespace desktopmonitor::web {

class WebView2Host final {
public:
    WebView2Host() = default;
    ~WebView2Host();

    WebView2Host(const WebView2Host&) = delete;
    WebView2Host& operator=(const WebView2Host&) = delete;

    /** 在擁有 UI 執行緒的視窗內初始化主題宿主。
     * Args:
     *     parentWindow: 宿主視窗。
     *     themeDirectory: 已驗證或可信內建的資產目錄。
     *     themeName: 原生狀態顯示名稱。
     *     entry: 已驗證的相對 HTML 入口。
     * Returns:
     *     非同步初始化的啟動結果。
     */
    HRESULT Initialize(HWND parentWindow, const std::wstring& themeDirectory,
                       const std::wstring& themeName, const std::wstring& entry = L"index.html");
    /** 設定全域 HTTP／HTTPS 資源存取；呼叫端須重新載入主題以撤銷既有連線。
     * Args:
     *     enabled: 使用者明確套用的偏好，預設為 false。
     */
    void SetNetworkEnabled(bool enabled) { networkPolicy_.SetExternalRequestsEnabled(enabled); }
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
    /** 重建同一主題的 renderer；每次選擇主題最多自動嘗試 3 次。
     * Returns:
     *     初始化啟動結果或已達重試上限的錯誤。
     */
    HRESULT Recover();
    /** 在原生宿主視窗被銷毀後，以相同主題重建新的 controller。
     * Args:
     *     parentWindow: 新建且有效的宿主視窗。
     * Returns:
     *     非同步初始化的啟動結果；保留主題入口、快照與 runtime 政策。
     */
    HRESULT RecreateForWindow(HWND parentWindow);
    /** 取得目前主題載入世代，以忽略舊 controller 排隊中的失敗通知。
     * Returns:
     *     遞增的載入世代。
     */
    unsigned long long LoadEpoch() const { return loadEpoch_; }

private:
    /** 記錄本工作階段首次封鎖的 HTTP／HTTPS 請求並通知可信原生介面。 */
    void NotifyNetworkBlocked();
    /** 在 UI 執行緒提供含強制 CSP 的資產，或依全域政策拒絕資源。
     * Args:
     *     args: WebView2 的真實資源事件。
     * Returns:
     *     回應處理結果。
     */
    HRESULT OnResourceRequested(ICoreWebView2WebResourceRequestedEventArgs* args);
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
    EventRegistrationToken processFailedToken_{};
    EventRegistrationToken frameNavigationToken_{};
    EventRegistrationToken permissionToken_{};
    EventRegistrationToken downloadToken_{};
    core::MetricsSnapshot currentSnapshot_{};
    std::vector<core::MetricsSnapshot> history_;
    std::wstring themeName_;
    std::wstring hostName_;
    std::wstring hostOrigin_;
    std::wstring themeDirectory_;
    std::wstring themeEntry_ = L"index.html";
    unsigned int updateIntervalMilliseconds_ = 1000;
    unsigned __int64 lastBroadcastTick_ = 0;
    bool handshakeComplete_ = false;
    bool subscribed_ = false;
    runtime::PowerState state_ = runtime::PowerState::Active;
    bool suspended_ = false;
    bool suspendPending_ = false;
    bool resumeSnapshotPending_ = false;
    unsigned long long runtimeEpoch_ = 0;
    unsigned long long readySequence_ = 0;
    unsigned long long loadEpoch_ = 0;
    unsigned recoveryAttempts_ = 0;
    std::shared_ptr<bool> lifetime_ = std::make_shared<bool>(true);
    runtime::ThemeNetworkPolicy networkPolicy_;
};

} // namespace desktopmonitor::web
