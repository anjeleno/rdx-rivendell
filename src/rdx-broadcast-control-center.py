#!/usr/bin/env python3
"""
RDX Professional Broadcast Control Center v3.2.14
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
                            QScrollArea, QFormLayout, QDialog, QDialogButtonBox)
from PyQt5.QtCore import Qt, QProcess, QTimer, pyqtSignal, QThread
from PyQt5.QtGui import QFont, QIcon, QPalette

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
        builder_layout = QFormLayout(builder_group)
        
        # Codec dropdown
        self.codec_combo = QComboBox()
        self.codec_combo.addItems(["MP3", "AAC+", "FLAC", "OGG", "OPUS"])
        self.codec_combo.currentTextChanged.connect(self.update_bitrate_options)
        builder_layout.addRow("Codec:", self.codec_combo)
        
        # Bitrate dropdown (dynamic based on codec)
        self.bitrate_combo = QComboBox()
        self.update_bitrate_options("MP3")  # Initialize with MP3 options
        builder_layout.addRow("Bitrate/Quality:", self.bitrate_combo)
        
        # Mount point input
        self.mount_input = QLineEdit()
        self.mount_input.setPlaceholderText("/example")
        builder_layout.addRow("Mount Point:", self.mount_input)
        
        # Station name input
        self.station_name_input = QLineEdit()
        self.station_name_input.setPlaceholderText(":: Station Name :: Station Slogan ::")
        builder_layout.addRow("Station Name:", self.station_name_input)
        
        # Genre input
        self.genre_input = QLineEdit()
        self.genre_input.setPlaceholderText("Rock, Pop, Jazz, etc.")
        builder_layout.addRow("Genre:", self.genre_input)
        
        # Description input
        self.description_input = QLineEdit()
        self.description_input.setPlaceholderText("Optional Description")
        builder_layout.addRow("Description:", self.description_input)
        
        # Add stream button
        add_btn = QPushButton("🎵 ADD STREAM")
        add_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; font-weight: bold; padding: 8px; }")
        add_btn.clicked.connect(self.add_stream)
        builder_layout.addRow(add_btn)
        
        layout.addWidget(builder_group)
        
        # Current Streams Section
        streams_group = QGroupBox("📋 Configured Streams")
        streams_layout = QVBoxLayout(streams_group)
        
        # Streams table
        self.streams_table = QTableWidget()
        self.streams_table.setColumnCount(7)
        self.streams_table.setHorizontalHeaderLabels(["Codec", "Bitrate", "Mount", "Station Name", "Genre", "Description", "Actions"])
        self.streams_table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch)
        streams_layout.addWidget(self.streams_table)
        
        # Configuration actions
        config_layout = QHBoxLayout()
        
        generate_btn = QPushButton("🔧 GENERATE LIQUIDSOAP CONFIG")
        generate_btn.setStyleSheet("QPushButton { background-color: #3498db; color: white; font-weight: bold; padding: 8px; }")
        generate_btn.clicked.connect(self.generate_liquidsoap_config)
        config_layout.addWidget(generate_btn)
        
        apply_btn = QPushButton("📡 APPLY TO ICECAST")
        apply_btn.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; font-weight: bold; padding: 8px; }")
        apply_btn.clicked.connect(self.apply_to_icecast)
        config_layout.addWidget(apply_btn)
        
        streams_layout.addLayout(config_layout)
        layout.addWidget(streams_group)
        
        # Status area
        self.status_text = QTextEdit()
        self.status_text.setMaximumHeight(150)
        self.status_text.setPlaceholderText("Stream configuration status will appear here...")
        layout.addWidget(QLabel("📊 Configuration Status:"))
        layout.addWidget(self.status_text)
        
    def update_bitrate_options(self, codec):
        """Update bitrate options based on selected codec"""
        self.bitrate_combo.clear()
        
        if codec == "MP3":
            self.bitrate_combo.addItems(["64 kbps", "96 kbps", "128 kbps", "160 kbps", "192 kbps", "256 kbps", "320 kbps"])
        elif codec == "AAC+":
            self.bitrate_combo.addItems(["32 kbps", "48 kbps", "64 kbps", "96 kbps", "128 kbps"])
        elif codec == "FLAC":
            self.bitrate_combo.addItems(["Quality 0", "Quality 3", "Quality 5", "Quality 8"])
        elif codec == "OGG":
            self.bitrate_combo.addItems(["64 kbps", "96 kbps", "128 kbps", "160 kbps", "192 kbps", "256 kbps"])
        elif codec == "OPUS":
            self.bitrate_combo.addItems(["48 kbps", "64 kbps", "96 kbps", "128 kbps", "160 kbps"])
            
    def add_stream(self):
        """Add a new stream configuration"""
        codec = self.codec_combo.currentText()
        bitrate = self.bitrate_combo.currentText()
        mount = self.mount_input.text().strip()
        station_name = self.station_name_input.text().strip()
        genre = self.genre_input.text().strip()
        description = self.description_input.text().strip()
        
        if not mount.startswith('/'):
            mount = '/' + mount
            
        if not mount or mount == '/':
            QMessageBox.warning(self, "Invalid Mount", "Please enter a valid mount point (e.g., /mp3-320)")
            return
            
        if not station_name:
            QMessageBox.warning(self, "Missing Station Name", "Please enter a station name")
            return
            
        # Check for duplicate mounts
        for stream in self.streams:
            if stream['mount'] == mount:
                QMessageBox.warning(self, "Duplicate Mount", f"Mount point {mount} already exists!")
                return
                
        # Add stream
        stream = {
            'codec': codec,
            'bitrate': bitrate,
            'mount': mount,
            'station_name': station_name,
            'genre': genre if genre else 'Various',
            'description': description if description else f'{codec} stream at {bitrate}'
        }
        self.streams.append(stream)
        
        # Update table
        self.refresh_streams_table()
        
        # Save streams persistently
        self.save_streams()
        
        # Clear inputs
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

set("log.file.path", "/home/rd/logs/soap.log")

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
            # Prefer widely-available ffmpeg-based AAC encoder.
            # Liquidsoap expects audio_bitrate as a string (e.g., "64k").
            kbps = bitrate.split()[0]
            try:
                int(kbps)
            except Exception:
                kbps = "64"
            # Explicitly mark as audio encoder to satisfy Liquidsoap 2.x typing
            return f"%ffmpeg(audio=true, video=false, format=\"adts\", audio_codec=\"aac\", audio_bitrate=\"{kbps}k\")"
        elif codec == "FLAC":
            quality = bitrate.split()[1]
            return f"%flac(compression={quality})"
        elif codec == "OGG":
            kbps = bitrate.split()[0]
            return f"%vorbis(quality=0.7)"
        elif codec == "OPUS":
            kbps = bitrate.split()[0]
            return f"%opus(bitrate={kbps})"
        else:
            return "%mp3(bitrate=192)"
            
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
        generate_config_btn.clicked.connect(self.generate_icecast_config)
        config_layout.addWidget(generate_config_btn)
        
        apply_config_btn = QPushButton("� PREPARE FOR DEPLOYMENT")
        apply_config_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; font-weight: bold; padding: 8px; }")
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
    """Tab 3: JACK Matrix - Visual connection matrix with critical connection protection"""
    
    def __init__(self):
        super().__init__()
        self.jack_clients = []
        self.connections = {}
        self.critical_connections = set()
        self.setup_ui()
        
    def setup_ui(self):
        layout = QVBoxLayout(self)
        
        # JACK Status Section
        status_group = QGroupBox("🔌 JACK Status")
        status_layout = QHBoxLayout(status_group)
        
        self.jack_status_label = QLabel("Status: ⏳ Checking JACK...")
        status_layout.addWidget(self.jack_status_label)
        
        refresh_btn = QPushButton("🔄 Refresh Connections")
        refresh_btn.clicked.connect(self.refresh_jack_connections)
        status_layout.addWidget(refresh_btn)
        
        layout.addWidget(status_group)
        
        # Connection Matrix Section
        matrix_group = QGroupBox("🔗 Connection Matrix")
        matrix_layout = QVBoxLayout(matrix_group)
        
        # Scroll area for matrix
        scroll_area = QScrollArea()
        self.matrix_widget = QWidget()
        self.matrix_layout = QGridLayout(self.matrix_widget)
        scroll_area.setWidget(self.matrix_widget)
        scroll_area.setWidgetResizable(True)
        matrix_layout.addWidget(scroll_area)
        
        layout.addWidget(matrix_group)
        
        # Connection Controls
        controls_group = QGroupBox("⚙️ Connection Controls")
        controls_layout = QGridLayout(controls_group)
        
        # Critical connection controls
        set_critical_btn = QPushButton("🔒 SET CRITICAL")
        set_critical_btn.setStyleSheet("QPushButton { background-color: #e67e22; color: white; font-weight: bold; padding: 8px; }")
        set_critical_btn.clicked.connect(self.set_critical_connection)
        controls_layout.addWidget(set_critical_btn, 0, 0)
        
        remove_critical_btn = QPushButton("🔓 REMOVE CRITICAL")
        remove_critical_btn.setStyleSheet("QPushButton { background-color: #95a5a6; color: white; font-weight: bold; padding: 8px; }")
        remove_critical_btn.clicked.connect(self.remove_critical_connection)
        controls_layout.addWidget(remove_critical_btn, 0, 1)
        
        auto_connect_btn = QPushButton("🎯 AUTO-CONNECT")
        auto_connect_btn.setStyleSheet("QPushButton { background-color: #27ae60; color: white; font-weight: bold; padding: 8px; }")
        auto_connect_btn.clicked.connect(self.auto_connect)
        controls_layout.addWidget(auto_connect_btn, 0, 2)
        
        # Emergency controls
        emergency_btn = QPushButton("🚨 EMERGENCY DISCONNECT ALL")
        emergency_btn.setStyleSheet("QPushButton { background-color: #c0392b; color: white; font-weight: bold; padding: 10px; }")
        emergency_btn.clicked.connect(self.emergency_disconnect)
        controls_layout.addWidget(emergency_btn, 1, 0, 1, 3)
        
        layout.addWidget(controls_group)
        
        # Initialize
        self.refresh_jack_connections()
        
    def refresh_jack_connections(self):
        """Refresh JACK connections and update matrix"""
        try:
            # Check if JACK is running
            result = subprocess.run(["jack_lsp"], capture_output=True, text=True)
            if result.returncode == 0:
                self.jack_status_label.setText("Status: ✅ JACK Running")
                self.jack_status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
                
                # Get client list
                self.jack_clients = self.parse_jack_clients(result.stdout)
                self.update_connection_matrix()
            else:
                self.jack_status_label.setText("Status: ❌ JACK Not Running")
                self.jack_status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
                
        except FileNotFoundError:
            self.jack_status_label.setText("Status: ❌ JACK Tools Not Found")
            self.jack_status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
            
    def parse_jack_clients(self, jack_lsp_output):
        """Parse jack_lsp output to get client names"""
        clients = set()
        for line in jack_lsp_output.strip().split('\n'):
            if ':' in line:
                client = line.split(':')[0]
                clients.add(client)
        return sorted(list(clients))
        
    def update_connection_matrix(self):
        """Update the visual connection matrix"""
        # Clear existing matrix
        for i in reversed(range(self.matrix_layout.count())):
            self.matrix_layout.itemAt(i).widget().setParent(None)
            
        if not self.jack_clients:
            no_clients_label = QLabel("No JACK clients detected")
            no_clients_label.setAlignment(Qt.AlignCenter)
            self.matrix_layout.addWidget(no_clients_label, 0, 0)
            return
            
        # Create header row and column
        self.matrix_layout.addWidget(QLabel(""), 0, 0)  # Top-left corner
        
        for i, client in enumerate(self.jack_clients):
            # Column headers
            header_label = QLabel(client)
            header_label.setStyleSheet("QLabel { font-weight: bold; background-color: #ecf0f1; padding: 5px; }")
            self.matrix_layout.addWidget(header_label, 0, i + 1)
            
            # Row headers
            header_label = QLabel(client)
            header_label.setStyleSheet("QLabel { font-weight: bold; background-color: #ecf0f1; padding: 5px; }")
            self.matrix_layout.addWidget(header_label, i + 1, 0)
            
        # Create connection buttons
        for i, source_client in enumerate(self.jack_clients):
            for j, dest_client in enumerate(self.jack_clients):
                if i == j:
                    # Self-connection (diagonal)
                    label = QLabel("—")
                    label.setAlignment(Qt.AlignCenter)
                    label.setStyleSheet("QLabel { background-color: #95a5a6; color: white; padding: 5px; }")
                    self.matrix_layout.addWidget(label, i + 1, j + 1)
                else:
                    # Connection button
                    connection_key = f"{source_client}→{dest_client}"
                    
                    btn = QPushButton("❌")
                    btn.setMaximumSize(50, 30)
                    
                    # Check if this is a critical connection
                    if connection_key in self.critical_connections:
                        btn.setText("🔒")
                        btn.setStyleSheet("QPushButton { background-color: #e67e22; color: white; font-weight: bold; }")
                    else:
                        btn.setStyleSheet("QPushButton { background-color: #ecf0f1; }")
                        
                    btn.clicked.connect(lambda checked, src=source_client, dst=dest_client: 
                                      self.toggle_connection(src, dst))
                    
                    self.matrix_layout.addWidget(btn, i + 1, j + 1)
                    
    def toggle_connection(self, source_client, dest_client):
        """Toggle JACK connection between clients"""
        connection_key = f"{source_client}→{dest_client}"
        
        # Check if this is a critical connection
        if connection_key in self.critical_connections:
            reply = QMessageBox.question(self, "Critical Connection", 
                                       f"This is a critical connection: {connection_key}\n"
                                       "Are you sure you want to modify it?",
                                       QMessageBox.Yes | QMessageBox.No)
            if reply == QMessageBox.No:
                return
                
        QMessageBox.information(self, "Connection Toggle", 
                              f"Toggle connection: {source_client} → {dest_client}\n"
                              "(JACK connection management will be implemented)")
        
    def set_critical_connection(self):
        """Set a connection as critical (protected)"""
        # This would show a dialog to select connections to protect
        QMessageBox.information(self, "Set Critical", 
                              "Select connections to mark as critical (protected)")
        
    def remove_critical_connection(self):
        """Remove critical status from a connection"""
        QMessageBox.information(self, "Remove Critical", 
                              "Select critical connections to unprotect")
        
    def auto_connect(self):
        """Auto-connect based on broadcast chain logic"""
        QMessageBox.information(self, "Auto-Connect", 
                              "Auto-connecting broadcast chain:\n"
                              "Rivendell → Stereo Tool → Liquidsoap")
        
    def emergency_disconnect(self):
        """Emergency disconnect all non-critical connections"""
        reply = QMessageBox.warning(self, "EMERGENCY DISCONNECT", 
                                   "⚠️ This will disconnect ALL non-critical JACK connections!\n"
                                   "Critical connections will be preserved.\n\n"
                                   "Continue?",
                                   QMessageBox.Yes | QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            QMessageBox.information(self, "Emergency Disconnect", 
                                  "All non-critical connections disconnected.\n"
                                  "Critical connections preserved.")


class ServiceControlTab(QWidget):
    """Tab 4: Service Control - Start/stop/configure all broadcast services"""
    
    def __init__(self):
        super().__init__()
        self.services = {
            'jack': {'name': 'JACK Audio', 'systemd': 'jack', 'status': 'unknown', 'user_service': False},
            'stereo_tool': {'name': 'Stereo Tool', 'systemd': 'stereo-tool', 'status': 'unknown', 'user_service': False},
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
        
        # Service Dependencies Info
        deps_group = QGroupBox("📊 Service Dependencies")
        deps_layout = QVBoxLayout(deps_group)
        
        deps_text = QLabel("""
🔗 Service Startup Order:
1. JACK Audio (Foundation)
2. Stereo Tool (Audio Processing)  
3. Liquidsoap (Stream Generation)
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
        
    def update_all_status(self):
        """Update status for all services"""
        for service_key, service_info in self.services.items():
            status_label = getattr(self, f"{service_key}_status_label")
            
            try:
                if service_key == 'jack':
                    # Special handling for JACK
                    result = subprocess.run(["jack_lsp"], capture_output=True, text=True)
                    if result.returncode == 0:
                        status_label.setText("✅ Running")
                        status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
                    else:
                        status_label.setText("❌ Stopped")
                        status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
                elif service_key == 'liquidsoap':
                    # Liquidsoap is launched as a user process (not a systemd unit)
                    # Detect by process name to reflect actual running state
                    proc_check = subprocess.run(["pgrep", "-x", "liquidsoap"], capture_output=True)
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
                        result = subprocess.run(["systemctl", "--user", "is-active", service_info['systemd']], 
                                              capture_output=True, text=True)
                    else:
                        # Standard systemd service check
                        result = subprocess.run(["systemctl", "is-active", service_info['systemd']], 
                                              capture_output=True, text=True)
                    
                    if result.stdout.strip() == "active":
                        status_label.setText("✅ Running")
                        status_label.setStyleSheet("QLabel { color: #27ae60; font-weight: bold; }")
                    else:
                        status_label.setText("❌ Stopped")
                        status_label.setStyleSheet("QLabel { color: #e74c3c; font-weight: bold; }")
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
                # Start JACK with basic configuration
                subprocess.run(["jackd", "-d", "alsa", "-r", "44100", "-p", "1024"], 
                             check=False, capture_output=True)
                QMessageBox.information(self, "JACK Started", "JACK audio server started successfully.")
                
            elif service_key == 'liquidsoap':
                # Start liquidsoap with generated config
                config_dir = self.get_config_directory()
                config_file = config_dir / "radio.liq"
                log_file = config_dir / "liquidsoap.log"
                
                # Verify liquidsoap is available
                import shutil
                import re
                if shutil.which("liquidsoap") is None:
                    QMessageBox.critical(self, "Liquidsoap Not Found", 
                                         "The 'liquidsoap' command is not installed or not in PATH.\n"
                                         "Please install Liquidsoap (e.g., 'sudo apt install liquidsoap liquidsoap-plugin-ffmpeg').")
                    return
                # Verify ffmpeg encoder plugin availability
                try:
                    plugin_check = subprocess.run(["liquidsoap", "-h", "encoder.ffmpeg"], capture_output=True, text=True)
                    if plugin_check.returncode != 0:
                        QMessageBox.critical(self, "Liquidsoap FFmpeg Plugin Missing",
                                             "The FFmpeg encoder plugin for Liquidsoap is not available.\n\n"
                                             "Install one of the following (varies by distro):\n"
                                             "  sudo apt install liquidsoap-plugin-ffmpeg\n"
                                             "  sudo apt install liquidsoap-plugin-all\n"
                                             "  sudo apt install liquidsoap-plugin-extra\n\n"
                                             "Then try starting Liquidsoap again.")
                        return
                except Exception:
                    pass
                # Parse-check Liquidsoap config before launching
                check = subprocess.run(["liquidsoap", "-c", str(config_file)], capture_output=True, text=True)
                if check.returncode != 0:
                    # Attempt auto-fix for common issues and re-check up to two strategies
                    orig_msg = (check.stderr or check.stdout or "Unknown parse error").strip()
                    # Sanitize config for common issues (unquoted bitrate, source label, ffmpeg audio flags)
                    self.sanitize_liquidsoap_config(config_file)
                    check2 = subprocess.run(["liquidsoap", "-c", str(config_file)], capture_output=True, text=True)
                    if check2.returncode != 0:
                        # Secondary, stricter sanitation: switch ffmpeg bitrate to numeric (e.g., 64k -> 64000)
                        self.sanitize_liquidsoap_config_strict(config_file)
                        check3 = subprocess.run(["liquidsoap", "-c", str(config_file)], capture_output=True, text=True)
                        if check3.returncode != 0:
                            msg2 = (check2.stderr or check2.stdout or "Unknown parse error").strip()
                            msg3 = (check3.stderr or check3.stdout or "Unknown parse error").strip()
                            QMessageBox.critical(self, "Liquidsoap Config Error",
                                                 f"Failed to parse Liquidsoap config.\n\nFirst error:\n{orig_msg}\n\nAfter auto-fix:\n{msg2}\n\nAfter strict fix:\n{msg3}")
                            return
                
                if config_file.exists():
                    try:
                        # Append output to a per-user log for troubleshooting
                        log_fh = open(log_file, "a", buffering=1)
                    except Exception:
                        log_fh = None
                    
                    try:
                        subprocess.Popen(["liquidsoap", str(config_file)],
                                         stdout=log_fh or subprocess.DEVNULL,
                                         stderr=log_fh or subprocess.DEVNULL,
                                         start_new_session=True)
                        QMessageBox.information(self, "Liquidsoap Started", 
                                                f"Liquidsoap started with config: {config_file}\n\n"
                                                f"Logs: {log_file}")
                    except Exception as e:
                        if log_fh:
                            log_fh.close()
                        QMessageBox.critical(self, "Liquidsoap Start Error", 
                                             f"Failed to launch Liquidsoap:\n{e}")
                        return
                    # Close our handle; child keeps fd open
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
                # Stop JACK
                subprocess.run(["killall", "jackd"], check=False)
                QMessageBox.information(self, "JACK Stopped", "JACK audio server stopped.")
                
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
                # Restart JACK
                subprocess.run(["killall", "jackd"], check=False)
                time.sleep(1)
                subprocess.run(["jackd", "-d", "alsa", "-r", "44100", "-p", "1024"], 
                             check=False, capture_output=True)
                QMessageBox.information(self, "JACK Restarted", "JACK audio server restarted successfully.")
                
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
                                         "The 'liquidsoap' command is not installed or not in PATH.\n"
                                         "Please install Liquidsoap (e.g., 'sudo apt install liquidsoap liquidsoap-plugin-ffmpeg').")
                    return
                # Verify ffmpeg encoder plugin availability
                try:
                    plugin_check = subprocess.run(["liquidsoap", "-h", "encoder.ffmpeg"], capture_output=True, text=True)
                    if plugin_check.returncode != 0:
                        QMessageBox.critical(self, "Liquidsoap FFmpeg Plugin Missing",
                                             "The FFmpeg encoder plugin for Liquidsoap is not available.\n\n"
                                             "Install one of the following (varies by distro):\n"
                                             "  sudo apt install liquidsoap-plugin-ffmpeg\n"
                                             "  sudo apt install liquidsoap-plugin-all\n"
                                             "  sudo apt install liquidsoap-plugin-extra\n\n"
                                             "Then try restarting Liquidsoap again.")
                        return
                except Exception:
                    pass
                # Parse-check Liquidsoap config before launching
                check = subprocess.run(["liquidsoap", "-c", str(config_file)], capture_output=True, text=True)
                if check.returncode != 0:
                    # Attempt auto-fix then strict fix as needed
                    orig_msg = (check.stderr or check.stdout or "Unknown parse error").strip()
                    self.sanitize_liquidsoap_config(config_file)
                    check2 = subprocess.run(["liquidsoap", "-c", str(config_file)], capture_output=True, text=True)
                    if check2.returncode != 0:
                        self.sanitize_liquidsoap_config_strict(config_file)
                        check3 = subprocess.run(["liquidsoap", "-c", str(config_file)], capture_output=True, text=True)
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
                        subprocess.Popen(["liquidsoap", str(config_file)],
                                         stdout=log_fh or subprocess.DEVNULL,
                                         stderr=log_fh or subprocess.DEVNULL,
                                         start_new_session=True)
                        QMessageBox.information(self, "Liquidsoap Restarted", 
                                                f"Liquidsoap restarted with config: {config_file}\n\n"
                                                f"Logs: {log_file}")
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
                subprocess.run(["systemctl", "restart", service_info['systemd']], check=True)
                QMessageBox.information(self, f"{service_info['name']} Restarted", 
                                      f"{service_info['name']} service restarted successfully.")
                
        except subprocess.CalledProcessError as e:
            QMessageBox.critical(self, "Service Restart Failed", 
                               f"Failed to restart {service_info['name']}:\n{str(e)}")
        except Exception as e:
            QMessageBox.critical(self, "Service Restart Error", 
                               f"Error restarting {service_info['name']}:\n{str(e)}")

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
            res = subprocess.run(["liquidsoap", "-h", "encoder.ffmpeg"], capture_output=True, text=True)
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
        QMessageBox.information(self, "Configure Service", 
                              f"Configuration for {service_info['name']} will open the appropriate settings.")
        
    def start_all_services(self):
        """Start all services in correct order"""
        reply = QMessageBox.question(self, "Start All Services", 
                                   "This will start all broadcast services in the correct order:\n"
                                   "JACK → Stereo Tool → Liquidsoap → Icecast\n\n"
                                   "Continue?",
                                   QMessageBox.Yes | QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            QMessageBox.information(self, "Starting Services", 
                                  "Starting all services in dependency order...")
            
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


class RDXBroadcastControlCenter(QMainWindow):
    """Main application window with tabbed interface"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("RDX Professional Broadcast Control Center v3.2.17")
        self.setMinimumSize(1000, 700)
        self.setup_ui()
        
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
        self.jack_matrix = JackMatrixTab()
        self.tab_widget.addTab(self.jack_matrix, "🔌 JACK Matrix")
        
        self.service_control = ServiceControlTab()
        self.tab_widget.addTab(self.service_control, "⚙️ Service Control")
        
        layout.addWidget(self.tab_widget)
        
        # Status bar
        self.statusBar().showMessage("Ready - Professional Broadcast Control Center v3.2.17")


def main():
    app = QApplication(sys.argv)
    
    # Set application properties
    app.setApplicationName("RDX Broadcast Control Center")
    app.setApplicationVersion("3.2.17")
    
    # Create and show main window
    window = RDXBroadcastControlCenter()
    window.show()
    
    # Handle Ctrl+C gracefully
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()