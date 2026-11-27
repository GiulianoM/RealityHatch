param([switch]$NoSign)
$ErrorActionPreference = 'Stop'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vs = & $vswhere -latest -products '*' -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'Visual Studio 2022 C++ tools not found.' }
$cmake = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
$build = Join-Path $PSScriptRoot 'build\realityhatch'
New-Item -ItemType Directory -Path $build -Force | Out-Null
& $cmake -S (Join-Path $PSScriptRoot 'layer') -B $build -G 'Visual Studio 17 2022' -A x64 2>&1 | Tee-Object (Join-Path $build 'configure.log')
if ($LASTEXITCODE -ne 0) { throw 'RealityHatch configure failed.' }
& $cmake --build $build --config Release --parallel 8 2>&1 | Tee-Object (Join-Path $build 'build.log')
if ($LASTEXITCODE -ne 0) { throw 'RealityHatch build failed.' }
Write-Host 'Built bin\layers\RealityHatchLayer.dll and its manifest.'
if (!$NoSign -and ((Test-Path -LiteralPath (Join-Path $PSScriptRoot '.local\certum-signing.json')) -or
    (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.local\development-certificate.json')))) {
    & (Join-Path $PSScriptRoot 'Sign-RealityHatch.ps1')
}
