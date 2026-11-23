// Copyright (c) 2026 GiulianoM
// SPDX-License-Identifier: MIT
#include <openxr/openxr.h>
#include <openxr/openxr_loader_negotiation.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>

extern "C" XrResult XRAPI_CALL xrNegotiateLoaderApiLayerInterface(
    const XrNegotiateLoaderInfo*, const char*, XrNegotiateApiLayerRequest*);
namespace {
void Check(bool condition, const char* message) {
    if (!condition) { std::fprintf(stderr, "FAIL: %s\n", message); std::exit(1); }
}
uintptr_t NextHandle = 100;
const XrInstanceCreateInfo* ExpectedCreate = nullptr;
const XrSessionCreateInfo* ExpectedSessionCreate = nullptr;
const XrFrameEndInfo* ExpectedFrame = nullptr;
XrResult FrameResult = XR_SUCCESS;
XrResult DestroyResult = XR_SUCCESS;
unsigned int EndCalls = 0;
XrResult XRAPI_CALL FakeDestroyInstance(XrInstance) { return XR_SUCCESS; }
XrResult XRAPI_CALL FakeDestroySession(XrSession) { return DestroyResult; }
XrResult XRAPI_CALL FakeCreateSession(XrInstance, const XrSessionCreateInfo* info, XrSession* session) {
    Check(info == ExpectedSessionCreate, "session create info pointer changed");
    *session = reinterpret_cast<XrSession>(++NextHandle);
    return XR_SUCCESS;
}
XrResult XRAPI_CALL FakeEndFrame(XrSession, const XrFrameEndInfo* info) {
    Check(info == ExpectedFrame, "frame-end info pointer changed");
    ++EndCalls;
    return FrameResult;
}
void XRAPI_CALL FakeExtension() {}
XrResult XRAPI_CALL FakeGetProc(XrInstance, const char* name, PFN_xrVoidFunction* function) {
    if (std::strcmp(name, "xrDestroyInstance") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(FakeDestroyInstance);
    else if (std::strcmp(name, "xrCreateSession") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(FakeCreateSession);
    else if (std::strcmp(name, "xrDestroySession") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(FakeDestroySession);
    else if (std::strcmp(name, "xrEndFrame") == 0) *function = reinterpret_cast<PFN_xrVoidFunction>(FakeEndFrame);
    else if (std::strcmp(name, "xrRealityHatchMockExtension") == 0) *function = FakeExtension;
    else { *function = nullptr; return XR_ERROR_FUNCTION_UNSUPPORTED; }
    return XR_SUCCESS;
}
XrResult XRAPI_CALL FakeCreateInstance(const XrInstanceCreateInfo* info, const XrApiLayerCreateInfo* layer, XrInstance* instance) {
    Check(info == ExpectedCreate, "instance create info pointer changed");
    Check(layer->nextInfo == nullptr, "layer did not advance the next-info chain");
    *instance = reinterpret_cast<XrInstance>(++NextHandle);
    return XR_SUCCESS;
}
template<typename T>
T Proc(const XrNegotiateApiLayerRequest& layer, XrInstance instance, const char* name) {
    PFN_xrVoidFunction function = nullptr;
    Check(layer.getInstanceProcAddr(instance, name, &function) == XR_SUCCESS && function, name);
    return reinterpret_cast<T>(function);
}
} // namespace

int main() {
    XrNegotiateLoaderInfo loader{};
    loader.structType = XR_LOADER_INTERFACE_STRUCT_LOADER_INFO;
    loader.structVersion = XR_LOADER_INFO_STRUCT_VERSION;
    loader.structSize = sizeof(loader);
    loader.minInterfaceVersion = loader.maxInterfaceVersion = XR_CURRENT_LOADER_API_LAYER_VERSION;
    loader.minApiVersion = XR_MAKE_VERSION(1, 0, 0);
    loader.maxApiVersion = XR_CURRENT_API_VERSION;
    XrNegotiateApiLayerRequest layer{};
    layer.structType = XR_LOADER_INTERFACE_STRUCT_API_LAYER_REQUEST;
    layer.structVersion = XR_API_LAYER_INFO_STRUCT_VERSION;
    layer.structSize = sizeof(layer);
    const char* name = "XR_APILAYER_NOVENDOR_realityhatch";
    Check(xrNegotiateLoaderApiLayerInterface(nullptr, name, &layer) == XR_ERROR_INITIALIZATION_FAILED, "null negotiation");
    Check(xrNegotiateLoaderApiLayerInterface(&loader, nullptr, &layer) == XR_ERROR_INITIALIZATION_FAILED, "null layer name");
    Check(xrNegotiateLoaderApiLayerInterface(&loader, name, nullptr) == XR_ERROR_INITIALIZATION_FAILED, "null request");
    Check(xrNegotiateLoaderApiLayerInterface(&loader, "wrong", &layer) == XR_ERROR_INITIALIZATION_FAILED, "wrong layer name");
    auto invalidLoader = loader;
    invalidLoader.structSize = 0;
    Check(xrNegotiateLoaderApiLayerInterface(&invalidLoader, name, &layer) == XR_ERROR_INITIALIZATION_FAILED, "invalid loader header");
    invalidLoader = loader;
    invalidLoader.minApiVersion = XR_MAKE_VERSION(2, 0, 0);
    Check(xrNegotiateLoaderApiLayerInterface(&invalidLoader, name, &layer) == XR_ERROR_INITIALIZATION_FAILED, "unsupported API range");
    auto invalidRequest = layer;
    invalidRequest.structVersion = 0;
    Check(xrNegotiateLoaderApiLayerInterface(&loader, name, &invalidRequest) == XR_ERROR_INITIALIZATION_FAILED, "invalid request header");
    Check(xrNegotiateLoaderApiLayerInterface(&loader, name, &layer) == XR_SUCCESS, "negotiation");

    XrApiLayerNextInfo next{};
    next.structType = XR_LOADER_INTERFACE_STRUCT_API_LAYER_NEXT_INFO;
    next.structVersion = XR_API_LAYER_NEXT_INFO_STRUCT_VERSION;
    next.structSize = sizeof(next);
    strcpy_s(next.layerName, name);
    next.nextGetInstanceProcAddr = FakeGetProc;
    next.nextCreateApiLayerInstance = FakeCreateInstance;
    XrApiLayerCreateInfo chain{};
    chain.structType = XR_LOADER_INTERFACE_STRUCT_API_LAYER_CREATE_INFO;
    chain.structVersion = XR_API_LAYER_CREATE_INFO_STRUCT_VERSION;
    chain.structSize = sizeof(chain);
    chain.nextInfo = &next;
    XrInstanceCreateInfo create{XR_TYPE_INSTANCE_CREATE_INFO};
    ExpectedCreate = &create;
    XrInstance a{}, b{};
    Check(layer.createApiLayerInstance(&create, &chain, &a) == XR_SUCCESS, "create instance A");
    Check(layer.createApiLayerInstance(&create, &chain, &b) == XR_SUCCESS, "create instance B");
    Check(chain.nextInfo == &next, "original creation chain mutated");
    Check(Proc<PFN_xrVoidFunction>(layer, a, "xrRealityHatchMockExtension") == FakeExtension, "extension forwarding");
    PFN_xrVoidFunction unknown = nullptr;
    Check(layer.getInstanceProcAddr(a, "xrUnknown", &unknown) == XR_ERROR_FUNCTION_UNSUPPORTED && !unknown, "unknown command result");
    XrSessionCreateInfo sessionCreate{XR_TYPE_SESSION_CREATE_INFO};
    ExpectedSessionCreate = &sessionCreate;
    XrSession sa{}, sb{};
    Check(Proc<PFN_xrCreateSession>(layer, a, "xrCreateSession")(a, &sessionCreate, &sa) == XR_SUCCESS, "create session A");
    Check(Proc<PFN_xrCreateSession>(layer, b, "xrCreateSession")(b, &sessionCreate, &sb) == XR_SUCCESS, "create session B");
    XrCompositionLayerProjection projection{XR_TYPE_COMPOSITION_LAYER_PROJECTION};
    const XrCompositionLayerBaseHeader* layers[] = {reinterpret_cast<const XrCompositionLayerBaseHeader*>(&projection)};
    XrFrameEndInfo frame{XR_TYPE_FRAME_END_INFO};
    frame.displayTime = 123456;
    frame.layerCount = 1;
    frame.layers = layers;
    ExpectedFrame = &frame;
    auto end = Proc<PFN_xrEndFrame>(layer, a, "xrEndFrame");
    Check(end(sa, &frame) == XR_SUCCESS, "successful end frame");
    FrameResult = XR_ERROR_TIME_INVALID;
    Check(end(sa, &frame) == XR_ERROR_TIME_INVALID, "failed frame result changed");
    Check(frame.layers == layers && frame.layerCount == 1 && frame.displayTime == 123456, "frame data changed");
    Check(EndCalls == 2, "frame forwarded more than once");
    FrameResult = XR_SUCCESS;
    auto destroySession = Proc<PFN_xrDestroySession>(layer, a, "xrDestroySession");
    DestroyResult = XR_ERROR_RUNTIME_FAILURE;
    Check(destroySession(sa) == XR_ERROR_RUNTIME_FAILURE, "failed destroy result changed");
    Check(end(sa, &frame) == XR_SUCCESS, "failed destruction lost session dispatch");
    DestroyResult = XR_SUCCESS;
    Check(destroySession(sa) == XR_SUCCESS, "destroy session A");
    Check(end(sa, &frame) == XR_ERROR_HANDLE_INVALID, "destroyed session retained");
    auto destroyInstance = Proc<PFN_xrDestroyInstance>(layer, a, "xrDestroyInstance");
    Check(destroyInstance(a) == XR_SUCCESS, "destroy instance A");
    Check(end(sb, &frame) == XR_SUCCESS, "instance A teardown broke instance B");
    destroyInstance = Proc<PFN_xrDestroyInstance>(layer, b, "xrDestroyInstance");
    Check(destroyInstance(b) == XR_SUCCESS, "destroy instance B with child session");
    Check(end(sb, &frame) == XR_ERROR_HANDLE_INVALID, "instance destruction retained child session");
    std::puts("PASS: negotiation, chained creation, unchanged frame data/results, extension forwarding, failed destruction, multi-instance lifecycle");
}
