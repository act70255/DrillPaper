#include "desktopmonitor/runtime/theme_network_policy.h"

using desktopmonitor::runtime::ThemeNetworkAction;
using desktopmonitor::runtime::ThemeNetworkPolicy;
using desktopmonitor::runtime::ThemeRequestKind;

extern "C" int TestEntry() {
    ThemeNetworkPolicy policy;
    if (policy.ExternalRequestsEnabled()) {
        return 1;
    }

    if (policy.Evaluate(ThemeRequestKind::LocalThemeResource) != ThemeNetworkAction::AllowLocal) {
        return 2;
    }

    if (policy.Evaluate(ThemeRequestKind::ExternalHttp) != ThemeNetworkAction::BlockAndPromptSettings) {
        return 3;
    }
    if (!policy.SettingsPromptShown() ||
        policy.Evaluate(ThemeRequestKind::ExternalHttps) != ThemeNetworkAction::BlockExternal) {
        return 4;
    }

    policy.SetExternalRequestsEnabled(true);
    if (policy.Evaluate(ThemeRequestKind::ExternalHttp) != ThemeNetworkAction::AllowExternal ||
        policy.Evaluate(ThemeRequestKind::ExternalHttps) != ThemeNetworkAction::AllowExternal) {
        return 5;
    }
    if (policy.Evaluate(ThemeRequestKind::UnsupportedScheme) != ThemeNetworkAction::BlockUnsupportedScheme) {
        return 6;
    }

    policy.SetExternalRequestsEnabled(false);
    if (policy.Evaluate(ThemeRequestKind::ExternalHttps) != ThemeNetworkAction::BlockExternal) {
        return 7;
    }
    return 0;
}
