# MultiMC Installer

A comprehensive installer for the popular Minecraft instance manager MultiMC. https://multimc.org/
**Disclaimer:** I am not associated with MultiMC. I have just created an auto-building installer for it.

## Download
*win64 is the only supported platform right now*

#### [Latest Release](https://github.com/modpotato/MultiMC-Installer/releases/latest)

## Setup Guide

1. Download the install from the link above.
2. Run the installer executable.
3. Follow the on-screen instructions to complete the installation process.
4. Once installed, launch MultiMC from your Start menu or desktop shortcut.

## Automated Builds (requires forked repo)

This repository includes a GitHub Action workflow that can automatically build and release the MSI installer. To trigger a new build:

1. Go to the "Actions" tab in the repository
2. Select the "Build and Release MSI Installer" workflow
3. Click "Run workflow"
4. Enter the version number and MultiMC download URL (defaults to the development build)
5. Click "Run workflow" to start the build process

The workflow will:
- Download the specified MultiMC version
- Build an MSI installer
- Create a new GitHub release with the installer

## Todo

- [x] Recode into an actual installer
- [x] Workflow to automate releases
- [ ] Support for linux

## Development

### Building the MSI Installer Locally

To build the MSI installer locally on Windows:

1. Install the [WiX Toolset](https://wixtoolset.org/releases/)
2. Run the build script:
   ```powershell
   .\build-msi-full.ps1 -Version "1.0.0" -DownloadUrl "https://files.multimc.org/downloads/mmc-develop-win32.zip"
   ```
3. The MSI will be created in the `build` directory

## Links

- [MultiMC Website](https://multimc.org/)
- [MultiMC Documentation](https://multimc.org/docs/)
- [MultiMC GitHub Repository](https://github.com/MultiMC/MultiMC5)
