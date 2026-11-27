# SC/EAC layer tests

## Certum-signed loading test — 27 November 2026

**Awake-headset repeat passed VR session and frame forwarding.** Evidence: `logs\sc-eac-20261127-155150\RESULT.md` and `result.json`, immutable `realityhatch-at-monitor-end.log`, external loader/debug capture, process/service samples and Game/EAC/RSI snapshots. The same publicly signed DLL was used. Game PID 34828 completed negotiation and instance creation at 20:54:13.448–449 UTC, created a Pimax session at 20:54:16.278 UTC, and forwarded at least 8,400 frames successfully by monitoring end, with no negative-result layer events. SC logged Pimax Crystal Super/native Pimax OpenXR and `VR: DISABLED -> ENABLED`; EAC's bootstrapper recorded successful in-game loading at 20:54:06.813 UTC. The user confirmed seeing the game UI in VR. Capture/monitoring stopped normally; the game was left running.

This validates the diagnostic layer's startup/menu forwarding in this configuration. It does not test gameplay-server acceptance or the future camera/composition implementation. The earlier asleep-headset run below remains useful comparison evidence.

After capture, the game was closed normally through its Quit Game confirmation at the user's request. Raw evidence stays local and is excluded from Git; the results and artifact identities here are the published summary.

The Certum-signed 0.1.2 deferred-state layer successfully loaded inside SC LIVE `4.10.3-live.13220821`, completed OpenXR negotiation and created an instance using native Pimax OpenXR with EAC enabled. Unlike the earlier self-signed runs, both RealityHatch's file log and external debug capture contain successful negotiation and instance markers.

Evidence directory: `logs\sc-eac-20261127-153955`, including `RESULT.md`, `realityhatch.log`, `openxr-debugview.log`, `test.json`, process/service samples, exact signed artifacts, and before/during/after Game/EAC/RSI snapshots. Signer thumbprint: `5FBBF23407B4D1FA07A559C132626AF32CAE8CB1`; DLL SHA-256: `0D478917222D37448750CA86F18CB2441B00663082202723893A211C83AC5C10`.

EAC's bootstrapper recorded successful in-game loading at 20:41:00.071 UTC. At 20:41:06.349–350 UTC, game PID 54148 logged `negotiation_entered`, `loader_negotiated`, `dispatch_state_ready`, `instance_created` and `runtime_properties` (`Pimax OpenXR`), all with result 0. SC then reported `No headset found`; the user confirmed the headset was asleep. Session creation and frame submission were therefore not exercised. SC reached its menu and was exited normally. No EAC configuration or global OpenXR settings were changed.

That first run passed the layer-loading check but could not validate sessions or frames. The awake-headset repeat above now supplies that evidence. These results support the public-signing route without establishing a universal EAC rule or compatibility of future camera/rendering code.

## Self-signed layer test — 23 November 2026

Outcome: the self-signed RealityHatch layer failed loading with both current-user trust and, in a subsequent repeat, current-user plus Local Machine trust. Enabling it caused SC VR initialization to fail with a file-access error. Disabling it for a fresh normal-launcher control run restored native Pimax VR. The user visually confirmed the control launched in VR and the machine-trust repeat did not.

## Configuration

- SC LIVE `4.10.3-live.13220821`, Vulkan, Pimax Crystal Super.
- Native runtime: `C:\Program Files\Pimax\Runtime\PiOpenXR_64.json`; the global runtime was already Pimax and was not changed.
- Layer: `XR_APILAYER_NOVENDOR_realityhatch`, implementation 1, API version 1.1.
- Signed DLL SHA-256: `3BEDB989E3E2DB3D3F37675710DC0EC632C26D1757D9DD2A353240F85B17F238`.
- Development signer: `CN=RealityHatch Development (PC2)`; thumbprint `67E980D4A5AF9A3B45EFC0A1E95272E125A1C330`.
- Trust scope: first test used current-user Root/TrustedPublisher stores; the repeat also trusted the same public certificate in Local Machine Root/TrustedPublisher. Authenticode verification was valid in the actual Windows user context.
- Smart App Control had previously been disabled manually by the user. No Windows security settings were changed during these tests.

## Procedure

Closed the existing RSI launcher normally so a fresh instance could inherit the test's process-local OpenXR variables. Started the normal signed RSI launcher, with explicit-layer discovery/enabling and diagnostic variables supplied to its process. Used its normal LAUNCH GAME button; did not start StarCitizen.exe directly. No game files, EAC files, hosts entries, network routes, EAC configuration, global environment variables, or OpenXR registry registrations were changed.

The harness checked that the known EOS null-client override was absent. Process/service samples and the EAC bootstrapper logs independently recorded the protected startup. The control used the same native Pimax runtime and normal RSI launch path, with the RealityHatch explicit-layer environment variables cleared.

## Evidence

| Run | Evidence directory | Result |
| --- | --- | --- |
| Self-signed layer enabled | `logs\sc-eac-20261123-145950` | VR initialization failed; no RealityHatch execution log was created |
| RealityHatch disabled, control | `logs\sc-eac-control-20261123-150749` | Native Pimax detected; VR enabled; user confirmed VR |
| Same layer, Local Machine trust added | `logs\sc-eac-20261123-151815` | Same file-access error; no RealityHatch execution log; user confirmed no VR |

The enabled test's Game.log records at `2026-11-23T20:01:46.232Z`: `VR initialization blocked by file access error`. It identifies OpenXR overlay software as a common cause. No layer negotiation, instance, session or frame events were recorded by RealityHatch in that launch.

The same test's EAC bootstrapper records `Easy Anti-Cheat successfully loaded in-game` at `20:01:38.505` UTC. The process/service samples show StarCitizen.exe launched by StarCitizen_Launcher.exe and EasyAntiCheat_EOS running.

The control's EAC bootstrapper records the same in-game EAC success at `20:08:31.482` UTC. Its Game.log records the Pimax Crystal Super with Pimax OpenXR at `20:08:37.866` UTC, then `VR: DISABLED -> ENABLED` at `20:08:46.119` UTC.

Relevant Windows Code Integrity queries returned no matching events in the test window; those query results were saved. This differs from the earlier Smart App Control rejection of unsigned development DLLs. EAC's available bootstrapper log did not provide a DLL-specific rejection reason, so the exact policy behind this file-access failure is not established.

Each directory contains test identity/configuration JSON, before/during/after Game.log and EAC/RSI log snapshots, launcher stdout/stderr, and timestamped process/service observations. The failed test directory also includes `result.json` and an `artifacts` directory containing the exact tested signed DLL, manifest and public certificate. It contains no private signing key. Raw diagnostic logs stay excluded from Git via `.gitignore`.

## Interpretation and cleanup

Self-signing with current-user trust, including the repeat with Local Machine trust, is insufficient for this SC protected-process startup using explicit-layer activation. Public-CA signing remains untested. The native-runtime and EAC-enabled no-layer control rules out a general SC/Pimax VR failure in the earlier comparison.

This was a startup/main-menu loading experiment, not a Persistent Universe or Arena Commander gameplay/session test. No successful RealityHatch loading under SC/EAC has been established.

All test games and test launchers were exited normally, their process-local settings were discarded, and the normal RSI launcher was reopened without the test layer enabled. The self-signed development certificate remains installed as requested; the layer binary is unchanged. A public-CA-signed comparison remains a possible next experiment.

## Local Machine trust repeat

At `2026-11-23T20:15:26.802Z`, the administrator-run `Trust-DevelopmentCertificateMachine.ps1` imported the existing public certificate into `Cert:\LocalMachine\Root` and `Cert:\LocalMachine\TrustedPublisher`. The private key remains non-exportable in the current-user personal store. No security policy or EAC setting was changed. The import transcript and JSON were copied into the repeat's evidence directory.

The repeat used the same DLL and manifest hashes, native Pimax runtime, explicit-layer environment and normal RSI/EAC launch procedure. Its `test.json` confirms all four user/machine trust entries were present and Authenticode was Valid. EAC reported successful in-game loading at `20:19:29.632` UTC; SC reported the same OpenXR file-access error at `20:19:36.471` UTC. The user confirmed it did not launch into VR. No RealityHatch execution log was created. The Code Integrity query found no matching events, and available EAC logs did not identify a DLL-specific rejection rule.

`logs\sc-eac-20261123-151815` contains before/during/after snapshots, process/service samples, `result.json`, certificate-import evidence, and the exact signed DLL, manifest and public certificate under `artifacts`. The game and test launcher were exited normally, monitoring finished at `20:21:29.719` UTC, and a fresh normal launcher was reopened. No second no-layer control was run; the earlier passing control is retained for comparison.

## Repeating the test

### Additional diagnostics

Evidence directory `logs\sc-eac-20261123-152558` contains two further normal RSI/EAC startups with the unchanged layer and native Pimax runtime. Microsoft-signed Sysinternals DbgViewCLI 5.02 captured user-mode `OutputDebugString` output externally, filtered to StarCitizen, without debugger attachment or kernel/global capture. It recorded repeated `xrCreateInstance` errors: `Failed loading layer information`, followed by `xrCreateInstance failed`. The final pair matches SC's file-access error at `2026-11-23T20:27:23.052Z`. The raw stream is `openxr-debugview.log`; the relevant extract is `openxr-errors.txt`.

`XR_LOADER_DEBUG=all` was already set for the previous experiments. Their redirected RSI stdout/stderr did not contain the game's loader output. In the inspected Khronos loader source, this variable enables detailed standard-output logging, while Windows debug output receives errors only. The dynamic-library failure path formats `GetLastError()` and the library path as a warning, which explains why this external error capture may omit the useful Windows error. This is a source-based explanation, not proof of the exact failure inside SC's bundled loader. The collector now records that loader's version, hash and Authenticode identity and preserves all Code Integrity XML records in the test window when available, including records without a matching filename.

A bounded 120-second Microsoft Process Monitor capture covered a further reproduction: SC reported the same file-access failure at `20:29:54.508Z`, with EAC reporting in-game initialization success at `20:29:47.239Z`. The trace files are `file-load-trace.pml` and `file-load-trace-1.pml`. Initial offline open attempts failed while a hidden viewer persisted; closing that viewer allowed the trace to open successfully. The user exported `realityhatch-file-events.csv`; the SC-only subset is `sc-realityhatch-file-events.csv`.

Important qualification: SC PID 86828 successfully read the manifest and opened the DLL. Process Monitor recorded five successful `Load Image` events for `RealityHatchLayer.dll` at local times `15:29:54.0631914`, `.2400838`, `.4402502`, `.4736467` and `.5069928`. There were no access-denied or invalid-image results in that SC/project-path extract. `FILE LOCKED WITH ONLY READERS` occurred during section synchronization, followed by successful mapping/image events; it is not evidence of the final rejection. Therefore, the evidence does not establish a simple Windows file-read or image-mapping denial. Mapping alone does not establish completion of DLL initialization or OpenXR negotiation. The absence of a layer log also cannot exclude entry into the negotiation export: the current implementation validates inputs before its first log call.

Static inspection with Microsoft's `dumpbin` shows only `KERNEL32.dll` as a direct import dependency, and the expected `xrNegotiateLoaderApiLayerInterface` export is present. This does not establish successful initialization within SC, but does not support a missing dynamically linked VC++ runtime dependency. The exact Windows load error and any EAC policy decision remain unproven.

The user also exported `sc-all-events.csv` (all displayed StarCitizen events). `sc-openxr-failure-window.csv` isolates local time `15:29:54`. This window contains no `ACCESS DENIED` operations. App-local `vulkan-1.dll` lookup failures are followed by successful System32 image loads. Pimax's application-specific logs, discovered through the trace, were copied to `pimax\pvr_client_StarCitizen_log*.txt`; they contain no explicit RealityHatch rejection reason. No attempted RealityHatch log-file access appears in the SC export. Neither these findings nor the successful image mappings establish that EAC accepted the layer's execution or certificate.

The next layer-side diagnostic identified here was an entry marker before negotiation validation, with explicit validation-failure records and Windows debug output in addition to file logging. This was subsequently implemented and tested as version 0.1.1 below. More detailed EAC policy decisions may require CIG/Epic developer-side diagnostics.

### Negotiation instrumentation repeat — version 0.1.1

Evidence: `logs\sc-eac-20261123-154747`. Rebuilt x64 Release and signed with the existing development identity; exact signed DLL SHA-256: `881BE9CEC10A700EF7D797704C0852C183C0F6866DE184152272F2F0C622B2C0`. The same four user/machine trust entries remained present, with Valid Authenticode verification. Native Pimax remained both the test override and global OpenXR runtime.

The new `negotiation_entered` record is emitted before argument validation. Header values and interface/API ranges are logged, and each failed validation has a distinct `negotiation_validation_failed` reason. All layer records now also use Win32 `OutputDebugString`, independent of successful file creation; file-path/open/write failures emit external diagnostics. The diagnostic changes do not add DllMain I/O or alter frame forwarding.

Validation passed: warning-free build/signature verification, CTest 1/1, recorded rejection reasons for exercised null/name/header/API-range cases, and native Pimax/Vulkan hello_xr negotiation/session/frame forwarding. Evidence includes the signing transcript/JSON, build logs, dispatch log, source snapshot, and sample result/log files. A separate short external-capture positive control with the same signed DLL and hello_xr PID 86720 recorded negotiation entry, headers, versions and success in `hello-xr-debug-positive-control.log`.

SC PID 41796 was launched normally through the fresh RSI launcher with EAC enabled. EAC recorded successful in-game initialization at `2026-11-23T20:48:35.063Z`; SC recorded its OpenXR file-access failure at `20:48:41.797Z`. External debug capture recorded five pairs of loader errors (`Failed loading layer information`, `xrCreateInstance failed`), but no RealityHatch entry, validation-failure or logger-failure marker. No `realityhatch.log` was created. Code Integrity queries returned no events in the test window. Thus, no execution of the instrumented negotiation body was observed in SC, while positive controls demonstrate both logging channels work with the same DLL. This does not reveal an exact EAC certificate-policy decision.

`result.json` summarizes the comparison. The exact signed DLL, manifest and public certificate are archived under `artifacts`. The game and test launcher were exited normally; the harness stopped its external capture, saved final snapshots, restored its environment, and a fresh normal launcher was reopened. No additional Process Monitor capture or no-layer control was run for this repeat.

### Matched-loader and deferred-state comparisons — version 0.1.2

The baseline experiment ran version 0.1.1 through an isolated copy of SC's exact `openxr_loader.dll` 1.1.60.0 with hello_xr/Vulkan2 and native Pimax. The copied loader SHA-256 equals the game's original: `0A9A30E7F59EC170354E5A6F8B169E0C36A4673D38C948119EEBD9AA56022763`. Negotiation, instance/session creation and frame forwarding passed. Evidence is in `logs\matched-loader-20261123-155909`; the original game loader remained unchanged. The baseline signed layer hash is `881BE9CEC10A700EF7D797704C0852C183C0F6866DE184152272F2F0C622B2C0`.

Version 0.1.2 (`deferred_state`) moves the namespace-scope mutex and maps into function-local `DispatchState`, constructed on first use. The normal first use is chained instance creation after successful negotiation. It adds initializing/constructed/ready markers, retains thread-safe first construction, and preserves dispatch and lifecycle behavior. Static CRT startup remains, so this does not isolate every possible DLL-initialization failure. No custom DllMain or entrypoint was added.

The deferred variant was built without warnings and signed with the same development certificate; full signed DLL SHA-256: `11E7B3D17BE14506751CFC17A42A001D33FEECFE0B83103DE38A50F20B63ED72`. CTest 1/1 passed, including existing multi-instance lifecycle checks; the validation log confirms a single state construction after negotiation. The deferred variant also passed hello_xr with the same copied SC loader and native Pimax. Its sample evidence is `logs\realityhatch-test-20261123-160028-789.*`, copied into the comparison directories. `comparison.json` records both layer hashes, the common loader identity and pass results.

The protected-game repeat is recorded separately in `logs\sc-eac-20261123-160137`, with external debug capture, before/during/after logs, build/signing evidence and source/artifact snapshots.

Result: the deferred variant did not resolve SC's failure. After the user acknowledged RSI's Early Access notice, normal protected startup created SC PID 41824; EAC reported successful in-game initialization at `2026-11-23T21:06:33.791Z`. SC reported the same OpenXR file-access error at `21:06:40.740Z`. The external capture recorded five pairs of loader failures, with no negotiation-entry, validation-failure, dispatch-state or logger-failure markers. No layer file log was created. Code Integrity queries found no events. The game's loader hash/version still matched the isolated sample copy.

| Comparison | Layer | Loader | Outcome |
| --- | --- | --- | --- |
| Isolated hello_xr baseline | 0.1.1, original dispatch globals | SC's exact 1.1.60 copy | Negotiation, session and frames passed |
| Isolated hello_xr deferred variant | 0.1.2, deferred dispatch state | Same SC loader copy | Negotiation passed; state constructed afterward; session and frames passed |
| Normal RSI/EAC SC startup | 0.1.2, deferred dispatch state | Original SC 1.1.60, native Pimax | Same VR failure; no RealityHatch markers recorded |

This weakens the loader-version mismatch and application dispatch-constructor hypotheses. It does not isolate every CRT/TLS/DLL initialization path or prove a particular EAC signature rule. No successful RealityHatch negotiation inside SC has been established.

The game exited normally at `21:08:39.904Z`. The test launcher was exited, its inherited settings discarded, external capture stopped, and final logs collected at `21:09:10Z`; a fresh normal launcher was reopened. The offline Process Monitor viewer from the earlier experiment was left available. No new Process Monitor run, security-policy change, game-file edit or global runtime change was made. `result.json` summarizes this repeat, and `comparison.json` links the two successful matched-loader sample runs.

### Related developer assessment

The [sc-api Option B discussion](https://github.com/m1ndgames/sc-api#option-b--a-custom-dbxlive64dll--rejected), reviewed 23 November 2026, advises against a custom replacement D-BOX connector DLL and says self-signing does not establish trust. The same section explicitly states that its probing stub was never loaded into the game. It therefore supplies a developer risk/trust assessment, not an observed self-signed SC/EAC rejection test. Its replacement-DLL scenario also differs from OpenXR API-layer registration. Local Windows certificate-store trust and acceptance by SC/EAC must be treated as separate questions; the report does not establish that any public-CA signature alone guarantees acceptance.

Epic documents additional `EOS_LC_AntiCheat` VeryVerbose logging through the game's EOS logging integration. This requires game-developer control; it is not a documented end-user switch for Star Citizen. Automatic EAC bootstrapper/service logs remain collected. The cached `easyanticheat_x64.eac` module is not treated as a text diagnostic log. No EAC configuration or game binaries were modified for these captures.

References: [Khronos loader debugging](https://github.com/KhronosGroup/OpenXR-SDK-Source/blob/main/specification/loader/debug.adoc), [loader logging implementation](https://github.com/KhronosGroup/OpenXR-SDK-Source/blob/main/src/loader/loader_logger.cpp), [Microsoft DebugView](https://learn.microsoft.com/en-us/sysinternals/downloads/debugview), [Microsoft Process Monitor](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon), [Epic Anti-Cheat logging](https://dev.epicgames.com/docs/epic-online-services/trust-and-safety/anti-cheat-interfaces/using-anti-cheat).

`Start-SCRealityHatchTest.ps1` prepares the environment and starts the normal launcher; the user or Computer Use then selects LAUNCH GAME. It records process/service observations for up to 15 minutes. `-WithoutLayer` runs the control. `-CaptureDebugOutput` starts a verified Microsoft-signed DbgViewCLI capture filtered to StarCitizen, archives its identity/settings, and stops that owned capture during cleanup. It refuses to replace an existing capture. The harness also archives the exact DLL, manifest and public certificate. `Collect-SCRealityHatchTest.ps1` saves snapshots while the game is running. To end monitoring after normally closing the test game/launcher, create `finish.request` in that run's evidence directory. A fresh normal launcher is required afterward because environment variables are inherited for the lifetime of the test launcher.
