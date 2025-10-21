#!/bin/bash
# RDX Package Builder
# Creates deployment packages with smart installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="/tmp/rdx-deployment-$(date +%Y%m%d-%H%M%S)"
VERSION="2.0.0"

echo "=== RDX Package Builder v$VERSION ==="
echo

# Create package directory
mkdir -p "$PACKAGE_DIR"
echo "Creating package at: $PACKAGE_DIR"

# Copy built executables
if [[ -f "$SCRIPT_DIR/build-enhanced/src/rdx-jack/rdx-jack-helper" ]]; then
    cp "$SCRIPT_DIR/build-enhanced/src/rdx-jack/rdx-jack-helper" "$PACKAGE_DIR/"
    echo "✓ Copied rdx-jack-helper"
else
    echo "✗ rdx-jack-helper not found - run build first"
    exit 1
fi

# Copy AAC streaming tools
if [[ -f "$SCRIPT_DIR/src/rdx-jack/rdx-aac-stream.sh" ]]; then
    cp "$SCRIPT_DIR/src/rdx-jack/rdx-aac-stream.sh" "$PACKAGE_DIR/"
    echo "✓ Copied AAC+ streaming tools"
else
    echo "✗ AAC streaming tools not found"
fi

# Copy systemd service if available
if [[ -f "$SCRIPT_DIR/build-enhanced/src/rdx-jack/rdx-jack-helper.service" ]]; then
    cp "$SCRIPT_DIR/build-enhanced/src/rdx-jack/rdx-jack-helper.service" "$PACKAGE_DIR/"
    echo "✓ Copied systemd service"
fi

# Copy smart installer
cp "$SCRIPT_DIR/smart-install.sh" "$PACKAGE_DIR/"
echo "✓ Copied smart installer"

# Copy documentation
if [[ -f "$SCRIPT_DIR/AAC_STREAMING_GUIDE.md" ]]; then
    cp "$SCRIPT_DIR/AAC_STREAMING_GUIDE.md" "$PACKAGE_DIR/"
    echo "✓ Copied documentation"
fi

# Create README for the package
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# RDX Rivendell Enhancement Package

## Smart Installation

This package includes an intelligent installer that automatically detects and installs missing dependencies on target Rivendell systems.

### Quick Install (Recommended)
```bash
sudo ./smart-install.sh
```

### Installation Options
```bash
# Interactive installation (default)
sudo ./smart-install.sh

# Automatic installation (no prompts)
sudo ./smart-install.sh -y

# Preview what would be installed
sudo ./smart-install.sh -d

# Force install even with missing dependencies
sudo ./smart-install.sh -f

# Skip dependency installation
sudo ./smart-install.sh -s
```

### Manual Installation
If you prefer manual installation:
```bash
# Copy executables
sudo cp rdx-jack-helper /usr/local/bin/
sudo cp rdx-aac-stream.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/rdx-*
sudo ln -sf /usr/local/bin/rdx-aac-stream.sh /usr/local/bin/rdx-aac-stream

# Install systemd service (optional)
sudo cp rdx-jack-helper.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable rdx-jack-helper
```

## Features

### Intelligent JACK Management
- `rdx-jack-helper` - Professional audio routing and management

### AAC+ Streaming
- `rdx-aac-stream` - Professional HE-AAC streaming
- Multiple quality profiles (HE-AAC v1/v2, LC-AAC)
- Automatic reconnection and monitoring

## Requirements

The smart installer will automatically detect and install:
- Qt5 development libraries
- Audio system libraries (JACK, ALSA, PulseAudio)
- Multimedia codecs (FFmpeg, Vorbis, FLAC, etc.)
- Build tools and dependencies

## Compatibility

- Ubuntu 20.04+ / Debian 11+
- Existing Rivendell installation required
- Builds against your current Rivendell version for maximum compatibility

## Support

See `AAC_STREAMING_GUIDE.md` for detailed usage instructions and examples.
EOF

echo "✓ Created package README"

# Create installation verification script
cat > "$PACKAGE_DIR/verify-install.sh" << 'EOF'
#!/bin/bash
# Verify RDX installation

echo "=== RDX Installation Verification ==="
echo

# Check tools
for tool in rdx-jack-helper rdx-aac-stream; do
    if command -v "$tool" >/dev/null 2>&1; then
        version=$($tool --version 2>/dev/null || $tool -h 2>&1 | head -1 || echo "Unknown")
        echo "✓ $tool: $version"
    else
        echo "✗ $tool: Not found"
    fi
done

# Check FFmpeg for AAC+ support
if command -v ffmpeg >/dev/null 2>&1; then
    echo "✓ FFmpeg: Available for AAC+ encoding"
else
    echo "✗ FFmpeg: Not available (AAC+ streaming disabled)"
fi

# Check Rivendell integration
if find /usr/lib /usr/local/lib -name "librd.so*" 2>/dev/null | head -1 >/dev/null; then
    echo "✓ Rivendell: Integration libraries found"
else
    echo "✗ Rivendell: Libraries not found (limited functionality)"
fi

# Check systemd service
if [[ -f "/etc/systemd/system/rdx-jack-helper.service" ]]; then
    status=$(systemctl is-active rdx-jack-helper 2>/dev/null || echo "inactive")
    echo "✓ RDX Service: $status"
else
    echo "- RDX Service: Not installed"
fi

echo
echo "Installation verification complete."
EOF

chmod +x "$PACKAGE_DIR/verify-install.sh"
echo "✓ Created verification script"

# Create package info
cat > "$PACKAGE_DIR/PACKAGE_INFO.txt" << EOF
RDX Rivendell Enhancement Package
Version: $VERSION
Built on: $(date)
Built from: $(hostname)
Rivendell version: $(rdadmin --version 2>/dev/null | head -1 || echo "Unknown")
Package contents:
$(ls -la "$PACKAGE_DIR" | tail -n +2)
EOF

echo "✓ Created package info"

# Create compressed package
PACKAGE_TAR="/tmp/rdx-rivendell-enhancement-v${VERSION}.tar.gz"
cd "$(dirname "$PACKAGE_DIR")"
tar -czf "$PACKAGE_TAR" "$(basename "$PACKAGE_DIR")"

echo
echo "========================="
echo "PACKAGE CREATED SUCCESS"
echo "========================="
echo "Package directory: $PACKAGE_DIR"
echo "Compressed package: $PACKAGE_TAR"
echo "Size: $(du -sh "$PACKAGE_TAR" | cut -f1)"
echo
echo "To deploy on target system:"
echo "1. Copy $PACKAGE_TAR to target machine"
echo "2. Extract: tar -xzf rdx-rivendell-enhancement-v${VERSION}.tar.gz"
echo "3. Run: sudo ./smart-install.sh"
echo
echo "The smart installer will automatically detect and install all dependencies!"