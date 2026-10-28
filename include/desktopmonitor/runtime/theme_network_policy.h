#pragma once

namespace desktopmonitor::runtime {

enum class ThemeRequestKind : unsigned char {
    LocalThemeResource,
    ExternalHttp,
    ExternalHttps,
    UnsupportedScheme
};

enum class ThemeNetworkAction : unsigned char {
    AllowLocal,
    AllowExternal,
    BlockExternal,
    BlockAndPromptSettings,
    BlockUnsupportedScheme
};

class ThemeNetworkPolicy final {
public:
    bool ExternalRequestsEnabled() const { return externalRequestsEnabled_; }
    bool SettingsPromptShown() const { return settingsPromptShown_; }

    void SetExternalRequestsEnabled(bool enabled) { externalRequestsEnabled_ = enabled; }

    ThemeNetworkAction Evaluate(ThemeRequestKind request) {
        switch (request) {
        case ThemeRequestKind::LocalThemeResource:
            return ThemeNetworkAction::AllowLocal;
        case ThemeRequestKind::UnsupportedScheme:
            return ThemeNetworkAction::BlockUnsupportedScheme;
        case ThemeRequestKind::ExternalHttp:
        case ThemeRequestKind::ExternalHttps:
            if (externalRequestsEnabled_) {
                return ThemeNetworkAction::AllowExternal;
            }
            if (!settingsPromptShown_) {
                settingsPromptShown_ = true;
                return ThemeNetworkAction::BlockAndPromptSettings;
            }
            return ThemeNetworkAction::BlockExternal;
        }
        return ThemeNetworkAction::BlockUnsupportedScheme;
    }

private:
    bool externalRequestsEnabled_ = false;
    bool settingsPromptShown_ = false;
};

} // namespace desktopmonitor::runtime
