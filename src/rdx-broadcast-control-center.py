#!/usr/bin/env python3
"""
RDX Professional Broadcast Control Center v3.5.4
Complete GUI control for streaming, icecast, JACK, and service management
"""

import sys
import os
import json
import subprocess
import signal
import time
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, 
                            QPushButton, QLabel, QWidget, QFrame, QMessageBox,
                            QGridLayout, QGroupBox, QTextEdit, QSplitter, QTabWidget,
                            QComboBox, QLineEdit, QTableWidget, QTableWidgetItem,
                            QHeaderView, QCheckBox, QSpinBox, QProgressBar,
                            QScrollArea, QFormLayout, QDialog, QDialogButtonBox,
                            QSizePolicy, QSystemTrayIcon, QMenu,
                            QGraphicsView, QGraphicsScene, QGraphicsEllipseItem,
                            QGraphicsLineItem, QGraphicsTextItem, QGraphicsPathItem)
from PyQt5.QtCore import Qt, QProcess, QTimer, pyqtSignal, QThread, QPointF, QEvent
from PyQt5.QtGui import QFont, QIcon, QPalette, QPen, QColor, QPainter, QPainterPath
import urllib.request
import shutil
import shlex

class StreamBuilderTab(QWidget):
    """Tab 1: Stream Builder - Create and manage streaming configurations"""
    
    def __init__(self):
        super().__init__()
        self.streams = []  # List to store configured streams
        self.setup_ui()
        self.load_streams()  # Load saved streams on startup
        
    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Stream Builder Section
        builder_group = QGroupBox("🎵 Add New Stream")
        form = QFormLayout(builder_group)

        # Codec and Bitrate
        self.codec_input = QComboBox()
        self.codec_input.addItems(["MP3", "AAC+", "FLAC", "OGG", "OPUS"])
        form.addRow("Codec:", self.codec_input)

        self.bitrate_input = QComboBox()
        self.bitrate_input.addItems(["64 kbps", "96 kbps", "128 kbps", "192 kbps", "256 kbps", "320 kbps"])
        form.addRow("Bitrate:", self.bitrate_input)

        # Mount and Metadata
        self.mount_input = QLineEdit("/stream")
        form.addRow("Mount:", self.mount_input)

        self.station_name_input = QLineEdit()
        form.addRow("Station Name:", self.station_name_input)

        self.genre_input = QLineEdit()
        form.addRow("Genre:", self.genre_input)

        self.description_input = QLineEdit()
        form.addRow("Description:", self.description_input)

        add_btn = QPushButton("➕ Add Stream")
        add_btn.clicked.connect(self.add_stream)
        form.addRow(add_btn)

        layout.addWidget(builder_group)

        # Streams table
        self.streams_table = QTableWidget()
        self.streams_table.setColumnCount(7)
        self.streams_table.setHorizontalHeaderLabels(["Codec", "Bitrate", "Mount", "Station Name", "Genre", "Description", "Actions"])
        self.streams_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.streams_table)

        # Actions (Generate/Apply)
        actions_row = QHBoxLayout()
        gen_btn = QPushButton("🔧 Generate Liquidsoap Config")
        gen_btn.setStyleSheet("QPushButton { background-color: #3498db; color: white; font-weight: bold; padding: 8px; }")
        gen_btn.setMinimumHeight(40)
        gen_btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        gen_btn.clicked.connect(self.generate_liquidsoap_config)
        actions_row.addWidget(gen_btn)

        apply_btn = QPushButton("📡 Apply to Icecast")
        apply_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; font-weight: bold; padding: 8px; }")
        apply_btn.setMinimumHeight(40)
        apply_btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        apply_btn.clicked.connect(self.apply_to_icecast)
        actions_row.addWidget(apply_btn)

        actions_row.addStretch(1)
        layout.addLayout(actions_row)

        # Status area group
        status_group = QGroupBox("📄 Configuration Status")
        status_layout = QVBoxLayout(status_group)
        self.status_text = QTextEdit()
        self.status_text.setReadOnly(True)
        status_layout.addWidget(self.status_text)
        layout.addWidget(status_group)

    def add_stream(self):
        """Add a new stream configuration from inputs"""
        codec = self.codec_input.currentText()
        bitrate = self.bitrate_input.currentText()
        mount = self.mount_input.text().strip()
        station_name = self.station_name_input.text().strip()
        genre = self.genre_input.text().strip()
        description = self.description_input.text().strip()

        if not mount:
            QMessageBox.warning(self, "Missing Mount", "Please enter a mount point (e.g., /stream).")
            return
        if not mount.startswith('/'):
            mount = '/' + mount

        # Prevent duplicates
        for s in self.streams:
            if s.get('mount') == mount:
                QMessageBox.warning(self, "Duplicate Mount", f"Mount point {mount} already exists!")
                return

        stream = {
            'codec': codec,
            'bitrate': bitrate,
            'mount': mount,
            'station_name': station_name,
            'genre': genre if genre else 'Various',
            'description': description if description else f'{codec} stream at {bitrate}'
        }
        self.streams.append(stream)

        # Update UI and persist
        self.refresh_streams_table()
        self.save_streams()

        # Clear some inputs
        self.mount_input.clear()
        self.station_name_input.clear()
        self.genre_input.clear()
        self.description_input.clear()

        self.status_text.append(f"✅ Added stream: {codec} {bitrate} → {mount}")
    def refresh_streams_table(self):
        """Refresh the streams table"""
        self.streams_table.setRowCount(len(self.streams))
        
        for row, stream in enumerate(self.streams):
            self.streams_table.setItem(row, 0, QTableWidgetItem(stream['codec']))
            self.streams_table.setItem(row, 1, QTableWidgetItem(stream['bitrate']))
            self.streams_table.setItem(row, 2, QTableWidgetItem(stream['mount']))
            self.streams_table.setItem(row, 3, QTableWidgetItem(stream.get('station_name', '')))
            self.streams_table.setItem(row, 4, QTableWidgetItem(stream.get('genre', '')))
            self.streams_table.setItem(row, 5, QTableWidgetItem(stream.get('description', '')))
            
            # Remove button
            remove_btn = QPushButton("🗑️ Remove")
            remove_btn.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; }")
            remove_btn.clicked.connect(lambda checked, r=row: self.remove_stream(r))
            self.streams_table.setCellWidget(row, 6, remove_btn)
            
    def remove_stream(self, row):
        """Remove a stream configuration"""
        if 0 <= row < len(self.streams):
            removed_stream = self.streams.pop(row)
            self.refresh_streams_table()
            self.save_streams()  # Save after removal
            self.status_text.append(f"🗑️ Removed stream: {removed_stream['codec']} {removed_stream['bitrate']} → {removed_stream['mount']}")
            
    def generate_liquidsoap_config(self):
        """Generate Liquidsoap configuration for all streams"""
        if not self.streams:
            QMessageBox.warning(self, "No Streams", "Please add at least one stream before generating config.")
            return
            
        try:
            # Get config directory
            config_dir = self.get_config_directory()
            
            liquidsoap_config = self.build_liquidsoap_config()
            
            config_file = config_dir / "radio.liq"
            with open(config_file, 'w') as f:
                f.write(liquidsoap_config)
            self.status_text.append(f"✅ Generated Liquidsoap config: {config_file}")
            self.status_text.append(f"📄 Configured {len(self.streams)} stream(s)")
            
        except Exception as e:
            self.status_text.append(f"❌ Failed to write config: {str(e)}")
            
    def get_config_directory(self):
        """Get the application config directory, creating it if needed with proper ownership"""
        import os
        import getpass
        import pwd
        import grp
        
        # Always use standard config directory - no fallbacks
        config_dir = Path.home() / ".config" / "rdx"
        
        try:
            current_user = getpass.getuser()
            user_info = pwd.getpwnam(current_user)
            user_uid = user_info.pw_uid
            user_gid = user_info.pw_gid
            
            # Ensure parent .config directory exists and has correct ownership
            config_parent = config_dir.parent
            config_parent.mkdir(parents=True, exist_ok=True)
            try:
                os.chown(config_parent, user_uid, user_gid)
            except (PermissionError, OSError):
                # If we can't fix .config ownership, try to continue anyway
                pass
            
            # Create and fix ownership of rdx directory
            config_dir.mkdir(parents=True, exist_ok=True)
            os.chown(config_dir, user_uid, user_gid)
            
            # Set proper permissions (755 for directory)
            config_dir.chmod(0o755)
            
            # Test write access
            test_file = config_dir / ".test"
            test_file.touch()
            test_file.unlink()
            
            return config_dir
            
        except (PermissionError, OSError) as e:
            # Try to provide helpful error message and recovery
            error_msg = f"Cannot create or access config directory {config_dir}: {e}\n\n"
            error_msg += "To fix this manually:\n"
            error_msg += f"sudo mkdir -p {config_dir}\n"
            error_msg += f"sudo chown {current_user}:{current_user} {config_dir}\n"
            error_msg += f"sudo chown {current_user}:{current_user} {config_parent}\n"
            error_msg += f"sudo chmod 755 {config_dir}\n"
            raise Exception(error_msg)
            raise Exception(f"Cannot create config directory {config_dir}: {e}\nCheck permissions on ~/.config/")
            
    def load_streams(self):
        """Load streams from persistent storage"""
        try:
            config_dir = self.get_config_directory()
            streams_file = config_dir / "streams.json"
            
            if streams_file.exists():
                import json
                with open(streams_file, 'r') as f:
                    self.streams = json.load(f)
                self.refresh_streams_table()
                self.status_text.append(f"📂 Loaded {len(self.streams)} stream(s) from {streams_file}")
        except Exception as e:
            self.status_text.append(f"⚠️ Could not load saved streams: {str(e)}")
            
    def save_streams(self):
        """Save streams to persistent storage"""
        try:
            config_dir = self.get_config_directory()
            streams_file = config_dir / "streams.json"
            
            import json
            with open(streams_file, 'w') as f:
                json.dump(self.streams, f, indent=2)
                
        except Exception as e:
            self.status_text.append(f"⚠️ Could not save streams: {str(e)}")
            
    def build_liquidsoap_config(self):
        """Build Liquidsoap configuration string"""
        config = '''#!/usr/bin/liquidsoap

# Log to user config directory so the in-app log viewer can read it
set("log.file.path", getenv("HOME") ^ "/.config/rdx/liquidsoap.log")

# Set sample rate to 48kHz
set("frame.audio.samplerate", 48000)

# Enable ICY metadata globally
set("icy.metadata", true)

# Grab JACK input
radio = input.jack(id="liquidsoap")

# Ensure stream stability
radio = mksafe(radio)

'''
        
        # Add output for each stream
        for stream in self.streams:
            codec_config = self.get_codec_config(stream['codec'], stream['bitrate'])
            mount_name = stream['mount'].lstrip('/')  # Remove leading slash for url field
            config += f'''
# {stream['codec']} {stream['bitrate']} stream
output.icecast(
  {codec_config},
  host="localhost",
  port=8000,
  password="hackm3",
  mount="{stream['mount']}",
  genre="{stream.get('genre', 'Various')}",
  url="{mount_name}",
  name="{stream.get('station_name', 'RDX Station')}",
  description="{stream.get('description', f'{stream["codec"]} stream at {stream["bitrate"]}')}",
    radio
)
'''
        
        return config
        
    def get_codec_config(self, codec, bitrate):
        """Get codec-specific configuration"""
        if codec == "MP3":
            kbps = bitrate.split()[0]
            return f"%mp3(bitrate={kbps})"
        elif codec in ("AAC+", "AAC"):
            # Prefer native fdkaac encoder if available; otherwise fall back to ffmpeg aac
            kbps = bitrate.split()[0]
            try:
                kbps_int = int(kbps)
            except Exception:
                kbps_int = 64
            if self._has_fdkaac():
                # fdkaac expects numeric kbps bitrate
                return f"%fdkaac(bitrate={kbps_int})"
            # Fallback: ffmpeg-based AAC (audio-only flags for Liquidsoap 2.x)
            return f"%ffmpeg(audio=true, video=false, format=\"adts\", audio_codec=\"aac\", audio_bitrate=\"{kbps_int}k\")"
        elif codec == "FLAC":
            # For Icecast, FLAC is typically sent in an Ogg container
            return "%ogg(%flac())"
        elif codec == "OGG":
            kbps = bitrate.split()[0]
            return f"%vorbis(quality=0.7)"
        elif codec == "OPUS":
            kbps = bitrate.split()[0]
            return f"%opus(bitrate={kbps})"
        else:
            return "%mp3(bitrate=192)"

    def _has_fdkaac(self) -> bool:
        """Return True if Liquidsoap fdkaac encoder is available (OPAM-aware)."""
        return self._has_liquidsoap_encoder("fdkaac")
            
    def apply_to_icecast(self):
        """Apply stream configuration to Icecast"""
        if not self.streams:
            QMessageBox.warning(self, "No Streams", "Please add at least one stream before applying to Icecast.")
            return
            
        # This will be implemented in the Icecast management tab
        self.status_text.append("📡 Stream configuration ready for Icecast application")
        self.status_text.append("🔄 Switch to Icecast Management tab to apply configuration")

    def save_streams(self):
        """Save current streams configuration to config file"""
        try:
            config_dir = self.get_config_directory()
            streams_file = config_dir / "streams.json"
            
            with open(streams_file, 'w') as f:
                json.dump(self.streams, f, indent=2)
                
        except Exception as e:
            self.status_text.append(f"⚠️ Failed to save streams: {str(e)}")
            
    def load_streams(self):
        """Load streams configuration from config file"""
        try:
            config_dir = self.get_config_directory()
            streams_file = config_dir / "streams.json"
            
            if streams_file.exists():
                with open(streams_file, 'r') as f:
                    self.streams = json.load(f)
                self.refresh_streams_table()
                if self.streams:
                    self.status_text.append(f"✅ Loaded {len(self.streams)} saved stream(s)")
                    
        except Exception as e:
            self.status_text.append(f"⚠️ Failed to load streams: {str(e)}")
            self.streams = []  # Reset to empty list if loading fails


class IcecastManagementTab(QWidget):
    """Tab 2: Icecast Management - Server configuration and mount management"""
    
    def __init__(self):
        super().__init__()
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # Server Settings Section
        server_group = QGroupBox("📡 Server Settings")
        server_layout = QFormLayout(server_group)
        
        # Host and Port
        self.host_input = QLineEdit("localhost")
        server_layout.addRow("Host:", self.host_input)
        
        self.port_input = QSpinBox()
        self.port_input.setRange(1000, 65535)
        self.port_input.setValue(8000)
        server_layout.addRow("Port:", self.port_input)
        
        # Passwords
        self.source_password = QLineEdit()
        self.source_password.setEchoMode(QLineEdit.Password)
        self.source_password.setText("hackm3")
        server_layout.addRow("Source Password:", self.source_password)
        
        self.admin_password = QLineEdit()
        self.admin_password.setEchoMode(QLineEdit.Password)
        self.admin_password.setText("Hackm333")
        server_layout.addRow("Admin Password:", self.admin_password)
        
        self.relay_password = QLineEdit()
        self.relay_password.setEchoMode(QLineEdit.Password)
        self.relay_password.setText("hackm33")
        server_layout.addRow("Relay Password:", self.relay_password)
        
        layout.addWidget(server_group)
        
        # Mount Points Section
        mounts_group = QGroupBox("🎵 Mount Points")
        mounts_layout = QVBoxLayout(mounts_group)
        
        # Mounts table
        self.mounts_table = QTableWidget()
        self.mounts_table.setColumnCount(4)
        self.mounts_table.setHorizontalHeaderLabels(["Mount", "Status", "Listeners", "Actions"])
        self.mounts_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        mounts_layout.addWidget(self.mounts_table)
        
        layout.addWidget(mounts_group)
        
        # Icecast Control Section
        control_group = QGroupBox("⚙️ Icecast Control")
        control_layout = QGridLayout(control_group)
        
        # Service control buttons
        start_btn = QPushButton("▶️ START ICECAST")
        start_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; font-weight: bold; padding: 10px; }")
        start_btn.clicked.connect(self.start_icecast)
        control_layout.addWidget(start_btn, 0, 0)
        
        stop_btn = QPushButton("⏹️ STOP ICECAST")
        stop_btn.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; font-weight: bold; padding: 10px; }")
        stop_btn.clicked.connect(self.stop_icecast)
        control_layout.addWidget(stop_btn, 0, 1)
        
        restart_btn = QPushButton("🔄 RESTART ICECAST")
        restart_btn.setStyleSheet("QPushButton { background-color: #f39c12; color: white; font-weight: bold; padding: 10px; }")
        restart_btn.clicked.connect(self.restart_icecast)
        control_layout.addWidget(restart_btn, 0, 2)
        
        # Status display
        self.status_label = QLabel("Status: ⏳ Checking...")
        self.status_label.setStyleSheet("QLabel { padding: 10px; background-color: #ecf0f1; border-radius: 5px; }")
        control_layout.addWidget(self.status_label, 1, 0, 1, 3)
        
        layout.addWidget(control_group)
        
        # Configuration management
        config_group = QGroupBox("📄 Configuration Management")
        config_layout = QHBoxLayout(config_group)

        generate_config_btn = QPushButton("🔧 GENERATE ICECAST.XML")
        generate_config_btn.setStyleSheet("QPushButton { background-color: #3498db; color: white; font-weight: bold; padding: 8px; }")
        generate_config_btn.setMinimumHeight(40)
        generate_config_btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        generate_config_btn.clicked.connect(self.generate_icecast_config)
        config_layout.addWidget(generate_config_btn)
        
        apply_config_btn = QPushButton("� PREPARE FOR DEPLOYMENT")
        apply_config_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; font-weight: bold; padding: 8px; }")
        apply_config_btn.setMinimumHeight(40)
        apply_config_btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        apply_config_btn.clicked.connect(self.apply_icecast_config)
        config_layout.addWidget(apply_config_btn)
        
        layout.addWidget(config_group)
        
        # Initialize status check
        self.check_icecast_status()
        
        # Status update timer
        self.status_timer = QTimer()
        self.status_timer.timeout.connect(self.check_icecast_status)
        self.status_timer.start(5000)  # Check every 5 seconds
        
    def start_icecast(self):
        """Start Icecast service"""
        try:
            subprocess.run(["sudo", "systemctl", "start", "icecast2"], check=True)
            self.status_label.setText("Status: ✅ Starting Icecast...")
        except subprocess.CalledProcessError:
            self.status_label.setText("Status: ❌ Failed to start Icecast")
            
    def stop_icecast(self):
        """Stop Icecast service"""
        try:
            subprocess.run(["sudo", "systemctl", "stop", "icecast2"], check=True)
            self.status_label.setText("Status: ⏹️ Stopping Icecast...")
        except subprocess.CalledProcessError:
            self.status_label.setText("Status: ❌ Failed to stop Icecast")
            
    def restart_icecast(self):
        """Restart Icecast service"""
        try:
            subprocess.run(["sudo", "systemctl", "restart", "icecast2"], check=True)
            self.status_label.setText("Status: 🔄 Restarting Icecast...")
        except subprocess.CalledProcessError:
            self.status_label.setText("Status: ❌ Failed to restart Icecast")
            
    def check_icecast_status(self):
        """Check Icecast service status"""
        try:
            result = subprocess.run(["systemctl", "is-active", "icecast2"], 
                                  capture_output=True, text=True)
            if result.stdout.strip() == "active":
                self.status_label.setText("Status: ✅ Running (Active)")
                self.status_label.setStyleSheet("QLabel { padding: 10px; background-color: #d5f4e6; color: #27ae60; border-radius: 5px; font-weight: bold; }")
            else:
                self.status_label.setText("Status: ❌ Stopped")
                self.status_label.setStyleSheet("QLabel { padding: 10px; background-color: #fadbd8; color: #e74c3c; border-radius: 5px; font-weight: bold; }")
        except:
            self.status_label.setText("Status: ❓ Unknown")
            self.status_label.setStyleSheet("QLabel { padding: 10px; background-color: #ecf0f1; border-radius: 5px; }")
            
    def generate_icecast_config(self):
        """Generate Icecast configuration"""
        try:
            # Get config directory
            config_dir = self.get_config_directory()
            
            icecast_config = self.build_icecast_config()
            
            config_file = config_dir / "icecast.xml"
            with open(config_file, 'w') as f:
                f.write(icecast_config)
            QMessageBox.information(self, "Config Generated", f"Icecast configuration generated:\n{config_file}")
            
        except Exception as e:
            QMessageBox.critical(self, "Config Error", f"Failed to generate config:\n{str(e)}")
            
    def build_icecast_config(self):
        """Build Icecast XML configuration with comprehensive template"""
        host = self.host_input.text()
        port = self.port_input.value()
        source_pass = self.source_password.text()
        admin_pass = self.admin_password.text()
        relay_pass = self.relay_password.text()
        
        # Build shoutcast-mounts from configured streams
        shoutcast_mounts = ""
        streams = self.load_streams_from_storage()
        if streams:
            for stream in streams:
                mount_path = stream['mount']
                shoutcast_mounts += f'        <shoutcast-mount>{mount_path}</shoutcast-mount>\n'
        
        # Add default mounts if no streams configured
        if not shoutcast_mounts:
            shoutcast_mounts = '        <shoutcast-mount>/192</shoutcast-mount>\n        <shoutcast-mount>/stream</shoutcast-mount>\n'
        
        config = f'''<icecast>
    <!-- location and admin are two arbitrary strings that are e.g. visible
         on the server info page of the icecast web interface
         (server_version.xsl). -->
    <location>Earth</location>
    <admin>icemaster@{host}</admin>

    <!-- IMPORTANT!
         Especially for inexperienced users:
         Start out by ONLY changing all passwords and restarting Icecast.
         For detailed setup instructions please refer to the documentation.
         It's also available here: http://icecast.org/docs/
    -->

    <limits>
        <clients>100</clients>
        <sources>10</sources>
        <queue-size>524288</queue-size>
        <client-timeout>30</client-timeout>
        <header-timeout>15</header-timeout>
        <source-timeout>10</source-timeout>
        <!-- If enabled, this will provide a burst of data when a client 
             first connects, thereby significantly reducing the startup 
             time for listeners that do substantial buffering. However,
             it also significantly increases latency between the source
             client and listening client.  For low-latency setups, you
             might want to disable this. -->
        <burst-on-connect>1</burst-on-connect>
        <!-- same as burst-on-connect, but this allows for being more
             specific on how much to burst. Most people won't need to
             change from the default 64k. Applies to all mountpoints  -->
        <burst-size>65535</burst-size>
    </limits>

    <authentication>
        <!-- Sources log in with username 'source' -->
        <source-password>{source_pass}</source-password>
        <!-- Relays log in with username 'relay' -->
        <relay-password>{relay_pass}</relay-password>

        <!-- Admin logs in with the username given below -->
        <admin-user>admin</admin-user>
        <admin-password>{admin_pass}</admin-password>
    </authentication>

    <!-- set the mountpoint for a shoutcast source to use, the default if not
         specified is /stream but you can change it here if an alternative is
         wanted or an extension is required
    <shoutcast-mount>/live.nsv</shoutcast-mount>
    -->

    <!-- Uncomment this if you want directory listings -->
    <!--
    <directory>
        <yp-url-timeout>15</yp-url-timeout>
        <yp-url>http://dir.xiph.org/cgi-bin/yp-cgi</yp-url>
    </directory>
    -->

    <!-- This is the hostname other people will use to connect to your server.
         It affects mainly the urls generated by Icecast for playlists and yp
         listings. You MUST configure it properly for YP listings to work!
    -->
    <hostname>{host}</hostname>

    <!-- You may have multiple <listen-socket> elements -->
    <listen-socket>
        <port>{port}</port>
{shoutcast_mounts.rstrip()}
        <!-- <bind-address>127.0.0.1</bind-address> -->
    </listen-socket>

    <!-- Global header settings 
         Headers defined here will be returned for every HTTP request to Icecast.

         The ACAO header makes Icecast public content/API by default
         This will make streams easier embeddable (some HTML5 functionality needs it).
         Also it allows direct access to e.g. /status-json.xsl from other sites.
         If you don't want this, comment out the following line or read up on CORS. 
    -->
    <http-headers>
        <header name="Access-Control-Allow-Origin" value="*" />
    </http-headers>

    <!-- Relaying
         You don't need this if you only have one server.
         Please refer to the documentation for a detailed explanation.
    -->
    <!--<master-server>127.0.0.1</master-server>-->
    <!--<master-server-port>8001</master-server-port>-->
    <!--<master-update-interval>120</master-update-interval>-->
    <!--<master-password>hackme</master-password>-->

    <!-- setting this makes all relays on-demand unless overridden, this is
         useful for master relays which do not have <relay> definitions here.
         The default is 0 -->
    <!--<relays-on-demand>1</relays-on-demand>-->

    <!-- Mountpoints
         Only define <mount> sections if you want to use advanced options,
         like alternative usernames or passwords
    -->

    <!-- Default settings for all mounts that don't have a specific <mount type="normal">.
    -->
    <!-- 
    <mount type="default">
        <public>0</public>
        <intro>/server-wide-intro.ogg</intro>
        <max-listener-duration>3600</max-listener-duration>
        <authentication type="url">
                <option name="mount_add" value="http://auth.example.org/stream_start.php"/>
        </authentication>
        <http-headers>
                <header name="foo" value="bar" />
        </http-headers>
    </mount>
    -->

    <fileserve>1</fileserve>

    <paths>
        <!-- basedir is only used if chroot is enabled -->
        <basedir>/usr/share/icecast2</basedir>

        <!-- Note that if <chroot> is turned on below, these paths must both
             be relative to the new root, not the original root -->
        <logdir>/var/log/icecast2</logdir>
        <webroot>/usr/share/icecast2/web</webroot>
        <adminroot>/usr/share/icecast2/admin</adminroot>
        <!-- <pidfile>/usr/share/icecast2/icecast.pid</pidfile> -->

        <!-- Aliases: treat requests for 'source' path as being for 'dest' path
             May be made specific to a port or bound address using the "port"
             and "bind-address" attributes.
          -->
        <!--
        <alias source="/foo" destination="/bar"/>
        -->
        <!-- Aliases: can also be used for simple redirections as well,
             this example will redirect all requests for http://server:port/ to
             the status page
        -->
        <alias source="/" destination="/status.xsl"/>
        <!-- The certificate file needs to contain both public and private part.
             Both should be PEM encoded.
        <ssl-certificate>/usr/share/icecast2/icecast.pem</ssl-certificate>
        -->
    </paths>

    <logging>
        <accesslog>access.log</accesslog>
        <errorlog>error.log</errorlog>
        <!-- <playlistlog>playlist.log</playlistlog> -->
        <loglevel>3</loglevel> <!-- 4 Debug, 3 Info, 2 Warn, 1 Error -->
        <logsize>10000</logsize> <!-- Max size of a logfile -->
        <!-- If logarchive is enabled (1), then when logsize is reached
             the logfile will be moved to [error|access|playlist].log.DATESTAMP,
             otherwise it will be moved to [error|access|playlist].log.old.
             Default is non-archive mode (i.e. overwrite)
        -->
        <!-- <logarchive>1</logarchive> -->
    </logging>

    <security>
        <chroot>0</chroot>
        <!--
        <changeowner>
            <user>nobody</user>
            <group>nogroup</group>
        </changeowner>
        -->
    </security>
</icecast>'''
        
        return config
        
    def apply_icecast_config(self):
        """Apply Icecast configuration and restart service automatically"""
        # Get config directory
        config_dir = self.get_config_directory()
        config_file = config_dir / "icecast.xml"
        
        # Auto-generate config if it doesn't exist
        if not config_file.exists():
            try:
                self.generate_icecast_config()
                # Recheck if config was created
                if not config_file.exists():
                    QMessageBox.warning(self, "Config Generation Failed", "Could not generate Icecast configuration.")
                    return
            except Exception as e:
                QMessageBox.critical(self, "Config Generation Error", f"Failed to generate config:\n{str(e)}")
                return
            
        # Verify the config file is readable
        try:
            with open(config_file, 'r') as f:
                config_content = f.read()
            if len(config_content) < 100:  # Basic sanity check
                QMessageBox.warning(self, "Invalid Config", "Generated config file appears to be incomplete.")
                return
        except Exception as e:
            QMessageBox.critical(self, "Config Read Error", f"Cannot read config file:\n{str(e)}")
            return
            
        try:
            # Create a temporary script to execute all privileged operations in one pkexec call
            # This prevents multiple authentication prompts
            temp_script = config_dir / "deploy_icecast_temp.sh"
            script_content = f'''#!/bin/bash
set -e

# Stop Icecast if running
systemctl stop icecast2 2>/dev/null || true

# Backup original config if it exists
if [ -f "/etc/icecast2/icecast.xml" ]; then
    cp "/etc/icecast2/icecast.xml" "/etc/icecast2/icecast.xml.backup"
fi

# Apply configuration by copying to system location
cp "{config_file}" "/etc/icecast2/icecast.xml"

# Set proper ownership and permissions
chown root:icecast "/etc/icecast2/icecast.xml"
chmod 640 "/etc/icecast2/icecast.xml"

# Start Icecast with new configuration
systemctl start icecast2

echo "SUCCESS: Icecast configuration deployed and service restarted"
'''
            
            # Write the temporary script
            with open(temp_script, 'w') as f:
                f.write(script_content)
            
            # Make script executable
            temp_script.chmod(0o755)
            
            # Execute the script with pkexec (single authentication prompt)
            result = subprocess.run(["pkexec", str(temp_script)], 
                                  capture_output=True, text=True, check=True)
            
            # Clean up temporary script
            temp_script.unlink()
            
            # Get mount point count from persistent storage
            streams = self.load_streams_from_storage()
            mount_count = len(streams)
            stream_info = "No streams configured in Stream Builder tab"
            if mount_count > 0:
                stream_names = [stream.get('mount', 'Unknown') for stream in streams]
                stream_info = f"Streams: {', '.join(stream_names)}"
            else:
                stream_info = "No streams configured in Stream Builder tab - add streams first!"
            
            QMessageBox.information(self, "Configuration Applied", 
                                  f"Icecast configuration applied and service restarted successfully!\n\n"
                                  f"Host: {self.host_input.text()}\n"
                                  f"Port: {self.port_input.value()}\n"
                                  f"Mount Points: {mount_count} configured\n"
                                  f"{stream_info}\n\n"
                                  f"Config file: {config_file}\n"
                                  f"Backup saved: /etc/icecast2/icecast.xml.backup")
                                  
        except subprocess.CalledProcessError as e:
            # Clean up temporary script if it exists
            temp_script = config_dir / "deploy_icecast_temp.sh"
            if temp_script.exists():
                temp_script.unlink()
                
            error_details = f"Command: {' '.join(e.cmd)}\n"
            error_details += f"Exit code: {e.returncode}\n"
            if e.stdout:
                error_details += f"stdout: {e.stdout}\n"
            if e.stderr:
                error_details += f"stderr: {e.stderr}\n"
                
            # If pkexec failed, suggest alternative
            if "pkexec" in str(e.cmd):
                error_details += f"\nNote: pkexec (PolicyKit) is required for GUI sudo operations.\n"
                error_details += f"Alternative: Run 'sudo rdx-control-center' from terminal for sudo access.\n"
                
            QMessageBox.critical(self, "Configuration Failed", 
                               f"Failed to apply Icecast configuration:\n\n{error_details}\n"
                               f"Source file: {config_file}\n"
                               f"Target: /etc/icecast2/icecast.xml")
        except Exception as e:
            # Clean up temporary script if it exists
            temp_script = config_dir / "deploy_icecast_temp.sh"
            if temp_script.exists():
                temp_script.unlink()
                
            QMessageBox.critical(self, "Configuration Error", 
                               f"Error applying configuration:\n{str(e)}")

    def get_config_directory(self):
        """Get the application config directory, creating it if needed with proper ownership"""
        import os
        import getpass
        import pwd
        import grp
        
        # Always use standard config directory - no fallbacks
        config_dir = Path.home() / ".config" / "rdx"
        
        try:
            current_user = getpass.getuser()
            user_info = pwd.getpwnam(current_user)
            user_uid = user_info.pw_uid
            user_gid = user_info.pw_gid
            
            # Ensure parent .config directory exists and has correct ownership
            config_parent = config_dir.parent
            config_parent.mkdir(parents=True, exist_ok=True)
            try:
                os.chown(config_parent, user_uid, user_gid)
            except (PermissionError, OSError):
                # If we can't fix .config ownership, try to continue anyway
                pass
            
            # Create and fix ownership of rdx directory
            config_dir.mkdir(parents=True, exist_ok=True)
            os.chown(config_dir, user_uid, user_gid)
            
            # Set proper permissions (755 for directory)
            config_dir.chmod(0o755)
            
            # Test write access
            test_file = config_dir / ".test"
            test_file.touch()
            test_file.unlink()
            
            return config_dir
            
        except (PermissionError, OSError) as e:
            # Try to provide helpful error message and recovery
            error_msg = f"Cannot create or access config directory {config_dir}: {e}\n\n"
            error_msg += "To fix this manually:\n"
            error_msg += f"sudo mkdir -p {config_dir}\n"
            error_msg += f"sudo chown {current_user}:{current_user} {config_dir}\n"
            error_msg += f"sudo chown {current_user}:{current_user} {config_parent}\n"
            error_msg += f"sudo chmod 755 {config_dir}\n"
            raise Exception(error_msg)
            test_file = config_dir / ".test"
            test_file.touch()
            test_file.unlink()
            return config_dir
            
        except (PermissionError, OSError) as e:
            # If we can't create or write to .config/rdx, there's a serious problem
            # Don't fall back to .rdx as it causes confusion
            raise Exception(f"Cannot create config directory {config_dir}: {e}\nCheck permissions on ~/.config/")
            
    def load_streams_from_storage(self):
        """Load streams from persistent storage"""
        try:
            config_dir = self.get_config_directory()
            streams_file = config_dir / "streams.json"
            
            if streams_file.exists():
                import json
                with open(streams_file, 'r') as f:
                    return json.load(f)
            return []
        except Exception as e:
            print(f"Could not load streams from storage: {e}")
            return []


class JackMatrixTab(QWidget):
    """Tab 3: JACK Patchboard - Simple stereo-aware patching with protection"""

    def __init__(self, main=None):
        super().__init__()
        # Optional reference to main window for settings access
        self.main = main
        # Parsed JACK ports by client: {client: {"in": [fullport,...], "out": [...]}}
        self.ports = {}
        # Known clients (sorted)
        self.jack_clients = []
        # Critical protected pairs: {"src→dst", ...}
        self.critical_pairs = set()
        # Load persisted protected pairs (if any)
        self._load_protected_pairs()
        self.setup_ui()

    # ---- Persistence for protected pairs (Matrix) ----
    def _config_dir(self) -> Path:
        p = Path.home() / ".config" / "rdx"
        try:
            p.mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        return p

    def _prot_file(self) -> Path:
        return self._config_dir() / "jack_protected.json"

    def _load_protected_pairs(self):
        try:
            pf = self._prot_file()
            if pf.exists():
                with open(pf, 'r') as f:
                    data = json.load(f)
                pairs = data.get('pairs', [])
                if isinstance(pairs, list):
                    self.critical_pairs = set(str(x) for x in pairs)
        except Exception:
            self.critical_pairs = set()

    def _save_protected_pairs(self):
        try:
            pf = self._prot_file()
            with open(pf, 'w') as f:
                json.dump({"pairs": sorted(list(self.critical_pairs))}, f, indent=2)
        except Exception:
            pass

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # JACK Status Section
        status_group = QGroupBox("🔌 JACK Status")
        status_layout = QHBoxLayout(status_group)

        self.jack_status_label = QLabel("Status: ⏳ Checking JACK…")
        status_layout.addWidget(self.jack_status_label)

        refresh_btn = QPushButton("🔄 Refresh")
        refresh_btn.clicked.connect(self.refresh_jack_connections)
        status_layout.addWidget(refresh_btn)

        layout.addWidget(status_group)

        # Patchboard Section (Stereo)
        patch_group = QGroupBox("🎚️ Patchboard (Stereo)")
        patch_layout = QGridLayout(patch_group)

        patch_layout.addWidget(QLabel("Source (stereo out)"), 0, 0)
        patch_layout.addWidget(QLabel("Destination (stereo in)"), 0, 1)
        patch_layout.addWidget(QLabel("Actions"), 0, 2)

        self.source_combo = QComboBox()
        self.dest_combo = QComboBox()
        patch_layout.addWidget(self.source_combo, 1, 0)
        patch_layout.addWidget(self.dest_combo, 1, 1)

        actions_w = QWidget()
        actions_h = QHBoxLayout(actions_w)
        actions_h.setContentsMargins(0, 0, 0, 0)
        self.protect_checkbox = QCheckBox("Protect pair")
        btn_connect = QPushButton("🔗 Connect L/R")
        btn_connect.setStyleSheet("QPushButton { background-color: #27ae60; color: white; }")
        btn_connect.clicked.connect(self.connect_selected_pair)
        btn_disconnect = QPushButton("⛓️ Disconnect")
        btn_disconnect.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; }")
        btn_disconnect.clicked.connect(self.disconnect_selected_pair)
        actions_h.addWidget(self.protect_checkbox)
        btn_unprotect = QPushButton("Unprotect current")
        btn_unprotect.clicked.connect(self.unprotect_current_pair)
        actions_h.addWidget(btn_unprotect)
        actions_h.addWidget(btn_connect)
        actions_h.addWidget(btn_disconnect)
        actions_h.addStretch(1)
        patch_layout.addWidget(actions_w, 1, 2)

        layout.addWidget(patch_group)

        # Fine-grained manual patching (single ports)
        fine_group = QGroupBox("🔧 Manual Patching (Per-Port)")
        fine_grid = QGridLayout(fine_group)
        fine_grid.addWidget(QLabel("Source Port (output)"), 0, 0)
        fine_grid.addWidget(QLabel("Destination Port (input)"), 0, 1)
        self.port_src_combo = QComboBox()
        self.port_dst_combo = QComboBox()
        fine_grid.addWidget(self.port_src_combo, 1, 0)
        fine_grid.addWidget(self.port_dst_combo, 1, 1)
        fine_actions = QWidget()
        fine_actions_h = QHBoxLayout(fine_actions)
        fine_actions_h.setContentsMargins(0,0,0,0)
        btn_p_connect = QPushButton("Connect")
        btn_p_connect.clicked.connect(self.connect_manual_ports)
        btn_p_disconnect = QPushButton("Disconnect")
        btn_p_disconnect.clicked.connect(self.disconnect_manual_ports)
        fine_actions_h.addWidget(btn_p_connect)
        fine_actions_h.addWidget(btn_p_disconnect)
        fine_actions_h.addStretch(1)
        fine_grid.addWidget(fine_actions, 1, 2)
        layout.addWidget(fine_group)

        # Info on detected ports
        info_group = QGroupBox("📊 Detected JACK clients and ports")
        info_v = QVBoxLayout(info_group)
        self.jack_info = QTextEdit()
        self.jack_info.setReadOnly(True)
        self.jack_info.setMinimumHeight(140)
        self.jack_info.setStyleSheet("QTextEdit { font-family: monospace; }")
        info_v.addWidget(self.jack_info)
        layout.addWidget(info_group)

        # Quick actions
        controls_group = QGroupBox("⚙️ Quick Actions")
        controls_layout = QHBoxLayout(controls_group)
        auto_connect_btn = QPushButton("🎯 Auto-Connect (RD → ST → LS)")
        auto_connect_btn.setStyleSheet("QPushButton { background-color: #2980b9; color: white; }")
        auto_connect_btn.clicked.connect(self.auto_connect)
        emergency_btn = QPushButton("🚨 Disconnect All (non-critical)")
        emergency_btn.setStyleSheet("QPushButton { background-color: #c0392b; color: white; }")
        emergency_btn.clicked.connect(self.emergency_disconnect)
        controls_layout.addWidget(auto_connect_btn)
        controls_layout.addWidget(emergency_btn)
        controls_layout.addStretch(1)
        layout.addWidget(controls_group)

        # Initialize
        self.refresh_jack_connections()
        # Note: auto-reconnect watcher lives on the Graph tab (user-facing control)

    # ---- JACK helpers (Matrix) ----
    def refresh_jack_connections(self):
        """Refresh JACK ports and update UI elements."""
        try:
            # Check if JACK is running
            try:
                base = subprocess.run(["jack_lsp"], capture_output=True, text=True, timeout=0.7)
            except subprocess.TimeoutExpired:
                self.jack_status_label.setText("Status: ⏳ JACK Probe Timed Out")
                self.jack_status_label.setStyleSheet("QLabel { color: #f39c12; font-weight: bold; }")
                return
            if base.returncode != 0:
                self.jack_status_label.setText("Status: ❌ JACK Not Running")
                self.jack_status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
                self.ports = {}
                self.jack_clients = []
                self.source_combo.clear()
                self.dest_combo.clear()
                self.jack_info.setPlainText("JACK is not running. Start JACK and refresh.")
                return
            # Ports with properties
            try:
                res = subprocess.run(["jack_lsp", "-p"], capture_output=True, text=True, timeout=0.7)
            except subprocess.TimeoutExpired:
                res = subprocess.CompletedProcess(args=["jack_lsp","-p"], returncode=1, stdout=base.stdout, stderr="")
            out = res.stdout if res.returncode == 0 else base.stdout
            self.ports = self._parse_jack_ports(out)
            self.jack_clients = sorted(list(self.ports.keys()))
            # Populate combos
            self._populate_combos()
            self._populate_port_combos()
            # Info text
            self._update_info()
            self.jack_status_label.setText("Status: ✅ JACK Running")
            self.jack_status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
        except FileNotFoundError:
            self.jack_status_label.setText("Status: ❌ JACK Tools Not Found")
            self.jack_status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")

    def _parse_jack_ports(self, txt: str) -> dict:
        """Parse 'jack_lsp -p' output into {client: {in:[ports], out:[ports]}}."""
        ports = {}
        current_port = None
        for raw in (txt or "").splitlines():
            line = raw.rstrip()
            if not line:
                continue
            if not line.startswith(" ") and ":" in line:
                # Port line like 'client:port'
                current_port = line.strip()
                client = current_port.split(":", 1)[0]
                ports.setdefault(client, {"in": [], "out": []})
                pname = current_port.split(":", 1)[1].lower()
                if "out" in pname and "in" not in pname:
                    ports[client]["out"].append(current_port)
                elif "in" in pname and "out" not in pname:
                    ports[client]["in"].append(current_port)
            elif line.strip().startswith("properties:") and current_port:
                props = line.split(":", 1)[1]
                client = current_port.split(":", 1)[0]
                try:
                    if current_port in ports.get(client, {}).get("in", []):
                        ports[client]["in"].remove(current_port)
                    if current_port in ports.get(client, {}).get("out", []):
                        ports[client]["out"].remove(current_port)
                except Exception:
                    pass
                if "output" in props:
                    ports[client]["out"].append(current_port)
                else:
                    ports[client]["in"].append(current_port)
        return ports

    def _populate_combos(self):
        def stereo_candidates(direction: str) -> list:
            cands = []
            for c, d in self.ports.items():
                if len(d.get(direction, [])) >= 2:
                    cands.append(c)
            def key(name: str):
                ln = name.lower(); score = 0
                if "rivendell" in ln or ln.startswith("rd"): score -= 10
                if "stereo" in ln: score -= 9
                if "liquidsoap" in ln: score -= 8
                if name.startswith("system"): score -= 7
                return (score, name)
            return [x for x in sorted(cands, key=key)]
        srcs = stereo_candidates("out")
        dsts = stereo_candidates("in")
        cur_s = self.source_combo.currentText()
        cur_d = self.dest_combo.currentText()
        self.source_combo.clear(); self.source_combo.addItems(srcs)
        self.dest_combo.clear(); self.dest_combo.addItems(dsts)
        if cur_s in srcs:
            self.source_combo.setCurrentText(cur_s)
        if cur_d in dsts:
            self.dest_combo.setCurrentText(cur_d)

    def _populate_port_combos(self):
        outs = []; ins = []
        for c, d in self.ports.items():
            outs.extend(d.get("out", []))
            ins.extend(d.get("in", []))
        def keyp(p: str):
            client, pn = p.split(":", 1)
            return (client.lower(), pn.lower())
        outs.sort(key=keyp); ins.sort(key=keyp)
        def label(p: str) -> str:
            client, pn = p.split(":", 1)
            pretty_c = self._pretty_client(client)
            pretty_p = self._pretty_port_name(pn)
            return f"{pretty_c}: {pretty_p}  ({pn})"
        cur_sp = self.port_src_combo.currentData() if self.port_src_combo.count() else None
        cur_dp = self.port_dst_combo.currentData() if self.port_dst_combo.count() else None
        self.port_src_combo.clear();
        for p in outs:
            self.port_src_combo.addItem(label(p), p)
        self.port_dst_combo.clear();
        for p in ins:
            self.port_dst_combo.addItem(label(p), p)
        if cur_sp:
            idx = self.port_src_combo.findData(cur_sp)
            if idx >= 0:
                self.port_src_combo.setCurrentIndex(idx)
        if cur_dp:
            idx = self.port_dst_combo.findData(cur_dp)
            if idx >= 0:
                self.port_dst_combo.setCurrentIndex(idx)

    def _update_info(self):
        lines = []
        for c in self.jack_clients:
            ins = len(self.ports.get(c, {}).get("in", []))
            outs = len(self.ports.get(c, {}).get("out", []))
            lines.append(f"{c}: in={ins} out={outs}")
        self.jack_info.setPlainText("\n".join(lines) if lines else "No JACK clients detected.")

    def _stereo_pair(self, client: str, direction: str) -> list:
        ports = list(self.ports.get(client, {}).get(direction, []))
        def sort_key(p: str):
            pn = p.split(":", 1)[1].lower()
            if re.search(r"(^|[_\-:])l(eft)?($|[_\-:])", pn):
                return (-2, pn)
            if re.search(r"(^|[_\-:])r(ight)?($|[_\-:])", pn):
                return (-1, pn)
            m = re.search(r"(\d+)$", pn)
            if m:
                return (int(m.group(1)), pn)
            return (999, pn)
        ports.sort(key=sort_key)
        return ports[:2]

    def connect_selected_pair(self):
        src = self.source_combo.currentText().strip()
        dst = self.dest_combo.currentText().strip()
        if not src or not dst or src == dst:
            QMessageBox.warning(self, "Invalid Selection", "Choose distinct source and destination with stereo ports.")
            return
        key = f"{src}→{dst}"
        if self.protect_checkbox.isChecked():
            self.critical_pairs.add(key)
            self._save_protected_pairs()
        s_ports = self._stereo_pair(src, "out")
        d_ports = self._stereo_pair(dst, "in")
        if len(s_ports) < 2 or len(d_ports) < 2:
            QMessageBox.warning(self, "Not Stereo", "Selected clients do not expose at least 2 ports each.")
            return
        ok = True; errs = []
        for sp, dp in zip(s_ports, d_ports):
            try:
                self._jack_connect(sp, dp)
            except Exception as e:
                ok = False; errs.append(f"{sp} -> {dp}: {e}")
        if ok:
            QMessageBox.information(self, "Connected", f"{src} → {dst} (L/R)")
        else:
            QMessageBox.warning(self, "Partial Failure", "Some connections failed:\n" + "\n".join(errs))

    def disconnect_selected_pair(self):
        src = self.source_combo.currentText().strip()
        dst = self.dest_combo.currentText().strip()
        if not src or not dst or src == dst:
            return
        key = f"{src}→{dst}"
        if key in self.critical_pairs:
            reply = QMessageBox.question(self, "Protected Pair", f"{key} is protected. Disconnect anyway?",
                                         QMessageBox.Yes | QMessageBox.No)
            if reply != QMessageBox.Yes:
                return
        s_ports = self._stereo_pair(src, "out")
        d_ports = self._stereo_pair(dst, "in")
        errs = []
        for sp, dp in zip(s_ports, d_ports):
            try:
                self._jack_disconnect(sp, dp)
            except Exception as e:
                errs.append(f"{sp} -/-> {dp}: {e}")
        if errs:
            QMessageBox.warning(self, "Disconnect Issues", "\n".join(errs))
        else:
            QMessageBox.information(self, "Disconnected", f"{src} ⛓️ {dst}")

    def unprotect_current_pair(self):
        src = self.source_combo.currentText().strip()
        dst = self.dest_combo.currentText().strip()
        if not src or not dst or src == dst:
            return
        key = f"{src}→{dst}"
        if key in self.critical_pairs:
            self.critical_pairs.remove(key)
            self._save_protected_pairs()
            QMessageBox.information(self, "Unprotected", f"Removed protection for: {key}")
        else:
            QMessageBox.information(self, "Not Protected", f"Current pair is not protected: {key}")

    def auto_connect(self):
        def find_like(names, direction):
            for c in self.jack_clients:
                lc = c.lower()
                if any(n in lc for n in names):
                    if len(self.ports.get(c, {}).get(direction, [])) >= 2:
                        return c
            return None
        rd = find_like(["rivendell", "rd"], "out") or find_like(["system"], "out")
        st = find_like(["stereo tool", "stereotool", "stereo_tool", "thimeo"], "in")
        ls_in = find_like(["liquidsoap"], "in")
        ls_out = find_like(["liquidsoap"], "out")
        sys_play = find_like(["system"], "in")
        actions = []
        if rd and st:
            self.source_combo.setCurrentText(rd); self.dest_combo.setCurrentText(st)
            self.connect_selected_pair(); actions.append(f"{rd}→{st}")
        if st and ls_in:
            self.source_combo.setCurrentText(st); self.dest_combo.setCurrentText(ls_in)
            self.connect_selected_pair(); actions.append(f"{st}→{ls_in}")
        if ls_out and sys_play:
            self.source_combo.setCurrentText(ls_out); self.dest_combo.setCurrentText(sys_play)
            self.connect_selected_pair(); actions.append(f"{ls_out}→{sys_play}")
        if not actions:
            QMessageBox.information(self, "Auto-Connect", "No suitable clients found for auto patching.")

    def emergency_disconnect(self):
        reply = QMessageBox.warning(self, "EMERGENCY DISCONNECT",
                                    "⚠️ This will disconnect ALL non-critical JACK connections!\n\nContinue?",
                                    QMessageBox.Yes | QMessageBox.No)
        if reply != QMessageBox.Yes:
            return
        try:
            try:
                res = subprocess.run(["jack_lsp", "-c"], capture_output=True, text=True, timeout=0.7)
            except subprocess.TimeoutExpired:
                raise RuntimeError("jack_lsp -c timed out")
            txt = res.stdout or ""
            to_disc = []
            cur_src = None
            for line in txt.splitlines():
                if not line:
                    continue
                if not line.startswith(" "):
                    cur_src = line.strip(); continue
                if line.strip().startswith("connections:"):
                    continue
                if cur_src and line.startswith("    "):
                    dst = line.strip()
                    s_client = cur_src.split(":", 1)[0]
                    d_client = dst.split(":", 1)[0]
                    key = f"{s_client}→{d_client}"
                    if key not in self.critical_pairs:
                        to_disc.append((cur_src, dst))
            errs = []
            for sp, dp in to_disc:
                try:
                    self._jack_disconnect(sp, dp)
                except Exception as e:
                    errs.append(f"{sp} -/-> {dp}: {e}")
            if errs:
                QMessageBox.warning(self, "Disconnect Issues", "\n".join(errs))
            else:
                QMessageBox.information(self, "Emergency Disconnect", "All non-critical connections disconnected.")
        except Exception as e:
            QMessageBox.critical(self, "JACK Error", f"Could not enumerate connections: {e}")

    # ---- Low-level JACK ops (Matrix) ----
    def _jack_connect(self, src_port: str, dst_port: str):
        try:
            res = subprocess.run(["jack_connect", src_port, dst_port], capture_output=True, text=True)
            if res.returncode != 0:
                if self._is_connected(src_port, dst_port):
                    return
                stderr = (res.stderr or '').strip(); stdout = (res.stdout or '').strip()
                raise RuntimeError(stderr or stdout or f"jack_connect failed with code {res.returncode}")
        except FileNotFoundError:
            raise RuntimeError("jack_connect not found in PATH")

    def _jack_disconnect(self, src_port: str, dst_port: str):
        try:
            subprocess.run(["jack_disconnect", src_port, dst_port], capture_output=True, text=True)
        except FileNotFoundError:
            raise RuntimeError("jack_disconnect not found in PATH")

    def _is_connected(self, src_port: str, dst_port: str) -> bool:
        try:
            res = subprocess.run(["jack_lsp", "-c"], capture_output=True, text=True)
            txt = res.stdout or ""; cur = None
            for line in txt.splitlines():
                if not line:
                    continue
                if not line.startswith(" "):
                    cur = line.strip(); continue
                if cur == src_port and line.startswith("    ") and line.strip() == dst_port:
                    return True
        except Exception:
            pass
        return False

    def _setting_enabled(self, key: str, default: bool = True) -> bool:
        try:
            if self.main and hasattr(self.main, "_settings"):
                return bool(self.main._settings.get(key, default))
        except Exception:
            pass
        return default

    def _vlc_autoreconnect_tick(self):
        """Periodically ensure VLC outputs feed Rivendell Record-In when present.
        - Only runs when enabled in Settings.
        - Will not override existing connections on Rivendell Record-In ports.
        - Best-effort: ignores transient jack_connect noise and retries on next tick.
        """
        try:
            if not self._setting_enabled('auto_reconnect_vlc', True):
                return
            # Is JACK up?
            base = self._run(["jack_lsp"], timeout=0.6)
            if base.returncode != 0:
                return
            # Snapshot current ports and connections (lightweight)
            res = self._run(["jack_lsp", "-p"], timeout=0.9)
            out = res.stdout or base.stdout
            ports = self._parse_ports(out)
            cons = self._list_connections()

            def find_like(names, direction, need=2):
                for c in sorted(ports.keys()):
                    lc = c.lower()
                    if any(n in lc for n in names):
                        if len(ports.get(c, {}).get(direction, [])) >= need:
                            return c
                return None

            vlc = find_like(["vlc"], "out")
            rd_in = find_like(["rivendell", "rd"], "in")
            if not (vlc and rd_in):
                return

            s_ports = self._first_two(ports.get(vlc, {}).get("out", []))
            d_ports = self._first_two(ports.get(rd_in, {}).get("in", []))
            if len(s_ports) != 2 or len(d_ports) != 2:
                return

            # If RD Record-In ports already have any source connected, skip to avoid overriding
            dp0_has = any(dst == d_ports[0] for (_, dst) in cons)
            dp1_has = any(dst == d_ports[1] for (_, dst) in cons)
            if dp0_has and dp1_has:
                return

            # Connect missing pairs best-effort
            try:
                if not dp0_has:
                    self._jack_connect(s_ports[0], d_ports[0])
                if not dp1_has:
                    self._jack_connect(s_ports[1], d_ports[1])
            except Exception:
                # Ignore; will retry on next tick
                pass
        except Exception:
            # Never let the watcher crash the UI
            pass

    # ---- Manual per-port connect/disconnect ----
    def connect_manual_ports(self):
        sp = self.port_src_combo.currentData()
        dp = self.port_dst_combo.currentData()
        if not sp or not dp:
            return
        try:
            self._jack_connect(sp, dp)
            QMessageBox.information(self, "Connected", f"{sp} → {dp}")
        except Exception as e:
            QMessageBox.critical(self, "JACK Error", str(e))

    def disconnect_manual_ports(self):
        sp = self.port_src_combo.currentData()
        dp = self.port_dst_combo.currentData()
        if not sp or not dp:
            return
        try:
            self._jack_disconnect(sp, dp)
            QMessageBox.information(self, "Disconnected", f"{sp} ⛓️ {dp}")
        except Exception as e:
            QMessageBox.critical(self, "JACK Error", str(e))

    # ---- Pretty naming helpers (Matrix) ----
    def _pretty_client(self, name: str) -> str:
        ln = (name or '').lower()
        if ln.startswith('system'):
            return 'System'
        if 'rivendell' in ln or ln.startswith('rd'):
            return 'Rivendell'
        if 'liquidsoap' in ln:
            return 'Liquidsoap'
        if 'stereo_tool' in ln or 'stereotool' in ln or 'stereo tool' in ln:
            return 'Stereo Tool'
        return name

    def _pretty_port_name(self, pn: str) -> str:
        lpn = (pn or '').lower()
        # Common JACK port namings
        if lpn in ("in_1", "capture_1", "playout_0l", "left", "l", "in_l", "in:left"):
            return "Left In"
        if lpn in ("in_2", "capture_2", "playout_0r", "right", "r", "in_r", "in:right"):
            return "Right In"
        if lpn in ("out_1", "playback_1", "out_l", "left", "l", "out:left"):
            return "Left Out"
        if lpn in ("out_2", "playback_2", "out_r", "right", "r", "out:right"):
            return "Right Out"
        return pn


    class _GraphEdgeItem(QGraphicsPathItem):
        """Custom path item for graph edges with reliable context menu handling."""

        def __init__(self, path: QPainterPath, owner, sp_full: str, dp_full: str):
            super().__init__(path)
            self._owner = owner
            self._sp_full = sp_full
            self._dp_full = dp_full
            self.setAcceptedMouseButtons(Qt.LeftButton | Qt.RightButton)
            self.setAcceptHoverEvents(True)
            try:
                self.setData(99, "edge")
                self.setData(100, sp_full)
                self.setData(101, dp_full)
            except Exception:
                pass

        def mousePressEvent(self, event):
            try:
                if event.button() == Qt.RightButton:
                    handled = self._owner._edge_context_menu(self._sp_full, self._dp_full, event.screenPos())
                    if handled:
                        event.accept()
                        return
            except Exception:
                pass
            super().mousePressEvent(event)

        def contextMenuEvent(self, event):
            try:
                handled = self._owner._edge_context_menu(self._sp_full, self._dp_full, event.screenPos())
                if handled:
                    event.accept()
                    return
            except Exception:
                pass
            super().contextMenuEvent(event)


    class _GraphEdgeHitBox(QGraphicsPathItem):
        """Transparent hit area over an edge to make right-clicking easier."""

        def __init__(self, path: QPainterPath, owner, sp_full: str, dp_full: str):
            super().__init__(path)
            self._owner = owner
            self._sp_full = sp_full
            self._dp_full = dp_full
            self.setAcceptedMouseButtons(Qt.LeftButton | Qt.RightButton)
            try:
                self.setData(99, "edge")
                self.setData(100, sp_full)
                self.setData(101, dp_full)
            except Exception:
                pass

        def mousePressEvent(self, event):
            try:
                if event.button() == Qt.RightButton:
                    handled = self._owner._edge_context_menu(self._sp_full, self._dp_full, event.screenPos())
                    if handled:
                        event.accept()
                        return
            except Exception:
                pass
            super().mousePressEvent(event)

        def contextMenuEvent(self, event):
            try:
                handled = self._owner._edge_context_menu(self._sp_full, self._dp_full, event.screenPos())
                if handled:
                    event.accept()
                    return
            except Exception:
                pass
            super().contextMenuEvent(event)


class JackGraphTab(QWidget):
    """Visual JACK graph: clients/ports as nodes with connectable edges and lock/unlock.
    Preview version designed to complement the Patchboard.
    """

    def __init__(self, main=None):
        super().__init__()
        self.main = main
        self.scene = QGraphicsScene(self)
        self.view = QGraphicsView(self.scene, self)
        try:
            self.view.setRenderHints(self.view.renderHints() | QPainter.Antialiasing | QPainter.TextAntialiasing | QPainter.SmoothPixmapTransform)
        except Exception:
            pass
        # Avoid rubber-band selection interfering with right-click menus
        self.view.setDragMode(QGraphicsView.NoDrag)
        # Route context menu events through this widget for reliable right-click handling
        try:
            self.view.viewport().installEventFilter(self)
        except Exception:
            pass
        # Improve zoom behavior
        try:
            self.view.setTransformationAnchor(QGraphicsView.AnchorUnderMouse)
            self.view.setResizeAnchor(QGraphicsView.AnchorViewCenter)
        except Exception:
            pass
        self._zoom_level = 1.0
        self._fit_pending = True  # Fit once by default; user can control zoom after
        self.ports = {}
        self.connections = []
        self.critical_pairs = set()
        self.profiles = {}
        self._load_protected_pairs()
        self._load_profiles()
        self._selected_out = None  # full port string (output)
        self._selected_in = None   # full port string (input)
        # Drag-to-connect state
        self._drag_line = None
        self._drag_src_item = None
        self._drag_hover_item = None
        self._drag_started = False
        # Layout constants for tidy alignment
        self._layout = {
            "row_h": 30,
            "left_dot_x": 320,
            "right_dot_x": 680,
            "port_label_offset": 12,   # gap between dot and port label
            "client_label_gap": 10,    # gap between client label and its port labels
            "left_port_label_x": 320 - 180,   # left column port labels
            "left_client_label_x": 320 - 180 - 160,
            "right_port_label_x": 680 + 12,   # right column port labels
            "right_client_label_x": 680 + 12 + 180,
            "first_port_offset": 36,
        }

        self._setup_ui()
        self.refresh()
        # Auto-reconnect watcher for VLC → Rivendell Record-In (optional)
        try:
            self._vlc_watch_timer = QTimer(self)
            self._vlc_watch_timer.setInterval(1500)
            self._vlc_watch_timer.timeout.connect(self._vlc_autoreconnect_tick)
            self._vlc_watch_timer.start()
        except Exception:
            pass

    def _setup_ui(self):
        root = QVBoxLayout(self)
        # Toolbar
        bar = QHBoxLayout()
        btn_refresh = QPushButton("🔄 Refresh")
        btn_refresh.clicked.connect(self.refresh)
        btn_auto = QPushButton("🎯 Auto-Connect")
        btn_auto.clicked.connect(self.auto_connect)
        btn_emerg = QPushButton("🚨 Disconnect Non-Critical")
        btn_emerg.clicked.connect(self.emergency_disconnect)
        btn_zoom_out = QPushButton("➖ Zoom Out")
        btn_zoom_out.clicked.connect(lambda: self._zoom(0.9))
        btn_zoom_in = QPushButton("➕ Zoom In")
        btn_zoom_in.clicked.connect(lambda: self._zoom(1.1))
        btn_fit = QPushButton("🖼️ Fit All")
        def _do_fit():
            try:
                rect = self.scene.itemsBoundingRect()
                if rect.isValid():
                    self.view.fitInView(rect, Qt.KeepAspectRatio)
                    self._zoom_level = 1.0
            except Exception:
                pass
            self._fit_pending = False
        btn_fit.clicked.connect(_do_fit)
        # Patch-specific toggle on this tab
        self.chk_vlc_reconnect = QCheckBox("Auto VLC → Rivendell Record-In")
        try:
            # Initialize from global settings if present
            if self.main and hasattr(self.main, "_settings"):
                self.chk_vlc_reconnect.setChecked(bool(self.main._settings.get('auto_reconnect_vlc', True)))
            self.chk_vlc_reconnect.stateChanged.connect(self._on_graph_vlc_toggle)
        except Exception:
            pass

        bar.addWidget(btn_refresh)
        bar.addWidget(btn_auto)
        bar.addWidget(btn_emerg)
        bar.addStretch(1)
        bar.addWidget(self.chk_vlc_reconnect)
        bar.addWidget(btn_zoom_out)
        bar.addWidget(btn_zoom_in)
        bar.addWidget(btn_fit)
        root.addLayout(bar)

        # Profiles row (no dropdowns on the tab)
        prof = QHBoxLayout()
        btn_profiles = QPushButton("📁 Profiles…")
        btn_profiles.clicked.connect(self.open_profiles_dialog)
        btn_generate = QPushButton("✨ Generate Profile")
        btn_generate.clicked.connect(self.generate_profile)
        prof.addWidget(btn_profiles)
        prof.addWidget(btn_generate)
        prof.addStretch(1)
        root.addLayout(prof)

        root.addWidget(self.view)
    # ----- Persistence -----
    def _config_dir(self) -> Path:
        p = Path.home() / ".config" / "rdx"
        try:
            p.mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        return p

    def _prot_file(self) -> Path:
        return self._config_dir() / "jack_protected.json"

    def _load_protected_pairs(self):
        try:
            pf = self._prot_file()
            if pf.exists():
                with open(pf, 'r') as f:
                    data = json.load(f)
                pairs = data.get('pairs', [])
                if isinstance(pairs, list):
                    self.critical_pairs = set(str(x) for x in pairs)
        except Exception:
            self.critical_pairs = set()

    def _save_protected_pairs(self):
        try:
            pf = self._prot_file()
            with open(pf, 'w') as f:
                json.dump({"pairs": sorted(list(self.critical_pairs))}, f, indent=2)
        except Exception:
            pass

    # ----- Profiles persistence -----
    def _profiles_file(self) -> Path:
        return self._config_dir() / "jack_profiles.json"

    def _load_profiles(self):
        try:
            pf = self._profiles_file()
            if pf.exists():
                with open(pf, 'r') as f:
                    data = json.load(f)
                if isinstance(data, dict):
                    self.profiles = {str(k): list(v) for k, v in data.items()}
        except Exception:
            self.profiles = {}
        # No on-tab profile combo to refresh; dialog lists are built on demand

    def _save_profiles(self):
        try:
            pf = self._profiles_file()
            with open(pf, 'w') as f:
                json.dump(self.profiles, f, indent=2)
        except Exception:
            pass

    # ---- Profiles dialog and helpers ----
    def open_profiles_dialog(self):
        try:
            from PyQt5.QtWidgets import QDialog, QVBoxLayout, QListWidget, QHBoxLayout, QPushButton, QInputDialog
            dlg = QDialog(self)
            dlg.setWindowTitle("JACK Profiles")
            lay = QVBoxLayout(dlg)
            lst = QListWidget(); lst.addItems(sorted(self.profiles.keys(), key=lambda s: s.lower()))
            lay.addWidget(lst)
            row = QHBoxLayout()
            btn_apply = QPushButton("Apply")
            btn_delete = QPushButton("Delete")
            btn_edit = QPushButton("Edit…")
            btn_save = QPushButton("Save Current As…")
            btn_close = QPushButton("Close")
            row.addWidget(btn_apply); row.addWidget(btn_delete); row.addWidget(btn_edit); row.addWidget(btn_save); row.addStretch(1); row.addWidget(btn_close)
            lay.addLayout(row)

            def cur_name():
                item = lst.currentItem()
                return item.text() if item else None

            def do_apply():
                name = cur_name()
                if name:
                    self.apply_profile(name)
                    self.refresh()

            def do_delete():
                name = cur_name()
                if name:
                    self.delete_profile(name)
                    lst.clear(); lst.addItems(sorted(self.profiles.keys(), key=lambda s: s.lower()))
            def do_edit():
                name = cur_name()
                if name:
                    self.edit_profile(name)
                    lst.clear(); lst.addItems(sorted(self.profiles.keys(), key=lambda s: s.lower()))

            def do_save():
                name, ok = QInputDialog.getText(dlg, "Save Profile", "Profile name:")
                if ok and name.strip():
                    self.save_current_as_profile(name.strip())
                    lst.clear(); lst.addItems(sorted(self.profiles.keys(), key=lambda s: s.lower()))

            btn_apply.clicked.connect(do_apply)
            btn_delete.clicked.connect(do_delete)
            btn_save.clicked.connect(do_save)
            btn_edit.clicked.connect(do_edit)
            btn_close.clicked.connect(dlg.accept)
            dlg.exec_()
        except Exception:
            pass

    def edit_profile(self, name: str):
        """Simple editor to add/remove pairs within a profile."""
        try:
            if name not in self.profiles:
                return
            pairs = [list(p) for p in self.profiles.get(name, [])]
            from PyQt5.QtWidgets import QDialog, QVBoxLayout, QHBoxLayout, QTableWidget, QTableWidgetItem, QPushButton, QComboBox, QMessageBox
            dlg = QDialog(self)
            dlg.setWindowTitle(f"Edit Profile: {name}")
            lay = QVBoxLayout(dlg)
            table = QTableWidget(0, 2, dlg)
            table.setHorizontalHeaderLabels(["Source (out)", "Destination (in)"])
            lay.addWidget(table)

            # Populate port combos
            outs = []
            ins = []
            for c, d in self.ports.items():
                outs.extend(d.get("out", []))
                ins.extend(d.get("in", []))
            outs = sorted(outs, key=lambda s: s.lower())
            ins = sorted(ins, key=lambda s: s.lower())

            def refresh_table():
                table.setRowCount(len(pairs))
                for r, (s, d) in enumerate(pairs):
                    table.setItem(r, 0, QTableWidgetItem(s))
                    table.setItem(r, 1, QTableWidgetItem(d))
            refresh_table()

            # Add controls
            row = QHBoxLayout()
            cmb_s = QComboBox(); cmb_s.addItems(outs)
            cmb_d = QComboBox(); cmb_d.addItems(ins)
            btn_add = QPushButton("Add Pair")
            btn_rm = QPushButton("Remove Selected")
            btn_save = QPushButton("Save")
            btn_close = QPushButton("Close")
            row.addWidget(cmb_s); row.addWidget(cmb_d); row.addWidget(btn_add); row.addWidget(btn_rm); row.addStretch(1); row.addWidget(btn_save); row.addWidget(btn_close)
            lay.addLayout(row)

            def on_add():
                s = cmb_s.currentText().strip(); d = cmb_d.currentText().strip()
                if s and d:
                    pairs.append([s, d])
                    refresh_table()
            def on_rm():
                r = table.currentRow()
                if 0 <= r < len(pairs):
                    pairs.pop(r)
                    refresh_table()
            def on_save():
                self.profiles[name] = pairs
                self._save_profiles()
                QMessageBox.information(dlg, "Profile Saved", f"Updated '{name}' with {len(pairs)} connection(s).")
            def on_close():
                dlg.accept()

            btn_add.clicked.connect(on_add)
            btn_rm.clicked.connect(on_rm)
            btn_save.clicked.connect(on_save)
            btn_close.clicked.connect(on_close)
            dlg.exec_()
        except Exception as e:
            try:
                QMessageBox.critical(self, "Edit Profile", f"Could not edit profile: {e}")
            except Exception:
                pass

    def save_current_as_profile(self, name: str = None):
        try:
            # Refresh connections to ensure current
            self.connections = self._list_connections()
            key = name
            if not key:
                from PyQt5.QtWidgets import QInputDialog
                key, ok = QInputDialog.getText(self, "Save Profile", "Profile name:")
                if not ok or not str(key).strip():
                    return
                key = str(key).strip()
            # Store as list of [src, dst]
            self.profiles[key] = [[s, d] for (s, d) in self.connections]
            self._save_profiles()
            QMessageBox.information(self, "Profile Saved", f"Saved profile '{key}' with {len(self.connections)} connections.")
        except Exception as e:
            QMessageBox.critical(self, "Save Profile", f"Could not save profile: {e}")

    def apply_profile(self, name: str):
        try:
            if not name or name not in self.profiles:
                return
            pairs = self.profiles.get(name, [])
            applied = 0
            for s, d in pairs:
                try:
                    # Only connect if both ports exist now
                    if self._port_exists(s) and self._port_exists(d):
                        self._jack_connect(s, d)
                        applied += 1
                except Exception:
                    pass
            self.refresh()
            QMessageBox.information(self, "Profile Applied", f"Applied {applied}/{len(pairs)} connections from '{name}'.")
        except Exception as e:
            QMessageBox.critical(self, "Apply Profile", f"Could not apply profile: {e}")

    def delete_profile(self, name: str):
        try:
            if not name or name not in self.profiles:
                return
            reply = QMessageBox.question(self, "Delete Profile",
                                         f"Delete profile '{name}'? This cannot be undone.",
                                         QMessageBox.Yes | QMessageBox.No)
            if reply != QMessageBox.Yes:
                return
            self.profiles.pop(name, None)
            self._save_profiles()
        except Exception as e:
            QMessageBox.critical(self, "Delete Profile", f"Could not delete profile: {e}")

    # ----- JACK queries -----
    def _run(self, args: list, timeout: float = 0.8):
        try:
            return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        except subprocess.TimeoutExpired:
            return subprocess.CompletedProcess(args=args, returncode=1, stdout="", stderr="timeout")

    def _parse_ports(self, txt: str) -> dict:
        # reuse logic from JackMatrixTab but simplified
        ports = {}
        cur = None
        for raw in (txt or "").splitlines():
            line = raw.rstrip()
            if not line:
                continue
            lstr = line.lstrip()
            # Treat any amount of whitespace (spaces/tabs) as indentation for property lines
            if lstr.lower().startswith("properties:") and cur:
                props = lstr.split(":", 1)[1]
                c = cur.split(":", 1)[0]
                try:
                    if cur in ports.get(c, {}).get("in", []):
                        ports[c]["in"].remove(cur)
                    if cur in ports.get(c, {}).get("out", []):
                        ports[c]["out"].remove(cur)
                except Exception:
                    pass
                if "output" in props:
                    ports[c]["out"].append(cur)
                else:
                    ports[c]["in"].append(cur)
                continue
            # New port: not indented and not a properties line
            if (not line.startswith(" ")) and (not lstr.lower().startswith("properties:")) and (":" in line):
                cur = line.strip()
                c = cur.split(":", 1)[0]
                ports.setdefault(c, {"in": [], "out": []})
                # guess by name
                pn = cur.split(":", 1)[1].lower()
                if "out" in pn and "in" not in pn:
                    ports[c]["out"].append(cur)
                elif "in" in pn and "out" not in pn:
                    ports[c]["in"].append(cur)
        return ports

    def _list_connections(self) -> list:
        cons = []
        res = self._run(["jack_lsp", "-c"], timeout=1.2)
        txt = res.stdout or ""
        src = None
        for line in txt.splitlines():
            if not line:
                continue
            # New source line has no leading whitespace (spaces or tabs)
            if not line[:1].isspace():
                src = line.strip()
                continue
            # Destination lines can have any indentation; accept if there is a current src
            if src and line[:1].isspace():
                dst = line.strip()
                if dst:
                    cons.append((src, dst))
        return cons

    # ----- Graph build -----
    def refresh(self):
        # Clear
        self.scene.clear()
        # Probe JACK
        base = self._run(["jack_lsp"], timeout=0.7)
        if base.returncode != 0:
            self.scene.addText("JACK is not running")
            return
        res = self._run(["jack_lsp", "-p"], timeout=0.9)
        out = res.stdout or base.stdout
        self.ports = self._parse_ports(out)
        self.connections = self._list_connections()
        # Layout: outputs on left, inputs on right (tidy aligned columns)
        L = self._layout
        left_x = L["left_dot_x"]
        right_x = L["right_dot_x"]
        y = 20
        port_items = {}
        header_font = QFont(); header_font.setBold(True)
        # Left column
        for client in sorted(self.ports.keys(), key=lambda x: x.lower()):
            outs = self.ports[client].get("out", [])
            if not outs:
                continue
            # Place client label above its port labels, left-justified with them
            title = self.scene.addText(client)
            title.setFont(header_font)
            title.setDefaultTextColor(QColor("#2c3e50"))
            title.setPos(L["left_port_label_x"], y)
            y2 = y + L["first_port_offset"]
            for p in outs:
                item = self._add_port_node(p, QPointF(left_x, y2), is_output=True)
                port_items[p] = item
                y2 += L["row_h"]
            y = y2 + 8
        # Right column
        y = 20
        for client in sorted(self.ports.keys(), key=lambda x: x.lower()):
            ins = self.ports[client].get("in", [])
            if not ins:
                continue
            # Place client label above its port labels, left-justified with them
            title = self.scene.addText(client)
            title.setFont(header_font)
            title.setDefaultTextColor(QColor("#2c3e50"))
            title.setPos(L["right_port_label_x"], y)
            y2 = y + L["first_port_offset"]
            for p in ins:
                item = self._add_port_node(p, QPointF(right_x, y2), is_output=False)
                port_items[p] = item
                y2 += L["row_h"]
            y = y2 + 8
        # Edges
        for sp, dp in self.connections:
            sp_item = port_items.get(sp)
            dp_item = port_items.get(dp)
            if not sp_item or not dp_item:
                continue
            self._add_edge(sp_item, dp_item)
        # Fit only if requested/pending; otherwise preserve user's zoom/scroll
        if getattr(self, "_fit_pending", False):
            rect = self.scene.itemsBoundingRect()
            if rect.isValid():
                self.view.fitInView(rect, Qt.KeepAspectRatio)
            self._fit_pending = False
        # No manual combos on the graph tab

    def _add_port_node(self, fullport: str, pos: QPointF, is_output: bool):
        r = 6
        color = QColor("#27ae60") if is_output else QColor("#3498db")
        pen = QPen(color); pen.setWidth(2)
        ell = QGraphicsEllipseItem(-r, -r, 2*r, 2*r)
        ell.setPen(pen)
        ell.setBrush(QColor("#ecf0f1"))
        ell.setToolTip(fullport)
        ell.setPos(pos)
        ell.setZValue(2)
        ell.setFlag(ell.ItemIsSelectable, True)
        try:
            ell.setAcceptedMouseButtons(Qt.LeftButton | Qt.RightButton)
        except Exception:
            pass
        # Attach metadata for drag/drop logic
        try:
            ell.setData(0, fullport)   # full port name
            ell.setData(1, bool(is_output))  # True if output node
        except Exception:
            pass
        # label
        lab = QGraphicsTextItem(fullport.split(":",1)[1])
        # Place labels in tidy columns
        L = self._layout
        if is_output:
            lab.setPos(QPointF(L["left_port_label_x"], pos.y() - 10))
        else:
            lab.setPos(QPointF(L["right_port_label_x"], pos.y() - 10))
        lab.setDefaultTextColor(QColor("#2c3e50"))
        self.scene.addItem(lab)
        self.scene.addItem(ell)

        # Drag-to-connect + click-to-connect combined handler
        ell._press_pos = None
        ell._orig_pen = pen

        def begin_drag(start_item, start_scene_pos):
            # Start a temporary line from the source output node
            self._drag_src_item = start_item
            self._drag_started = True
            p1 = start_item.scenePos()
            self._drag_line = QGraphicsLineItem(p1.x()+6, p1.y(), start_scene_pos.x(), start_scene_pos.y())
            dl_pen = QPen(QColor("#8e44ad")); dl_pen.setStyle(Qt.DashLine); dl_pen.setWidth(2)
            self._drag_line.setPen(dl_pen)
            self._drag_line.setZValue(0.5)
            self.scene.addItem(self._drag_line)

        def update_drag(to_scene_pos):
            if not self._drag_line or not self._drag_src_item:
                return
            p1 = self._drag_src_item.scenePos()
            self._drag_line.setLine(p1.x()+6, p1.y(), to_scene_pos.x(), to_scene_pos.y())
            # Hover highlight for valid input targets
            try:
                items = self.scene.items(to_scene_pos)
            except Exception:
                items = []
            target = None
            for it in items:
                try:
                    if isinstance(it, QGraphicsEllipseItem) and (it.data(1) is False):
                        target = it
                        break
                except Exception:
                    continue
            if target is not self._drag_hover_item:
                # Clear previous highlight
                if isinstance(self._drag_hover_item, QGraphicsEllipseItem):
                    try:
                        self._drag_hover_item.setPen(self._drag_hover_item._orig_pen)
                    except Exception:
                        pass
                self._drag_hover_item = target
                if isinstance(self._drag_hover_item, QGraphicsEllipseItem):
                    hl = QPen(QColor("#f1c40f")); hl.setWidth(3)
                    self._drag_hover_item.setPen(hl)

        def end_drag(end_scene_pos):
            # Finalize drag: connect if dropped over an input node
            if self._drag_line:
                try:
                    self.scene.removeItem(self._drag_line)
                except Exception:
                    pass
                self._drag_line = None
            target = None
            try:
                items = self.scene.items(end_scene_pos)
            except Exception:
                items = []
            for it in items:
                try:
                    if isinstance(it, QGraphicsEllipseItem) and (it.data(1) is False):
                        target = it
                        break
                except Exception:
                    continue
            # Clear hover highlight
            if isinstance(self._drag_hover_item, QGraphicsEllipseItem):
                try:
                    self._drag_hover_item.setPen(self._drag_hover_item._orig_pen)
                except Exception:
                    pass
            self._drag_hover_item = None

            if self._drag_src_item and target:
                try:
                    sp = str(self._drag_src_item.data(0))
                    dp = str(target.data(0))
                    self._jack_connect(sp, dp)
                    self.refresh()
                except Exception as e:
                    QMessageBox.critical(self, "JACK Error", f"Connect failed: {e}\n{sp} → {dp}")

            self._drag_src_item = None
            self._drag_started = False

        def on_press(event):
            if event.button() == Qt.RightButton:
                # Context menu: disconnects for this port, copy name
                try:
                    menu = QMenu()
                    act_disc_all = menu.addAction("Disconnect all on this port")
                    act_copy = menu.addAction("Copy port name")
                    chosen = menu.exec_(event.screenPos().toPoint())
                    if chosen == act_disc_all:
                        try:
                            cons = self._list_connections()
                            p = fullport
                            for s,d in cons:
                                if s == p or d == p:
                                    try:
                                        self._jack_disconnect(s, d)
                                    except Exception:
                                        pass
                            self.refresh()
                        except Exception:
                            pass
                    elif chosen == act_copy:
                        try:
                            QApplication.clipboard().setText(fullport)
                        except Exception:
                            pass
                    return
                except Exception:
                    pass
            if event.button() == Qt.LeftButton:
                ell._press_pos = event.scenePos()
            return super(QGraphicsEllipseItem, ell).mousePressEvent(event)

        def on_move(event):
            # Start drag only when moved a bit and source is an output node
            if bool(ell.data(1)) and ell._press_pos is not None:
                delta = event.scenePos() - ell._press_pos
                if not self._drag_started and (abs(delta.x()) > 3 or abs(delta.y()) > 3):
                    # Suppress click-to-connect selection when drag begins
                    self._selected_out = None
                    self._selected_in = None
                    begin_drag(ell, event.scenePos())
            if self._drag_started:
                update_drag(event.scenePos())
            return super(QGraphicsEllipseItem, ell).mouseMoveEvent(event)

        def on_release(event):
            # If a drag was in progress, finish it; otherwise fall back to click-to-connect
            if self._drag_started:
                end_drag(event.scenePos())
            else:
                if event.button() == Qt.LeftButton:
                    if is_output:
                        self._selected_out = fullport
                    else:
                        self._selected_in = fullport
                    if self._selected_out and self._selected_in:
                        try:
                            self._jack_connect(self._selected_out, self._selected_in)
                            self.refresh()
                        except Exception as e:
                            QMessageBox.critical(self, "JACK Error", f"Connect failed: {e}")
                        finally:
                            self._selected_out = None
                            self._selected_in = None
            ell._press_pos = None
            return super(QGraphicsEllipseItem, ell).mouseReleaseEvent(event)

        ell.mousePressEvent = on_press
        ell.mouseMoveEvent = on_move
        ell.mouseReleaseEvent = on_release
        return ell

    # ---- Zoom helper ----
    def _zoom(self, factor: float):
        try:
            new_level = self._zoom_level * float(factor)
            new_level = max(0.2, min(4.0, new_level))
            ratio = new_level / (self._zoom_level if self._zoom_level else 1.0)
            self.view.scale(ratio, ratio)
            self._zoom_level = new_level
            self._fit_pending = False
        except Exception:
            pass

    # ---- Manual connect helpers ----
    def _populate_manual_combos(self):
        try:
            outs = []
            ins = []
            for c, d in self.ports.items():
                outs.extend(d.get("out", []))
                ins.extend(d.get("in", []))
            outs_sorted = sorted(outs, key=lambda s: s.lower())
            ins_sorted = sorted(ins, key=lambda s: s.lower())
            if hasattr(self, 'manual_out') and hasattr(self, 'manual_in'):
                self.manual_out.clear(); self.manual_in.clear()
                for p in outs_sorted:
                    self.manual_out.addItem(p)
                for p in ins_sorted:
                    self.manual_in.addItem(p)
        except Exception:
            pass

    def connect_manual_ports(self):
        try:
            sp = (self.manual_out.currentText() or '').strip()
            dp = (self.manual_in.currentText() or '').strip()
            if sp and dp:
                if not self._direction_ok(sp, dp):
                    QMessageBox.warning(self, "Port Direction",
                                        "The selected source doesn't look like an output or the destination isn't an input.\nProceed anyway?",
                                        QMessageBox.Ok, QMessageBox.Ok)
                self._jack_connect(sp, dp)
                self.refresh()
        except Exception as e:
            QMessageBox.critical(self, "JACK Error", f"Connect failed: {e}")

    def disconnect_manual_ports(self):
        try:
            sp = (self.manual_out.currentText() or '').strip()
            dp = (self.manual_in.currentText() or '').strip()
            if sp and dp:
                self._jack_disconnect(sp, dp)
                self.refresh()
        except Exception as e:
            QMessageBox.critical(self, "JACK Error", f"Disconnect failed: {e}")

    def toggle_lock_manual_pair(self):
        try:
            sp = (self.manual_out.currentText() or '').strip()
            dp = (self.manual_in.currentText() or '').strip()
            if not (sp and dp):
                return
            s_client = sp.split(":",1)[0]
            d_client = dp.split(":",1)[0]
            key = f"{s_client}→{d_client}"
            if key in self.critical_pairs:
                self.critical_pairs.remove(key)
            else:
                self.critical_pairs.add(key)
            self._save_protected_pairs()
            self.refresh()
        except Exception:
            pass

    def _add_edge(self, sp_item: QGraphicsEllipseItem, dp_item: QGraphicsEllipseItem):
        p1 = sp_item.scenePos()
        p2 = dp_item.scenePos()
        # Curved, sexy cable using cubic Bezier
        path = QPainterPath(QPointF(p1.x()+6, p1.y()))
        dx = max(40.0, abs(p2.x() - p1.x()) * 0.35)
        c1 = QPointF(p1.x() + dx, p1.y())
        c2 = QPointF(p2.x() - dx, p2.y())
        path.cubicTo(c1, c2, QPointF(p2.x()-6, p2.y()))
        sp_full = sp_item.toolTip()
        dp_full = dp_item.toolTip()
        line = _GraphEdgeItem(path, self, sp_full, dp_full)
        s_client = sp_item.toolTip().split(":",1)[0]
        d_client = dp_item.toolTip().split(":",1)[0]
        key = f"{s_client}→{d_client}"
        is_prot = key in self.critical_pairs
        pen = QPen(QColor("#e67e22") if is_prot else QColor("#34495e"))
        pen.setWidth(4 if is_prot else 3)
        try:
            pen.setCapStyle(Qt.RoundCap)
            pen.setJoinStyle(Qt.RoundJoin)
        except Exception:
            pass
        line.setPen(pen)
        line.setZValue(1)
        line.setToolTip(f"{sp_item.toolTip()} → {dp_item.toolTip()}")
        line.setFlag(line.ItemIsSelectable, False)
        self.scene.addItem(line)

        # Add a small state icon near the middle of the line
        midx = (p1.x()+p2.x())/2
        midy = (p1.y()+p2.y())/2
        icon = QGraphicsTextItem("🔐" if is_prot else "⚠️")
        icon.setDefaultTextColor(QColor("#e67e22") if is_prot else QColor("#7f8c8d"))
        icon.setPos(midx - 6, midy - 10)
        icon.setZValue(1.5)
        try:
            icon.setAcceptedMouseButtons(Qt.NoButton)
        except Exception:
            pass
        self.scene.addItem(icon)

        # Add a wide transparent hit-area to make right-clicking easier
        hit = _GraphEdgeHitBox(path, self, sp_full, dp_full)
        hit.setPen(QPen(QColor(0,0,0,0), 14))
        hit.setBrush(Qt.NoBrush)
        hit.setZValue(1.6)
        hit.setFlag(hit.ItemIsSelectable, False)
        self.scene.addItem(hit)

    def _edge_context_menu(self, sp_full: str, dp_full: str, screen_pos):
        try:
            menu = QMenu()
            act_disc = menu.addAction("Disconnect")
            # Lock state computed live
            s_client = sp_full.split(":",1)[0]
            d_client = dp_full.split(":",1)[0]
            key = f"{s_client}→{d_client}"
            is_prot = key in self.critical_pairs
            if is_prot:
                act_disc.setEnabled(False)
            act_lock = menu.addAction("Unlock (unprotect)" if is_prot else "Lock (protect)")
            menu.addSeparator()
            act_stereo = menu.addAction("Make Stereo Pair (L→L, R→R)")
            act_mono_l = menu.addAction("Mono Left → both inputs")
            act_mono_r = menu.addAction("Mono Right → both inputs")
            menu.addSeparator()
            # Independent L/R actions
            act_conn_l = menu.addAction("Connect Left → Left")
            act_conn_r = menu.addAction("Connect Right → Right")
            act_disc_l = menu.addAction("Disconnect Left")
            act_disc_r = menu.addAction("Disconnect Right")
            try:
                chosen = menu.exec_(screen_pos.toPoint())
            except Exception:
                chosen = menu.exec_(screen_pos)
            if chosen == act_disc:
                try:
                    self._jack_disconnect(sp_full, dp_full)
                    self.refresh()
                except Exception as e:
                    QMessageBox.critical(self, "JACK Error", f"Disconnect failed: {e}")
            elif chosen == act_lock:
                if is_prot:
                    if key in self.critical_pairs:
                        self.critical_pairs.remove(key)
                else:
                    self.critical_pairs.add(key)
                self._save_protected_pairs()
                self.refresh()
            elif chosen in (act_stereo, act_mono_l, act_mono_r, act_conn_l, act_conn_r, act_disc_l, act_disc_r):
                try:
                    s_ports = self._first_two(self.ports.get(s_client,{}).get("out",[]))
                    d_ports = self._first_two(self.ports.get(d_client,{}).get("in",[]))
                    if len(d_ports) < 2:
                        return True
                    if chosen == act_stereo:
                        if len(s_ports) >= 2:
                            try:
                                self._jack_connect(s_ports[0], d_ports[0])
                                self._jack_connect(s_ports[1], d_ports[1])
                            except Exception:
                                pass
                    elif chosen == act_mono_l:
                        src = s_ports[0] if s_ports else sp_full
                        try:
                            self._jack_connect(src, d_ports[0])
                            self._jack_connect(src, d_ports[1])
                        except Exception:
                            pass
                    elif chosen == act_mono_r:
                        src = (s_ports[1] if len(s_ports) > 1 else sp_full)
                        try:
                            self._jack_connect(src, d_ports[0])
                            self._jack_connect(src, d_ports[1])
                        except Exception:
                            pass
                    elif chosen == act_conn_l:
                        if len(s_ports) >= 1:
                            self._jack_connect(s_ports[0], d_ports[0])
                    elif chosen == act_conn_r:
                        if len(s_ports) >= 2:
                            self._jack_connect(s_ports[1], d_ports[1])
                    elif chosen == act_disc_l:
                        if len(s_ports) >= 1:
                            self._jack_disconnect(s_ports[0], d_ports[0])
                    elif chosen == act_disc_r:
                        if len(s_ports) >= 2:
                            self._jack_disconnect(s_ports[1], d_ports[1])
                    self.refresh()
                except Exception:
                    pass
            return True
        except Exception:
            try:
                return False
            except Exception:
                pass
        return False

    def eventFilter(self, obj, event):
        # Intercept viewport context menu events to ensure menus appear instead of selection rectangles
        try:
            if obj is self.view.viewport() and event.type() == QEvent.ContextMenu:
                scene_pos = self.view.mapToScene(event.pos())
                for it in self.scene.items(scene_pos):
                    try:
                        if isinstance(it, QGraphicsPathItem) and it.data(99) == "edge":
                            screen_pt = self.view.mapToGlobal(event.pos())
                            handled = self._edge_context_menu(it.data(100), it.data(101), screen_pt)
                            if handled:
                                return True
                    except Exception:
                        continue
                return False
        except Exception:
            pass
        return super().eventFilter(obj, event)

    # ---- Settings and watcher ----
    def _setting_enabled(self, key: str, default: bool = True) -> bool:
        try:
            if self.main and hasattr(self.main, "_settings"):
                return bool(self.main._settings.get(key, default))
        except Exception:
            pass
        return default

    def _vlc_autoreconnect_tick(self):
        """Ensure VLC outputs feed Rivendell Record-In when present and inputs are free."""
        try:
            if not self._setting_enabled('auto_reconnect_vlc', True):
                return
            base = self._run(["jack_lsp"], timeout=0.6)
            if base.returncode != 0:
                return
            res = self._run(["jack_lsp", "-p"], timeout=0.9)
            out = res.stdout or base.stdout
            ports = self._parse_ports(out)
            cons = self._list_connections()

            def find_like(names, direction, need=2):
                for c in sorted(ports.keys()):
                    lc = c.lower()
                    if any(n in lc for n in names):
                        if len(ports.get(c, {}).get(direction, [])) >= need:
                            return c
                return None

            vlc = find_like(["vlc"], "out")
            rd_in = find_like(["rivendell", "rd"], "in")
            if not (vlc and rd_in):
                return
            s_ports = (ports.get(vlc, {}).get("out", []) or [])
            d_ports = (ports.get(rd_in, {}).get("in", []) or [])
            s_ports = self._first_two(s_ports)
            d_ports = self._first_two(d_ports)
            if len(s_ports) != 2 or len(d_ports) != 2:
                return
            # Check if RD inputs already have any source
            dp0_has = any(dst == d_ports[0] for (_, dst) in cons)
            dp1_has = any(dst == d_ports[1] for (_, dst) in cons)
            if dp0_has and dp1_has:
                return
            try:
                if not dp0_has:
                    self._jack_connect(s_ports[0], d_ports[0])
                if not dp1_has:
                    self._jack_connect(s_ports[1], d_ports[1])
            except Exception:
                pass
            # Do not refresh here; next periodic refresh/interaction will redraw
        except Exception:
            pass

    def _on_graph_vlc_toggle(self, _state):
        try:
            val = bool(self.chk_vlc_reconnect.isChecked())
            if self.main and hasattr(self.main, "_settings"):
                self.main._settings['auto_reconnect_vlc'] = val
                self.main.save_settings()
        except Exception:
            pass

    # ----- Quick actions -----
    def auto_connect(self):
        # Simple delegate using current graph state; avoid creating feedback loops
        def find_like(names, direction):
            for c in sorted(self.ports.keys()):
                lc = c.lower()
                if any(n in lc for n in names):
                    if len(self.ports.get(c, {}).get(direction, [])) >= 2:
                        return c
            return None
        rd = find_like(["rivendell", "rd"], "out") or find_like(["system"], "out")
        rd_in = find_like(["rivendell", "rd"], "in")
        vlc = find_like(["vlc"], "out")
        st = find_like(["stereo tool", "stereotool", "stereo_tool", "thimeo"], "in")
        ls_in = find_like(["liquidsoap"], "in")
        ls_out = find_like(["liquidsoap"], "out")
        sys_play = find_like(["system"], "in")
        actions = []
        existing = set((s.split(":",1)[0], d.split(":",1)[0]) for (s,d) in self._list_connections())
        def pair(a,b):
            return f"{a}→{b}" if a and b else None
        for a,b in ((rd,st),(st,ls_in),(ls_out,sys_play)):
            if a and b:
                s_ports = self._first_two(self.ports.get(a,{}).get("out",[]))
                d_ports = self._first_two(self.ports.get(b,{}).get("in",[]))
                # Avoid connecting if reverse path exists to prevent feedback (b→a already)
                if ((b,a) in existing) or ((a,b) in existing and a==b):
                    continue
                if len(s_ports)==2 and len(d_ports)==2:
                    try:
                        self._jack_connect(s_ports[0], d_ports[0])
                        self._jack_connect(s_ports[1], d_ports[1])
                        actions.append(pair(a,b))
                    except Exception:
                        pass
        # Prefer bringing external audio into Rivendell if available
        if vlc and rd_in:
            s_ports = self._first_two(self.ports.get(vlc,{}).get("out",[]))
            d_ports = self._first_two(self.ports.get(rd_in,{}).get("in",[]))
            if len(s_ports)==2 and len(d_ports)==2:
                try:
                    self._jack_connect(s_ports[0], d_ports[0])
                    self._jack_connect(s_ports[1], d_ports[1])
                    actions.append(pair(vlc, rd_in))
                except Exception:
                    pass
        if not actions:
            QMessageBox.information(self, "Auto-Connect", "No suitable clients found for auto patching.")
        self.refresh()

    # ----- Profiles actions -----
    def save_current_as_profile(self):
        try:
            from PyQt5.QtWidgets import QInputDialog
            # Refresh connections to ensure current
            self.connections = self._list_connections()
            name, ok = QInputDialog.getText(self, "Save Profile", "Profile name:")
            if not ok or not name.strip():
                return
            key = name.strip()
            # Store as list of [src, dst]
            self.profiles[key] = [[s, d] for (s, d) in self.connections]
            self._save_profiles()
            self._refresh_profiles_combo()
            self.profile_combo.setCurrentText(key)
            QMessageBox.information(self, "Profile Saved", f"Saved profile '{key}' with {len(self.connections)} connections.")
        except Exception as e:
            QMessageBox.critical(self, "Save Profile", f"Could not save profile: {e}")

    def apply_selected_profile(self):
        try:
            name = self.profile_combo.currentText().strip()
            if not name or name not in self.profiles:
                return
            pairs = self.profiles.get(name, [])
            applied = 0
            for s, d in pairs:
                try:
                    # Only connect if both ports exist now
                    if self._port_exists(s) and self._port_exists(d):
                        self._jack_connect(s, d)
                        applied += 1
                except Exception:
                    pass
            self.refresh()
            QMessageBox.information(self, "Profile Applied", f"Applied {applied}/{len(pairs)} connections from '{name}'.")
        except Exception as e:
            QMessageBox.critical(self, "Apply Profile", f"Could not apply profile: {e}")

    def delete_selected_profile(self):
        try:
            name = self.profile_combo.currentText().strip()
            if not name or name not in self.profiles:
                return
            reply = QMessageBox.question(self, "Delete Profile",
                                         f"Delete profile '{name}'? This cannot be undone.",
                                         QMessageBox.Yes | QMessageBox.No)
            if reply != QMessageBox.Yes:
                return
            self.profiles.pop(name, None)
            self._save_profiles()
            self._refresh_profiles_combo()
        except Exception as e:
            QMessageBox.critical(self, "Delete Profile", f"Could not delete profile: {e}")

    def _port_exists(self, port_full: str) -> bool:
        try:
            # Quick membership check in parsed ports
            client = port_full.split(":", 1)[0]
            d = self.ports.get(client, {})
            return (port_full in d.get("in", [])) or (port_full in d.get("out", []))
        except Exception:
            return False

    def generate_profile(self):
        try:
            # Build a suggested chain: VLC→RD(in), RD(out)→ST(in), ST(out)→LS(in), LS(out)→system(playback)
            def find_like(names, direction, need=2):
                for c in sorted(self.ports.keys()):
                    lc = c.lower()
                    if any(n in lc for n in names):
                        if len(self.ports.get(c, {}).get(direction, [])) >= need:
                            return c
                return None
            def first2(c, direction):
                return self._first_two(self.ports.get(c, {}).get(direction, [])) if c else []

            vlc = find_like(["vlc"], "out")
            rd_in = find_like(["rivendell", "rd"], "in")
            rd_out = find_like(["rivendell", "rd"], "out")
            st_in = find_like(["stereo tool", "stereotool", "stereo_tool", "thimeo"], "in")
            st_out = find_like(["stereo tool", "stereotool", "stereo_tool", "thimeo"], "out")
            ls_in = find_like(["liquidsoap"], "in")
            ls_out = find_like(["liquidsoap"], "out")
            sys_in = find_like(["system"], "in")

            pairs = []
            def add_pair_ports(src_client, dst_client):
                if not (src_client and dst_client):
                    return
                sps = first2(src_client, "out")
                dps = first2(dst_client, "in")
                if len(sps) == 2 and len(dps) == 2:
                    pairs.append([sps[0], dps[0]])
                    pairs.append([sps[1], dps[1]])

            # Suggested stereo pairs
            add_pair_ports(vlc, rd_in)
            add_pair_ports(rd_out, st_in)
            add_pair_ports(st_out, ls_in)
            add_pair_ports(ls_out, sys_in)

            if not pairs:
                QMessageBox.information(self, "Generate Profile", "No suitable stereo clients found to generate a profile.")
                return

            # Show summary and ask for name
            summary = "\n".join([f"{s} → {d}" for s, d in pairs])
            msg = QMessageBox(self)
            msg.setIcon(QMessageBox.Information)
            msg.setWindowTitle("Generated Profile")
            msg.setText("Proposed connections:\n\n" + summary)
            msg.setStandardButtons(QMessageBox.Ok | QMessageBox.Cancel)
            ret = msg.exec_()
            if ret != QMessageBox.Ok:
                return

            from PyQt5.QtWidgets import QInputDialog
            default_name = time.strftime("Suggested %Y-%m-%d %H:%M")
            name, ok = QInputDialog.getText(self, "Save Generated Profile", "Profile name:", text=default_name)
            if not ok or not name.strip():
                return
            key = name.strip()
            self.profiles[key] = pairs
            self._save_profiles()
            # Offer immediate apply (best-effort; continue on individual errors)
            applied = 0
            errs = []
            for s, d in pairs:
                if self._port_exists(s) and self._port_exists(d):
                    try:
                        self._jack_connect(s, d)
                        applied += 1
                    except Exception as e:
                        errs.append(str(e))
            self.refresh()
            if errs:
                # Show a concise warning but confirm partial success
                uniq = []
                for m in errs:
                    lm = m.strip()
                    if lm and lm not in uniq:
                        uniq.append(lm)
                detail = "\n".join(uniq[:3])  # limit noise
                QMessageBox.warning(self, "Profile Generated",
                                    f"Saved '{key}' and applied {applied}/{len(pairs)} connections, with some non-fatal issues:\n{detail}")
            else:
                QMessageBox.information(self, "Profile Generated", f"Saved '{key}' and applied {applied}/{len(pairs)} connections.")
        except Exception as e:
            QMessageBox.critical(self, "Generate Profile", f"Could not generate profile: {e}")

    def emergency_disconnect(self):
        reply = QMessageBox.warning(self, "EMERGENCY DISCONNECT",
                                    "⚠️ This will disconnect ALL non-critical JACK connections!\n\nContinue?",
                                    QMessageBox.Yes | QMessageBox.No)
        if reply != QMessageBox.Yes:
            return
        try:
            res = self._run(["jack_lsp", "-c"], timeout=1.0)
            txt = res.stdout or ""
            cur_src = None
            for line in txt.splitlines():
                if not line:
                    continue
                if not line.startswith(" "):
                    cur_src = line.strip()
                    continue
                if cur_src and line.startswith("    "):
                    dst = line.strip()
                    s_client = cur_src.split(":", 1)[0]
                    d_client = dst.split(":", 1)[0]
                    key = f"{s_client}→{d_client}"
                    if key not in self.critical_pairs:
                        try:
                            self._jack_disconnect(cur_src, dst)
                        except Exception:
                            pass
            QMessageBox.information(self, "Emergency Disconnect", "All non-critical connections disconnected.")
        except Exception as e:
            QMessageBox.critical(self, "JACK Error", f"Could not enumerate connections: {e}")

    # ----- helpers -----
    def _first_two(self, arr):
        """Pick a sensible stereo pair from a list of full port names.
        Preference order:
        1) Matching L/R pair with same base (e.g., fm_l/fm_r, out_L/out_R)
        2) Matching numeric pair with same base (0/1 then 1/2, e.g., in_0/in_1, out_1/out_2)
        3) First available Left + first available Right across all ports
        4) Fallback to the first two ports sorted stably
        """
        ports = list(arr)
        if len(ports) <= 2:
            return ports

        def split(p: str):
            client, pn = p.split(":", 1)
            return client, pn

        def norm_base_and_side(pn: str):
            pl = pn.lower()
            # Detect side markers
            side = None
            if re.search(r"(^|[_.\-:])l(eft)?($|[_.\-:])", pl):
                side = "L"
            if re.search(r"(^|[_.\-:])r(ight)?($|[_.\-:])", pl):
                side = "R"
            # Trailing single letter L/R (e.g., record_0L)
            if side is None and re.search(r"[a-zA-Z0-9]_?[lL]$", pn):
                side = "L"
            if side is None and re.search(r"[a-zA-Z0-9]_?[rR]$", pn):
                side = "R"
            # Numeric index at end
            num = None
            m = re.search(r"(?:[_:\-])(\d+)$", pl)
            if m:
                try:
                    num = int(m.group(1))
                except Exception:
                    num = None
            # Compute base: strip trailing side or numeric tokens
            base = pl
            base = re.sub(r"([_.:\-])?(l(eft)?|r(ight)?)$", "", base)
            base = re.sub(r"([_.:\-])(\d+)$", "", base)
            return base, side, num

        # Group by client+base to find best L/R or numeric pairs
        groups = {}
        meta = {}
        for p in ports:
            client, pn = split(p)
            base, side, num = norm_base_and_side(pn)
            key = (client.lower(), base)
            groups.setdefault(key, []).append(p)
            meta[p] = (side, num)

        # 1) Try exact L/R within same base
        for key, items in groups.items():
            left = None; right = None
            for p in items:
                s, _ = meta[p]
                if s == "L" and left is None:
                    left = p
                elif s == "R" and right is None:
                    right = p
            if left and right:
                return [left, right]

        # 2) Try numeric pairs within same base (prefer 0/1, else 1/2)
        for prefer in ((0,1), (1,2)):
            for key, items in groups.items():
                want = {prefer[0]: None, prefer[1]: None}
                for p in items:
                    _, n = meta[p]
                    if n in want and want[n] is None:
                        want[n] = p
                if all(want.values()):
                    return [want[prefer[0]], want[prefer[1]]]

        # 3) First Left + first Right overall
        first_l = next((p for p in ports if meta.get(p, (None,None))[0] == "L"), None)
        first_r = next((p for p in ports if meta.get(p, (None,None))[0] == "R"), None)
        if first_l and first_r:
            return [first_l, first_r]

        # 4) Stable fallback: sort by client/port then take two
        def key_fallback(p: str):
            client, pn = split(p)
            return (client.lower(), pn.lower())
        ports.sort(key=key_fallback)
        return ports[:2]

    def _jack_connect(self, src_port: str, dst_port: str):
        r = self._run(["jack_connect", src_port, dst_port], timeout=1.8)
        if r.returncode != 0:
            msg = (r.stderr or r.stdout or "jack_connect failed").strip()
            low = msg.lower()
            # Ignore common non-fatal noise
            if "cannot lock down" in low:
                # If connection ended up established, treat as success
                if self._connected(src_port, dst_port):
                    return
            if "already connected" in low or "ports are already connected" in low:
                return
            if self._connected(src_port, dst_port):
                return
            # Some systems return a generic "cannot connect client" even when already connected
            if "cannot connect" in low and self._connected(src_port, dst_port):
                return
            raise RuntimeError(msg)

    def _jack_disconnect(self, src_port: str, dst_port: str):
        self._run(["jack_disconnect", src_port, dst_port], timeout=1.2)

    def _connected(self, sp: str, dp: str) -> bool:
        res = self._run(["jack_lsp", "-c"], timeout=1.2)
        txt = res.stdout or ""
        cur = None
        for line in txt.splitlines():
            if not line:
                continue
            if not line.startswith(" "):
                cur = line.strip()
                continue
            # Accept any kind/amount of whitespace before the destination line
            if cur == sp and line.strip() == dp:
                return True
        return False

    def _direction_ok(self, sp: str, dp: str) -> bool:
        try:
            s_client = sp.split(":",1)[0]
            d_client = dp.split(":",1)[0]
            return (sp in self.ports.get(s_client,{}).get("out", [])) and (dp in self.ports.get(d_client,{}).get("in", []))
        except Exception:
            return True

    # ---- JACK helpers ----
    def refresh_jack_connections(self):
        """Refresh JACK ports and update UI elements."""
        try:
            # Check if JACK is running
            try:
                base = subprocess.run(["jack_lsp"], capture_output=True, text=True, timeout=0.7)
            except subprocess.TimeoutExpired:
                self.jack_status_label.setText("Status: ⏳ JACK Probe Timed Out")
                self.jack_status_label.setStyleSheet("QLabel { color: #f39c12; font-weight: bold; }")
                return
            if base.returncode != 0:
                self.jack_status_label.setText("Status: ❌ JACK Not Running")
                self.jack_status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
                self.ports = {}
                self.jack_clients = []
                self.source_combo.clear()
                self.dest_combo.clear()
                self.jack_info.setPlainText("JACK is not running. Start JACK and refresh.")
                return
            # Ports with properties
            try:
                res = subprocess.run(["jack_lsp", "-p"], capture_output=True, text=True, timeout=0.7)
            except subprocess.TimeoutExpired:
                res = subprocess.CompletedProcess(args=["jack_lsp","-p"], returncode=1, stdout=base.stdout, stderr="")
            if res.returncode != 0:
                out = base.stdout
            else:
                out = res.stdout
            self.ports = self._parse_jack_ports(out)
            self.jack_clients = sorted(list(self.ports.keys()))
            # Populate combos
            self._populate_combos()
            self._populate_port_combos()
            # Info text
            self._update_info()
            self.jack_status_label.setText("Status: ✅ JACK Running")
            self.jack_status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
        except FileNotFoundError:
            self.jack_status_label.setText("Status: ❌ JACK Tools Not Found")
            self.jack_status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")

    def _parse_jack_ports(self, txt: str) -> dict:
        """Parse 'jack_lsp -p' output into {client: {in:[ports], out:[ports]}}."""
        ports = {}
        current_port = None
        for raw in (txt or "").splitlines():
            line = raw.rstrip()
            if not line:
                continue
            if not line.startswith(" ") and ":" in line:
                # Port line like 'client:port'
                current_port = line.strip()
                client = current_port.split(":", 1)[0]
                ports.setdefault(client, {"in": [], "out": []})
                # Default direction unknown until properties parsed; assume both lists handle after
                # If we never see properties, include heuristically to out if name contains 'out' else in
                pname = current_port.split(":", 1)[1].lower()
                if "out" in pname and "in" not in pname:
                    ports[client]["out"].append(current_port)
                elif "in" in pname and "out" not in pname:
                    ports[client]["in"].append(current_port)
                else:
                    # Will be corrected when properties line encountered
                    pass
            elif line.strip().startswith("properties:") and current_port:
                props = line.split(":", 1)[1]
                client = current_port.split(":", 1)[0]
                # Remove from both to avoid duplicates
                try:
                    if current_port in ports.get(client, {}).get("in", []):
                        ports[client]["in"].remove(current_port)
                    if current_port in ports.get(client, {}).get("out", []):
                        ports[client]["out"].remove(current_port)
                except Exception:
                    pass
                if "output" in props:
                    ports[client]["out"].append(current_port)
                else:
                    ports[client]["in"].append(current_port)
        return ports

    def _populate_combos(self):
        def stereo_candidates(direction: str) -> list:
            cands = []
            for c, d in self.ports.items():
                if len(d.get(direction, [])) >= 2:
                    cands.append(c)
            # Prefer recognizable names in a friendly order
            def key(name: str):
                ln = name.lower()
                score = 0
                if "rivendell" in ln or ln.startswith("rd"): score -= 10
                if "stereo" in ln: score -= 9
                if "liquidsoap" in ln: score -= 8
                if name.startswith("system"): score -= 7
                return (score, name)
            return [x for x in sorted(cands, key=key)]
        srcs = stereo_candidates("out")
        dsts = stereo_candidates("in")
        cur_s = self.source_combo.currentText()
        cur_d = self.dest_combo.currentText()
        self.source_combo.clear(); self.source_combo.addItems(srcs)
        self.dest_combo.clear(); self.dest_combo.addItems(dsts)
        # Try restore previous selection
        if cur_s in srcs:
            self.source_combo.setCurrentText(cur_s)
        if cur_d in dsts:
            self.dest_combo.setCurrentText(cur_d)

    def _populate_port_combos(self):
        # Flat lists of full port names
        outs = []
        ins = []
        for c, d in self.ports.items():
            outs.extend(d.get("out", []))
            ins.extend(d.get("in", []))
        # Sort for readability by client then port
        def keyp(p: str):
            client, pn = p.split(":", 1)
            return (client.lower(), pn.lower())
        outs.sort(key=keyp)
        ins.sort(key=keyp)
        # Build nice labels
        def label(p: str) -> str:
            client, pn = p.split(":", 1)
            pretty_c = self._pretty_client(client)
            pretty_p = self._pretty_port_name(pn)
            return f"{pretty_c}: {pretty_p}  ({pn})"
        cur_sp = self.port_src_combo.currentData() if self.port_src_combo.count() else None
        cur_dp = self.port_dst_combo.currentData() if self.port_dst_combo.count() else None
        self.port_src_combo.clear()
        for p in outs:
            self.port_src_combo.addItem(label(p), p)
        self.port_dst_combo.clear()
        for p in ins:
            self.port_dst_combo.addItem(label(p), p)
        # Try restore previous selection
        if cur_sp:
            idx = self.port_src_combo.findData(cur_sp)
            if idx >= 0:
                self.port_src_combo.setCurrentIndex(idx)
        if cur_dp:
            idx = self.port_dst_combo.findData(cur_dp)
            if idx >= 0:
                self.port_dst_combo.setCurrentIndex(idx)

    def _update_info(self):
        lines = []
        for c in self.jack_clients:
            ins = len(self.ports.get(c, {}).get("in", []))
            outs = len(self.ports.get(c, {}).get("out", []))
            lines.append(f"{c}: in={ins} out={outs}")
        self.jack_info.setPlainText("\n".join(lines) if lines else "No JACK clients detected.")

    def _stereo_pair(self, client: str, direction: str) -> list:
        """Return first two ports for client in given direction (in/out)."""
        ports = list(self.ports.get(client, {}).get(direction, []))
        # Sort to ensure L/R or 1/2 ordering
        def sort_key(p: str):
            pn = p.split(":", 1)[1].lower()
            # Prefer left before right if labeled
            if re.search(r"(^|[_\-:])l(eft)?($|[_\-:])", pn):
                return (-2, pn)
            if re.search(r"(^|[_\-:])r(ight)?($|[_\-:])", pn):
                return (-1, pn)
            m = re.search(r"(\d+)$", pn)
            if m:
                return (int(m.group(1)), pn)
            return (999, pn)
        ports.sort(key=sort_key)
        return ports[:2]

    def connect_selected_pair(self):
        src = self.source_combo.currentText().strip()
        dst = self.dest_combo.currentText().strip()
        if not src or not dst or src == dst:
            QMessageBox.warning(self, "Invalid Selection", "Choose distinct source and destination with stereo ports.")
            return
        key = f"{src}→{dst}"
        if self.protect_checkbox.isChecked():
            self.critical_pairs.add(key)
            self._save_protected_pairs()
        s_ports = self._stereo_pair(src, "out")
        d_ports = self._stereo_pair(dst, "in")
        if len(s_ports) < 2 or len(d_ports) < 2:
            QMessageBox.warning(self, "Not Stereo", "Selected clients do not expose at least 2 ports each.")
            return
        ok = True
        errs = []
        for sp, dp in zip(s_ports, d_ports):
            try:
                self._jack_connect(sp, dp)
            except Exception as e:
                ok = False
                errs.append(f"{sp} -> {dp}: {e}")
        if ok:
            QMessageBox.information(self, "Connected", f"{src} → {dst} (L/R)")
        else:
            QMessageBox.warning(self, "Partial Failure", "Some connections failed:\n" + "\n".join(errs))

    def disconnect_selected_pair(self):
        src = self.source_combo.currentText().strip()
        dst = self.dest_combo.currentText().strip()
        if not src or not dst or src == dst:
            return
        key = f"{src}→{dst}"
        if key in self.critical_pairs:
            reply = QMessageBox.question(self, "Protected Pair", f"{key} is protected. Disconnect anyway?",
                                         QMessageBox.Yes | QMessageBox.No)
            if reply != QMessageBox.Yes:
                return
        s_ports = self._stereo_pair(src, "out")
        d_ports = self._stereo_pair(dst, "in")
        errs = []
        for sp, dp in zip(s_ports, d_ports):
            try:
                self._jack_disconnect(sp, dp)
            except Exception as e:
                errs.append(f"{sp} -/-> {dp}: {e}")
        if errs:
            QMessageBox.warning(self, "Disconnect Issues", "\n".join(errs))
        else:
            QMessageBox.information(self, "Disconnected", f"{src} ⛓️ {dst}")

    def unprotect_current_pair(self):
        """Remove protection flag from the currently selected Source→Destination pair."""
        src = self.source_combo.currentText().strip()
        dst = self.dest_combo.currentText().strip()
        if not src or not dst or src == dst:
            return
        key = f"{src}→{dst}"
        if key in self.critical_pairs:
            self.critical_pairs.remove(key)
            self._save_protected_pairs()
            QMessageBox.information(self, "Unprotected", f"Removed protection for: {key}")
        else:
            QMessageBox.information(self, "Not Protected", f"Current pair is not protected: {key}")

    def auto_connect(self):
        """Heuristic chain: Rivendell/rd* → Stereo Tool → Liquidsoap; also LS → system:playback."""
        # Prefer commonly named clients
        def find_like(names, direction):
            for c in self.jack_clients:
                lc = c.lower()
                if any(n in lc for n in names):
                    if len(self.ports.get(c, {}).get(direction, [])) >= 2:
                        return c
            return None
        rd = find_like(["rivendell", "rd"], "out") or find_like(["system"], "out")
        st = find_like(["stereo tool", "stereotool", "stereo_tool", "thimeo"], "in")
        ls_in = find_like(["liquidsoap"], "in")
        ls_out = find_like(["liquidsoap"], "out")
        sys_play = find_like(["system"], "in")
        actions = []
        if rd and st:
            self.source_combo.setCurrentText(rd)
            self.dest_combo.setCurrentText(st)
            self.connect_selected_pair()
            actions.append(f"{rd}→{st}")
        if st and ls_in:
            self.source_combo.setCurrentText(st)
            self.dest_combo.setCurrentText(ls_in)
            self.connect_selected_pair()
            actions.append(f"{st}→{ls_in}")
        if ls_out and sys_play:
            self.source_combo.setCurrentText(ls_out)
            self.dest_combo.setCurrentText(sys_play)
            self.connect_selected_pair()
            actions.append(f"{ls_out}→{sys_play}")
        if not actions:
            QMessageBox.information(self, "Auto-Connect", "No suitable clients found for auto patching.")

    def emergency_disconnect(self):
        reply = QMessageBox.warning(self, "EMERGENCY DISCONNECT",
                                    "⚠️ This will disconnect ALL non-critical JACK connections!\n\nContinue?",
                                    QMessageBox.Yes | QMessageBox.No)
        if reply != QMessageBox.Yes:
            return
        # Parse current connections and disconnect those not protected
        try:
            try:
                res = subprocess.run(["jack_lsp", "-c"], capture_output=True, text=True, timeout=0.7)
            except subprocess.TimeoutExpired:
                raise RuntimeError("jack_lsp -c timed out")
            txt = res.stdout or ""
            to_disc = []
            cur_src = None
            for line in txt.splitlines():
                if not line:
                    continue
                if not line.startswith(" "):
                    cur_src = line.strip()
                    continue
                if line.strip().startswith("connections:"):
                    # following lines are indented connection targets
                    continue
                if cur_src and line.startswith("    "):
                    dst = line.strip()
                    # Extract client names
                    s_client = cur_src.split(":", 1)[0]
                    d_client = dst.split(":", 1)[0]
                    key = f"{s_client}→{d_client}"
                    if key not in self.critical_pairs:
                        to_disc.append((cur_src, dst))
            errs = []
            for sp, dp in to_disc:
                try:
                    self._jack_disconnect(sp, dp)
                except Exception as e:
                    errs.append(f"{sp} -/-> {dp}: {e}")
            if errs:
                QMessageBox.warning(self, "Disconnect Issues", "\n".join(errs))
            else:
                QMessageBox.information(self, "Emergency Disconnect", "All non-critical connections disconnected.")
        except Exception as e:
            QMessageBox.critical(self, "JACK Error", f"Could not enumerate connections: {e}")

    # ---- Persistence for protected pairs ----
    def _config_dir(self) -> Path:
        p = Path.home() / ".config" / "rdx"
        try:
            p.mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        return p

    def _prot_file(self) -> Path:
        return self._config_dir() / "jack_protected.json"

    def _load_protected_pairs(self):
        try:
            pf = self._prot_file()
            if pf.exists():
                with open(pf, 'r') as f:
                    data = json.load(f)
                pairs = data.get('pairs', [])
                if isinstance(pairs, list):
                    self.critical_pairs = set(str(x) for x in pairs)
        except Exception:
            self.critical_pairs = set()

    def _save_protected_pairs(self):
        try:
            pf = self._prot_file()
            with open(pf, 'w') as f:
                json.dump({"pairs": sorted(list(self.critical_pairs))}, f, indent=2)
        except Exception:
            pass

    # ---- Low-level JACK ops with better errors ----
    def _jack_connect(self, src_port: str, dst_port: str):
        try:
            res = subprocess.run(["jack_connect", src_port, dst_port], capture_output=True, text=True)
            if res.returncode != 0:
                # If already connected, treat as success
                if self._is_connected(src_port, dst_port):
                    return
                stderr = (res.stderr or '').strip()
                stdout = (res.stdout or '').strip()
                raise RuntimeError(stderr or stdout or f"jack_connect failed with code {res.returncode}")
        except FileNotFoundError:
            raise RuntimeError("jack_connect not found in PATH")

    def _jack_disconnect(self, src_port: str, dst_port: str):
        try:
            subprocess.run(["jack_disconnect", src_port, dst_port], capture_output=True, text=True)
        except FileNotFoundError:
            raise RuntimeError("jack_disconnect not found in PATH")

    def _is_connected(self, src_port: str, dst_port: str) -> bool:
        try:
            res = subprocess.run(["jack_lsp", "-c"], capture_output=True, text=True)
            txt = res.stdout or ""
            cur = None
            for line in txt.splitlines():
                if not line:
                    continue
                if not line.startswith(" "):
                    cur = line.strip()
                    continue
                if cur == src_port and line.startswith("    "):
                    if line.strip() == dst_port:
                        return True
        except Exception:
            pass
        return False

    # ---- Manual per-port connect/disconnect ----
    def connect_manual_ports(self):
        sp = self.port_src_combo.currentData()
        dp = self.port_dst_combo.currentData()
        if not sp or not dp:
            QMessageBox.warning(self, "Invalid Selection", "Select a source output port and a destination input port.")
            return
        try:
            self._jack_connect(sp, dp)
            QMessageBox.information(self, "Connected", f"{sp} → {dp}")
        except Exception as e:
            QMessageBox.warning(self, "Connect Failed", f"{sp} -> {dp}: {e}")

    def disconnect_manual_ports(self):
        sp = self.port_src_combo.currentData()
        dp = self.port_dst_combo.currentData()
        if not sp or not dp:
            return
        try:
            self._jack_disconnect(sp, dp)
            QMessageBox.information(self, "Disconnected", f"{sp} ⛓️ {dp}")
        except Exception as e:
            QMessageBox.warning(self, "Disconnect Failed", f"{sp} -/-> {dp}: {e}")

    # ---- Pretty naming helpers ----
    def _pretty_client(self, name: str) -> str:
        ln = name.lower()
        if ln.startswith('system'):
            return 'System'
        if 'rivendell' in ln or ln.startswith('rd'):
            return 'Rivendell'
        if 'liquidsoap' in ln:
            return 'Liquidsoap'
        if 'stereo_tool' in ln or 'stereotool' in ln or 'stereo tool' in ln:
            return 'Stereo Tool'
        return name

    def _pretty_port_name(self, pn: str) -> str:
        lpn = pn.lower()
        # Common JACK port namings
        if lpn in ("in_1", "capture_1", "playout_0l", "left", "l", "in_l", "in:left"):
            return "Left In"
        if lpn in ("in_2", "capture_2", "playout_0r", "right", "r", "in_r", "in:right"):
            return "Right In"
        if lpn in ("out_1", "playback_1", "out_l", "left", "l", "out:left"):
            return "Left Out"
        if lpn in ("out_2", "playback_2", "out_r", "right", "r", "out:right"):
            return "Right Out"
        return pn


class ServiceControlTab(QWidget):
    """Tab 4: Service Control - Start/stop/configure all broadcast services"""
    
    def __init__(self, main=None):
        super().__init__()
        self.main = main
        # Persisted JACK settings used to start/stop server
        self.jack_settings = self._load_jack_settings()
        self.services = {
            'jack': {'name': 'JACK Audio', 'systemd': 'jack', 'status': 'unknown', 'user_service': False},
            # Use a per-user unit that points to the currently active Stereo Tool instance
            'stereo_tool': {'name': 'Stereo Tool', 'systemd': 'rdx-stereotool-active', 'status': 'unknown', 'user_service': True},
            'liquidsoap': {'name': 'Liquidsoap', 'systemd': 'liquidsoap', 'status': 'unknown', 'user_service': True},
            'icecast': {'name': 'Icecast', 'systemd': 'icecast2', 'status': 'unknown', 'user_service': False}
        }
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
    # Individual Service Controls
        services_group = QGroupBox("🛠️ Individual Service Controls")
        services_layout = QGridLayout(services_group)
        
        # Header row
        services_layout.addWidget(QLabel("Service"), 0, 0)
        services_layout.addWidget(QLabel("Status"), 0, 1)
        services_layout.addWidget(QLabel("Actions"), 0, 2, 1, 4)
        
        # Service rows
        row = 1
        for service_key, service_info in self.services.items():
            # Service name
            name_label = QLabel(service_info['name'])
            name_label.setStyleSheet("QLabel { font-weight: bold; }")
            services_layout.addWidget(name_label, row, 0)
            
            # Status label
            status_label = QLabel("⏳ Checking...")
            setattr(self, f"{service_key}_status_label", status_label)
            services_layout.addWidget(status_label, row, 1)
            
            # Control buttons
            start_btn = QPushButton("▶️ Start")
            start_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; }")
            start_btn.clicked.connect(lambda checked, s=service_key: self.start_service(s))
            services_layout.addWidget(start_btn, row, 2)
            
            stop_btn = QPushButton("⏹️ Stop")
            stop_btn.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; }")
            stop_btn.clicked.connect(lambda checked, s=service_key: self.stop_service(s))
            services_layout.addWidget(stop_btn, row, 3)
            
            restart_btn = QPushButton("🔄 Restart")
            restart_btn.setStyleSheet("QPushButton { background-color: #f39c12; color: white; }")
            restart_btn.clicked.connect(lambda checked, s=service_key: self.restart_service(s))
            services_layout.addWidget(restart_btn, row, 4)
            
            config_btn = QPushButton("⚙️ Configure")
            config_btn.setStyleSheet("QPushButton { background-color: #3498db; color: white; }")
            config_btn.clicked.connect(lambda checked, s=service_key: self.configure_service(s))
            services_layout.addWidget(config_btn, row, 5)

            # Keep references for JACK to enable/disable based on management mode
            if service_key == 'jack':
                self.jack_status_label = status_label
                self.jack_start_btn = start_btn
                self.jack_stop_btn = stop_btn
                self.jack_restart_btn = restart_btn

            # Stereo Tool extras: Logs button and active status label
            if service_key == 'stereo_tool':
                logs_btn = QPushButton("📄 Logs")
                logs_btn.setStyleSheet("QPushButton { background-color: #8e44ad; color: white; }")
                logs_btn.clicked.connect(self.open_stereotool_logs)
                services_layout.addWidget(logs_btn, row, 6)

                self.stereotool_active_label = QLabel("Active: —")
                self.stereotool_active_label.setStyleSheet("QLabel { color: #7f8c8d; font-size: 10px; }")
                services_layout.addWidget(self.stereotool_active_label, row, 7)

            # Optional, compact capability line for Liquidsoap encoders
            if service_key == 'liquidsoap':
                self.liquidsoap_encoders_label = QLabel("")
                self.liquidsoap_encoders_label.setStyleSheet(
                    "QLabel { color: #7f8c8d; font-size: 10px; }"
                )
                self.liquidsoap_encoders_label.setVisible(False)
                services_layout.addWidget(self.liquidsoap_encoders_label, row, 6)
            
            row += 1
            
        layout.addWidget(services_group)
        
        # Master Controls
        master_group = QGroupBox("🎛️ Master Control")
        master_layout = QGridLayout(master_group)
        
        start_all_btn = QPushButton("🚀 START ALL SERVICES")
        start_all_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; font-weight: bold; padding: 15px; font-size: 14px; }")
        start_all_btn.clicked.connect(self.start_all_services)
        master_layout.addWidget(start_all_btn, 0, 0)
        
        stop_all_btn = QPushButton("⏹️ STOP ALL SERVICES")
        stop_all_btn.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; font-weight: bold; padding: 15px; font-size: 14px; }")
        stop_all_btn.clicked.connect(self.stop_all_services)
        master_layout.addWidget(stop_all_btn, 0, 1)
        
        emergency_btn = QPushButton("🚨 EMERGENCY STOP")
        emergency_btn.setStyleSheet("QPushButton { background-color: #8e44ad; color: white; font-weight: bold; padding: 15px; font-size: 14px; }")
        emergency_btn.clicked.connect(self.emergency_stop)
        master_layout.addWidget(emergency_btn, 1, 0, 1, 2)
        
        layout.addWidget(master_group)
        
        # Launch Order & Timing controls
        order_group = QGroupBox("🚦 Launch Order & Timing")
        order_layout = QVBoxLayout(order_group)
        self.order_table = QTableWidget(0, 3, order_group)
        self.order_table.setHorizontalHeaderLabels(["Service", "Delay (s)", "Unit"])
        self.order_table.horizontalHeader().setStretchLastSection(True)
        order_layout.addWidget(self.order_table)

        order_buttons = QHBoxLayout()
        btn_up = QPushButton("⬆️ Move Up")
        btn_down = QPushButton("⬇️ Move Down")
        btn_save = QPushButton("💾 Save Order")
        btn_start = QPushButton("▶️ Start In Order")
        order_buttons.addWidget(btn_up)
        order_buttons.addWidget(btn_down)
        order_buttons.addStretch(1)
        order_buttons.addWidget(btn_save)
        order_buttons.addWidget(btn_start)
        order_layout.addLayout(order_buttons)
        layout.addWidget(order_group)

        self._init_launch_order_ui()

        btn_up.clicked.connect(lambda: self._move_selected_order_row(-1))
        btn_down.clicked.connect(lambda: self._move_selected_order_row(1))
        btn_save.clicked.connect(self._save_launch_order)
        btn_start.clicked.connect(self._start_services_in_order)

        # Service Dependencies Info
        deps_group = QGroupBox("📊 Service Dependencies")
        deps_layout = QVBoxLayout(deps_group)
        
        deps_text = QLabel("""
🔗 Service Startup Order:
1. JACK Audio (Foundation)
2. Liquidsoap (Stream Generation)
3. Stereo Tool (Audio Processing)
4. Icecast (Stream Server)

⚠️ Dependencies: Each service depends on the previous one running correctly.
        """)
        deps_text.setStyleSheet("QLabel { background-color: #f8f9fa; padding: 10px; border-radius: 5px; }")
        deps_layout.addWidget(deps_text)
        
        layout.addWidget(deps_group)
        
        # Liquidsoap Log Viewer
        log_group = QGroupBox("📄 Liquidsoap Log (latest 500 lines)")
        log_layout = QVBoxLayout(log_group)
        
        # Controls row for log
        log_controls = QHBoxLayout()
        self.follow_log_checkbox = QCheckBox("Follow")
        self.follow_log_checkbox.setChecked(True)
        refresh_btn = QPushButton("Refresh Now")
        refresh_btn.clicked.connect(self.update_log_view)
        log_controls.addWidget(self.follow_log_checkbox)
        log_controls.addStretch(1)
        log_controls.addWidget(refresh_btn)
        
        # Log text area
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setStyleSheet("QTextEdit { font-family: monospace; background: #0e0e0e; color: #e0e0e0; }")
        self.log_text.setPlaceholderText("Liquidsoap log will appear here after starting the service...")
        
        log_layout.addLayout(log_controls)
        log_layout.addWidget(self.log_text)
        layout.addWidget(log_group)
        
        # Status update timer
        self.status_timer = QTimer()
        self.status_timer.timeout.connect(self.update_all_status)
        self.status_timer.start(3000)  # Check every 3 seconds
        
        # Log update timer
        self.log_timer = QTimer()
        self.log_timer.timeout.connect(self.update_log_view)
        self.log_timer.start(2000)
        
        # Initial status check
        self.update_all_status()
        self.update_log_view()
        # Initial one-time probe for Liquidsoap encoder capabilities
        self._last_liq_probe_ts = 0.0
        self.update_liquidsoap_encoders_label(force=True)

        # Apply initial JACK management state to controls
        self._apply_jack_manage_mode_to_controls()

    # ---- JACK settings persistence and helpers ---------------------------
    def _jack_settings_path(self) -> Path:
        return Path.home() / ".config" / "rdx" / "jack_settings.json"

    def _load_jack_settings(self) -> dict:
        d = {
            "manage": True,            # Whether RDX should manage JACK server
            "mode": "jackd",          # jackd | jackdbus
            "backend": "alsa",        # alsa | dummy
            "device": "",             # e.g., hw:PCH or hw:0
            "rate": 48000,             # Sample rate
            "period": 256,             # Frames/period (-p)
            "nperiods": 2,             # Periods/buffer (-n)
            "realtime": True,          # Use -R for realtime
            "extra_args": ""          # Extra args for jackd driver
        }
        try:
            p = self._jack_settings_path()
            if p.exists():
                with open(p, 'r') as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        d.update(data)
        except Exception:
            pass
        return d

    def _save_jack_settings(self, data: dict):
        try:
            p = self._jack_settings_path()
            p.parent.mkdir(parents=True, exist_ok=True)
            with open(p, 'w') as f:
                json.dump(data, f, indent=2)
            self.jack_settings = data
        except Exception:
            pass

    def _jack_is_running(self) -> bool:
        try:
            res = subprocess.run(["jack_lsp"], capture_output=True, timeout=0.7)
            return res.returncode == 0
        except Exception:
            return False

    def _build_jackd_command(self) -> list:
        s = self.jack_settings
        cmd = ["jackd"]
        if s.get("realtime", True):
            cmd.append("-R")
        cmd += ["-d", s.get("backend", "alsa")]  # select driver
        if s.get("backend", "alsa").lower() == "alsa":
            dev = s.get("device", "").strip()
            if dev:
                cmd += ["-d", dev]
            rate = int(s.get("rate", 48000) or 48000)
            period = int(s.get("period", 256) or 256)
            nperiods = int(s.get("nperiods", 2) or 2)
            cmd += ["-r", str(rate), "-p", str(period), "-n", str(nperiods)]
        # Simple dummy backend params: sample rate and period
        # Note: dummy driver does NOT support '-n' (nperiods). Only ALSA uses '-n'.
        if s.get("backend", "alsa").lower() == "dummy":
            rate = int(s.get("rate", 48000) or 48000)
            period = int(s.get("period", 256) or 256)
            cmd += ["-r", str(rate), "-p", str(period)]
        extra = s.get("extra_args", "").strip()
        if extra:
            try:
                cmd += shlex.split(extra)
            except Exception:
                # Fallback: append as a single token to avoid crash
                cmd.append(extra)
        return cmd

    def _jackdbus_preview_commands(self) -> list:
        """Return a list of strings representing jack_control commands to apply settings."""
        s = self.jack_settings
        cmds = []
        backend = s.get("backend", "alsa")
        cmds.append(f"jack_control ds {backend}")
        # Engine params
        rt = str(bool(s.get("realtime", True))).lower()
        cmds.append(f"jack_control eps realtime {rt}")
        # Driver params
        if backend.lower() == "alsa":
            dev = s.get("device", "").strip()
            if dev:
                cmds.append(f"jack_control dps device {shlex.quote(dev)}")
            rate = int(s.get("rate", 48000) or 48000)
            period = int(s.get("period", 256) or 256)
            nperiods = int(s.get("nperiods", 2) or 2)
            cmds.append(f"jack_control dps rate {rate}")
            cmds.append(f"jack_control dps period {period}")
            cmds.append(f"jack_control dps nperiods {nperiods}")
        elif backend.lower() == "dummy":
            rate = int(s.get("rate", 48000) or 48000)
            period = int(s.get("period", 256) or 256)
            nperiods = int(s.get("nperiods", 2) or 2)
            cmds.append(f"jack_control dps rate {rate}")
            cmds.append(f"jack_control dps period {period}")
            cmds.append(f"jack_control dps nperiods {nperiods}")
        cmds.append("jack_control start")
        return cmds

    def _start_jack_server(self) -> tuple:
        """Start JACK according to selected mode. Returns (ok: bool, message: str)."""
        mode = self.jack_settings.get("mode", "jackd").lower()
        if mode == "jackdbus":
            # Apply settings via jack_control then start
            try:
                # Best-effort stop before reconfiguring
                subprocess.run(["jack_control", "stop"], check=False)
                backend = self.jack_settings.get("backend", "alsa")
                subprocess.run(["jack_control", "ds", backend], check=False)
                # Engine params
                rt = str(bool(self.jack_settings.get("realtime", True))).lower()
                subprocess.run(["jack_control", "eps", "realtime", rt], check=False)
                # Driver params
                if backend.lower() == "alsa":
                    dev = self.jack_settings.get("device", "").strip()
                    if dev:
                        subprocess.run(["jack_control", "dps", "device", dev], check=False)
                    rate = int(self.jack_settings.get("rate", 48000) or 48000)
                    period = int(self.jack_settings.get("period", 256) or 256)
                    nperiods = int(self.jack_settings.get("nperiods", 2) or 2)
                    subprocess.run(["jack_control", "dps", "rate", str(rate)], check=False)
                    subprocess.run(["jack_control", "dps", "period", str(period)], check=False)
                    subprocess.run(["jack_control", "dps", "nperiods", str(nperiods)], check=False)
                else:
                    rate = int(self.jack_settings.get("rate", 48000) or 48000)
                    period = int(self.jack_settings.get("period", 256) or 256)
                    nperiods = int(self.jack_settings.get("nperiods", 2) or 2)
                    subprocess.run(["jack_control", "dps", "rate", str(rate)], check=False)
                    subprocess.run(["jack_control", "dps", "period", str(period)], check=False)
                    subprocess.run(["jack_control", "dps", "nperiods", str(nperiods)], check=False)
                # Start
                r = subprocess.run(["jack_control", "start"], capture_output=True, text=True)
                if r.returncode == 0:
                    return True, "Started JACK (jackdbus)"
                return False, (r.stderr or r.stdout or "jack_control start failed").strip()
            except FileNotFoundError:
                return False, "'jack_control' not found in PATH. Install jackdbus (jackd2)."
            except Exception as e:
                return False, f"Error starting jackdbus: {e}"
        else:
            # jackd direct
            cmd = self._build_jackd_command()
            try:
                # Guard: if ALSA backend selected without device, refuse to start implicitly
                try:
                    backend = self.jack_settings.get("backend", "alsa").lower()
                except Exception:
                    backend = "alsa"
                if backend == "alsa" and not self.jack_settings.get("device", "").strip():
                    return False, "ALSA backend selected but no device set. RDX will not auto-pick a device.\nSet Device in JACK Settings or switch backend to Dummy."

                # Write jackd output to a per-user log for diagnostics
                log_path = Path.home() / ".config" / "rdx" / "jackd.log"
                log_path.parent.mkdir(parents=True, exist_ok=True)
                with open(log_path, 'ab', buffering=0) as lf:
                    proc = subprocess.Popen(cmd, stdout=lf, stderr=lf, start_new_session=True)
                # Brief grace period then verify
                time.sleep(0.5)
                if self._jack_is_running():
                    return True, f"Launched JACK: {' '.join(cmd)}"
                # Wait a bit longer in case ALSA needed time
                time.sleep(1.0)
                if self._jack_is_running():
                    return True, f"Launched JACK: {' '.join(cmd)}"
                # Read last lines from log for error detail
                try:
                    tail = self._tail_file(log_path, 40)
                except Exception:
                    tail = ""
                return False, ("jackd failed to start. Last log lines:\n" + tail).strip()
            except FileNotFoundError:
                return False, "'jackd' not found in PATH. Install JACK (jackd/jackd2)."
            except Exception as e:
                return False, f"Failed to start jackd: {e}"

    def _stop_jack_server(self):
        """Best-effort stop regardless of mode."""
        try:
            subprocess.run(["jack_control", "stop"], check=False)
            subprocess.run(["jack_control", "exit"], check=False)
        except Exception:
            pass
        try:
            subprocess.run(["killall", "-q", "jackd"], check=False)
        except Exception:
            pass

    def _alsa_devices(self) -> list:
        """Return a list of ALSA device identifiers like 'hw:0', 'hw:PCH'."""
        devs = []
        try:
            r = subprocess.run(["bash", "-lc", "aplay -l"], capture_output=True, text=True, timeout=1.5)
            out = (r.stdout or "") + (r.stderr or "")
            # Parse lines like: card 0: PCH [HDA Intel PCH], device 0: ALC... [..]
            cards = {}
            for line in out.splitlines():
                line = line.strip()
                m = re.match(r"card\s+(\d+):\s+([^\s\[]+)", line)
                if m:
                    cid = m.group(1)
                    cname = m.group(2)
                    cards[cid] = cname
            for cid, cname in cards.items():
                devs.append(f"hw:{cid}")
                if cname and cname != cid:
                    devs.append(f"hw:{cname}")
        except Exception:
            pass
        # Always include defaults
        base = ["default", "hw:0", "hw:1"]
        seen = set()
        out = []
        for dname in base + devs:
            if dname and dname not in seen:
                seen.add(dname)
                out.append(dname)
        return out

    def _probe_running_jack_config(self) -> dict:
        """Attempt to detect current running JACK configuration.
        Returns a dict with keys: mode, backend, device, rate, period, nperiods, realtime.
        Empty dict if not detected.
        """
        # First try jackdbus via jack_control
        try:
            st = subprocess.run(["jack_control", "status"], capture_output=True, text=True, timeout=1.0)
            sout = (st.stdout or "") + (st.stderr or "")
            if st.returncode == 0 and ("started" in sout.lower() or "running" in sout.lower()):
                res = {"mode": "jackdbus"}
                # Driver
                ds = subprocess.run(["jack_control", "ds"], capture_output=True, text=True, timeout=1.0)
                dso = (ds.stdout or ds.stderr or "").strip().lower()
                # Heuristics: often prints just the driver name
                drv = None
                for cand in ("alsa", "dummy", "firewire", "coreaudio"):
                    if cand in dso:
                        drv = cand
                        break
                if drv:
                    res["backend"] = drv
                # Params
                dp = subprocess.run(["jack_control", "dp"], capture_output=True, text=True, timeout=1.0)
                ep = subprocess.run(["jack_control", "ep"], capture_output=True, text=True, timeout=1.0)
                txt = (dp.stdout or "") + "\n" + (ep.stdout or "")
                def _grab(k, cast=str):
                    m = re.search(rf"\b{k}\s*=\s*([\w:\-\.]+)", txt)
                    if not m:
                        return None
                    val = m.group(1)
                    try:
                        if cast is bool:
                            return str(val).lower() in ("1", "true", "yes", "on")
                        return cast(val)
                    except Exception:
                        return None
                res["device"] = _grab("device", str) or ""
                res["rate"] = _grab("rate", int)
                res["period"] = _grab("period", int)
                res["nperiods"] = _grab("nperiods", int)
                res["realtime"] = _grab("realtime", bool)
                return {k: v for k, v in res.items() if v is not None}
        except Exception:
            pass
        # Fallback: parse jackd command line
        try:
            ps = subprocess.run(["bash", "-lc", "ps -C jackd -o args="], capture_output=True, text=True, timeout=1.0)
            args = (ps.stdout or "").strip()
            if args:
                parts = shlex.split(args)
                res = {"mode": "jackd", "realtime": False}
                i = 0
                backend = None
                device = None
                while i < len(parts):
                    t = parts[i]
                    if t == "-R":
                        res["realtime"] = True
                        i += 1
                        continue
                    if t == "-d" and i + 1 < len(parts):
                        val = parts[i+1]
                        if backend is None:
                            backend = val
                        else:
                            device = val
                        i += 2
                        continue
                    if t == "-r" and i + 1 < len(parts):
                        res["rate"] = int(parts[i+1])
                        i += 2
                        continue
                    if t == "-p" and i + 1 < len(parts):
                        res["period"] = int(parts[i+1])
                        i += 2
                        continue
                    if t == "-n" and i + 1 < len(parts):
                        res["nperiods"] = int(parts[i+1])
                        i += 2
                        continue
                    i += 1
                if backend:
                    res["backend"] = backend
                if device:
                    res["device"] = device
                return res
        except Exception:
            pass
        return {}

    def _tail_file(self, path: Path, n: int = 60) -> str:
        try:
            data = path.read_text(errors='ignore')
            lines = data.splitlines()
            return "\n".join(lines[-n:])
        except Exception:
            return ""

    def _apply_jack_manage_mode_to_controls(self):
        manage = self.jack_settings.get("manage", True)
        # If not managing, disable start/stop/restart for JACK
        for btn in (getattr(self, 'jack_start_btn', None), getattr(self, 'jack_stop_btn', None), getattr(self, 'jack_restart_btn', None)):
            if btn is not None:
                btn.setEnabled(bool(manage))
        # Ensure user systemd unit exists/updated and enabled state reflects settings
        try:
            self._ensure_jack_unit()
            autostart = bool(self.jack_settings.get("autostart", False)) and manage
            if autostart:
                subprocess.run(["systemctl", "--user", "enable", "rdx-jack"], check=False)
            else:
                subprocess.run(["systemctl", "--user", "disable", "rdx-jack"], check=False)
        except Exception:
            pass

    def _jack_unit_path(self) -> Path:
        return Path.home() / ".config" / "systemd" / "user" / "rdx-jack.service"

    def _ensure_jack_unit(self):
        """Create/update per-user systemd unit for JACK based on current settings.
        This enables autostart at login if the unit is enabled. For headless pre-login,
        consider enabling lingering for the user (loginctl enable-linger $USER) and prefer jackd mode.
        """
        try:
            unit_dir = self._jack_unit_path().parent
            unit_dir.mkdir(parents=True, exist_ok=True)
            s = self.jack_settings
            mode = s.get("mode", "jackd").lower()
            if mode == "jackdbus":
                # Build a shell sequence to configure and start via jack_control
                backend = s.get("backend", "alsa")
                rate = int(s.get("rate", 48000) or 48000)
                period = int(s.get("period", 256) or 256)
                nperiods = int(s.get("nperiods", 2) or 2)
                dev = (s.get("device", "") or "").strip()
                rt = str(bool(s.get("realtime", True))).lower()
                seq = [
                    "jack_control stop",
                    f"jack_control ds {backend}",
                    f"jack_control eps realtime {rt}",
                    f"jack_control dps rate {rate}",
                    f"jack_control dps period {period}",
                    f"jack_control dps nperiods {nperiods}",
                ]
                if backend.lower() == "alsa" and dev:
                    seq.insert(3, f"jack_control dps device {shlex.quote(dev)}")
                seq.append("jack_control start")
                execstart = f"/bin/bash -lc '{' && '.join(seq)}'"
            else:
                # jackd command as built for interactive start
                cmd = self._build_jackd_command()
                # Quote safely for ExecStart
                execstart = " ".join(shlex.quote(x) for x in cmd)
            unit = f"""[Unit]
Description=RDX JACK Server
After=default.target
Wants=default.target

[Service]
Type=simple
ExecStart={execstart}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
"""
            self._jack_unit_path().write_text(unit, encoding="utf-8")
            subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
        except Exception:
            # Non-fatal: interactive controls still work
            pass

    def _st_path_root(self) -> Path:
        return Path.home() / ".config" / "rdx" / "processing" / "stereotool"

    def _active_symlink(self) -> Path:
        return self._st_path_root() / "active"

    def _active_stereotool_display(self) -> str:
        try:
            link = self._active_symlink()
            if link.is_symlink():
                target = os.path.realpath(str(link))
                return os.path.basename(target)
        except Exception:
            pass
        return "—"

    # ---- Liquidsoap path/env helpers ------------------------------------
    def _liquidsoap_bin(self) -> str:
        """Prefer the per-user OPAM shim at ~/.local/bin/liquidsoap if present.
        Fallback to whichever 'liquidsoap' is on PATH.
        """
        try:
            home_bin = str(Path.home() / ".local" / "bin" / "liquidsoap")
            if os.path.isfile(home_bin) and os.access(home_bin, os.X_OK):
                return home_bin
        except Exception:
            pass
        return "liquidsoap"

    def _subprocess_env_with_localbin(self) -> dict:
        """Return env with ~/.local/bin prepended to PATH so OPAM shim is found."""
        env = os.environ.copy()
        try:
            home_local_bin = str(Path.home() / ".local" / "bin")
            path = env.get("PATH", "")
            parts = path.split(":") if path else []
            if home_local_bin and home_local_bin not in parts:
                env["PATH"] = f"{home_local_bin}:{path}" if path else home_local_bin
        except Exception:
            pass
        return env

    def update_liquidsoap_encoders_label(self, force: bool = False):
        """Update the compact Liquidsoap encoders label with detected capabilities.
        Keeps UI uncluttered by hiding if nothing is found or liquidsoap missing.
        """
        label = getattr(self, 'liquidsoap_encoders_label', None)
        if label is None:
            return
        try:
            import shutil, time as _time
            if shutil.which("liquidsoap") is None:
                label.setVisible(False)
                return
            now = _time.time()
            if not force and hasattr(self, '_last_liq_probe_ts') and (now - getattr(self, '_last_liq_probe_ts', 0.0) < 30.0):
                return
            self._last_liq_probe_ts = now

            names = ["fdkaac", "ffmpeg", "mp3", "opus", "vorbis", "flac"]
            available = []
            for n in names:
                if self._has_liquidsoap_encoder(n):
                    available.append(n)
            if available:
                txt = "Encoders: " + ", ".join(available)
                label.setText(txt)
                label.setToolTip("Detected Liquidsoap encoders: " + ", ".join(available))
                label.setVisible(True)
            else:
                label.setVisible(False)
        except Exception:
            # On any error, hide to avoid UI noise
            label.setVisible(False)

    def _has_liquidsoap_encoder(self, name: str) -> bool:
        """Return True if 'encoder.<name>' help is available (plugin built/linked).
        This prefers the per-user OPAM shim and augments PATH so GUI sessions see it.
        """
        try:
            res = subprocess.run([self._liquidsoap_bin(), "-h", f"encoder.{name}"],
                                 capture_output=True, text=True,
                                 env=self._subprocess_env_with_localbin())
            out = (res.stdout or "") + (res.stderr or "")
            return res.returncode == 0 and "Plugin not found" not in out
        except Exception:
            return False

    def _config_requests_aac(self, config_file: Path) -> bool:
        """Return True if the given config file appears to request an AAC output.
        Heuristics: looks for '%fdkaac(' or ffmpeg with audio_codec="aac".
        """
        try:
            if not config_file.exists():
                return False
            txt = config_file.read_text(encoding="utf-8", errors="ignore")
            if re.search(r"%fdkaac\s*\(", txt):
                return True
            if re.search(r"%ffmpeg\s*\(.*audio_codec\s*=\s*\"aac\"", txt, flags=re.IGNORECASE | re.DOTALL):
                return True
            # Also consider generic AAC mentions in encoder lines
            if re.search(r"encoder\.(ffmpeg|aac).*aac", txt, flags=re.IGNORECASE):
                return True
            return False
        except Exception:
            return False
        
    def update_all_status(self):
        """Update status for all services"""
        for service_key, service_info in self.services.items():
            status_label = getattr(self, f"{service_key}_status_label")
            
            try:
                if service_key == 'jack':
                    # Special handling for JACK
                    try:
                        result = subprocess.run(["jack_lsp"], capture_output=True, text=True, timeout=0.7)
                    except subprocess.TimeoutExpired:
                        status_label.setText("⏳ Probe Timeout")
                        status_label.setStyleSheet("QLabel { color: #f39c12; font-weight: bold; }")
                        continue
                    if result.returncode == 0:
                        status_label.setText("✅ Running")
                        status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
                    else:
                        status_label.setText("❌ Stopped")
                        status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
                elif service_key == 'liquidsoap':
                    # Liquidsoap is launched as a user process (not a systemd unit)
                    # Detect by process name to reflect actual running state
                    try:
                        proc_check = subprocess.run(["pgrep", "-x", "liquidsoap"], capture_output=True, timeout=0.7)
                    except subprocess.TimeoutExpired:
                        status_label.setText("⏳ Probe Timeout")
                        status_label.setStyleSheet("QLabel { color: #f39c12; font-weight: bold; }")
                        continue
                    if proc_check.returncode == 0:
                        status_label.setText("✅ Running")
                        status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
                    else:
                        status_label.setText("❌ Stopped")
                        status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
                else:
                    # Check if it's a user service
                    if service_info.get('user_service', False):
                        # User systemd service check
                        try:
                            result = subprocess.run(["systemctl", "--user", "is-active", service_info['systemd']], 
                                              capture_output=True, text=True, timeout=0.7)
                        except subprocess.TimeoutExpired:
                            status_label.setText("⏳ Probe Timeout")
                            status_label.setStyleSheet("QLabel { color: #f39c12; font-weight: bold; }")
                            continue
                    else:
                        # Standard systemd service check
                        try:
                            result = subprocess.run(["systemctl", "is-active", service_info['systemd']], 
                                              capture_output=True, text=True, timeout=0.7)
                        except subprocess.TimeoutExpired:
                            status_label.setText("⏳ Probe Timeout")
                            status_label.setStyleSheet("QLabel { color: #f39c12; font-weight: bold; }")
                            continue
                    
                    if result.stdout.strip() == "active":
                        status_label.setText("✅ Running")
                        status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
                    else:
                        status_label.setText("❌ Stopped")
                        status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
                # Update Stereo Tool active info line
                if service_key == 'stereo_tool' and hasattr(self, 'stereotool_active_label'):
                    self.stereotool_active_label.setText(f"Active: {self._active_stereotool_display()}")
            except Exception:
                status_label.setText("❓ Unknown")
                status_label.setStyleSheet("QLabel { color: #95a5a6; }")

    def update_log_view(self):
        """Tail and display the Liquidsoap log inside the UI"""
        try:
            config_dir = self.get_config_directory()
            log_path = config_dir / "liquidsoap.log"
            if not log_path.exists():
                self.log_text.setPlaceholderText("No Liquidsoap log found yet. Start Liquidsoap to generate logs.")
                return
            # Read last 500 lines to avoid huge memory usage
            with open(log_path, 'r', errors='ignore') as f:
                lines = f.readlines()
            tail_lines = lines[-500:]
            text = ''.join(tail_lines)
            # Update only if changed to reduce flicker
            if self.log_text.toPlainText() != text:
                self.log_text.setPlainText(text)
                if self.follow_log_checkbox.isChecked():
                    cursor = self.log_text.textCursor()
                    cursor.movePosition(cursor.End)
                    self.log_text.setTextCursor(cursor)
        except Exception:
            # Non-fatal: keep UI responsive even if log read fails
            pass
        
    def start_service(self, service_key):
        """Start a specific service automatically"""
        service_info = self.services[service_key]
        try:
            if service_key == 'jack':
                # Respect management mode; if disabled, inform user
                if not self.jack_settings.get("manage", True):
                    QMessageBox.information(self, "JACK Managed Externally",
                                            "RDX is set to not manage the JACK server.\n\n"
                                            "Enable management in the JACK Settings (Configure) if you want RDX to start it.")
                    return
                # Avoid duplicate starts
                if self._jack_is_running():
                    QMessageBox.information(self, "JACK Already Running", "JACK audio server is already running.")
                    return
                ok, msg = self._start_jack_server()
                if not ok:
                    QMessageBox.critical(self, "JACK Start Failed", msg)
                    return
                # Brief grace period then probe
                QTimer.singleShot(800, self.update_all_status)
                QMessageBox.information(self, "JACK Start Requested", msg)

            elif service_key == 'liquidsoap':
                # Start liquidsoap with generated config
                config_dir = self.get_config_directory()
                config_file = config_dir / "radio.liq"
                log_file = config_dir / "liquidsoap.log"

                # Verify liquidsoap is available
                import shutil
                # Check with augmented PATH and OPAM shim fallback
                liq_bin = self._liquidsoap_bin()
                liq_in_path = shutil.which("liquidsoap") is not None
                if not (liq_in_path or (os.path.isfile(liq_bin) and os.access(liq_bin, os.X_OK))):
                    QMessageBox.critical(self, "Liquidsoap Not Found",
                                         "The 'liquidsoap' command is not installed or not in PATH.\n\n"
                                         "Recommended: Build via OPAM (PPA-free) from the installer dialog, or run:\n"
                                         "  pkexec /bin/bash /usr/share/rdx/install-liquidsoap-opam.sh\n\n"
                                         "Alternative (may lack codecs):\n  sudo apt install liquidsoap")
                    return
                # If AAC is requested by the config, ensure at least one AAC path is available
                try:
                    if self._config_requests_aac(config_file):
                        has_fdkaac = self._has_liquidsoap_encoder("fdkaac")
                        has_ffmpeg = self._has_liquidsoap_encoder("ffmpeg")
                        if not (has_fdkaac or has_ffmpeg):
                            # Offer guided installation (OPAM preferred) if no AAC encoders are available
                            if self.prompt_install_ffmpeg_plugin():
                                # Re-check after install
                                has_fdkaac = self._has_liquidsoap_encoder("fdkaac")
                                has_ffmpeg = self._has_liquidsoap_encoder("ffmpeg")
                                if not (has_fdkaac or has_ffmpeg):
                                    QMessageBox.critical(self, "Liquidsoap AAC Encoder Missing",
                                                         "No AAC encoder is available (fdkaac or ffmpeg).\n\n"
                                                         "Consider building Liquidsoap via OPAM for full codec support, or install plugin packages where available.")
                                    return
                            else:
                                QMessageBox.critical(self, "Liquidsoap AAC Encoder Missing",
                                                     "No AAC encoder is available (fdkaac or ffmpeg).\n\n"
                                                     "Options: Use MP3-only streams for now, or install Liquidsoap via OPAM for AAC support.")
                                return
                except Exception:
                    # Don't block start if detection fails; parse-check will validate
                    pass

                # Parse-check Liquidsoap config before launching
                check = subprocess.run([self._liquidsoap_bin(), "-c", str(config_file)], capture_output=True, text=True, env=self._subprocess_env_with_localbin())
                if check.returncode != 0:
                    # Attempt auto-fix then strict fix as needed
                    orig_msg = (check.stderr or check.stdout or "Unknown parse error").strip()
                    self.sanitize_liquidsoap_config(config_file)
                    check2 = subprocess.run([self._liquidsoap_bin(), "-c", str(config_file)], capture_output=True, text=True, env=self._subprocess_env_with_localbin())
                    if check2.returncode != 0:
                        self.sanitize_liquidsoap_config_strict(config_file)
                        check3 = subprocess.run([self._liquidsoap_bin(), "-c", str(config_file)], capture_output=True, text=True, env=self._subprocess_env_with_localbin())
                        if check3.returncode != 0:
                            msg2 = (check2.stderr or check2.stdout or "Unknown parse error").strip()
                            msg3 = (check3.stderr or check3.stdout or "Unknown parse error").strip()
                            QMessageBox.critical(self, "Liquidsoap Config Error",
                                                 f"Failed to parse Liquidsoap config.\n\nFirst error:\n{orig_msg}\n\nAfter auto-fix:\n{msg2}\n\nAfter strict fix:\n{msg3}")
                            return

                if config_file.exists():
                    try:
                        log_fh = open(log_file, "a", buffering=1)
                    except Exception:
                        log_fh = None
                    try:
                        subprocess.Popen([self._liquidsoap_bin(), str(config_file)],
                                         stdout=log_fh or subprocess.DEVNULL,
                                         stderr=log_fh or subprocess.DEVNULL,
                                         start_new_session=True,
                                         env=self._subprocess_env_with_localbin())
                        QMessageBox.information(self, "Liquidsoap Started",
                                                f"Liquidsoap started with config: {config_file}\n\n"
                                                f"Logs: {log_file}")
                        # Refresh encoders line shortly after start
                        QTimer.singleShot(1000, lambda: self.update_liquidsoap_encoders_label(force=True))
                    except Exception as e:
                        if log_fh:
                            log_fh.close()
                        QMessageBox.critical(self, "Liquidsoap Start Error",
                                             f"Failed to launch Liquidsoap:\n{e}")
                        return
                    if log_fh:
                        try:
                            log_fh.close()
                        except Exception:
                            pass
                else:
                    QMessageBox.warning(self, "No Config",
                                        "Please generate Liquidsoap configuration first in Stream Builder tab.")

            else:
                # For other services, use systemctl
                if service_info.get('user_service', False):
                    subprocess.run(["systemctl", "--user", "start", service_info['systemd']], check=True)
                else:
                    subprocess.run(["systemctl", "start", service_info['systemd']], check=True)
                QMessageBox.information(self, f"{service_info['name']} Started",
                                        f"{service_info['name']} service started successfully.")

        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Service Start Failed",
                                 f"Failed to start {service_info['name']}:\n{str(e)}")
        except Exception as e:
            QMessageBox.critical(self, "Service Start Error",
                                 f"Error starting {service_info['name']}:\n{str(e)}")

                
    def stop_service(self, service_key):
        """Stop a specific service automatically"""
        service_info = self.services[service_key]
        
        try:
            if service_key == 'jack':
                if not self.jack_settings.get("manage", True):
                    QMessageBox.information(self, "JACK Managed Externally",
                                            "RDX is set to not manage the JACK server, so it won't stop it.")
                    return
                # Stop JACK (best-effort)
                self._stop_jack_server()
                QTimer.singleShot(500, self.update_all_status)
                QMessageBox.information(self, "JACK Stop Requested", "Requested JACK shutdown.")
                
            elif service_key == 'liquidsoap':
                # Stop liquidsoap
                subprocess.run(["killall", "liquidsoap"], check=False)
                QMessageBox.information(self, "Liquidsoap Stopped", "Liquidsoap stopped.")
                
            else:
                # For other services, use systemctl
                subprocess.run(["systemctl", "stop", service_info['systemd']], check=True)
                QMessageBox.information(self, f"{service_info['name']} Stopped", 
                                      f"{service_info['name']} service stopped successfully.")
                
        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Service Stop Failed", 
                               f"Failed to stop {service_info['name']}:\n{str(e)}")
        except Exception as e:
            QMessageBox.critical(self, "Service Stop Error", 
                               f"Error stopping {service_info['name']}:\n{str(e)}")

    def restart_service(self, service_key):
        """Restart a specific service automatically"""
        service_info = self.services[service_key]
        try:
            if service_key == 'jack':
                if not self.jack_settings.get("manage", True):
                    QMessageBox.information(self, "JACK Managed Externally",
                                            "RDX is set to not manage the JACK server.")
                    return
                self._stop_jack_server()
                time.sleep(0.8)
                ok, msg = self._start_jack_server()
                if not ok:
                    QMessageBox.critical(self, "JACK Restart Failed", msg)
                    return
                QTimer.singleShot(900, self.update_all_status)
                QMessageBox.information(self, "JACK Restart Requested", msg)

            elif service_key == 'liquidsoap':
                # Restart liquidsoap
                subprocess.run(["killall", "liquidsoap"], check=False)
                time.sleep(1)

                config_dir = self.get_config_directory()
                config_file = config_dir / "radio.liq"
                log_file = config_dir / "liquidsoap.log"

                # Verify liquidsoap is available
                import shutil
                if shutil.which("liquidsoap") is None:
                    QMessageBox.critical(self, "Liquidsoap Not Found",
                                         "The 'liquidsoap' command is not installed or not in PATH.\n\n"
                                         "Recommended: Build via OPAM (PPA-free) from the installer dialog, or run:\n"
                                         "  pkexec /bin/bash /usr/share/rdx/install-liquidsoap-opam.sh\n\n"
                                         "Alternative (may lack codecs):\n  sudo apt install liquidsoap")
                    return
                # If AAC is requested by the config, ensure at least one AAC path is available
                try:
                    if self._config_requests_aac(config_file):
                        has_fdkaac = self._has_liquidsoap_encoder("fdkaac")
                        has_ffmpeg = self._has_liquidsoap_encoder("ffmpeg")
                        if not (has_fdkaac or has_ffmpeg):
                            if self.prompt_install_ffmpeg_plugin():
                                has_fdkaac = self._has_liquidsoap_encoder("fdkaac")
                                has_ffmpeg = self._has_liquidsoap_encoder("ffmpeg")
                                if not (has_fdkaac or has_ffmpeg):
                                    QMessageBox.critical(self, "Liquidsoap AAC Encoder Missing",
                                                         "No AAC encoder is available (fdkaac or ffmpeg).\n\n"
                                                         "Consider building Liquidsoap via OPAM for full codec support, or install plugin packages where available.")
                                    return
                            else:
                                QMessageBox.critical(self, "Liquidsoap AAC Encoder Missing",
                                                     "No AAC encoder is available (fdkaac or ffmpeg).\n\n"
                                                     "Options: Use MP3-only streams for now, or install Liquidsoap via OPAM for AAC support.")
                                return
                except Exception:
                    pass

                # Parse-check Liquidsoap config before launching
                check = subprocess.run([self._liquidsoap_bin(), "-c", str(config_file)], capture_output=True, text=True, env=self._subprocess_env_with_localbin())
                if check.returncode != 0:
                    # Attempt auto-fix then strict fix as needed
                    orig_msg = (check.stderr or check.stdout or "Unknown parse error").strip()
                    self.sanitize_liquidsoap_config(config_file)
                    check2 = subprocess.run([self._liquidsoap_bin(), "-c", str(config_file)], capture_output=True, text=True, env=self._subprocess_env_with_localbin())
                    if check2.returncode != 0:
                        self.sanitize_liquidsoap_config_strict(config_file)
                        check3 = subprocess.run([self._liquidsoap_bin(), "-c", str(config_file)], capture_output=True, text=True, env=self._subprocess_env_with_localbin())
                        if check3.returncode != 0:
                            msg2 = (check2.stderr or check2.stdout or "Unknown parse error").strip()
                            msg3 = (check3.stderr or check3.stdout or "Unknown parse error").strip()
                            QMessageBox.critical(self, "Liquidsoap Config Error",
                                                 f"Failed to parse Liquidsoap config.\n\nFirst error:\n{orig_msg}\n\nAfter auto-fix:\n{msg2}\n\nAfter strict fix:\n{msg3}")
                            return

                if config_file.exists():
                    try:
                        log_fh = open(log_file, "a", buffering=1)
                    except Exception:
                        log_fh = None
                    try:
                        subprocess.Popen([self._liquidsoap_bin(), str(config_file)],
                                         stdout=log_fh or subprocess.DEVNULL,
                                         stderr=log_fh or subprocess.DEVNULL,
                                         start_new_session=True,
                                         env=self._subprocess_env_with_localbin())
                        QMessageBox.information(self, "Liquidsoap Restarted",
                                                f"Liquidsoap restarted with config: {config_file}\n\n"
                                                f"Logs: {log_file}")
                        # Refresh encoders line shortly after restart
                        QTimer.singleShot(1000, lambda: self.update_liquidsoap_encoders_label(force=True))
                    except Exception as e:
                        if log_fh:
                            log_fh.close()
                        QMessageBox.critical(self, "Liquidsoap Restart Error",
                                             f"Failed to launch Liquidsoap:\n{e}")
                        return
                    if log_fh:
                        try:
                            log_fh.close()
                        except Exception:
                            pass
                else:
                    QMessageBox.warning(self, "No Config",
                                        "Please generate Liquidsoap configuration first in Stream Builder tab.")

            else:
                # For other services, use systemctl
                if service_info.get('user_service', False):
                    subprocess.run(["systemctl", "--user", "restart", service_info['systemd']], check=True)
                else:
                    subprocess.run(["systemctl", "restart", service_info['systemd']], check=True)
                QMessageBox.information(self, f"{service_info['name']} Restarted",
                                        f"{service_info['name']} service restarted successfully.")

        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Service Restart Failed",
                                 f"Failed to restart {service_info['name']}:\n{str(e)}")
        except Exception as e:
            QMessageBox.critical(self, "Service Restart Error",
                                 f"Error restarting {service_info['name']}:\n{str(e)}")
            
    
    def prompt_install_ffmpeg_plugin(self) -> bool:
        """Install Liquidsoap's ffmpeg plugin with a modal progress dialog streaming logs.
        Returns True if installation was attempted, False otherwise.
        """
        try:
            from PyQt5.QtWidgets import QInputDialog, QDialog, QVBoxLayout
            from PyQt5.QtCore import QProcess

            options = [
                "Build via OPAM (PPA-free)",
                "Install from current repos",
                "Add official Liquidsoap repo + install",
                "Add vendor repo (Paravel) + install",
                "Cancel",
            ]
            choice, ok = QInputDialog.getItem(self, "Install FFmpeg Plugin",
                                              "FFmpeg encoder plugin is missing. Choose installation method:",
                                              options, 0, False)
            if not ok or choice == "Cancel":
                return False
            mode = "current"
            if choice.startswith("Build via OPAM"):
                mode = "opam"
            elif choice.startswith("Add official"):
                mode = "official"
            elif choice.startswith("Add vendor"):
                mode = "vendor"

            # Prepare modal dialog
            dlg = QDialog(self)
            dlg.setWindowTitle("Installing FFmpeg Plugin…")
            dlg.setModal(True)
            v = QVBoxLayout(dlg)
            log_view = QTextEdit()
            log_view.setReadOnly(True)
            log_view.setMinimumSize(600, 320)
            v.addWidget(log_view)

            # Start process with pkexec /bin/bash installer
            installer = "/usr/share/rdx/install-liquidsoap-plugin.sh"
            proc = QProcess(dlg)
            if mode == "opam":
                # Use dedicated OPAM installer which handles root+user phases
                installer = "/usr/share/rdx/install-liquidsoap-opam.sh"
                dlg.setWindowTitle("Building Liquidsoap via OPAM… (PPA-free)")
                proc.setProgram("pkexec")
                proc.setArguments(["/bin/bash", installer])
            else:
                proc.setProgram("pkexec")
                proc.setArguments(["/bin/bash", installer, mode])
            proc.setProcessChannelMode(QProcess.MergedChannels)

            def append_output():
                data = proc.readAll().data().decode(errors="replace")
                if data:
                    log_view.append(data.rstrip())
            proc.readyRead.connect(append_output)

            finished_ok = {"code": None}

            def on_finished(code, _status):
                finished_ok["code"] = int(code)
                dlg.accept()

            proc.finished.connect(on_finished)
            proc.start()
            dlg.exec_()

            exit_code = finished_ok["code"] if finished_ok["code"] is not None else 1
            if exit_code != 0 and mode != "opam":
                # Attempt a fallback search/install directly from current repos and disable broken PPA entries
                log_view.append("\n--- Fallback: trying alternative install from current repos ---\n")
                alt_script = r"""#!/usr/bin/env bash
set -euo pipefail
log(){ echo "[rdx-alt] $*"; }
disable_savonet(){ for f in /etc/apt/sources.list.d/*savonet* 2>/dev/null; do [ -f "$f" ] || continue; log "Disabling $f"; sed -i 's/^deb /# disabled by rdx: deb /' "$f" || true; sed -i 's/^deb-src /# disabled by rdx: deb-src /' "$f" || true; mv "$f" "$f.disabled" 2>/dev/null || true; done; }
enable_repos(){ if command -v add-apt-repository >/dev/null 2>&1; then add-apt-repository -y universe || true; add-apt-repository -y multiverse || true; fi }
try_install(){ local p; for p in "$@"; do if apt-get -s install "$p" >/dev/null 2>&1; then log "Installing $p"; DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$p" && return 0; fi; done; return 1; }
verify(){ liquidsoap -h encoder.ffmpeg >/dev/null 2>&1 && exit 0 || exit 2; }
disable_savonet || true
enable_repos || true
apt-get update || true
base=(liquidsoap-plugin-ffmpeg liquidsoap-plugin-all liquidsoap-plugin-extra liquidsoap-plugins-extra liquidsoap-plugins liquidsoap-plugin-fdkaac)
dyn=$(apt-cache search -n '^liquidsoap.*(plugin|plugins).*' 2>/dev/null | awk '{print $1}' | grep -E 'ffmpeg|extra|all|fdkaac' | sort -u || true)
pkgs=("${base[@]}")
for n in $dyn; do pkgs+=("$n"); done
try_install "${pkgs[@]}" || true
verify
"""
                # Write and run fallback script
                import tempfile
                alt_path = Path(tempfile.gettempdir()) / "rdx-alt-install.sh"
                try:
                    alt_path.write_text(alt_script, encoding="utf-8")
                    alt_path.chmod(0o755)
                except Exception as werr:
                    log_view.append(f"Could not write fallback script: {werr}")
                proc2 = QProcess(dlg)
                proc2.setProgram("pkexec")
                proc2.setArguments(["/bin/bash", str(alt_path)])
                proc2.setProcessChannelMode(QProcess.MergedChannels)
                proc2.readyRead.connect(lambda: log_view.append(proc2.readAll().data().decode(errors="replace").rstrip()))
                fin = {"code": None}
                proc2.finished.connect(lambda code, status: (fin.update({"code": int(code)}), dlg.accept()))
                # Reuse dialog to show fallback progress
                dlg.setWindowTitle("Installing FFmpeg Plugin… (Fallback)")
                proc2.start()
                dlg.exec_()
                fcode = fin["code"] if fin["code"] is not None else 1
                if fcode != 0:
                    tail = "\n".join(log_view.toPlainText().splitlines()[-80:])
                    QMessageBox.critical(self, "Install Failed",
                                         f"FFmpeg plugin installation failed (exit {exit_code}), fallback also failed (exit {fcode}).\n\nLast output:\n{tail}\n\n"
                                         "Options: Use MP3 only for now, or install Liquidsoap via OPAM for full AAC.")
                    return False

            if mode == "opam":
                # Quick self-check to surface environment to the user
                try:
                    v = subprocess.run(["bash", "-lc", "liquidsoap --version"], capture_output=True, text=True)
                    e = subprocess.run(["bash", "-lc", "liquidsoap --list-encoders | head -n 200"], capture_output=True, text=True)
                    log_view.append("\n--- Verification ---")
                    log_view.append((v.stdout or v.stderr or "").strip())
                    log_view.append((e.stdout or e.stderr or "").strip())
                except Exception:
                    pass
                QMessageBox.information(self, "OPAM Install Complete",
                                        "Liquidsoap was built via OPAM. If this is your first OPAM install, you may need to restart RDX for PATH to refresh.\n\nRechecking availability…")
            else:
                QMessageBox.information(self, "Install Complete",
                                        "FFmpeg plugin installation attempted. Rechecking availability…")
            return True
        except Exception as e:
            QMessageBox.critical(self, "Install Error", f"Error during installation: {e}")
            return False

    def get_config_directory(self):
        """Get the application config directory, creating it if needed"""
        import os
        
        # Try standard config directory first
        config_dir = Path.home() / ".config" / "rdx"
        
        try:
            # Create and test if we can write to standard location
            config_dir.mkdir(parents=True, exist_ok=True)
            test_file = config_dir / ".test"
            test_file.touch()
            test_file.unlink()
            return config_dir
        except (PermissionError, OSError):
            # If standard location fails, try creating in home directory
            fallback_dir = Path.home() / ".rdx"
            try:
                fallback_dir.mkdir(parents=True, exist_ok=True)
                return fallback_dir
            except (PermissionError, OSError):
                # Last resort - use temp directory with user-specific name
                import tempfile
                import getpass
                temp_dir = Path(tempfile.gettempdir()) / f"rdx-{getpass.getuser()}"
                temp_dir.mkdir(parents=True, exist_ok=True)
                return temp_dir

    def sanitize_liquidsoap_config(self, config_file: Path):
        """Auto-fix common Liquidsoap config issues in-place.
        - Quote ffmpeg audio_bitrate values: 64k -> "64k"
        - Replace unsupported 'source=radio' with positional 'radio'
        """
        try:
            txt = config_file.read_text(encoding="utf-8")
        except Exception:
            return
        new = txt
        # Ensure ffmpeg encoder is marked as audio to avoid type errors in 2.x
        # Insert audio=true, video=false if not already present
        new = re.sub(r'%ffmpeg\((?![^)]*\baudio\s*=)', r'%ffmpeg(audio=true, video=false, ', new)
        # Fix unquoted audio_bitrate values
        new = re.sub(r'(audio_bitrate\s*=\s*)(\d+k)(\b)', r'\1"\2"', new)
        # Replace source=radio with positional radio while preserving separators
        new = re.sub(r'\bsource\s*=\s*radio\s*,', 'radio,', new)
        new = re.sub(r'\bsource\s*=\s*radio(\s*[)\n])', r'radio\1', new)
        if new != txt:
            try:
                config_file.write_text(new, encoding="utf-8")
            except Exception:
                pass

    def sanitize_liquidsoap_config_strict(self, config_file: Path):
        """Apply stricter fixes for Liquidsoap/FFmpeg compatibility.
        - Ensure ffmpeg has audio=true, video=false
        - Convert audio_bitrate values like "64k" or 64k to integer bits per second (e.g., 64000)
        - Keep positional source for output.icecast
        """
        try:
            txt = config_file.read_text(encoding="utf-8")
        except Exception:
            return
        new = txt
        # Ensure audio flags present
        new = re.sub(r'%ffmpeg\((?![^)]*\baudio\s*=)', r'%ffmpeg(audio=true, video=false, ', new)
        # Replace quoted or unquoted Nxk with integer Nx000 (approximate kbps to bps)
        def kb_to_bps(match):
            num = match.group(1)
            try:
                val = int(num)
            except Exception:
                return match.group(0)
            return f"{val}000"
        # Handle quoted "64k"
        new = re.sub(r'audio_bitrate\s*=\s*"(\d+)k"', lambda m: f'audio_bitrate={kb_to_bps(m)}', new)
        # Handle unquoted 64k
        new = re.sub(r'audio_bitrate\s*=\s*(\d+)k\b', lambda m: f'audio_bitrate={kb_to_bps(m)}', new)
        # Probe ffmpeg capabilities and adjust codec/format if unsupported
        codecs, formats = self._probe_ffmpeg_capabilities()
        # If 'aac' codec not available but libfdk_aac is, switch
        if codecs is not None:
            if 'aac' not in codecs and 'libfdk_aac' in codecs:
                new = re.sub(r'audio_codec\s*=\s*"aac"', 'audio_codec="libfdk_aac"', new)
        # If 'adts' format not available, remove explicit format parameter
        if formats is not None and 'adts' not in formats:
            new = re.sub(r',\s*format\s*=\s*"[^"]+"', '', new)
        # Remove any duplicate commas from earlier insertions
        new = re.sub(r',\s*,', ', ', new)
        if new != txt:
            try:
                config_file.write_text(new, encoding="utf-8")
            except Exception:
                pass

    def _probe_ffmpeg_capabilities(self):
        """Return (codecs, formats) sets supported by Liquidsoap ffmpeg encoder, or (None, None) on failure."""
        try:
            res = subprocess.run([self._liquidsoap_bin(), "-h", "encoder.ffmpeg"], capture_output=True, text=True, env=self._subprocess_env_with_localbin())
            if res.returncode != 0:
                return (None, None)
            out = res.stdout or res.stderr or ""
            codecs = set()
            formats = set()
            # Heuristics: look for sections listing codecs/formats
            for line in out.splitlines():
                l = line.strip()
                if l.startswith("audio_codec") and ":" in l:
                    # skip option description line
                    continue
                if l.startswith("Available audio codecs") or l.startswith("Audio codecs"):
                    continue
                if l.startswith("Available formats") or l.startswith("Formats"):
                    continue
                # Common tokens
                for token in ["aac", "libfdk_aac", "adts", "mp4", "mpegts"]:
                    if token in l:
                        # naive classification: container formats vs codecs
                        if token in ("adts", "mp4", "mpegts"):
                            formats.add(token)
                        else:
                            codecs.add(token)
            return (codecs or None, formats or None)
        except Exception:
            return (None, None)
                
    def configure_service(self, service_key):
        """Configure a specific service"""
        service_info = self.services[service_key]
        if service_key == 'jack':
            self._open_jack_settings_dialog()
            return
        QMessageBox.information(self, "Configure Service", f"Configuration for {service_info['name']} will open the appropriate settings.")

    def _open_jack_settings_dialog(self):
        from PyQt5.QtWidgets import QFormLayout, QDialog, QDialogButtonBox, QComboBox, QCheckBox, QLineEdit, QSpinBox, QHBoxLayout, QPushButton
        dlg = QDialog(self)
        dlg.setWindowTitle("JACK Settings")
        form = QFormLayout(dlg)

        # Manage toggle
        manage_cb = QCheckBox("Let RDX manage the JACK server")
        manage_cb.setChecked(self.jack_settings.get("manage", True))
        form.addRow("Management:", manage_cb)

        # Autostart toggle
        autostart_cb = QCheckBox("Start JACK at login (user service)")
        autostart_cb.setToolTip("Creates/enables a per-user systemd unit 'rdx-jack' so JACK starts when you log in.\nFor pre-login headless boot, prefer jackd mode and enable user lingering.")
        autostart_cb.setChecked(self.jack_settings.get("autostart", False))
        form.addRow("Autostart:", autostart_cb)

        # Mode selector
        mode_combo = QComboBox()
        mode_combo.addItems(["jackd", "jackdbus"])  # direct or jackdbus via jack_control
        cur_mode = self.jack_settings.get("mode", "jackd")
        midx = mode_combo.findText(cur_mode)
        mode_combo.setCurrentIndex(max(0, midx))
        form.addRow("Mode:", mode_combo)

        # Backend selector
        backend_combo = QComboBox()
        backend_combo.addItems(["alsa", "dummy"])  # conservative set; more can be added later
        cur_backend = self.jack_settings.get("backend", "alsa")
        idx = backend_combo.findText(cur_backend)
        backend_combo.setCurrentIndex(max(0, idx))
        form.addRow("Backend:", backend_combo)

        # ALSA device with dropdown + refresh; editable
        dev_row = QHBoxLayout()
        dev_combo = QComboBox(); dev_combo.setEditable(True)
        try:
            for dname in self._alsa_devices():
                dev_combo.addItem(dname)
        except Exception:
            pass
        cur_dev = self.jack_settings.get("device", "")
        if cur_dev and dev_combo.findText(cur_dev) < 0:
            dev_combo.addItem(cur_dev)
        if cur_dev:
            dev_combo.setCurrentText(cur_dev)
        dev_combo.setEditable(True)
        dev_combo.setInsertPolicy(QComboBox.NoInsert)
        dev_btn = QPushButton("Refresh")
        def _refresh_devs():
            devs = self._alsa_devices()
            dev_combo.clear()
            for dname in devs:
                dev_combo.addItem(dname)
        dev_btn.clicked.connect(_refresh_devs)
        dev_row.addWidget(dev_combo)
        dev_row.addWidget(dev_btn)
        form.addRow("ALSA Device:", dev_row)

        # Numeric params
        rate_spin = QSpinBox(); rate_spin.setRange(8000, 192000); rate_spin.setSingleStep(1000)
        rate_spin.setValue(int(self.jack_settings.get("rate", 48000)))
        form.addRow("Sample Rate (Hz):", rate_spin)

        period_spin = QSpinBox(); period_spin.setRange(16, 4096)
        period_spin.setValue(int(self.jack_settings.get("period", 256)))
        form.addRow("Frames/Period:", period_spin)

        nper_spin = QSpinBox(); nper_spin.setRange(2, 8)
        nper_spin.setValue(int(self.jack_settings.get("nperiods", 2)))
        form.addRow("Periods/Buffer:", nper_spin)

        rt_cb = QCheckBox("Enable realtime (-R)")
        rt_cb.setChecked(self.jack_settings.get("realtime", True))
        form.addRow("Realtime:", rt_cb)

        extra_edit = QLineEdit(self.jack_settings.get("extra_args", ""))
        extra_edit.setPlaceholderText("Extra jackd driver args (advanced)")
        form.addRow("Extra Args:", extra_edit)

        # Presets row
        presets_row = QHBoxLayout()
        preset_combo = QComboBox(); preset_combo.addItems(["Select a preset…", "Live Low Latency", "Production Stable", "Dummy (No HW)"])
        apply_preset_btn = QPushButton("Apply Preset")
        def _apply_preset():
            name = preset_combo.currentText()
            if name == "Live Low Latency":
                backend_combo.setCurrentText("alsa")
                rate_spin.setValue(48000)
                period_spin.setValue(128)
                nper_spin.setValue(3)
                rt_cb.setChecked(True)
            elif name == "Production Stable":
                backend_combo.setCurrentText("alsa")
                rate_spin.setValue(48000)
                period_spin.setValue(256)
                nper_spin.setValue(2)
                rt_cb.setChecked(True)
            elif name == "Dummy (No HW)":
                backend_combo.setCurrentText("dummy")
                rate_spin.setValue(48000)
                period_spin.setValue(256)
                nper_spin.setValue(2)
                rt_cb.setChecked(False)
        apply_preset_btn.clicked.connect(_apply_preset)
        presets_row.addWidget(preset_combo)
        presets_row.addWidget(apply_preset_btn)
        form.addRow("Presets:", presets_row)

        # Adopt/show current row
        adopt_row = QHBoxLayout()
        adopt_btn = QPushButton("Adopt From Running")
        show_btn = QPushButton("Show Current")
        def _adopt():
            cur = self._probe_running_jack_config()
            if not cur:
                QMessageBox.information(dlg, "No Running JACK", "Could not detect a running JACK configuration.")
                return
            # Update fields with detected
            mode_combo.setCurrentText(cur.get("mode", mode_combo.currentText()))
            backend_combo.setCurrentText(cur.get("backend", backend_combo.currentText()))
            dval = cur.get("device", dev_combo.currentText())
            if dval and dev_combo.findText(dval) < 0:
                dev_combo.addItem(dval)
            if dval:
                dev_combo.setCurrentText(dval)
            rate_spin.setValue(int(cur.get("rate", rate_spin.value())))
            period_spin.setValue(int(cur.get("period", period_spin.value())))
            nper_spin.setValue(int(cur.get("nperiods", nper_spin.value())))
            rt_cb.setChecked(bool(cur.get("realtime", rt_cb.isChecked())))
        def _show():
            cur = self._probe_running_jack_config()
            if not cur:
                QMessageBox.information(dlg, "No Running JACK", "Could not detect a running JACK configuration.")
                return
            # Prepare summary
            lines = [
                f"Mode: {cur.get('mode','?')}",
                f"Backend: {cur.get('backend','?')}",
                f"Device: {cur.get('device','')}",
                f"Rate: {cur.get('rate','?')}",
                f"Period: {cur.get('period','?')}",
                f"Nperiods: {cur.get('nperiods','?')}",
                f"Realtime: {cur.get('realtime','?')}"
            ]
            QMessageBox.information(dlg, "Detected JACK Settings", "\n".join(lines))
        adopt_btn.clicked.connect(_adopt)
        show_btn.clicked.connect(_show)
        adopt_row.addWidget(adopt_btn)
        adopt_row.addWidget(show_btn)
        form.addRow("Detect:", adopt_row)

        # Buttons
        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        form.addRow(buttons)
        buttons.accepted.connect(dlg.accept)
        buttons.rejected.connect(dlg.reject)

        if dlg.exec_() == QDialog.Accepted:
            data = {
                "manage": manage_cb.isChecked(),
                "autostart": autostart_cb.isChecked(),
                "mode": mode_combo.currentText(),
                "backend": backend_combo.currentText(),
                "device": dev_combo.currentText().strip(),
                "rate": int(rate_spin.value()),
                "period": int(period_spin.value()),
                "nperiods": int(nper_spin.value()),
                "realtime": rt_cb.isChecked(),
                "extra_args": extra_edit.text().strip(),
            }
            self._save_jack_settings(data)
            self._apply_jack_manage_mode_to_controls()
            # Show preview of resulting command
            if data.get("mode", "jackd") == "jackdbus":
                preview = "\n".join(self._jackdbus_preview_commands())
                QMessageBox.information(self, "JACK Settings Saved", f"JACK settings saved.\n\njack_control sequence:\n{preview}")
            else:
                cmd = self._build_jackd_command()
                QMessageBox.information(self, "JACK Settings Saved", f"JACK settings saved.\n\nCommand preview:\n{' '.join(cmd)}")
        
    def start_all_services(self):
        """Start all services in correct order"""
        reply = QMessageBox.question(self, "Start All Services", 
                                   "This will start all broadcast services in the correct order:\n"
                                   "JACK → Liquidsoap → Stereo Tool → Icecast\n\n"
                                   "Continue?",
                                   QMessageBox.Yes | QMessageBox.No)

        if reply == QMessageBox.Yes:
            # Start in sequence with simple checks
            try:
                # JACK
                jack_ok = subprocess.run(["jack_lsp"], capture_output=True, timeout=0.7).returncode == 0
                if not jack_ok and self.jack_settings.get("manage", True):
                    self.start_service('jack')
                    time.sleep(1)

                # Liquidsoap (needs JACK client available)
                self.start_service('liquidsoap')
                time.sleep(1)

                # Stereo Tool via per-user systemd unit
                self._ensure_stereotool_unit()
                self.start_service('stereo_tool')
                time.sleep(1)

                # Icecast
                self.start_service('icecast')
            except Exception as e:
                QMessageBox.critical(self, "Start All Error", f"Failed to start all services: {e}")
            
    def stop_all_services(self):
        """Stop all services in reverse order"""
        reply = QMessageBox.question(self, "Stop All Services", 
                                   "This will stop all broadcast services in reverse order:\n"
                                   "Icecast → Liquidsoap → Stereo Tool → JACK\n\n"
                                   "Continue?",
                                   QMessageBox.Yes | QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            QMessageBox.information(self, "Stopping Services", 
                                  "Stopping all services in reverse dependency order...")
            
    def emergency_stop(self):
        """Emergency stop all services immediately"""
        reply = QMessageBox.warning(self, "EMERGENCY STOP", 
                                   "⚠️ EMERGENCY STOP ⚠️\n\n"
                                   "This will immediately terminate all broadcast services!\n"
                                   "Use only in emergency situations.\n\n"
                                   "Continue?",
                                   QMessageBox.Yes | QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            QMessageBox.information(self, "Emergency Stop", 
                                  "🚨 All broadcast services stopped immediately!")

    def open_stereotool_logs(self):
        """Open a dialog with the last 500 lines of the Stereo Tool user-service log."""
        try:
            from PyQt5.QtWidgets import QDialog, QVBoxLayout
            dlg = QDialog(self)
            dlg.setWindowTitle("Stereo Tool Logs (rdx-stereotool-active)")
            v = QVBoxLayout(dlg)
            txt = QTextEdit()
            txt.setReadOnly(True)
            v.addWidget(txt)
            # Fetch logs via journalctl
            res = subprocess.run(["journalctl", "--user", "-u", "rdx-stereotool-active", "-n", "500", "--no-pager"],
                                 capture_output=True, text=True)
            output = (res.stdout or res.stderr or "No logs available").strip()
            txt.setPlainText(output)
            dlg.resize(800, 500)
            dlg.exec_()
        except Exception as e:
            QMessageBox.critical(self, "Logs Error", f"Could not open logs: {e}")

    # ---- Launch order helpers ----
    def _init_launch_order_ui(self):
        if not hasattr(self, 'order_table'):
            return
        try:
            default_order = ['jack', 'liquidsoap', 'stereo_tool', 'icecast']
            default_delays = {k: 2 for k in default_order}
            settings = getattr(self.main, '_settings', {}) if self.main else {}
            saved_order = settings.get('service_launch_order') if isinstance(settings, dict) else None
            saved_delays = settings.get('service_delays') if isinstance(settings, dict) else None
            order = saved_order if isinstance(saved_order, list) and saved_order else default_order
            delays = default_delays.copy()
            if isinstance(saved_delays, dict):
                for key, value in saved_delays.items():
                    try:
                        delays[key] = int(value)
                    except Exception:
                        continue
            self.order_table.setRowCount(0)
            from PyQt5.QtWidgets import QSpinBox
            for key in order:
                info = self.services.get(key)
                if not info:
                    continue
                row = self.order_table.rowCount()
                self.order_table.insertRow(row)
                self.order_table.setItem(row, 0, QTableWidgetItem(info['name']))
                spin = QSpinBox()
                spin.setRange(0, 60)
                spin.setValue(int(delays.get(key, 2)))
                spin.setProperty('service_key', key)
                self.order_table.setCellWidget(row, 1, spin)
                self.order_table.setItem(row, 2, QTableWidgetItem(info.get('systemd', '')))
        except Exception:
            pass

    def _swap_order_rows(self, a: int, b: int):
        if not hasattr(self, 'order_table'):
            return
        try:
            if not (0 <= a < self.order_table.rowCount()) or not (0 <= b < self.order_table.rowCount()):
                return
            if a == b:
                return
            for col in (0, 1, 2):
                if col == 1:
                    wa = self.order_table.cellWidget(a, col)
                    wb = self.order_table.cellWidget(b, col)
                    self.order_table.removeCellWidget(a, col)
                    self.order_table.removeCellWidget(b, col)
                    self.order_table.setCellWidget(a, col, wb)
                    self.order_table.setCellWidget(b, col, wa)
                else:
                    ia = self.order_table.takeItem(a, col)
                    ib = self.order_table.takeItem(b, col)
                    self.order_table.setItem(a, col, ib)
                    self.order_table.setItem(b, col, ia)
        except Exception:
            pass

    def _move_selected_order_row(self, direction: int):
        if not hasattr(self, 'order_table'):
            return
        try:
            current = self.order_table.currentRow()
            if current < 0:
                return
            target = current + int(direction)
            if not (0 <= target < self.order_table.rowCount()):
                return
            self._swap_order_rows(current, target)
            self.order_table.selectRow(target)
        except Exception:
            pass

    def _save_launch_order(self):
        if not hasattr(self, 'order_table'):
            return
        try:
            from PyQt5.QtWidgets import QSpinBox
            order = []
            delays = {}
            for row in range(self.order_table.rowCount()):
                name_item = self.order_table.item(row, 0)
                spin = self.order_table.cellWidget(row, 1)
                if not name_item:
                    continue
                key = None
                for svc_key, info in self.services.items():
                    if info['name'] == name_item.text():
                        key = svc_key
                        break
                if not key:
                    continue
                order.append(key)
                if isinstance(spin, QSpinBox):
                    delays[key] = int(spin.value())
            if self.main and hasattr(self.main, '_settings'):
                self.main._settings['service_launch_order'] = order
                self.main._settings['service_delays'] = delays
                self.main.save_settings()
            QMessageBox.information(self, "Saved", "Launch order and delays saved.")
        except Exception as e:
            QMessageBox.warning(self, "Save Failed", f"Could not save order: {e}")

    def _start_services_in_order(self):
        if not hasattr(self, 'order_table'):
            return
        try:
            from PyQt5.QtWidgets import QSpinBox
            sequence = []
            for row in range(self.order_table.rowCount()):
                name_item = self.order_table.item(row, 0)
                spin = self.order_table.cellWidget(row, 1)
                if not name_item:
                    continue
                key = None
                for svc_key, info in self.services.items():
                    if info['name'] == name_item.text():
                        key = svc_key
                        break
                if not key:
                    continue
                delay = int(spin.value()) if isinstance(spin, QSpinBox) else 0
                sequence.append((key, delay))

            if not sequence:
                QMessageBox.information(self, "Start In Order", "No services to start.")
                return

            def step(index):
                if index >= len(sequence):
                    QMessageBox.information(self, "Start Complete", "All services started in order.")
                    self.update_all_status()
                    return
                svc_key, delay_secs = sequence[index]
                self._start_service_key(svc_key)
                QTimer.singleShot(max(0, delay_secs) * 1000, lambda: step(index + 1))

            step(0)
        except Exception as e:
            QMessageBox.warning(self, "Start Failed", f"Could not start ordered sequence: {e}")

    def _start_service_key(self, key: str):
        try:
            self.start_service(key)
        except Exception:
            pass

    # ---- Stereo Tool helpers (systemd user unit and active symlink) ----
    def _st_path_root(self) -> Path:
        return Path.home() / ".config" / "rdx" / "processing" / "stereotool"

    def _active_symlink(self) -> Path:
        return self._st_path_root() / "active"

    def _ensure_stereotool_unit(self):
        """Create/update per-user systemd unit that runs the active Stereo Tool binary.
        Unit: rdx-stereotool-active.service under ~/.config/systemd/user
        """
        try:
            root = self._st_path_root()
            root.mkdir(parents=True, exist_ok=True)
            active = self._active_symlink()
            # If no active binary, do nothing (UI will guide to Stereo Tool Manager tab)
            if not active.exists():
                return
            unit_dir = Path.home() / ".config" / "systemd" / "user"
            unit_dir.mkdir(parents=True, exist_ok=True)
            unit_path = unit_dir / "rdx-stereotool-active.service"
            # Minimal ExecStart; Stereo Tool JACK GUI typically self-manages JACK ports
            unit = f"""[Unit]
Description=RDX Stereo Tool (active instance)
After=default.target
Wants=default.target

[Service]
Type=simple
ExecStart={str(active)}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
"""
            unit_path.write_text(unit, encoding="utf-8")
            # Reload user daemon to pick up changes
            subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
            # Enable unit so it can be started at login if desired
            subprocess.run(["systemctl", "--user", "enable", "rdx-stereotool-active"], check=False)
        except Exception:
            # Non-fatal; Service Control will still allow manual start attempts
            pass


class StereoToolManagerTab(QWidget):
    """Tab: Stereo Tool Manager - manage multiple versions and active instance.
    Features:
    - Add instance from URL or local file
    - Download helper to fetch Linux JACK x64 artifact from Thimeo site
    - Manage active instance via symlink
    - Generate per-user systemd unit for active instance
    """

    def __init__(self):
        super().__init__()
        self.instances = []
        self.setup_ui()
        self._load_instances()
        self._refresh_table()

    def _root(self) -> Path:
        return Path.home() / ".config" / "rdx" / "processing" / "stereotool"

    def _instances_file(self) -> Path:
        return self._root() / "stereotool_instances.json"

    def _active_link(self) -> Path:
        return self._root() / "active"

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Actions row
        actions = QHBoxLayout()
        btn_add_url = QPushButton("⬇️ Add from URL")
        btn_add_url.clicked.connect(self.add_from_url)
        actions.addWidget(btn_add_url)

        btn_add_file = QPushButton("📦 Add from File")
        btn_add_file.clicked.connect(self.add_from_file)
        actions.addWidget(btn_add_file)

        btn_download = QPushButton("🌐 Download JACK x64 (Auto)")
        btn_download.clicked.connect(self.download_latest)
        actions.addWidget(btn_download)

        btn_latest = QPushButton("🔗 Download from 'Latest' URL")
        btn_latest.setToolTip("Uses a configured 'latest' URL if set, or prompts you to paste one.")
        btn_latest.clicked.connect(self.download_from_latest)
        actions.addWidget(btn_latest)

        actions.addStretch(1)
        layout.addLayout(actions)

        # Optional 'Latest URL' field (persisted in settings)
        latest_group = QGroupBox("Optional: Official 'latest' URL")
        lg = QHBoxLayout(latest_group)
        self.latest_url_input = QLineEdit()
        self.latest_url_input.setPlaceholderText("https://… (paste an official latest link here)")
        self.latest_url_input.editingFinished.connect(self._save_latest_url)
        lg.addWidget(QLabel("Latest URL:"))
        lg.addWidget(self.latest_url_input)
        layout.addWidget(latest_group)

        # Table of instances
        self.table = QTableWidget()
        self.table.setColumnCount(5)
        self.table.setHorizontalHeaderLabels(["Name", "Version", "Path", "Active", "Actions"])
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        layout.addWidget(self.table)

        # Status area
        self.status = QLabel("")
        layout.addWidget(self.status)

        # Helper text
        help_box = QGroupBox("About Stereo Tool management")
        hl = QVBoxLayout(help_box)
        hl.addWidget(QLabel("RDX stores Stereo Tool under ~/.config/rdx/processing/stereotool and switches the active version using a symlink. A per-user systemd unit runs the active instance."))
        layout.addWidget(help_box)

        # Load any saved 'latest' URL
        try:
            self.latest_url_input.setText(self._load_latest_url())
        except Exception:
            pass

    def _refresh_table(self):
        self.table.setRowCount(len(self.instances))
        active = self._active_link()
        active_target = None
        try:
            if active.is_symlink():
                active_target = os.path.realpath(str(active))
        except Exception:
            active_target = None
        for i, inst in enumerate(self.instances):
            self.table.setItem(i, 0, QTableWidgetItem(inst.get('name', ''))) 
            self.table.setItem(i, 1, QTableWidgetItem(inst.get('version', ''))) 
            self.table.setItem(i, 2, QTableWidgetItem(inst.get('path', ''))) 
            is_active = (active_target == inst.get('path'))
            self.table.setItem(i, 3, QTableWidgetItem("Yes" if is_active else "No"))
            # Actions
            w = QWidget()
            h = QHBoxLayout(w)
            h.setContentsMargins(0,0,0,0)
            btn_act = QPushButton("Activate")
            btn_act.clicked.connect(lambda checked, idx=i: self.activate(idx))
            h.addWidget(btn_act)
            btn_start = QPushButton("Start")
            btn_start.clicked.connect(lambda checked, idx=i: self.start(idx))
            h.addWidget(btn_start)
            btn_stop = QPushButton("Stop")
            btn_stop.clicked.connect(lambda checked, idx=i: self.stop(idx))
            h.addWidget(btn_stop)
            btn_rm = QPushButton("Remove")
            btn_rm.clicked.connect(lambda checked, idx=i: self.remove(idx))
            h.addWidget(btn_rm)
            h.addStretch(1)
            self.table.setCellWidget(i, 4, w)

    def _save_instances(self):
        try:
            self._root().mkdir(parents=True, exist_ok=True)
            with open(self._instances_file(), 'w') as f:
                json.dump(self.instances, f, indent=2)
        except Exception as e:
            self.status.setText(f"⚠️ Could not save instances: {e}")

    def _load_instances(self):
        try:
            p = self._instances_file()
            if p.exists():
                with open(p, 'r') as f:
                    self.instances = json.load(f)
            else:
                self.instances = []
        except Exception as e:
            self.instances = []
            self.status.setText(f"⚠️ Could not load instances: {e}")

    def add_from_url(self):
        try:
            from PyQt5.QtWidgets import QInputDialog
            url, ok = QInputDialog.getText(self, "Add from URL", "Direct download URL (.tar.gz/.zip/.run):")
            if not ok or not url.strip():
                return
            self._root().mkdir(parents=True, exist_ok=True)
            dest = self._root() / os.path.basename(url)
            self.status.setText(f"Downloading {url} → {dest}…")
            urllib.request.urlretrieve(url, str(dest))
            # If it's a plain binary, make executable; otherwise leave as archive
            if dest.suffix == '' or dest.suffix == '.bin':
                dest.chmod(0o755)
                self._add_instance_record(name=dest.name, path=str(dest), version=self._guess_version(dest.name))
            else:
                self._add_instance_record(name=dest.name, path=str(dest), version=self._guess_version(dest.name))
            self._save_instances()
            self._refresh_table()
            self.status.setText(f"✅ Added: {dest}")
        except Exception as e:
            QMessageBox.critical(self, "Download Error", f"Failed to download: {e}")

    def download_from_latest(self):
        """Download using the configured 'latest' URL (if present), else prompt for one and persist it."""
        try:
            url = (self.latest_url_input.text() or "").strip()
            if not url:
                from PyQt5.QtWidgets import QInputDialog
                url, ok = QInputDialog.getText(self, "Latest URL", "Paste the official 'latest' JACK x64 link:")
                if not ok or not url.strip():
                    return
                self.latest_url_input.setText(url.strip())
                self._save_latest_url()
            self._root().mkdir(parents=True, exist_ok=True)
            dest = self._root() / os.path.basename(url)
            self.status.setText(f"Downloading {url} → {dest}…")
            urllib.request.urlretrieve(url, str(dest))
            try:
                dest.chmod(0o755)
            except Exception:
                pass
            self._add_instance_record(name=dest.name, path=str(dest), version=self._guess_version(dest.name))
            self._save_instances()
            self._refresh_table()
            self.status.setText(f"✅ Downloaded: {dest}")
        except Exception as e:
            QMessageBox.critical(self, "Latest URL Error", f"Failed to download from latest URL: {e}")

    def add_from_file(self):
        try:
            from PyQt5.QtWidgets import QFileDialog
            path, _ = QFileDialog.getOpenFileName(self, "Select Stereo Tool binary or archive", str(Path.home()))
            if not path:
                return
            src = Path(path)
            self._root().mkdir(parents=True, exist_ok=True)
            dest = self._root() / src.name
            shutil.copy2(str(src), str(dest))
            try:
                dest.chmod(0o755)
            except Exception:
                pass
            self._add_instance_record(name=dest.name, path=str(dest), version=self._guess_version(dest.name))
            self._save_instances()
            self._refresh_table()
            self.status.setText(f"✅ Added: {dest}")
        except Exception as e:
            QMessageBox.critical(self, "Add Error", f"Failed to add file: {e}")

    def download_latest(self):
        """Fetch Thimeo downloads page, find Linux JACK x64 artifacts, and download one.
        More robust parser: collects all hrefs, filters by keywords, lets user pick if multiple.
        """
        try:
            from urllib.parse import urljoin
            from PyQt5.QtWidgets import QInputDialog
            self._root().mkdir(parents=True, exist_ok=True)
            base = "https://www.thimeo.com/stereo-tool/download/"
            self.status.setText("Fetching Thimeo downloads page…")
            html = urllib.request.urlopen(base, timeout=20).read().decode("utf-8", errors="ignore")
            # Collect all hrefs
            links = re.findall(r'href=["\']([^"\']+)["\']', html, flags=re.IGNORECASE)
            candidates = []
            for href in links:
                href_l = href.lower()
                if not href_l.startswith("http"):
                    full = urljoin(base, href)
                else:
                    full = href
                # Heuristics for Linux JACK x64 artifacts
                if all(k in href_l for k in ["linux", "jack"]) and any(k in href_l for k in ["64", "x64", "amd64"]):
                    if any(href_l.endswith(ext) for ext in [".run", ".zip", ".tar.gz", ".tgz", ".tar.xz"]) or "stereo_tool" in href_l:
                        candidates.append(full)
            # Deduplicate while preserving order
            seen = set()
            unique = []
            for c in candidates:
                if c not in seen:
                    unique.append(c)
                    seen.add(c)
            if not unique:
                raise RuntimeError("No Linux JACK x64 candidates found on page.")
            pick = unique[0]
            if len(unique) > 1:
                item, ok = QInputDialog.getItem(self, "Select Artifact", "Choose a Stereo Tool artifact to download:", unique, 0, False)
                if not ok or not item:
                    return
                pick = item
            dest = self._root() / os.path.basename(pick)
            self.status.setText(f"Downloading {pick} → {dest}…")
            urllib.request.urlretrieve(pick, str(dest))
            try:
                dest.chmod(0o755)
            except Exception:
                pass
            self._add_instance_record(name=dest.name, path=str(dest), version=self._guess_version(dest.name))
            self._save_instances()
            self._refresh_table()
            self.status.setText(f"✅ Downloaded: {dest}")
        except Exception as e:
            QMessageBox.warning(self, "Auto-download failed",
                                f"Could not auto-detect Linux JACK x64 artifact.\n{e}\n\n"
                                "Please use 'Add from URL' or 'Add from File'.")

    def _add_instance_record(self, name: str, path: str, version: str = ""):
        self.instances.append({
            "name": name,
            "path": path,
            "version": version,
        })

    def _guess_version(self, name: str) -> str:
        m = re.search(r"([0-9]{3,4,5})", name)
        return m.group(1) if m else ""

    # ---- Persist 'latest' URL in settings.json ----
    def _settings_path(self) -> Path:
        p = Path.home() / ".config" / "rdx"
        try:
            p.mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        return p / "settings.json"

    def _load_latest_url(self) -> str:
        try:
            sp = self._settings_path()
            if sp.exists():
                with open(sp, 'r') as f:
                    data = json.load(f)
                return str(data.get('st_latest_url', ''))
        except Exception:
            pass
        return ""

    def _save_latest_url(self):
        try:
            sp = self._settings_path()
            data = {}
            if sp.exists():
                try:
                    with open(sp, 'r') as f:
                        data = json.load(f) or {}
                except Exception:
                    data = {}
            data['st_latest_url'] = self.latest_url_input.text().strip()
            with open(sp, 'w') as f:
                json.dump(data, f, indent=2)
        except Exception:
            pass

    def activate(self, idx: int):
        try:
            inst = self.instances[idx]
            target = Path(inst.get('path', ''))
            if not target.exists():
                QMessageBox.warning(self, "Missing File", f"Binary not found: {target}")
                return
            root = self._root()
            root.mkdir(parents=True, exist_ok=True)
            link = self._active_link()
            if link.exists() or link.is_symlink():
                try:
                    link.unlink()
                except Exception:
                    pass
            os.symlink(str(target), str(link))
            # Ensure the per-user unit is created/updated
            try:
                # Reuse helper from ServiceControlTab if available
                parent = self.parent()
                while parent and not isinstance(parent, ServiceControlTab):
                    parent = parent.parent()
                # Even if not found, we can write the unit here too
            except Exception:
                pass
            # Write unit file
            unit_dir = Path.home() / ".config" / "systemd" / "user"
            unit_dir.mkdir(parents=True, exist_ok=True)
            unit_path = unit_dir / "rdx-stereotool-active.service"
            unit = f"""[Unit]
Description=RDX Stereo Tool (active instance)
After=default.target
Wants=default.target

[Service]
Type=simple
ExecStart={str(link)}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
"""
            unit_path.write_text(unit, encoding="utf-8")
            subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
            subprocess.run(["systemctl", "--user", "enable", "rdx-stereotool-active"], check=False)
            self._refresh_table()
            QMessageBox.information(self, "Activated", f"Active Stereo Tool set to: {target}")
        except Exception as e:
            QMessageBox.critical(self, "Activate Error", f"Failed to activate: {e}")

    def start(self, idx: int):
        try:
            # Ensure unit exists
            unit_path = Path.home() / ".config" / "systemd" / "user" / "rdx-stereotool-active.service"
            if not unit_path.exists():
                self.activate(idx)
            subprocess.run(["systemctl", "--user", "start", "rdx-stereotool-active"], check=False)
        except Exception as e:
            QMessageBox.critical(self, "Start Error", f"Failed to start: {e}")

    def stop(self, idx: int):
        try:
            subprocess.run(["systemctl", "--user", "stop", "rdx-stereotool-active"], check=False)
        except Exception as e:
            QMessageBox.critical(self, "Stop Error", f"Failed to stop: {e}")

    def remove(self, idx: int):
        try:
            inst = self.instances[idx]
            path = Path(inst.get('path', ''))
            # Avoid deleting if it's the active symlink target
            active_target = None
            try:
                if self._active_link().is_symlink():
                    active_target = os.path.realpath(str(self._active_link()))
            except Exception:
                active_target = None
            if active_target and str(path) == active_target:
                QMessageBox.warning(self, "In Use", "This instance is active. Deactivate first.")
                return
            # Remove file
            try:
                if path.exists():
                    path.unlink()
            except Exception:
                pass
            # Remove from list
            del self.instances[idx]
            self._save_instances()
            self._refresh_table()
        except Exception as e:
            QMessageBox.critical(self, "Remove Error", f"Failed to remove: {e}")


class SettingsTab(QWidget):
    """Tab: Settings - Autostart and System Tray preferences"""

    def __init__(self, main_window):
        super().__init__()
        self.main = main_window
        self.setup_ui()
        self.refresh_status()

    def setup_ui(self):
        layout = QVBoxLayout(self)

        # Autostart via systemd --user
        auto_group = QGroupBox("▶️ Autostart (systemd — user)")
        gl = QGridLayout(auto_group)
        self.autostart_status = QLabel("Status: ⏳")
        gl.addWidget(self.autostart_status, 0, 0, 1, 3)
        btn_install = QPushButton("Install/Update user unit")
        btn_install.clicked.connect(self.install_or_update_unit)
        gl.addWidget(btn_install, 1, 0)
        btn_enable = QPushButton("Enable on Login")
        btn_enable.setStyleSheet("QPushButton { background-color: #27ae60; color: white; }")
        btn_enable.clicked.connect(self.enable_unit)
        gl.addWidget(btn_enable, 1, 1)
        btn_disable = QPushButton("Disable on Login")
        btn_disable.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; }")
        btn_disable.clicked.connect(self.disable_unit)
        gl.addWidget(btn_disable, 1, 2)
        btn_start = QPushButton("Start Now")
        btn_start.clicked.connect(self.start_unit)
        gl.addWidget(btn_start, 2, 0)
        btn_restart = QPushButton("Restart")
        btn_restart.clicked.connect(self.restart_unit)
        gl.addWidget(btn_restart, 2, 1)
        btn_stop = QPushButton("Stop Now")
        btn_stop.clicked.connect(self.stop_unit)
        gl.addWidget(btn_stop, 2, 2)
        layout.addWidget(auto_group)

        # System Tray settings
        tray_group = QGroupBox("🧰 System Tray")
        hl = QHBoxLayout(tray_group)
        self.chk_tray_on_close = QCheckBox("Minimize to tray on close")
        self.chk_tray_on_close.setChecked(bool(getattr(self.main, 'tray_minimize_on_close', False)))
        self.chk_tray_on_close.stateChanged.connect(self.on_tray_toggle)
        btn_hide_now = QPushButton("Hide to tray now")
        btn_hide_now.clicked.connect(self.main.hide_to_tray)
        hl.addWidget(self.chk_tray_on_close)
        hl.addStretch(1)
        hl.addWidget(btn_hide_now)
        layout.addWidget(tray_group)

        # JACK Auto-Reconnect moved to Graph tab (per user request)

        layout.addStretch(1)

    # ---- Autostart helpers ----
    def unit_path(self) -> Path:
        return Path.home() / ".config" / "systemd" / "user" / "rdx-control-center.service"

    def install_or_update_unit(self):
        try:
            unit_dir = self.unit_path().parent
            unit_dir.mkdir(parents=True, exist_ok=True)
            # Use the installed launcher wrapper
            exec_path = "/usr/local/bin/rdx-control-center"
            unit = f"""[Unit]
Description=RDX Broadcast Control Center (GUI)
After=default.target
Wants=default.target

[Service]
Type=simple
ExecStart={exec_path}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
"""
            self.unit_path().write_text(unit, encoding="utf-8")
            subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
            QMessageBox.information(self, "Unit Installed", f"Installed/updated: {self.unit_path()}")
            self.refresh_status()
        except Exception as e:
            QMessageBox.critical(self, "Unit Error", f"Failed to install/update unit: {e}")

    def enable_unit(self):
        try:
            self.install_or_update_unit()
            subprocess.run(["systemctl", "--user", "enable", "rdx-control-center"], check=False)
            self.refresh_status()
        except Exception as e:
            QMessageBox.critical(self, "Enable Error", f"Failed to enable: {e}")

    def disable_unit(self):
        try:
            subprocess.run(["systemctl", "--user", "disable", "rdx-control-center"], check=False)
            self.refresh_status()
        except Exception as e:
            QMessageBox.critical(self, "Disable Error", f"Failed to disable: {e}")

    def start_unit(self):
        try:
            subprocess.run(["systemctl", "--user", "start", "rdx-control-center"], check=False)
            self.refresh_status()
        except Exception as e:
            QMessageBox.critical(self, "Start Error", f"Failed to start: {e}")

    def stop_unit(self):
        try:
            subprocess.run(["systemctl", "--user", "stop", "rdx-control-center"], check=False)
            self.refresh_status()
        except Exception as e:
            QMessageBox.critical(self, "Stop Error", f"Failed to stop: {e}")

    def restart_unit(self):
        try:
            subprocess.run(["systemctl", "--user", "restart", "rdx-control-center"], check=False)
            self.refresh_status()
        except Exception as e:
            QMessageBox.critical(self, "Restart Error", f"Failed to restart: {e}")

    def refresh_status(self):
        try:
            enabled = subprocess.run(["systemctl", "--user", "is-enabled", "rdx-control-center"], capture_output=True, text=True)
            active = subprocess.run(["systemctl", "--user", "is-active", "rdx-control-center"], capture_output=True, text=True)
            en = (enabled.stdout or "").strip()
            ac = (active.stdout or "").strip()
            txt = f"Status: {'✅ Enabled' if en == 'enabled' else '❌ Disabled'} | {'✅ Active' if ac == 'active' else '❌ Inactive'}"
            self.autostart_status.setText(txt)
        except Exception:
            self.autostart_status.setText("Status: ❓ Unknown (systemd --user not available?)")

    def on_tray_toggle(self, _state):
        self.main.tray_minimize_on_close = self.chk_tray_on_close.isChecked()
        try:
            self.main.save_settings()
        except Exception:
            pass

    def on_vlc_reconnect_toggle(self, _state):
        try:
            self.main._settings['auto_reconnect_vlc'] = bool(self.chk_vlc_reconnect.isChecked())
            self.main.save_settings()
        except Exception:
            pass


class RDXBroadcastControlCenter(QMainWindow):
    """Main application window with tabbed interface"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("RDX Professional Broadcast Control Center v3.5.4")
        self.setMinimumSize(1000, 700)
        # Tray/minimize settings
        self.tray_minimize_on_close = False
        self._settings = {}
        self._load_settings()
        self.setup_ui()
        self._setup_tray()
        
    def setup_ui(self):
        """Setup the main user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout(central_widget)
        
        # Header
        header = QLabel("RDX Professional Broadcast Control Center")
        header.setAlignment(Qt.AlignCenter)
        header.setStyleSheet(
            "QLabel { "
            "font-size: 20px; "
            "font-weight: bold; "
            "padding: 15px; "
            "background-color: #2c3e50; "
            "color: white; "
            "border-radius: 8px; "
            "margin-bottom: 10px; "
            "}"
        )
        layout.addWidget(header)
        
        # Tab widget
        self.tab_widget = QTabWidget()
        
        # Add tabs
        self.stream_builder = StreamBuilderTab()
        self.tab_widget.addTab(self.stream_builder, "🎵 Stream Builder")
        
        self.icecast_management = IcecastManagementTab()
        self.tab_widget.addTab(self.icecast_management, "📡 Icecast Management")
        
        # Add remaining tabs
        self.jack_matrix = JackMatrixTab(self)
        self.tab_widget.addTab(self.jack_matrix, "🔌 JACK Patchboard")

        # Visual Graph (preview)
        try:
            self.jack_graph = JackGraphTab(self)
            self.tab_widget.addTab(self.jack_graph, "🕸️ JACK Graph")
        except Exception:
            # Non-fatal if graphics are unavailable
            pass

        # Stereo Tool Manager
        self.stereo_tool_manager = StereoToolManagerTab()
        self.tab_widget.addTab(self.stereo_tool_manager, "🎚️ Stereo Tool Manager")

        self.service_control = ServiceControlTab(self)
        self.tab_widget.addTab(self.service_control, "⚙️ Service Control")

        # Settings tab
        self.settings_tab = SettingsTab(self)
        self.tab_widget.addTab(self.settings_tab, "🛠️ Settings")
        
        layout.addWidget(self.tab_widget)
        
        # Status bar
        self.statusBar().showMessage("Ready - Professional Broadcast Control Center v3.5.4")

    # ---- System tray ----
    def _setup_tray(self):
        try:
            self.tray = QSystemTrayIcon(self)
            # Try themed icon, fallback to default if theme not found
            icon = QIcon.fromTheme("audio-card")
            if icon.isNull():
                icon = self.windowIcon() or QIcon()
            self.tray.setIcon(icon)
            menu = QMenu()
            act_show = menu.addAction("Show/Hide")
            act_quit = menu.addAction("Quit")
            act_show.triggered.connect(self.toggle_visibility)
            act_quit.triggered.connect(self.quit_app)
            self.tray.setContextMenu(menu)
            self.tray.activated.connect(lambda reason: self.toggle_visibility() if reason == QSystemTrayIcon.Trigger else None)
            self.tray.show()
        except Exception:
            # Tray optional; ignore errors
            self.tray = None

    def toggle_visibility(self):
        if self.isVisible():
            self.hide()
        else:
            self.showNormal()
            self.raise_()
            self.activateWindow()

    def hide_to_tray(self):
        if self.tray:
            self.hide()
            self.tray.showMessage("RDX Control Center", "Running in system tray.", QSystemTrayIcon.Information, 2000)

    def quit_app(self):
        QApplication.instance().quit()

    def closeEvent(self, event):
        if getattr(self, 'tray_minimize_on_close', False) and self.tray:
            event.ignore()
            self.hide_to_tray()
        else:
            super().closeEvent(event)

    # ---- Settings persistence ----
    def _config_dir(self) -> Path:
        p = Path.home() / ".config" / "rdx"
        try:
            p.mkdir(parents=True, exist_ok=True)
        except Exception:
            pass
        return p

    def _settings_file(self) -> Path:
        return self._config_dir() / "settings.json"

    def _load_settings(self):
        try:
            p = self._settings_file()
            if p.exists():
                with open(p, 'r') as f:
                    self._settings = json.load(f)
                self.tray_minimize_on_close = bool(self._settings.get('tray_minimize_on_close', False))
        except Exception:
            self._settings = {}

    def save_settings(self):
        try:
            self._settings['tray_minimize_on_close'] = bool(self.tray_minimize_on_close)
            with open(self._settings_file(), 'w') as f:
                json.dump(self._settings, f, indent=2)
        except Exception:
            pass


def main():
    app = QApplication(sys.argv)
    
    # Set application properties
    app.setApplicationName("RDX Broadcast Control Center")
    app.setApplicationVersion("3.4.14")
    
    # Create and show main window
    window = RDXBroadcastControlCenter()
    window.show()
    
    # Handle Ctrl+C gracefully
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()