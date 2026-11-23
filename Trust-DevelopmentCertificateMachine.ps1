param()
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this script as administrator to import the public certificate into Local Machine stores.'
}
$metadata = Get-Content -LiteralPath (Join-Path $PSScriptRoot '.local\development-certificate.json') -Raw | ConvertFrom-Json
$publicPath = Join-Path $PSScriptRoot '.local\RealityHatch-Development.cer'
$public = New-Object Security.Cryptography.X509Certificates.X509Certificate2($publicPath)
if ($public.Thumbprint -ne $metadata.thumbprint -or $public.Subject -ne 'CN=RealityHatch Development (PC2)' -or $public.HasPrivateKey) {
    throw 'Public certificate identity mismatch, or certificate unexpectedly contains a private key.'
}
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$prefix = Join-Path $logs ('machine-certificate-trust-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
Start-Transcript -LiteralPath "$prefix.log" | Out-Null
try {
    $changes = @(foreach ($store in @('Cert:\LocalMachine\Root','Cert:\LocalMachine\TrustedPublisher')) {
        $path = Join-Path $store $public.Thumbprint
        $alreadyPresent = Test-Path -LiteralPath $path
        if (!$alreadyPresent) { Import-Certificate -FilePath $publicPath -CertStoreLocation $store | Out-Null }
        if (!(Test-Path -LiteralPath $path)) { throw "Certificate was not found after import: $store" }
        Write-Host "Verified $store : $($public.Thumbprint)"
        [ordered]@{store=$store;alreadyPresent=$alreadyPresent;presentAfter=$true}
    })
    $record = [ordered]@{utc=[DateTime]::UtcNow.ToString('o');subject=$public.Subject;thumbprint=$public.Thumbprint;publicCertificateOnly=$true;stores=$changes}
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$prefix.json" -Encoding UTF8
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot '.local\machine-certificate-trust.json') -Encoding UTF8
} finally { Stop-Transcript | Out-Null }
