# RDX GUI Integration Guide
# How to add RDX intelligent routing controls to existing RDAdmin

## 🎯 Integration Overview

RDX provides a complete GUI interface that integrates seamlessly into RDAdmin, giving users **FULL CONTROL** of all intelligent routing features without ever needing command-line access.

## 🔥 What Users Get: "RDX Audio Control" Button

When RDX is installed, users see a prominent **"🔥 RDX Audio Control"** button in RDAdmin that opens a comprehensive tabbed interface:

### 📋 **Tab 1: Profiles** 
- **Profile Selection**: Live-broadcast, Production, Automation profiles
- **One-Click Loading**: Instant profile switching with visual feedback  
- **Profile Description**: Shows what each profile does
- **Save/Reset**: Modify and save custom profile settings

### 📋 **Tab 2: Inputs**
- **Current Source Display**: Shows active input (VLC, System, etc.)
- **Source Switching**: Dropdown + button to change input sources
- **Available Sources List**: Live detection of VLC, Hydrogen, system capture
- **Input Level Meter**: Visual feedback of audio levels

### 📋 **Tab 3: Services** 
- **Service Status**: Live status of Stereo Tool, Liquidsoap, Icecast2, etc.
- **Start/Stop/Restart**: Full service control with one click
- **Service Logs**: Real-time log display for troubleshooting
- **Auto-Management**: Services start/stop with profiles automatically

### 📋 **Tab 4: Connections**
- **JACK Device List**: All detected audio devices with connection counts
- **Connection Matrix**: Visual connection management (like QJackCtl but integrated)
- **Critical Protection List**: Shows and manages protected connections
- **Connect/Disconnect**: Manual connection control when needed

### 📋 **Tab 5: Monitor**
- **Real-Time Status**: CPU usage, XRuns, latency, sample rate
- **System Scan**: Force re-detection of audio hardware
- **Emergency Stop**: Red button to disconnect everything in emergencies
- **Status Log**: Comprehensive system activity log

### 📋 **Tab 6: Advanced**
- **Behavior Settings**: Toggle auto-routing, critical protection
- **Scan Interval**: Configure how often RDX checks for changes  
- **Configuration Export/Import**: Backup and restore settings
- **Service Path**: Configure RDX service location

## 🔧 Integration Methods

### Method 1: Automatic Installation (Recommended)
When RDX installer detects existing Rivendell:
```bash
# RDX installer automatically detects RDAdmin and integrates GUI
./install-rdx.sh
# User gets "RDX Audio Control" button automatically
```

### Method 2: Manual Integration (For Developers)
Add to existing RDAdmin code:
```cpp
#include "rdx_integration.h"

// In RDAdmin main window constructor:
ADD_RDX_BUTTON(this, station);
```

### Method 3: Plugin-Style Integration  
RDX can be loaded as a plugin module:
```cpp
// Dynamic loading approach
QPluginLoader loader("librdx-gui.so");
RdxIntegration *rdx = qobject_cast<RdxIntegration*>(loader.instance());
if (rdx) {
    rdx->addRdxButtonToRdAdmin(this, station);
}
```

## 🎛️ User Experience Flow

### Scenario 1: Station Manager Setting Up Profiles
1. **Opens RDAdmin** → Clicks "🔥 RDX Audio Control"
2. **Profiles Tab** → Selects "live-broadcast" profile  
3. **Clicks "Load Profile"** → Entire broadcast chain established automatically
4. **Monitor Tab** → Confirms all services running and connections protected

### Scenario 2: Operator Switching Input Sources
1. **Opens RDX** → **Inputs Tab**
2. **Sees "Current: system"** → Wants to switch to VLC for music
3. **Selects "vlc" from dropdown** → Clicks "Switch Input"
4. **Immediate visual feedback** → VLC now routing to Rivendell automatically

### Scenario 3: Engineer Troubleshooting Audio Issues
1. **Opens RDX** → **Monitor Tab** → Clicks "🔍 Scan System"
2. **Services Tab** → Sees "🔴 Stereo Tool (Stopped)"
3. **Clicks "Restart Service"** → Stereo Tool starts automatically
4. **Connections Tab** → Confirms processing chain re-established

### Scenario 4: Emergency Audio Problems
1. **Opens RDX** → **Monitor Tab** → Clicks "🚨 Emergency Stop"
2. **All connections disconnected** → Audio stops but no damage
3. **Profiles Tab** → Clicks "Load Profile" → Normal operation restored

## 🛡️ Safety Features in GUI

### Critical Connection Protection Visualization
- **Protected connections shown with 🛡️ shield icon**
- **Attempts to disconnect protected connections show warning dialog**
- **Emergency stop asks for confirmation with big warning**

### Service Status Indicators
- **🟢 Green**: Service running normally
- **🔴 Red**: Service stopped or failed
- **🟡 Yellow**: Service starting/stopping
- **⚠️ Warning**: Service running but degraded

### Real-Time Updates
- **All tabs update automatically every 5 seconds**
- **Immediate feedback on all user actions**
- **Live status changes reflected instantly**

## 🚀 Installation Impact on Users

### Before RDX Installation:
- Users manage JACK manually with command-line tools
- Audio routing requires technical knowledge  
- Service management scattered across different interfaces
- No protection against accidentally breaking live audio

### After RDX Installation:
- **Single "RDX Audio Control" button** provides everything
- **One-click profile loading** sets up entire broadcast chain
- **Intelligent automation** handles routine routing decisions
- **Critical protection** prevents accidental audio interruptions
- **Professional interface** suitable for non-technical operators

## 🔧 Technical Architecture

### GUI Components Built:
- ✅ **RdxJackDialog**: Complete tabbed interface with all features
- ✅ **RdxIntegration**: Functions to add RDX button to RDAdmin  
- ✅ **Installation Detection**: Automatic GUI integration during RDX install
- ✅ **Service Communication**: GUI talks to rdx-jack-helper via command interface

### Integration Points:
- ✅ **RDAdmin Button**: Prominent placement in main interface
- ✅ **Station Context**: GUI automatically configured for current station
- ✅ **Rivendell Integration**: Respects existing permissions and settings
- ✅ **Help System**: Tooltips and context help throughout interface

## 🎯 Result

**Users get professional broadcast-grade intelligent routing control directly within the familiar RDAdmin interface they already know and trust.**

No command-line knowledge required. No external tools needed. Complete functionality in one integrated interface.

**This is GUI-FIRST design done right!** 🔥