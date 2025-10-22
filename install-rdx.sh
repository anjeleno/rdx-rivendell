#!/bin/bash
# RDX Smart Installer - Auto-detects Ubuntu version and installs appropriate package
# Supports Ubuntu 22.04 (Jammy) and 24.04+ (Noble and newer)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="anjeleno/rdx-rivendell"
PACKAGE_NAME="rdx-broadcast-control-center"
TEMP_DIR="/tmp/rdx-installer"

echo -e "${BLUE}🎯 RDX Broadcast Control Center - Smart Installer${NC}"
echo "=============================================================="

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Detect Ubuntu version
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            UBUNTU_VERSION="$VERSION_ID"
            UBUNTU_CODENAME="$VERSION_CODENAME"
            print_info "Detected Ubuntu $UBUNTU_VERSION ($UBUNTU_CODENAME)"
            return 0
        else
            print_error "This installer is designed for Ubuntu systems only"
            print_info "Detected OS: $PRETTY_NAME"
            exit 1
        fi
    else
        print_error "Cannot detect operating system version"
        exit 1
    fi
}

# Detect desktop environment
detect_desktop_environment() {
    print_info "Detecting desktop environment..."
    
    if [ "$XDG_CURRENT_DESKTOP" ]; then
        DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
        print_info "Desktop environment: $DESKTOP_ENV"
        
        if [[ "$DESKTOP_ENV" == *"MATE"* ]]; then
            print_warning "MATE desktop detected - using enhanced launcher compatibility"
        fi
    else
        print_warning "Desktop environment not detected"
    fi
}

# Check if Rivendell is installed
check_rivendell() {
    if [ -f "/etc/rd.conf" ] && [ -f "/usr/bin/rdadmin" ]; then
        print_status "Rivendell installation detected"
        
        # Try to get Rivendell version
        if command -v rdadmin >/dev/null 2>&1; then
            RIVENDELL_VERSION=$(rdadmin --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
            print_info "Rivendell version: $RIVENDELL_VERSION"
        fi
        
        return 0
    else
        print_warning "Rivendell not detected - RDX will install but may have limited functionality"
        return 1
    fi
}

# Check and install dependencies based on Ubuntu version
install_dependencies() {
    print_info "Checking and installing dependencies for Ubuntu $UBUNTU_VERSION..."
    
    # Update package cache
    sudo apt-get update -qq
    
    # Base dependencies for all Ubuntu versions
    DEPS="python3 python3-pyqt5"
    
    # Version-specific adjustments
    case "$UBUNTU_VERSION" in
        "22.04")
            print_info "Using Ubuntu 22.04 (Jammy) dependency set"
            # 22.04 has python3-pyqt5 which includes widgets
            OPTIONAL_DEPS="jackd2 liquidsoap icecast2 qjackctl"
            ;;
        "24.04"|"24.10"|"25."*)
            print_info "Using Ubuntu 24.04+ dependency set"
            # 24.04+ may have separate widget packages, but we stick to main package for compatibility
            OPTIONAL_DEPS="jackd2 liquidsoap icecast2 qjackctl"
            ;;
        *)
            print_warning "Ubuntu version $UBUNTU_VERSION not specifically tested"
            print_info "Using standard dependency set"
            OPTIONAL_DEPS="jackd2 liquidsoap icecast2 qjackctl"
            ;;
    esac
    
    # Install required dependencies
    print_info "Installing required dependencies: $DEPS"
    sudo apt-get install -y $DEPS
    
    # Install optional dependencies (don't fail if not available)
    print_info "Installing recommended dependencies: $OPTIONAL_DEPS"
    for dep in $OPTIONAL_DEPS; do
        if sudo apt-get install -y "$dep" >/dev/null 2>&1; then
            print_status "Installed $dep"
        else
            print_warning "Could not install $dep (optional)"
        fi
    done
}

# Download the appropriate package
download_package() {
    print_info "Downloading RDX Broadcast Control Center..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Get latest release info
    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    
    if [ -z "$LATEST_RELEASE" ]; then
        print_error "Could not determine latest release version"
        exit 1
    fi
    
    print_info "Latest version: $LATEST_RELEASE"
    
    # Construct download URL
    PACKAGE_FILE="${PACKAGE_NAME}_${LATEST_RELEASE#v}_amd64.deb"
    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_RELEASE/$PACKAGE_FILE"
    
    print_info "Downloading: $DOWNLOAD_URL"
    
    if wget -q "$DOWNLOAD_URL"; then
        print_status "Package downloaded successfully"
        echo "$PACKAGE_FILE"
    else
        print_error "Failed to download package"
        exit 1
    fi
}

# Install the package
install_package() {
    local package_file="$1"
    
    print_info "Installing RDX Broadcast Control Center..."
    
    if sudo dpkg -i "$package_file"; then
        print_status "Package installed successfully"
    else
        print_warning "Package installation had issues, attempting to fix dependencies..."
        sudo apt-get install -f -y
        
        if sudo dpkg -i "$package_file"; then
            print_status "Package installed successfully after dependency fix"
        else
            print_error "Failed to install package"
            exit 1
        fi
    fi
}

# Post-installation setup
post_install_setup() {
    print_info "Performing post-installation setup..."
    
    # Create rd user if it doesn't exist
    if ! id "rd" >/dev/null 2>&1; then
        print_info "Creating 'rd' user for broadcast operations..."
        sudo useradd -r -s /bin/bash -d /home/rd -m rd
        print_status "User 'rd' created"
    else
        print_status "User 'rd' already exists"
    fi
    
    # Add rd user to audio and pulse-access groups
    print_info "Configuring user permissions..."
    sudo usermod -a -G audio,pulse-access rd 2>/dev/null || true
    
    # Add sudo permissions for broadcast management
    print_info "Setting up broadcast management permissions..."
    sudo tee /etc/sudoers.d/rdx-broadcast >/dev/null << 'EOSUDO'
# RDX Broadcast Control Center permissions
rd ALL=(root) NOPASSWD: /bin/cp * /etc/icecast2/icecast.xml
rd ALL=(root) NOPASSWD: /usr/bin/systemctl start icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl stop icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl restart icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl status icecast2
rd ALL=(root) NOPASSWD: /usr/bin/systemctl start liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl stop liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl restart liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl status liquidsoap
rd ALL=(root) NOPASSWD: /usr/bin/systemctl start jackd
rd ALL=(root) NOPASSWD: /usr/bin/systemctl stop jackd
rd ALL=(root) NOPASSWD: /usr/bin/systemctl restart jackd
rd ALL=(root) NOPASSWD: /usr/bin/systemctl status jackd
EOSUDO
    
    if [ $? -eq 0 ]; then
        print_status "Broadcast management permissions configured"
    else
        print_warning "Could not configure sudo permissions - manual setup may be required"
    fi
    
    # Set up configuration directory
    if [ ! -d "/home/rd/.config/rdx" ]; then
        sudo mkdir -p /home/rd/.config/rdx
        print_status "Configuration directory created"
    fi
    
    # Fix ownership of rd user directories
    print_info "Setting correct ownership for rd user directories..."
    sudo chown -R rd:rd /home/rd/.config 2>/dev/null || true
    sudo chown -R rd:rd /home/rd 2>/dev/null || true
    
    # Create logs directory
    if [ ! -d "/home/rd/logs" ]; then
        sudo mkdir -p /home/rd/logs
        sudo chown rd:rd /home/rd/logs
        print_status "Logs directory created"
    fi
    
    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        sudo update-desktop-database /usr/share/applications
        print_status "Desktop database updated"
    fi
}

# Main installation process
main() {
    print_info "Starting RDX Broadcast Control Center installation..."
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this installer as root"
        print_info "Run as a regular user with sudo privileges"
        exit 1
    fi
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        print_info "This installer requires sudo privileges"
        sudo -v
    fi
    
    # Detect system information
    detect_ubuntu_version
    detect_desktop_environment
    
    # Detect system
    detect_ubuntu_version
    check_rivendell
    
    # Install dependencies
    install_dependencies
    
    # Download and install package
    package_file=$(download_package)
    install_package "$package_file"
    
    # Post-installation setup
    post_install_setup
    
    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"
    
    echo ""
    print_status "🎉 RDX Broadcast Control Center installed successfully!"
    echo ""
    echo -e "${BLUE}📱 Launch Options:${NC}"
    echo "   • Applications → Sound & Video → 'RDX Broadcast Control Center'"
    if [[ "$DESKTOP_ENV" == *"MATE"* ]]; then
        echo "   • For MATE Desktop: 'RDX Terminal Launcher' (if main launcher fails)"
    fi
    echo "   • Command line: rdx-control-center"
    echo "   • Debug mode: rdx-debug-launcher"
    echo ""
    echo -e "${BLUE}✨ Features Available:${NC}"
    echo "   🎵 Stream Builder (MP3, AAC+, FLAC, OGG, OPUS)"
    echo "   📡 Icecast Management (Complete GUI control)"
    echo "   🔌 JACK Matrix (Visual connections + critical protection)"
    echo "   ⚙️ Service Control (Coordinated broadcast services)"
    echo ""
    
    if [ -f "/etc/rd.conf" ]; then
        echo -e "${GREEN}🎯 Ready for broadcast automation with Rivendell integration!${NC}"
    else
        echo -e "${YELLOW}💡 Install Rivendell for full broadcast automation features${NC}"
    fi
}

# Run main function
main "$@"