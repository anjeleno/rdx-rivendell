#!/bin/bash
# RDX Broadcast Control Center Package Builder v3.0.0
# Creates comprehensive broadcast automation package

set -e

# Package information
PACKAGE_NAME="rdx-broadcast-control-center"
PACKAGE_VERSION="3.0.0"
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
mkdir -p "$PACKAGE_DIR/home/rd/.config/rdx"

# Copy main application
echo "📋 Installing main application..."
cp "$RDX_ROOT/src/rdx-broadcast-control-center.py" "$PACKAGE_DIR/usr/local/bin/"
chmod +x "$PACKAGE_DIR/usr/local/bin/rdx-broadcast-control-center.py"

# Copy desktop entry
echo "🖥️ Installing desktop integration..."
cp "$RDX_ROOT/rdx-broadcast-control-center.desktop" "$PACKAGE_DIR/usr/share/applications/"

# Create wrapper script for easier launching
cat > "$PACKAGE_DIR/usr/local/bin/rdx-control-center" << 'EOF'
#!/bin/bash
# RDX Broadcast Control Center Launcher

export DISPLAY=${DISPLAY:-:0}
cd /home/rd
exec python3 /usr/local/bin/rdx-broadcast-control-center.py "$@"
EOF
chmod +x "$PACKAGE_DIR/usr/local/bin/rdx-control-center"

# Create configuration directory with examples
echo "⚙️ Setting up configuration..."

# Example Liquidsoap config
cat > "$PACKAGE_DIR/home/rd/.config/rdx/radio.liq.example" << 'EOF'
#!/usr/bin/liquidsoap
# RDX Generated Liquidsoap Configuration
# Edit this file through RDX Broadcast Control Center

set("log.file.path", "/home/rd/logs/soap.log")
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
  radio
)
EOF

# Example Icecast config
cat > "$PACKAGE_DIR/home/rd/.config/rdx/icecast.xml.example" << 'EOF'
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
- Examples: \`/usr/share/doc/$PACKAGE_NAME/\`

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
Depends: python3 (>= 3.6), python3-pyqt5, python3-pyqt5.qtwidgets
Recommends: jackd2, liquidsoap, icecast2, qjackctl
Suggests: stereo-tool
Description: $DESCRIPTION
 Professional broadcast control center providing complete GUI management
 for streaming, icecast configuration, JACK audio routing, and service
 orchestration. Includes stream builder with multiple codecs, visual
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
        # Create rd user if it doesn't exist
        if ! id "rd" >/dev/null 2>&1; then
            useradd -r -s /bin/bash -d /home/rd -m rd
            echo "Created user 'rd' for Rivendell/RDX operations"
        fi
        
        # Set up configuration directory
        if [ ! -d "/home/rd/.config/rdx" ]; then
            mkdir -p /home/rd/.config/rdx
            chown rd:rd /home/rd/.config/rdx
        fi
        
        # Create logs directory
        if [ ! -d "/home/rd/logs" ]; then
            mkdir -p /home/rd/logs
            chown rd:rd /home/rd/logs
        fi
        
        # Set permissions
        chown rd:rd /home/rd/.config/rdx/* 2>/dev/null || true
        
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
        echo "User configurations preserved in /home/rd/.config/rdx/"
        ;;
        
    purge)
        # Remove configuration files on purge
        rm -rf /home/rd/.config/rdx 2>/dev/null || true
        echo "RDX Broadcast Control Center purged completely."
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
FINAL_PACKAGE="$RDX_ROOT/deb-builds/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCHITECTURE}.deb"
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