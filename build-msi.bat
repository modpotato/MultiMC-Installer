@echo off
REM Batch file to run the PowerShell build script

echo Building MultiMC MSI Installer...
echo This script will download MultiMC, prepare files, and create an MSI installer
echo Using improved file path handling with robust error checking

powershell -ExecutionPolicy Bypass -File .\build-msi-full.ps1 %*
if %ERRORLEVEL% NEQ 0 (
    echo Build failed with error code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo Build completed successfully.
echo MSI installer can be found in the 'build' directory.