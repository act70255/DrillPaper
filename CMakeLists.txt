cmake_minimum_required(VERSION 3.25)

project(DesktopMonitor VERSION 0.1.0 LANGUAGES CXX)

if(NOT WIN32)
    message(FATAL_ERROR "DesktopMonitor is a Windows-only application.")
endif()

add_executable(DesktopMonitor WIN32
    src/app/main.cpp
)
target_compile_features(DesktopMonitor PRIVATE cxx_std_20)
target_compile_definitions(DesktopMonitor PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX)
if(MSVC)
    target_compile_options(DesktopMonitor PRIVATE /W4 /permissive- /utf-8)
endif()
target_link_libraries(DesktopMonitor PRIVATE user32 gdi32)

set_target_properties(DesktopMonitor PROPERTIES
    CXX_EXTENSIONS OFF
    MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
)
