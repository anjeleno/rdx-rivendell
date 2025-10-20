# RDX Dependency Matrix
# Complete breakdown of dependencies for RDX functionality

## 🏗️ CORE DEPENDENCIES (Required for RDX to function)

### Build-Time Dependencies
- **build-essential** (gcc, g++, make) - Compiling C++ code
- **cmake** (>= 3.16) - Build system
- **pkg-config** - Library discovery during build

### Runtime Dependencies  
- **Qt5 Core & DBus** - Service architecture and inter-process communication
  - libqt5core5a
  - libqt5dbus5
- **JACK Audio** - Core audio routing functionality
  - libjack-jackd2-0 (or libjack0)
  - jackd2 (JACK daemon)
- **ALSA** - Hardware audio device detection
  - libasound2
- **D-Bus** - System service communication
  - dbus
  - libdbus-1-3

### System Integration
- **systemd** - Service management (auto-start, dependencies)
- **sudo** - Privileged operations during installation

## 🎵 BROADCAST STACK (Optional - Detected & Managed)

### Audio Processing
- **Stereo Tool** - Professional audio processing
  - Status: External binary (downloaded/provided by user)
  - Detection: Command availability + executable permissions
  - Management: Auto-startup, process monitoring, graceful shutdown
  
- **JACK Rack** - Plugin host for LADSPA/LV2 effects
  - Package: jack-rack
  - Detection: `which jack-rack`
  - Management: Profile-based plugin loading

### Streaming Software
- **Liquidsoap** - Advanced streaming automation
  - Package: liquidsoap, liquidsoap-plugin-all
  - Detection: `liquidsoap --version`
  - Management: Script validation, auto-restart, config generation
  
- **Icecast2** - Streaming server
  - Package: icecast2
  - Detection: `systemctl status icecast2` or `which icecast2`
  - Management: Config generation, service orchestration

### Alternative Encoders (User Choice)
- **DarkIce** - Simple JACK→Icecast streaming
  - Package: darkice
  - Use Case: Lightweight streaming without scripting
  
- **GlassCoder** - Multi-format encoder (MP3, AAC, Opus)
  - Package: glasscoder (or build from source)
  - Use Case: Advanced codec support, multiple streams
  
- **BUTT** (Broadcast Using This Tool) - Simple streaming client
  - Package: butt or manual install
  - Use Case: Remote broadcast streaming

### Media Players & Tools
- **VLC** - Media player with JACK support
  - Package: vlc, vlc-plugin-jack
  - Detection: `which vlc` + JACK plugin availability
  - Management: Auto-routing when detected
  
## 🔍 DETECTION & MANAGEMENT STRATEGY

### 1. Runtime Detection (Smart Discovery)
```bash
# Command-based detection
command -v liquidsoap &> /dev/null && echo "Liquidsoap available"

# Service-based detection  
systemctl is-active icecast2 &> /dev/null && echo "Icecast2 running"

# Binary + configuration detection
[ -f "/usr/local/bin/stereo_tool_gui_jack_64" ] && echo "Stereo Tool installed"

# JACK client detection (real-time)
jack_lsp | grep -i "liquidsoap\|vlc\|darkice" && echo "JACK clients active"
```

### 2. Installation Options (User Choice)
- **Detect Existing**: Use whatever user already has installed
- **Offer Alternatives**: Present options (DarkIce vs GlassCoder vs Liquidsoap)
- **Recommend Stack**: Suggest tested combinations
- **Minimal Install**: Just core RDX functionality

### 3. Configuration Management
- **Preserve Existing**: Don't overwrite user configurations
- **Enhance Existing**: Add RDX integration to current setup
- **Create New**: Generate optimized configs for new installs
- **Profile-Based**: Different configs for different use cases

## 📦 INSTALLATION MATRICES

### Matrix 1: Existing Rivendell System
```
Detected: Liquidsoap + Icecast2 + VLC
Action: Enhance existing setup with RDX intelligence
Config: Integrate with current radio.liq, preserve Icecast config
```

### Matrix 2: Clean Installation  
```
Options Presented:
- Lightweight: DarkIce + Icecast2
- Professional: Liquidsoap + Icecast2 + Stereo Tool
- Multi-Stream: GlassCoder + Multiple endpoints
User Choice: Professional
Action: Install recommended stack + configure for RDX
```

### Matrix 3: Development/Testing
```
Install: Core RDX + VLC + basic JACK tools
Skip: Heavy processing (Stereo Tool)
Purpose: Testing routing logic without broadcast complexity
```

## 🎛️ DEPENDENCY LEVELS

### Level 1: RDX Core (Always Required)
- Qt5, JACK, ALSA, D-Bus, systemd
- **Size**: ~50MB
- **Function**: Basic intelligent routing

### Level 2: Basic Broadcasting (Optional)
- + Icecast2, VLC, basic JACK tools
- **Size**: +100MB  
- **Function**: Simple streaming capability

### Level 3: Professional Broadcasting (Recommended)
- + Liquidsoap, Stereo Tool, advanced tools
- **Size**: +200MB
- **Function**: Full broadcast automation

### Level 4: Multi-Format Streaming (Advanced)
- + GlassCoder, DarkIce, multiple encoders
- **Size**: +150MB
- **Function**: Multiple streams, codec flexibility

## 🔧 CURRENT IMPLEMENTATION STATUS

✅ **Already Implemented in install-rdx.sh:**
- Smart detection of all major broadcast tools
- Interactive selection with user preferences  
- Auto-install mode for unattended setup
- Preservation of existing configurations
- Alternative encoder options (DarkIce vs GlassCoder)

✅ **Already Working:**
- Runtime detection and integration
- Service orchestration based on detected tools
- Profile adaptation to available software
- Critical connection protection regardless of stack