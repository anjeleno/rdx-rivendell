# RDX (Rivendell Extended) Integration for rivendell-auto-install.sh
#
# Add these functions to your rivendell-auto-install.sh script to include RDX
# intelligent audio routing system in the automated installation process.
#
# INSERT AFTER the install_broadcasting_tools function

# Function to install RDX (Rivendell Extended) intelligent audio routing
install_rdx() {
    echo "🔥 Installing RDX (Rivendell Extended) - Intelligent Audio Routing System..."
    
    # Check if we're in the right environment
    if [ ! -d "/home/rd" ]; then
        echo "❌ RDX requires Rivendell installation. Please run standard Rivendell installation first."
        return 1
    fi
    
    # Create RDX installation directory
    sudo mkdir -p /opt/rdx
    cd /opt/rdx
    
    # Clone RDX repository
    echo "📦 Downloading RDX source code..."
    if ! sudo git clone https://github.com/anjeleno/rdx-rivendell.git .; then
        echo "❌ Failed to clone RDX repository"
        return 1
    fi
    
    # Install RDX dependencies
    echo "📦 Installing RDX dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential cmake \
        qtbase5-dev qttools5-dev \
        libjack-jackd2-dev \
        libasound2-dev \
        libdbus-1-dev \
        pkg-config \
        wget curl
    
    # Build RDX
    echo "🔨 Building RDX from source..."
    
    # Clean any previous build
    if [ -d "build" ]; then
        sudo rm -rf build
    fi
    
    sudo mkdir build
    cd build
    
    # Configure with CMake
    sudo cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DJACK_SUPPORT=ON
    
    # Build with all available cores
    sudo make -j$(nproc)
    
    # Install RDX system-wide
    echo "📦 Installing RDX system-wide..."
    sudo make install
    
    # Create RDX configuration directories
    sudo mkdir -p /etc/rdx
    sudo mkdir -p /var/log/rdx
    sudo mkdir -p /usr/share/rdx
    
    # Install RDX configuration files
    sudo cp ../config/rdx-profiles.xml /etc/rdx/
    sudo chown -R rd:rivendell /etc/rdx
    sudo chmod -R 755 /etc/rdx
    
    # Set up log permissions
    sudo chown -R rd:rivendell /var/log/rdx
    sudo chmod -R 755 /var/log/rdx
    
    # Install systemd service
    echo "🔧 Installing RDX systemd service..."
    
    sudo tee /etc/systemd/system/rdx-jack-helper.service > /dev/null <<EOF
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
    
    # Enable but don't start yet (JACK needs to be configured first)
    sudo systemctl daemon-reload
    sudo systemctl enable rdx-jack-helper
    
    # Set up log rotation
    sudo tee /etc/logrotate.d/rdx > /dev/null <<EOF
/var/log/rdx/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 rd rivendell
}
EOF

    # Create desktop integration
    echo "🖥️ Creating RDX desktop integration..."
    
    sudo tee /usr/share/applications/rdx-control.desktop > /dev/null <<EOF
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

    # Add RDX to rd user's PATH and create aliases
    echo "🔧 Configuring RDX user environment..."
    
    # Add RDX aliases to rd user's bashrc
    sudo tee -a /home/rd/.bashrc > /dev/null <<EOF

# RDX (Rivendell Extended) Aliases
alias rdx-scan='rdx-jack-helper --scan'
alias rdx-live='rdx-jack-helper --profile live-broadcast'
alias rdx-production='rdx-jack-helper --profile production'
alias rdx-automation='rdx-jack-helper --profile automation'
alias rdx-switch-vlc='rdx-jack-helper --switch-input vlc'
alias rdx-switch-system='rdx-jack-helper --switch-input system'
alias rdx-sources='rdx-jack-helper --list-sources'
alias rdx-status='systemctl status rdx-jack-helper'

# Quick RDX help
alias rdx-help='echo "🔥 RDX Commands:
  rdx-scan        - Scan for JACK devices
  rdx-live        - Switch to live broadcast profile  
  rdx-production  - Switch to production profile
  rdx-automation  - Switch to automation profile
  rdx-switch-vlc  - Route VLC as main input
  rdx-switch-system - Route system capture as main input
  rdx-sources     - List available input sources
  rdx-status      - Check RDX service status
  rdx-jack-helper --help - Full command help"'

EOF

    # Set ownership
    sudo chown rd:rivendell /home/rd/.bashrc
    
    # Create RDX quick start script for desktop
    sudo tee /home/rd/Desktop/RDX-QuickStart.sh > /dev/null <<EOF
#!/bin/bash
# RDX Quick Start Script
# Double-click to launch RDX Audio Control

# Open terminal with RDX status
gnome-terminal --title="RDX Audio Control" -- bash -c "
echo '🔥 RDX (Rivendell Extended) - Intelligent Audio Routing'
echo '=================================================='
echo
echo '📊 Current JACK Status:'
rdx-jack-helper --scan
echo
echo '🚀 Quick Commands:'
echo '  rdx-live        - Live broadcast profile'
echo '  rdx-production  - Production profile'
echo '  rdx-switch-vlc  - Route VLC input'
echo '  rdx-sources     - List input sources'
echo
echo 'Type any RDX command or press Ctrl+C to exit'
bash
"
EOF

    sudo chmod +x /home/rd/Desktop/RDX-QuickStart.sh
    sudo chown rd:rivendell /home/rd/Desktop/RDX-QuickStart.sh
    
    echo "✅ RDX installation completed!"
    echo
    echo "🎉 RDX Features Available:"
    echo "   ✅ Intelligent JACK device discovery"
    echo "   ✅ Auto-routing with critical connection protection"
    echo "   ✅ Smart hardware detection (processors, streamers, inputs)"
    echo "   ✅ Profile-based service orchestration"
    echo "   ✅ Real-time audio routing management"
    echo
    echo "🚀 RDX will start automatically with Rivendell after reboot!"
    echo "   Use 'rdx-help' command for quick reference"
    
    # Mark step as completed
    mark_step_completed "install_rdx"
}

# Function to configure RDX broadcast tools integration
configure_rdx_broadcast_tools() {
    echo "🔧 Configuring RDX broadcast tools integration..."
    
    # Detect and configure Stereo Tool if available
    if [ -f "/home/rd/APPS/stereo_tool_gui_jack_64_1030" ]; then
        echo "📡 Configuring Stereo Tool for RDX..."
        
        # Copy to system location for RDX
        sudo cp /home/rd/APPS/stereo_tool_gui_jack_64_1030 /usr/local/bin/stereo_tool_gui_jack_64
        sudo chmod +x /usr/local/bin/stereo_tool_gui_jack_64
        
        echo "✅ Stereo Tool configured for RDX"
    fi
    
    # Update RDX configuration to match installed broadcast tools
    if [ -f "/etc/rdx/rdx-profiles.xml" ]; then
        echo "🔧 Updating RDX profiles for installed broadcast tools..."
        
        # Update Liquidsoap path if installed differently
        if command -v liquidsoap &> /dev/null; then
            LIQUIDSOAP_PATH=$(which liquidsoap)
            sudo sed -i "s|/usr/bin/liquidsoap|$LIQUIDSOAP_PATH|g" /etc/rdx/rdx-profiles.xml
        fi
        
        echo "✅ RDX profiles updated"
    fi
    
    # Create RDX integration with existing radio.liq
    if [ -f "/home/rd/APPS/radio.liq" ]; then
        echo "🌊 Integrating RDX with existing Liquidsoap configuration..."
        
        # Create RDX-enhanced radio.liq
        sudo cp /home/rd/APPS/radio.liq /home/rd/APPS/radio.liq.backup
        
        # Add RDX JACK integration to radio.liq
        sudo tee -a /home/rd/APPS/radio.liq > /dev/null <<EOF

# RDX Integration - Intelligent JACK Routing
# This section is managed by RDX for optimal audio routing

# RDX-managed JACK inputs
rdx_input = input.jack("rdx_main_input")
rdx_processed = input.jack("rdx_processed_output")

# Smart fallback chain with RDX
main_source = fallback(track_sensitive=false, [
    rdx_processed,  # RDX processed audio (highest priority)
    rdx_input,      # RDX main input
    default         # Original default source
])

# Output to RDX for processing chain
output.jack("rdx_chain_input", main_source)
EOF
        
        echo "✅ Liquidsoap configuration enhanced for RDX"
    fi
    
    mark_step_completed "configure_rdx_broadcast_tools"
}

# Integration point for main installer
# ADD THIS TO THE MAIN INSTALLATION SEQUENCE after install_broadcasting_tools:

# In the main installation flow, add these lines after install_broadcasting_tools:
# if ! step_completed "install_rdx"; then install_rdx; fi
# if ! step_completed "configure_rdx_broadcast_tools"; then configure_rdx_broadcast_tools; fi