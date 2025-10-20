#!/bin/bash
# RDX Deployment Package Manager
# Creates deployment packages for different scenarios

set -e

PACKAGE_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RDX_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 RDX Deployment Package Manager v${PACKAGE_VERSION}"

# Package types
create_standalone_package() {
    echo "📦 Creating standalone RDX package..."
    
    PACKAGE_DIR="/tmp/rdx-standalone-${PACKAGE_VERSION}"
    
    # Clean and create package directory
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    
    # Copy RDX source
    cp -r "$RDX_ROOT"/{src,include,config,CMakeLists.txt,README.md,CHANGELOG.md} "$PACKAGE_DIR/"
    
    # Copy installation script
    cp "$SCRIPT_DIR/install-rdx.sh" "$PACKAGE_DIR/"
    
    # Create package info
    cat > "$PACKAGE_DIR/PACKAGE_INFO.txt" <<EOF
RDX (Rivendell Extended) Standalone Package
Version: ${PACKAGE_VERSION}
Package Type: Standalone Installation
Build Date: $(date)

INSTALLATION:
1. Extract this package to any directory
2. Run: ./install-rdx.sh
3. Follow interactive prompts for broadcast tools
4. Reboot and enjoy intelligent audio routing!

REQUIREMENTS:
- Existing Rivendell installation
- JACK audio system
- Ubuntu 20.04+ or compatible Linux distribution

FEATURES:
✅ Intelligent JACK device discovery
✅ Auto-routing with critical connection protection  
✅ Smart hardware detection
✅ Profile-based service orchestration
✅ Real-time audio routing management

SUPPORT:
- GitHub: https://github.com/anjeleno/rdx-rivendell
- Documentation: See README.md and CHANGELOG.md
EOF

    # Create compressed package
    cd /tmp
    tar -czf "rdx-standalone-${PACKAGE_VERSION}.tar.gz" "rdx-standalone-${PACKAGE_VERSION}/"
    
    echo "✅ Standalone package created: /tmp/rdx-standalone-${PACKAGE_VERSION}.tar.gz"
}

create_installer_integration_package() {
    echo "📦 Creating Rivendell-Installer integration package..."
    
    PACKAGE_DIR="/tmp/rdx-installer-integration-${PACKAGE_VERSION}"
    
    # Clean and create package directory
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    
    # Copy RDX source
    cp -r "$RDX_ROOT"/{src,include,config,CMakeLists.txt} "$PACKAGE_DIR/"
    
    # Copy integration files
    cp "$RDX_ROOT/rivendell-installer/rdx-integration.sh" "$PACKAGE_DIR/"
    
    # Create integration instructions
    cat > "$PACKAGE_DIR/INTEGRATION_INSTRUCTIONS.md" <<EOF
# RDX Integration with rivendell-auto-install.sh

## Quick Integration

1. **Copy RDX source to installer:**
   \`\`\`bash
   cp -r rdx-installer-integration-${PACKAGE_VERSION}/* /path/to/rivendell-installer/
   \`\`\`

2. **Add RDX functions to rivendell-auto-install.sh:**
   
   Add the contents of \`rdx-integration.sh\` to your \`rivendell-auto-install.sh\` file.
   
   **Insert Location:** After the \`install_broadcasting_tools\` function

3. **Add RDX to installation sequence:**
   
   In the main installation flow (around line 665), add these lines after \`install_broadcasting_tools\`:
   
   \`\`\`bash
   # RDX (Rivendell Extended) Installation
   if ! step_completed "install_rdx"; then install_rdx; fi
   if ! step_completed "configure_rdx_broadcast_tools"; then configure_rdx_broadcast_tools; fi
   \`\`\`

4. **Test the integration:**
   
   Run your enhanced installer on a fresh system and verify RDX is installed automatically.

## What This Adds

- ✅ **Automated RDX installation** during Rivendell setup
- ✅ **Intelligent broadcast tools detection** and integration
- ✅ **Desktop shortcuts** and user aliases
- ✅ **Systemd service** configuration
- ✅ **Enhanced Liquidsoap** integration for existing radio.liq

## User Experience

After installation, users will have:
- \`rdx-help\` command for quick reference
- Desktop shortcut for RDX Audio Control
- Automatic RDX service startup with Rivendell
- Pre-configured intelligent routing profiles

## Customization

Edit \`rdx-profiles.xml\` to customize:
- Audio routing profiles
- Critical connection patterns  
- Service orchestration rules
- Auto-detection behaviors

EOF

    # Create compressed package
    cd /tmp
    tar -czf "rdx-installer-integration-${PACKAGE_VERSION}.tar.gz" "rdx-installer-integration-${PACKAGE_VERSION}/"
    
    echo "✅ Installer integration package created: /tmp/rdx-installer-integration-${PACKAGE_VERSION}.tar.gz"
}

create_development_package() {
    echo "📦 Creating RDX development package..."
    
    PACKAGE_DIR="/tmp/rdx-development-${PACKAGE_VERSION}"
    
    # Clean and create package directory  
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    
    # Copy complete RDX source tree
    cp -r "$RDX_ROOT"/* "$PACKAGE_DIR/"
    
    # Remove build artifacts
    rm -rf "$PACKAGE_DIR/build"
    
    # Create development info
    cat > "$PACKAGE_DIR/DEVELOPMENT.md" <<EOF
# RDX Development Package

## Development Setup

1. **Build Requirements:**
   \`\`\`bash
   sudo apt-get install build-essential cmake qtbase5-dev qttools5-dev 
   sudo apt-get install libjack-jackd2-dev libasound2-dev libdbus-1-dev
   \`\`\`

2. **Build RDX:**
   \`\`\`bash
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Debug -DJACK_SUPPORT=ON
   make -j\$(nproc)
   \`\`\`

3. **Install locally:**
   \`\`\`bash
   sudo make install
   \`\`\`

## Development Features

- **Full source code** with documentation
- **CMake build system** with debug support
- **Qt5 integration** for future GUI development
- **JACK audio system** integration with promiscuous mode
- **D-Bus service architecture** for system integration
- **Modular design** for easy feature extension

## Architecture

- \`src/rdx-jack/\` - Core intelligent routing engine
- \`include/\` - Header files and interfaces
- \`config/\` - XML profile configurations
- \`scripts/\` - Installation and deployment utilities
- \`rivendell-installer/\` - Integration with existing installers

## Contributing

1. Fork the repository
2. Create feature branch
3. Implement and test changes
4. Update documentation
5. Submit pull request

## Testing

- Test with VLC, system capture, and Stereo Tool
- Verify critical connection protection
- Test profile switching and service orchestration
- Validate JACK device detection across different hardware

EOF

    # Create compressed package
    cd /tmp
    tar -czf "rdx-development-${PACKAGE_VERSION}.tar.gz" "rdx-development-${PACKAGE_VERSION}/"
    
    echo "✅ Development package created: /tmp/rdx-development-${PACKAGE_VERSION}.tar.gz"
}

# Create VM deployment image
create_vm_deployment_image() {
    echo "📦 Creating VM deployment image..."
    
    PACKAGE_DIR="/tmp/rdx-vm-deployment-${PACKAGE_VERSION}"
    
    # Clean and create package directory
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"
    
    # Copy standalone installation
    cp -r "$RDX_ROOT"/{src,include,config,CMakeLists.txt,README.md,CHANGELOG.md} "$PACKAGE_DIR/"
    cp "$SCRIPT_DIR/install-rdx.sh" "$PACKAGE_DIR/"
    
    # Create VM-specific quick installer
    cat > "$PACKAGE_DIR/vm-quick-install.sh" <<EOF
#!/bin/bash
# RDX Quick VM Installation Script

echo "🔥 RDX VM Quick Installation"
echo "==========================="

# Auto-install with recommended broadcast tools
echo "🚀 Installing RDX with recommended broadcast tools..."
./install-rdx.sh --auto-install-broadcast

echo
echo "🎉 RDX VM Installation Complete!"
echo 
echo "🚀 Quick Test Commands:"
echo "   rdx-scan              # Discover JACK devices"
echo "   rdx-live             # Switch to live profile"
echo "   rdx-switch-vlc       # Route VLC as input"
echo "   rdx-sources          # List available sources"
echo
echo "📊 Monitor routing changes in QJackCtl Graph view"
echo "🔥 Your VM now has WICKED intelligent audio routing!"
EOF

    chmod +x "$PACKAGE_DIR/vm-quick-install.sh"
    
    # Create VM deployment instructions
    cat > "$PACKAGE_DIR/VM_DEPLOYMENT.md" <<EOF
# RDX VM Deployment Guide

## VM Requirements

- **OS:** Ubuntu 22.04 LTS or compatible
- **RAM:** 2GB minimum, 4GB recommended
- **CPU:** 2 cores minimum
- **Disk:** 20GB minimum
- **Audio:** JACK-compatible audio system

## Quick Deployment

1. **Copy to VM:**
   \`\`\`bash
   scp rdx-vm-deployment-${PACKAGE_VERSION}.tar.gz user@vm-ip:/tmp/
   \`\`\`

2. **Extract and install:**
   \`\`\`bash
   cd /tmp
   tar -xzf rdx-vm-deployment-${PACKAGE_VERSION}.tar.gz
   cd rdx-vm-deployment-${PACKAGE_VERSION}
   ./vm-quick-install.sh
   \`\`\`

3. **Test installation:**
   \`\`\`bash
   rdx-scan
   rdx-live
   \`\`\`

## VM-Specific Features

- **Auto-detection** of VM audio hardware
- **Optimized profiles** for virtual environments
- **Lightweight service** configuration
- **Remote monitoring** capabilities

## Network Configuration

RDX includes network-accessible features:
- Icecast streaming on port 8000
- HTTP status monitoring (if enabled)
- JACK network audio (optional)

Configure firewall rules as needed for your network setup.

## Testing Checklist

- [ ] JACK service starts correctly
- [ ] RDX discovers audio devices
- [ ] Profile switching works
- [ ] VLC routing functions
- [ ] Critical connections protected
- [ ] Service survives reboot

EOF

    # Create compressed package
    cd /tmp
    tar -czf "rdx-vm-deployment-${PACKAGE_VERSION}.tar.gz" "rdx-vm-deployment-${PACKAGE_VERSION}/"
    
    echo "✅ VM deployment package created: /tmp/rdx-vm-deployment-${PACKAGE_VERSION}.tar.gz"
}

# Main menu
show_menu() {
    echo
    echo "📦 RDX Deployment Package Options:"
    echo
    echo "1. Standalone Package        - For existing Rivendell systems"
    echo "2. Installer Integration     - For rivendell-auto-install.sh"  
    echo "3. Development Package       - Complete source for developers"
    echo "4. VM Deployment Image       - Optimized for virtual machines"
    echo "5. Create All Packages       - Generate all package types"
    echo "6. Exit"
    echo
    read -p "Select package type (1-6): " choice
    
    case $choice in
        1)
            create_standalone_package
            ;;
        2)
            create_installer_integration_package
            ;;
        3)
            create_development_package
            ;;
        4)
            create_vm_deployment_image
            ;;
        5)
            echo "🚀 Creating all RDX deployment packages..."
            create_standalone_package
            create_installer_integration_package  
            create_development_package
            create_vm_deployment_image
            echo
            echo "🎉 All packages created in /tmp/"
            ls -lh /tmp/rdx-*-${PACKAGE_VERSION}.tar.gz
            ;;
        6)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please select 1-6."
            show_menu
            ;;
    esac
}

# Check if we're in the right directory
if [ ! -f "$RDX_ROOT/src/rdx-jack/rdx_jack_manager.cpp" ]; then
    echo "❌ Please run this script from the RDX project directory"
    echo "   Expected to find: src/rdx-jack/rdx_jack_manager.cpp"
    exit 1
fi

# Run menu
show_menu

echo
echo "🎉 Package creation completed!"
echo "📁 All packages are available in /tmp/"