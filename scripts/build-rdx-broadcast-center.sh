#!/bin/bash
# RDX Broadcast Control Center Package Builder v3.0
# Creates comprehensive broadcast automation package

set -e

# Package information
PACKAGE_NAME="rdx-broadcast-control-center"
PACKAGE_VERSION="3.7.9"
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

# Pre-copy source sanity check (non-destructive)
echo "🧪 Pre-checking source syntax..."
if ! python3 -m py_compile "$RDX_ROOT/src/rdx-broadcast-control-center.py" >/dev/null 2>&1; then
    echo "⚠️  Source compile failed. Will rely on packaging-time normalization."
    if [ "${RDX_FAIL_ON_SOURCE_SYNTAX:-0}" = "1" ]; then
        echo "❌ RDX_FAIL_ON_SOURCE_SYNTAX=1 set; aborting build due to source syntax error." >&2
        python3 -m py_compile "$RDX_ROOT/src/rdx-broadcast-control-center.py"  # show error
        exit 1
    fi
    if [ "${RDX_FIX_SOURCE:-0}" = "1" ]; then
        echo "🔧 Applying opt-in source normalization (RDX_FIX_SOURCE=1)..."
        python3 "$RDX_ROOT/scripts/fix-rdx-app-indentation.py" --file "$RDX_ROOT/src/rdx-broadcast-control-center.py" --write --backup || true
        # Re-check after normalization
        python3 -m py_compile "$RDX_ROOT/src/rdx-broadcast-control-center.py" || true
    fi
fi

# Copy main application
echo "📋 Installing main application..."
cp "$RDX_ROOT/src/rdx-broadcast-control-center.py" "$PACKAGE_DIR/usr/local/bin/"
chmod +x "$PACKAGE_DIR/usr/local/bin/rdx-broadcast-control-center.py"

# Sanity-check and normalize indentation if needed (prevents stray IndentationError)
echo "🧪 Sanity-checking Python script syntax..."
python3 - <<PY
import sys, re, ast
from pathlib import Path

path = Path("$PACKAGE_DIR/usr/local/bin/rdx-broadcast-control-center.py")
code = path.read_text(encoding='utf-8')

def try_compile(txt):
    try:
        compile(txt, str(path), 'exec')
        return True
    except Exception as e:
        print(f"   ⛔ Compile check failed: {e}")
        return False

def scan_class_scope_self(txt):
    """AST-based: return list of (lineno, source_line) where 'self' is referenced at class scope (not inside methods)."""
    lines = txt.splitlines()
    out = []
    try:
        tree = ast.parse(txt)
    except Exception:
        # If AST can't parse, skip (compile check will handle)
        return out

    class SelfAtClassScopeVisitor(ast.NodeVisitor):
        def __init__(self):
            self.violations = []

        def visit_ClassDef(self, node: ast.ClassDef):
            # Scan direct class body statements excluding nested FunctionDef/ClassDef bodies
            for stmt in node.body:
                if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                    continue
                # Walk stmt to find Name('self')
                if any(isinstance(n, ast.Name) and n.id == 'self' for n in ast.walk(stmt)):
                    lineno = getattr(stmt, 'lineno', None)
                    if lineno is not None and 1 <= lineno <= len(lines):
                        self.violations.append((lineno, lines[lineno-1]))
            # Continue into nested classes
            self.generic_visit(node)

    v = SelfAtClassScopeVisitor()
    v.visit(tree)
    return v.violations

def jackmatrix_methods_present(txt):
    """Return True if class JackMatrixTab defines required methods like _pretty_client and _pretty_port_name."""
    try:
        tree = ast.parse(txt)
    except Exception:
        return False
    required = {"_pretty_client", "_pretty_port_name"}
    class Found(Exception):
        pass
    have = set()
    class_names = []
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef) and node.name == "JackMatrixTab":
            for stmt in node.body:
                if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                    if stmt.name in required:
                        have.add(stmt.name)
        if isinstance(node, ast.ClassDef):
            class_names.append(node.name)
    return required.issubset(have), have, class_names

def normalize(txt):
    lines = txt.splitlines()
    out = []
    cls_stack = []
    in_method = False
    method_indent = None
    target_classes = {
        'RDXBroadcastControlCenter',
        'JackMatrixTab',
        'StereoToolManagerTab',
        'ServiceControlTab',
        'SettingsTab'
    }

    def current_class():
        return cls_stack[-1] if cls_stack else None

    for i, line in enumerate(lines):
        stripped = line.lstrip(' ')
        lead = len(line) - len(stripped)

        # Track class begin
        m_cls = re.match(r'^class\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(', line)
        if m_cls:
            cls_stack.append(m_cls.group(1))
            in_method = False
            method_indent = None
            out.append(line)
            continue

        # Detect method definitions inside target classes
        if current_class() in target_classes and re.match(r'^\s*def\s+[A-Za-z_][A-Za-z0-9_]*\s*\(', line):
            in_method = True
            method_indent = lead
            out.append(line)
            continue

        # Leaving a method when dedented
        if in_method and lead <= (method_indent or 0) and stripped and not stripped.startswith('#') and not stripped.startswith('def '):
            in_method = False
            method_indent = None

        if in_method and current_class() in target_classes:
            desired = (method_indent or 0) + 4
            if stripped and not stripped.startswith(('def ', 'class ')):
                if lead < desired:
                    line = ' ' * desired + stripped

        out.append(line)

    fixed = '\n'.join(out)
    # Specifically ensure common status bar/title lines are indented like a normal body line
    fixed = re.sub(r'(?m)^(\s{0,4})(self\.(statusBar\(\)\.showMessage|setWindowTitle)\(.*\))$', r'        \2', fixed)
    return fixed

# 1) Initial compile check
ok = try_compile(code)

# 2) Check for class-scope self usage; attempt normalize once if found
errs = scan_class_scope_self(code)
if errs:
    print("   ⛔ Found 'self.' at class scope (outside any method):")
    for ln, text in errs[:10]:
        print(f"      line {ln}: {text.strip()}")
    print("   🔧 Applying indentation normalization (wider scope)...")
    fixed = normalize(code)
    path.write_text(fixed, encoding='utf-8')
    # Re-check
    ok = try_compile(fixed)
    errs2 = scan_class_scope_self(fixed)
    if errs2:
        print("   ❌ Still found class-scope 'self.' after normalization; aborting build.")
        for ln, text in errs2[:10]:
            print(f"      line {ln}: {text.strip()}")
        sys.exit(1)
    if not ok:
        print("   ❌ Invalid after normalization; aborting build.")
        sys.exit(1)
    print("   ✅ Fixed and valid")
    # After normalization, enforce JackMatrixTab methods presence
    present, have, classes = jackmatrix_methods_present(fixed)
    if not present:
        print("   ❌ JackMatrixTab integrity check failed: required methods missing (e.g., _pretty_client). Aborting build.")
        print(f"      Found methods: {sorted(have)}")
        print(f"      Classes in module: {sorted(classes)}")
        sys.exit(1)
    sys.exit(0)

if ok:
    # Even if compile passes, enforce the class-scope 'self.' check
    errs = scan_class_scope_self(code)
    if errs:
        print("   ❌ Build guard: class-scope 'self.' detected; failing build to prevent runtime NameError.")
        for ln, text in errs[:10]:
            print(f"      line {ln}: {text.strip()}")
        sys.exit(1)
    # Enforce JackMatrixTab methods presence
    present, have, classes = jackmatrix_methods_present(code)
    if not present:
        print("   ❌ Build guard: JackMatrixTab missing required methods (_pretty_client/_pretty_port_name). Failing build.")
        print(f"      Found methods: {sorted(have)}")
        print(f"      Classes in module: {sorted(classes)}")
        # Debug snippet around potential definitions
        lines = code.splitlines()
        # Dump method names the AST sees inside JackMatrixTab
        try:
            import ast
            tree = ast.parse(code)
            for node in ast.walk(tree):
                if isinstance(node, ast.ClassDef) and node.name == 'JackMatrixTab':
                    seen = []
                    for stmt in node.body:
                        if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                            seen.append((stmt.name, getattr(stmt, 'lineno', -1)))
                    print(f"      AST sees methods in JackMatrixTab: {seen}")
        except Exception as e:
            print(f"      AST dump failed: {e}")
        for idx, line in enumerate(lines, start=1):
            if line.lstrip().startswith('def _pretty_client') or line.lstrip().startswith('def _pretty_port_name'):
                start = max(1, idx-2)
                end = min(len(lines), idx+3)
                print(f"      Source near line {idx}:")
                for i in range(start, end+1):
                    s = lines[i-1]
                    print(f"        {i:4d}: {repr(s)}")
                # Find nearest enclosing class header above
                for j in range(idx-1, 0, -1):
                    if lines[j-1].lstrip().startswith('class '):
                        print(f"      Nearest class header above pretty method: line {j}: {lines[j-1].strip()}")
                        break
        sys.exit(1)
    print("   ✅ Syntax OK")
    sys.exit(0)

print("   ❌ Invalid and no auto-normalization applied; aborting build.")
sys.exit(1)
PY

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

# Ensure OPAM shim is preferred when present
export PATH="$HOME/.local/bin:$PATH"

# Log Python runtime and app script version header for diagnostics
PY_VER=$(python3 -c 'import sys; print(sys.version.replace("\n"," "))' 2>/dev/null)
log_error "Python: ${PY_VER}"
if [ -f "/usr/local/bin/rdx-broadcast-control-center.py" ]; then
    head -n 3 /usr/local/bin/rdx-broadcast-control-center.py 2>/dev/null | sed 's/^/[app-header] /' >> /var/log/rdx-launcher.log 2>/dev/null || \
    head -n 3 /usr/local/bin/rdx-broadcast-control-center.py 2>/dev/null | sed 's/^/[app-header] /' >> /tmp/rdx-launcher.log
fi

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
Depends: python3 (>= 3.6), python3-pyqt5, liquidsoap (>= 2.0.0), jackd2, icecast2, vlc, vlc-plugin-jack
Recommends: liquidsoap-plugin-ffmpeg | liquidsoap-plugin-all | liquidsoap-plugin-extra, qjackctl
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
        # Note: Do not run apt/apt-get in maintainer scripts. If Liquidsoap is installed
        # but missing the FFmpeg encoder, we leave a friendly hint and let users install
        # plugins via the GUI (Services → Install Liquidsoap FFmpeg Plugin) or by running:
        #    pkexec /bin/bash /usr/share/rdx/install-liquidsoap-plugin.sh
        if command -v liquidsoap >/dev/null 2>&1; then
            if ! liquidsoap -h encoder.ffmpeg >/dev/null 2>&1 || liquidsoap -h encoder.ffmpeg 2>&1 | grep -qi "Plugin not found"; then
                echo "[postinst] Liquidsoap detected without FFmpeg encoder."
                echo "[postinst] Tip: Use the RDX app (Services tab) to install the plugin,"
                echo "[postinst] or run: pkexec /bin/bash /usr/share/rdx/install-liquidsoap-plugin.sh"
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

# Append all output to log file for postmortem
LOG_FILE="/var/log/rdx-plugin-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

detect_series() {
    if have_cmd lsb_release; then
        lsb_release -cs
    elif [ -f /etc/os-release ]; then
        . /etc/os-release; echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    else
        echo "jammy"
    fi
}

enable_universe_multiverse() {
    if have_cmd add-apt-repository; then
        log "Ensuring 'universe' and 'multiverse' are enabled"
        add-apt-repository -y universe || true
        add-apt-repository -y multiverse || true
    else
        apt_install software-properties-common || true
        add-apt-repository -y universe || true
        add-apt-repository -y multiverse || true
    fi
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
    apt_install ca-certificates gnupg lsb-release software-properties-common || true
    local series
    series=$(detect_series)
    log "Detected series: $series"

    if have_cmd add-apt-repository; then
        log "Enabling official Liquidsoap PPA (savonet/ppa)"
        if add-apt-repository -y ppa:savonet/ppa; then
            apt-get update || true
            return 0
        else
            log "add-apt-repository failed; falling back to manual source setup"
        fi
    fi

    # Manual fallback: add PPA sources list and import key via keyserver
    local list="/etc/apt/sources.list.d/savonet-ubuntu-ppa-${series}.list"
    echo "deb http://ppa.launchpad.net/savonet/ppa/ubuntu ${series} main" > "$list"
    echo "deb-src http://ppa.launchpad.net/savonet/ppa/ubuntu ${series} main" >> "$list"
    # Try to fetch key from keyserver
    if have_cmd gpg; then
        log "Importing PPA key from keyserver"
        apt_install dirmngr || true
        # Try common keyservers
        gpg --keyserver keyserver.ubuntu.com --recv-keys 0x5ABCE6D5740500DB || \
        gpg --keyserver hkps://keys.openpgp.org --recv-keys 0x5ABCE6D5740500DB || true
        gpg --export 0x5ABCE6D5740500DB | tee /etc/apt/trusted.gpg.d/savonet-ppa.gpg >/dev/null || true
    else
        log "gpg not available; skipping explicit key import (may rely on system defaults)"
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
    # Fast-path: if plugin already present, do nothing
    if check_ffmpeg_plugin; then
        log "FFmpeg plugin already available; nothing to do."
        exit 0
    fi

    if ! command -v apt-get >/dev/null 2>&1; then
        log "apt-get not found; cannot install packages automatically"
        exit 1
    fi

    case "$MODE" in
        current)
            enable_universe_multiverse || true
            apt-get update || true
            try_install_plugins_from_current || exit 1
            ;;
        official)
            enable_universe_multiverse || true
            apt-get update || true
            try_install_plugins_from_current || { add_official_repo; try_install_plugins_from_current || exit 1; }
            ;;
        vendor)
            enable_universe_multiverse || true
            apt-get update || true
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

# Core dependency installer: jackd2, icecast2, vlc, vlc-plugin-jack, qjackctl and audio permissions
cat > "$PACKAGE_DIR/usr/share/rdx/install-deps.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[rdx-deps] $*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

# Determine invoking user for group membership fixes
resolve_user(){
    if [ "${EUID}" -ne 0 ]; then id -un; return 0; fi
    if [ -n "${PKEXEC_UID:-}" ]; then getent passwd "${PKEXEC_UID}" | cut -d: -f1; return 0; fi
    if [ -n "${SUDO_UID:-}" ]; then echo "${SUDO_USER}"; return 0; fi
    if logname 2>/dev/null; then logname; return 0; fi
    echo "root"
}

enable_repos(){
    if have add-apt-repository; then
        add-apt-repository -y universe || true
        add-apt-repository -y multiverse || true
    else
        apt-get update || true
    fi
}

install_pkgs(){
    export DEBIAN_FRONTEND=noninteractive
    apt-get update || true
    apt-get install -y --no-install-recommends jackd2 icecast2 vlc vlc-plugin-jack qjackctl || true
}

ensure_audio_perms(){
    local user; user="$(resolve_user)"
    if id "$user" >/dev/null 2>&1; then
        log "Adding $user to 'audio' group (if not already)"
        usermod -a -G audio "$user" 2>/dev/null || true
    fi
    # Ensure realtime privileges for @audio
    local lim="/etc/security/limits.d/99-rdx-audio.conf"
    if [ ! -f "$lim" ]; then
        cat > "$lim" <<EOL
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice       -19
EOL
    fi
}

main(){
    if ! have apt-get; then
        log "apt-get not found; cannot install dependencies automatically"
        exit 1
    fi
    enable_repos || true
    install_pkgs || true
    ensure_audio_perms || true
    log "Core dependencies pass completed. A reboot or re-login may be required for group changes to apply."
}

main "$@"
EOF
chmod +x "$PACKAGE_DIR/usr/share/rdx/install-deps.sh"

# Ship JACK readiness helper so systemd units can reliably wait for JACK
install -d "$PACKAGE_DIR/usr/local/bin"
install -m 0755 "$(dirname "$0")/../scripts/jack-wait-ready.sh" "$PACKAGE_DIR/usr/local/bin/jack-wait-ready.sh"

# Local apt-based installer helper (embedded copy)
# Note: This is primarily for reference after install. For initial installation,
# download the .deb and the same-named install-local-<ver>.sh from the release
# page and place them in the same folder, or pass the .deb path as an argument.
cat > "$PACKAGE_DIR/usr/share/rdx/install-local-${PACKAGE_VERSION}.sh" << EOF
#!/usr/bin/env bash
set -euo pipefail

DEB_PATH="\${1:-rdx-broadcast-control-center_${PACKAGE_VERSION}_amd64.deb}"

if [[ ! -f "\${DEB_PATH}" ]]; then
    echo "Usage: \${0##*/} </path/to/rdx-broadcast-control-center_${PACKAGE_VERSION}_amd64.deb>" >&2
    echo "If no argument is provided, it looks for ./rdx-broadcast-control-center_${PACKAGE_VERSION}_amd64.deb" >&2
    exit 2
fi

echo "Installing \${DEB_PATH} via apt (auto-resolves dependencies)…"
sudo apt update || true
sudo apt install -y "\${DEB_PATH}"
echo "Done. Launch with: rdx-control-center"
EOF
chmod +x "$PACKAGE_DIR/usr/share/rdx/install-local-${PACKAGE_VERSION}.sh"

# OPAM-based installer (PPA-free build)
cat > "$PACKAGE_DIR/usr/share/rdx/install-liquidsoap-opam.sh" << 'EORDX_OPAM'
#!/usr/bin/env bash
set -euo pipefail

# RDX OPAM-based Liquidsoap installer (PPA-free)
# - Installs system build dependencies (root)
# - Initializes OPAM per user and builds Liquidsoap with AAC/FFmpeg support (user)
# - Creates a stable shim in ~/.local/bin/liquidsoap so the app can find it

log() { echo "[rdx-opam] $*"; }
warn() { echo "[rdx-opam][WARN] $*" >&2; }
err() { echo "[rdx-opam][ERROR] $*" >&2; }

need_root_pkgs=(
    opam bubblewrap build-essential m4 pkg-config git curl unzip rsync
    libpcre3-dev libtag1-dev libmad0-dev libfaad-dev libfdk-aac-dev
    libasound2-dev libpulse-dev libjack-jackd2-dev
    libavcodec-dev libavformat-dev libavutil-dev libswresample-dev
    libssl-dev zlib1g-dev libflac-dev libogg-dev libvorbis-dev libsamplerate0-dev libsoxr-dev
)

resolve_target_user() {
    if [ "${EUID}" -ne 0 ]; then id -un; return 0; fi
    if [ -n "${PKEXEC_UID:-}" ]; then getent passwd "${PKEXEC_UID}" | cut -d: -f1; return 0; fi
    if [ -n "${SUDO_UID:-}" ]; then echo "${SUDO_USER}"; return 0; fi
    if logname 2>/dev/null; then logname; return 0; fi
    err "Unable to determine invoking user. Set PKEXEC_UID or run without root."; return 1
}

apt_install_deps() {
    log "Installing system dependencies (requires root)…"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update || true
    if command -v add-apt-repository >/dev/null 2>&1; then
        add-apt-repository -y universe || true
        add-apt-repository -y multiverse || true
        apt-get update || true
    fi
    apt-get install -y --no-install-recommends "${need_root_pkgs[@]}"
}

user_install_opam() {
    local user_home="$1"; shift
    local user_shell="$1"; shift
    local user_name="$1"; shift

    log "Initializing OPAM for user: ${user_name}"
    mkdir -p "${user_home}/.local/bin"
    if ! grep -qs 'export PATH=.*\.local/bin' "${user_home}/.profile" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${user_home}/.profile"
    fi
    OPAMYES=1 OPAMERRLOGLEN=0 opam init -y --disable-sandboxing || true
    if ! opam switch show 2>/dev/null | grep -q '^rdx-liq$'; then
        if ! opam switch create rdx-liq 4.14.2 -y; then
            opam switch create rdx-liq -y
        fi
    fi
    eval "$(opam env --switch=rdx-liq --set-switch)"
    OPAMYES=1 opam install -y opam-depext || true
    OPAMYES=1 opam depext -y liquidsoap || true
    OPAMYES=1 opam install -y liquidsoap
    local opam_bin
    opam_bin="$(opam var bin)" || opam_bin="${user_home}/.opam/rdx-liq/bin"
    local liq_bin="${opam_bin}/liquidsoap"
    if [ ! -x "${liq_bin}" ]; then
        err "Liquidsoap binary not found at ${liq_bin}"; return 2
    fi
    cat > "${user_home}/.local/bin/liquidsoap" <<EORDX_SHIM
#!/usr/bin/env bash
if [ -f "$HOME/.opam/opam-init/init.sh" ]; then . "$HOME/.opam/opam-init/init.sh" >/dev/null 2>&1 || true; fi
exec "${liq_bin}" "$@"
EORDX_SHIM
    chmod +x "${user_home}/.local/bin/liquidsoap"
    if ! "${liq_bin}" -h encoder.fdkaac >/dev/null 2>&1; then warn "encoder.fdkaac not available"; fi
    if ! "${liq_bin}" -h encoder.ffmpeg >/dev/null 2>&1; then warn "encoder.ffmpeg not available"; fi
    log "OPAM Liquidsoap installed at ${liq_bin}"
}

main() {
    local tgt_user
    tgt_user="$(resolve_target_user)"
    if [ "${EUID}" -eq 0 ]; then
        apt_install_deps
        local home shell
        home="$(getent passwd "${tgt_user}" | cut -d: -f6)"
        shell="$(getent passwd "${tgt_user}" | cut -d: -f7)"
        if [ -z "${home}" ] || [ ! -d "${home}" ]; then err "Cannot determine home for ${tgt_user}"; exit 1; fi
        log "Switching to user ${tgt_user} for OPAM install"
        su - "${tgt_user}" -c "bash -lc 'set -e; export OPAMYES=1; opam --version >/dev/null 2>&1 || true; $(typeset -f user_install_opam); user_install_opam \"${home}\" \"${shell}\" \"${tgt_user}\"'"
    else
        user_install_opam "${HOME}" "${SHELL}" "$(id -un)"
    fi
    log "OPAM installation complete."
}

main "$@"
EORDX_OPAM
chmod +x "$PACKAGE_DIR/usr/share/rdx/install-liquidsoap-opam.sh"

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
# Ensure helper scripts in /usr/share/rdx are executable
if ls "$PACKAGE_DIR/usr/share/rdx/"*.sh >/dev/null 2>&1; then
    chmod +x "$PACKAGE_DIR/usr/share/rdx/"*.sh || true
fi

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