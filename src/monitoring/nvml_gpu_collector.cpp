#include <windows.h>

#include "desktopmonitor/monitoring/nvml_gpu_collector.h"

namespace desktopmonitor::monitoring {
namespace {
using desktopmonitor::core::MakeAvailable;
using desktopmonitor::core::MakeUnavailable;
using desktopmonitor::core::MetricUnit;

using NvmlReturn = int;
using NvmlDevice = struct NvmlDeviceOpaque*;
constexpr NvmlReturn kNvmlSuccess = 0;

struct NvmlUtilization {
    unsigned int gpu;
    unsigned int memory;
};

using NvmlInitFunction = NvmlReturn(__cdecl*)();
using NvmlShutdownFunction = NvmlReturn(__cdecl*)();
using NvmlDeviceCountFunction = NvmlReturn(__cdecl*)(unsigned int*);
using NvmlDeviceHandleFunction = NvmlReturn(__cdecl*)(unsigned int, NvmlDevice*);
using NvmlUtilizationFunction = NvmlReturn(__cdecl*)(NvmlDevice, NvmlUtilization*);

HMODULE LoadNvmlLibrary() {
    wchar_t systemDirectory[MAX_PATH]{};
    const UINT systemLength = GetSystemDirectoryW(systemDirectory, MAX_PATH);
    if (systemLength > 0 && systemLength < MAX_PATH - 10) {
        lstrcatW(systemDirectory, L"\\nvml.dll");
        HMODULE library = LoadLibraryExW(systemDirectory, nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (library != nullptr) {
            return library;
        }
    }

    wchar_t programDirectory[MAX_PATH]{};
    const DWORD programLength = GetEnvironmentVariableW(L"ProgramW6432", programDirectory, MAX_PATH);
    constexpr wchar_t kNvmlRelativePath[] = L"\\NVIDIA Corporation\\NVSMI\\nvml.dll";
    const int relativeLength = lstrlenW(kNvmlRelativePath);
    if (programLength > 0 && programLength < MAX_PATH &&
        static_cast<int>(programLength) + relativeLength < MAX_PATH) {
        lstrcatW(programDirectory, kNvmlRelativePath);
        return LoadLibraryExW(programDirectory, nullptr,
                              LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    }
    return nullptr;
}

template <typename Function>
Function ResolveFunction(HMODULE library, const char* name) {
    return reinterpret_cast<Function>(GetProcAddress(library, name));
}
} // namespace

NvmlGpuCollector::NvmlGpuCollector() {
    HMODULE library = LoadNvmlLibrary();
    if (library == nullptr) {
        return;
    }

    const auto initialize = ResolveFunction<NvmlInitFunction>(library, "nvmlInit_v2");
    const auto count = ResolveFunction<NvmlDeviceCountFunction>(library, "nvmlDeviceGetCount_v2");
    const auto handle = ResolveFunction<NvmlDeviceHandleFunction>(library,
                                                                  "nvmlDeviceGetHandleByIndex_v2");
    const auto utilization = ResolveFunction<NvmlUtilizationFunction>(
        library, "nvmlDeviceGetUtilizationRates");
    const auto shutdown = ResolveFunction<NvmlShutdownFunction>(library, "nvmlShutdown");
    if (initialize == nullptr || count == nullptr || handle == nullptr || utilization == nullptr ||
        shutdown == nullptr || initialize() != kNvmlSuccess) {
        FreeLibrary(library);
        return;
    }

    library_ = library;
    deviceCountFunction_ = reinterpret_cast<void*>(count);
    deviceHandleFunction_ = reinterpret_cast<void*>(handle);
    utilizationFunction_ = reinterpret_cast<void*>(utilization);
    shutdownFunction_ = reinterpret_cast<void*>(shutdown);
    initialized_ = true;
}

NvmlGpuCollector::~NvmlGpuCollector() {
    if (initialized_ && shutdownFunction_ != nullptr) {
        const auto shutdown = reinterpret_cast<NvmlShutdownFunction>(shutdownFunction_);
        shutdown();
    }
    if (library_ != nullptr) {
        FreeLibrary(static_cast<HMODULE>(library_));
    }
}

core::MetricValue NvmlGpuCollector::ReadGpuUtilization() {
    if (!initialized_ || deviceCountFunction_ == nullptr || deviceHandleFunction_ == nullptr ||
        utilizationFunction_ == nullptr) {
        return MakeUnavailable(MetricUnit::Percent);
    }

    const auto getCount = reinterpret_cast<NvmlDeviceCountFunction>(deviceCountFunction_);
    const auto getHandle = reinterpret_cast<NvmlDeviceHandleFunction>(deviceHandleFunction_);
    const auto getUtilization = reinterpret_cast<NvmlUtilizationFunction>(utilizationFunction_);
    unsigned int deviceCount = 0;
    if (getCount(&deviceCount) != kNvmlSuccess || deviceCount == 0) {
        return MakeUnavailable(MetricUnit::Percent);
    }

    for (unsigned int index = 0; index < deviceCount; ++index) {
        NvmlDevice device = nullptr;
        if (getHandle(index, &device) != kNvmlSuccess || device == nullptr) {
            continue;
        }
        NvmlUtilization utilization{};
        if (getUtilization(device, &utilization) == kNvmlSuccess && utilization.gpu <= 100) {
            return MakeAvailable(static_cast<double>(utilization.gpu), MetricUnit::Percent);
        }
    }
    return MakeUnavailable(MetricUnit::Percent);
}

} // namespace desktopmonitor::monitoring
