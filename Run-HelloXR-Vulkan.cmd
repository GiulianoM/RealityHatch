@echo off
setlocal
set "XR_RUNTIME_JSON=C:\Program Files\Pimax\Runtime\PiOpenXR_64.json"
if not exist "%XR_RUNTIME_JSON%" (
  echo Pimax OpenXR runtime manifest not found: %XR_RUNTIME_JSON%
  pause
  exit /b 1
)
cd /d "%~dp0bin"
hello_xr.exe --graphics Vulkan2 --verbose %*
if errorlevel 1 pause
