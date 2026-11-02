cmake_minimum_required(VERSION 3.25)

project(DrillPaper VERSION 0.1.0 LANGUAGES C CXX)

if(NOT WIN32)
    message(FATAL_ERROR "DrillPaper is a Windows-only application.")
endif()
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "DrillPaper currently supports Windows x64 builds only.")
endif()

# 全專案（含 FetchContent 相依與測試）統一靜態連結 CRT，讓 app 不需要 VC++ 可轉散發套件；見票 17。
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

set(DRILLPAPER_WEBVIEW2_SDK_VERSION "1.0.2478.35" CACHE STRING "Pinned WebView2 SDK version")
if(DEFINED ENV{WEBVIEW2_SDK_ROOT})
    set(_drillpaper_webview2_default "$ENV{WEBVIEW2_SDK_ROOT}")
else()
    set(_drillpaper_webview2_default
        "$ENV{USERPROFILE}/.nuget/packages/microsoft.web.webview2/${DRILLPAPER_WEBVIEW2_SDK_VERSION}")
endif()
set(DRILLPAPER_WEBVIEW2_SDK_ROOT "${_drillpaper_webview2_default}" CACHE PATH "WebView2 NuGet package root")
if(NOT EXISTS "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/include/WebView2.h")
    message(FATAL_ERROR "WebView2 ${DRILLPAPER_WEBVIEW2_SDK_VERSION} headers not found at ${DRILLPAPER_WEBVIEW2_SDK_ROOT}.")
endif()
if(NOT EXISTS "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/x64/WebView2Loader.dll.lib")
    message(FATAL_ERROR "WebView2 x64 loader library is missing from ${DRILLPAPER_WEBVIEW2_SDK_ROOT}.")
endif()

add_library(desktopmonitor_core INTERFACE)
target_include_directories(desktopmonitor_core INTERFACE include)
target_compile_features(desktopmonitor_core INTERFACE cxx_std_20)

include(FetchContent)
set(JSON_BuildTests OFF CACHE BOOL "" FORCE)
FetchContent_Declare(nlohmann_json
    URL https://codeload.github.com/nlohmann/json/tar.gz/refs/tags/v3.11.3
    URL_HASH SHA256=0d8ef5af7f9794e3263480193c491549b2ba6cc74bb018906202ada498a79406)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
FetchContent_Declare(miniz
    URL https://codeload.github.com/richgel999/miniz/tar.gz/refs/tags/3.0.2
    URL_HASH SHA256=c4b4c25a4eb81883448ff8924e6dba95c800094a198dc9ce66a292ac2ef8e018)
FetchContent_MakeAvailable(nlohmann_json miniz)

add_library(desktopmonitor_themes src/themes/theme_manager.cpp)
add_library(desktopmonitor_settings src/app/settings_store.cpp)
target_link_libraries(desktopmonitor_settings PUBLIC desktopmonitor_core PRIVATE nlohmann_json::nlohmann_json ole32)
target_compile_definitions(desktopmonitor_settings PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
if(MSVC)
    target_compile_options(desktopmonitor_settings PRIVATE /W4 /permissive- /utf-8)
endif()
target_link_libraries(desktopmonitor_themes PUBLIC desktopmonitor_core PRIVATE nlohmann_json::nlohmann_json miniz)
target_compile_definitions(desktopmonitor_themes PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
if(MSVC)
    target_compile_options(desktopmonitor_themes PRIVATE /W4 /permissive- /utf-8)
endif()

add_executable(DrillPaper WIN32
    src/app/main.cpp
    src/app/theme_commands.cpp
    src/platform/windows/desktop_host.cpp
    src/platform/windows/monitor_info.cpp
    src/platform/windows/power_notifications.cpp
    src/platform/windows/management_shell.cpp
    src/monitoring/windows_metrics_collector.cpp
    src/monitoring/nvml_gpu_collector.cpp
    src/web/protocol_v1.cpp
    src/web/webview2_host.cpp
)
target_include_directories(DrillPaper PRIVATE
    "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/include"
)
target_compile_definitions(DrillPaper PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(DrillPaper PRIVATE desktopmonitor_core desktopmonitor_themes desktopmonitor_settings shell32 wtsapi32 comdlg32 shcore comctl32)
if(MSVC)
    target_compile_options(DrillPaper PRIVATE /W4 /permissive- /utf-8)
endif()
target_link_libraries(DrillPaper PRIVATE
    user32 gdi32 iphlpapi pdh ole32 shlwapi
    "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/x64/WebView2Loader.dll.lib"
)

set_target_properties(DrillPaper PROPERTIES
    CXX_EXTENSIONS OFF
)

add_custom_command(TARGET DrillPaper POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${PROJECT_SOURCE_DIR}/third_party/licenses"
        "$<TARGET_FILE_DIR:DrillPaper>/resources/licenses"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
        "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/x64/WebView2Loader.dll"
        "$<TARGET_FILE_DIR:DrillPaper>/WebView2Loader.dll"
    COMMAND "${CMAKE_COMMAND}" -E make_directory
        "$<TARGET_FILE_DIR:DrillPaper>/resources/themes/minimal/javascript"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${PROJECT_SOURCE_DIR}/sdk/examples/minimal"
        "$<TARGET_FILE_DIR:DrillPaper>/resources/themes/minimal"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${PROJECT_SOURCE_DIR}/sdk/javascript"
        "$<TARGET_FILE_DIR:DrillPaper>/resources/themes/minimal/javascript"
    COMMAND "${CMAKE_COMMAND}" -E make_directory
        "$<TARGET_FILE_DIR:DrillPaper>/resources/themes/dashboard/javascript"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${PROJECT_SOURCE_DIR}/sdk/examples/dashboard"
        "$<TARGET_FILE_DIR:DrillPaper>/resources/themes/dashboard"
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
        "${PROJECT_SOURCE_DIR}/sdk/javascript"
        "$<TARGET_FILE_DIR:DrillPaper>/resources/themes/dashboard/javascript"
    VERBATIM
)

include(CTest)
if(BUILD_TESTING)
    include(FetchContent)
    FetchContent_Declare(
        Catch2
        URL https://codeload.github.com/catchorg/Catch2/tar.gz/refs/tags/v3.8.1
        URL_HASH SHA256=18b3f70ac80fccc340d8c6ff0f339b2ae64944782f8d2fca2bd705cf47cadb79
    )
    FetchContent_MakeAvailable(Catch2)
    list(APPEND CMAKE_MODULE_PATH "${catch2_SOURCE_DIR}/extras")
    include(Catch)
    set_property(DIRECTORY APPEND PROPERTY TEST_INCLUDE_FILES
        "${PROJECT_SOURCE_DIR}/scripts/ctest-workspace.cmake")

    add_executable(DrillPaperTests
        tests/unit/core_contracts_test.cpp
        tests/unit/sampling_worker_test.cpp
        tests/unit/desktop_recovery_retry_test.cpp
        tests/unit/managed_playback_test.cpp
        tests/unit/monitor_targets_test.cpp
        tests/unit/protocol_v1_test.cpp
        src/web/protocol_v1.cpp
    )
    target_link_libraries(DrillPaperTests PRIVATE desktopmonitor_core Catch2::Catch2WithMain)
    if(MSVC)
        target_compile_options(DrillPaperTests PRIVATE /W4 /permissive- /utf-8)
    endif()
    catch_discover_tests(DrillPaperTests PROPERTIES TIMEOUT 20)

    add_executable(DrillPaperThemeTests tests/unit/theme_manager_test.cpp)
    add_executable(DrillPaperSettingsTests tests/unit/settings_store_test.cpp)
    target_link_libraries(DrillPaperSettingsTests PRIVATE desktopmonitor_settings Catch2::Catch2WithMain)
    target_compile_definitions(DrillPaperSettingsTests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    if(MSVC)
        target_compile_options(DrillPaperSettingsTests PRIVATE /W4 /permissive- /utf-8)
    endif()
    catch_discover_tests(DrillPaperSettingsTests PROPERTIES TIMEOUT 20)
    target_link_libraries(DrillPaperThemeTests PRIVATE desktopmonitor_themes Catch2::Catch2WithMain miniz)
    if(MSVC)
        target_compile_options(DrillPaperThemeTests PRIVATE /utf-8)
    endif()
    add_test(NAME DrillPaperThemeTests COMMAND DrillPaperThemeTests)
    set_tests_properties(DrillPaperThemeTests PROPERTIES TIMEOUT 60)
    add_test(NAME DrillPaperThemeCli COMMAND powershell.exe -NoProfile -ExecutionPolicy Bypass
        -File "${PROJECT_SOURCE_DIR}/scripts/test-theme-cli.ps1" -ApplicationPath "$<TARGET_FILE:DrillPaper>")
    set_tests_properties(DrillPaperThemeCli PROPERTIES TIMEOUT 60)
    # 靜態連結 CRT 後，執行檔不得再依賴 VC++ 可轉散發套件或 UCRT DLL。
    add_test(NAME DrillPaperStaticCrt COMMAND node "${PROJECT_SOURCE_DIR}/scripts/check-pe-imports.mjs" "$<TARGET_FILE:DrillPaper>")

    add_executable(DrillPaperWindowsMetricsIntegrationTests
        tests/integration/windows_metrics_collector_test.cpp
        src/monitoring/windows_metrics_collector.cpp
        src/monitoring/nvml_gpu_collector.cpp
    )
    target_compile_definitions(DrillPaperWindowsMetricsIntegrationTests PRIVATE
        UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
    )
    target_link_libraries(DrillPaperWindowsMetricsIntegrationTests PRIVATE
        desktopmonitor_core Catch2::Catch2WithMain iphlpapi pdh
    )
    if(MSVC)
        target_compile_options(DrillPaperWindowsMetricsIntegrationTests PRIVATE
            /W4 /permissive- /utf-8
        )
    endif()
    catch_discover_tests(DrillPaperWindowsMetricsIntegrationTests PROPERTIES TIMEOUT 60)
    # 受控負載的實機觀測需明確執行，不加入一般 CTest。
    add_executable(DrillPaperMetricsAccuracyProbe
        tests/integration/metrics_accuracy_probe.cpp
        src/monitoring/windows_metrics_collector.cpp
        src/monitoring/nvml_gpu_collector.cpp)
    target_compile_definitions(DrillPaperMetricsAccuracyProbe PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    target_link_libraries(DrillPaperMetricsAccuracyProbe PRIVATE desktopmonitor_core nlohmann_json::nlohmann_json iphlpapi pdh psapi)
    if(MSVC)
        target_compile_options(DrillPaperMetricsAccuracyProbe PRIVATE /W4 /permissive- /utf-8)
    endif()
    add_executable(DrillPaperWindowsHostIntegrationTests
        tests/integration/desktop_host_test.cpp
        src/platform/windows/desktop_host.cpp)
    target_compile_definitions(DrillPaperWindowsHostIntegrationTests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    target_link_libraries(DrillPaperWindowsHostIntegrationTests PRIVATE desktopmonitor_core Catch2::Catch2WithMain user32 gdi32)
    if(MSVC)
        target_compile_options(DrillPaperWindowsHostIntegrationTests PRIVATE /W4 /permissive- /utf-8)
    endif()
    catch_discover_tests(DrillPaperWindowsHostIntegrationTests TEST_SPEC "~[shell-live]" PROPERTIES TIMEOUT 20)
    add_executable(DrillPaperManagementIntegrationTests
        tests/integration/management_shell_test.cpp src/platform/windows/management_shell.cpp)
    target_compile_definitions(DrillPaperManagementIntegrationTests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    target_link_libraries(DrillPaperManagementIntegrationTests PRIVATE desktopmonitor_core Catch2::Catch2
        user32 gdi32 shell32 comdlg32 comctl32 gdiplus dwmapi)
    if(MSVC)
        target_compile_options(DrillPaperManagementIntegrationTests PRIVATE /W4 /permissive- /utf-8)
    endif()
    catch_discover_tests(DrillPaperManagementIntegrationTests PROPERTIES TIMEOUT 30 RUN_SERIAL TRUE)
    add_executable(DrillPaperParentFixture WIN32 tests/integration/parent_window_fixture.cpp)
    # 故障注入僅存在測試入口；產品 EXE 不含測試開關。
    get_target_property(_monitor_fixture_sources DrillPaper SOURCES)
    list(REMOVE_ITEM _monitor_fixture_sources src/app/main.cpp)
    add_executable(DrillPaperMonitorDegradeFixture WIN32 tests/integration/monitor_degrade_fixture.cpp ${_monitor_fixture_sources})
    target_include_directories(DrillPaperMonitorDegradeFixture PRIVATE "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/include")
    target_compile_definitions(DrillPaperMonitorDegradeFixture PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    get_target_property(_monitor_fixture_libraries DrillPaper LINK_LIBRARIES)
    target_link_libraries(DrillPaperMonitorDegradeFixture PRIVATE ${_monitor_fixture_libraries})
    if(MSVC)
        target_compile_options(DrillPaperMonitorDegradeFixture PRIVATE /W4 /permissive- /utf-8)
    endif()
    add_executable(DrillPaperMonitorIntegrationTests tests/integration/monitor_info_test.cpp src/platform/windows/monitor_info.cpp)
    target_compile_definitions(DrillPaperMonitorIntegrationTests PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    target_link_libraries(DrillPaperMonitorIntegrationTests PRIVATE desktopmonitor_core Catch2::Catch2WithMain user32 shcore)
    if(MSVC)
        target_compile_options(DrillPaperMonitorIntegrationTests PRIVATE /W4 /permissive- /utf-8)
    endif()
    catch_discover_tests(DrillPaperMonitorIntegrationTests PROPERTIES TIMEOUT 20)
    target_compile_definitions(DrillPaperParentFixture PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
    target_link_libraries(DrillPaperParentFixture PRIVATE desktopmonitor_core user32 shell32)
    if(MSVC)
        target_compile_options(DrillPaperParentFixture PRIVATE /W4 /permissive- /utf-8)
    endif()
endif()
