# RealityHatch runtime composition assessment

Research date: 23 November 2026. Status: architecture exploration; no runtime settings changed and no compositor prototype tested.

A separate camera application submitting an overlay to SteamVR is a viable architecture to evaluate. A supported equivalent that preserves the native Pimax OpenXR runtime has not been established. Keep the chosen C++ API layer as an alternative while comparing these routes.

## Options

| Route | Custom RealityHatch DLL inside Star Citizen | Runtime implications | Assessment |
| --- | --- | --- | --- |
| Separate OpenVR overlay application | No, by design | Star Citizen uses SteamVR as its OpenXR runtime; Pimax headset uses its supported SteamVR driver path | Best documented external-compositor candidate. Requires evaluating the runtime change and performance. |
| Separate application using native Pimax compositor | Intended to avoid it | Retains Pimax OpenXR if cross-process composition is supported | Unproven. Pimax SDK frame submission is documented, but overlay coexistence with another process is not established. |
| Existing signed OpenXR layer or our signed layer | Yes | Retains Pimax OpenXR | Remains a distinct alternative; moving camera processing outside the game alone does not remove the in-process layer. |

## What the documented APIs provide

Valve's OpenVR SDK provides an overlay application type, independent overlay texture submission, head/device-relative or absolute transforms, show/hide controls and SBS left/right rendering. These support an external stereo desk window. Use a normal in-scene overlay, not a dashboard-only panel that disappears when the dashboard closes. [Valve SDK header](https://github.com/ValveSoftware/openvr/blob/master/headers/openvr.h), [Valve overlay sample](https://github.com/ValveSoftware/openvr/blob/master/samples/helloworldoverlay/openvroverlaycontroller.cpp)

Proposed pipeline: ELP SBS MJPEG -> capture/decode in a separate C++ application -> OpenCV calibration -> GPU stereo image with a desk-region alpha mask -> SteamVR overlay compositor. Manual controls and a head-pitch threshold with hysteresis can live entirely in that application. Automatic startup would launch the application rather than register an implicit API layer. These are design proposals, not tested behavior.

The overlay renderer need not use the same graphics API as Star Citizen. It can submit its own compatible GPU textures; compare direct submission with desktop capture for latency. This follows from the independent overlay submission API. A stereo panel preserves binocular cues but does not automatically correct camera-to-eye viewpoint differences or provide game-depth occlusion.

SteamVR must own the game's presentation for this route. Merely running SteamVR alongside a game using native Pimax OpenXR does not establish that SteamVR overlays will appear over that game. The Pimax-native runtime requirement therefore needs an explicit decision before adopting the SteamVR route.

Pimax documents PVR sessions, swapchains and pvr_submitFrame. Multiple sessions and composition layers do not by themselves establish independent, simultaneous overlays from different applications. Confirm coexistence, focus behavior, stereo/alpha support and current SDK support with Pimax or a minimal probe. [Pimax native SDK](https://developer.pimax.com/document/sdk/native/native-pc-xr-sdk.html)

OpenXR's XR_EXTX_overlay extension is not ratified and requires runtime support; a second ordinary OpenXR application is not automatically an overlay. Enumerate the installed runtime's extensions before considering it. The Khronos inventory does not include Pimax, so it cannot settle support on PC2. An API-layer implementation of the extension would reintroduce in-process code. [Extension reference](https://registry.khronos.org/OpenXR/specs/1.1/man/html/XR_EXTX_overlay.html), [Runtime inventory](https://github.khronos.org/OpenXR-Inventory/runtime_extension_support.html)

## Existing utilities

- OpenKneeboard uses an in-process layer for native OpenXR rendering; its SteamVR overlay mode is the relevant external alternative. Its documentation does not establish blanket EAC whitelisting. [Internals](https://openkneeboard.com/internals/), [Game compatibility](https://openkneeboard.com/compatibility/games/)
- MRGO advertises both OpenXR API-layer and SteamVR modes. Do not assume its OpenXR mode avoids loading code into the game or is EAC-whitelisted. [Developer listing](https://store.steampowered.com/app/4620960/MRGO__Mixed_Reality_Go/)
- Free/open-source Desktop+ can capture a camera-preview window and split stereo layouts between eyes. This is a useful initial usability test, with an extra capture stage and without assuming calibrated passthrough or automatic look-down activation. [User guide](https://github.com/elvissteinjr/DesktopPlus/blob/master/docs/user_guide.md)

## Minimal evaluation

### Reported Star Citizen runtime performance

Checked 23 November 2026. Reports favor native Pimax for Star Citizen consistency, but no controlled comparison was found supporting a reliable percentage or millisecond penalty for SteamVR on the Crystal Super Micro-OLED.

- On 16 June 2026, an OpenMR Star Citizen user recommended native Pimax for more consistent performance than SteamVR; no matched benchmark was supplied. [OpenMR report](https://forum.openmr.com/t/star-citizen-4-5-and-vr/42539?page=5)
- A Dream Air/RTX 5090 user reported roughly 50+ FPS in stations and asteroid fields with Pimax Play/EVO and frequent Star Citizen crashes with Sboys3. This is an informal stability/performance report, not a measured runtime FPS delta. [Firsthand comparison](https://www.reddit.com/r/Pimax/comments/1wv1m7v/sboys3_vs_pimax_evo_informal_playtesting_results/)
- A Crystal Super OLED user reported recurring CPU frame-time spikes in Star Citizen with Sboys3 1.3.0-beta, plus warping/stutter with SteamVR motion smoothing. This describes a particular beta configuration and cannot establish current universal behavior. [Firsthand comment in Micro-OLED discussion](https://www.reddit.com/r/Pimax/comments/1ujarb3/my_sboys3_driver_experience_with_a_crystal_super/)
- PimaxXR developer mbucchia explains that projection-mode comparisons can change pixel workload: the older Pimax implementation increases resolution for parallel projections while the Sboys3 toggle does not. Match actual render dimensions and comparable image quality rather than percentages or switch labels. [Developer explanation](https://www.reddit.com/r/Pimax/comments/1ujkww1/boys3_drivers_versus_the_openxr_toolkit/)

Treat SteamVR's runtime/driver cost separately from camera-overlay cost. Compare native Pimax, SteamVR with Pimax's driver path, and SteamVR with Sboys3 as distinct configurations where supported. Start with the same refresh rate, actual per-eye dimensions, game scene/settings and DLSS mode, with frame generation and motion smoothing off; then test desired smoothing separately. Measure baseline, overlay hidden and overlay visible. Track high-percentile frame times and stability as well as average FPS.

### Evaluation sequence

1. Record current runtime, driver versions, resolution, refresh rate and Star Citizen frame-time baseline; preserve settings for rollback.
2. Under SteamVR OpenXR, display a left/right-labeled test pattern from a separate overlay application. Confirm both eyes, alpha, placement and visibility with the dashboard closed.
3. Confirm it coexists with Star Citizen launched normally with EAC enabled. Verify no RealityHatch layer or DLL is loaded into the game. Do not modify the game or disable EAC.
4. Add camera capture/calibration, desk masking and both activation modes. Hide stale frames on failure.
5. Measure capture-to-display latency, GPU/CPU overhead, game frame times and stereo comfort against the Pimax-native baseline. Do not assume the external route is faster or slower.
6. If native Pimax is mandatory, first establish a supported external-compositor API or advertised overlay extension. Avoid implementing a replacement runtime or modifying the compositor merely to simulate an external overlay.

Process separation removes the custom in-game DLL loading/signing problem for this architecture; it is not a general EAC approval or non-interference guarantee.
