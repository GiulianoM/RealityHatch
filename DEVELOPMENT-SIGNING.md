# Certum and development signing on PC2

RealityHatch now defaults to Certum smartcard signing on PC2 when `.local\certum-signing.json` is present. The dedicated self-signed development certificate remains available explicitly for development.

## Certum smartcard signing, 27 November 2026

Windows detected the issued certificate on the cryptoCertum3.6 card in the ACS ACR40T reader. Its public certificate was registered in the current-user personal (`My`) store and associated with the existing key through Microsoft Smart Card Key Storage Provider. The private key stays on the card; no PIN or private key is saved in project files. No Root or TrustedPublisher entries were added for this certificate.

- Signer: Open Source Developer Giuliano Moschini.
- Issuer: Certum Code Signing 2021 CA.
- Thumbprint: `5FBBF23407B4D1FA07A559C132626AF32CAE8CB1`.
- Certificate expires 27 November 2027, 20:31:19 UTC.

```powershell
.\Sign-RealityHatch.ps1 -SigningProfile Certum
```

The default `Auto` profile chooses Certum when configured, otherwise the development profile. Once Certum is selected, missing card/key access, invalid certificate, timestamp failure or verification failure stops signing; there is no fallback to self-signing. `-SigningProfile Development` explicitly selects the old development certificate. Builds use the same automatic selection unless `-NoSign` is supplied. The card may request its PIN through Windows; do not pass it on the command line or store it in configuration.

Certum signing selects the exact thumbprint, uses SHA-256 and RFC 3161 timestamping at `http://time.certum.pl` with SHA-256, then verifies using SignTool and PowerShell Authenticode, including timestamp presence. A copy of the pre-signing DLL is retained next to the signing transcript for comparison. Only the RealityHatch layer is signed; vendor binaries are unchanged.

First public signing succeeded with zero SignTool warnings/errors; Authenticode status was `Valid`, and the Certum timestamp was verified. Full-file SHA-256: `0D478917222D37448750CA86F18CB2441B00663082202723893A211C83AC5C10`. Evidence: `logs\signing-20261127-153710-828.log` and `.json`. Local public-certificate/provider diagnostics are in `.local\certum`; signing configuration contains public identity information only in `.local\certum-signing.json`.

The publicly signed DLL passed the normal-launcher SC/EAC startup test with native Pimax OpenXR on 27 November 2026: successful negotiation, session creation and at least 8,400 forwarded frames, with the user confirming the game UI in VR. Evidence: `logs\sc-eac-20261127-155150`. See [SC/EAC results](SC-EAC-TEST.md). The public signature has not been separately retested in hello_xr; earlier hello_xr tests used the development signature. Future camera/composition code still requires validation.

References: [Certum SignTool instructions](https://files.certum.eu/documents/manual_en/Signing_with_the_use_of_jarsigner_tool_and_signtool.pdf), [Microsoft SignTool](https://learn.microsoft.com/windows/win32/seccrypto/signtool).

## Create and trust

```powershell
.\Initialize-DevelopmentCertificate.ps1
```

The script creates `CN=RealityHatch Development (PC2)` in `Cert:\CurrentUser\My`, with a non-exportable RSA-3072 private key, SHA-256 and the code-signing EKU. Validity is one year. It exports only a public `.cer` file and imports that public certificate into the current user's `Root` and `TrustedPublisher` stores. Windows may require the user to approve a certificate-trust prompt. It makes no machine-wide trust change and does not modify Smart App Control or EAC.

The public certificate and thumbprint metadata are in `.local`. No PFX or private key is exported. `.local`, PFX and P12 files are excluded by `.gitignore`. Re-running setup reuses the recorded certificate rather than creating another one.

## Development profile: sign and verify

For the separately requested machine-wide trust experiment on PC2, run `Trust-DevelopmentCertificateMachine.ps1` as administrator. It validates the existing public certificate's identity and imports only that certificate into Local Machine `Root` and `TrustedPublisher`. It saves `logs\machine-certificate-trust-*.log` and `.json`, plus `.local\machine-certificate-trust.json`. This was completed on 23 November 2026; no private key was moved or exported.

```powershell
.\Sign-RealityHatch.ps1 -SigningProfile Development
```

SignTool selects the exact thumbprint in the current-user `My` store and signs `bin\layers\RealityHatchLayer.dll` using SHA-256. It then runs `signtool verify /pa /all /v` and verifies the signer and `Valid` Authenticode status again in PowerShell. Vendor DLLs and hello_xr are not re-signed. Development signatures are not timestamped and expire with the development certificate; use trusted timestamps for releases.

After setup, `Build-RealityHatch.ps1` automatically re-signs the layer after each successful build. `-NoSign` explicitly skips that step. Certificate creation/trust is never implicit in a build.

## Diagnostic evidence

All times inside structured metadata and layer log records are UTC. Log filename stamps use the PC's local clock.

| Component | Saved output |
| --- | --- |
| Certificate setup | `logs\certificate-setup-*.log`; public identity/validity in `.local\development-certificate.json` |
| Signing and verification | `logs\signing-*.log` and `.json`, including before/after SHA-256, signer thumbprint, signature status and tool path |
| CMake and compiler | `build\realityhatch\configure.log` and `build.log` |
| Dispatch/lifecycle tests | `build\realityhatch\Testing\Temporary\LastTest.log`; layer diagnostics use `REALITYHATCH_LOG` or the fallback below |
| Automated sample test | `logs\realityhatch-test-*.layer.log`, `.stdout.log`, `.stderr.log` and `.json` |
| Manual sample launcher | `logs\realityhatch-run-*.layer.log`, `.console.log`, `.launcher.log` and `.json` |
| Layer without a launcher log override | `%LOCALAPPDATA%\RealityHatch\logs\layer-YYYYMMDD-PID.log` |

The launch/test JSON records the actual layer SHA-256, signature status and signer thumbprint. Layer diagnostics include PID, UTC time, build/version, negotiation, runtime properties, instance/session lifecycle, first/every 300th frame forwarding and errors. Failures to write diagnostics do not change forwarded API results. A missing layer log may mean the DLL was rejected before its code ran; loader output and Windows Code Integrity events are then important evidence.

## Scope of the next test

Local Authenticode validity and loading in hello_xr do not establish SC/EAC acceptance. Current-user trust does not install the certificate into machine-wide stores or automatically make it trusted by another account or service. No SC launch or EAC experiment is performed by these scripts.

The user previously disabled Smart App Control manually for development. A locally trusted self-signed certificate does not establish acceptance by Smart App Control's public-trust policy.

## Verification on PC2, 23 November 2026

- Certificate thumbprint: `67E980D4A5AF9A3B45EFC0A1E95272E125A1C330`.
- Subject: `CN=RealityHatch Development (PC2)`; expires 23 November 2027, 19:24:58 UTC.
- Current-user personal key store, Trusted Root and Trusted Publishers entries verified. CNG key export policy is `None` (non-exportable).
- SignTool verification and PowerShell Authenticode both report success/Valid.
- Signed DLL SHA-256: `3BEDB989E3E2DB3D3F37675710DC0EC632C26D1757D9DD2A353240F85B17F238`.
- Signed native Pimax/Vulkan sample test passed: `logs\realityhatch-test-20261123-142959-795.json`, with matching layer/stdout/stderr logs.
- Fallback logging test passed: `logs\realityhatch-test-20261123-143023-418.json`, recording the per-user log `C:\Users\giuli\AppData\Local\RealityHatch\logs\layer-20261123-14800.log`.
- Manual-launcher console/transcript/metadata logging was checked with the sample help command.
- Dispatch/lifecycle tests passed after the logging changes. SC/EAC startup tests failed with current-user trust and again after adding Local Machine Root/TrustedPublisher trust; the earlier native Pimax no-layer control passed. See [SC/EAC test evidence](SC-EAC-TEST.md).

## Removing local trust later

Use the thumbprint recorded in `.local\development-certificate.json` to identify this exact certificate. Remove only that entry from the current-user and Local Machine Trusted Root Certification Authorities and Trusted Publishers stores when the experiment is finished; machine-store removal requires administrator rights. The personal (`My`) store also contains its private key; remove that entry only if deliberately retiring this development identity. No trust cleanup has been performed automatically.

References: [Microsoft New-SelfSignedCertificate](https://learn.microsoft.com/en-us/powershell/module/pki/new-selfsignedcertificate), [Microsoft SignTool](https://learn.microsoft.com/en-us/windows/win32/seccrypto/signtool).
