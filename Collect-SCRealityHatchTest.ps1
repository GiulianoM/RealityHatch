param([string]$Directory, [ValidateSet('before','during','after')][string]$Phase = 'during')
$ErrorActionPreference = 'Stop'
if (!$Directory) { $Directory = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '.local\current-sc-test.json') -Raw | ConvertFrom-Json).directory }
$resolved = [IO.Path]::GetFullPath($Directory)
$logsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'logs')) + '\'
if (!$resolved.StartsWith($logsRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Evidence must stay within project logs.' }
$metadata = Get-Content -LiteralPath (Join-Path $resolved 'test.json') -Raw | ConvertFrom-Json
$destination = Join-Path $resolved ($Phase + '-' + (Get-Date -Format 'HHmmss'))
New-Item -ItemType Directory -Path $destination -Force | Out-Null
function Copy-SharedLog([string]$Source, [string]$Target) {
    if (!(Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    $inputFile = $null; $outputFile = $null
    try {
        $inputFile = [IO.File]::Open($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $outputFile = [IO.File]::Create($Target)
        $inputFile.CopyTo($outputFile)
    } catch { Write-Warning "Could not snapshot $Source : $($_.Exception.Message)" }
    finally { if ($outputFile) {$outputFile.Dispose()}; if ($inputFile) {$inputFile.Dispose()} }
}
Copy-SharedLog (Join-Path $metadata.gameRoot 'Game.log') (Join-Path $destination 'Game.log')
foreach ($root in @((Join-Path $env:APPDATA 'EasyAntiCheat'),(Join-Path $env:APPDATA 'rsilauncher\logs'))) {
    if (Test-Path -LiteralPath $root) {
        foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.log' -Recurse -File) {
            $relative = $file.FullName.Substring($root.Length).TrimStart('\').Replace('\','-')
            $prefix = if ($root -match 'EasyAntiCheat') {'eac-'} else {'rsi-'}
            Copy-SharedLog $file.FullName (Join-Path $destination ($prefix + $relative))
        }
    }
}
try {
    # Preserve all records in the test window: signature-information events can
    # correlate by ActivityID without repeating the blocked DLL's filename.
    $end = [DateTime]::UtcNow
    $allEvents = @(Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-CodeIntegrity/Operational';StartTime=([DateTime]$metadata.startedUtc).ToLocalTime();EndTime=$end.ToLocalTime()} -ErrorAction Stop)
    @('<Events>') + @($allEvents | ForEach-Object { $_.ToXml() }) + @('</Events>') |
        Set-Content -LiteralPath (Join-Path $destination 'code-integrity-window.xml') -Encoding UTF8
    $events = @($allEvents |
        Where-Object { $_.Message -match 'RealityHatch|StarCitizen' } | Select-Object TimeCreated,Id,Message)
    ConvertTo-Json -InputObject $events -Depth 4 | Set-Content -LiteralPath (Join-Path $destination 'code-integrity.json') -Encoding UTF8
} catch {
    $_.Exception.Message | Set-Content -LiteralPath (Join-Path $destination 'code-integrity-read-status.txt') -Encoding UTF8
}
$gameLoader = Join-Path $metadata.gameRoot 'Bin64\openxr_loader.dll'
if (Test-Path -LiteralPath $gameLoader) {
    $loaderFile = Get-Item -LiteralPath $gameLoader
    $loaderSignature = Get-AuthenticodeSignature -LiteralPath $gameLoader
    [ordered]@{path=$gameLoader;sha256=(Get-FileHash -LiteralPath $gameLoader -Algorithm SHA256).Hash;
        fileVersion=$loaderFile.VersionInfo.FileVersion;productVersion=$loaderFile.VersionInfo.ProductVersion;
        signatureStatus=$loaderSignature.Status.ToString();signer=$loaderSignature.SignerCertificate.Subject} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'game-loader-identity.json') -Encoding UTF8
}
Get-AuthenticodeSignature -LiteralPath $metadata.layer |
    Select-Object Status,StatusMessage,@{Name='Signer';Expression={$_.SignerCertificate.Subject}},@{Name='Thumbprint';Expression={$_.SignerCertificate.Thumbprint}} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'layer-signature.json') -Encoding UTF8
Write-Host "Saved snapshot: $destination"
