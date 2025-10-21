# RDX Build Scripts Directory

This directory contains all scripts for building RDX Debian packages.

## 📦 Script Overview

### **🥇 Enhanced Builder** - `build-deb-enhanced.sh`
**The complete, feature-rich package builder**
- **Includes**: Core + AAC+ streaming + smart installer + optional GUI
- **Best for**: Production deployments, complete installations
- **Output**: `rdx-rivendell-enhanced_2.1.0_amd64.deb`

```bash
# Build everything (recommended)
./build-deb-enhanced.sh

# With GUI support
./build-deb-enhanced.sh --include-gui

# Custom configuration
./build-deb-enhanced.sh --package-name my-rdx --version 3.0.0
```

### **⚡ Core Builder** - `build-deb-core.sh`
**Minimal CLI-only package**
- **Includes**: Basic JACK routing, systemd service
- **Best for**: Server environments, minimal installations
- **Output**: `rdx-rivendell-core_1.0.0_amd64.deb`

```bash
# Build minimal package
./build-deb-core.sh
```

### **🧠 Adaptive Builder** - `build-deb-adaptive.sh`
**Smart environment detection**
- **Includes**: Adapts based on available components
- **Best for**: Unknown environments, automatic builds
- **Output**: Varies based on detection

```bash
# Auto-detect and build appropriate package
./build-deb-adaptive.sh
```

### **🖥️ Standard Builder** - `build-deb-package.sh`
**Standard package with GUI**
- **Includes**: Core + GUI components
- **Best for**: Desktop environments
- **Output**: `rdx-rivendell_1.0.0_amd64.deb`

```bash
# Build standard package
./build-deb-package.sh
```

### **📦 Multi-Builder** - `build-all-packages.sh`
**Builds multiple package variants**
- **Includes**: Creates several different packages
- **Best for**: Distribution, testing multiple variants
- **Output**: Multiple .deb files

```bash
# Build all variants
./build-all-packages.sh
```

## 🚀 Quick Start

### **Most Users (Recommended)**
```bash
# Build complete package with all features
./build-deb-enhanced.sh
```

### **Server Environments**
```bash
# Build minimal CLI package
./build-deb-core.sh
```

### **Unknown Environment**
```bash
# Let script decide what to build
./build-deb-adaptive.sh
```

## 🎯 Feature Matrix

| Feature | Enhanced | Core | Adaptive | Standard | Multi |
|---------|----------|------|----------|----------|-------|
| **JACK Routing** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **AAC+ Streaming** | ✅ | ❌ | ❌ | ❌ | Varies |
| **Smart Installer** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **GUI Support** | Optional | ❌ | Auto | ✅ | Varies |
| **Custom Options** | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Rivendell Integration** | ✅ | ✅ | Auto | ✅ | ✅ |
| **Size** | Large | Small | Varies | Medium | Multiple |
| **Dependencies** | Many | Few | Auto | Medium | Varies |

## 📋 Available Command Options

### Enhanced Builder Options
```bash
--no-aac                # Exclude AAC+ streaming
--no-smart-install      # Exclude smart installer  
--include-gui           # Include GUI components
--debug                 # Debug build with symbols
--package-name NAME     # Custom package name
--version VERSION       # Custom version
--help                  # Show help
```

### Usage Examples
```bash
# Minimal enhanced package
./build-deb-enhanced.sh --no-aac --no-smart-install

# GUI-enabled package
./build-deb-enhanced.sh --include-gui

# Custom professional package
./build-deb-enhanced.sh --include-gui --package-name rdx-pro --version 2.1.0

# Development package
./build-deb-enhanced.sh --debug --package-name rdx-dev
```

## 🛠️ Prerequisites

### **Build Dependencies**
```bash
sudo apt-get install -y \
    build-essential \
    cmake \
    qtbase5-dev \
    libjack-jackd2-dev \
    libasound2-dev \
    libdbus-1-dev \
    dpkg-dev
```

### **Runtime Dependencies (Enhanced)**
```bash
# Core
libc6, libqt5core5a, libjack-jackd2-0, jackd2, systemd

# AAC+ Streaming  
ffmpeg, libavcodec58, libavformat58

# GUI (optional)
libqt5widgets5, libqt5gui5
```

## 📁 Output Locations

### **Package Files**
```bash
/root/rdx-rivendell/rdx-rivendell-enhanced_2.1.0_amd64.deb
/root/rdx-rivendell/rdx-rivendell-core_1.0.0_amd64.deb
/root/rdx-rivendell/rdx-rivendell_1.0.0_amd64.deb
```

### **Build Directories**
```bash
/tmp/rdx-enhanced-deb-build/     # Enhanced builds
/tmp/rdx-core-deb-build/         # Core builds
/root/rdx-rivendell/build-*/     # Source builds
```

## 🔧 Troubleshooting

### **Common Issues**

#### Permission Denied
```bash
chmod +x build-deb-*.sh
```

#### Missing Dependencies
```bash
sudo apt-get update
sudo apt-get install build-essential cmake qtbase5-dev libjack-jackd2-dev dpkg-dev
```

#### Build Failures
```bash
# Clean previous builds
rm -rf /root/rdx-rivendell/build-*
rm -rf /tmp/rdx-*

# Retry build
./build-deb-enhanced.sh --debug
```

#### Package Issues
```bash
# Check package contents
dpkg-deb --contents package.deb

# Verify package info
dpkg-deb --info package.deb

# Test installation
sudo dpkg --dry-run -i package.deb
```

## 📊 Performance Characteristics

### **Build Times** (approximate)
- **Enhanced**: 3-5 minutes (full features)
- **Core**: 1-2 minutes (minimal)
- **Adaptive**: 1-5 minutes (varies)
- **Standard**: 2-3 minutes (GUI)
- **Multi**: 5-10 minutes (all variants)

### **Package Sizes** (approximate)
- **Enhanced**: 200-300KB (with dependencies)
- **Core**: 70-100KB (minimal)
- **Standard**: 150-200KB (with GUI)

## 🎯 Recommendations

### **For Production Broadcast Stations**
```bash
./build-deb-enhanced.sh --include-gui --package-name rdx-broadcast
```

### **For Automation Servers**
```bash
./build-deb-core.sh
```

### **For Development/Testing**
```bash
./build-deb-enhanced.sh --debug --package-name rdx-dev
```

### **For Distribution**
```bash
./build-all-packages.sh
```

## 📞 Getting Help

### **Script Help**
```bash
./build-deb-enhanced.sh --help
```

### **Check Available Scripts**
```bash
ls -la build-*.sh
```

### **Documentation**
- `../docs/PACKAGE-BUILDER-GUIDE.md` - Comprehensive guide
- `../docs/QUICK-BUILD-REFERENCE.md` - Quick reference
- Individual script `--help` options

---

**Recommended**: Start with `./build-deb-enhanced.sh` for most use cases.