param()
$ErrorActionPreference = 'Stop'
$metadataPath = Join-Path $PSScriptRoot '.local\development-certificate.json'
if (!(Test-Path -LiteralPath $metadataPath)) { throw 'Run Initialize-DevelopmentCertificate.ps1 first.' }
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$cert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $metadata.thumbprint)
if ($cert.Subject -ne 'CN=RealityHatch Development (PC2)' -or !$cert.HasPrivateKey -or $cert.NotAfter -le (Get-Date)) {
    throw 'Development signing certificate is unavailable or invalid.'
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
    & $signtool sign /sha1 $cert.Thumbprint /s My /fd SHA256 /d 'RealityHatch development layer' /v $dll
    if ($LASTEXITCODE -ne 0) { throw 'SignTool signing failed.' }
    & $signtool verify /pa /all /v $dll
    if ($LASTEXITCODE -ne 0) { throw 'SignTool Authenticode verification failed.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $dll
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ne $cert.Thumbprint) {
        throw 'Signed layer does not validate against the expected development certificate.'
    }
    [ordered]@{
        signedUtc = [DateTime]::UtcNow.ToString('o')
        file = $dll
        sha256Before = $before
        sha256After = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
        subject = $cert.Subject
        thumbprint = $cert.Thumbprint
        signatureStatus = $signature.Status.ToString()
        trustScope = 'CurrentUser on PC2'
        timestamped = $false
        signtool = $signtool
    } | ConvertTo-Json | Set-Content -LiteralPath "$prefix.json" -Encoding UTF8
    Write-Host "Signed and verified: $dll"
    Write-Host "Signing evidence: $prefix.log and .json"
} finally { Stop-Transcript | Out-Null }
