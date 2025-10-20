# RDX (Rivendell Extended) - CHANGELOG

## [1.0.0] - 2025-10-20 - "WICKED" Release 🔥

### 🚀 MAJOR FEATURES - Broadcast-Grade Intelligence

#### Intelligent Auto-Routing System
- **Smart Hardware Detection**: Automatically discovers audio processors (Stereo Tool, Jack Rack, Carla, Non-Mixer)
- **Streaming Client Recognition**: Detects streaming software (Liquidsoap, GlassCoder, Darkice, Butt, Icecast)  
- **Input Source Awareness**: Identifies input sources (VLC, System Capture, Hydrogen, Rosegarden)
- **Priority-Based Routing**: Configurable input source priorities (system=100, vlc=80, liquidsoap=60)

#### Critical Connection Protection 🛡️
- **Broadcast-Safe Operations**: Never interrupts live audio processing chains
- **Critical Client Protection**: Refuses to disconnect protected clients (processing, streaming)
- **Pattern-Based Safeguards**: Protects Rivendell→Processor→Streaming chains automatically
- **User-Configurable Protection**: XML-defined critical connections with priority levels
- **Override Protection**: Prevents accidental disconnection of live broadcast infrastructure

#### Profile-Based Service Orchestration
- **Auto-Service Startup**: Profile-driven service orchestration (Stereo Tool, Liquidsoap)
- **Smart Chain Building**: Automatically establishes processing chains based on detected hardware
- **Adaptive Configuration**: Works with any broadcast hardware setup, not hardcoded
- **Real-Time Monitoring**: Live JACK client detection and connection management

### �️ SIMPLIFIED MANAGEMENT

#### Replaces Manual JACK Control
- **Eliminates Complex Patching**: No need for manual JACK connection management
- **One-Command Operation**: Complete broadcast setup from single profile command
- **Intelligent Automation**: Automatic routing decisions based on audio context
- **Professional Workflow**: Focus on content creation, not technical routing

### �🎵 INTELLIGENT BEHAVIORS

#### VLC Auto-Routing
- **Intentional Media Detection**: VLC automatically routes to Rivendell (recognized as intentional playback)
- **Smart Conflict Prevention**: Only auto-routes when no other input is active
- **Dynamic Client Support**: Handles VLC instances with varying process IDs

#### System Capture Management  
- **Respectful Input Handling**: Physical inputs respect user/preset control (no automatic conflicts)
- **Manual Override Available**: `--switch-input system` for deliberate physical input routing
- **Live Switching**: Seamless input source changes without audio dropouts

#### Processing Chain Intelligence
- **Hardware Agnostic**: Detects and connects any audio processing setup
- **Flexible Port Matching**: Smart port detection with pattern matching (not hardcoded names)
- **Multi-Vendor Support**: Works with Stereo Tool, Jack Rack, Carla, and other processors

### 🛠️ TECHNICAL FEATURES

#### Enhanced JACK Management
- **Real-Time Client Monitoring**: 1-second interval JACK client change detection
- **Connection State Tracking**: Maintains awareness of current routing configuration  
- **Broadcast-Safe Disconnection**: Only touches input routing, never output connections
- **Multi-User JACK Support**: Promiscuous mode support for cross-user compatibility

#### Command-Line Interface
```bash
# Profile management with smart routing
rdx-jack-helper --profile live-broadcast    # Auto-establishes complete broadcast chain
rdx-jack-helper --list-profiles             # Show available configurations

# Input source control
rdx-jack-helper --switch-input vlc          # Route VLC to Rivendell
rdx-jack-helper --switch-input system       # Route physical inputs to Rivendell  
rdx-jack-helper --list-sources              # Show available sources with priorities

# Safety operations
rdx-jack-helper --disconnect vlc            # Safe disconnection (non-critical only)
rdx-jack-helper --scan                      # Hardware discovery and status
```

#### Configuration System
- **XML-Based Profiles**: User-configurable critical connections and routing rules
- **Hardware Detection Rules**: Configurable client type detection patterns
- **Priority Management**: User-defined input source priority systems
- **Profile Inheritance**: Multiple broadcast scenarios (live, production, automation)

### 🔧 INFRASTRUCTURE IMPROVEMENTS

#### Build System
- **CMake Integration**: Professional build system with proper JACK/Qt5 linking
- **Multi-Target Support**: rdx-jack-helper service with modular architecture  
- **Library Management**: Proper ALSA, JACK, Qt5 Core/DBus dependencies
- **Cross-Platform Ready**: Linux-focused with expandable architecture

#### Service Architecture
- **D-Bus Integration**: System bus service with fallback test mode
- **Real-Time Monitoring**: Timer-based JACK status and device scanning
- **Event-Driven Design**: Qt5 signal/slot architecture for responsive operations
- **Memory Management**: Proper resource cleanup and connection management

### 📡 BROADCAST ECOSYSTEM INTEGRATION

#### Rivendell Compatibility
- **Native Integration**: Built specifically for Rivendell broadcast automation
- **GlassCoder Support**: Fred Gleason's streaming encoder fully supported
- **RDAdmin Ready**: Architecture prepared for GUI plugin integration
- **Existing Workflow**: Enhances rather than replaces current Rivendell operations

#### Professional Features
- **Live Audio Priority**: Critical connections protected during all operations
- **Zero-Downtime Switching**: Input changes without interrupting broadcast output
- **Hardware Flexibility**: Supports any professional broadcast hardware configuration
- **Operator Safety**: Prevents accidental disconnection of live audio infrastructure

### 🚨 BREAKING CHANGES
- Initial release - no breaking changes from previous versions

### 📝 NOTES
- Requires JACK Audio Connection Kit
- Designed for Linux broadcast environments  
- Qt5 and ALSA dependencies required
- Tested with Stereo Tool, Liquidsoap, VLC, and standard ALSA hardware

### 🙏 ACKNOWLEDGMENTS
- Built for the professional broadcast community
- Inspired by real-world broadcast engineering needs
- Designed with live radio operation safety as primary concern

---

**This release represents a quantum leap in broadcast automation intelligence and safety.** 🎙️📡✨