@echo off
setlocal
powershell.exe -NoLogo -NoProfile -File "%~dp0Run-HelloXR-RealityHatch.ps1" %*
if errorlevel 1 pause
