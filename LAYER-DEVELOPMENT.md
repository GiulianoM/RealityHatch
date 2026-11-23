# RealityHatch minimal OpenXR layer

The first development milestone is a C++ diagnostic API layer. It loads through the standard OpenXR loader, forwards calls, and records successful creation and frame submission. It does not capture a camera or draw an overlay yet.

## Build and run

Build the hello_xr host first if the generated Khronos headers are missing, then:

```powershell
.\Build-RealityHatch.ps1
.\Run-HelloXR-RealityHatch.cmd
```

Output: `bin\layers\RealityHatchLayer.dll` and `bin\layers\RealityHatch.json`.

The launcher selects Vulkan2 and native Pimax, and enables `XR_APILAYER_NOVENDOR_realityhatch` for that process only using `XR_API_LAYER_PATH` and `XR_ENABLE_API_LAYERS`. Nothing is registered in the Windows OpenXR layer registry. The ordinary `Run-HelloXR-Vulkan.cmd` continues to launch the host without requesting RealityHatch.

Manual launches save unique `logs\realityhatch-run-*` layer, console and launcher logs plus JSON containing the DLL hash and signer identity. Events include loader negotiation, build/version, runtime properties, instance/session creation, the first and every 300th `xrEndFrame`, frame errors, and destruction. Each record contains UTC time, PID, result, count and submitted layer count. Without `REALITYHATCH_LOG`, the layer writes to `%LOCALAPPDATA%\RealityHatch\logs\layer-YYYYMMDD-PID.log`. Logs are best-effort; file I/O failures do not change forwarded API results. No logging takes place inside DllMain.

## Behavior

- Intercepts the loader/API-layer negotiation and chained instance creation.
- Tracks dispatch separately for each instance and session.
- Wraps `xrCreateSession`, `xrDestroySession`, `xrDestroyInstance` and `xrEndFrame`.
- Forwards other function lookups, including unknown extensions, to the next layer/runtime.
- Passes application creation and frame submission structures unchanged. It does not modify swapchains, images, frame timing, layer arrays, or game code.
- Uses a statically linked C++ runtime to avoid extra development DLL dependencies.
- Version 0.1.1 logs `negotiation_entered` before argument validation, input headers/version ranges, and a specific `negotiation_validation_failed` reason for each rejected check. Records go to both the log file and Windows `OutputDebugString`; file-path/open/write failures also emit debug diagnostics. No logging is performed from DllMain.
- Version 0.1.2 (`deferred_state`) moves the namespace-scope dispatch mutex/maps into a function-local `DispatchState`. Normal construction starts in chained instance creation, after negotiation, with `dispatch_state_initializing`, `dispatch_state_constructed` and `dispatch_state_ready` markers. First use is thread-safe; dispatch/lifecycle behavior is preserved. The static CRT remains in use, so this isolates application dispatch-state constructors rather than all CRT initialization.

## Tests

```powershell
.\Test-RealityHatch.ps1
```

`-SampleDirectory <isolated-directory>` selects an alternate hello_xr executable and adjacent loader without modifying the standard sample or game installation. Test metadata records the adjacent loader's path, version and SHA-256. The SC 1.1.60 loader comparison uses `logs\matched-loader-20261123-155909\sample`.

This starts its own hello_xr instance for 12 seconds, selects the native Pimax manifest, enables RealityHatch, captures uniquely named logs, and stops only the test process if it is still running. It restores the caller's environment variables. A pass requires successful instance/session creation, an `xrEndFrame` returning `XR_SUCCESS`, and loader confirmation of the Pimax manifest. The sample's redirected console output can remain buffered, so the test uses the loader's runtime-load message rather than relying on hello_xr's later runtime-name message.

Forwarding/lifecycle tests are built as `build\realityhatch\Release\RealityHatchDispatchTests.exe`. They exercise the same layer source against a mock downstream implementation. CTest registers them as `dispatch-forwarding`. They check invalid negotiation, creation-chain advancement, extension forwarding, preservation of frame pointers/data/results, single downstream frame calls, failed session destruction, multiple instances, and cleanup of child dispatch after instance destruction.

## Verified on PC2, 23 November 2026

- x64 Release build succeeds, without compiler warnings.
- Dispatch tests: 1/1 passed.
- Initial real DLL test found the manifest but Windows Smart App Control rejected the unsigned layer before its code executed. Code Integrity events 3033/3077 identified `VerifiedAndReputableDesktop` and status `0xc0e90002`.
- The user then reported disabling Smart App Control manually. The agent made no Windows security-policy or certificate-trust changes.
- Live rerun passed with the unsigned layer and native Pimax Vulkan2. Evidence: `logs\realityhatch-test-20261123-141427-962.layer.log` plus matching stdout/stderr logs. Events `loader_negotiated`, `instance_created`, `session_created`, and `end_frame_forwarded` all recorded result 0; the frame had one submitted composition layer.
- hello_xr's baseline scene was visually confirmed working by the user before this milestone. Visual confirmation with the diagnostic layer enabled remains for the user; the layer currently draws nothing new.

The layer is now self-signed with `RealityHatch Development (PC2)` and locally trusted for the current Windows user. SignTool and PowerShell Authenticode validation pass, and sample loading/frame forwarding passes with the signed binary. The default fallback log path was tested too. The subsequent SC/EAC startup test failed VR initialization with this layer enabled; a no-layer control passed. See [SC/EAC results](SC-EAC-TEST.md). Public signing remains the planned deployment route; local certificate trust and Smart App Control/EAC acceptance are separate concerns. See [development signing and diagnostic evidence](DEVELOPMENT-SIGNING.md).

Reference: [Khronos OpenXR loader design](https://registry.khronos.org/OpenXR/specs/1.1/loader.html).
