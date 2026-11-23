// Copyright (c) 2026 GiulianoM
// SPDX-License-Identifier: MIT
#include <windows.h>
#include <openxr/openxr.h>
#include <openxr/openxr_loader_negotiation.h>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <memory>
#include <mutex>
#include <new>
#include <unordered_map>

namespace {
constexpr char LayerName[] = "XR_APILAYER_NOVENDOR_realityhatch";

// No file I/O or OpenXR work is performed from DllMain. An explicit log path
// overrides the per-user fallback, so future non-sample launches also log.
bool LogPath(wchar_t* path, DWORD capacity) noexcept {
    const DWORD supplied = GetEnvironmentVariableW(L"REALITYHATCH_LOG", path, capacity);
    if (supplied > 0) return supplied < capacity;
    wchar_t local[32768];
    const DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", local, 32768);
    if (length == 0 || length >= 32768) return false;
    wchar_t folder[32768];
    if (swprintf_s(folder, L"%s\\RealityHatch", local) < 0) return false;
    if (!CreateDirectoryW(folder, nullptr) && GetLastError() != ERROR_ALREADY_EXISTS) return false;
    if (swprintf_s(folder, L"%s\\RealityHatch\\logs", local) < 0) return false;
    if (!CreateDirectoryW(folder, nullptr) && GetLastError() != ERROR_ALREADY_EXISTS) return false;
    SYSTEMTIME time{};
    GetSystemTime(&time);
    return swprintf_s(path, capacity, L"%s\\layer-%04u%02u%02u-%lu.log", folder,
                      time.wYear, time.wMonth, time.wDay, GetCurrentProcessId()) >= 0;
}

void Log(const char* event, XrResult result = XR_SUCCESS, unsigned long long count = 0,
         unsigned int layers = 0, const char* details = "") noexcept {
    SYSTEMTIME time{};
    GetSystemTime(&time);
    char line[4096];
    const int size = std::snprintf(line, sizeof(line),
        "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ pid=%lu event=%s result=%d count=%llu layers=%u %s\r\n",
        time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute, time.wSecond,
        time.wMilliseconds, GetCurrentProcessId(), event, static_cast<int>(result), count, layers, details);
    if (size > 0 && static_cast<size_t>(size) < sizeof(line)) {
        // External Win32 debug capture remains useful even if file logging fails.
        OutputDebugStringA(line);
        wchar_t path[32768];
        if (!LogPath(path, 32768)) {
            OutputDebugStringA("RealityHatch log_path_unavailable\r\n");
            return;
        }
        HANDLE file = CreateFileW(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                  nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (file == INVALID_HANDLE_VALUE) {
            char error[128];
            std::snprintf(error, sizeof(error), "RealityHatch log_file_open_failed win32_error=%lu\r\n", GetLastError());
            OutputDebugStringA(error);
            return;
        }
        DWORD written = 0;
        if (!WriteFile(file, line, static_cast<DWORD>(size), &written, nullptr)) {
            char error[128];
            std::snprintf(error, sizeof(error), "RealityHatch log_file_write_failed win32_error=%lu\r\n", GetLastError());
            OutputDebugStringA(error);
        }
        CloseHandle(file);
    }
}

struct Instance {
    PFN_xrGetInstanceProcAddr getProc = nullptr;
    PFN_xrDestroyInstance destroy = nullptr;
    PFN_xrCreateSession createSession = nullptr;
    PFN_xrDestroySession destroySession = nullptr;
    PFN_xrEndFrame endFrame = nullptr;
};
struct Session {
    XrInstance owner = XR_NULL_HANDLE;
    std::shared_ptr<Instance> dispatch;
    std::atomic<unsigned long long> frames{0};
};
struct DispatchState {
    std::mutex mutex;
    std::unordered_map<XrInstance, std::shared_ptr<Instance>> instances;
    std::unordered_map<XrSession, std::shared_ptr<Session>> sessions;
    DispatchState() { Log("dispatch_state_constructed"); }
};

DispatchState& State() {
    // No namespace-scope C++ dispatch objects are constructed during DLL load.
    // C++ guarantees thread-safe construction on the first state access.
    static DispatchState registry;
    return registry;
}

std::shared_ptr<Instance> FindInstance(XrInstance instance) {
    auto& registry = State();
    std::lock_guard<std::mutex> lock(registry.mutex);
    auto found = registry.instances.find(instance);
    return found == registry.instances.end() ? nullptr : found->second;
}
std::shared_ptr<Session> FindSession(XrSession session) {
    auto& registry = State();
    std::lock_guard<std::mutex> lock(registry.mutex);
    auto found = registry.sessions.find(session);
    return found == registry.sessions.end() ? nullptr : found->second;
}

XrResult XRAPI_CALL EndFrame(XrSession session, const XrFrameEndInfo* info) {
    try {
        auto state = FindSession(session);
        if (!state) return XR_ERROR_HANDLE_INVALID;
        // Preserve the original structure, layer pointers, timing and result.
        const XrResult result = state->dispatch->endFrame(session, info);
        const auto count = ++state->frames;
        if (count == 1 || count % 300 == 0 || XR_FAILED(result)) {
            Log("end_frame_forwarded", result, count, info ? info->layerCount : 0);
        }
        return result;
    } catch (...) { return XR_ERROR_RUNTIME_FAILURE; }
}

XrResult XRAPI_CALL DestroySession(XrSession session) {
    try {
        auto state = FindSession(session);
        if (!state) return XR_ERROR_HANDLE_INVALID;
        const XrResult result = state->dispatch->destroySession(session);
        Log("session_destroyed", result, state->frames.load());
        if (XR_SUCCEEDED(result)) {
            auto& registry = State();
            std::lock_guard<std::mutex> lock(registry.mutex);
            registry.sessions.erase(session);
        }
        return result;
    } catch (...) { return XR_ERROR_RUNTIME_FAILURE; }
}

XrResult XRAPI_CALL CreateSession(XrInstance instance, const XrSessionCreateInfo* info, XrSession* session) {
    try {
        auto dispatch = FindInstance(instance);
        if (!dispatch) return XR_ERROR_HANDLE_INVALID;
        // Allocate before creating the runtime object, so an allocation failure
        // cannot lose ownership of a newly created session.
        auto state = std::make_shared<Session>();
        state->owner = instance;
        state->dispatch = dispatch;
        const XrResult result = dispatch->createSession(instance, info, session);
        if (XR_FAILED(result)) { Log("session_create_failed", result); return result; }
        try {
            auto& registry = State();
            std::lock_guard<std::mutex> lock(registry.mutex);
            registry.sessions.emplace(*session, state);
        } catch (...) {
            dispatch->destroySession(*session);
            *session = XR_NULL_HANDLE;
            return XR_ERROR_OUT_OF_MEMORY;
        }
        Log("session_created", result);
        return result;
    } catch (const std::bad_alloc&) { return XR_ERROR_OUT_OF_MEMORY; }
      catch (...) { return XR_ERROR_RUNTIME_FAILURE; }
}

XrResult XRAPI_CALL DestroyInstance(XrInstance instance) {
    try {
        auto dispatch = FindInstance(instance);
        if (!dispatch) return XR_ERROR_HANDLE_INVALID;
        const XrResult result = dispatch->destroy(instance);
        if (XR_SUCCEEDED(result)) {
            auto& registry = State();
            std::lock_guard<std::mutex> lock(registry.mutex);
            for (auto item = registry.sessions.begin(); item != registry.sessions.end();) {
                if (item->second->owner == instance) item = registry.sessions.erase(item);
                else ++item;
            }
            registry.instances.erase(instance);
        }
        Log("instance_destroyed", result);
        return result;
    } catch (...) { return XR_ERROR_RUNTIME_FAILURE; }
}

XrResult XRAPI_CALL CreateInstanceNotUsed(const XrInstanceCreateInfo*, XrInstance*) {
    // The loader calls CreateApiLayerInstance instead.
    return XR_ERROR_FUNCTION_UNSUPPORTED;
}

XrResult XRAPI_CALL GetInstanceProcAddr(XrInstance instance, const char* name, PFN_xrVoidFunction* function) {
    if (!name || !function) return XR_ERROR_VALIDATION_FAILURE;
    *function = nullptr;
    if (std::strcmp(name, "xrGetInstanceProcAddr") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(GetInstanceProcAddr);
        return XR_SUCCESS;
    }
    if (std::strcmp(name, "xrCreateInstance") == 0) {
        *function = reinterpret_cast<PFN_xrVoidFunction>(CreateInstanceNotUsed);
        return XR_SUCCESS;
    }
    try {
        auto dispatch = FindInstance(instance);
        if (!dispatch) return XR_ERROR_HANDLE_INVALID;
        const XrResult result = dispatch->getProc(instance, name, function);
        if (XR_FAILED(result)) return result;
        if (std::strcmp(name, "xrDestroyInstance") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(DestroyInstance);
        else if (std::strcmp(name, "xrCreateSession") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(CreateSession);
        else if (std::strcmp(name, "xrDestroySession") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(DestroySession);
        else if (std::strcmp(name, "xrEndFrame") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(EndFrame);
        return result;
    } catch (...) { return XR_ERROR_RUNTIME_FAILURE; }
}

template<typename T>
bool Load(PFN_xrGetInstanceProcAddr getProc, XrInstance instance, const char* name, T& output) {
    PFN_xrVoidFunction function = nullptr;
    if (XR_FAILED(getProc(instance, name, &function)) || !function) return false;
    output = reinterpret_cast<T>(function);
    return true;
}

XrResult XRAPI_CALL CreateApiLayerInstance(const XrInstanceCreateInfo* info,
                                          const XrApiLayerCreateInfo* layerInfo, XrInstance* instance) {
    if (!info || !instance || !layerInfo ||
        layerInfo->structType != XR_LOADER_INTERFACE_STRUCT_API_LAYER_CREATE_INFO ||
        layerInfo->structVersion != XR_API_LAYER_CREATE_INFO_STRUCT_VERSION ||
        layerInfo->structSize != sizeof(XrApiLayerCreateInfo) || !layerInfo->nextInfo) {
        return XR_ERROR_INITIALIZATION_FAILED;
    }
    const auto* next = layerInfo->nextInfo;
    if (next->structType != XR_LOADER_INTERFACE_STRUCT_API_LAYER_NEXT_INFO ||
        next->structVersion != XR_API_LAYER_NEXT_INFO_STRUCT_VERSION ||
        next->structSize != sizeof(XrApiLayerNextInfo) ||
        std::strcmp(next->layerName, LayerName) != 0 ||
        !next->nextGetInstanceProcAddr || !next->nextCreateApiLayerInstance) {
        return XR_ERROR_INITIALIZATION_FAILED;
    }
    try {
        Log("dispatch_state_initializing");
        auto& registry = State();
        Log("dispatch_state_ready");
        auto dispatch = std::make_shared<Instance>();
        dispatch->getProc = next->nextGetInstanceProcAddr;
        XrApiLayerCreateInfo forwarded = *layerInfo;
        forwarded.nextInfo = next->next;
        const XrResult result = next->nextCreateApiLayerInstance(info, &forwarded, instance);
        if (XR_FAILED(result)) { Log("instance_create_failed", result); return result; }
        if (!Load(dispatch->getProc, *instance, "xrDestroyInstance", dispatch->destroy)) {
            Log("missing_destroy_instance", XR_ERROR_INITIALIZATION_FAILED);
            return XR_ERROR_INITIALIZATION_FAILED;
        }
        if (!Load(dispatch->getProc, *instance, "xrCreateSession", dispatch->createSession) ||
            !Load(dispatch->getProc, *instance, "xrDestroySession", dispatch->destroySession) ||
            !Load(dispatch->getProc, *instance, "xrEndFrame", dispatch->endFrame)) {
            dispatch->destroy(*instance);
            *instance = XR_NULL_HANDLE;
            return XR_ERROR_INITIALIZATION_FAILED;
        }
        try {
            std::lock_guard<std::mutex> lock(registry.mutex);
            registry.instances.emplace(*instance, dispatch);
        } catch (...) {
            dispatch->destroy(*instance);
            *instance = XR_NULL_HANDLE;
            return XR_ERROR_OUT_OF_MEMORY;
        }
        Log("instance_created", result);
        PFN_xrGetInstanceProperties getProperties = nullptr;
        if (Load(dispatch->getProc, *instance, "xrGetInstanceProperties", getProperties)) {
            XrInstanceProperties properties{XR_TYPE_INSTANCE_PROPERTIES};
            if (XR_SUCCEEDED(getProperties(*instance, &properties))) {
                char details[512];
                std::snprintf(details, sizeof(details), "runtime=%.*s runtime_version=%llu",
                    XR_MAX_RUNTIME_NAME_SIZE, properties.runtimeName,
                    static_cast<unsigned long long>(properties.runtimeVersion));
                Log("runtime_properties", XR_SUCCESS, 0, 0, details);
            }
        }
        return result;
    } catch (const std::bad_alloc&) { return XR_ERROR_OUT_OF_MEMORY; }
      catch (...) { return XR_ERROR_RUNTIME_FAILURE; }
}
} // namespace

extern "C" __declspec(dllexport) XrResult XRAPI_CALL xrNegotiateLoaderApiLayerInterface(
    const XrNegotiateLoaderInfo* loader, const char* name, XrNegotiateApiLayerRequest* request) {
    constexpr XrVersion supported = XR_MAKE_VERSION(1, 1, 0);
    // This marker precedes every validation branch, including null arguments.
    Log("negotiation_entered", XR_SUCCESS, 0, 0, "version=0.1.2 variant=deferred_state arch=x64 build=" __DATE__ "_" __TIME__);
    const auto reject = [](const char* reason) {
        Log("negotiation_validation_failed", XR_ERROR_INITIALIZATION_FAILED, 0, 0, reason);
        return XR_ERROR_INITIALIZATION_FAILED;
    };
    if (!loader) return reject("reason=null_loader");
    if (!name) return reject("reason=null_layer_name");
    if (!request) return reject("reason=null_request");
    if (std::strcmp(name, LayerName) != 0) return reject("reason=layer_name_mismatch");
    char inputs[512];
    std::snprintf(inputs, sizeof(inputs),
        "loader_type=%d loader_version=%u loader_size=%zu request_type=%d request_version=%u request_size=%zu",
        static_cast<int>(loader->structType), loader->structVersion, loader->structSize,
        static_cast<int>(request->structType), request->structVersion, request->structSize);
    Log("negotiation_headers", XR_SUCCESS, 0, 0, inputs);
    if (loader->structType != XR_LOADER_INTERFACE_STRUCT_LOADER_INFO) return reject("reason=loader_struct_type");
    if (loader->structVersion != XR_LOADER_INFO_STRUCT_VERSION) return reject("reason=loader_struct_version");
    if (loader->structSize != sizeof(*loader)) return reject("reason=loader_struct_size");
    if (request->structType != XR_LOADER_INTERFACE_STRUCT_API_LAYER_REQUEST) return reject("reason=request_struct_type");
    if (request->structVersion != XR_API_LAYER_INFO_STRUCT_VERSION) return reject("reason=request_struct_version");
    if (request->structSize != sizeof(*request)) return reject("reason=request_struct_size");
    std::snprintf(inputs, sizeof(inputs),
        "interface_min=%u interface_max=%u interface_supported=%u api_min=%llu api_max=%llu api_supported=%llu",
        loader->minInterfaceVersion, loader->maxInterfaceVersion, XR_CURRENT_LOADER_API_LAYER_VERSION,
        static_cast<unsigned long long>(loader->minApiVersion), static_cast<unsigned long long>(loader->maxApiVersion),
        static_cast<unsigned long long>(supported));
    Log("negotiation_versions", XR_SUCCESS, 0, 0, inputs);
    if (loader->minInterfaceVersion > XR_CURRENT_LOADER_API_LAYER_VERSION) return reject("reason=interface_min_too_high");
    if (loader->maxInterfaceVersion < XR_CURRENT_LOADER_API_LAYER_VERSION) return reject("reason=interface_max_too_low");
    if (loader->minApiVersion > supported) return reject("reason=api_min_too_high");
    if (loader->maxApiVersion < XR_MAKE_VERSION(1, 0, 0)) return reject("reason=api_max_too_low");
    request->layerInterfaceVersion = XR_CURRENT_LOADER_API_LAYER_VERSION;
    request->layerApiVersion = loader->maxApiVersion < supported ? loader->maxApiVersion : supported;
    request->getInstanceProcAddr = GetInstanceProcAddr;
    request->createApiLayerInstance = CreateApiLayerInstance;
    Log("loader_negotiated");
    Log("component_version", XR_SUCCESS, 0, 0, "version=0.1.2 variant=deferred_state arch=x64 build=" __DATE__ "_" __TIME__);
    return XR_SUCCESS;
}
