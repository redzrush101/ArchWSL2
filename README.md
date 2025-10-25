# ArchWSL2
Arch Linux on WSL2 (Windows 10 FCU or later) based on [wsldl](https://github.com/yuk7/wsldl).

[![Screenshot-2022-07-26-064739.png](https://i.postimg.cc/wBzRfFbg/Screenshot-2022-07-26-064739.png)](https://postimg.cc/sMn21PrN)
[![Github All Releases](https://img.shields.io/github/downloads/sileshn/ArchWSL2/total?logo=github&style=flat-square)](https://github.com/sileshn/ArchWSL2/releases) [![GitHub release (latest by date)](https://img.shields.io/github/v/release/sileshn/ArchWSL2?display_name=release&label=latest%20release&style=flat-square)](https://github.com/sileshn/ArchWSL2/releases/latest)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com) [![License](https://img.shields.io/github/license/sileshn/ArchWSL2.svg?style=flat-square)](https://github.com/sileshn/ArchWSL2/blob/main/LICENSE)

## Features
* Increase virtual disk size from default 256GB
* Create new user and set as default
* Native systemd support (WSL v0.67.6+)
* Configurable wsl.conf with [section headers](https://i.postimg.cc/MZ4DC1Fw/Screenshot-2022-02-02-071533.png)

## Intel Graphics Note
Intel WSL driver may not load properly by default. Fix with `ldd /usr/lib/wsl/drivers/iigd_dch_d.inf_amd64_49b17bc90a910771/*.so` and install missing libraries or create symlinks for version mismatches.

## Requirements
* x64: Windows 10 Version 1903+ (Build 18362+)
* ARM64: Windows 10 Version 2004+ (Build 19041+)
* WSL 2 requires Build 18362+

## Installation
### Windows 10 Version 2004+
```cmd
wsl.exe --install
```

### Windows 10 Version < 2004
```cmd
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```
Install [Linux kernel update](https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi)

## ArchWSL2 Installation
1. [Download](https://github.com/sileshn/ArchWSL2/releases/latest) installer zip
2. Extract all files to same directory
3. Set WSL 2 as default (manual installation only):
   ```cmd
   wsl --set-default-version 2
   ```
4. Run `Arch.exe` to extract rootfs and register to WSL

**Note:** Rename `Arch.exe` for multiple instances with different names.

## User Setup
### First Run
ArchWSL2 prompts for user creation. For manual setup:

```cmd
passwd
useradd -m -g users -G wheel -s /bin/bash <username>
echo "%wheel ALL=(ALL) ALL" >/etc/sudoers.d/wheel
passwd <username>
exit
```

### Set Default User
**Method 1:** Edit wsl.conf
```cmd
sed -i '/\[user\]/a default = username' /etc/wsl.conf
```
Restart WSL.

**Method 2:** Use config command
```cmd
Arch.exe config --default-user <username>
```

## Usage
### Commands
```cmd
Arch.exe                    # Open shell
Arch.exe run <command>      # Run command
Arch.exe config --default-user <user>  # Set default user
Arch.exe backup <file>      # Create backup
Arch.exe clean              # Uninstall instance
```

### Examples
```cmd
>Arch.exe run uname -r
>Arch.exe runp echo C:\Windows\System32\cmd.exe
>Arch.exe config --default-term wt
```

## Update
```cmd
sudo pacman -Syu              # Standard update
sudo pacman -Syyuu            # Force refresh if update fails
```

## Backup & Restore
### Backup
```cmd
Arch.exe backup backup.tar.gz           # WSL1/2
Arch.exe backup backup.ext4.vhdx.gz     # WSL2 only
```

### Restore
```cmd
Arch.exe install backup.tar.gz          # .tar.gz files
Arch.exe install backup.ext4.vhdx.gz    # .vhdx files
```

## Uninstall
```cmd
Arch.exe clean
```

## Build from Source
### Prerequisites
Docker, tar, zip, unzip, bsdtar

```cmd
git clone https://github.com/sileshn/ArchWSL2.git
cd ArchWSL2
make
make clean    # Clean build artifacts
```

## Docker Setup
```cmd
sudo pacman -S docker
sudo systemctl start docker.service
sudo systemctl enable docker.service
sudo usermod -aG docker $USER
```
