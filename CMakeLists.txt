cmake_minimum_required(VERSION 3.25)

project(DrillPaper VERSION 0.1.0 LANGUAGES CXX)

if(NOT WIN32)
    message(FATAL_ERROR "DrillPaper is a Windows-only application.")
endif()
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "DrillPaper currently supports Windows x64 builds only.")
endif()

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

add_executable(DrillPaper WIN32
    src/app/main.cpp
    src/platform/windows/desktop_host.cpp
    src/monitoring/windows_metrics_collector.cpp
    src/monitoring/nvml_gpu_collector.cpp
    src/web/protocol_v1.cpp
    src/web/webview2_host.cpp
)
target_include_directories(DrillPaper PRIVATE
    "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/include"
)
target_compile_definitions(DrillPaper PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
target_link_libraries(DrillPaper PRIVATE desktopmonitor_core)
if(MSVC)
    target_compile_options(DrillPaper PRIVATE /W4 /permissive- /utf-8)
endif()
target_link_libraries(DrillPaper PRIVATE
    user32 gdi32 iphlpapi pdh ole32
    "${DRILLPAPER_WEBVIEW2_SDK_ROOT}/build/native/x64/WebView2Loader.dll.lib"
)

set_target_properties(DrillPaper PROPERTIES
    CXX_EXTENSIONS OFF
    MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
)

add_custom_command(TARGET DrillPaper POST_BUILD
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
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v3.8.1
        GIT_SHALLOW TRUE
    )
    FetchContent_MakeAvailable(Catch2)
    list(APPEND CMAKE_MODULE_PATH "${catch2_SOURCE_DIR}/extras")
    include(Catch)

    add_executable(DrillPaperTests
        tests/unit/core_contracts_test.cpp
        tests/unit/protocol_v1_test.cpp
        src/web/protocol_v1.cpp
    )
    target_link_libraries(DrillPaperTests PRIVATE desktopmonitor_core Catch2::Catch2WithMain)
    catch_discover_tests(DrillPaperTests)

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
    catch_discover_tests(DrillPaperWindowsMetricsIntegrationTests)
endif()
