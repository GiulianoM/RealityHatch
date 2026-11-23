param(
    [string]$VulkanSdk = (Join-Path $PSScriptRoot 'tools\VulkanSDK'),
    [string]$PythonExecutable = 'python',
    [string]$LoaderDll = (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\SteamVR\bin\win64\openxr_loader.dll')
)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'OpenXR-SDK-Source'
$build = Join-Path $PSScriptRoot 'build\hello-xr-vulkan'
$bin = Join-Path $PSScriptRoot 'bin'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (!(Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio 2022 C++ Build Tools first.' }
$vs = & $vswhere -latest -products '*' -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vs) { throw 'Visual Studio 2022 C++ tools were not found.' }
$cmake = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
if (!(Test-Path -LiteralPath $cmake)) { throw 'Install the Visual Studio C++ CMake tools component.' }
if (!(Test-Path -LiteralPath (Join-Path $VulkanSdk 'Include\vulkan\vulkan.h'))) { throw "Vulkan SDK headers not found: $VulkanSdk" }
$pythonCommand = Get-Command -Name $PythonExecutable -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$pythonCommand) { throw 'Install Python 3 on PATH or supply -PythonExecutable with its full path.' }
$PythonExecutable = $pythonCommand.Source
if (!(Test-Path -LiteralPath $LoaderDll)) { throw 'Supply -LoaderDll with a compatible, Authenticode-signed x64 OpenXR loader DLL. The default uses the installed SteamVR copy.' }
$loaderSignature = Get-AuthenticodeSignature -LiteralPath $LoaderDll
if ($loaderSignature.Status -ne 'Valid') { throw "Loader signature must be valid: $LoaderDll ($($loaderSignature.Status))" }
New-Item -ItemType Directory -Path $build,$bin -Force | Out-Null
$oldSdk = $env:VULKAN_SDK
try {
    $env:VULKAN_SDK = $VulkanSdk
    & $cmake -S $source -B $build -G 'Visual Studio 17 2022' -A x64 `
        '-DBUILD_TESTS=ON' '-DBUILD_SDK_TESTS=ON' '-DBUILD_API_LAYERS=OFF' `
        '-DBUILD_CONFORMANCE_TESTS=OFF' '-DBUILD_TESTING=OFF' '-DDYNAMIC_LOADER=ON' `
        "-DPython3_EXECUTABLE=$PythonExecutable" `
        '-UCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE' `
        "-DGLSL_COMPILER=$VulkanSdk\Bin\glslc.exe" 2>&1 | Tee-Object -FilePath (Join-Path $build 'configure.log')
    if ($LASTEXITCODE -ne 0) { throw "CMake configure failed: $LASTEXITCODE" }
    $cache = Get-Content -LiteralPath (Join-Path $build 'CMakeCache.txt') -Raw
    if ($cache -notmatch 'Vulkan_LIBRARY:FILEPATH=[^\r\n]+vulkan-1.lib') { throw 'Vulkan was not enabled; inspect configure.log.' }
    & $cmake --build $build --config Release --target hello_xr --parallel 8 2>&1 | Tee-Object -FilePath (Join-Path $build 'build.log')
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $LASTEXITCODE" }
    $sampleOutput = Join-Path $build 'src\tests\hello_xr\Release'
    Copy-Item -LiteralPath (Join-Path $sampleOutput 'hello_xr.exe') -Destination $bin -Force
    # Retain the upstream build output, but deploy a trusted loader: PC2's
    # Windows Code Integrity policy rejects the locally compiled unsigned DLL.
    Copy-Item -LiteralPath $LoaderDll -Destination (Join-Path $bin 'openxr_loader.dll') -Force
    if ((Get-AuthenticodeSignature -LiteralPath (Join-Path $bin 'openxr_loader.dll')).Status -ne 'Valid') { throw 'Deployed loader signature validation failed.' }
    [ordered]@{
        source = $LoaderDll
        version = (Get-Item -LiteralPath $LoaderDll).VersionInfo.FileVersion
        publisher = $loaderSignature.SignerCertificate.Subject
        certificateThumbprint = $loaderSignature.SignerCertificate.Thumbprint
        sha256 = (Get-FileHash -LiteralPath (Join-Path $bin 'openxr_loader.dll') -Algorithm SHA256).Hash
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $bin 'openxr-loader-provenance.json') -Encoding UTF8
    Get-ChildItem -LiteralPath $sampleOutput -Filter '*.pdb' | Copy-Item -Destination $bin -Force
    if (!(Test-Path -LiteralPath (Join-Path $bin 'hello_xr.exe'))) { throw 'Build completed without the expected executable.' }
    Write-Host "Built: $bin\hello_xr.exe"
} finally {
    $env:VULKAN_SDK = $oldSdk
}
