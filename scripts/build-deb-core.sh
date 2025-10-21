#!/bin/bash
# RDX Core Debian Package Builder  
# Creates .deb package with working rdx-jack-helper (core functionality)

set -e

# Package information
PACKAGE_NAME="rdx-rivendell-core"
PACKAGE_VERSION="1.0.0"
ARCHITECTURE="amd64"
MAINTAINER="RDX Development Team <rdx@example.com>"
DESCRIPTION="RDX intelligent JACK audio routing system (core components)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RDX_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/tmp/rdx-core-deb-build"
PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"

echo "🔥 RDX Core Debian Package Builder v${PACKAGE_VERSION}"
echo "======================================================"

# Clean and create build directory
cleanup_build() {
    echo "🧹 Cleaning previous build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# Create package directory structure
create_package_structure() {
    echo "📁 Creating Debian package structure..."
    
    mkdir -p "${PACKAGE_DIR}/DEBIAN"
    mkdir -p "${PACKAGE_DIR}/usr/local/bin"
    mkdir -p "${PACKAGE_DIR}/etc/rdx"
    mkdir -p "${PACKAGE_DIR}/etc/systemd/system"
    mkdir -p "${PACKAGE_DIR}/usr/share/applications"
    mkdir -p "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-core"
    mkdir -p "${PACKAGE_DIR}/var/log/rdx"
}

# Build only the core components
build_rdx_core() {
    echo "🔨 Building RDX core components..."
    
    cd "$RDX_ROOT"
    
    # Clean previous build
    rm -rf build-core
    mkdir build-core
    cd build-core
    
    # Configure to build only rdx-jack components
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr/local" \
        -DJACK_SUPPORT=ON
    
    # Build only rdx-jack-helper (skip GUI that needs Rivendell headers)
    make rdx-jack-helper -j$(nproc)
    
    echo "✅ RDX core build completed successfully"
}

# Install files into package directory
install_core_files() {
    echo "📦 Installing core files into package structure..."
    
    # Install main binary
    cp "${RDX_ROOT}/build-core/src/rdx-jack/rdx-jack-helper" "${PACKAGE_DIR}/usr/local/bin/"
    chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-jack-helper"
    
    # Install configuration files
    cp "${RDX_ROOT}/config/rdx-profiles.xml" "${PACKAGE_DIR}/etc/rdx/"
    
    # Install systemd service
    cat > "${PACKAGE_DIR}/etc/systemd/system/rdx-jack-helper.service" <<EOF
[Unit]
Description=RDX JACK Helper Service - Intelligent Audio Routing
Documentation=https://github.com/anjeleno/rdx-rivendell
After=jackd.service
Wants=jackd.service

[Service]
Type=simple
User=rd
Group=rivendell
ExecStart=/usr/local/bin/rdx-jack-helper
Restart=always
RestartSec=5
Environment=JACK_PROMISCUOUS_SERVER=audio
WorkingDirectory=/home/rd

[Install]
WantedBy=multi-user.target
EOF
    
    # Install desktop file (launches CLI interface)
    cat > "${PACKAGE_DIR}/usr/share/applications/rdx-control.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RDX Audio Control
Comment=RDX Intelligent Audio Routing Control (Command Line)
Exec=x-terminal-emulator -e /usr/local/bin/rdx-jack-helper --interactive
Icon=audio-card
Terminal=true
Categories=AudioVideo;Audio;
Keywords=audio;jack;rivendell;broadcast;routing;
StartupNotify=true
EOF
    
    # Install documentation
    cp "${RDX_ROOT}/README.md" "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-core/"
    cp "${RDX_ROOT}/CHANGELOG.md" "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-core/"
    
    echo "✅ Core files installed successfully"
}

# Create Debian control file
create_control_file() {
    echo "📋 Creating Debian control file..."
    
    cat > "${PACKAGE_DIR}/DEBIAN/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${PACKAGE_VERSION}
Section: sound
Priority: optional
Architecture: ${ARCHITECTURE}
Essential: no
Installed-Size: $(du -sk "${PACKAGE_DIR}" | cut -f1)
Maintainer: ${MAINTAINER}
Homepage: https://github.com/anjeleno/rdx-rivendell
Depends: libc6 (>= 2.34), libqt5core5a (>= 5.15.0), libqt5dbus5 (>= 5.15.0), libjack-jackd2-0 | libjack0, jackd2, libasound2 (>= 1.2.0), libdbus-1-3, systemd
Recommends: rivendell (>= 4.0.0), vlc, vlc-plugin-jack, liquidsoap (>= 2.0.0), icecast2
Suggests: stereo-tool, glasscoder, darkice, butt
Conflicts: pulseaudio-module-jack
Provides: rdx-audio-routing
Description: ${DESCRIPTION}
 RDX (Rivendell Extended) core provides intelligent JACK audio routing
 with critical connection protection. This package contains the core
 rdx-jack-helper service that provides intelligent audio management.
 .
 Core Features:
  * Smart JACK device discovery and connection management
  * Intelligent auto-routing (VLC, system capture, processing chains)
  * Critical connection protection for broadcast safety
  * Profile-based audio routing (live-broadcast, production, automation)
  * Real-time monitoring and service orchestration
  * Command-line interface with full feature access
 .
 This is the core package that provides CLI functionality. Works standalone
 or with Rivendell broadcast automation systems. GUI integration available
 separately when Rivendell is installed.
 .
 Quick Start:
  rdx-jack-helper --scan              # Discover audio devices
  rdx-jack-helper --profile live      # Load broadcast profile
  rdx-jack-helper --switch-input vlc  # Route VLC to outputs
EOF
    
    echo "✅ Control file created"
}

# Create post-installation script
create_postinst() {
    echo "📜 Creating post-installation script..."
    
    cat > "${PACKAGE_DIR}/DEBIAN/postinst" <<'EOF'
#!/bin/bash
# RDX Core post-installation script

set -e

case "$1" in
    configure)
        echo "🔥 Configuring RDX Core (Intelligent Audio Routing)..."
        
        # Create RDX directories
        mkdir -p /etc/rdx /var/log/rdx
        
        # Set permissions if rivendell group exists
        if getent group rivendell > /dev/null 2>&1; then
            echo "✅ Found rivendell group - setting RDX permissions for Rivendell integration"
            chown -R rd:rivendell /etc/rdx /var/log/rdx 2>/dev/null || true
        else
            echo "ℹ️  Rivendell not detected - RDX will work in standalone mode"
            # Set permissions for current user
            chown -R $SUDO_USER:$SUDO_USER /etc/rdx /var/log/rdx 2>/dev/null || true
        fi
        
        chmod -R 755 /etc/rdx /var/log/rdx
        
        # Reload systemd and enable service
        systemctl daemon-reload
        
        # Only enable service if rivendell group exists (integrated mode)
        if getent group rivendell > /dev/null 2>&1; then
            systemctl enable rdx-jack-helper 2>/dev/null || true
            echo "✅ RDX service enabled - will start with system"
        else
            echo "ℹ️  RDX service available but not auto-enabled (standalone mode)"
            echo "   Run: systemctl enable rdx-jack-helper"  
        fi
        
        # Add convenient aliases for rd user
        if [ -d "/home/rd" ] && [ -f "/home/rd/.bashrc" ]; then
            if ! grep -q "RDX (Rivendell Extended) Aliases" /home/rd/.bashrc; then
                cat >> /home/rd/.bashrc << 'RDXEOF'

# RDX (Rivendell Extended) Aliases
alias rdx-scan='rdx-jack-helper --scan'
alias rdx-live='rdx-jack-helper --profile live-broadcast'  
alias rdx-production='rdx-jack-helper --profile production'
alias rdx-automation='rdx-jack-helper --profile automation'
alias rdx-switch-vlc='rdx-jack-helper --switch-input vlc'
alias rdx-switch-system='rdx-jack-helper --switch-input system'
alias rdx-sources='rdx-jack-helper --list-sources'
alias rdx-status='systemctl status rdx-jack-helper'
alias rdx-help='echo "🔥 RDX Commands: rdx-scan, rdx-live, rdx-production, rdx-automation, rdx-switch-vlc, rdx-switch-system, rdx-sources, rdx-status | rdx-jack-helper --help for full options"'
RDXEOF
                chown rd:rivendell /home/rd/.bashrc 2>/dev/null || true
                echo "✅ RDX aliases added to rd user"
            fi
        fi
        
        echo ""
        echo "🎉 RDX Core installation complete!"
        echo ""
        echo "🚀 Quick Start Commands:"
        echo "   rdx-jack-helper --scan              # Discover JACK devices"
        echo "   rdx-jack-helper --profile live      # Load live broadcast profile"  
        echo "   rdx-jack-helper --switch-input vlc  # Route VLC to Rivendell"
        echo "   rdx-jack-helper --list-sources      # Show available input sources"
        echo "   rdx-jack-helper --help              # Full command reference"
        echo ""
        echo "🎛️ Service Management:"
        echo "   systemctl start rdx-jack-helper     # Start intelligent routing"
        echo "   systemctl status rdx-jack-helper    # Check service status"
        echo ""
        echo "📡 Your system now has WICKED intelligent audio routing!"
        ;;
esac

exit 0
EOF
    
    chmod +x "${PACKAGE_DIR}/DEBIAN/postinst"
    echo "✅ Post-installation script created"
}

# Create pre-removal script  
create_prerm() {
    echo "📜 Creating pre-removal script..."
    
    cat > "${PACKAGE_DIR}/DEBIAN/prerm" <<'EOF'
#!/bin/bash
# RDX Core pre-removal script

set -e

case "$1" in
    remove|upgrade|deconfigure)
        echo "🔥 Stopping RDX services..."
        
        # Stop and disable service
        systemctl stop rdx-jack-helper 2>/dev/null || true
        systemctl disable rdx-jack-helper 2>/dev/null || true
        
        echo "✅ RDX services stopped"
        ;;
esac

exit 0
EOF
    
    chmod +x "${PACKAGE_DIR}/DEBIAN/prerm"
    echo "✅ Pre-removal script created"
}

# Build the .deb package
build_deb_package() {
    echo "🔧 Building Debian package..."
    
    cd "$BUILD_DIR"
    
    # Build the package
    dpkg-deb --build "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"
    
    # Move to final location
    mv "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb" "$RDX_ROOT/"
    
    echo "✅ Debian package built successfully!"
    echo "📦 Package: ${RDX_ROOT}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
}

# Show package information
show_package_info() {
    echo ""
    echo "📋 RDX Core Package Information:"
    echo "==============================="
    
    cd "$RDX_ROOT"
    
    local deb_file="${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
    
    echo "📦 File: $deb_file"
    echo "📏 Size: $(ls -lh "$deb_file" | awk '{print $5}')"
    echo ""
    echo "🔍 Package Contents:"
    dpkg-deb --contents "$deb_file" | head -15
    echo ""
    echo "📋 Package Info:"
    dpkg-deb --info "$deb_file"
    echo ""
    echo "🚀 Installation Instructions:"
    echo "   sudo dpkg -i $deb_file"
    echo "   sudo apt-get install -f  # Fix any dependency issues"
    echo ""
    echo "🎯 Testing Commands:"
    echo "   rdx-jack-helper --scan"
    echo "   rdx-jack-helper --profile live-broadcast"
    echo "   rdx-jack-helper --help"
    echo ""
    echo "🎉 Ready for deployment!"
}

# Main execution
main() {
    echo "🎯 Building RDX Core Debian package (CLI components only)..."
    echo ""
    
    # Check dependencies
    if ! command -v dpkg-deb &> /dev/null; then
        echo "❌ dpkg-deb not found. Please install: sudo apt-get install dpkg-dev"
        exit 1
    fi
    
    if [ ! -f "$RDX_ROOT/CMakeLists.txt" ]; then
        echo "❌ Please run this script from the RDX project directory"
        exit 1
    fi
    
    # Build process
    cleanup_build
    create_package_structure
    build_rdx_core
    install_core_files
    create_control_file
    create_postinst
    create_prerm
    build_deb_package
    show_package_info
    
    echo ""
    echo "🎉 RDX Core Debian package creation complete!"
    echo "   This package provides CLI intelligent routing functionality"
    echo "   GUI integration available when Rivendell headers are present"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi