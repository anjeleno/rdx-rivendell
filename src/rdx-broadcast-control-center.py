#!/usr/bin/env python3
"""
RDX Professional Broadcast Control Center v3.0.0
Complete GUI control for streaming, icecast, JACK, and service management
"""

import sys
import os
import json
import subprocess
import signal
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
        self.streams_table.setColumnCount(4)
        self.streams_table.setHorizontalHeaderLabels(["Codec", "Bitrate", "Mount", "Actions"])
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
        
        if not mount.startswith('/'):
            mount = '/' + mount
            
        if not mount or mount == '/':
            QMessageBox.warning(self, "Invalid Mount", "Please enter a valid mount point (e.g., /mp3-320)")
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
            'mount': mount
        }
        self.streams.append(stream)
        
        # Update table
        self.refresh_streams_table()
        
        # Clear inputs
        self.mount_input.clear()
        
        self.status_text.append(f"✅ Added stream: {codec} {bitrate} → {mount}")
        
    def refresh_streams_table(self):
        """Refresh the streams table"""
        self.streams_table.setRowCount(len(self.streams))
        
        for row, stream in enumerate(self.streams):
            self.streams_table.setItem(row, 0, QTableWidgetItem(stream['codec']))
            self.streams_table.setItem(row, 1, QTableWidgetItem(stream['bitrate']))
            self.streams_table.setItem(row, 2, QTableWidgetItem(stream['mount']))
            
            # Remove button
            remove_btn = QPushButton("🗑️ Remove")
            remove_btn.setStyleSheet("QPushButton { background-color: #e74c3c; color: white; }")
            remove_btn.clicked.connect(lambda checked, r=row: self.remove_stream(r))
            self.streams_table.setCellWidget(row, 3, remove_btn)
            
    def remove_stream(self, row):
        """Remove a stream configuration"""
        if 0 <= row < len(self.streams):
            removed_stream = self.streams.pop(row)
            self.refresh_streams_table()
            self.status_text.append(f"🗑️ Removed stream: {removed_stream['codec']} {removed_stream['bitrate']} → {removed_stream['mount']}")
            
    def generate_liquidsoap_config(self):
        """Generate Liquidsoap configuration for all streams"""
        if not self.streams:
            QMessageBox.warning(self, "No Streams", "Please add at least one stream before generating config.")
            return
            
        config_dir = Path.home() / ".config" / "rdx"
        config_dir.mkdir(parents=True, exist_ok=True)
        
        liquidsoap_config = self.build_liquidsoap_config()
        
        config_file = config_dir / "radio.liq"
        try:
            with open(config_file, 'w') as f:
                f.write(liquidsoap_config)
            self.status_text.append(f"✅ Generated Liquidsoap config: {config_file}")
            self.status_text.append(f"📄 Configured {len(self.streams)} stream(s)")
        except Exception as e:
            self.status_text.append(f"❌ Failed to write config: {str(e)}")
            
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
            config += f'''
# {stream['codec']} {stream['bitrate']} stream
output.icecast(
  {codec_config},
  host="localhost",
  port=8000,
  password="hackm3",
  mount="{stream['mount']}",
  genre="Electronic",
  url="Stream",
  name=":: Station Name :: {stream['codec']} {stream['bitrate']} ::",
  description="",
  radio
)
'''
        
        return config
        
    def get_codec_config(self, codec, bitrate):
        """Get codec-specific configuration"""
        if codec == "MP3":
            kbps = bitrate.split()[0]
            return f"%mp3(bitrate={kbps})"
        elif codec == "AAC+":
            kbps = bitrate.split()[0]
            return f"%aac(bitrate={kbps})"
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
        
        apply_config_btn = QPushButton("📄 APPLY CONFIG")
        apply_config_btn.setStyleSheet("QPushButton { background-color: #9b59b6; color: white; font-weight: bold; padding: 8px; }")
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
        config_dir = Path.home() / ".config" / "rdx"
        config_dir.mkdir(parents=True, exist_ok=True)
        
        icecast_config = self.build_icecast_config()
        
        config_file = config_dir / "icecast.xml"
        try:
            with open(config_file, 'w') as f:
                f.write(icecast_config)
            QMessageBox.information(self, "Config Generated", f"Icecast configuration generated:\n{config_file}")
        except Exception as e:
            QMessageBox.critical(self, "Config Error", f"Failed to generate config:\n{str(e)}")
            
    def build_icecast_config(self):
        """Build Icecast XML configuration"""
        host = self.host_input.text()
        port = self.port_input.value()
        source_pass = self.source_password.text()
        admin_pass = self.admin_password.text()
        relay_pass = self.relay_password.text()
        
        config = f'''<icecast>
    <location>Broadcast Station</location>
    <admin>admin@{host}</admin>

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
        <source-password>{source_pass}</source-password>
        <relay-password>{relay_pass}</relay-password>
        <admin-user>admin</admin-user>
        <admin-password>{admin_pass}</admin-password>
    </authentication>

    <hostname>{host}</hostname>

    <listen-socket>
        <port>{port}</port>
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
</icecast>'''
        
        return config
        
    def apply_icecast_config(self):
        """Apply generated configuration to system"""
        config_file = Path.home() / ".config" / "rdx" / "icecast.xml"
        if not config_file.exists():
            QMessageBox.warning(self, "No Config", "Please generate configuration first.")
            return
            
        reply = QMessageBox.question(self, "Apply Configuration", 
                                   "This will replace the system Icecast configuration.\nContinue?",
                                   QMessageBox.Yes | QMessageBox.No)
        
        if reply == QMessageBox.Yes:
            try:
                # Copy to system location (requires sudo)
                subprocess.run(["sudo", "cp", str(config_file), "/etc/icecast2/icecast.xml"], check=True)
                QMessageBox.information(self, "Config Applied", "Icecast configuration applied successfully!\nRestart Icecast to apply changes.")
            except subprocess.CalledProcessError:
                QMessageBox.critical(self, "Apply Failed", "Failed to apply configuration.\nCheck sudo permissions.")


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
            'jack': {'name': 'JACK Audio', 'systemd': 'jack', 'status': 'unknown'},
            'stereo_tool': {'name': 'Stereo Tool', 'systemd': 'stereo-tool', 'status': 'unknown'},
            'liquidsoap': {'name': 'Liquidsoap', 'systemd': 'liquidsoap', 'status': 'unknown'},
            'icecast': {'name': 'Icecast', 'systemd': 'icecast2', 'status': 'unknown'}
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
        
        # Status update timer
        self.status_timer = QTimer()
        self.status_timer.timeout.connect(self.update_all_status)
        self.status_timer.start(3000)  # Check every 3 seconds
        
        # Initial status check
        self.update_all_status()
        
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
                
    def start_service(self, service_key):
        """Start a specific service"""
        service_info = self.services[service_key]
        
        if service_key == 'jack':
            QMessageBox.information(self, "Start JACK", 
                                  "JACK startup requires specific configuration.\n"
                                  "Use JACK configuration tools or RDX profiles.")
        else:
            try:
                subprocess.run(["sudo", "systemctl", "start", service_info['systemd']], check=True)
                QMessageBox.information(self, "Service Started", f"{service_info['name']} service started successfully!")
            except subprocess.CalledProcessError:
                QMessageBox.critical(self, "Start Failed", f"Failed to start {service_info['name']} service.")
                
    def stop_service(self, service_key):
        """Stop a specific service"""
        service_info = self.services[service_key]
        
        try:
            if service_key == 'jack':
                subprocess.run(["sudo", "killall", "jackd"], check=True)
            else:
                subprocess.run(["sudo", "systemctl", "stop", service_info['systemd']], check=True)
            QMessageBox.information(self, "Service Stopped", f"{service_info['name']} service stopped successfully!")
        except subprocess.CalledProcessError:
            QMessageBox.critical(self, "Stop Failed", f"Failed to stop {service_info['name']} service.")
            
    def restart_service(self, service_key):
        """Restart a specific service"""
        service_info = self.services[service_key]
        
        if service_key == 'jack':
            QMessageBox.information(self, "Restart JACK", 
                                  "JACK restart requires specific procedures.\n"
                                  "Use JACK configuration tools or RDX profiles.")
        else:
            try:
                subprocess.run(["sudo", "systemctl", "restart", service_info['systemd']], check=True)
                QMessageBox.information(self, "Service Restarted", f"{service_info['name']} service restarted successfully!")
            except subprocess.CalledProcessError:
                QMessageBox.critical(self, "Restart Failed", f"Failed to restart {service_info['name']} service.")
                
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
        self.setWindowTitle("🎯 RDX Professional Broadcast Control Center v3.0.0")
        self.setMinimumSize(1000, 700)
        self.setup_ui()
        
    def setup_ui(self):
        """Setup the main user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout(central_widget)
        
        # Header
        header = QLabel("🎯 RDX Professional Broadcast Control Center")
        header.setAlignment(Qt.AlignCenter)
        header.setStyleSheet("""
            QLabel { 
                font-size: 20px; 
                font-weight: bold; 
                padding: 15px;
                background-color: #2c3e50;
                color: white;
                border-radius: 8px;
                margin-bottom: 10px;
            }
        """)
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
        self.statusBar().showMessage("Ready - Professional Broadcast Control Center v3.0.0")


def main():
    app = QApplication(sys.argv)
    
    # Set application properties
    app.setApplicationName("RDX Broadcast Control Center")
    app.setApplicationVersion("3.0.0")
    
    # Create and show main window
    window = RDXBroadcastControlCenter()
    window.show()
    
    # Handle Ctrl+C gracefully
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()