#!/bin/bash
# RDX Debian Package Builder
# Creates professional .deb packages for RDX installation

set -e

# Package information
PACKAGE_NAME="rdx-rivendell"
PACKAGE_VERSION="1.0.0"
ARCHITECTURE="amd64"
MAINTAINER="RDX Development Team <rdx@example.com>"
DESCRIPTION="Intelligent audio routing system for Rivendell broadcast automation"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RDX_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/tmp/rdx-deb-build"
PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"

echo "🔥 RDX Debian Package Builder v${PACKAGE_VERSION}"
echo "=================================================="

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
    mkdir -p "${PACKAGE_DIR}/usr/local/lib"
    mkdir -p "${PACKAGE_DIR}/usr/local/include/rdx"
    mkdir -p "${PACKAGE_DIR}/etc/rdx"
    mkdir -p "${PACKAGE_DIR}/etc/systemd/system"
    mkdir -p "${PACKAGE_DIR}/usr/share/applications"
    mkdir -p "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell"
    mkdir -p "${PACKAGE_DIR}/var/log/rdx"
}

# Build RDX from source
build_rdx() {
    echo "🔨 Building RDX from source..."
    
    cd "$RDX_ROOT"
    
    # Clean previous build
    rm -rf build
    mkdir build
    cd build
    
    # Configure for release
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr/local" \
        -DJACK_SUPPORT=ON
    
    # Build with all cores
    make -j$(nproc)
    
    echo "✅ RDX build completed successfully"
}

# Install files into package directory
install_files() {
    echo "📦 Installing files into package structure..."
    
    # Install binaries
    cp "${RDX_ROOT}/build/src/rdx-jack/rdx-jack-helper" "${PACKAGE_DIR}/usr/local/bin/"
    chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-jack-helper"
    
    # Install GUI library (if built)
    if [ -f "${RDX_ROOT}/build/src/rdx-gui/librdx-gui.a" ]; then
        cp "${RDX_ROOT}/build/src/rdx-gui/librdx-gui.a" "${PACKAGE_DIR}/usr/local/lib/"
    fi
    
    # Install headers
    cp -r "${RDX_ROOT}/src/rdx-gui/"*.h "${PACKAGE_DIR}/usr/local/include/rdx/" 2>/dev/null || true
    cp -r "${RDX_ROOT}/include/"* "${PACKAGE_DIR}/usr/local/include/rdx/" 2>/dev/null || true
    
    # Install configuration files
    cp "${RDX_ROOT}/config/rdx-profiles.xml" "${PACKAGE_DIR}/etc/rdx/"
    
    # Install systemd service
    cat > "${PACKAGE_DIR}/etc/systemd/system/rdx-jack-helper.service" <<EOF
[Unit]
Description=RDX JACK Helper Service - Intelligent Audio Routing
Documentation=https://github.com/anjeleno/rdx-rivendell
After=jackd.service rivendell.target
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
WantedBy=rivendell.target
EOF
    
    # Install desktop file
    cat > "${PACKAGE_DIR}/usr/share/applications/rdx-control.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RDX Audio Control
Comment=RDX Intelligent Audio Routing Control
Exec=/usr/local/bin/rdx-jack-helper --gui
Icon=audio-card
Terminal=false
Categories=AudioVideo;Audio;
Keywords=audio;jack;rivendell;broadcast;routing;
StartupNotify=true
EOF
    
    # Install documentation
    cp "${RDX_ROOT}/README.md" "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell/"
    cp "${RDX_ROOT}/CHANGELOG.md" "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell/"
    
    # Create log directory with proper permissions
    chown rd:rivendell "${PACKAGE_DIR}/var/log/rdx" 2>/dev/null || true
    
    echo "✅ Files installed successfully"
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
Depends: rivendell (>= 4.0.0), libc6 (>= 2.34), libqt5core5a (>= 5.15.0), libqt5dbus5 (>= 5.15.0), libjack-jackd2-0 | libjack0, jackd2, libasound2 (>= 1.2.0), libdbus-1-3, systemd
Recommends: vlc, vlc-plugin-jack, liquidsoap (>= 2.0.0), icecast2
Suggests: stereo-tool, glasscoder, darkice, butt
Conflicts: pulseaudio-module-jack
Description: ${DESCRIPTION}
 RDX (Rivendell Extended) provides broadcast-grade intelligent audio routing
 with critical connection protection. Automatically detects and manages JACK
 audio connections, processing chains, and streaming services.
 .
 Features:
  * Smart hardware detection (audio processors, streamers, inputs)
  * Automatic audio routing with conflict prevention
  * Critical connection protection for live broadcast safety
  * Profile-based service orchestration
  * Real-time monitoring and adaptation
  * Complete GUI integration with RDAdmin
 .
 This package provides the core RDX functionality. Additional broadcast
 tools can be installed via companion packages or manually.
EOF
    
    echo "✅ Control file created"
}

# Create post-installation script
create_postinst() {
    echo "📜 Creating post-installation script..."
    
    cat > "${PACKAGE_DIR}/DEBIAN/postinst" <<'EOF'
#!/bin/bash
# RDX post-installation script

set -e

case "$1" in
    configure)
        echo "🔥 Configuring RDX (Rivendell Extended)..."
        
        # Create RDX group if it doesn't exist
        if ! getent group rivendell > /dev/null 2>&1; then
            echo "⚠️  Warning: rivendell group not found. RDX requires Rivendell to be installed first."
        fi
        
        # Set proper permissions
        if [ -d "/etc/rdx" ]; then
            chown -R rd:rivendell /etc/rdx 2>/dev/null || true
            chmod -R 755 /etc/rdx
        fi
        
        if [ -d "/var/log/rdx" ]; then
            chown -R rd:rivendell /var/log/rdx 2>/dev/null || true
            chmod -R 755 /var/log/rdx
        fi
        
        # Reload systemd and enable service
        systemctl daemon-reload
        systemctl enable rdx-jack-helper 2>/dev/null || true
        
        # Add rd user aliases
        if [ -f "/home/rd/.bashrc" ]; then
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
alias rdx-help='echo "🔥 RDX Commands: rdx-scan, rdx-live, rdx-production, rdx-automation, rdx-switch-vlc, rdx-switch-system, rdx-sources, rdx-status"'
RDXEOF
                chown rd:rivendell /home/rd/.bashrc 2>/dev/null || true
            fi
        fi
        
        echo "✅ RDX configuration complete!"
        echo ""
        echo "🚀 Quick Start:"
        echo "   rdx-scan              # Discover JACK devices"  
        echo "   rdx-live              # Load live broadcast profile"
        echo "   rdx-switch-vlc        # Switch input to VLC"
        echo ""
        echo "🎛️ GUI Control:"
        echo "   Launch RDAdmin and look for '🔥 RDX Audio Control' button"
        echo ""
        echo "📡 Your Rivendell system now has WICKED intelligent audio routing!"
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
# RDX pre-removal script

set -e

case "$1" in
    remove|upgrade|deconfigure)
        echo "🔥 Stopping RDX services..."
        
        # Stop and disable service
        systemctl stop rdx-jack-helper 2>/dev/null || true
        systemctl disable rdx-jack-helper 2>/dev/null || true
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
    echo "📋 Package Information:"
    echo "======================="
    
    cd "$RDX_ROOT"
    
    echo "📦 File: ${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
    echo "📏 Size: $(ls -lh "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb" | awk '{print $5}')"
    echo ""
    echo "🔍 Package Contents:"
    dpkg-deb --contents "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb" | head -20
    echo ""
    echo "📋 Package Info:"
    dpkg-deb --info "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
    echo ""
    echo "🚀 Installation Instructions:"
    echo "   sudo dpkg -i ${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
    echo "   sudo apt-get install -f  # Fix any dependency issues"
    echo ""
    echo "🎉 Ready for deployment!"
}

# Main execution
main() {
    echo "🎯 Building RDX Debian package..."
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
    build_rdx
    install_files
    create_control_file
    create_postinst
    create_prerm
    build_deb_package
    show_package_info
    
    echo ""
    echo "🎉 RDX Debian package creation complete!"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi