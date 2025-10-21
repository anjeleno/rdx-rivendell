# Smart Installer - Deployment Guide

## Overview

The RDX smart installer automatically detects and installs missing dependencies on target Rivendell systems, making deployment seamless across different environments.

## Key Features

### 🔍 **Intelligent Dependency Detection**
- Scans for all required build tools, libraries, and codecs
- Detects existing Rivendell installation and version
- Identifies missing packages and suggests installations
- Supports Ubuntu/Debian package management

### 📦 **Comprehensive Package Management**
- Qt5 framework (Core, Widgets, DBus, SQL, Network)
- Audio systems (JACK, ALSA, PulseAudio)
- Multimedia codecs (FFmpeg, Vorbis, FLAC, AAC+)
- Build tools (CMake, GCC, pkg-config)
- Optional enhancements (ImageMagick, systemd)

### 🛡️ **Safe Installation Process**
- Creates automatic backups before installation
- Supports dry-run mode for preview
- Interactive confirmation for dependency installation
- Force mode for environments with known missing deps
- Comprehensive logging and verification

## Installation Modes

### 1. **Interactive Mode (Recommended)**
```bash
sudo ./smart-install.sh
```
**Features:**
- Prompts user for confirmation
- Shows detailed dependency analysis
- Allows selective installation

### 2. **Automatic Mode**
```bash
sudo ./smart-install.sh -y
```
**Features:**
- No user prompts
- Installs all missing dependencies
- Perfect for automated deployments

### 3. **Dry-Run Mode**
```bash
sudo ./smart-install.sh -d
```
**Features:**
- Shows what would be installed
- No actual changes made
- Perfect for deployment planning

### 4. **Force Mode**
```bash
sudo ./smart-install.sh -f
```
**Features:**
- Continues even if dependencies fail
- For environments with known limitations
- Advanced users only

## Dependency Categories Detected

### Core Build Tools
- **cmake** - Build system generator
- **build-essential** - GCC compiler and make
- **pkg-config** - Library metadata tool

### Qt5 Framework
- **qtbase5-dev** - Core Qt5 development
- **qtbase5-dev-tools** - Qt5 build tools (moc, etc.)

### Audio System
- **libjack-jackd2-dev** - JACK audio development
- **libasound2-dev** - ALSA sound system
- **libpulse-dev** - PulseAudio development

### Multimedia Codecs
- **libavcodec-dev** - FFmpeg video/audio codecs
- **libavformat-dev** - FFmpeg container formats
- **libavutil-dev** - FFmpeg utilities
- **libswresample-dev** - FFmpeg audio resampling
- **ffmpeg** - Complete multimedia framework

### Additional Libraries
- **libvorbis-dev** - Ogg Vorbis codec
- **libflac-dev** - FLAC lossless codec
- **libtag1-dev** - Metadata handling
- **libcurl4-openssl-dev** - HTTP/networking
- **libssl-dev** - SSL/TLS encryption
- **libmusicbrainz5-dev** - Music database

### System Libraries
- **libpam0g-dev** - Authentication
- **libsamplerate0-dev** - Audio resampling
- **libsoundtouch-dev** - Audio processing
- **libdiscid-dev** - CD identification

## Target System Requirements

### Operating System
- **Ubuntu 20.04+** (Focal Fossa or later)
- **Debian 11+** (Bullseye or later)
- **Other Debian-based distributions** (with apt package manager)

### Rivendell Installation
- **Any working Rivendell installation**
- **Version 3.x or 4.x supported**
- **Standard installation paths detected automatically**

### System Resources
- **50MB disk space** (for dependencies)
- **Root access** (for system package installation)
- **Internet connection** (for package downloads)

## Deployment Scenarios

### Scenario 1: Fresh Rivendell System
```bash
# System has Rivendell but no development packages
./smart-install.sh -y
# Result: Installs all build dependencies + RDX
```

### Scenario 2: Development System
```bash
# System already has some development tools
./smart-install.sh
# Result: Only installs missing packages
```

### Scenario 3: Offline/Restricted System
```bash
# Install dependencies manually first, then:
./smart-install.sh -s
# Result: Skips dependency installation, installs RDX only
```

### Scenario 4: Testing/Preview
```bash
# Preview what would be installed
./smart-install.sh -d
# Result: Shows dependency analysis without changes
```

## Verification Process

The installer automatically verifies:

### ✅ **Tool Installation**
- rdx-jack-helper executable and version
- AAC+ streaming tools availability
- Symbolic link creation

### ✅ **Dependency Satisfaction**
- FFmpeg availability for AAC+ encoding
- Rivendell library integration
- Qt5 framework completeness

### ✅ **Service Integration**
- systemd service installation
- Service enablement (optional)
- Configuration file placement

## Troubleshooting

### Common Issues

#### "Rivendell installation not found"
**Solution:** Ensure Rivendell is installed and rdadmin is in PATH
```bash
which rdadmin
# Should return path to rdadmin executable
```

#### "Package installation failed"
**Solution:** Check internet connection and package repositories
```bash
apt update
apt list --upgradable
```

#### "Permission denied"
**Solution:** Run installer with sudo
```bash
sudo ./smart-install.sh
```

### Advanced Troubleshooting

#### Check Installation Log
```bash
cat /tmp/rdx-install.log
```

#### Verify Dependencies Manually
```bash
./verify-install.sh
```

#### Test Individual Components
```bash
rdx-jack-helper --version
rdx-aac-stream -h
```

## Example Installation Session

```bash
$ sudo ./smart-install.sh

================================================================
  RDX Rivendell Enhancement - Smart Installer v2.0.0
  Intelligent dependency detection and installation
================================================================

[INFO] Detected OS: Ubuntu 22.04.3 LTS (jammy)
[SUCCESS] Found Rivendell at: /usr
[INFO] Rivendell version: 4.3.0

[PROGRESS] Scanning system dependencies...

Core Build Tools:
[SUCCESS] ✓ cmake found
[SUCCESS] ✓ make found
[SUCCESS] ✓ g++ found

Qt5 Framework:
[SUCCESS] ✓ libQt5Core found
[WARNING] ✗ libQt5Widgets missing
[WARNING] ✗ libQt5DBus missing

Audio System:
[SUCCESS] ✓ libjack found
[WARNING] ✗ libasound missing

[WARNING] 8 dependencies missing

[PROGRESS] Installing missing dependencies...
[INFO] Packages to install: qtbase5-dev libasound2-dev libavcodec-dev...

Install these packages? [y/N]: y

[INFO] Updating package cache...
[INFO] Installing packages...
[SUCCESS] Dependencies installed successfully

[PROGRESS] Creating backup of existing installation...
[SUCCESS] Backup created at: /tmp/rdx-backup-20251020-123456

[PROGRESS] Installing RDX enhancement package...
[SUCCESS] Installed: rdx-jack-helper
[SUCCESS] Installed: AAC+ streaming tools
[SUCCESS] Installed: systemd service

Enable RDX service to start on boot? [y/N]: y
[SUCCESS] RDX service enabled for auto-start

[PROGRESS] Verifying installation...
[SUCCESS] rdx-jack-helper installed: 1.0.0
[SUCCESS] AAC+ streaming tools installed
[SUCCESS] FFmpeg available for AAC+ encoding
[SUCCESS] Rivendell integration available

=========================
  INSTALLATION COMPLETE  
=========================

[SUCCESS] RDX Rivendell Enhancement installed successfully!

Installed Tools:
  • rdx-jack-helper    - Intelligent JACK management
  • rdx-aac-stream     - Professional AAC+ streaming

Quick Start:
  # Test JACK helper
  rdx-jack-helper --version

  # Start AAC+ stream (example)
  rdx-aac-stream -b 64 -1 icecast://source:password@server:8000/stream.aac

Documentation:
  • Complete guide: ./AAC_STREAMING_GUIDE.md
  • Installation log: /tmp/rdx-install.log
  • Backup location: /tmp/rdx-backup-20251020-123456

Service Management:
  systemctl start rdx-jack-helper
  systemctl enable rdx-jack-helper
  systemctl status rdx-jack-helper

[SUCCESS] Ready for professional broadcast audio enhancement!
```

## Benefits of Smart Installation

### 🚀 **Deployment Efficiency**
- **Zero manual dependency hunting**
- **One-command installation**
- **Automatic environment adaptation**

### 🛡️ **Error Prevention**
- **Missing dependency detection**
- **Version compatibility checking**
- **Installation verification**

### 📊 **Professional Deployment**
- **Reproducible installations**
- **Comprehensive logging**
- **Rollback capability via backups**

---

This smart installer represents the **professional deployment standard** - automatically adapting to different target environments while ensuring complete functionality.