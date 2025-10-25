#!/bin/bash
# RDX Installation Script for External Rivendell Systems
# Usage: ./install-rdx.sh [--build-only] [--install-only]

set -e

RDX_VERSION="1.0.0"
INSTALL_PREFIX="/usr/local"
RD_USER="rd"
RD_GROUP="rivendell"

echo "🔥 RDX (Rivendell Extended) Installation Script v${RDX_VERSION}"
echo "   Intelligent Audio Routing System"

# Check for Rivendell installation
check_rivendell() {
    echo "🔍 Checking Rivendell installation..."
    
    if ! command -v rdadmin &> /dev/null; then
        echo "❌ Rivendell not found! Please install Rivendell first."
        echo "   Visit: https://github.com/ElvishArtisan/rivendell"
        exit 1
    fi
    
    RD_VERSION=$(rdadmin --version 2>&1 | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    echo "✅ Found Rivendell version: $RD_VERSION"
    
    # Check for required users/groups
    if ! id "$RD_USER" &>/dev/null; then
        echo "❌ User '$RD_USER' not found. Rivendell may not be properly installed."
        exit 1
    fi
    
    echo "✅ Rivendell user '$RD_USER' found"
}

# Detect available broadcast tools
detect_broadcast_tools() {
    echo "🔍 Detecting broadcast tools..."
    
    declare -A TOOLS_STATUS
    
    # Audio processors
    if command -v stereo_tool_gui_jack_64 &> /dev/null; then
        TOOLS_STATUS["stereo_tool"]="installed"
    else
        TOOLS_STATUS["stereo_tool"]="missing"
    fi
    
    # Streaming software
    if command -v liquidsoap &> /dev/null; then
        TOOLS_STATUS["liquidsoap"]="installed"
        LIQUIDSOAP_VERSION=$(liquidsoap --version 2>&1 | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    else
        TOOLS_STATUS["liquidsoap"]="missing"
    fi
    
    if command -v icecast2 &> /dev/null; then
        TOOLS_STATUS["icecast2"]="installed"
    else
        TOOLS_STATUS["icecast2"]="missing"
    fi
    
    if command -v darkice &> /dev/null; then
        TOOLS_STATUS["darkice"]="installed"
    else
        TOOLS_STATUS["darkice"]="missing"
    fi
    
    if command -v glasscoder &> /dev/null; then
        TOOLS_STATUS["glasscoder"]="installed"
    else
        TOOLS_STATUS["glasscoder"]="missing"
    fi
    
    # Media players
    if command -v vlc &> /dev/null; then
        TOOLS_STATUS["vlc"]="installed"
    else
        TOOLS_STATUS["vlc"]="missing"
    fi
    
    if command -v audacity &> /dev/null; then
        TOOLS_STATUS["audacity"]="installed"
    else
        TOOLS_STATUS["audacity"]="missing"
    fi
    
    # JACK tools
    if command -v qjackctl &> /dev/null; then
        TOOLS_STATUS["qjackctl"]="installed"
    else
        TOOLS_STATUS["qjackctl"]="missing"
    fi
    
    if command -v jack_connect &> /dev/null; then
        TOOLS_STATUS["jack_tools"]="installed"
    else
        TOOLS_STATUS["jack_tools"]="missing"
    fi
    
    # Report findings
    echo "📊 Broadcast Tools Detection Results:"
    echo
    
    for tool in "${!TOOLS_STATUS[@]}"; do
        status="${TOOLS_STATUS[$tool]}"
        if [ "$status" = "installed" ]; then
            echo "   ✅ $tool - Installed"
        else
            echo "   ❌ $tool - Missing"
        fi
    done
    
    echo
    
    # Store results globally for use by other functions
    declare -gA DETECTED_TOOLS
    for tool in "${!TOOLS_STATUS[@]}"; do
        DETECTED_TOOLS["$tool"]="${TOOLS_STATUS[$tool]}"
    done
}

# Interactive broadcast tools installation
install_broadcast_tools() {
    echo "🎙️ RDX Broadcast Tools Installation"
    echo "   Choose which tools to install for your broadcast setup:"
    echo
    
    # Initialize selection array
    declare -A INSTALL_TOOLS
    
    # Audio processors
    echo "🎚️  AUDIO PROCESSORS:"
    if [ "${DETECTED_TOOLS["stereo_tool"]}" = "missing" ]; then
        read -p "   📡 Install Stereo Tool (Professional Audio Processor)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_TOOLS["stereo_tool"]="yes"
        fi
    else
        echo "   ✅ Stereo Tool - Already installed"
    fi
    
    # Streaming software
    echo
    echo "📡 STREAMING SOFTWARE:"
    
    if [ "${DETECTED_TOOLS["liquidsoap"]}" = "missing" ]; then
        read -p "   🌊 Install Liquidsoap (Advanced Audio Streaming)? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            INSTALL_TOOLS["liquidsoap"]="yes"
        fi
    else
        echo "   ✅ Liquidsoap $LIQUIDSOAP_VERSION - Already installed"
    fi
    
    if [ "${DETECTED_TOOLS["icecast2"]}" = "missing" ]; then
        read -p "   🧊 Install Icecast2 (Streaming Server)? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            INSTALL_TOOLS["icecast2"]="yes"
        fi
    else
        echo "   ✅ Icecast2 - Already installed"
    fi
    
    # Alternative encoders
    echo
    echo "🎵 STREAMING ENCODERS (Choose One or More):"
    
    if [ "${DETECTED_TOOLS["darkice"]}" = "missing" ]; then
        read -p "   🌙 Install DarkIce (Simple JACK → Icecast)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_TOOLS["darkice"]="yes"
        fi
    else
        echo "   ✅ DarkIce - Already installed"
    fi
    
    if [ "${DETECTED_TOOLS["glasscoder"]}" = "missing" ]; then
        read -p "   🔮 Install GlassCoder (Advanced Multi-format Encoder)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_TOOLS["glasscoder"]="yes"
        fi
    else
        echo "   ✅ GlassCoder - Already installed"
    fi
    
    # Media players and tools
    echo
    echo "🎬 MEDIA PLAYERS & TOOLS:"
    
    if [ "${DETECTED_TOOLS["vlc"]}" = "missing" ]; then
        read -p "   🎥 Install VLC Media Player (Essential for RDX)? [Y/n]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            INSTALL_TOOLS["vlc"]="yes"
        fi
    else
        echo "   ✅ VLC - Already installed"
    fi
    
    if [ "${DETECTED_TOOLS["audacity"]}" = "missing" ]; then
        read -p "   🎧 Install Audacity (Audio Editor)? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            INSTALL_TOOLS["audacity"]="yes"
        fi
    else
        echo "   ✅ Audacity - Already installed"
    fi
    
    if [ "${DETECTED_TOOLS["qjackctl"]}" = "missing" ]; then
        # QJackCtl installed as dependency for JACK tools, but RDX provides the interface
        INSTALL_TOOLS["qjackctl"]="auto"
    else
        echo "   ✅ JACK Tools - Available (managed by RDX)"
    fi
    
    # Now install selected tools
    echo
    echo "📦 Installing selected broadcast tools..."
    
    for tool in "${!INSTALL_TOOLS[@]}"; do
        if [ "${INSTALL_TOOLS[$tool]}" = "yes" ] || [ "${INSTALL_TOOLS[$tool]}" = "auto" ]; then
            install_single_tool "$tool"
        fi
    done
    
    echo "✅ Broadcast tools installation complete!"
}

# Install individual tools
install_single_tool() {
    local tool="$1"
    
    echo "📦 Installing $tool..."
    
    case "$tool" in
        "stereo_tool")
            install_stereo_tool
            ;;
        "liquidsoap")
            install_liquidsoap
            ;;
        "icecast2")
            install_icecast2
            ;;
        "darkice")
            install_darkice
            ;;
        "glasscoder")
            install_glasscoder
            ;;
        "vlc")
            install_vlc
            ;;
        "audacity")
            install_audacity
            ;;
        "qjackctl")
            install_qjackctl_dependency
            ;;
        *)
            echo "⚠️  Unknown tool: $tool"
            ;;
    esac
}

# Individual tool installers
install_stereo_tool() {
    echo "📡 Installing Stereo Tool..."
    
    # Download and install Stereo Tool
    STEREO_TOOL_URL="https://www.thimeo.com/stereo-tool/download/stereo_tool_gui_jack_64_1030"
    STEREO_TOOL_PATH="/usr/local/bin/stereo_tool_gui_jack_64"
    
    if ! wget -q --spider "$STEREO_TOOL_URL" 2>/dev/null; then
        echo "⚠️  Stereo Tool download not available. Please download manually from:"
        echo "   https://www.thimeo.com/stereo-tool/"
        echo "   Place binary at: $STEREO_TOOL_PATH"
        return
    fi
    
    sudo wget "$STEREO_TOOL_URL" -O "$STEREO_TOOL_PATH"
    sudo chmod +x "$STEREO_TOOL_PATH"
    
    echo "✅ Stereo Tool installed to $STEREO_TOOL_PATH"
}

install_liquidsoap() {
    if command -v apt-get &> /dev/null; then
    sudo apt-get install -y liquidsoap liquidsoap-plugin-all liquidsoap-plugin-ffmpeg
    elif command -v yum &> /dev/null; then
        sudo yum install -y liquidsoap
    else
        echo "⚠️  Please install Liquidsoap manually for your distribution"
    fi
}

install_icecast2() {
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y icecast2
        
        # Basic Icecast configuration
        sudo tee /etc/icecast2/icecast.xml > /dev/null <<EOF
<icecast>
    <location>RDX Broadcast Station</location>
    <admin>admin@localhost</admin>
    <limits>
        <clients>100</clients>
        <sources>2</sources>
        <queue-size>524288</queue-size>
        <client-timeout>30</client-timeout>
        <header-timeout>15</header-timeout>
        <source-timeout>10</source-timeout>
        <burst-on-connect>1</burst-on-connect>
        <burst-size>65535</burst-size>
    </limits>
    <authentication>
        <source-password>rdx_source_password_change_me</source-password>
        <relay-password>rdx_relay_password_change_me</relay-password>
        <admin-user>admin</admin-user>
        <admin-password>rdx_admin_password_change_me</admin-password>
    </authentication>
    <hostname>localhost</hostname>
    <listen-socket>
        <port>8000</port>
        <bind-address>0.0.0.0</bind-address>
    </listen-socket>
    <fileserve>1</fileserve>
    <paths>
        <basedir>/usr/share/icecast2</basedir>
        <logdir>/var/log/icecast2</logdir>
        <webroot>/usr/share/icecast2/web</webroot>
        <adminroot>/usr/share/icecast2/admin</adminroot>
        <pidfile>/var/run/icecast2/icecast.pid</pidfile>
        <alias source="/" destination="/status.xsl"/>
    </paths>
    <logging>
        <accesslog>access.log</accesslog>
        <errorlog>error.log</errorlog>
        <loglevel>3</loglevel>
        <logsize>10000</logsize>
    </logging>
</icecast>
EOF
        
        echo "⚠️  Icecast2 installed! CHANGE DEFAULT PASSWORDS in /etc/icecast2/icecast.xml"
        
    elif command -v yum &> /dev/null; then
        sudo yum install -y icecast
    else
        echo "⚠️  Please install Icecast2 manually for your distribution"
    fi
}

install_darkice() {
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y darkice
    elif command -v yum &> /dev/null; then
        sudo yum install -y darkice
    else
        echo "⚠️  Please install DarkIce manually for your distribution"
    fi
}

install_glasscoder() {
    if command -v apt-get &> /dev/null; then
        # GlassCoder might need to be built from source on some systems
        if ! sudo apt-get install -y glasscoder; then
            echo "📦 Building GlassCoder from source..."
            
            # Install build dependencies
            sudo apt-get install -y build-essential autotools-dev autoconf libtool \
                libcurl4-openssl-dev libmp3lame-dev libtwolame-dev \
                libopus-dev libvorbis-dev libflac-dev libasound2-dev libjack-jackd2-dev
            
            # Clone and build
            git clone https://github.com/RadioFreeAsia/GlassCoder.git /tmp/glasscoder
            cd /tmp/glasscoder
            autoreconf -i
            ./configure
            make -j$(nproc)
            sudo make install
            cd -
            rm -rf /tmp/glasscoder
        fi
    else
        echo "⚠️  Please install GlassCoder manually from: https://github.com/RadioFreeAsia/GlassCoder"
    fi
}

install_vlc() {
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y vlc vlc-plugin-jack
    elif command -v yum &> /dev/null; then
        sudo yum install -y vlc
    else
        echo "⚠️  Please install VLC manually for your distribution"
    fi
}

install_audacity() {
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y audacity
    elif command -v yum &> /dev/null; then
        sudo yum install -y audacity
    else
        echo "⚠️  Please install Audacity manually for your distribution"
    fi
}

install_qjackctl_dependency() {
    # Install QJackCtl silently as JACK dependency (RDX provides the user interface)
    echo "📦 Installing JACK tools (managed by RDX)..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y qjackctl --no-install-recommends
    elif command -v yum &> /dev/null; then
        sudo yum install -y qjackctl
    else
        echo "⚠️  Please install JACK tools manually for your distribution"
    fi
}

# Install RDX core dependencies
install_dependencies() {
    echo "📦 Installing RDX core dependencies..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        sudo apt-get update
        sudo apt-get install -y \
            build-essential cmake \
            qtbase5-dev qttools5-dev \
            libjack-jackd2-dev \
            libasound2-dev \
            libdbus-1-dev \
            pkg-config \
            wget curl git
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        sudo yum install -y \
            gcc-c++ cmake \
            qt5-qtbase-devel qt5-qttools-devel \
            jack-audio-connection-kit-devel \
            alsa-lib-devel \
            dbus-devel \
            pkgconfig \
            wget curl git
    else
        echo "❌ Unsupported package manager. Please install dependencies manually:"
        echo "   - build-essential/gcc-c++, cmake"
        echo "   - Qt5 development libraries"
        echo "   - JACK development libraries" 
        echo "   - ALSA development libraries"
        echo "   - D-Bus development libraries"
        exit 1
    fi
    
    echo "✅ Core dependencies installed"
}

# Build RDX
build_rdx() {
    echo "🔨 Building RDX from source..."
    
    BUILD_DIR="build"
    
    # Clean previous build
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
    
    mkdir "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Configure with CMake
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -DJACK_SUPPORT=ON
    
    # Build with all available cores
    make -j$(nproc)
    
    echo "✅ RDX build completed"
}

# Install RDX
install_rdx() {
    echo "📦 Installing RDX system-wide..."
    
    # Install binaries
    sudo make install
    
    # Create RDX directories
    sudo mkdir -p /etc/rdx
    sudo mkdir -p /var/log/rdx
    sudo mkdir -p /usr/share/rdx
    
    # Install configuration
    sudo cp ../config/rdx-profiles.xml /etc/rdx/
    sudo chown -R $RD_USER:$RD_GROUP /etc/rdx
    sudo chmod -R 755 /etc/rdx
    
    # Install systemd service (if systemd is available)
    if systemctl --version &>/dev/null; then
        echo "🔧 Installing systemd service..."
        
        sudo tee /etc/systemd/system/rdx-jack-helper.service > /dev/null <<EOF
[Unit]
Description=RDX JACK Helper Service
Documentation=https://github.com/anjeleno/rdx-rivendell
After=jackd.service
Wants=jackd.service

[Service]
Type=simple
User=$RD_USER
Group=$RD_GROUP
ExecStart=$INSTALL_PREFIX/bin/rdx-jack-helper
Restart=always
RestartSec=5
Environment=JACK_PROMISCUOUS_SERVER=audio

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable rdx-jack-helper
        echo "✅ Systemd service installed"
    fi
    
    # Set up log rotation
    sudo tee /etc/logrotate.d/rdx > /dev/null <<EOF
/var/log/rdx/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 $RD_USER $RD_GROUP
}
EOF

    echo "✅ RDX installation completed"

    # Install helper scripts
    if [ -f ../scripts/jack-wait-ready.sh ]; then
        sudo install -m 0755 ../scripts/jack-wait-ready.sh /usr/local/bin/jack-wait-ready.sh
        echo "✅ Installed jack-wait-ready.sh to /usr/local/bin"
    fi
}

# Create desktop integration
create_desktop_integration() {
    echo "🖥️ Creating desktop integration..."
    
    # Create desktop file for RDX Control Panel
    sudo tee /usr/share/applications/rdx-control.desktop > /dev/null <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=RDX Audio Control
Comment=RDX Intelligent Audio Routing Control
Exec=$INSTALL_PREFIX/bin/rdx-jack-helper --gui
Icon=audio-card
Terminal=false
Categories=AudioVideo;Audio;
Keywords=audio;jack;rivendell;broadcast;
StartupNotify=true
EOF

    echo "✅ Desktop integration created"
}

# Main installation flow
main() {
    echo
    echo "🎙️ Starting RDX installation for existing Rivendell system..."
    echo
    
    # Parse arguments
    BUILD_ONLY=false
    INSTALL_ONLY=false
    SKIP_BROADCAST_TOOLS=false
    AUTO_INSTALL_BROADCAST=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --install-only)
                INSTALL_ONLY=true
                shift
                ;;
            --skip-broadcast-tools)
                SKIP_BROADCAST_TOOLS=true
                shift
                ;;
            --auto-install-broadcast)
                AUTO_INSTALL_BROADCAST=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: $0 [--build-only] [--install-only] [--skip-broadcast-tools] [--auto-install-broadcast]"
                exit 1
                ;;
        esac
    done
    
    # Run checks
    check_rivendell
    
    # Always detect broadcast tools for status reporting
    detect_broadcast_tools
    
    if [ "$INSTALL_ONLY" != true ]; then
        install_dependencies
        
        # Offer broadcast tools installation
        if [ "$SKIP_BROADCAST_TOOLS" != true ]; then
            echo
            if [ "$AUTO_INSTALL_BROADCAST" = true ]; then
                echo "🚀 Auto-installing recommended broadcast tools..."
                # Auto-install essentials
                declare -A AUTO_TOOLS
                AUTO_TOOLS["liquidsoap"]="yes"
                AUTO_TOOLS["icecast2"]="yes" 
                AUTO_TOOLS["vlc"]="yes"
                AUTO_TOOLS["qjackctl"]="auto"
                
                for tool in "${!AUTO_TOOLS[@]}"; do
                    if [ "${DETECTED_TOOLS[$tool]}" = "missing" ]; then
                        install_single_tool "$tool"
                    fi
                done
            else
                read -p "🎙️ Would you like to install/configure broadcast tools? [Y/n]: " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    install_broadcast_tools
                fi
            fi
        fi
        
        build_rdx
    fi
    
    if [ "$BUILD_ONLY" != true ]; then
        if [ ! -f "build/src/rdx-jack/rdx-jack-helper" ]; then
            echo "❌ RDX not built! Run without --install-only first."
            exit 1
        fi
        
        cd build
        install_rdx
        create_desktop_integration
    fi
    
    echo
    echo "🎉 RDX Installation Complete!"
    echo
    echo "📊 Installed Broadcast Tools:"
    
    # Re-detect tools to show final status
    detect_broadcast_tools
    
    echo
    echo "🚀 Quick Start:"
    echo "   # Test intelligent routing"
    echo "   rdx-jack-helper --profile live-broadcast"
    echo
    echo "   # Switch input sources" 
    echo "   rdx-jack-helper --switch-input vlc"
    echo "   rdx-jack-helper --switch-input system"
    echo
    echo "   # View available sources"
    echo "   rdx-jack-helper --list-sources"
    echo
    if [ "${DETECTED_TOOLS["icecast2"]}" = "installed" ]; then
        echo "   # Start streaming server"
        echo "   sudo systemctl start icecast2"
        echo "   # Access web interface: http://localhost:8000"
        echo
    fi
    
    echo "📡 Your Rivendell system now has WICKED intelligent audio routing!"
    echo "   RDX manages all JACK connections automatically - no manual patching needed!"
    echo
}

# Check if running as root for system installation
if [[ $EUID -eq 0 ]]; then
    echo "⚠️  Don't run as root! RDX will use sudo when needed."
    exit 1
fi

# Run main installation
main "$@"