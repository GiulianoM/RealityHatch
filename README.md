# RealityHatch

Calibrated stereo-camera passthrough for OpenXR VR applications.

Created and maintained by [GiulianoM](https://github.com/GiulianoM). RealityHatch's original code, scripts and documentation are available under the [MIT License](LICENSE).

RealityHatch is a C++ OpenXR API layer being developed to display calibrated side-by-side camera imagery inside VR. The initial use is a desk-control passthrough window in the lower center of the VR view, toggled with Left Alt + V. The planned window uses native camera per-eye resolution; activation is hotkey-only.

Compatible SBS camera modules are the intended scope. The ELP-USB3DGS1200P01-H120 is the initial test camera. Star Citizen with Vulkan and native Pimax OpenXR is the primary target environment.

## Current status

Updated 27 November 2026. **The Certum-signed diagnostic layer loads successfully in Star Citizen with EAC enabled and native Pimax OpenXR.**

- Implemented: C++ API-layer stub, deferred dispatch initialization, negotiation/lifecycle/frame diagnostics, and smartcard signing with verified timestamps.
- Validated: normal SC LIVE `4.10.3-live.13220821` launcher startup with Vulkan/native Pimax, successful OpenXR negotiation and session creation, and at least **8,400 successful frame forwards** without logged layer errors during capture. The game UI was confirmed visible in the headset.
- Development host: Khronos hello_xr works with Vulkan/native Pimax; the layer previously passed loading and frame-forwarding tests there using its development signature.
- Planned: calibrated SBS camera capture and stereo overlay rendering, with **Left Alt + V** toggling a lower-center camera-resolution window. Hotkey handling, camera capture and overlay rendering are not implemented yet.

This is a startup/menu test of the diagnostic layer, not a gameplay-server or camera-passthrough validation. Earlier locally trusted self-signed SC/EAC tests failed before OpenXR negotiation. See the test report for configuration, comparison and limitations. Raw logs, certificates and built binaries remain local.

- [Requirements and research](REQUIREMENTS.md)
- [Build and run the development host](HELLO-XR.md)
- [Build, run and test the minimal API layer](LAYER-DEVELOPMENT.md)
- [Certum and development signing, with saved diagnostics](DEVELOPMENT-SIGNING.md)
- [SC/EAC public-signed success and earlier self-signed results](SC-EAC-TEST.md)
- [Runtime composition assessment](RUNTIME-COMPOSITION.md)

Run `Run-HelloXR-Vulkan.cmd` with Pimax Play running and the headset connected. The launcher selects native Pimax for the sample process without changing the globally selected OpenXR runtime.

Use `Run-HelloXR-RealityHatch.cmd` to run the same sample with the RealityHatch layer enabled only for that launch. Timestamped diagnostics and signature/hash metadata appear in `logs\realityhatch-run-*`.

## Building from source

This repository contains the diagnostic API-layer stub, lifecycle tests, Windows build/run/signing scripts, and development findings. Start with [HELLO-XR.md](HELLO-XR.md) to obtain the pinned Khronos development host and prerequisites, then [LAYER-DEVELOPMENT.md](LAYER-DEVELOPMENT.md) to build RealityHatch. The current layer is version 0.1.2, with deferred dispatch-state construction and negotiation diagnostics.

The launchers and SC test scripts currently contain PC2-specific Pimax and game installation paths; adjust them for another machine. Development certificate creation and trust are explicit setup actions, described in [DEVELOPMENT-SIGNING.md](DEVELOPMENT-SIGNING.md).

## AI-assisted development

RealityHatch is developed with assistance from OpenAI Codex and other AI tools, including contributions to code, scripts, documentation, research, and debugging. AI-assisted work can contain errors; its use does not establish correctness, hardware compatibility, or anti-cheat acceptance. Feature and test claims should be read alongside the documented validation results and known limitations.

Commits made with Codex assistance include a `Co-authored-by: Codex <codex@openai.com>` trailer. This attribution does not imply endorsement by OpenAI.

## Third-party components

Khronos OpenXR headers, loader and hello_xr are separate upstream components with their own licensing; see the upstream license files. This repository does not include the downloaded OpenXR checkout, Vulkan SDK, vendor runtime/loader DLLs or diagnostic utilities. Fetch these separately using the build guide. RealityHatch's MIT License does not replace their licences.

Build outputs, local certificate material, machine configuration and raw diagnostic logs are excluded from Git. The checked-in development documents summarize the local experiments; paths under `logs` refer to evidence retained on the development machine.
