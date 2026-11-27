# RealityHatch initial requirements

Recorded 22 November 2026. Updated 27 November 2026. Status: requirements and development record; minimal diagnostic API layer implemented and tested with hello_xr. Camera passthrough is not implemented yet.

Provide stereoscopic SBS-camera passthrough for OpenXR VR applications so the user can see and operate real-world desk controls. Star Citizen is the primary target game environment; the software is not game-specific. The ordered ELP module is the initial test camera, not a brand or model requirement. Project name: RealityHatch. Description: "Calibrated stereo-camera passthrough for OpenXR VR applications."

## Confirmed requirements

| ID | Requirement |
| --- | --- |
| R1 | Support compatible side-by-side (SBS) stereoscopic camera modules without an ELP brand/model dependency. Use the ordered ELP-USB3DGS1200P01-H120 as the initial validation device; verify capture modes and calibration per camera. |
| R2 | Display passthrough in the user's Pimax Crystal Super Micro-OLED VR headset. |
| R3 | Support OpenXR VR applications, with Star Citizen's native Vulkan VR mode using the Pimax OpenXR runtime as the primary target environment. Avoid game-specific dependencies in the core camera and composition implementation. |
| R4 | Make physical desk controls visible and usable without removing the headset during play. |
| R5 | Build an OpenXR API layer with automatic loading after installation and configuration. |
| R6 | Preserve compatibility with Star Citizen's Easy Anti-Cheat protections. Do not bypass or disable anti-cheat. |
| R7 | Maintain the project on PC2 in D:\Projects\RealityHatch. |
| R8 | Show desk passthrough in a camera-resolution window centered horizontally in the lower area of each eye view. Preserve separate left/right camera images and their aspect ratio. |
| R9 | Use hotkey activation only: Left Alt + V toggles passthrough visibility. No look-down activation. |
| R10 | Implement a custom OpenXR API layer in C++. |
| R11 | Initially support SBS MJPEG capture and split each frame into corresponding left/right eye images. Verify supported capture modes on each camera; support for every format or camera is not implied. |
| R12 | Use OpenCV camera and stereo calibration to correct lens distortion and rectify the eye images. |
| R13 | Integrate calibrated stereo desk passthrough through the standard OpenXR API-layer call chain, using separate composition layers or Vulkan blending into rendered eye images as required for native Pimax compatibility. |
| R14 | Maintain RealityHatch as an MIT-licensed open-source project published at https://github.com/GiulianoM/RealityHatch, with public source and project information supporting eligibility for Certum Open Source Code Signing. Meet the certificate's issuance and usage requirements; see the distribution and signing decision below. |
| R15 | Present camera imagery as a visual overlay. Drawing over rendered eye images is permitted; do not modify game executables, game DLLs, executable code in memory, or gameplay logic. Use standard OpenXR layer loading and graphics APIs; do not bypass EAC. |
| R16 | Develop and test outside Star Citizen using the stock Khronos hello_xr object scene with Vulkan graphics and the native Pimax runtime as the default. A custom room or spatial grids are not required. |
| R17 | Use simple 3D box meshes around physical desk devices, such as a keyboard or joystick base, as the initial passthrough masks. Anchor each box to ArUco markers rigidly attached to its device so it follows the device's position and rotation. |

## Manual activation and view window

Confirmed 25 November 2026: use Left Alt + V as the default passthrough toggle, with hotkey activation only. Looking down does not change visibility. This supersedes the earlier Ctrl + Alt + V choice and automatic look-down requirement. Toggle visibility once per chord press, rather than repeatedly while held. Scope hotkey handling to the foreground VR application. Hotkey handling remains planned; the diagnostic stub does not implement it yet.

The installed Star Citizen LIVE defaultProfile.xml contains no assignment for Left Alt + V or standalone Left Alt, and the local default profile contained no custom keyboard rebindings. Verify that the chord does not also trigger plain V's scanning/melee actions during integration testing.

Place the view window at the horizontal center in the lower area of each eye view, fixed relative to the headset view. Use the selected camera mode's native per-eye resolution after splitting the SBS frame, preserve aspect ratio and stereo eye separation, and avoid unnecessary resampling. First approximation, confirmed 25 November 2026: with headset panels described by the user as roughly 4K per eye, start with a camera-resolution rectangle in the lower center; defer angular-size tuning and precise placement until visual headset testing. Use the actual OpenXR per-eye render dimensions for placement, since render dimensions can differ from physical panel resolution. This window layout does not remove the previously selected device-mask requirements below.

## Device mask scope

Confirmed 25 November 2026: start with ArUco-anchored device boxes. Configure and save each box's width, depth, height, and position/orientation relative to its marker anchor. A single visible marker can provide a device pose; additional markers may be used as a rigid group for visibility and stability. Record the dictionary, marker IDs, and measured marker size with the device configuration.

Project the box into each calibrated camera view to form the corresponding passthrough alpha mask, preserving separate left/right imagery through the camera-to-display mapping. The box is a reveal volume, not a reconstruction of the device or a source of game-scene depth. A joystick-base anchor follows the base; it does not measure movement of the stick.

Hand tracking and hand-shaped masks are deferred to a possible later phase. They are not part of the initial device-mask implementation. Camera capture, ArUco tracking, and box-mask rendering remain planned work, not implemented features.

## Chosen implementation architecture

Runtime composition is also under evaluation as of 23 November 2026; see [Runtime composition assessment](RUNTIME-COMPOSITION.md). The separate SteamVR overlay route avoids a custom RealityHatch DLL in the game but would change the selected OpenXR runtime. Native Pimax external composition remains unproven. This exploration does not supersede the confirmed requirements or the C++ API-layer option.

Camera SBS MJPEG capture -> MJPEG decode -> left/right split -> correction using OpenCV calibration -> Vulkan rendering into layer-owned OpenXR swapchains -> stereo desk composition submitted through xrEndFrame -> Pimax OpenXR runtime.

Overlay clarification, 23 November 2026: prefer an additional alpha-blended XrCompositionLayerProjection with distinct per-eye views, submitted after the game's existing layers. Render camera imagery and the desk mask into RealityHatch-owned swapchains. Pixels outside the desk mask are transparent. The Left Alt + V hotkey toggles visibility; look-down activation is disabled. Drawing into rendered eye images is also permitted if needed for Pimax compatibility; the restriction is on modifying game code, not the rendered pixels. Both approaches use an in-process API layer. [Khronos projection layer reference](https://registry.khronos.org/OpenXR/specs/1.1/man/html/XrCompositionLayerProjection.html)

Validate this mechanism with a transparent stereo test pattern on the installed native Pimax runtime before building the camera renderer: correct eye separation, additional projection-layer support, alpha blending, available layer count and the active view configuration. PassthroughForge reports that Pimax ignores overlay per-eye flags and consequently renders its stereo camera content directly into game frames. This is an allowed fallback; its report does not establish whether a separate stereo projection layer works on our runtime. Any direct Vulkan blending must respect OpenXR swapchain ownership and GPU synchronization: complete image access before forwarding release to the runtime, rather than writing to already released images at xrEndFrame. Avoiding game-code modification does not establish EAC acceptance; sign the in-process binaries and test the chosen rendering path with normal EAC enabled. [PassthroughForge v2.99.231 changelog](https://www.passthroughforge.com/changelog.html)

Preserve distinct left/right imagery to provide binocular depth cues. Camera calibration and stereo display alone do not provide a reconstructed depth map or correct camera-to-eye viewpoint differences at every distance. Decide whether depth reconstruction and reprojection are needed after evaluating desk-distance stereo comfort and alignment.

Minimize capture-to-display latency by keeping capture and decoding off the xrEndFrame path, using the latest complete stereo pair, bounding queues, and avoiding unnecessary copies. These are implementation goals; lowest latency and native runtime compatibility require measurement and validation.

## API layer loading and anti-cheat findings

Research checked 22 November 2026.

- Automatic loading is supported by the standard OpenXR loader through an implicit API layer manifest and Windows registry registration. The loader loads the DLL in the calling application's process and chains it ahead of the selected runtime; Pimax does not isolate the layer in a separate runtime process. The standard loader mechanism specifies no Authenticode signing prerequisite. [Khronos loader documentation](https://registry.khronos.org/OpenXR/specs/1.1/loader.html)
- Pimax publishes DesktopXR as a third-party OpenXR API layer with automatic installer registration, supporting this general architecture. This does not validate our particular Vulkan layer or exempt it from EAC. [Pimax DesktopXR article](https://store.pimax.com/blogs/blogs/desktopxr-for-openxr)
- The claim that signing is unnecessary for Star Citizen is not supported by the available evidence. OFXR Bridge's developer reports that signing its binaries enabled loading under Star Citizen EAC. This is firsthand project evidence, not a universal EAC policy or proof that signing alone will suffice for RealityHatch. [OFXR Bridge release 0.2.14.1](https://github.com/djules75/OFXR-Bridge/releases/tag/0.2.14.1)
- VectorXR documents signed releases tested under Star Citizen EAC, including development testing with a Pimax Crystal Super and Pimax OpenXR. It explicitly distinguishes successful testing from game-developer endorsement. [VectorXR usage guide](https://github.com/DienerTech/vectorxr/blob/master/docs/usage.md)
- User-provided update, 22 November 2026: recent PassthroughForge Discord reports confirm that its unsigned layer is blocked from loading in Star Citizen by EAC. Treat the reported unsigned build as unsuitable for the primary game. Exact build versions and Discord message links were not supplied; the reports were relayed by the user, not independently accessed.

Decision: retain the custom C++ OpenXR API layer architecture. Signing is not an OpenXR loader requirement, but signing and EAC acceptance remain deployment dependencies to resolve for Star Citizen. No guarantee of EAC non-interference has been established for our custom DLL and its dependencies.

Chosen certificate authority: Certum; intended product: Open Source Code Signing (updated by user decision, 25 November 2026). Rationale: OFXR Bridge reports successful Star Citizen EAC loading after signing, and inspection of its official v0.2.14.1 release found valid Authenticode signatures on all three executable binaries, issued by Certum Code Signing 2021 CA to Open Source Developer Julien Choulet. Certificate issued and installed on the activated smartcard, 27 November 2026. The RealityHatch layer was signed and timestamped with it; SignTool and PowerShell Authenticode verification passed. See [signing evidence and configuration](DEVELOPMENT-SIGNING.md). The publicly signed layer subsequently passed native Pimax SC/EAC startup, session creation and at least 8,400 successful frame forwards; the user confirmed the game UI in VR. See [SC/EAC evidence](SC-EAC-TEST.md). Camera/composition and gameplay-server validation remain outstanding. Verify EAC acceptance for RealityHatch's own signed binaries rather than assuming acceptance transfers from OFXR.

Distribution decision, 25 November 2026: RealityHatch is already published on [GitHub](https://github.com/GiulianoM/RealityHatch) under the [MIT License](LICENSE), superseding the earlier private/closed-source requirement. Publication was confirmed by the user; the local LICENSE contains the MIT terms with copyright attributed to GiulianoM, and the origin remote points to that repository. Maintain public project information identifying the maintainer to support Certum verification. Preserve the license obligations of reused source and dependencies.

Certum eligibility requirements, checked 25 November 2026: the Open Source certificate is issued to individuals and requires identity verification, a subscriber utility bill, and a publicly accessible ongoing project clearly showing the subscriber's relationship to it. Certum states that signing commercially distributed software results in revocation; use this certificate only within its permitted scope. See [Certum's required documents and usage restrictions](https://support.certum.eu/en/code-signing-required-documents/). Plan for the supported cryptographic card, reader, and signing software specified by the [Open Source Code Signing product](https://shop.certum.eu/open-source-code-signing-code.html?___store=certum_en); confirm the current requirements when ordering. Local self-signing remains a development mechanism, not the intended public-release signing path.

Signing assessment, 22 November 2026: Windows-trusted Authenticode signing is the practical baseline for DLLs loaded into protected OpenXR applications. [OpenXR developer Fred Emmott's guidance](https://fredemmott.com/blog/2024/11/25/best-practices-for-openxr-api-layers.html) identifies this as a requirement of most anti-cheat software and recommends timestamping. OFXR's Star Citizen release provides direct evidence that signing enabled its loading. No public EAC specification was found establishing a signature as the only acceptance condition, and no evidence was found requiring separate manual approval for every signed Star Citizen OpenXR layer. As a game-specific caveat, [NextLevelXR's developer](https://nextlevelsimgaming.co.uk/nextlevelxr-mod.html) documents fully Certum-signed binaries while still awaiting EAC whitelisting for Le Mans Ultimate online play. Working assumption for RealityHatch: sign and timestamp the layer and all project DLL dependencies loaded into the game, preserve valid vendor signatures, then verify loading and operation with SC's EAC enabled. Treat additional approval as conditional if required, rather than an established prerequisite for every layer.

## Proposed requirements to confirm

- Validate left/right assignment and synchronization, and calibrate camera placement relative to the eyes for the useful desk viewing distance.
- Allow adjustment of the desk region's size, shape and placement, and the look-down threshold and transition behavior.
- Keep capture-to-display latency and added game frame time low enough for comfortable control use. Set numerical limits after measuring the camera and baseline game performance.
- Hide stale camera images and recover cleanly from camera disconnects, capture failure, headset/session restarts and game exit.
- Provide saved settings, an easy disable/uninstall path and activation restricted to the intended application where practical.

## Existing software assessment

Checked 22 November 2026. No documented free package was found meeting the complete ELP SBS camera, desk mask, dual activation, native Pimax OpenXR, Vulkan and Star Citizen EAC requirements. These are documentation findings; no candidate has been installed or tested on PC2.

Signing/SC evidence review, 23 November 2026: no independently verified example was found of a public-CA-signed external-camera passthrough API layer working with Star Citizen on native Pimax OpenXR. Do not treat OFXR's signing success as an existing camera-passthrough solution. MRGO advertises OpenXR USB-camera passthrough, but its public page supplies no signing or SC/EAC compatibility evidence; signature status remains unverified. Rectus is SteamVR-runtime-only; PSVR2 Passthrough documents PSVR2/SteamVR and D3D11/D3D12, without a documented SC Vulkan success. A further candidate, Virtual Real Cockpit, explicitly reports its add-on unsigned with signing in progress and no Vulkan support. This is a scoped negative research finding, not proof that no such software exists, and other candidates' binaries were not downloaded for Authenticode inspection in this review. Quest/Virtual Desktop passthrough reports concern a different runtime/headset path. [MRGO developer listing](https://store.steampowered.com/app/4620960/MRGO__Mixed_Reality_Go/), [Virtual Real Cockpit troubleshooting](https://virtualrealcockpit.com/manual/12)

| Candidate | Availability | Relevant functionality and gaps |
| --- | --- | --- |
| [Rectus OpenXR SteamVR Passthrough](https://github.com/Rectus/openxr-steamvr-passthrough) | Free, MIT | Closest open-source foundation: C++ API layer, USB stereo input, OpenCV calibration/reconstruction and Vulkan rendering. Documents SteamVR-only runtime support and webcam timing limitations. Native Pimax and the requested desk mask/activation need assessment or adaptation. |
| [PSVR2 Passthrough](https://github.com/AdamChesters/psvr2passthrough) | Free, MIT | Implicit OpenXR layer, calibrated stereo, xrEndFrame composition, keyboard/gamepad/HOTAS hold or toggle. Uses PSVR2 driver camera memory and D3D11/D3D12; ELP capture and Vulkan require development. |
| [VRPassthrough](https://github.com/SovaKingGood/VRPassthrough) | Public source; reuse license unclear | DirectShow USB capture, MJPEG decoding, stereo SteamVR overlay and visibility hotkey. Expects two camera devices, rather than one SBS input. Requires SteamVR; no documented OpenCV stereo calibration or native Pimax path. |
| [DesktopXR](https://github.com/glenimp617/DesktopXR) | Free per developer | Desktop/web overlays and Pimax runtime support are useful adjacent capabilities. No documented direct stereo-camera calibration/passthrough pipeline; not an established replacement. |
| [xr_passthrough_layer](https://github.com/yshui/xr_passthrough_layer) | Free, MIT | Early Rust/Linux-oriented layer, tested with Valve Index. Not a ready Windows/Pimax/ELP solution. |

Paid alternatives are relevant benchmarks, rather than free replacements:

- [PassthroughForge camera guide](https://www.passthroughforge.com/webcam-capture.html): native MJPEG capture, SBS per-eye display, shaped camera windows, head/world locking and stereo tuning. The [product page](https://www.passthroughforge.com/index.html) lists a EUR 49 license and 14-day trial. Current status for Star Citizen: blocked for the unsigned build, according to recent Discord reports relayed by the user on 22 November 2026. Reconsider after a release is demonstrated to load with SC's EAC enabled; Vulkan, calibration and activation requirements still need validation.
- [MRGO](https://store.steampowered.com/app/4620960/MRGO__Mixed_Reality_Go/): USD 34.99 at review; external UVC capture, hand/environment passthrough and OpenXR/SteamVR modes. SBS calibration, desk masking, look-down activation and Star Citizen EAC support are not established by its listing.

Assessment: inspect Rectus for reuse before implementing from scratch. Its [webcam guide](https://github.com/Rectus/openxr-steamvr-passthrough/wiki/Webcam-Setup) covers calibration and stereo reconstruction; its [compatibility table](https://github.com/Rectus/openxr-steamvr-passthrough/wiki/Compatibility) specifies packed SBS/over-under stereo input. Evaluate the cost of removing SteamVR dependencies and adding desk masking/activation. Retain EAC/signing validation for any reused or modified layer. Existing implementations do not establish RealityHatch approval.

## Feasibility decisions before implementation

SC/EAC startup experiment, 23 November 2026: the self-signed/current-user-trusted layer did not pass loading in SC LIVE 4.10.3 (13220821). The normal RSI/EAC launch reported successful in-game EAC initialization, but SC reported OpenXR VR initialization blocked by a file-access error, with no RealityHatch execution log. A fresh normal-launcher control with RealityHatch disabled restored native Pimax VR and was visually confirmed by the user. Test and control logs, artifact hashes, signer identity and process/service observations are saved. The precise rejection rule was not exposed by available logs; a repeat with additional Local Machine Root/TrustedPublisher trust also failed with the same error and no layer log. Public-CA signing remains untested. See [SC/EAC results](SC-EAC-TEST.md). This result supersedes the earlier hypothesis that current-user self-signing alone would suffice for SC.

Additional diagnostics qualify that result: external Windows debug output confirms failure loading API-layer information, while Process Monitor records successful manifest reads and five successful mappings of RealityHatchLayer.dll inside SC. Successful OpenXR negotiation/session creation remains unconfirmed, and no exact EAC certificate-policy rejection has been established. The raw traces, filtered CSV extracts, loader identity, direct import/export inspection and Pimax application logs are retained in `logs\sc-eac-20261123-152558`.

Version 0.1.1 adds negotiation-entry and specific validation-failure logging to both files and Windows debug output. The rebuilt signed layer passes mock validation/forwarding and native Pimax/Vulkan hello_xr tests, including an external-capture positive control. The subsequent normal SC/EAC repeat still failed VR initialization, with no entry marker in either channel; evidence is in `logs\sc-eac-20261123-154747`. The [sc-api developer's self-signing assessment](https://github.com/m1ndgames/sc-api#option-b--a-custom-dbxlive64dll--rejected) is a related reference, but that README says its custom stub was never loaded into the game, so it is not a measured SC/EAC signature-rejection result.

Matched-loader comparison: both version 0.1.1 and the signed version 0.1.2 deferred-state variant passed hello_xr with SC's exact 1.1.60 loader copied into an isolated sample directory and native Pimax. The original game loader is unchanged. Version 0.1.2 defers the dispatch mutex/maps until first state access after negotiation; tests verify single construction and preserved multi-instance lifecycle behavior. Its SC/EAC repeat still failed with the same VR file-access error and no negotiation/state marker. Evidence: `logs\matched-loader-20261123-155909` and `logs\sc-eac-20261123-160137`. Loader-version mismatch and dispatch-state construction are therefore weaker explanations; EAC rejection versus other initialization failure remains unresolved.

Development signing milestone, 23 November 2026: created `CN=RealityHatch Development (PC2)` with a non-exportable RSA-3072 private key in the current-user personal certificate store. Its public certificate is trusted in the current user's Root and TrustedPublisher stores. The layer is signed using SHA-256, and SignTool/PowerShell Authenticode verification both pass. The signed layer passed native Pimax/Vulkan hello_xr instance/session/frame forwarding tests, including the fallback log path. Builds now re-sign automatically once the local certificate configuration exists. Signing transcripts, hashes, signer identity, layer/runtime diagnostics, loader/console output and test metadata are saved locally. Subsequent SC/EAC tests with current-user and Local Machine trust failed; see the results above. [Development signing and diagnostics](DEVELOPMENT-SIGNING.md)

Minimal-layer milestone, 23 November 2026: RealityHatch's C++ diagnostic layer was built and successfully loaded by hello_xr on Vulkan2/native Pimax. Negotiation, instance creation, session creation and successful xrEndFrame forwarding were recorded. A separate dispatch/lifecycle test suite passed. The layer is enabled per test process only, with no global registry registration, and currently changes no rendered imagery. Its unsigned DLL was initially blocked by Smart App Control; the live test succeeded after the user disabled that setting manually. No certificates were created and no Windows security settings were changed by the agent. SC/EAC and signed-layer tests remain outstanding. [Layer development notes](LAYER-DEVELOPMENT.md)

Development host decision, 23 November 2026 (revised by user): use Khronos hello_xr (C++, Apache-2.0) with its stock object scene and Vulkan graphics by default. This supersedes the proposed custom gridded room; no custom scene development is needed initially. Its graphics abstraction also supports D3D11 and D3D12 if needed for diagnosis. Keep camera passthrough in the separately loaded RealityHatch API layer so tests exercise the intended deployment architecture. The unmodified sample was downloaded and built successfully on PC2 as an x64 Release executable with Vulkan support; command-line help was checked. The launcher selects Vulkan2 (XR_KHR_vulkan_enable2) and native Pimax via a process-local runtime override; PC2's global SteamVR runtime selection remains unchanged. Headset rendering has not yet been tested, and the camera layer has not been implemented. See [build and launch notes](HELLO-XR.md). [Khronos hello_xr source](https://github.com/KhronosGroup/OpenXR-SDK-Source/tree/main/src/tests/hello_xr)

Development host validation, 23 November 2026: repaired Windows Code Integrity rejection of the unsigned development loader by deploying a valid Valve-signed x64 OpenXR loader from the installed SteamVR files. The launch still explicitly selects native Pimax, independently of where the loader binary came from. Vulkan2 startup detected Pimax Crystal Super, created both eye swapchains and reached the visible session state. Visual headset confirmation remains pending. The build script now preserves this signed-loader deployment; no Windows security policy or certificate trust was changed. This result does not validate signing or EAC acceptance for the future RealityHatch API layer. Details and provenance are in [the development-host notes](HELLO-XR.md).

Early signing experiment (user direction, 22 November 2026): test whether a locally trusted, self-signed development certificate is sufficient for EAC to allow the minimal OpenXR layer to load. Do this before purchasing a public certificate or building the complete camera pipeline. Windows trust and EAC acceptance are separate test outcomes; acceptance of a locally trusted certificate is a hypothesis, not an established requirement or guarantee.

1. Build a minimal C++ layer that forwards OpenXR calls unchanged and records successful loading and xrEndFrame interception.
2. Create a development code-signing certificate, trust its public certificate in the appropriate Windows certificate stores on the test PC, sign the development DLL and verify Authenticode validation. Keep its private key protected and trust changes scoped and documented.
3. Confirm loading in an independent OpenXR application using the Pimax runtime.
4. With Star Citizen launched normally and EAC enabled, check whether the same signed layer loads and reaches xrEndFrame. Record certificate identity, build hashes, SC/runtime versions, layer logs and any EAC rejection. Do not disable or bypass EAC.
5. Interpret a pass as evidence for that exact configuration; interpret rejection as a reason to assess a public Certum certificate or seek guidance. Neither Windows signature validation nor a single launch establishes general EAC compatibility.

Testing clarification, 23 November 2026: Arena Commander offline Free Flight is a useful repeatable VR test scene, but CIG's documentation of offline gameplay does not establish that EAC is inactive or that self-signed layers are allowed. Launch normally for the EAC-acceptance experiment. Do not use loopback redirection, hosts-file changes or blocked EAC endpoints as evidence of acceptance: a test with protection disabled or bypassed cannot validate protected-session loading. Develop and debug the full renderer in an independent Vulkan OpenXR test application using native Pimax; test the minimal locally trusted self-signed layer separately under normal SC/EAC. If rejected, retain self-signing for the independent test application and use public signing or a CIG-authorized development route for SC integration. [CIG Arena Commander guide](https://support.robertsspaceindustries.com/hc/en-us/articles/360003091714-Arena-Commander)

Remaining feasibility checks:

1. Verify API-layer loading and composition with the installed Star Citizen native VR build and Pimax OpenXR runtime; record the tested versions.
2. Verify the exact camera specification and delivered capture modes: per-eye resolution, frame rate, format, stereo packing, synchronization, lens field of view and baseline. Do not infer these from the model suffix.
3. Use the early minimal-layer experiment to resolve the development signing path; verify signing and EAC acceptance again for the complete layer and its loaded dependencies. Standard OpenXR loading does not establish CIG/EAC approval; obtain applicable guidance or approval if required. Validate camera capture and rendering first in an independent OpenXR test application.
4. Validate the chosen C++ OpenXR layer architecture against Pimax runtime Vulkan swapchains, composition limits and Star Citizen's native VR mode. Select the stereo composition layer type and desk mask after this validation.

## Questions to complete the requirements

1. After testing the initial lower-center camera-resolution window, does its size or vertical offset need adjustment, and how should camera-to-eye alignment be calibrated?
2. Should the passthrough window start hidden when a VR session begins?
3. Which Star Citizen build and Pimax runtime version will be used for initial testing?
4. What is the camera order/specification URL, and when is delivery expected?
5. Which controls must be visible, at what distance, and under what desk lighting? Will the camera mount rigidly on the headset?
6. What are PC2's GPU, Windows version, headset refresh rate, and acceptable performance cost? These determine measurable latency, readability and frame-time acceptance targets.

## Initial acceptance checks

- With Star Citizen's native Vulkan VR mode and the Pimax OpenXR runtime, the configured layer loads automatically and displays passthrough only in the desk region within the game view.
- Left Alt + V toggles the lower-center passthrough window once per press. Looking down does not change visibility. The window preserves native camera per-eye resolution, aspect ratio and stereo separation.
- The user can identify and operate the agreed desk controls at normal seated distance and lighting without removing the headset.
- Measured latency and added frame time meet the agreed limits; stereo remains comfortable during normal head motion.
- SBS decoding preserves stereo pairing; OpenCV calibration corrects distortion and alignment at the agreed desk distances.
- Camera failure removes stale imagery without disrupting the game; disable/uninstall restores the previous setup.
- The integration meets the established CIG/EAC requirements. A successful launch alone is not proof of approval.

## Technical references

- [Best Practices for OpenXR API Layers on Windows — Fred Emmott, OpenKneeboard developer](https://fredemmott.com/blog/2024/11/25/best-practices-for-openxr-api-layers.html): implementation best-practices reference for RealityHatch. Apply its relevant guidance during design, implementation, packaging and review, including DLL signing and timestamping, layer registration and ordering, compatibility and diagnostics. This developer guidance supplements the authoritative OpenXR specification and does not establish EAC acceptance.
- [Khronos OpenXR Loader design and operation](https://registry.khronos.org/OpenXR/specs/1.1/loader.html): documents implicit API layers for automatic loading and their position between application and runtime.
- [CIG Easy Anti-Cheat guidance](https://support.robertsspaceindustries.com/hc/en-us/articles/4412282759191-Easy-Anti-Cheat): describes restrictions on unauthorized modifications; it does not approve this proposed layer.
- [Khronos xrEndFrame reference](https://registry.khronos.org/OpenXR/specs/1.1/man/html/xrEndFrame.html): frame submission passes composition layers to the runtime for compositing.
- [OpenCV camera calibration and 3D reconstruction](https://docs.opencv.org/4.x/d9/d0c/group__calib3d.html): calibration, stereo rectification and disparity-to-3D functions.

User statements are the source for the confirmed requirements. Proposed requirements and acceptance targets remain subject to the answers above.
