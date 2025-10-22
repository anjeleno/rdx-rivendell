#!/bin/bash
# RDX Broadcast Control Center Package Builder v3.0
# Creates comprehensive broadcast automation package

set -e

# Package information
PACKAGE_NAME="rdx-broadcast-control-center"
PACKAGE_VERSION="3.2.18"
ARCHITECTURE="amd64"
MAINTAINER="RDX Development Team <rdx@example.com>"
DESCRIPTION="RDX Professional Broadcast Control Center - Complete GUI for streaming, icecast, JACK, and service management"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RDX_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/tmp/rdx-broadcast-center-build"
PACKAGE_DIR="${BUILD_DIR}/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"

echo "🎯 RDX Broadcast Control Center Package Builder v${PACKAGE_VERSION}"
echo "=================================================================="

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$PACKAGE_DIR"

# Create package directory structure
echo "📁 Creating package structure..."
mkdir -p "$PACKAGE_DIR/DEBIAN"
mkdir -p "$PACKAGE_DIR/usr/local/bin"
mkdir -p "$PACKAGE_DIR/usr/share/applications"
mkdir -p "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME"
mkdir -p "$PACKAGE_DIR/etc/systemd/system"
mkdir -p "$PACKAGE_DIR/etc/skel/.config/rdx"

# Copy main application
echo "📋 Installing main application..."
cp "$RDX_ROOT/src/rdx-broadcast-control-center.py" "$PACKAGE_DIR/usr/local/bin/"
chmod +x "$PACKAGE_DIR/usr/local/bin/rdx-broadcast-control-center.py"

# Copy desktop entries
echo "🖥️ Installing desktop integration..."
cp "$RDX_ROOT/rdx-broadcast-control-center.desktop" "$PACKAGE_DIR/usr/share/applications/"
cp "$RDX_ROOT/rdx-debug-launcher.desktop" "$PACKAGE_DIR/usr/share/applications/"
cp "$RDX_ROOT/rdx-terminal-launcher.desktop" "$PACKAGE_DIR/usr/share/applications/"

# Create wrapper script for easier launching with error handling
cat > "$PACKAGE_DIR/usr/local/bin/rdx-control-center" << 'EOF'
#!/bin/bash
# RDX Broadcast Control Center Launcher with Error Handling

# Enable debug mode if DEBUG=1
if [ "$DEBUG" = "1" ]; then
    set -x
fi

# Function to log errors
log_error() {
    echo "$(date): $1" >> /var/log/rdx-launcher.log 2>/dev/null || \
    echo "$(date): $1" >> /tmp/rdx-launcher.log
}

# Function to show error dialog if GUI available
show_error() {
    local message="$1"
    log_error "$message"
    
    # Try to show GUI error dialog
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --text="RDX Error: $message" 2>/dev/null &
    elif command -v kdialog >/dev/null 2>&1; then
        kdialog --error "$message" 2>/dev/null &
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "RDX Error" "$message" 2>/dev/null &
    fi
    
    # Also print to stderr
    echo "ERROR: $message" >&2
}

# Check if running in GUI environment
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
    log_error "No DISPLAY set, defaulting to :0"
fi

# Test if DISPLAY is accessible (skip strict X11 check on Wayland or when xset is unavailable)
if [ "${XDG_SESSION_TYPE}" != "wayland" ] && command -v xset >/dev/null 2>&1; then
    if ! xset q >/dev/null 2>&1; then
        log_error "X11 display not accessible via xset; proceeding anyway."
        # Do not exit here; allow PyQt to attempt to initialize the display
    fi
fi

# Check Python3 availability
if ! command -v python3 >/dev/null 2>&1; then
    show_error "Python3 not found. Please install python3."
    exit 1
fi

# Check PyQt5 availability
if ! python3 -c "import PyQt5" >/dev/null 2>&1; then
    show_error "PyQt5 not available. Please install python3-pyqt5."
    exit 1
fi

# Check if main script exists
if [ ! -f "/usr/local/bin/rdx-broadcast-control-center.py" ]; then
    show_error "RDX application file not found. Please reinstall RDX."
    exit 1
fi

# Change to invoking user's home directory (do not assume specific user)
cd "$HOME" 2>/dev/null || cd /tmp

# Launch with error capture
log_error "Starting RDX Broadcast Control Center"

# Try to launch and capture any Python errors
if ! python3 /usr/local/bin/rdx-broadcast-control-center.py "$@" 2>/tmp/rdx-python-error.log; then
    PYTHON_ERROR=$(cat /tmp/rdx-python-error.log 2>/dev/null || echo "Unknown Python error")
    show_error "Failed to start RDX: $PYTHON_ERROR"
    exit 1
fi
EOF
chmod +x "$PACKAGE_DIR/usr/local/bin/rdx-control-center"

# Create debug launcher
cat > "$PACKAGE_DIR/usr/local/bin/rdx-control-center-debug" << 'EOF'
#!/bin/bash
# RDX Debug Launcher - Shows all errors in terminal

echo "🔍 RDX Debug Launcher"
echo "===================="

# Export debug mode
export DEBUG=1

# Check environment
echo "🖥️  Display: $DISPLAY"
echo "🐍 Python: $(python3 --version 2>&1)"
echo "📦 PyQt5: $(python3 -c 'import PyQt5; print("Available")' 2>&1)"
echo "🏠 Home: $HOME"
echo "👤 User: $(whoami)"
echo ""

# Run with debug output
exec /usr/local/bin/rdx-control-center "$@"
EOF
chmod +x "$PACKAGE_DIR/usr/local/bin/rdx-control-center-debug"

# Create configuration directory with examples
echo "⚙️ Setting up configuration templates (skel)..."

# Example Liquidsoap config
cat > "$PACKAGE_DIR/etc/skel/.config/rdx/radio.liq.example" << 'EOF'
#!/usr/bin/liquidsoap
# RDX Generated Liquidsoap Configuration
# Edit this file through RDX Broadcast Control Center

set("log.file.path", "/tmp/soap.log")
set("frame.audio.samplerate", 48000)
set("icy.metadata", true)

# JACK input
radio = input.jack(id="liquidsoap")
radio = mksafe(radio)

# Example streams (configure through GUI)
# MP3 320kbps
output.icecast(
    %mp3(bitrate=320),
    host="localhost",
    port=8000,
    password="hackm3",
    mount="/mp3-320",
    genre="Broadcast",
    name="Station Name - MP3 320",
    source=radio
)
EOF

# Example Icecast config
cat > "$PACKAGE_DIR/etc/skel/.config/rdx/icecast.xml.example" << 'EOF'
<icecast>
    <location>Broadcast Station</location>
    <admin>admin@localhost</admin>

    <limits>
        <clients>100</clients>
        <sources>10</sources>
        <queue-size>524288</queue-size>
        <client-timeout>30</client-timeout>
        <header-timeout>15</header-timeout>
        <source-timeout>10</source-timeout>
        <burst-on-connect>1</burst-on-connect>
        <burst-size>65535</burst-size>
    </limits>

    <authentication>
        <source-password>hackm3</source-password>
        <relay-password>hackm33</relay-password>
        <admin-user>admin</admin-user>
        <admin-password>Hackm333</admin-password>
    </authentication>

    <hostname>localhost</hostname>

    <listen-socket>
        <port>8000</port>
    </listen-socket>

    <http-headers>
        <header name="Access-Control-Allow-Origin" value="*" />
    </http-headers>

    <paths>
        <basedir>/usr/share/icecast2</basedir>
        <logdir>/var/log/icecast2</logdir>
        <webroot>/usr/share/icecast2/web</webroot>
        <adminroot>/usr/share/icecast2/admin</adminroot>
        <alias source="/" destination="/status.xsl"/>
    </paths>

    <logging>
        <accesslog>access.log</accesslog>
        <errorlog>error.log</errorlog>
        <loglevel>3</loglevel>
        <logsize>10000</logsize>
    </logging>

    <security>
        <chroot>0</chroot>
    </security>
</icecast>
EOF

# Create README
cat > "$PACKAGE_DIR/usr/share/doc/$PACKAGE_NAME/README.md" << EOF
# RDX Broadcast Control Center v$PACKAGE_VERSION

## Overview
Professional broadcast automation control center providing complete GUI management for:
- Stream building (MP3, AAC+, FLAC, OGG, OPUS)
- Icecast server configuration and management
- JACK audio connection matrix with critical connection protection
- Service orchestration (JACK, Stereo Tool, Liquidsoap, Icecast)

## Installation
\`\`\`bash
sudo dpkg -i ${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb
sudo apt-get install -f  # Install dependencies if needed
\`\`\`

## Configuration Deployment
Icecast configurations are managed by the application and stored per-user:
\`\`\`bash
# Configuration files are saved to ~/.config/rdx/
# Manage generation and deployment from the GUI
\`\`\`

## Usage
### GUI Launch
- **Applications → Sound & Video → "🎯 RDX Broadcast Control Center"**
- Or run: \`rdx-control-center\`

### Command Line
\`\`\`bash
python3 /usr/local/bin/rdx-broadcast-control-center.py
\`\`\`

## Features

### Tab 1: Stream Builder 🎵
- Codec dropdowns (MP3, AAC+, FLAC, OGG, OPUS)
- Bitrate/quality selection
- Custom mount point configuration
- Add/remove streams
- Generate Liquidsoap configuration
- Apply to Icecast

### Tab 2: Icecast Management 📡
- Server settings (host, port, passwords)
- Mount point management
- Service control (start/stop/restart)
- Configuration generation and application

### Tab 3: JACK Matrix 🔌
- Visual connection matrix
- Critical connection protection
- Auto-connect functionality
- Emergency disconnect

### Tab 4: Service Control ⚙️
- Individual service management
- Master controls (start/stop all)
- Emergency stop
- Service dependency management

## Configuration
- User configs: \`~/.config/rdx/\`
- Examples for new users: \`/etc/skel/.config/rdx/\`
- Documentation: \`/usr/share/doc/$PACKAGE_NAME/\`

## Requirements
- Python 3.6+
- PyQt5
- JACK Audio Connection Kit
- Liquidsoap (for streaming)
- Icecast2 (for stream serving)

## Support
Complete broadcast automation solution for professional radio stations.
EOF

# Create DEBIAN control file
cat > "$PACKAGE_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: sound
Priority: optional
Architecture: $ARCHITECTURE
Maintainer: $MAINTAINER
Depends: python3 (>= 3.6), python3-pyqt5, liquidsoap (>= 2.0.0)
Recommends: liquidsoap-plugin-ffmpeg | liquidsoap-plugin-all | liquidsoap-plugin-extra, jackd2, icecast2, qjackctl
Suggests: stereo-tool
Description: $DESCRIPTION
 Professional broadcast streaming center providing complete GUI management
 for streaming, icecast configuration, JACK audio routing, and service
 orchestration. Includes smart stream builder with multiple codecs, visual
 JACK connection matrix with critical connection protection, and
 comprehensive service management.
 .
 Features:
  * Stream Builder: MP3, AAC+, FLAC, OGG, OPUS with custom mount points
  * Icecast Management: Complete server configuration and control
  * JACK Matrix: Visual connections with critical protection
  * Service Control: Coordinated management of broadcast services
 .
 Perfect for professional radio stations requiring reliable broadcast
 automation with intuitive GUI control.
EOF

# Create postinst script
cat > "$PACKAGE_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    configure)
        # Attempt to ensure Liquidsoap FFmpeg plugin is available automatically
        if command -v liquidsoap >/dev/null 2>&1; then
            # If ffmpeg encoder help shows missing, try install
            if ! liquidsoap -h encoder.ffmpeg >/dev/null 2>&1 || liquidsoap -h encoder.ffmpeg 2>&1 | grep -qi "Plugin not found"; then
                echo "[postinst] Ensuring Liquidsoap FFmpeg plugin is installed..."
                if command -v /usr/share/rdx/install-liquidsoap-plugin.sh >/dev/null 2>&1; then
                    # First try current repos; on failure, try official repo path
                    /usr/share/rdx/install-liquidsoap-plugin.sh current || /usr/share/rdx/install-liquidsoap-plugin.sh official || true
                fi
            fi
        fi

        # Ensure skeleton examples are in place for new users
        if [ -d "/etc/skel/.config/rdx" ]; then
            chmod 755 /etc/skel/.config /etc/skel/.config/rdx 2>/dev/null || true
            find /etc/skel/.config/rdx -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi

        # Initialize configuration directory for all existing human users (UID >= 1000)
        while IFS=: read -r name passwd uid gid gecos home shell; do
            if [ "$uid" -ge 1000 ] && [ -d "$home" ] && [ -w "$home" ] && [[ "$shell" != *"nologin"* ]] && [[ "$shell" != *"false"* ]]; then
                # Create ~/.config/rdx with proper ownership and permissions
                install -d -m 755 -o "$name" -g "$name" "$home/.config/rdx"
                # Seed example files if available (do not overwrite existing files)
                if [ -d "/etc/skel/.config/rdx" ]; then
                    cp -n /etc/skel/.config/rdx/* "$home/.config/rdx/" 2>/dev/null || true
                fi
                chown -R "$name":"$name" "$home/.config/rdx" 2>/dev/null || true
            fi
        done < <(getent passwd)
        
        # Update desktop database
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database /usr/share/applications
        fi
        
        echo "🎯 RDX Broadcast Control Center installed successfully!"
        echo "Launch from: Applications → Sound & Video → RDX Broadcast Control Center"
        echo "Or run: rdx-control-center"
        ;;
esac

exit 0
EOF
chmod +x "$PACKAGE_DIR/DEBIAN/postinst"

# Helper script to install Liquidsoap ffmpeg plugin (with optional repo enablement)
install -d "$PACKAGE_DIR/usr/share/rdx"
cat > "$PACKAGE_DIR/usr/share/rdx/install-liquidsoap-plugin.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-current}"

log() { echo "[rdx-install] $*"; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

try_install_plugins_from_current() {
    local pkgs=(liquidsoap-plugin-ffmpeg liquidsoap-plugin-all liquidsoap-plugin-extra)
    local ok=1
    for p in "${pkgs[@]}"; do
        if apt-get -s install "$p" >/dev/null 2>&1; then
            log "Attempting to install $p"
            apt_install "$p" && ok=0 && break || true
        fi
    done
    return $ok
}

add_official_repo() {
    if have_cmd add-apt-repository; then
        :
    else
        apt_install software-properties-common || true
    fi
    if have_cmd add-apt-repository; then
        log "Enabling official Liquidsoap PPA (savonet/ppa)"
        add-apt-repository -y ppa:savonet/ppa || true
    else
        log "add-apt-repository not available; skipping PPA enable."
    fi
    apt-get update || true
}

add_vendor_repo() {
    # Placeholder: vendor repository details not configured.
    log "Vendor repo not configured. Skipping."
}

check_ffmpeg_plugin() {
    if ! command -v liquidsoap >/dev/null 2>&1; then
        return 1
    fi
    out=$(liquidsoap -h encoder.ffmpeg 2>&1 || true)
    echo "$out" | grep -qi 'plugin not found' && return 1
    # If command failed return code, also consider missing
    liquidsoap -h encoder.ffmpeg >/dev/null 2>&1
}

main() {
    if ! command -v apt-get >/dev/null 2>&1; then
        log "apt-get not found; cannot install packages automatically"
        exit 1
    fi
    # Ensure apt cache is fresh
    apt-get update || true

    if check_ffmpeg_plugin; then
        log "FFmpeg plugin already available."
        exit 0
    fi

    case "$MODE" in
        current)
            try_install_plugins_from_current || exit 1
            ;;
        official)
            try_install_plugins_from_current || { add_official_repo; try_install_plugins_from_current || exit 1; }
            ;;
        vendor)
            try_install_plugins_from_current || { add_vendor_repo; try_install_plugins_from_current || exit 1; }
            ;;
        *)
            log "Unknown mode: $MODE"
            exit 1
            ;;
    esac

    if check_ffmpeg_plugin; then
        log "FFmpeg plugin installed successfully."
        exit 0
    else
        log "FFmpeg plugin still missing after install attempts."
        exit 2
    fi
}

main "$@"
EOF
chmod +x "$PACKAGE_DIR/usr/share/rdx/install-liquidsoap-plugin.sh"

# Create prerm script
cat > "$PACKAGE_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    remove|upgrade|deconfigure)
        # Stop any running services gracefully
        echo "Stopping RDX services..."
        ;;
esac

exit 0
EOF
chmod +x "$PACKAGE_DIR/DEBIAN/prerm"

# Create postrm script
cat > "$PACKAGE_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    remove)
        # Update desktop database
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database /usr/share/applications
        fi
        
        echo "RDX Broadcast Control Center removed."
        echo "User configurations preserved in ~/.config/rdx/"
        ;;
        
    purge)
        # Remove configuration templates on purge (do not touch user homes)
        rm -rf /etc/skel/.config/rdx 2>/dev/null || true
        echo "RDX Broadcast Control Center purged completely (skeleton examples removed)."
        ;;
esac

exit 0
EOF
chmod +x "$PACKAGE_DIR/DEBIAN/postrm"

# Set permissions
echo "🔒 Setting permissions..."
find "$PACKAGE_DIR" -type d -exec chmod 755 {} \;
find "$PACKAGE_DIR" -type f -exec chmod 644 {} \;
chmod +x "$PACKAGE_DIR/usr/local/bin/"*
chmod +x "$PACKAGE_DIR/DEBIAN/"*

# Build the package
echo "📦 Building package..."
cd "$BUILD_DIR"
dpkg-deb --build "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}"

# Move to final location
FINAL_PACKAGE="$RDX_ROOT/releases/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
mkdir -p "$(dirname "$FINAL_PACKAGE")"
mv "${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb" "$FINAL_PACKAGE"

# Get package size
PACKAGE_SIZE=$(du -h "$FINAL_PACKAGE" | cut -f1)

echo ""
echo "🎉 SUCCESS! RDX Broadcast Control Center package built!"
echo "📦 Package: $FINAL_PACKAGE"
echo "📊 Size: $PACKAGE_SIZE"
echo ""
echo "🚀 Installation:"
echo "   sudo dpkg -i \"$FINAL_PACKAGE\""
echo "   sudo apt-get install -f  # If dependencies needed"
echo ""
echo "🎯 Launch:"
echo "   Applications → Sound & Video → RDX Broadcast Control Center"
echo "   Or run: rdx-control-center"
echo ""
echo "✨ Features:"
echo "   🎵 Stream Builder (MP3, AAC+, FLAC, OGG, OPUS)"
echo "   📡 Icecast Management (Complete GUI control)"
echo "   🔌 JACK Matrix (Visual connections + critical protection)"
echo "   ⚙️ Service Control (Coordinated broadcast services)"

# Clean up build directory
rm -rf "$BUILD_DIR"