param()
$ErrorActionPreference = 'Stop'
$local = Join-Path $PSScriptRoot '.local'
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $local,$logs -Force | Out-Null
$log = Join-Path $logs ('certificate-setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log')
Start-Transcript -LiteralPath $log | Out-Null
try {
    $metadataPath = Join-Path $local 'development-certificate.json'
    $publicPath = Join-Path $local 'RealityHatch-Development.cer'
    $subject = 'CN=RealityHatch Development (PC2)'
    if (Test-Path -LiteralPath $metadataPath) {
        $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
        $cert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $metadata.thumbprint)
        if ($cert.Subject -ne $subject -or !$cert.HasPrivateKey -or $cert.NotAfter -le (Get-Date)) {
            throw 'Existing development certificate is not suitable; inspect it before replacing it.'
        }
        Write-Host 'Reusing the recorded development certificate.'
    } else {
        $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $subject `
            -FriendlyName 'RealityHatch local development signing' -CertStoreLocation Cert:\CurrentUser\My `
            -Provider 'Microsoft Software Key Storage Provider' -KeyAlgorithm RSA -KeyLength 3072 `
            -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -KeyUsage DigitalSignature `
            -NotAfter (Get-Date).AddYears(1)
        [ordered]@{
            subject = $cert.Subject
            thumbprint = $cert.Thumbprint
            store = 'Cert:\CurrentUser\My'
            trustStores = @('Cert:\CurrentUser\Root','Cert:\CurrentUser\TrustedPublisher')
            notBeforeUtc = $cert.NotBefore.ToUniversalTime().ToString('o')
            notAfterUtc = $cert.NotAfter.ToUniversalTime().ToString('o')
            privateKeyExportable = $false
            createdUtc = [DateTime]::UtcNow.ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding UTF8
    }
    # Export only the public certificate. The private key stays non-exportable
    # in the user's Windows key store; no PFX or password file is created.
    Export-Certificate -Cert $cert -FilePath $publicPath -Force | Out-Null
    foreach ($store in @('Cert:\CurrentUser\Root','Cert:\CurrentUser\TrustedPublisher')) {
        if (!(Test-Path -LiteralPath (Join-Path $store $cert.Thumbprint))) {
            Import-Certificate -FilePath $publicPath -CertStoreLocation $store | Out-Null
            Write-Host "Added public development certificate to $store"
        } else { Write-Host "Already trusted in $store" }
    }
    Write-Host "Subject: $($cert.Subject)"
    Write-Host "Thumbprint: $($cert.Thumbprint)"
    Write-Host "Expires UTC: $($cert.NotAfter.ToUniversalTime().ToString('o'))"
    Write-Host 'Scope: current Windows user on PC2; no machine-wide trust changes.'
} finally { Stop-Transcript | Out-Null }
