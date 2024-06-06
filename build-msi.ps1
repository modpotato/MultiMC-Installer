# PowerShell script to build MultiMC MSI installer
param (
    [string]$DownloadUrl = "https://files.multimc.org/downloads/mmc-develop-win32.zip",
    [string]$OutputDir = ".\build",
    [string]$TempDir = ".\temp",
    [string]$Version = "1.0.0"
)

# Create necessary directories
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

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

# Debug - show what's in the directory
Write-Host "Contents of MultiMC directory:"
Get-ChildItem -Path $multiMCDir.FullName -Recurse | Select-Object -First 20 | ForEach-Object {
    Write-Host $_.FullName
}

# First, create a working directory for processing files
$workingDir = Join-Path $TempDir "MultiMCFiles"
New-Item -ItemType Directory -Force -Path $workingDir | Out-Null

# Copy all files from the MultiMC directory to the working directory
Copy-Item -Path "$($multiMCDir.FullName)\*" -Destination $workingDir -Recurse -Force

# Create a file list for WiX
Write-Host "Creating file list for WiX..."
$fileListPath = Join-Path $TempDir "filelist.wxs"
$fileListContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
    <Fragment>
        <ComponentGroup Id="MultiMCFiles" Directory="INSTALLFOLDER">
"@

# Add all files to the component group
Get-ChildItem -Path $workingDir -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring($workingDir.Length + 1)
    $id = "File_" + [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + "_" + [Guid]::NewGuid().ToString("N")
    
    # Handle directory structure
    $dirPath = [System.IO.Path]::GetDirectoryName($relativePath)
    if ($dirPath) {
        $dirId = "Dir_" + $dirPath.Replace("\", "_").Replace(" ", "_").Replace(".", "_")
        
        # Add directory reference if it doesn't exist yet
        if ($fileListContent -notmatch $dirId) {
            $fileListContent += @"
            <DirectoryRef Id="INSTALLFOLDER">
                <Directory Id="$dirId" Name="$dirPath" />
            </DirectoryRef>
"@
        }
        
        $fileListContent += @"
            <Component Id="$id" Guid="*" Directory="$dirId">
                <File Id="$($id)_File" Source="$($_.FullName)" KeyPath="yes" />
            </Component>
"@
    } else {
        $fileListContent += @"
            <Component Id="$id" Guid="*">
                <File Id="$($id)_File" Source="$($_.FullName)" KeyPath="yes" />
            </Component>
"@
    }
}

$fileListContent += @"
        </ComponentGroup>
    </Fragment>
</Wix>
"@

$fileListContent | Out-File -FilePath $fileListPath -Encoding utf8

# Create a simple license file if it doesn't exist
$licensePath = Join-Path $TempDir "License.rtf"
@"
{\rtf1\ansi\ansicpg1252\deff0\nouicompat\deflang1033{\fonttbl{\f0\fnil\fcharset0 Calibri;}}
{\*\generator Riched20 10.0.19041}\viewkind4\uc1 
\pard\sa200\sl276\slmult1\f0\fs22\lang9 MultiMC Launcher License\par
MultiMC is licensed under the Apache License, Version 2.0.\par
You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0\par
}
"@ | Out-File -FilePath $licensePath -Encoding utf8

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

Write-Host "Files prepared for WiX. You can now run the WiX tools to build the MSI."
Write-Host "Example command: heat dir $workingDir -cg MultiMCFiles -dr INSTALLFOLDER -gg -srd -ke -sfrag -var var.SourceDir -out filelist.wxs"
Write-Host "               candle MultiMC.wxs filelist.wxs -dSourceDir=$workingDir"
Write-Host "               light -ext WixUIExtension MultiMC.wixobj filelist.wixobj -out $OutputDir\MultiMC-$Version.msi -sval -b $TempDir"

# Return the paths for use in other scripts
return @{
    "TempDir" = $TempDir
    "OutputDir" = $OutputDir
    "Version" = $Version
    "WorkingDir" = $workingDir
}