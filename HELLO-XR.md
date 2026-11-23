# hello_xr Vulkan development host

Use the stock Khronos object scene with the native Pimax OpenXR runtime. Camera passthrough will be developed as a separate API layer; the sample itself is unmodified.

## Source and prerequisites

- Source: https://github.com/KhronosGroup/OpenXR-SDK-Source
- Downloaded commit: `040046ba7934bf01265b6e95b8a2bd674a2f20f9` (23 November 2026).
- Source license: Apache-2.0; retain the upstream license files.
- Microsoft Visual Studio 2022 C++ Build Tools, CMake and Windows SDK.
- LunarG Vulkan SDK 1.4.363.0, extracted using the documented `copy_only=1` option into `tools\VulkanSDK`. No system Vulkan SDK registration is needed.
- Python 3 for upstream code generation. The build script accepts `-PythonExecutable` for another interpreter.
- A compatible signed x64 OpenXR loader DLL. On PC2 the build script defaults to the installed Valve-signed loader at `C:\Program Files (x86)\Steam\steamapps\common\SteamVR\bin\win64\openxr_loader.dll` (1.1.62.0). Use `-LoaderDll` to specify another trusted compatible loader. This dependency is for the development host; it does not select the SteamVR runtime.

## Build

From PowerShell in this project:

```powershell
git clone https://github.com/KhronosGroup/OpenXR-SDK-Source.git OpenXR-SDK-Source
git -C OpenXR-SDK-Source checkout --detach 040046ba7934bf01265b6e95b8a2bd674a2f20f9
.\Build-HelloXR.ps1
```

The upstream checkout is intentionally excluded from RealityHatch's Git repository. Preserve its upstream licence files. Install Python 3 and place it on PATH, or pass `-PythonExecutable` with its full path. If your Vulkan SDK is installed elsewhere, pass `-VulkanSdk` with that directory.

This builds the x64 Release `hello_xr` target and an upstream development loader in the build tree. For deployment, it copies the executable and the validated signed loader into `bin`; it does not deploy the unsigned locally built loader. Configure and build logs are in `build\hello-xr-vulkan`. The script selects the local Vulkan SDK only for the build process. Loader source, version, publisher, certificate thumbprint and SHA-256 are recorded in `bin\openxr-loader-provenance.json`. Do not publish this installed vendor binary as a RealityHatch release without checking its redistribution terms.

## Run

Start Pimax Play and connect the headset. Then run:

```powershell
.\Run-HelloXR-Vulkan.cmd
```

The launcher selects `--graphics Vulkan2 --verbose` and sets `XR_RUNTIME_JSON=C:\Program Files\Pimax\Runtime\PiOpenXR_64.json` only for this process. PC2 currently has SteamVR selected globally; the launcher uses native Pimax without changing that global setting. `Vulkan2` is hello_xr's name for its `XR_KHR_vulkan_enable2` backend. For the older Vulkan binding, supply `--graphics Vulkan` to the launcher. If Pimax is moved to another installation directory, update the manifest path in the launcher.

The build may include other graphics backends, but the supplied launcher defaults to Vulkan. OpenXR itself imposes no code-signing requirement, but Windows Application Control can restrict unsigned development executables and DLLs independently of EAC. Successful operation here does not establish SC/EAC acceptance.

## Build verification

Built successfully on PC2 on 23 November 2026: OpenXR 1.1.65, MSVC 19.44, Windows SDK 10.0.26100.0, Vulkan SDK 1.4.363.0, x64 Release. Configuration reports Vulkan enabled, and the Vulkan GLSL shaders were compiled with glslc. Output: `bin\hello_xr.exe` and `bin\openxr_loader.dll`. The executable's `--help` output was checked (upstream returns exit code 1 for help). Upstream emits floating-point truncation warnings in its optional spatial-containers scene; the build succeeds. No upstream sample source changes were required.

Native Pimax Vulkan session startup was verified on 23 November 2026 after the loader repair below. Visual confirmation of the objects in the headset remains pending. No camera API layer or development certificates were installed by this build.

After renaming the project directory to `D:\Projects\RealityHatch` on 23 November 2026, CMake was regenerated and the Vulkan sample rebuilt successfully at the new path. The prior generated build is preserved in `build\hello-xr-vulkan-before-rename`. Initial launch attempts were blocked by Windows Application Control.

### Bad Image error repaired, 23 November 2026

The user's `0xC0E90002` dialog named the locally compiled `openxr_loader.dll`. Windows Code Integrity events 3033 and 3077 confirmed rejection for signing-policy requirements. The DLL was a valid x64 PE and matched the build output; replacing it with the installed, valid Valve-signed x64 loader resolved startup. The unsigned DLL is preserved in `build\loader-backup\openxr_loader.locally-built.dll`. No Windows security policy was changed, and no signing certificate was imported.

Verified: executable help runs, the corrected build/deployment script completes, and the deployed loader signature is valid. A Vulkan2 launch using the explicit Pimax manifest logged `RuntimeName=Pimax OpenXR`, detected `Pimax Crystal Super`, created both eye swapchains and reached `XR_SESSION_STATE_VISIBLE`. Probe output is in `logs\hello-xr-vulkan.stdout.log` and `logs\hello-xr-vulkan.stderr.log`. This establishes native Pimax session startup; it does not substitute for user confirmation of the headset image.
