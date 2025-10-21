# RDX Package Builder Comprehensive Guide

## 📦 Complete Guide to Building RDX Debian Packages

This guide covers all RDX package build scripts with copy/paste examples for every scenario.

---

## 🚀 Quick Start

### **Build Everything (Recommended)**
```bash
# Navigate to project root
cd /root/rdx-rivendell

# Build complete package with ALL features
chmod +x scripts/build-deb-enhanced.sh
./scripts/build-deb-enhanced.sh

# Result: rdx-rivendell-enhanced_2.1.0_amd64.deb with EVERYTHING
```

---

## 📋 Available Build Scripts

### 1. **`build-deb-enhanced.sh`** - ⭐ **THE COMPLETE BUILDER**
**Purpose**: Builds single .deb with ALL features
**Includes**: Core + AAC+ streaming + smart installer + optional GUI
**Best for**: Production deployments, complete installations

### 2. **`build-deb-core.sh`** - Minimal CLI
**Purpose**: Basic JACK routing, CLI-only
**Includes**: Core routing, systemd service
**Best for**: Server environments, minimal installs

### 3. **`build-deb-adaptive.sh`** - Smart Detection
**Purpose**: Adapts to available components
**Includes**: Varies based on what's detected
**Best for**: Unknown environments

### 4. **`build-deb-package.sh`** - Standard
**Purpose**: Standard package with GUI
**Includes**: Core + GUI (no streaming)
**Best for**: Desktop environments

### 5. **`build-all-packages.sh`** - Multi-Builder
**Purpose**: Builds multiple package variants
**Includes**: Creates several packages
**Best for**: Distribution, testing multiple variants

---

## 🎯 Enhanced Builder Usage (`build-deb-enhanced.sh`)

### **Default Build (Recommended)**
```bash
# Build with ALL features enabled
./scripts/build-deb-enhanced.sh

# Creates: rdx-rivendell-enhanced_2.1.0_amd64.deb
# Includes: Core + AAC+ streaming + smart installer
```

### **GUI Integration Build**
```bash
# Build with GUI support (requires Rivendell headers)
./scripts/build-deb-enhanced.sh --include-gui

# Creates package with graphical interface
```

### **Minimal Build**
```bash
# Build without AAC+ streaming
./scripts/build-deb-enhanced.sh --no-aac

# Build without smart installer
./scripts/build-deb-enhanced.sh --no-smart-install

# Build with both disabled
./scripts/build-deb-enhanced.sh --no-aac --no-smart-install
```

### **Custom Package Details**
```bash
# Custom package name and version
./scripts/build-deb-enhanced.sh \
    --package-name rdx-studio \
    --version 3.0.0

# Creates: rdx-studio_3.0.0_amd64.deb
```

### **Development Build**
```bash
# Debug build with symbols
./scripts/build-deb-enhanced.sh --debug

# Creates debug version for development
```

### **Complete Custom Build**
```bash
# Everything customized
./scripts/build-deb-enhanced.sh \
    --include-gui \
    --package-name rdx-pro \
    --version 2.1.0 \
    --debug

# Creates: rdx-pro_2.1.0_amd64.deb with GUI and debug symbols
```

---

## 🛠️ Core Builder Usage (`build-deb-core.sh`)

### **Basic Core Package**
```bash
# Build minimal CLI package
./scripts/build-deb-core.sh

# Creates: rdx-rivendell-core_1.0.0_amd64.deb
# Size: ~70KB, minimal dependencies
```

**Use cases:**
- Server environments without desktop
- Minimal Docker containers
- CI/CD automated testing
- Resource-constrained systems

---

## 🧠 Adaptive Builder Usage (`build-deb-adaptive.sh`)

### **Smart Detection Build**
```bash
# Automatically detects available components
./scripts/build-deb-adaptive.sh

# Detects and builds based on:
# - Rivendell headers presence
# - Rivendell installation
# - Available Qt5 components
```

**Adaptive Behavior:**
- **Full Package**: If Rivendell + headers detected
- **GUI Package**: If Qt5 but no Rivendell
- **Core Package**: If minimal environment

---

## 📦 Multi-Package Builder (`build-all-packages.sh`)

### **Build All Variants**
```bash
# Creates multiple package versions
./scripts/build-all-packages.sh

# Creates:
# - rdx-rivendell-core_1.0.0_amd64.deb
# - rdx-rivendell-gui_1.0.0_amd64.deb  
# - rdx-rivendell-adaptive_1.0.0_amd64.deb
```

---

## 🎯 Feature Comparison Table

| Feature | Enhanced | Core | Standard | Adaptive | Multi |
|---------|----------|------|----------|----------|-------|
| JACK Routing | ✅ | ✅ | ✅ | ✅ | ✅ |
| AAC+ Streaming | ✅ | ❌ | ❌ | ❌ | Varies |
| Smart Installer | ✅ | ❌ | ❌ | ❌ | ❌ |
| GUI Support | Optional | ❌ | ✅ | Auto | Varies |
| Custom Options | ✅ | ❌ | ❌ | ❌ | ❌ |
| Size | Large | Small | Medium | Varies | Multiple |

---

## 🔧 Installation Examples

### **Install Enhanced Package**
```bash
# Install the complete package
sudo dpkg -i rdx-rivendell-enhanced_2.1.0_amd64.deb

# Fix any dependency issues
sudo apt-get install -f

# Verify installation
rdx-jack-helper --scan
rdx-stream start hq
rdx-deps check
```

### **Install Core Package**
```bash
# Install minimal package
sudo dpkg -i rdx-rivendell-core_1.0.0_amd64.deb

# Start service
sudo systemctl enable rdx-jack-helper
sudo systemctl start rdx-jack-helper

# Test functionality
rdx-jack-helper --profile live-broadcast
```

---

## 🚨 Troubleshooting Builds

### **Common Build Issues**

#### Missing Dependencies
```bash
# Install build dependencies first
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    qtbase5-dev \
    libjack-jackd2-dev \
    libasound2-dev \
    libdbus-1-dev \
    dpkg-dev
```

#### Permission Issues
```bash
# Make scripts executable
chmod +x scripts/build-deb-*.sh

# Run from project root
cd /root/rdx-rivendell
./scripts/build-deb-enhanced.sh
```

#### Build Failures
```bash
# Clean previous builds
rm -rf build-*
rm -rf /tmp/rdx-*

# Rebuild from scratch
./scripts/build-deb-enhanced.sh --debug
```

### **Debugging Build Process**

#### Verbose Output
```bash
# Enable debug output
export RDX_DEBUG=1
./scripts/build-deb-enhanced.sh --debug
```

#### Check Build Logs
```bash
# View build logs
tail -f /tmp/rdx-enhanced-deb-build/build.log

# Check package contents before building
ls -la /tmp/rdx-enhanced-deb-build/rdx-rivendell-enhanced_*/
```

---

## 📁 Output Locations

### **Package Files**
```bash
# Enhanced package
/root/rdx-rivendell/rdx-rivendell-enhanced_2.1.0_amd64.deb

# Core package  
/root/rdx-rivendell/rdx-rivendell-core_1.0.0_amd64.deb

# Standard package
/root/rdx-rivendell/rdx-rivendell_1.0.0_amd64.deb
```

### **Build Directories**
```bash
# Enhanced build
/tmp/rdx-enhanced-deb-build/

# Core build
/tmp/rdx-core-deb-build/

# Source builds
/root/rdx-rivendell/build-enhanced/
/root/rdx-rivendell/build-core/
```

---

## 🎛️ Advanced Usage Scenarios

### **Production Broadcast Station**
```bash
# Build complete production package
./scripts/build-deb-enhanced.sh \
    --include-gui \
    --package-name rdx-broadcast-pro \
    --version 2.1.0

# Install on broadcast workstation
sudo dpkg -i rdx-broadcast-pro_2.1.0_amd64.deb
```

### **Automation Server**
```bash
# Build minimal server package
./scripts/build-deb-core.sh

# Install on headless server
scp rdx-rivendell-core_1.0.0_amd64.deb server:/tmp/
ssh server "sudo dpkg -i /tmp/rdx-rivendell-core_1.0.0_amd64.deb"
```

### **Development Environment**
```bash
# Build debug version for development
./scripts/build-deb-enhanced.sh \
    --debug \
    --package-name rdx-dev \
    --version dev-$(date +%Y%m%d)

# Creates timestamped dev package
```

### **Distribution Package**
```bash
# Build all variants for distribution
./scripts/build-all-packages.sh

# Creates complete package set
ls -la *.deb
```

---

## 🔍 Package Verification

### **Check Package Contents**
```bash
# List files in package
dpkg-deb --contents rdx-rivendell-enhanced_2.1.0_amd64.deb

# Show package info
dpkg-deb --info rdx-rivendell-enhanced_2.1.0_amd64.deb

# Check dependencies
dpkg-deb --field rdx-rivendell-enhanced_2.1.0_amd64.deb Depends
```

### **Test Package Installation**
```bash
# Test install without actually installing
sudo dpkg --dry-run -i rdx-rivendell-enhanced_2.1.0_amd64.deb

# Check for dependency conflicts
sudo dpkg -i rdx-rivendell-enhanced_2.1.0_amd64.deb 2>&1 | grep -i "conflict\|error"
```

---

## 🎯 Quick Reference

### **Most Common Commands**
```bash
# 🥇 RECOMMENDED: Build everything
./scripts/build-deb-enhanced.sh

# 🏆 With GUI support
./scripts/build-deb-enhanced.sh --include-gui

# 💻 Minimal for servers
./scripts/build-deb-core.sh

# 🔧 Help for any script
./scripts/build-deb-enhanced.sh --help
```

### **Installation Commands**
```bash
# Install package
sudo dpkg -i *.deb && sudo apt-get install -f

# Start services
sudo systemctl enable rdx-jack-helper
sudo systemctl start rdx-jack-helper

# Test installation
rdx-jack-helper --scan
rdx-stream start medium
rdx-deps check
```

---

## 📞 Support Commands

### **Get Help**
```bash
# Enhanced builder help
./scripts/build-deb-enhanced.sh --help

# Check what's available
ls -la scripts/build-*.sh

# Verify dependencies
rdx-deps check  # (after installation)
```

### **System Information**
```bash
# Check system compatibility
lsb_release -a
dpkg --print-architecture

# Check JACK availability
jack_control status || jackd --version

# Check Qt5 availability
pkg-config --modversion Qt5Core Qt5Widgets
```

---

This guide covers every scenario for building RDX packages. The **Enhanced Builder** (`build-deb-enhanced.sh`) is recommended for most users as it creates a complete package with all features.