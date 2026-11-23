param([ValidateRange(3,120)][int]$Seconds = 12, [switch]$UseDefaultLog, [string]$SampleDirectory = (Join-Path $PSScriptRoot 'bin'))
$ErrorActionPreference = 'Stop'
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$prefix = Join-Path $logs "realityhatch-test-$stamp"
$layerLog = "$prefix.layer.log"
$envNames = @('XR_RUNTIME_JSON','XR_API_LAYER_PATH','XR_ENABLE_API_LAYERS','REALITYHATCH_LOG','XR_LOADER_DEBUG')
$saved = @{}
$process = $null
$dll = Join-Path $PSScriptRoot 'bin\layers\RealityHatchLayer.dll'
$signature = Get-AuthenticodeSignature -LiteralPath $dll
$metadata = [ordered]@{
    startedUtc = [DateTime]::UtcNow.ToString('o')
    layer = $dll
    layerSha256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    signatureStatus = $signature.Status.ToString()
    signerThumbprint = if ($signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null }
    manifestSha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'bin\layers\RealityHatch.json') -Algorithm SHA256).Hash
    runtimeManifest = 'C:\Program Files\Pimax\Runtime\PiOpenXR_64.json'
    graphics = 'Vulkan2'
    useDefaultLayerLog = [bool]$UseDefaultLog
    layerLog = $layerLog
    processId = $null
    exitedNaturally = $null
    exitCode = $null
    completedUtc = $null
    passed = $false
    sampleExecutable = Join-Path $SampleDirectory 'hello_xr.exe'
    loaderPath = Join-Path $SampleDirectory 'openxr_loader.dll'
    loaderSha256 = (Get-FileHash -LiteralPath (Join-Path $SampleDirectory 'openxr_loader.dll')).Hash
    loaderVersion = (Get-Item -LiteralPath (Join-Path $SampleDirectory 'openxr_loader.dll')).VersionInfo.FileVersion
}
try {
    foreach ($name in $envNames) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $env:XR_RUNTIME_JSON = 'C:\Program Files\Pimax\Runtime\PiOpenXR_64.json'
    $env:XR_API_LAYER_PATH = Join-Path $PSScriptRoot 'bin\layers'
    $env:XR_ENABLE_API_LAYERS = 'XR_APILAYER_NOVENDOR_realityhatch'
    $env:REALITYHATCH_LOG = if ($UseDefaultLog) { $null } else { $layerLog }
    $env:XR_LOADER_DEBUG = 'info'
    $process = Start-Process -FilePath $metadata.sampleExecutable `
        -ArgumentList '--graphics Vulkan2 --verbose' -WorkingDirectory $SampleDirectory `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput "$prefix.stdout.log" -RedirectStandardError "$prefix.stderr.log"
    if ($UseDefaultLog) {
        $layerLog = Join-Path $env:LOCALAPPDATA ('RealityHatch\logs\layer-' + [DateTime]::UtcNow.ToString('yyyyMMdd') + '-' + $process.Id + '.log')
        $metadata.layerLog = $layerLog
    }
    $exited = $process.WaitForExit($Seconds * 1000)
    $metadata.processId = $process.Id
    $metadata.exitedNaturally = $exited
    if ($exited) { $metadata.exitCode = $process.ExitCode }
    Write-Host "Sample process: $($process.Id); exited: $exited; logs: $prefix.*"
    if ($exited) { Write-Host "Sample exit code: $($process.ExitCode)" }
} finally {
    # Stop only the process this test started, never another sample or VR app.
    if ($process -and !$process.HasExited) { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    $metadata.completedUtc = [DateTime]::UtcNow.ToString('o')
    $metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$prefix.json" -Encoding UTF8
}
if (Test-Path -LiteralPath $layerLog) {
    $events = Get-Content -LiteralPath $layerLog -Raw
    Write-Output $events
} else { $events = '' }
$stdout = Get-Content -LiteralPath "$prefix.stdout.log" -Raw
$stderr = Get-Content -LiteralPath "$prefix.stderr.log" -Raw
if ($events -notmatch 'event=negotiation_entered result=0' -or
    $events -notmatch 'event=negotiation_headers result=0' -or
    $events -notmatch 'event=negotiation_versions result=0' -or
    $events -notmatch 'event=loader_negotiated result=0' -or
    $events -notmatch 'event=instance_created result=0' -or
    $events -notmatch 'event=session_created result=0' -or
    $events -notmatch 'event=end_frame_forwarded result=0' -or
    $stdout -notmatch ('LoadRuntime succeeded loading runtime defined in manifest file ' +
        [regex]::Escape('C:\Program Files\Pimax\Runtime\PiOpenXR_64.json'))) {
    Write-Output $stdout
    Write-Output $stderr
    throw "RealityHatch load/frame test did not pass. Inspect $prefix.*"
}
Write-Host 'PASS: RealityHatch instance/session creation and successful xrEndFrame forwarding on native Pimax.'
$metadata.passed = $true
$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$prefix.json" -Encoding UTF8
