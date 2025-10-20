# RDX - Rivendell Extended

**Professional broadcast audio system extensions for Rivendell Radio Automation**

RDX enhances Rivendell v4+ with integrated control of JACK, Icecast, Liquidsoap, Stereo Tool, and AES67 networking—all from within the familiar RDAdmin interface.

## 🎯 Project Vision

Transform Rivendell from an excellent radio automation system into a **complete broadcast ecosystem** with seamless control over the entire audio chain:

- **JACK Audio**: Profile-based management with device discovery and intelligent patchbay
- **Streaming**: Integrated Icecast configuration and Liquidsoap control
- **Processing**: Stereo Tool lifecycle management and auto-startup
- **Networking**: AES67 audio-over-IP integration with JACK bridging
- **System**: PulseAudio elimination for broadcast-clean audio paths

## 🏗️ Architecture

RDX follows the **Extension Package** approach for maximum compatibility:

```
┌─────────────────┐    ┌─────────────────┐
│   Rivendell     │    │      RDX        │
│  (Unchanged)    │    │   Extensions    │
├─────────────────┤    ├─────────────────┤
│ • RDAdmin       │◄──►│ • Enhanced UI   │
│ • Database      │◄──►│ • New Tables    │
│ • Permissions   │◄──►│ • D-Bus Service │
│ • JACK Base     │◄──►│ • Profiles      │
└─────────────────┘    └─────────────────┘
```

### Core Components

- **rdx-helper**: D-Bus service for privileged operations (JACK, system services)
- **rdx-admin**: Enhanced RDAdmin dialogs for integrated control
- **rdx-database**: Extended schema for profiles and service configurations
- **rdx-packaging**: Clean .deb installation that extends existing Rivendell

## 🚀 Features

### JACK Management
- **Profile System**: Named configurations with automatic device discovery
- **Smart Patchbay**: Persistent connections with auto-retry and client detection
- **Device Discovery**: Intelligent ALSA device enumeration (USB vs PCI)
- **Health Monitoring**: Xrun tracking, CPU load, transport state
- **Validation**: Pre-flight checks and automatic rollback on failure

### Broadcast Chain Control
- **Icecast Integration**: GUI configuration editor with template system
- **Liquidsoap Management**: Script validation, multi-stream support
- **Stereo Tool Control**: Auto-startup, multiple instance management
- **Service Orchestration**: Proper startup ordering and dependency management

### Network Audio
- **AES67 Support**: Pluggable provider system for various AoIP stacks
- **JACK Bridging**: Seamless integration of network audio with local routing
- **Stream Discovery**: Automatic detection and mapping of network streams

### System Integration
- **PulseAudio Elimination**: Clean broadcast environment, no desktop audio leakage
- **Permission Integration**: Leverages existing Rivendell user/group system
- **Database Driven**: All configuration stored in Rivendell's MySQL database
- **Backup/Rollback**: Versioned configurations with automatic recovery

## 📦 Installation

RDX installs as an extension package that enhances existing Rivendell installations:

```bash
# Install RDX (depends on rivendell package)
sudo dpkg -i rdx-rivendell_1.0.0_amd64.deb

# Start enhanced services
sudo systemctl enable rdx-helper
sudo systemctl start rdx-helper

# Launch RDAdmin - new "Advanced Audio" button appears
rdadmin
```

### Upgrade Compatibility

```bash
# Rivendell updates work normally
sudo apt upgrade rivendell

# RDX updates independently  
sudo apt upgrade rdx-rivendell
```

## 🛠️ Development Status

### Phase 1: Foundation ✅
- [x] Architecture audit of Rivendell v4
- [x] Extension strategy defined
- [x] Repository structure established

### Phase 2: JACK Enhancement 🚧
- [ ] Analyze existing `edit_jack.cpp`
- [ ] Design profile management system
- [ ] Implement device discovery
- [ ] Create enhanced JACK dialog

### Phase 3: Service Integration 📋
- [ ] Icecast configuration management
- [ ] Liquidsoap script handling
- [ ] Stereo Tool orchestration
- [ ] PulseAudio elimination

### Phase 4: Network Audio 📋
- [ ] AES67 provider framework
- [ ] JACK bridging implementation
- [ ] Stream discovery and routing

### Phase 5: Polish & Package 📋
- [ ] Debian packaging
- [ ] Integration testing
- [ ] Documentation
- [ ] Release preparation

## 🎯 Target Environments

- **Ubuntu 22.04 LTS (Jammy)** - Primary target
- **Ubuntu 24.04 LTS (Noble)** - Forward compatibility
- **Future LTS releases** - Designed for longevity

## 📚 Documentation

- **[Architecture Audit](docs/architecture-audit.md)** - Comprehensive Rivendell v4 analysis
- **[Database Schema](docs/database-schema.md)** - RDX table structures
- **[API Reference](docs/api-reference.md)** - D-Bus interface documentation
- **[Installation Guide](docs/installation.md)** - Deployment procedures
- **[User Manual](docs/user-manual.md)** - Operator documentation

## 🤝 Contributing

RDX is designed to benefit the entire Rivendell community:

1. **Extension First**: Features that can enhance upstream Rivendell
2. **Community Feedback**: Regular updates and feature discussions
3. **Upstream Contributions**: Valuable enhancements contributed back to Rivendell
4. **Professional Focus**: Real-world broadcast requirements drive development

## 📄 License

RDX follows Rivendell's licensing model:
- **GPL v2** for core functionality
- **Compatible** with Rivendell's existing license terms
- **Open Source** with professional support options

## 🏢 Professional Support

Enterprise support and custom development available for broadcast facilities requiring:
- Custom AES67 integration
- Specialized audio processing chains  
- Multi-site synchronization
- Advanced automation features

---

**RDX: Enhancing Rivendell with advanced features for both physical and cloud-native installations.**

*For questions, feature requests, or professional support inquiries, please open an issue or contact the development team.*