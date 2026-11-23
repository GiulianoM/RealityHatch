param([ValidateRange(30,1800)][int]$MonitorSeconds = 900, [switch]$WithoutLayer, [switch]$CaptureDebugOutput)
$ErrorActionPreference = 'Stop'
if (Get-Process -Name 'StarCitizen','RSI Launcher' -ErrorAction SilentlyContinue) {
    throw 'Exit Star Citizen and the RSI launcher normally before starting this test; environment settings require a fresh launcher.'
}
if ($env:EOS_USE_ANTICHEATCLIENTNULL -and $env:EOS_USE_ANTICHEATCLIENTNULL -ne '0') {
    throw 'An anti-cheat null-client setting is present. This is not a valid protected-game test.'
}
$dll = Join-Path $PSScriptRoot 'bin\layers\RealityHatchLayer.dll'
$signature = Get-AuthenticodeSignature -LiteralPath $dll
$certificate = Get-Content -LiteralPath (Join-Path $PSScriptRoot '.local\development-certificate.json') -Raw | ConvertFrom-Json
$trustStores = @(foreach ($store in @('Cert:\CurrentUser\Root','Cert:\CurrentUser\TrustedPublisher','Cert:\LocalMachine\Root','Cert:\LocalMachine\TrustedPublisher')) {
    [ordered]@{store=$store;present=(Test-Path -LiteralPath (Join-Path $store $certificate.thumbprint))}
})
$machineTrusted = @($trustStores | Where-Object { $_.store -like 'Cert:\LocalMachine\*' -and $_.present }).Count -eq 2
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $certificate.thumbprint) {
    throw 'The layer must validate with the recorded development certificate before this test.'
}
$runPrefix = if ($WithoutLayer) {'logs\sc-eac-control-'} else {'logs\sc-eac-'}
$directory = Join-Path $PSScriptRoot ($runPrefix + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $directory -Force | Out-Null
$metadata = [ordered]@{
    startedUtc = [DateTime]::UtcNow.ToString('o')
    directory = $directory
    launcher = 'D:\Program Files\Roberts Space Industries\RSI Launcher\RSI Launcher.exe'
    gameRoot = 'D:\Program Files\Roberts Space Industries\StarCitizen\LIVE'
    layer = $dll
    layerSha256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    signatureStatus = $signature.Status.ToString()
    signerSubject = $signature.SignerCertificate.Subject
    signerThumbprint = $signature.SignerCertificate.Thumbprint
    trustScope = if ($machineTrusted) {'CurrentUser + LocalMachine Root/TrustedPublisher'} else {'CurrentUser'}
    certificateTrustStores = $trustStores
    runtimeManifest = 'C:\Program Files\Pimax\Runtime\PiOpenXR_64.json'
    manifest = Join-Path $PSScriptRoot 'bin\layers\RealityHatch.json'
    manifestSha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'bin\layers\RealityHatch.json') -Algorithm SHA256).Hash
    globalRuntime = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Khronos\OpenXR\1').ActiveRuntime
    layerActivation = if ($WithoutLayer) {'RealityHatch explicit-layer variables cleared for the control run'} else {'XR_API_LAYER_PATH and XR_ENABLE_API_LAYERS inherited from the normal RSI launcher'}
    layerEnabled = !$WithoutLayer
    eacConfigurationChanged = $false
    launcherProcessId = $null
    monitoringEndedUtc = $null
    debugCapture = $null
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $directory 'test.json') -Encoding UTF8
$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot '.local\current-sc-test.json') -Encoding UTF8
& (Join-Path $PSScriptRoot 'Collect-SCRealityHatchTest.ps1') -Directory $directory -Phase before
$names = @('XR_RUNTIME_JSON','XR_API_LAYER_PATH','XR_ENABLE_API_LAYERS','REALITYHATCH_LOG','XR_LOADER_DEBUG')
$saved = @{}
$capture = $null
Start-Transcript -LiteralPath (Join-Path $directory 'monitor.log') | Out-Null
try {
    $artifacts = Join-Path $directory 'artifacts'
    New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
    Copy-Item -LiteralPath $dll,$metadata.manifest,(Join-Path $PSScriptRoot '.local\RealityHatch-Development.cer') -Destination $artifacts
    if ($CaptureDebugOutput) {
        $captureTool = Join-Path $PSScriptRoot 'tools\DebugView\dbgviewcli64.exe'
        $captureSignature = Get-AuthenticodeSignature -LiteralPath $captureTool
        if ($captureSignature.Status -ne 'Valid' -or $captureSignature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
            throw 'A verified Microsoft-signed DbgViewCLI is required for external capture.'
        }
        $captureStatus = & $captureTool --status
        if ($captureStatus -match '^running=true$') { throw 'An external debug capture is already running; it will not be interrupted.' }
        $captureArgs = '--accepteula --no-banner --win32 --no-kernel --no-global --process-filter StarCitizen --clock-ms --duration ' +
            ($MonitorSeconds + 30) + ' --max-lines 50000 --log "' + (Join-Path $directory 'openxr-debugview.log') + '"'
        $capture = Start-Process -FilePath $captureTool -ArgumentList $captureArgs -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $directory 'debugview.stdout.log') -RedirectStandardError (Join-Path $directory 'debugview.stderr.log')
        $metadata.debugCapture = [ordered]@{tool=$captureTool;sha256=(Get-FileHash $captureTool).Hash;processId=$capture.Id;
            mode='Win32 OutputDebugString; StarCitizen process filter; no kernel/global capture';arguments=$captureArgs}
        Start-Sleep -Milliseconds 500
        if ($capture.HasExited) { throw 'External capture exited before the test launcher started; inspect debugview.stderr.log.' }
    }
    foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $env:XR_RUNTIME_JSON = $metadata.runtimeManifest
    $env:XR_API_LAYER_PATH = if ($WithoutLayer) { $null } else { Join-Path $PSScriptRoot 'bin\layers' }
    $env:XR_ENABLE_API_LAYERS = if ($WithoutLayer) { $null } else { 'XR_APILAYER_NOVENDOR_realityhatch' }
    $env:REALITYHATCH_LOG = if ($WithoutLayer) { $null } else { Join-Path $directory 'realityhatch.log' }
    $env:XR_LOADER_DEBUG = 'all'
    $process = Start-Process -FilePath $metadata.launcher -WorkingDirectory (Split-Path $metadata.launcher) `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $directory 'launcher.stdout.log') `
        -RedirectStandardError (Join-Path $directory 'launcher.stderr.log')
    $metadata.launcherProcessId = $process.Id
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $directory 'test.json') -Encoding UTF8
    Write-Host "Test launcher PID: $($process.Id)"
    Write-Host "Evidence directory: $directory"
    $deadline = (Get-Date).AddSeconds($MonitorSeconds)
    while ((Get-Date) -lt $deadline -and !(Test-Path -LiteralPath (Join-Path $directory 'finish.request'))) {
        $processes = @(Get-CimInstance Win32_Process | Where-Object {
            $_.Name -match '^(StarCitizen.*|EasyAntiCheat.*|RSI Launcher)\.exe$'
        } | Select-Object Name,ProcessId,ParentProcessId,ExecutablePath)
        $services = @(Get-CimInstance Win32_Service | Where-Object { $_.Name -match 'EasyAntiCheat' } | Select-Object Name,State,StartMode)
        [ordered]@{utc=[DateTime]::UtcNow.ToString('o');processes=$processes;services=$services} |
            ConvertTo-Json -Depth 5 -Compress | Add-Content -LiteralPath (Join-Path $directory 'process-service-samples.jsonl') -Encoding UTF8
        Start-Sleep -Seconds 2
    }
} finally {
    if ($capture -and !$capture.HasExited) {
        & $captureTool --stop | Out-Null
        if (!$capture.WaitForExit(5000)) { Stop-Process -Id $capture.Id -ErrorAction SilentlyContinue }
    }
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    $metadata.monitoringEndedUtc = [DateTime]::UtcNow.ToString('o')
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $directory 'test.json') -Encoding UTF8
    & (Join-Path $PSScriptRoot 'Collect-SCRealityHatchTest.ps1') -Directory $directory -Phase after
    Stop-Transcript | Out-Null
}
