# RDX Broadcast Control Center v3.0.4 - MATE Desktop Compatibility

## Version 3.0.4 Release Notes

**Date:** December 2024  
**Focus:** Enhanced MATE Desktop Environment Compatibility

### What's New in v3.0.4

🖥️ **Multiple Desktop Launchers**
- Standard desktop launcher (primary)
- MATE-specific terminal launcher (fallback)
- Debug launcher with comprehensive error reporting
- Command-line launcher with enhanced error handling

🔧 **MATE Desktop Fixes**
- Resolved "An error has occurred" generic failures
- Added terminal-based launcher for MATE compatibility
- Enhanced error logging and diagnostics
- Multiple fallback launch methods

### For Ubuntu 22.04 MATE Users

If you're experiencing desktop launch issues, try these options **in order**:

#### 1. Primary Launcher (Try First)
- **Location:** Applications → Sound & Video → "RDX Broadcast Control Center"
- **File:** `rdx-broadcast-control-center.desktop`
- **Should work** for most MATE installations

#### 2. MATE Terminal Launcher (If #1 Fails)
- **Location:** Applications → Sound & Video → "RDX Terminal Launcher"
- **File:** `rdx-terminal-launcher.desktop`
- **Specifically designed** for MATE desktop compatibility
- Opens in terminal with full error visibility

#### 3. Command Line (Always Works)
```bash
# Standard launch
rdx-control-center

# Debug mode (shows all errors)
DEBUG=1 rdx-control-center

# Direct python execution
python3 /usr/local/bin/rdx-broadcast-control-center.py
```

#### 4. Debug Launcher
- **Location:** Applications → Sound & Video → "RDX Debug Launcher"
- **Purpose:** Comprehensive error reporting and diagnostics

### Installation for v3.0.4

#### Smart Installer (Recommended)
```bash
curl -sSL https://raw.githubusercontent.com/anjeleno/rdx-rivendell/main/install-rdx.sh | bash
```

#### Manual Installation
```bash
# Download latest package
wget https://github.com/anjeleno/rdx-rivendell/releases/latest/download/rdx-broadcast-control-center_3.0.4_amd64.deb

# Install
sudo dpkg -i rdx-broadcast-control-center_3.0.4_amd64.deb
sudo apt-get install -f  # Fix any dependencies
```

### Features Included

✅ **Complete Broadcast Control Center**
- 🎵 Stream Builder (MP3, AAC+, FLAC, OGG, OPUS)
- 📡 Icecast Management (Complete GUI control)
- 🔌 JACK Matrix (Visual connections + critical protection)
- ⚙️ Service Control (Coordinated broadcast services)

✅ **Enhanced Error Handling**
- Comprehensive error logging (`/var/log/rdx-launcher.log`)
- GUI error dialogs when possible
- Terminal fallback for debugging
- Multiple launch methods for compatibility

### Troubleshooting MATE Desktop Issues

#### Problem: "An error has occurred" when clicking desktop icon

**Solution 1:** Use MATE Terminal Launcher
1. Go to Applications → Sound & Video
2. Click "RDX Terminal Launcher" instead
3. Application will launch in terminal with error visibility

**Solution 2:** Launch from terminal
```bash
# See what's actually happening
rdx-control-center
```

**Solution 3:** Check error logs
```bash
# Check system logs
tail -f /var/log/rdx-launcher.log

# Or temporary logs if system log unavailable
tail -f /tmp/rdx-launcher.log
```

#### Problem: Desktop entries not appearing

**Solution:**
```bash
# Refresh desktop database
sudo update-desktop-database
gtk-update-icon-cache -f /usr/share/icons/hicolor/
```

#### Problem: Dependencies missing on Ubuntu 22.04

**Solution:**
```bash
# Force dependency installation
sudo apt-get update
sudo apt-get install -f
sudo apt-get install python3-pyqt5 python3-pyqt5.qtwidgets python3-pyqt5.qtcore python3-pyqt5.qtgui
```

### MATE Desktop Environment Detection

The installer now automatically detects MATE desktop and:
- Provides MATE-specific launch instructions
- Installs additional terminal-based launchers
- Gives enhanced troubleshooting guidance

### Version History

- **v3.0.0:** Complete blueprint implementation
- **v3.0.1:** Ubuntu 22.04 compatibility fixes
- **v3.0.2:** Smart installer integration
- **v3.0.3:** Desktop launch failure fixes
- **v3.0.4:** MATE desktop compatibility + multiple launchers

### Support

If you continue to experience issues:

1. **Try all launch methods** listed above
2. **Check error logs** for specific error messages
3. **Run in debug mode** to see detailed output
4. **Verify dependencies** are properly installed

The RDX Broadcast Control Center is fully functional - these are just launcher compatibility issues with MATE desktop environment.

---

**RDX v3.0.4 - Professional Broadcast Control for Ubuntu MATE** 🎵📡🔌⚙️