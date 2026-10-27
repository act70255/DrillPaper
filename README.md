# DesktopMonitor

DesktopMonitor is planned as a Windows x64 desktop metrics host with a C++20/Win32 core, a WebView2 renderer, and an open HTML/CSS/JavaScript theme SDK. Theme content is intended to run locally; the product has no account or telemetry requirement.

## Project status

This repository is at the initial engineering audit. See [`docs/STATUS.md`](docs/STATUS.md) for work completed, commands actually run, and environment blockers. The desktop wallpaper, WebView2 integration, measurements, and release package are not considered verified until their Windows checks have run.

## Requirements

- Windows 10/11 x64, Visual Studio 2022 C++ desktop workload, Windows 10/11 SDK, CMake 3.25+, Git, and the WebView2 Evergreen Runtime.
- Node.js is only used for SDK contract tests and is not a runtime dependency of themes or the application.
- An NVIDIA driver is optional; unsupported GPU metrics must be reported as unavailable.

## Build and test

After the native prerequisites are installed, configure and build with:

```powershell
cmake --preset windows-msvc-debug
cmake --build --preset windows-msvc-debug
ctest --preset windows-msvc-debug --output-on-failure
```

Use `scripts/check-environment.ps1` to inspect local prerequisites. It reports missing components; it does not install them. The exact current environment and tested commands are recorded in `docs/STATUS.md`.

## Theme SDK

The public JavaScript SDK and mock host will live under `sdk/javascript/`. Theme authors should be able to develop static themes without C++ or a Node.js runtime in the shipped application. See [`docs/theme-sdk.md`](docs/theme-sdk.md) once the SDK phase is complete.

## Security and support

Third-party themes are untrusted web content. The project will document the WebView2 origin, navigation, message, and network boundaries actually enforced. Windows Shell wallpaper attachment is not a documented stable API; until the compatibility matrix contains real GUI evidence, use the preview path and treat desktop attachment as unverified.
