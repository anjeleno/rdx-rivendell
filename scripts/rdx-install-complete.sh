#!/bin/bash

##############################################################################
# RDX Complete Installation Script - Professional Broadcast Integration
# Version: 2.2.0
# 
# This script provides complete RDX integration into an existing Rivendell
# system, including GUI components and RDAdmin integration.
##############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
RDX_VERSION="2.4.0"
RDX_HOME="/opt/rdx"
RDX_CONFIG="/etc/rdx"
RIVENDELL_CONFIG="/etc/rd.conf"
MYSQL_CREDS=""
DB_HOST=""
DB_USER=""
DB_PASS=""
DB_NAME=""

##############################################################################
# Logging Functions
##############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${PURPLE}===================================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}===================================================${NC}\n"
}

##############################################################################
# System Detection Functions
##############################################################################

detect_rivendell() {
    log_info "Detecting Rivendell installation..."
    
    if [ ! -f "$RIVENDELL_CONFIG" ]; then
        log_error "Rivendell configuration not found at $RIVENDELL_CONFIG"
        log_error "This script requires a functioning Rivendell installation"
        exit 1
    fi
    
    # Extract database credentials from rd.conf [mySQL] section
    DB_HOST=$(grep -A 10 "^\[mySQL\]" "$RIVENDELL_CONFIG" | grep "^Hostname=" | cut -d'=' -f2)
    DB_USER=$(grep -A 10 "^\[mySQL\]" "$RIVENDELL_CONFIG" | grep "^Loginname=" | cut -d'=' -f2)
    DB_PASS=$(grep -A 10 "^\[mySQL\]" "$RIVENDELL_CONFIG" | grep "^Password=" | cut -d'=' -f2)
    DB_NAME=$(grep -A 10 "^\[mySQL\]" "$RIVENDELL_CONFIG" | grep "^Database=" | cut -d'=' -f2)
    
    log_success "Rivendell detected - Database: $DB_NAME@$DB_HOST"
    
    # Test database connection
    if ! mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "SELECT COUNT(*) FROM VERSION;" >/dev/null 2>&1; then
        log_error "Cannot connect to Rivendell database"
        exit 1
    fi
    
    log_success "Database connection verified"
}

detect_audio_system() {
    log_info "Detecting audio system..."
    
    # Check for JACK
    if command -v jackd >/dev/null 2>&1; then
        log_success "JACK Audio Connection Kit detected"
        JACK_AVAILABLE=true
    else
        log_warning "JACK not found - will install"
        JACK_AVAILABLE=false
    fi
    
    # Check for ALSA
    if [ -d "/proc/asound" ]; then
        log_success "ALSA detected"
        ALSA_AVAILABLE=true
    else
        log_warning "ALSA not found"
        ALSA_AVAILABLE=false
    fi
    
    # Check audio interfaces
    audio_interfaces=$(aplay -l 2>/dev/null | grep "card" | wc -l || echo "0")
    log_info "Audio interfaces detected: $audio_interfaces"
}

##############################################################################
# Dependency Management
##############################################################################

install_dependencies() {
    log_header "Installing Dependencies"
    
    # Core dependencies (be conservative to avoid Rivendell conflicts)
    local deps=(
        "jackd2"
        "jack-tools" 
        "qjackctl"
        "libjack-jackd2-dev"
        "ffmpeg"
        "libavcodec-extra"
        "libqt5widgets5"
        "libqt5sql5-mysql"
        "mysql-client"
        "alsa-utils"
    )
    
    log_info "Updating package lists..."
    apt-get update >/dev/null 2>&1
    
    for dep in "${deps[@]}"; do
        if ! dpkg -l | grep -q "^ii  $dep "; then
            log_info "Installing $dep..."
            if ! apt-get install -y "$dep" >/dev/null 2>&1; then
                log_warning "Failed to install $dep - continuing anyway"
            else
                log_success "$dep installed"
            fi
        else
            log_success "$dep already installed"
        fi
    done
    
    # Check for potential Rivendell conflicts and warn
    log_info "Checking for potential audio conflicts..."
    if systemctl is-active --quiet rivendell; then
        log_success "Rivendell service is running - safe to continue"
    else
        log_warning "Rivendell service not running - this is normal during installation"
    fi
}

##############################################################################
# RDX Core Installation
##############################################################################

install_rdx_core() {
    log_header "Installing RDX Core Components"
    
    # Create directories
    log_info "Creating RDX directory structure..."
    mkdir -p "$RDX_HOME"/{bin,lib,share,config}
    mkdir -p "$RDX_CONFIG"
    mkdir -p /var/log/rdx
    mkdir -p /var/run/rdx
    
    # Install main executable (check if already installed by .deb package)
    log_info "Checking RDX executable installation..."
    if [ -f "/usr/local/bin/rdx-jack-helper" ]; then
        cp "/usr/local/bin/rdx-jack-helper" "$RDX_HOME/bin/rdx-jack"
        chmod +x "$RDX_HOME/bin/rdx-jack"
        log_success "RDX executable installed from package"
    elif [ -f "./rdx-jack" ]; then
        cp ./rdx-jack "$RDX_HOME/bin/"
        chmod +x "$RDX_HOME/bin/rdx-jack"
        log_success "RDX executable installed from source"
    else
        log_error "RDX executable not found - package may not be properly installed"
        log_info "Please ensure rdx-rivendell-enhanced package is installed first"
        exit 1
    fi
    
    # Install GUI library if available (check package installation first)
    if [ -f "/usr/local/share/rdx/librdx-gui.a" ]; then
        cp "/usr/local/share/rdx/librdx-gui.a" "$RDX_HOME/lib/"
        log_success "RDX GUI library installed from package"
    elif [ -f "./librdx-gui.a" ]; then
        cp ./librdx-gui.a "$RDX_HOME/lib/"
        log_success "RDX GUI library installed from source"
    else
        log_warning "RDX GUI library not found - basic functionality only"
    fi
    
    # Install configuration templates
    cat > "$RDX_CONFIG/rdx.conf" << 'EOF'
[Audio]
SampleRate=48000
BufferSize=1024
Channels=2
JackAutoStart=true
DefaultProfile=broadcast

[Streaming]
EnableAAC=true
EnableMP3=true
DefaultBitrate=128
Quality=high

[Integration]
RivendellIntegration=true
AutoDetectServices=true
CreateDesktopEntry=true

[Logging]
LogLevel=INFO
LogFile=/var/log/rdx/rdx.log
MaxLogSize=10MB
EOF
    
    log_success "Configuration templates installed"
}

##############################################################################
# Database Integration
##############################################################################

create_rdx_database_schema() {
    log_header "Creating RDX Database Schema"
    
    log_info "Creating RDX configuration tables..."
    
    # Create RDX tables in Rivendell database
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" << 'EOF'
CREATE TABLE IF NOT EXISTS RDX_CONFIG (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    PARAMETER VARCHAR(64) NOT NULL UNIQUE,
    VALUE VARCHAR(255),
    DESCRIPTION TEXT,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS RDX_PROFILES (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    NAME VARCHAR(64) NOT NULL UNIQUE,
    DESCRIPTION TEXT,
    SAMPLE_RATE INT DEFAULT 48000,
    BUFFER_SIZE INT DEFAULT 1024,
    CHANNELS INT DEFAULT 2,
    JACK_SETTINGS TEXT,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS RDX_AUDIO_INPUTS (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    NAME VARCHAR(64) NOT NULL,
    DEVICE VARCHAR(128),
    CHANNELS INT DEFAULT 2,
    ENABLED ENUM('Y','N') DEFAULT 'Y',
    JACK_PORT VARCHAR(128),
    PROFILE_ID INT,
    FOREIGN KEY (PROFILE_ID) REFERENCES RDX_PROFILES(ID) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS RDX_STREAMING_SERVICES (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    NAME VARCHAR(64) NOT NULL,
    TYPE ENUM('ICECAST','SHOUTCAST','RTMP','HLS') DEFAULT 'ICECAST',
    URL VARCHAR(255),
    MOUNT_POINT VARCHAR(128),
    USERNAME VARCHAR(64),
    PASSWORD VARCHAR(128),
    BITRATE INT DEFAULT 128,
    FORMAT ENUM('MP3','AAC','OGG') DEFAULT 'AAC',
    ENABLED ENUM('Y','N') DEFAULT 'Y',
    PROFILE_ID INT,
    FOREIGN KEY (PROFILE_ID) REFERENCES RDX_PROFILES(ID) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS RDX_CONNECTIONS (
    ID INT AUTO_INCREMENT PRIMARY KEY,
    SOURCE_PORT VARCHAR(128),
    DEST_PORT VARCHAR(128),
    CONNECTION_TYPE ENUM('AUDIO','MIDI','CONTROL') DEFAULT 'AUDIO',
    AUTO_CONNECT ENUM('Y','N') DEFAULT 'N',
    PROFILE_ID INT,
    FOREIGN KEY (PROFILE_ID) REFERENCES RDX_PROFILES(ID) ON DELETE CASCADE
);

INSERT IGNORE INTO RDX_CONFIG (PARAMETER, VALUE, DESCRIPTION) VALUES
('VERSION', '2.2.0', 'RDX System Version'),
('INTEGRATION_ENABLED', 'Y', 'RDAdmin Integration Status'),
('GUI_ENABLED', 'Y', 'GUI Components Available'),
('AUTO_START', 'Y', 'Auto-start with Rivendell'),
('LOG_LEVEL', 'INFO', 'Default logging level');

INSERT IGNORE INTO RDX_PROFILES (NAME, DESCRIPTION, SAMPLE_RATE, BUFFER_SIZE, CHANNELS) VALUES
('broadcast', 'Professional Broadcast Profile', 48000, 1024, 2),
('streaming', 'High-Quality Streaming Profile', 44100, 512, 2),
('production', 'Studio Production Profile', 96000, 256, 8);
EOF

    if [ $? -eq 0 ]; then
        log_success "RDX database schema created successfully"
    else
        log_error "Failed to create database schema"
        exit 1
    fi
}

##############################################################################
# RDAdmin Integration
##############################################################################

integrate_with_rdadmin() {
    log_header "Integrating with RDAdmin"
    
    # Check if RDAdmin is available
    if ! command -v rdadmin >/dev/null 2>&1; then
        log_error "RDAdmin not found - cannot integrate"
        return 1
    fi
    
    log_info "Creating RDAdmin integration components..."
    
    # Create RDX control script for RDAdmin
    cat > "$RDX_HOME/bin/rdx-admin-launcher" << 'EOF'
#!/bin/bash
# RDX Admin Launcher - Called from RDAdmin
export RDX_HOME="/opt/rdx"
export PATH="$RDX_HOME/bin:$PATH"

# Check if RDX GUI is available
if [ -f "$RDX_HOME/lib/librdx-gui.a" ]; then
    # Launch GUI version
    exec "$RDX_HOME/bin/rdx-jack" --gui "$@"
else
    # Launch console version
    exec "$RDX_HOME/bin/rdx-jack" "$@"
fi
EOF
    chmod +x "$RDX_HOME/bin/rdx-admin-launcher"
    
    # Create desktop entry for RDX
    cat > /usr/share/applications/rivendell-rdx.desktop << 'EOF'
[Desktop Entry]
Encoding=UTF-8
Terminal=false
Categories=Qt;KDE;Rivendell;Audio;
Name=RDX Audio Control
GenericName=Professional Audio Processing
Comment=Advanced audio processing and streaming for Rivendell
Exec=/opt/rdx/bin/rdx-admin-launcher
Icon=multimedia-volume-control
Type=Application
Terminal=false
EOF
    
    # Create RDAdmin menu integration
    log_info "Configuring RDAdmin menu integration..."
    
    # Add RDX button configuration to database
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" << 'EOF'
INSERT IGNORE INTO RDX_CONFIG (PARAMETER, VALUE, DESCRIPTION) VALUES
('RDADMIN_BUTTON_TEXT', '🔥 RDX Audio Control', 'Text for RDAdmin button'),
('RDADMIN_BUTTON_COMMAND', '/opt/rdx/bin/rdx-admin-launcher', 'Command executed by RDAdmin button'),
('RDADMIN_BUTTON_TOOLTIP', 'Launch RDX Professional Audio Control', 'Tooltip for RDAdmin button'),
('RDADMIN_INTEGRATION_VERSION', '2.2.0', 'Version of RDAdmin integration');
EOF
    
    log_success "RDAdmin integration configured"
    
    # Create symbolic link for easy access
    ln -sf "$RDX_HOME/bin/rdx-admin-launcher" /usr/local/bin/rdx-admin
    
    log_success "RDX accessible via 'rdx-admin' command"
}

##############################################################################
# Service Configuration
##############################################################################

configure_systemd_services() {
    log_header "Configuring System Services"
    
    # Create RDX systemd service
    cat > /etc/systemd/system/rdx.service << 'EOF'
[Unit]
Description=RDX Professional Audio Processing
After=rivendell.service mysql.service
Requires=rivendell.service
PartOf=rivendell.service

[Service]
Type=forking
User=rivendell
Group=rivendell
Environment=RDX_HOME=/opt/rdx
Environment=PATH=/opt/rdx/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=/opt/rdx/bin/rdx-jack --daemon
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
PIDFile=/var/run/rdx/rdx.pid
Restart=always
RestartSec=10

[Install]
WantedBy=rivendell.service
EOF
    
    # Enable and configure service
    systemctl daemon-reload
    systemctl enable rdx.service
    
    log_success "RDX service configured and enabled"
}

##############################################################################
# Audio Configuration
##############################################################################

configure_jack_integration() {
    log_header "Configuring JACK Integration"
    
    # Create JACK configuration for Rivendell integration
    cat > "$RDX_CONFIG/jack.conf" << 'EOF'
# RDX JACK Configuration for Rivendell Integration
JACK_DEFAULT_SERVER="default"
JACK_DRIVER="alsa"
JACK_SAMPLE_RATE="48000"
JACK_PERIOD_SIZE="1024"
JACK_PERIODS="2"
JACK_DEVICE="hw:0"
JACK_REALTIME="true"
JACK_PRIORITY="70"

# Auto-connection rules
AUTO_CONNECT_RIVENDELL="true"
AUTO_CONNECT_SYSTEM="true"
EOF
    
    # Set up JACK auto-start script
    cat > "$RDX_HOME/bin/rdx-jack-setup" << 'EOF'
#!/bin/bash
# RDX JACK Setup and Auto-connection

source /opt/rdx/config/jack.conf 2>/dev/null || true

# Start JACK if not running
if ! pgrep -f "jackd" >/dev/null; then
    echo "Starting JACK Audio Connection Kit..."
    jackd -d "$JACK_DRIVER" -r "$JACK_SAMPLE_RATE" -p "$JACK_PERIOD_SIZE" -n "$JACK_PERIODS" &
    sleep 3
fi

# Auto-connect to Rivendell ports
if [ "$AUTO_CONNECT_RIVENDELL" = "true" ]; then
    # Connect RDX outputs to Rivendell inputs
    jack_connect rdx:output_1 rivendell:input_1 2>/dev/null || true
    jack_connect rdx:output_2 rivendell:input_2 2>/dev/null || true
    
    # Connect Rivendell outputs to RDX inputs
    jack_connect rivendell:output_1 rdx:input_1 2>/dev/null || true
    jack_connect rivendell:output_2 rdx:input_2 2>/dev/null || true
fi

# Auto-connect to system ports
if [ "$AUTO_CONNECT_SYSTEM" = "true" ]; then
    jack_connect system:capture_1 rdx:input_1 2>/dev/null || true
    jack_connect system:capture_2 rdx:input_2 2>/dev/null || true
    jack_connect rdx:output_1 system:playback_1 2>/dev/null || true
    jack_connect rdx:output_2 system:playback_2 2>/dev/null || true
fi

echo "JACK setup completed"
EOF
    chmod +x "$RDX_HOME/bin/rdx-jack-setup"
    
    log_success "JACK integration configured"
}

##############################################################################
# Post-Installation Configuration
##############################################################################

configure_post_installation() {
    log_header "Post-Installation Configuration"
    
    # Set permissions
    chown -R rivendell:rivendell "$RDX_HOME"
    chown -R rivendell:rivendell "$RDX_CONFIG"
    chown -R rivendell:rivendell /var/log/rdx
    chown -R rivendell:rivendell /var/run/rdx
    
    # Create log rotation
    cat > /etc/logrotate.d/rdx << 'EOF'
/var/log/rdx/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    copytruncate
    su rivendell rivendell
}
EOF
    
    # Add RDX to Rivendell user's PATH
    if ! grep -q "RDX_HOME" /home/rivendell/.bashrc 2>/dev/null; then
        echo 'export RDX_HOME="/opt/rdx"' >> /home/rivendell/.bashrc
        echo 'export PATH="$RDX_HOME/bin:$PATH"' >> /home/rivendell/.bashrc
    fi
    
    log_success "Post-installation configuration completed"
}

##############################################################################
# Verification and Testing
##############################################################################

verify_installation() {
    log_header "Verifying Installation"
    
    local errors=0
    
    # Check executables
    if [ -x "$RDX_HOME/bin/rdx-jack" ]; then
        log_success "RDX executable found and executable"
    else
        log_error "RDX executable missing or not executable"
        ((errors++))
    fi
    
    # Check database tables
    if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "SELECT COUNT(*) FROM RDX_CONFIG;" >/dev/null 2>&1; then
        log_success "RDX database tables accessible"
    else
        log_error "RDX database tables not found"
        ((errors++))
    fi
    
    # Check services
    if systemctl is-enabled rdx.service >/dev/null 2>&1; then
        log_success "RDX service enabled"
    else
        log_warning "RDX service not enabled"
    fi
    
    # Check desktop integration
    if [ -f "/usr/share/applications/rivendell-rdx.desktop" ]; then
        log_success "Desktop entry created"
    else
        log_warning "Desktop entry missing"
    fi
    
    # Test basic functionality
    log_info "Testing RDX basic functionality..."
    if timeout 10 "$RDX_HOME/bin/rdx-jack" --version >/dev/null 2>&1; then
        log_success "RDX responds to version query"
    else
        log_warning "RDX version test failed"
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Installation verification completed successfully"
        return 0
    else
        log_error "Installation verification found $errors errors"
        return 1
    fi
}

##############################################################################
# Main Installation Flow
##############################################################################

display_banner() {
    echo -e "${CYAN}"
    echo "██████╗ ██████╗ ██╗  ██╗    ██████╗ ██╗██╗   ██╗███████╗███╗   ██╗██████╗ ███████╗██╗     ██╗     "
    echo "██╔══██╗██╔══██╗╚██╗██╔╝    ██╔══██╗██║██║   ██║██╔════╝████╗  ██║██╔══██╗██╔════╝██║     ██║     "
    echo "██████╔╝██║  ██║ ╚███╔╝     ██████╔╝██║██║   ██║█████╗  ██╔██╗ ██║██║  ██║█████╗  ██║     ██║     "
    echo "██╔══██╗██║  ██║ ██╔██╗     ██╔══██╗██║╚██╗ ██╔╝██╔══╝  ██║╚██╗██║██║  ██║██╔══╝  ██║     ██║     "
    echo "██║  ██║██████╔╝██╔╝ ██╗    ██║  ██║██║ ╚████╔╝ ███████╗██║ ╚████║██████╔╝███████╗███████╗███████╗"
    echo "╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚══════╝╚══════╝"
    echo -e "${NC}"
    echo -e "${BLUE}Professional Audio Processing & Streaming for Rivendell Radio Automation${NC}"
    echo -e "${BLUE}Version: $RDX_VERSION | Complete Installation & Integration${NC}\n"
}

main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    display_banner
    
    log_info "Starting RDX Complete Installation..."
    
    # Pre-installation checks
    detect_rivendell
    detect_audio_system
    
    # Installation steps
    install_dependencies
    install_rdx_core
    create_rdx_database_schema
    integrate_with_rdadmin
    configure_systemd_services
    configure_jack_integration
    configure_post_installation
    
    # Verification
    if verify_installation; then
        log_header "🎉 Installation Completed Successfully!"
        echo -e "${GREEN}RDX Professional Audio Processing is now integrated with your Rivendell system.${NC}\n"
        
        echo -e "${CYAN}Getting Started:${NC}"
        echo -e "• Launch via RDAdmin: Look for '🔥 RDX Audio Control' button"
        echo -e "• Command line: ${YELLOW}rdx-admin${NC}"
        echo -e "• Desktop: Applications → Rivendell → RDX Audio Control"
        echo -e "• Service status: ${YELLOW}systemctl status rdx${NC}"
        echo -e "• Configuration: ${YELLOW}$RDX_CONFIG/rdx.conf${NC}"
        echo -e "• Logs: ${YELLOW}/var/log/rdx/rdx.log${NC}\n"
        
        echo -e "${CYAN}Features Available:${NC}"
        echo -e "• Professional audio processing with Stereo Tool integration"
        echo -e "• AAC+ and MP3 streaming to multiple services"
        echo -e "• JACK audio routing and connection management"
        echo -e "• Real-time audio monitoring and control"
        echo -e "• Complete Rivendell database integration"
        echo -e "• Web-based remote control interface\n"
        
        echo -e "${YELLOW}Next Steps:${NC}"
        echo -e "1. Restart Rivendell: ${YELLOW}systemctl restart rivendell${NC}"
        echo -e "2. Launch RDAdmin and look for the RDX button"
        echo -e "3. Configure your audio profiles and streaming services"
        echo -e "4. Test JACK connections with your audio hardware\n"
        
        log_success "Installation completed successfully!"
        exit 0
    else
        log_error "Installation completed with warnings - please review above"
        exit 2
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "RDX Complete Installation Script"
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --verify      Verify existing installation"
        echo "  --uninstall   Remove RDX installation"
        echo ""
        exit 0
        ;;
    --verify)
        detect_rivendell
        verify_installation
        exit $?
        ;;
    --uninstall)
        log_warning "Uninstalling RDX..."
        systemctl stop rdx.service 2>/dev/null || true
        systemctl disable rdx.service 2>/dev/null || true
        rm -rf "$RDX_HOME"
        rm -rf "$RDX_CONFIG"
        rm -f /etc/systemd/system/rdx.service
        rm -f /usr/share/applications/rivendell-rdx.desktop
        rm -f /usr/local/bin/rdx-admin
        systemctl daemon-reload
        log_success "RDX uninstalled"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac