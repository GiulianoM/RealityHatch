param([ValidateSet('Auto', 'Certum', 'Development')][string]$SigningProfile = 'Auto')
$ErrorActionPreference = 'Stop'
$certumMetadataPath = Join-Path $PSScriptRoot '.local\certum-signing.json'
if ($SigningProfile -eq 'Auto') {
    $SigningProfile = if (Test-Path -LiteralPath $certumMetadataPath) { 'Certum' } else { 'Development' }
}
$metadataPath = if ($SigningProfile -eq 'Certum') { $certumMetadataPath } else {
    Join-Path $PSScriptRoot '.local\development-certificate.json'
}
if (!(Test-Path -LiteralPath $metadataPath)) { throw "Signing configuration missing: $metadataPath" }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$cert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $metadata.thumbprint)
if (!$cert.HasPrivateKey -or $cert.NotBefore -gt (Get-Date) -or $cert.NotAfter -le (Get-Date)) {
    throw 'Signing certificate or its private-key association is unavailable or invalid.'
}
if ($SigningProfile -eq 'Development' -and $cert.Subject -ne 'CN=RealityHatch Development (PC2)') {
    throw 'Unexpected development signing identity.'
}
if ($SigningProfile -eq 'Certum' -and ($cert.Subject -ne $metadata.subject -or $cert.Issuer -ne $metadata.issuer -or
    $cert.Issuer -notmatch 'CN=Certum Code Signing')) {
    throw 'Unexpected Certum signing identity.'
}
$ekuExtension = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' }
if ('1.3.6.1.5.5.7.3.3' -notin @($ekuExtension.EnhancedKeyUsages | ForEach-Object { $_.Value })) {
    throw 'Selected certificate does not have the code-signing EKU.'
}
$kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$signtool = Get-ChildItem -LiteralPath $kits -Directory | Where-Object { $_.Name -match '^10\.0\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | ForEach-Object { Join-Path $_.FullName 'x64\signtool.exe' } |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (!$signtool) { throw 'Windows SDK SignTool was not found.' }
$dll = Join-Path $PSScriptRoot 'bin\layers\RealityHatchLayer.dll'
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$prefix = Join-Path $logs ('signing-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
Start-Transcript -LiteralPath "$prefix.log" | Out-Null
try {
    $before = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    Copy-Item -LiteralPath $dll -Destination "$prefix.before.dll"
    $signArguments = @('sign', '/sha1', $cert.Thumbprint, '/s', 'My', '/fd', 'SHA256', '/d', 'RealityHatch OpenXR API layer', '/v')
    if ($SigningProfile -eq 'Certum') {
        if ($metadata.timestampUrl -ne 'http://time.certum.pl') { throw 'Unexpected Certum timestamp endpoint.' }
        $signArguments += @('/tr', $metadata.timestampUrl, '/td', 'SHA256')
    }
    $signArguments += $dll
    & $signtool @signArguments
    if ($LASTEXITCODE -ne 0) { throw 'SignTool signing failed.' }
    & $signtool verify /pa /all /v $dll
    if ($LASTEXITCODE -ne 0) { throw 'SignTool Authenticode verification failed.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $dll
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $cert.Thumbprint) {
        throw 'Signed layer does not validate against the expected signing certificate.'
    }
    if ($SigningProfile -eq 'Certum' -and !$signature.TimeStamperCertificate) {
        throw 'Certum signature has no verified timestamp.'
    }
    [ordered]@{
        signedUtc = [DateTime]::UtcNow.ToString('o')
        file = $dll
        sha256Before = $before
        sha256After = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
        subject = $cert.Subject
        issuer = $cert.Issuer
        thumbprint = $cert.Thumbprint
        signingProfile = $SigningProfile
        signatureStatus = $signature.Status.ToString()
        trustScope = if ($SigningProfile -eq 'Certum') { 'Public CA; Windows Authenticode verified on PC2' } else { 'Local development trust on PC2' }
        timestamped = [bool]$signature.TimeStamperCertificate
        timestampSubject = if ($signature.TimeStamperCertificate) { $signature.TimeStamperCertificate.Subject } else { $null }
        timestampUrl = if ($SigningProfile -eq 'Certum') { $metadata.timestampUrl } else { $null }
        signtool = $signtool
    } | ConvertTo-Json | Set-Content -LiteralPath "$prefix.json" -Encoding UTF8
    Write-Host "Signed and verified: $dll"
    Write-Host "Signing evidence: $prefix.log and .json"
} finally { Stop-Transcript | Out-Null }
