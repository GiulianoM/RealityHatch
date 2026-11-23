param([Parameter(ValueFromRemainingArguments=$true)][string[]]$SampleArguments)
$ErrorActionPreference = 'Stop'
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$prefix = Join-Path $logs ('realityhatch-run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$names = @('XR_RUNTIME_JSON','XR_API_LAYER_PATH','XR_ENABLE_API_LAYERS','REALITYHATCH_LOG','XR_LOADER_DEBUG')
$saved = @{}
$result = 1
Start-Transcript -LiteralPath "$prefix.launcher.log" | Out-Null
try {
    foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $env:XR_RUNTIME_JSON = 'C:\Program Files\Pimax\Runtime\PiOpenXR_64.json'
    $env:XR_API_LAYER_PATH = Join-Path $PSScriptRoot 'bin\layers'
    $env:XR_ENABLE_API_LAYERS = 'XR_APILAYER_NOVENDOR_realityhatch'
    $env:REALITYHATCH_LOG = "$prefix.layer.log"
    $env:XR_LOADER_DEBUG = 'info'
    if (!(Test-Path -LiteralPath $env:XR_RUNTIME_JSON)) { throw 'Native Pimax runtime manifest was not found.' }
    $dll = Join-Path $PSScriptRoot 'bin\layers\RealityHatchLayer.dll'
    $signature = Get-AuthenticodeSignature -LiteralPath $dll
    [ordered]@{
        startedUtc = [DateTime]::UtcNow.ToString('o')
        layerSha256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
        signatureStatus = $signature.Status.ToString()
        signerThumbprint = if ($signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null }
        runtimeManifest = $env:XR_RUNTIME_JSON
        graphics = 'Vulkan2'
        arguments = $SampleArguments
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$prefix.json" -Encoding UTF8
    Write-Host "Logs: $prefix.*"
    # Windows PowerShell 5.1 turns redirected native stderr into ErrorRecords.
    # Loader warnings must be captured, not terminate this logging pipeline.
    try {
        $ErrorActionPreference = 'Continue'
        & (Join-Path $PSScriptRoot 'bin\hello_xr.exe') --graphics Vulkan2 --verbose @SampleArguments 2>&1 |
            Tee-Object -FilePath "$prefix.console.log"
        $result = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    Write-Host "Sample exit code: $result"
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    Stop-Transcript | Out-Null
}
exit $result
