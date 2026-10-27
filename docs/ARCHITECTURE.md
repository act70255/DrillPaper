# Architecture

## Target boundaries

The product follows the handoff's dependency direction:

- `core` owns immutable metric values, quality, units, and capability names.
- `monitoring` reads OS and optional hardware APIs and reports core values; it has no renderer dependency.
- `runtime` owns scheduling, change detection, bounded history, latest-wins delivery, and power state policy.
- `platform/windows` owns preview and desktop Shell windows, DPI, session/power notifications, and Explorer recovery.
- `web` owns WebView2 lifetime, the versioned JSON bridge, and navigation policy.
- `theme` owns manifest/package validation, installation, activation, examples, and public SDK assets.

Dependencies flow toward `core`. WebView2 APIs stay on the window-owning thread. The renderer queue carries at most the latest pending snapshot; chart history has its own fixed capacity. Themes are offline static files and cannot call a native API directly.

## Confirmed test seams

The test scope is agreed with the user:

1. Public metrics values and collector behavior, including unavailable readings and warm-up.
2. Runtime state transitions, bounded history, and latest-wins delivery.
3. Theme manifest/package validation and protocol/SDK behavior.
4. Win32 Shell and WebView2 use GUI/integration checks when the native environment is available; unit tests cannot establish those results.

## Current implementation boundary

The initial executable is a plain Win32 preview window. Desktop attachment, monitoring, WebView2, import, and SDK behavior are separate later phases. This file describes target boundaries; see `docs/STATUS.md` for which parts have evidence.
