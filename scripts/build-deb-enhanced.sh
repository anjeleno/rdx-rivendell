#!/bin/bash
# RDX Enhanced Debian Package Builder
# Creates .deb package with AAC+ streaming and smart dependency management

set -e

# Package information
PACKAGE_NAME="rdx-rivendell-enhanced"
PACKAGE_VERSION="2.0.0"
ARCHITECTURE="amd64"
MAINTAINER="RDX Development Team <rdx@example.com>"
DESCRIPTION="RDX intelligent JACK audio routing with AAC+ streaming and smart dependencies"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RDX_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/tmp/rdx-enhanced-deb-build"
PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"

# Command line options
INCLUDE_AAC=true
INCLUDE_SMART_INSTALL=true
INCLUDE_GUI=false
BUILD_TYPE="Release"

# Auto-detect Rivendell installation and enable GUI automatically
detect_rivendell_and_configure() {
    echo "� Auto-detecting system configuration..."
    
    # Check for Rivendell installation
    if [ -f "/etc/rd.conf" ] && [ -f "/usr/bin/rdadmin" ]; then
        echo "✅ Rivendell installation detected - enabling GUI components"
        INCLUDE_GUI=true
        
        # Check for database connectivity
        if [ -f "/etc/rd.conf" ]; then
            local db_host=$(grep "^Hostname=" /etc/rd.conf | cut -d'=' -f2)
            local db_user=$(grep "^Loginname=" /etc/rd.conf | cut -d'=' -f2)
            local db_pass=$(grep "^Password=" /etc/rd.conf | cut -d'=' -f2)
            local db_name=$(grep "^Database=" /etc/rd.conf | cut -d'=' -f2)
            
            if mysql -h "$db_host" -u "$db_user" -p"$db_pass" -D "$db_name" -e "SELECT 1;" >/dev/null 2>&1; then
                echo "✅ Rivendell database connectivity verified"
            else
                echo "⚠️  Rivendell database not accessible - GUI will be basic"
            fi
        fi
    else
        echo "ℹ️  No Rivendell installation detected - GUI components disabled"
        INCLUDE_GUI=false
    fi
    
    # Check for Qt5 development packages
    if dpkg -l | grep -q "qtbase5-dev\|libqt5widgets5"; then
        echo "✅ Qt5 development packages available"
    else
        echo "⚠️  Qt5 development packages not found - GUI may be limited"
    fi
    
    # Check for JACK
    if command -v jackd >/dev/null 2>&1 || dpkg -l | grep -q "jackd2"; then
        echo "✅ JACK Audio Connection Kit detected"
    else
        echo "⚠️  JACK not detected - will include in dependencies"
    fi
    
    echo "🎯 Build configuration determined:"
    echo "   AAC+ Streaming: $INCLUDE_AAC"
    echo "   Smart Installer: $INCLUDE_SMART_INSTALL" 
    echo "   GUI Components: $INCLUDE_GUI"
    echo "   Build Type: $BUILD_TYPE"
}

echo "�🔥 RDX Enhanced Debian Package Builder v${PACKAGE_VERSION}"
echo "=========================================================="

# Run auto-detection first
detect_rivendell_and_configure

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-aac)
                INCLUDE_AAC=false
                echo "📡 AAC+ streaming disabled"
                shift
                ;;
            --no-smart-install)
                INCLUDE_SMART_INSTALL=false
                echo "🧠 Smart installer disabled"
                shift
                ;;
            --include-gui)
                INCLUDE_GUI=true
                echo "🖥️  GUI components force-enabled"
                shift
                ;;
            --no-gui)
                INCLUDE_GUI=false
                echo "🖥️  GUI components force-disabled"
                shift
                ;;
            --debug)
                BUILD_TYPE="Debug"
                echo "🐛 Debug build enabled"
                shift
                ;;
            --package-name)
                PACKAGE_NAME="$2"
                echo "📦 Custom package name: $PACKAGE_NAME"
                shift 2
                ;;
            --version)
                PACKAGE_VERSION="$2"
                echo "🔢 Custom version: $PACKAGE_VERSION"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "❌ Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Update paths with new package name
    PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"
}

# Show help information
show_help() {
    cat << EOF
🔥 RDX Enhanced Debian Package Builder

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --no-aac                Exclude AAC+ streaming functionality
    --no-smart-install      Exclude smart dependency installer
    --include-gui           Force include GUI components (overrides auto-detection)
    --no-gui                Force exclude GUI components (overrides auto-detection)
    --debug                 Build with debug symbols
    --package-name NAME     Custom package name (default: rdx-rivendell-enhanced)
    --version VERSION       Custom version (default: 2.0.0)
    --help                  Show this help message

EXAMPLES:
    # Build with auto-detection (recommended)
    $0

    # Build minimal package without AAC+ streaming
    $0 --no-aac

    # Force GUI components even if Rivendell not detected
    $0 --include-gui --package-name rdx-studio --version 2.1.0

    # Build without GUI components even on Rivendell system
    $0 --no-gui

    # Build debug version for development
    $0 --debug --package-name rdx-dev

FEATURES:
    🔍 Auto-detection of Rivendell installation and GUI capability
    ✅ Core JACK audio routing with intelligent management
    ✅ AAC+ streaming (HE-AAC v1/v2, LC-AAC) with FFmpeg
    ✅ Smart dependency detection and auto-installation
    ✅ Professional systemd service integration
    ✅ Comprehensive CLI tools and aliases
    ✅ Rivendell broadcast automation integration
    ✅ Real-time monitoring and connection protection

EOF
}

# Clean and create build directory
cleanup_build() {
    echo "🧹 Cleaning previous build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# Create package directory structure
create_package_structure() {
    echo "📁 Creating enhanced Debian package structure..."
    
    mkdir -p "${PACKAGE_DIR}/DEBIAN"
    mkdir -p "${PACKAGE_DIR}/usr/local/bin"
    mkdir -p "${PACKAGE_DIR}/usr/local/share/rdx"
    mkdir -p "${PACKAGE_DIR}/etc/rdx"
    mkdir -p "${PACKAGE_DIR}/etc/systemd/system"
    mkdir -p "${PACKAGE_DIR}/usr/share/applications"
    mkdir -p "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-enhanced"
    mkdir -p "${PACKAGE_DIR}/var/log/rdx"
    
    if [ "$INCLUDE_AAC" = true ]; then
        mkdir -p "${PACKAGE_DIR}/etc/rdx/aac-profiles"
        mkdir -p "${PACKAGE_DIR}/var/lib/rdx/streams"
    fi
}

# Build RDX components
build_rdx_components() {
    echo "🔨 Building RDX enhanced components..."
    
    cd "$RDX_ROOT"
    
    # Clean previous build
    rm -rf build-enhanced
    mkdir build-enhanced
    cd build-enhanced
    
    # Configure build
    local cmake_options="-DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DCMAKE_INSTALL_PREFIX=/usr/local -DJACK_SUPPORT=ON"
    
    if [ "$INCLUDE_GUI" = true ]; then
        cmake_options="$cmake_options -DGUI_SUPPORT=ON"
    fi
    
    cmake .. $cmake_options
    
    # Build components
    make rdx-jack-helper -j$(nproc)
    
    if [ "$INCLUDE_GUI" = true ]; then
        echo "🖥️  Building GUI components..."
        make rdx-gui -j$(nproc) || echo "⚠️  GUI build failed - continuing with CLI only"
    fi
    
    echo "✅ RDX enhanced build completed successfully"
}

# Install core files
install_core_files() {
    echo "📦 Installing enhanced files into package structure..."
    
    # Install main binary
    cp "${RDX_ROOT}/build-enhanced/src/rdx-jack/rdx-jack-helper" "${PACKAGE_DIR}/usr/local/bin/"
    chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-jack-helper"
    
    # Install GUI if built
    if [ "$INCLUDE_GUI" = true ] && [ -f "${RDX_ROOT}/build-enhanced/src/rdx-gui/rdx-gui" ]; then
        cp "${RDX_ROOT}/build-enhanced/src/rdx-gui/rdx-gui" "${PACKAGE_DIR}/usr/local/bin/"
        chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-gui"
        echo "✅ GUI components installed"
    fi
    
    # Install configuration files
    cp "${RDX_ROOT}/config/rdx-profiles.xml" "${PACKAGE_DIR}/etc/rdx/"
    
    # Install systemd service
    cat > "${PACKAGE_DIR}/etc/systemd/system/rdx-jack-helper.service" <<EOF
[Unit]
Description=RDX JACK Helper Service - Enhanced Audio Routing with AAC+ Streaming
Documentation=https://github.com/anjeleno/rdx-rivendell
After=jackd.service
Wants=jackd.service

[Service]
Type=simple
User=rd
Group=rivendell
ExecStart=/usr/local/bin/rdx-jack-helper --daemon
Restart=always
RestartSec=5
Environment=JACK_PROMISCUOUS_SERVER=audio
Environment=RDX_LOG_LEVEL=info
Environment=RDX_AAC_ENABLED=true
WorkingDirectory=/home/rd

[Install]
WantedBy=multi-user.target
EOF

    echo "✅ Core files installed successfully"
}

# Install AAC+ streaming components
install_aac_components() {
    if [ "$INCLUDE_AAC" = false ]; then
        echo "⏭️  Skipping AAC+ components (disabled)"
        return
    fi
    
    echo "📡 Installing AAC+ streaming components..."
    
    # Install AAC streaming script
    cp "${RDX_ROOT}/src/rdx-jack/rdx-aac-stream.sh" "${PACKAGE_DIR}/usr/local/bin/"
    chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-aac-stream.sh"
    
    # Create AAC streaming helper script
    cat > "${PACKAGE_DIR}/usr/local/bin/rdx-stream" <<'EOF'
#!/bin/bash
# RDX AAC+ Streaming Helper
# Simplified interface for rdx-aac-stream.sh

SCRIPT_DIR="/usr/local/bin"
AAC_SCRIPT="$SCRIPT_DIR/rdx-aac-stream.sh"

show_help() {
    echo "🎵 RDX AAC+ Streaming Helper"
    echo ""
    echo "USAGE:"
    echo "    rdx-stream [COMMAND] [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "    start [profile]     Start streaming with profile (hq, medium, low)"
    echo "    stop               Stop streaming"
    echo "    status             Show streaming status"
    echo "    profiles           List available profiles"
    echo "    test              Test stream connection"
    echo ""
    echo "EXAMPLES:"
    echo "    rdx-stream start hq              # Start high-quality stream"
    echo "    rdx-stream start medium          # Start medium-quality stream"
    echo "    rdx-stream stop                  # Stop streaming"
    echo "    rdx-stream status                # Check status"
    echo ""
    echo "For advanced options, use: rdx-aac-stream.sh --help"
}

case "$1" in
    start)
        profile="${2:-medium}"
        echo "🎵 Starting AAC+ stream with $profile profile..."
        "$AAC_SCRIPT" --profile "$profile" --daemon
        ;;
    stop)
        echo "🛑 Stopping AAC+ stream..."
        "$AAC_SCRIPT" --stop
        ;;
    status)
        "$AAC_SCRIPT" --status
        ;;
    profiles)
        echo "🎵 Available AAC+ Profiles:"
        echo "  hq     - High Quality (HE-AAC v2, 128kbps)"
        echo "  medium - Medium Quality (HE-AAC v1, 96kbps)"
        echo "  low    - Low Quality (LC-AAC, 64kbps)"
        ;;
    test)
        echo "🧪 Testing stream connection..."
        "$AAC_SCRIPT" --test
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
EOF
    chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-stream"
    
    # Install AAC profile configurations
    cat > "${PACKAGE_DIR}/etc/rdx/aac-profiles/hq.conf" <<EOF
# High Quality AAC+ Profile
codec=aac_he_v2
bitrate=128k
quality=vbr_3
reconnect=true
daemon=true
EOF

    cat > "${PACKAGE_DIR}/etc/rdx/aac-profiles/medium.conf" <<EOF
# Medium Quality AAC+ Profile  
codec=aac_he
bitrate=96k
quality=vbr_4
reconnect=true
daemon=true
EOF

    cat > "${PACKAGE_DIR}/etc/rdx/aac-profiles/low.conf" <<EOF
# Low Quality AAC Profile
codec=aac_low
bitrate=64k
quality=cbr
reconnect=true
daemon=true
EOF
    
    echo "✅ AAC+ streaming components installed"
}

# Install smart dependency management
install_smart_components() {
    if [ "$INCLUDE_SMART_INSTALL" = false ]; then
        echo "⏭️  Skipping smart installer (disabled)"
        return
    fi
    
    echo "🧠 Installing smart dependency management..."
    
    # Install smart installer
    cp "${RDX_ROOT}/smart-install.sh" "${PACKAGE_DIR}/usr/local/share/rdx/"
    chmod +x "${PACKAGE_DIR}/usr/local/share/rdx/smart-install.sh"
    
    # Create dependency management wrapper
    cat > "${PACKAGE_DIR}/usr/local/bin/rdx-deps" <<'EOF'
#!/bin/bash
# RDX Dependency Management Helper

SMART_INSTALLER="/usr/local/share/rdx/smart-install.sh"

show_help() {
    echo "🧠 RDX Smart Dependency Manager"
    echo ""
    echo "USAGE:"
    echo "    rdx-deps [COMMAND] [OPTIONS]"
    echo ""
    echo "COMMANDS:"
    echo "    check              Check system dependencies"
    echo "    scan               Scan for missing dependencies"
    echo "    install            Install missing dependencies"
    echo "    install --auto-yes Install dependencies non-interactively"
    echo "    list               List all dependencies"
    echo "    rivendell          Check Rivendell installation"
    echo "    audio              Check audio system"
    echo "    streaming          Check streaming tools"
    echo ""
    echo "EXAMPLES:"
    echo "    rdx-deps check                   # Check all dependencies"
    echo "    rdx-deps scan                    # Scan for missing packages"
    echo "    rdx-deps install                 # Install missing packages"
    echo "    rdx-deps install --auto-yes      # Auto-install without prompts"
    echo "    rdx-deps rivendell               # Check Rivendell status"
}

case "$1" in
    check)
        echo "🔍 Checking RDX dependencies..."
        "$SMART_INSTALLER" --check-only
        ;;
    scan)
        echo "🔍 Scanning for missing dependencies..."
        "$SMART_INSTALLER" --scan-only
        ;;
    install)
        if [ "$2" = "--auto-yes" ]; then
            echo "📦 Installing missing dependencies automatically..."
            DEBIAN_FRONTEND=noninteractive "$SMART_INSTALLER" --install-deps-only --auto-yes
        else
            echo "📦 Installing missing dependencies..."
            "$SMART_INSTALLER" --install-deps-only
        fi
        ;;
    list)
        echo "📋 RDX Dependencies:"
        "$SMART_INSTALLER" --list-deps
        ;;
    rivendell)
        echo "🎛️  Checking Rivendell installation..."
        "$SMART_INSTALLER" --check-rivendell
        ;;
    audio)
        echo "🔊 Checking audio system..."
        "$SMART_INSTALLER" --check-audio
        ;;
    streaming)
        echo "📡 Checking streaming tools..."
        "$SMART_INSTALLER" --check-streaming
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
EOF
    chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-deps"
    
    echo "✅ Smart dependency management installed"
}

# Install complete installation script
install_complete_installer() {
    echo "🎯 Installing complete RDX installation script..."
    
    # Install the complete installation script
    if [ -f "${RDX_ROOT}/scripts/rdx-install-complete.sh" ]; then
        cp "${RDX_ROOT}/scripts/rdx-install-complete.sh" "${PACKAGE_DIR}/usr/local/share/rdx/"
        chmod +x "${PACKAGE_DIR}/usr/local/share/rdx/rdx-install-complete.sh"
        
        # Create convenient symlink
        ln -sf "/usr/local/share/rdx/rdx-install-complete.sh" "${PACKAGE_DIR}/usr/local/bin/rdx-install"
        
        echo "✅ Complete installation script installed as 'rdx-install'"
    else
        echo "⚠️  Complete installation script not found - skipping"
    fi
}

# Create desktop entries
create_desktop_entries() {
    echo "🖥️  Creating desktop entries..."
    
    # Main CLI interface
    # Create GUI launcher script if GUI is available
    if [ "$INCLUDE_GUI" = true ]; then
        cat > "${PACKAGE_DIR}/usr/local/bin/rdx-gui-launcher" <<'EOF'
#!/bin/bash
# RDX GUI Launcher - Detects and launches appropriate interface

# Check if GUI is available
if [ -n "$DISPLAY" ] && command -v rdx-jack-helper >/dev/null 2>&1; then
    # Try to launch GUI version
    if rdx-jack-helper --version >/dev/null 2>&1; then
        # Launch with GUI if Qt is available
        exec rdx-jack-helper "$@"
    fi
fi

# Fallback to terminal interface
exec x-terminal-emulator -e bash -c "rdx-jack-helper --help; echo; echo 'Press Enter to close...'; read"
EOF
        chmod +x "${PACKAGE_DIR}/usr/local/bin/rdx-gui-launcher"
    fi

    cat > "${PACKAGE_DIR}/usr/share/applications/rdx-control.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RDX Audio Control
Comment=RDX Enhanced Audio Routing Control
Exec=/usr/local/bin/rdx-gui-launcher
Icon=audio-card
Terminal=false
Categories=AudioVideo;Audio;
Keywords=audio;jack;rivendell;broadcast;routing;aac;streaming;
StartupNotify=true
EOF

    # AAC Streaming interface (if enabled)
    if [ "$INCLUDE_AAC" = true ]; then
        cat > "${PACKAGE_DIR}/usr/share/applications/rdx-streaming.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RDX Streaming Control
Comment=RDX AAC+ Streaming Control
Exec=x-terminal-emulator -e bash -c "echo 'RDX Streaming Control'; echo '====================='; rdx-stream --help; echo; echo 'Quick Start:'; echo '  rdx-stream start hq    # Start high quality stream'; echo '  rdx-stream stop        # Stop streaming'; echo '  rdx-stream status      # Check status'; echo; echo 'Press Enter to close...'; read"
Icon=applications-multimedia
Terminal=true
Categories=AudioVideo;Audio;
Keywords=audio;streaming;aac;broadcast;icecast;
StartupNotify=true
EOF
    fi
    
    # GUI interface (if enabled and built)
    if [ "$INCLUDE_GUI" = true ] && [ -f "${PACKAGE_DIR}/usr/local/bin/rdx-gui" ]; then
        cat > "${PACKAGE_DIR}/usr/share/applications/rdx-gui.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RDX GUI Control
Comment=RDX Enhanced Audio Routing GUI
Exec=/usr/local/bin/rdx-gui
Icon=audio-card
Terminal=false
Categories=AudioVideo;Audio;
Keywords=audio;jack;rivendell;broadcast;routing;gui;
StartupNotify=true
EOF
    fi
    
    echo "✅ Desktop entries created"
}

# Create enhanced control file
create_control_file() {
    echo "📋 Creating enhanced Debian control file..."
    
    # Build dependencies list - Core dependencies only (move optional to Recommends)
    local base_deps="libc6 (>= 2.34), libqt5core5a (>= 5.12.0), libqt5dbus5 (>= 5.12.0), libjack-jackd2-0 | libjack0, libasound2 (>= 1.0.0), libdbus-1-3"
    local aac_deps=""
    local gui_deps=""
    local recommends="rivendell (>= 4.0.0), jackd2, qjackctl"
    
    if [ "$INCLUDE_AAC" = true ]; then
        # Move FFmpeg to recommends for flexibility - not everyone needs streaming
        recommends="$recommends, ffmpeg (>= 4.0.0), libavcodec60 | libavcodec58, libavformat60 | libavformat58, libavutil58 | libavutil56"
    fi
    
    if [ "$INCLUDE_GUI" = true ]; then
        gui_deps=", libqt5widgets5 (>= 5.12.0), libqt5gui5 (>= 5.12.0)"
    fi
    
    local all_deps="${base_deps}${aac_deps}${gui_deps}"
    
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
Depends: ${all_deps}
Recommends: ${recommends}, vlc, vlc-plugin-jack, liquidsoap (>= 2.0.0), icecast2, stereo-tool
Suggests: glasscoder, darkice, butt, obs-studio
Conflicts: pulseaudio-module-jack
Provides: rdx-audio-routing, rdx-aac-streaming
Description: ${DESCRIPTION}
 RDX (Rivendell Extended) enhanced provides intelligent JACK audio routing
 with AAC+ streaming and smart dependency management. Professional broadcast
 automation integration with modern streaming capabilities.
 .
 Enhanced Features:
  * Smart JACK device discovery and connection management
  * Intelligent auto-routing (VLC, system capture, processing chains)
  * Critical connection protection for broadcast safety
  * Profile-based audio routing (live-broadcast, production, automation)
  * Real-time monitoring and service orchestration
 .
 This enhanced package provides complete broadcast automation capabilities
 with modern streaming support. Works standalone or integrates seamlessly
 with Rivendell broadcast systems.
 .
 Quick Start:
  rdx-jack-helper --scan              # Discover audio devices
  rdx-jack-helper --profile live      # Load broadcast profile
  rdx-stream start hq                 # Start AAC+ streaming
  rdx-deps check                      # Check dependencies
EOF
    
    echo "✅ Enhanced control file created"
}

# Create enhanced post-installation script
create_postinst() {
    echo "📜 Creating enhanced post-installation script..."
    
    cat > "${PACKAGE_DIR}/DEBIAN/postinst" <<'EOF'
#!/bin/bash
# RDX Enhanced post-installation script

# Don't use set -e - we want to handle errors gracefully
# set -e

case "$1" in
    configure)
        echo "🔥 Configuring RDX Enhanced (Intelligent Audio + AAC+ Streaming)..."
        
        # Create RDX directories
        mkdir -p /etc/rdx /var/log/rdx /var/lib/rdx/streams
        
        # Set permissions if rivendell group exists
        if getent group rivendell > /dev/null 2>&1; then
            echo "✅ Found rivendell group - setting RDX permissions for Rivendell integration"
            chown -R rd:rivendell /etc/rdx /var/log/rdx /var/lib/rdx 2>/dev/null || true
        else
            echo "ℹ️  Rivendell not detected - RDX will work in standalone mode"
            # Set permissions for current user
            chown -R $SUDO_USER:$SUDO_USER /etc/rdx /var/log/rdx /var/lib/rdx 2>/dev/null || true
        fi
        
        chmod -R 755 /etc/rdx /var/log/rdx /var/lib/rdx
        
        # Reload systemd and enable service
        systemctl daemon-reload
        
        # Only enable service if rivendell group exists (integrated mode)
        if getent group rivendell > /dev/null 2>&1; then
            systemctl enable rdx-jack-helper 2>/dev/null || true
            echo "✅ RDX enhanced service enabled - will start with system"
        else
            echo "ℹ️  RDX service available but not auto-enabled (standalone mode)"
            echo "   Run: systemctl enable rdx-jack-helper"  
        fi
        
        # Add enhanced aliases for rd user
        if [ -d "/home/rd" ] && [ -f "/home/rd/.bashrc" ]; then
            if ! grep -q "RDX Enhanced Aliases" /home/rd/.bashrc; then
                cat >> /home/rd/.bashrc << 'RDXEOF'

# RDX Enhanced Aliases
alias rdx-scan='rdx-jack-helper --scan'
alias rdx-live='rdx-jack-helper --profile live-broadcast'  
alias rdx-production='rdx-jack-helper --profile production'
alias rdx-automation='rdx-jack-helper --profile automation'
alias rdx-switch-vlc='rdx-jack-helper --switch-input vlc'
alias rdx-switch-system='rdx-jack-helper --switch-input system'
alias rdx-sources='rdx-jack-helper --list-sources'
alias rdx-status='systemctl status rdx-jack-helper'
alias rdx-stream-start='rdx-stream start medium'
alias rdx-stream-stop='rdx-stream stop'
alias rdx-stream-status='rdx-stream status'
alias rdx-deps-check='rdx-deps check'
alias rdx-help='echo "🔥 RDX Enhanced Commands: rdx-scan, rdx-live, rdx-stream-start, rdx-deps-check | rdx-jack-helper --help for full options"'
RDXEOF
                chown rd:rivendell /home/rd/.bashrc 2>/dev/null || true
                echo "✅ RDX enhanced aliases added to rd user"
            fi
        fi
        
        # Run smart dependency check and auto-install
        if [ -x "/usr/local/bin/rdx-deps" ]; then
            echo "🧠 Running automated dependency installation..."
            echo "   This may take a few minutes to install missing packages..."
            
            # First check what's missing
            /usr/local/bin/rdx-deps check
            
            # Check if we're running during package installation (avoid deadlock)
            # Check for any dpkg/apt processes running
            if ps aux | grep -E "(dpkg|apt-get|apt|gdebi)" | grep -v grep >/dev/null 2>&1; then
                echo "📦 Package installation detected - skipping automatic dependency installation"
                echo "   Dependencies will be installed after package installation completes"
                echo ""
                echo "🔧 To install missing dependencies manually, run:"
                echo "   sudo rdx-deps install"
                echo "   OR: sudo apt-get install pkg-config qtbase5-dev-tools"
            elif /usr/local/bin/rdx-deps scan | grep -q "missing"; then
                echo "📦 Installing missing dependencies automatically..."
                echo "   Installing: JACK audio, FFmpeg, multimedia libraries..."
                
                # Update package lists first
                apt-get update -qq 2>/dev/null || true
                
                # Run the smart installer non-interactively (don't fail package install if this fails)
                if DEBIAN_FRONTEND=noninteractive /usr/local/bin/rdx-deps install --auto-yes 2>/dev/null; then
                    echo "✅ Dependencies installed automatically"
                else
                    echo "⚠️  Automatic dependency installation had issues"
                    echo "   You can install missing dependencies manually with:"
                    echo "   sudo rdx-deps install"
                    echo ""
                    echo "   Or install specific packages:"
                    echo "   sudo apt-get install jackd2 ffmpeg cmake pkg-config"
                fi
            else
                echo "✅ All dependencies already satisfied"
            fi
        fi
        
        echo ""
        echo "🎉 RDX Enhanced installation complete!"
        echo ""
        echo "🚀 Quick Start Commands:"
        echo "   rdx-jack-helper --scan              # Discover JACK devices"
        echo "   rdx-jack-helper --profile live      # Load live broadcast profile"  
        echo "   rdx-stream start hq                 # Start AAC+ streaming"
        echo "   rdx-deps check                      # Check dependencies"
        echo "   rdx-jack-helper --help              # Full command reference"
        echo ""
        echo "🎛️ Service Management:"
        echo "   systemctl start rdx-jack-helper     # Start intelligent routing"
        echo "   systemctl status rdx-jack-helper    # Check service status"
        echo ""
        echo "📡 Streaming Commands:"
        echo "   rdx-stream start [hq|medium|low]    # Start AAC+ streaming"
        echo "   rdx-stream stop                     # Stop streaming"
        echo "   rdx-stream status                   # Check stream status"
        echo ""
        echo "🧠 Dependency Management:"
        echo "   rdx-deps check                      # Check all dependencies"
        echo "   rdx-deps install                    # Install missing packages"
        echo ""
        echo "🎯 Complete Integration:"
        echo "   rdx-install                         # Run complete RDAdmin integration"
        echo "   rdx-install --verify                # Verify installation"
        echo ""
        echo "📡 Your system now has WICKED intelligent audio + AAC+ streaming!"
        echo "💡 For full RDAdmin integration, run: sudo rdx-install"
        ;;
esac

exit 0
EOF
    
    chmod +x "${PACKAGE_DIR}/DEBIAN/postinst"
    echo "✅ Enhanced post-installation script created"
}

# Create pre-removal script  
create_prerm() {
    echo "📜 Creating pre-removal script..."
    
    cat > "${PACKAGE_DIR}/DEBIAN/prerm" <<'EOF'
#!/bin/bash
# RDX Enhanced pre-removal script

set -e

case "$1" in
    remove|upgrade|deconfigure)
        echo "🔥 Stopping RDX enhanced services..."
        
        # Stop streaming
        if [ -x "/usr/local/bin/rdx-stream" ]; then
            /usr/local/bin/rdx-stream stop 2>/dev/null || true
        fi
        
        # Stop and disable service
        systemctl stop rdx-jack-helper 2>/dev/null || true
        systemctl disable rdx-jack-helper 2>/dev/null || true
        
        echo "✅ RDX enhanced services stopped"
        ;;
esac

exit 0
EOF
    
    chmod +x "${PACKAGE_DIR}/DEBIAN/prerm"
    echo "✅ Pre-removal script created"
}

# Install documentation
install_documentation() {
    echo "📚 Installing comprehensive documentation..."
    
    # Copy main documentation
    cp "${RDX_ROOT}/README.md" "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-enhanced/"
    cp "${RDX_ROOT}/CHANGELOG.md" "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-enhanced/"
    
    # Create feature-specific docs
    if [ "$INCLUDE_AAC" = true ]; then
        cat > "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-enhanced/AAC-STREAMING.md" <<'EOF'
# RDX AAC+ Streaming Guide

## Quick Start
```bash
# Start high-quality streaming
rdx-stream start hq

# Check streaming status
rdx-stream status

# Stop streaming
rdx-stream stop
```

## Available Profiles
- **hq**: High Quality (HE-AAC v2, 128kbps)
- **medium**: Medium Quality (HE-AAC v1, 96kbps)  
- **low**: Low Quality (LC-AAC, 64kbps)

## Advanced Usage
```bash
# Direct script access with custom options
rdx-aac-stream.sh --server icecast.example.com --port 8000 --profile hq --daemon

# Test stream without connecting
rdx-aac-stream.sh --test --profile medium
```

## Configuration
Edit `/etc/rdx/aac-profiles/*.conf` to customize streaming settings.
EOF
    fi
    
    if [ "$INCLUDE_SMART_INSTALL" = true ]; then
        cat > "${PACKAGE_DIR}/usr/share/doc/rdx-rivendell-enhanced/DEPENDENCIES.md" <<'EOF'
# RDX Smart Dependency Management

## Quick Start
```bash
# Check all dependencies
rdx-deps check

# Install missing packages
rdx-deps install

# Check specific components
rdx-deps rivendell
rdx-deps audio
rdx-deps streaming
```

## Manual Dependency Check
```bash
# Full smart installer access
/usr/local/share/rdx/smart-install.sh --check-only
/usr/local/share/rdx/smart-install.sh --install-deps-only
```

## Required Dependencies
- **Core**: JACK, Qt5, systemd
- **Audio**: ALSA, PulseAudio compatibility
- **Streaming**: FFmpeg, audio codecs
- **Optional**: Rivendell, VLC, Liquidsoap
EOF
    fi
    
    echo "✅ Comprehensive documentation installed"
}

# Build the .deb package
build_deb_package() {
    echo "🔧 Building enhanced Debian package..."
    
    cd "$BUILD_DIR"
    
    # Build the package
    dpkg-deb --build "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"
    
    # Create deb-builds directory if it doesn't exist
    mkdir -p "$RDX_ROOT/deb-builds"
    
    # Move to final location
    mv "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb" "$RDX_ROOT/deb-builds/"
    
    echo "✅ Enhanced Debian package built successfully!"
    echo "📦 Package: ${RDX_ROOT}/deb-builds/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
}

# Show package information
show_package_info() {
    echo ""
    echo "📋 RDX Enhanced Package Information:"
    echo "===================================="
    
    cd "$RDX_ROOT"
    
    local deb_file="${RDX_ROOT}/deb-builds/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
    
    echo "📦 File: $deb_file"
    echo "📏 Size: $(ls -lh "$deb_file" | awk '{print $5}')"
    echo ""
    echo "🎯 Features Included:"
    echo "   ✅ Intelligent JACK audio routing"
    [ "$INCLUDE_AAC" = true ] && echo "   ✅ AAC+ streaming (HE-AAC v1/v2, LC-AAC)"
    [ "$INCLUDE_SMART_INSTALL" = true ] && echo "   ✅ Smart dependency management"
    [ "$INCLUDE_GUI" = true ] && echo "   ✅ GUI interface"
    echo "   ✅ Professional systemd integration"
    echo "   ✅ Comprehensive CLI tools"
    echo ""
    echo "🔍 Package Contents:"
    dpkg-deb --contents "$deb_file" | head -20
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
    [ "$INCLUDE_AAC" = true ] && echo "   rdx-stream start hq"
    [ "$INCLUDE_SMART_INSTALL" = true ] && echo "   rdx-deps check"
    echo "   rdx-jack-helper --help"
    echo ""
    echo "🎉 Ready for deployment!"
}

# Main execution
main() {
    echo "🎯 Building RDX Enhanced Debian package..."
    echo ""
    
    # Parse command line arguments
    parse_args "$@"
    
    echo "🔧 Build Configuration:"
    echo "   Package: $PACKAGE_NAME v$PACKAGE_VERSION"
    echo "   AAC+ Streaming: $INCLUDE_AAC"
    echo "   Smart Installer: $INCLUDE_SMART_INSTALL"
    echo "   GUI Components: $INCLUDE_GUI"
    echo "   Build Type: $BUILD_TYPE"
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
    
    if [ "$INCLUDE_AAC" = true ] && [ ! -f "$RDX_ROOT/src/rdx-jack/rdx-aac-stream.sh" ]; then
        echo "❌ AAC streaming script not found. Please ensure rdx-aac-stream.sh exists."
        exit 1
    fi
    
    if [ "$INCLUDE_SMART_INSTALL" = true ] && [ ! -f "$RDX_ROOT/smart-install.sh" ]; then
        echo "❌ Smart installer not found. Please ensure smart-install.sh exists."
        exit 1
    fi
    
    # Build process
    cleanup_build
    create_package_structure
    build_rdx_components
    install_core_files
    install_aac_components
    install_smart_components
    install_complete_installer
    create_desktop_entries
    install_documentation
    create_control_file
    create_postinst
    create_prerm
    build_deb_package
    show_package_info
    
    echo ""
    echo "🎉 RDX Enhanced Debian package creation complete!"
    echo "   This package provides intelligent routing + AAC+ streaming + smart dependencies"
    echo "   Professional broadcast automation with modern streaming capabilities"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi