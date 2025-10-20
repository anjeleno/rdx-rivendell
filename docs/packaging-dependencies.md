# RDX Debian Package Control Specification
# Defines dependency relationships for professional packaging

## Primary Package: rdx-rivendell

### Control File Template
```
Package: rdx-rivendell
Version: 1.0.0
Section: sound
Priority: optional
Architecture: amd64
Essential: no
Installed-Size: 2048

# HARD DEPENDENCIES (Package won't install without these)
Depends: 
    rivendell (>= 4.0.0),
    libc6 (>= 2.34),
    libqt5core5a (>= 5.15.0),
    libqt5dbus5 (>= 5.15.0),
    libjack-jackd2-0 | libjack0,
    jackd2,
    libasound2 (>= 1.2.0),
    libdbus-1-3,
    systemd

# RECOMMENDED (Installed by default, but removable)
Recommends:
    vlc,
    vlc-plugin-jack,
    liquidsoap (>= 2.0.0),
    icecast2

# SUGGESTED (Available for installation, not installed by default)
Suggests:
    rdx-broadcast-essentials,
    rdx-professional-stack,
    rdx-multi-stream-tools

# CONFLICTS (Packages that cause problems)
Conflicts:
    pulseaudio-module-jack

Maintainer: RDX Development Team
Description: Intelligent audio routing system for Rivendell
 RDX (Rivendell Extended) provides broadcast-grade intelligent audio routing
 with critical connection protection. Automatically detects and manages JACK
 audio connections, processing chains, and streaming services.
 .
 Features:
  * Smart hardware detection (audio processors, streamers, inputs)
  * Automatic audio routing with conflict prevention
  * Critical connection protection for live broadcast safety
  * Profile-based service orchestration
  * Real-time monitoring and adaptation
 .
 This package provides the core RDX functionality. Additional broadcast
 tools can be installed via companion packages or manually.
```

## Companion Packages (Optional Stacks)

### rdx-broadcast-essentials
```
Package: rdx-broadcast-essentials
Depends: rdx-rivendell, liquidsoap, icecast2, vlc, vlc-plugin-jack
Description: Essential broadcast stack for RDX
 Installs the recommended minimal broadcast stack for RDX:
 Liquidsoap for streaming automation, Icecast2 for streaming server,
 and VLC with JACK support for media playback.
```

### rdx-professional-stack  
```
Package: rdx-professional-stack
Depends: rdx-broadcast-essentials, darkice, butt
Recommends: stereo-tool, glasscoder
Description: Professional broadcast tools for RDX
 Complete professional broadcast stack including multiple streaming
 encoders and audio processing tools. Suitable for professional
 radio stations and broadcast facilities.
```

### rdx-multi-stream-tools
```
Package: rdx-multi-stream-tools
Depends: rdx-rivendell, glasscoder, darkice
Suggests: butt, mixxx
Description: Multi-format streaming tools for RDX
 Advanced streaming encoder collection supporting multiple formats
 and streaming protocols. Ideal for multi-platform broadcasting
 and content distribution.
```

## Virtual Packages (Alternative Providers)

### rdx-audio-processor (Virtual)
```
# Provided by multiple packages
Provides: rdx-audio-processor

# Real packages:
Package: rdx-stereo-tool
Provides: rdx-audio-processor
Depends: rdx-rivendell
Description: Stereo Tool integration for RDX

Package: rdx-jack-rack
Provides: rdx-audio-processor  
Depends: rdx-rivendell, jack-rack
Description: JACK Rack plugin host integration
```

### rdx-stream-encoder (Virtual)
```
# Provided by multiple packages
Provides: rdx-stream-encoder

# Real packages:
Package: rdx-liquidsoap
Provides: rdx-stream-encoder
Depends: rdx-rivendell, liquidsoap
Description: Liquidsoap streaming integration

Package: rdx-darkice
Provides: rdx-stream-encoder
Depends: rdx-rivendell, darkice
Description: DarkIce simple streaming integration

Package: rdx-glasscoder
Provides: rdx-stream-encoder  
Depends: rdx-rivendell, glasscoder
Description: GlassCoder multi-format streaming
```

## Installation Scenarios

### Scenario 1: Minimal Installation
```bash
# Install only core RDX functionality
sudo apt install rdx-rivendell

# User gets:
- Core intelligent routing
- JACK management  
- Service orchestration framework
- Basic device detection
- No automatic streaming/processing tools
```

### Scenario 2: Recommended Installation
```bash
# Install with essential broadcast tools
sudo apt install rdx-broadcast-essentials

# User gets:
- Everything from minimal +
- Liquidsoap for automation
- Icecast2 for streaming
- VLC with JACK support
- Pre-configured for basic broadcasting
```

### Scenario 3: Professional Installation
```bash
# Full professional stack
sudo apt install rdx-professional-stack

# User gets:
- Everything from essentials +
- Multiple streaming encoders
- Professional audio processing options
- Advanced configuration templates
- Multi-stream capabilities
```

### Scenario 4: Custom Installation
```bash
# Cherry-pick components
sudo apt install rdx-rivendell rdx-stereo-tool rdx-glasscoder

# User gets:
- Core RDX +
- Stereo Tool processing +
- GlassCoder streaming
- Custom configuration for specific needs
```

## Runtime Dependency Management

### Smart Package Detection
```python
# RDX runtime detection (already implemented)
def detect_available_tools():
    tools = {}
    
    # Command-based detection
    for tool in ['liquidsoap', 'darkice', 'glasscoder', 'vlc']:
        tools[tool] = shutil.which(tool) is not None
    
    # Service-based detection
    tools['icecast2'] = subprocess.call(['systemctl', 'is-active', 'icecast2'], 
                                      stdout=subprocess.DEVNULL) == 0
    
    # Package-based detection
    tools['stereo_tool'] = Path('/usr/local/bin/stereo_tool_gui_jack_64').exists()
    
    return tools
```

### Graceful Degradation
```cpp
// RDX adapts functionality based on available tools
class RdxCapabilities {
public:
    bool hasAudioProcessor() { return hasStereoTool() || hasJackRack(); }
    bool hasStreamEncoder() { return hasLiquidsoap() || hasDarkice() || hasGlasscoder(); }
    bool hasMediaPlayer() { return hasVLC() || hasAudacity(); }
    
    // Enable features only when dependencies are available
    void configureProfile(const QString& profileName) {
        if (profileName == "live-broadcast" && !hasAudioProcessor()) {
            // Fall back to basic routing without processing
            qWarning() << "Audio processor not available, using basic routing";
        }
    }
};
```

## Current Implementation Status

✅ **Already Working in install-rdx.sh:**
- ✅ **Smart Detection**: Automatically detects all major broadcast tools
- ✅ **Interactive Selection**: User chooses which tools to install
- ✅ **Alternative Options**: Presents DarkIce vs GlassCoder vs Liquidsoap choices  
- ✅ **Graceful Handling**: Works with existing installations
- ✅ **Auto-Install Mode**: `--auto-install-broadcast` for unattended setup

✅ **Runtime Adaptation:**
- ✅ **Profile Adaptation**: Configurations adapt to available tools
- ✅ **Service Orchestration**: Only manages services that are installed
- ✅ **Graceful Degradation**: Core functionality works without optional tools

🔜 **Next: Debian Packaging**
- Package core RDX with minimal dependencies
- Create companion packages for broadcast stacks
- Implement virtual package providers for alternatives