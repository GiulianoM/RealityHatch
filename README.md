# RealityHatch

Calibrated stereo-camera passthrough for OpenXR VR applications.

Created and maintained by [GiulianoM](https://github.com/GiulianoM). RealityHatch's original code, scripts and documentation are available under the [MIT License](LICENSE).

RealityHatch is a C++ OpenXR API layer being developed to display calibrated side-by-side camera imagery inside VR. The initial use is a desk-control passthrough region, activated manually or by looking down.

Compatible SBS camera modules are the intended scope. The ELP-USB3DGS1200P01-H120 is the initial test camera. Star Citizen with Vulkan and native Pimax OpenXR is the primary target environment.

## Current status

The stock Khronos hello_xr host works with Vulkan and native Pimax. The minimal diagnostic RealityHatch layer is self-signed with a locally trusted development certificate and passes loading/frame-forwarding tests with that host. SC/EAC tests failed VR initialization with a file-access error using both current-user trust and additional Local Machine trust; a no-layer control restored native Pimax VR. Camera capture and overlay rendering are not implemented yet. The user manually disabled Windows Smart App Control before development tests.

- [Requirements and research](REQUIREMENTS.md)
- [Build and run the development host](HELLO-XR.md)
- [Build, run and test the minimal API layer](LAYER-DEVELOPMENT.md)
- [Local development signing and saved diagnostics](DEVELOPMENT-SIGNING.md)
- [SC/EAC self-signed loading test and control results](SC-EAC-TEST.md)
- [Runtime composition assessment](RUNTIME-COMPOSITION.md)

Run `Run-HelloXR-Vulkan.cmd` with Pimax Play running and the headset connected. The launcher selects native Pimax for the sample process without changing the globally selected OpenXR runtime.

Use `Run-HelloXR-RealityHatch.cmd` to run the same sample with the RealityHatch layer enabled only for that launch. Timestamped diagnostics and signature/hash metadata appear in `logs\realityhatch-run-*`.

## Building from source

This repository contains the diagnostic API-layer stub, lifecycle tests, Windows build/run/signing scripts, and development findings. Start with [HELLO-XR.md](HELLO-XR.md) to obtain the pinned Khronos development host and prerequisites, then [LAYER-DEVELOPMENT.md](LAYER-DEVELOPMENT.md) to build RealityHatch. The current layer is version 0.1.2, with deferred dispatch-state construction and negotiation diagnostics.

The launchers and SC test scripts currently contain PC2-specific Pimax and game installation paths; adjust them for another machine. Development certificate creation and trust are explicit setup actions, described in [DEVELOPMENT-SIGNING.md](DEVELOPMENT-SIGNING.md).

## Third-party components

Khronos OpenXR headers, loader and hello_xr are separate upstream components with their own licensing; see the upstream license files. This repository does not include the downloaded OpenXR checkout, Vulkan SDK, vendor runtime/loader DLLs or diagnostic utilities. Fetch these separately using the build guide. RealityHatch's MIT License does not replace their licences.

Build outputs, local certificate material, machine configuration and raw diagnostic logs are excluded from Git. The checked-in development documents summarize the local experiments; paths under `logs` refer to evidence retained on the development machine.
