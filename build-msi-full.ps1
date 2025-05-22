# Full PowerShell script to build MultiMC MSI installer
param (
    [string]$DownloadUrl = "https://files.multimc.org/downloads/mmc-develop-win32.zip",
    [string]$OutputDir = (Join-Path $PSScriptRoot "build"),
    [string]$TempDir = (Join-Path $PSScriptRoot "temp"),
    [string]$Version = "1.0.0",
    [switch]$InstallWix = $false
)

function Install-WixToolset {
    Write-Host "Installing WiX Toolset..."
    $wixUrl = "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311.exe"
    $wixInstaller = Join-Path $TempDir "wix311.exe"
    
    # Download WiX installer
    Invoke-WebRequest -Uri $wixUrl -OutFile $wixInstaller
    
    # Install WiX silently
    Start-Process -FilePath $wixInstaller -ArgumentList "/install", "/quiet" -Wait
    
    # Add WiX to PATH for this session
    $env:PATH += ";C:\Program Files (x86)\WiX Toolset v3.11\bin"
}

function Test-WixToolset {
    try {
        $null = Get-Command candle.exe -ErrorAction Stop
        $null = Get-Command light.exe -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Create necessary directories
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# Check if WiX is installed
if (-not (Test-WixToolset)) {
    if ($InstallWix) {
        Install-WixToolset
    } else {
        Write-Error "WiX Toolset is not installed. Run this script with -InstallWix to install it automatically."
        exit 1
    }
}

# Download MultiMC
Write-Host "Downloading MultiMC from $DownloadUrl..."
$zipPath = Join-Path $TempDir "multimc.zip"
Invoke-WebRequest -Uri $DownloadUrl -OutFile $zipPath

# Extract the ZIP file
Write-Host "Extracting MultiMC..."
Expand-Archive -Path $zipPath -DestinationPath $TempDir -Force

# Find the MultiMC directory (it might be in a subdirectory)
$multiMCDir = Get-ChildItem -Path $TempDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "MultiMC.exe") } | Select-Object -First 1
if (-not $multiMCDir) {
    # If we can't find a directory with MultiMC.exe, check if it's directly in the temp dir
    if (Test-Path (Join-Path $TempDir "MultiMC.exe")) {
        $multiMCDir = Get-Item $TempDir
    } else {
        Write-Error "Could not find MultiMC.exe in the extracted files."
        exit 1
    }
}

# Create license file from project LICENSE
$licensePath = Join-Path $TempDir "LICENSE"
Copy-Item -Path ".\LICENSE" -Destination $licensePath

# Create placeholder images for the installer
Write-Host "Creating UI bitmaps for the installer..."
$bannerPath = Join-Path $TempDir "banner.bmp"
$dialogPath = Join-Path $TempDir "dialog.bmp"

# Create empty bitmap files with System.Drawing if they don't exist
Add-Type -AssemblyName System.Drawing
if (-not (Test-Path $bannerPath)) {
    $banner = New-Object System.Drawing.Bitmap 493, 58
    $graphics = [System.Drawing.Graphics]::FromImage($banner)
    $graphics.FillRectangle([System.Drawing.Brushes]::White, 0, 0, 493, 58)
    $banner.Save($bannerPath)
    $banner.Dispose()
    $graphics.Dispose()
}

if (-not (Test-Path $dialogPath)) {
    $dialog = New-Object System.Drawing.Bitmap 493, 312
    $graphics = [System.Drawing.Graphics]::FromImage($dialog)
    $graphics.FillRectangle([System.Drawing.Brushes]::White, 0, 0, 493, 312)
    $dialog.Save($dialogPath)
    $dialog.Dispose()
    $graphics.Dispose()
}

# Copy the main WiX file to the temp directory
Copy-Item -Path ".\MultiMC.wxs" -Destination $TempDir

# Update version in the WiX file
$wxsPath = Join-Path $TempDir "MultiMC.wxs"
(Get-Content $wxsPath) -replace 'Version="1.0.0"', "Version=`"$Version`"" | Set-Content $wxsPath

# First, create a working directory for processing files
$workingDir = Join-Path $TempDir "MultiMCFiles"
New-Item -ItemType Directory -Force -Path $workingDir | Out-Null

# Copy all files from the MultiMC directory to the working directory
Copy-Item -Path "$($multiMCDir.FullName)\*" -Destination $workingDir -Recurse -Force

# Change to the temp directory for WiX commands
Push-Location $TempDir

try {
    # Debug - show what's in the directory
    Write-Host "Contents of MultiMC directory:"
    Get-ChildItem -Path $multiMCDir.FullName -Recurse | Select-Object -First 20 | ForEach-Object {
        Write-Host $_.FullName
    }
    
    # Generate the file list using heat
    Write-Host "Generating file list with heat..."
    $heatArgs = @(
        "dir"
        """$workingDir"""
        "-cg"
        "MultiMCFiles"
        "-dr"
        "INSTALLFOLDER"
        "-gg"
        "-srd"
        "-ke"
        "-sfrag"
        "-var"
        "var.SourceDir"
        "-out"
        "filelist.wxs"
    )
    $heatProc = Start-Process -FilePath "heat.exe" -ArgumentList $heatArgs -NoNewWindow -Wait -PassThru
    if ($heatProc.ExitCode -ne 0) {
        Write-Error "Heat exited with code $($heatProc.ExitCode)"
    }
    
    # Print the generated filelist.wxs for debugging
    Write-Host "Generated filelist.wxs first 20 lines:"
    Get-Content -Path "filelist.wxs" -TotalCount 20
    
    # Compile the WiX source files
    Write-Host "Compiling WiX source files with candle..."
    $candleArgs = @(
        "MultiMC.wxs"
        "filelist.wxs"
        "-dSourceDir=""$workingDir"""
    )
    $candleProc = Start-Process -FilePath "candle.exe" -ArgumentList $candleArgs -NoNewWindow -Wait -PassThru
    if ($candleProc.ExitCode -ne 0) {
        Write-Error "Candle exited with code $($candleProc.ExitCode)"
    }
    
    # Link the compiled objects into an MSI
    Write-Host "Linking with light to create MSI..."
    $msiPath = Join-Path $OutputDir "MultiMC-$Version.msi"
    $lightArgs = @(
        "-ext"
        "WixUIExtension"
        "MultiMC.wixobj"
        "filelist.wixobj"
        "-out"
        """$msiPath"""
        "-sval"
        "-b"
        """$TempDir"""
    )
    $lightProc = Start-Process -FilePath "light.exe" -ArgumentList $lightArgs -NoNewWindow -Wait -PassThru
    if ($lightProc.ExitCode -ne 0) {
        Write-Error "Light exited with code $($lightProc.ExitCode)"
    }
    
    if (Test-Path $msiPath) {
        Write-Host "MSI created successfully: $msiPath"
    } else {
        Write-Error "Failed to create MSI."
        exit 1
    }
} finally {
    # Return to the original directory
    Pop-Location
}

# Clean up temp files if successful
if (Test-Path $msiPath) {
    Write-Host "Cleaning up temporary files..."
    Remove-Item -Path $TempDir -Recurse -Force
}

Write-Host "Build completed successfully."