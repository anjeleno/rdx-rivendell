# RDX Quick Build Reference

## 🚀 Copy/Paste Commands

### **Build Complete Package (Recommended)**
```bash
cd /root/rdx-rivendell
chmod +x scripts/build-deb-enhanced.sh
./scripts/build-deb-enhanced.sh
```

### **Build with GUI Support**
```bash
./scripts/build-deb-enhanced.sh --include-gui
```

### **Build Minimal Core Package**
```bash
./scripts/build-deb-core.sh
```

### **Install Package**
```bash
sudo dpkg -i rdx-rivendell-enhanced_2.0.0_amd64.deb
sudo apt-get install -f
```

### **Test Installation**
```bash
rdx-jack-helper --scan
rdx-stream start hq
rdx-deps check
systemctl status rdx-jack-helper
```

## 📋 All Available Scripts

| Script | Purpose | Output |
|--------|---------|--------|
| `build-deb-enhanced.sh` | **Complete package** | All features |
| `build-deb-core.sh` | Minimal CLI | Basic functionality |
| `build-deb-adaptive.sh` | Smart detection | Adaptive features |
| `build-deb-package.sh` | Standard + GUI | Core + GUI |
| `build-all-packages.sh` | Multiple variants | Several packages |

## 🎯 Enhanced Builder Options

```bash
# Default: Everything enabled
./scripts/build-deb-enhanced.sh

# Without AAC streaming
./scripts/build-deb-enhanced.sh --no-aac

# Without smart installer
./scripts/build-deb-enhanced.sh --no-smart-install

# Custom name and version
./scripts/build-deb-enhanced.sh --package-name my-rdx --version 3.0.0

# Debug build
./scripts/build-deb-enhanced.sh --debug

# Full customization
./scripts/build-deb-enhanced.sh --include-gui --package-name rdx-pro --version 2.1.0
```

## 🔧 Troubleshooting

```bash
# Install dependencies
sudo apt-get install build-essential cmake qtbase5-dev libjack-jackd2-dev dpkg-dev

# Clean and retry
rm -rf build-* /tmp/rdx-*
./scripts/build-deb-enhanced.sh

# Check package
dpkg-deb --info rdx-rivendell-enhanced_2.0.0_amd64.deb
```

## ✅ Features Included in Enhanced Package

- ✅ Core JACK audio routing
- ✅ AAC+ streaming (HE-AAC v1/v2, LC-AAC)  
- ✅ Smart dependency management
- ✅ Professional systemd integration
- ✅ Comprehensive CLI tools
- ✅ Desktop integration
- ✅ Auto-aliases for rd user
- ✅ Complete documentation