#!/bin/bash
# RDX Rivendell Enhancement - Smart Installer
# Intelligent dependency detection and installation for any Rivendell system
#
# Version: 2.0.0
# Compatible with: Ubuntu/Debian Rivendell installations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_LOG="/tmp/rdx-install.log"
BACKUP_DIR="/tmp/rdx-backup-$(date +%Y%m%d-%H%M%S)"

# Create log file with proper permissions
if [[ $EUID -eq 0 ]]; then
    # Running as root, use /tmp with proper permissions
    touch "$INSTALL_LOG" 2>/dev/null || INSTALL_LOG="/dev/null"
    chmod 666 "$INSTALL_LOG" 2>/dev/null || true
else
    # Running as user, use home directory
    INSTALL_LOG="$HOME/rdx-install.log"
    touch "$INSTALL_LOG" 2>/dev/null || INSTALL_LOG="/dev/null"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Installation mode
INTERACTIVE=true
FORCE_INSTALL=false
SKIP_DEPS=false
DRY_RUN=false
CHECK_ONLY=false
SCAN_ONLY=false
INSTALL_DEPS_ONLY=false
AUTO_YES=false

print_header() {
    clear
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  RDX Rivendell Enhancement - Smart Installer v2.0.0${NC}"
    echo -e "${BLUE}  Intelligent dependency detection and installation${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo
}

print_status() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$INSTALL_LOG"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$INSTALL_LOG"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$INSTALL_LOG"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$INSTALL_LOG"
}

print_progress() {
    echo -e "${PURPLE}[PROGRESS]${NC} $1" | tee -a "$INSTALL_LOG"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "RDX Smart Installer - Intelligent dependency detection for Rivendell"
    echo ""
    echo "Options:"
    echo "  -y, --yes           Non-interactive mode (auto-confirm)"
    echo "  --auto-yes          Same as --yes (for compatibility)"
    echo "  -f, --force         Force installation even if dependencies fail"
    echo "  -s, --skip-deps     Skip dependency installation"
    echo "  -d, --dry-run       Show what would be installed without doing it"
    echo "  --check-only        Only check dependencies, don't install"
    echo "  --scan-only         Only scan for missing packages"
    echo "  --install-deps-only Only install missing dependencies"
    echo "  -h, --help          Show this help"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes|--auto-yes)
            INTERACTIVE=false
            AUTO_YES=true
            shift
            ;;
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        -s|--skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --scan-only)
            SCAN_ONLY=true
            shift
            ;;
        --install-deps-only)
            INSTALL_DEPS_ONLY=true
            INTERACTIVE=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# System detection functions
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        OS_VERSION=$VERSION_ID
        OS_CODENAME=$VERSION_CODENAME
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    print_status "Detected OS: $OS $OS_VERSION ($OS_CODENAME)"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This installer must be run as root (use sudo)"
        exit 1
    fi
}

detect_rivendell() {
    print_progress "Detecting Rivendell installation..."
    
    # Check for Rivendell binaries
    RIVENDELL_PATHS=(
        "/usr/bin/rdadmin"
        "/usr/local/bin/rdadmin"
        "/opt/rivendell/bin/rdadmin"
    )
    
    RIVENDELL_FOUND=false
    RIVENDELL_PREFIX=""
    
    for path in "${RIVENDELL_PATHS[@]}"; do
        if [[ -x "$path" ]]; then
            RIVENDELL_FOUND=true
            RIVENDELL_PREFIX=$(dirname $(dirname "$path"))
            print_success "Found Rivendell at: $RIVENDELL_PREFIX"
            break
        fi
    done
    
    if [[ "$RIVENDELL_FOUND" == "false" ]]; then
        print_error "Rivendell installation not found!"
        print_error "Please install Rivendell first before installing RDX enhancements"
        exit 1
    fi
    
    # Detect Rivendell version
    if command -v rdadmin >/dev/null 2>&1; then
        RIVENDELL_VERSION=$(rdadmin --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "Unknown")
        print_status "Rivendell version: $RIVENDELL_VERSION"
    fi
    
    # Check for Rivendell libraries
    RIVENDELL_LIBS=(
        "librd.so"
        "librdconf.so"
    )
    
    for lib in "${RIVENDELL_LIBS[@]}"; do
        if find /usr/lib /usr/local/lib /opt -name "$lib" 2>/dev/null | head -1; then
            print_status "Found Rivendell library: $lib"
        else
            print_warning "Rivendell library not found: $lib"
        fi
    done
}

check_dependency() {
    local dep_type="$1"
    local dep_name="$2"
    local package_name="$3"
    local check_command="$4"
    
    case "$dep_type" in
        "command")
            if command -v "$dep_name" >/dev/null 2>&1; then
                print_success "✓ $dep_name found"
                return 0
            else
                print_warning "✗ $dep_name missing"
                echo "$package_name" >> /tmp/missing_packages.txt
                return 1
            fi
            ;;
        "library")
            if ldconfig -p | grep -q "$dep_name" 2>/dev/null; then
                print_success "✓ $dep_name found"
                return 0
            else
                print_warning "✗ $dep_name missing"
                echo "$package_name" >> /tmp/missing_packages.txt
                return 1
            fi
            ;;
        "file")
            if [[ -f "$dep_name" ]]; then
                print_success "✓ $dep_name found"
                return 0
            else
                print_warning "✗ $dep_name missing"
                echo "$package_name" >> /tmp/missing_packages.txt
                return 1
            fi
            ;;
        "custom")
            if eval "$check_command" >/dev/null 2>&1; then
                print_success "✓ $dep_name found"
                return 0
            else
                print_warning "✗ $dep_name missing"
                echo "$package_name" >> /tmp/missing_packages.txt
                return 1
            fi
            ;;
    esac
}

detect_dependencies() {
    print_progress "Scanning system dependencies..."
    
    # Clear missing packages list
    rm -f /tmp/missing_packages.txt
    touch /tmp/missing_packages.txt
    
    # Core build dependencies
    echo -e "\n${YELLOW}Core Build Tools:${NC}"
    check_dependency "command" "cmake" "cmake" ""
    check_dependency "command" "make" "build-essential" ""
    check_dependency "command" "g++" "build-essential" ""
    check_dependency "command" "pkg-config" "pkg-config" ""
    
    # Qt5 dependencies
    echo -e "\n${YELLOW}Qt5 Framework:${NC}"
    check_dependency "library" "libQt5Core" "qtbase5-dev" ""
    check_dependency "library" "libQt5Widgets" "qtbase5-dev" ""
    check_dependency "library" "libQt5DBus" "qtbase5-dev" ""
    check_dependency "library" "libQt5Sql" "qtbase5-dev" ""
    check_dependency "library" "libQt5Network" "qtbase5-dev" ""
    check_dependency "command" "moc" "qtbase5-dev-tools" ""
    
    # Audio system dependencies
    echo -e "\n${YELLOW}Audio System:${NC}"
    check_dependency "library" "libjack" "libjack-jackd2-dev" ""
    check_dependency "library" "libasound" "libasound2-dev" ""
    check_dependency "library" "libpulse" "libpulse-dev" ""
    
    # Multimedia codec dependencies
    echo -e "\n${YELLOW}Multimedia Codecs:${NC}"
    check_dependency "library" "libavcodec" "libavcodec-dev" ""
    check_dependency "library" "libavformat" "libavformat-dev" ""
    check_dependency "library" "libavutil" "libavutil-dev" ""
    check_dependency "library" "libswresample" "libswresample-dev" ""
    check_dependency "command" "ffmpeg" "ffmpeg" ""
    
    # Additional multimedia libraries
    echo -e "\n${YELLOW}Additional Multimedia:${NC}"
    check_dependency "library" "libvorbis" "libvorbis-dev" ""
    check_dependency "library" "libvorbisenc" "libvorbisenc-dev" ""
    check_dependency "library" "libogg" "libogg-dev" ""
    check_dependency "library" "libFLAC" "libflac-dev" ""
    check_dependency "library" "libsndfile" "libsndfile1-dev" ""
    check_dependency "library" "libtag" "libtag1-dev" ""
    check_dependency "library" "libcurl" "libcurl4-openssl-dev" ""
    check_dependency "library" "libssl" "libssl-dev" ""
    check_dependency "library" "libmusicbrainz5" "libmusicbrainz5-dev" ""
    
    # System libraries
    echo -e "\n${YELLOW}System Libraries:${NC}"
    check_dependency "library" "libpam" "libpam0g-dev" ""
    check_dependency "library" "libsamplerate" "libsamplerate0-dev" ""
    check_dependency "library" "libSoundTouch" "libsoundtouch-dev" ""
    check_dependency "library" "libdiscid" "libdiscid-dev" ""
    check_dependency "library" "libid3" "libid3-3.8.3-dev" ""
    
    # Optional dependencies
    echo -e "\n${YELLOW}Optional Features:${NC}"
    check_dependency "library" "libMagick++" "libmagick++-dev" ""
    check_dependency "command" "systemctl" "systemd" ""
    
    # Count missing packages
    MISSING_COUNT=$(wc -l < /tmp/missing_packages.txt)
    
    if [[ $MISSING_COUNT -eq 0 ]]; then
        print_success "All dependencies satisfied!"
        return 0
    else
        print_warning "$MISSING_COUNT dependencies missing"
        return 1
    fi
}

install_dependencies() {
    if [[ "$SKIP_DEPS" == "true" ]]; then
        print_status "Skipping dependency installation (--skip-deps)"
        return 0
    fi
    
    if [[ ! -f /tmp/missing_packages.txt ]] || [[ $(wc -l < /tmp/missing_packages.txt) -eq 0 ]]; then
        print_success "No dependencies to install"
        return 0
    fi
    
    print_progress "Installing missing dependencies..."
    
    # Remove duplicates and create package list
    PACKAGES=$(sort /tmp/missing_packages.txt | uniq | tr '\n' ' ')
    
    print_status "Packages to install: $PACKAGES"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would install packages: $PACKAGES"
        return 0
    fi
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo -e "\n${YELLOW}Install these packages? [y/N]:${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_warning "Dependency installation skipped by user"
            if [[ "$FORCE_INSTALL" == "false" ]]; then
                print_error "Cannot continue without dependencies (use -f to force)"
                exit 1
            fi
        fi
    fi
    
    # Update package cache
    print_status "Updating package cache..."
    if ! apt update 2>&1 | tee -a "$INSTALL_LOG"; then
        print_error "Failed to update package cache"
        return 1
    fi
    
    # Install packages
    print_status "Installing packages..."
    if apt install -y $PACKAGES 2>&1 | tee -a "$INSTALL_LOG"; then
        print_success "Dependencies installed successfully"
        return 0
    else
        print_error "Failed to install some dependencies"
        if [[ "$FORCE_INSTALL" == "false" ]]; then
            exit 1
        fi
        return 1
    fi
}

backup_existing() {
    print_progress "Creating backup of existing installation..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing RDX tools if they exist
    for tool in rdx-jack-helper rdx-aac-stream rdx-aac-stream.sh; do
        if [[ -f "/usr/local/bin/$tool" ]]; then
            cp "/usr/local/bin/$tool" "$BACKUP_DIR/"
            print_status "Backed up: $tool"
        fi
    done
    
    # Backup systemd service if it exists
    if [[ -f "/etc/systemd/system/rdx-jack-helper.service" ]]; then
        cp "/etc/systemd/system/rdx-jack-helper.service" "$BACKUP_DIR/"
        print_status "Backed up: systemd service"
    fi
    
    print_success "Backup created at: $BACKUP_DIR"
}

install_rdx_package() {
    print_progress "Installing RDX enhancement package..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "DRY RUN: Would install RDX package"
        return 0
    fi
    
    # Copy main tools
    if [[ -f "$SCRIPT_DIR/rdx-jack-helper" ]]; then
        cp "$SCRIPT_DIR/rdx-jack-helper" /usr/local/bin/
        chmod +x /usr/local/bin/rdx-jack-helper
        print_success "Installed: rdx-jack-helper"
    else
        print_error "rdx-jack-helper not found in package"
        return 1
    fi
    
    # Copy AAC streaming tools
    if [[ -f "$SCRIPT_DIR/rdx-aac-stream.sh" ]]; then
        cp "$SCRIPT_DIR/rdx-aac-stream.sh" /usr/local/bin/
        chmod +x /usr/local/bin/rdx-aac-stream.sh
        ln -sf /usr/local/bin/rdx-aac-stream.sh /usr/local/bin/rdx-aac-stream
        print_success "Installed: AAC+ streaming tools"
    else
        print_warning "AAC streaming tools not found (optional)"
    fi
    
    # Install systemd service if available
    if [[ -f "$SCRIPT_DIR/rdx-jack-helper.service" ]]; then
        cp "$SCRIPT_DIR/rdx-jack-helper.service" /etc/systemd/system/
        systemctl daemon-reload
        print_success "Installed: systemd service"
        
        if [[ "$INTERACTIVE" == "true" ]]; then
            echo -e "\n${YELLOW}Enable RDX service to start on boot? [y/N]:${NC} "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                systemctl enable rdx-jack-helper
                print_success "RDX service enabled for auto-start"
            fi
        fi
    fi
    
    return 0
}

post_install_verification() {
    print_progress "Verifying installation..."
    
    # Test main tools
    if command -v rdx-jack-helper >/dev/null 2>&1; then
        VERSION=$(rdx-jack-helper --version 2>/dev/null || echo "Unknown")
        print_success "rdx-jack-helper installed: $VERSION"
    else
        print_error "rdx-jack-helper installation failed"
        return 1
    fi
    
    if command -v rdx-aac-stream >/dev/null 2>&1; then
        print_success "AAC+ streaming tools installed"
        
        # Test AAC capabilities
        if command -v ffmpeg >/dev/null 2>&1; then
            print_success "FFmpeg available for AAC+ encoding"
        else
            print_warning "FFmpeg not available - AAC+ encoding disabled"
        fi
    else
        print_warning "AAC+ streaming tools not installed"
    fi
    
    # Test Rivendell integration
    if find /usr/lib /usr/local/lib -name "librd.so*" 2>/dev/null | head -1 >/dev/null; then
        print_success "Rivendell integration available"
    else
        print_warning "Rivendell libraries not found - limited functionality"
    fi
    
    return 0
}

show_installation_summary() {
    print_header
    echo -e "${GREEN}=========================${NC}"
    echo -e "${GREEN}  INSTALLATION COMPLETE  ${NC}"
    echo -e "${GREEN}=========================${NC}"
    echo
    
    print_success "RDX Rivendell Enhancement installed successfully!"
    echo
    
    echo -e "${CYAN}Installed Tools:${NC}"
    echo "  • rdx-jack-helper    - Intelligent JACK management"
    echo "  • rdx-aac-stream     - Professional AAC+ streaming"
    echo
    
    echo -e "${CYAN}Quick Start:${NC}"
    echo "  # Test JACK helper"
    echo "  rdx-jack-helper --version"
    echo
    echo "  # Start AAC+ stream (example)"
    echo "  rdx-aac-stream -b 64 -1 icecast://source:password@server:8000/stream.aac"
    echo
    
    echo -e "${CYAN}Documentation:${NC}"
    if [[ -f "$SCRIPT_DIR/AAC_STREAMING_GUIDE.md" ]]; then
        echo "  • Complete guide: $SCRIPT_DIR/AAC_STREAMING_GUIDE.md"
    fi
    echo "  • Installation log: $INSTALL_LOG"
    echo "  • Backup location: $BACKUP_DIR"
    echo
    
    if [[ -f "/etc/systemd/system/rdx-jack-helper.service" ]]; then
        echo -e "${CYAN}Service Management:${NC}"
        echo "  systemctl start rdx-jack-helper"
        echo "  systemctl enable rdx-jack-helper"
        echo "  systemctl status rdx-jack-helper"
        echo
    fi
    
    print_success "Ready for professional broadcast audio enhancement!"
}

# Main installation flow
main() {
    # Handle specialized operation modes
    if [[ "$CHECK_ONLY" == "true" ]]; then
        print_header
        detect_os
        detect_rivendell
        detect_dependencies
        exit 0
    fi
    
    if [[ "$SCAN_ONLY" == "true" ]]; then
        detect_os
        detect_dependencies
        exit 0
    fi
    
    if [[ "$INSTALL_DEPS_ONLY" == "true" ]]; then
        # Check for root privileges for installation
        if [[ $EUID -ne 0 ]]; then
            print_error "Installing dependencies requires root privileges. Use: sudo rdx-deps install"
            exit 1
        fi
        
        detect_os
        detect_rivendell
        
        # Set non-interactive mode for automatic installation
        export DEBIAN_FRONTEND=noninteractive
        
        if ! detect_dependencies; then
            install_dependencies
        fi
        exit 0
    fi
    
    # Normal full installation flow
    print_header
    
    # Initial setup
    check_root
    detect_os
    
    echo "Starting installation at $(date)" > "$INSTALL_LOG"
    
    # System analysis
    detect_rivendell
    
    if ! detect_dependencies; then
        if [[ "$FORCE_INSTALL" == "false" ]]; then
            install_dependencies
        fi
    fi
    
    # Installation
    backup_existing
    install_rdx_package
    
    # Verification and completion
    post_install_verification
    show_installation_summary
    
    print_success "Installation completed successfully!"
}

# Run main installation
main "$@"