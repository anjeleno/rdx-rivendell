#!/usr/bin/env python3
"""
RDX Enhanced RDAdmin Launcher
Unified interface for RDAdmin + RDX functionality
"""

import sys
import os
import subprocess
import signal
from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, 
                            QPushButton, QLabel, QWidget, QFrame, QMessageBox,
                            QGridLayout, QGroupBox, QTextEdit, QSplitter)
from PyQt5.QtCore import Qt, QProcess, QTimer, pyqtSignal
from PyQt5.QtGui import QFont, QIcon, QPalette

class RDXEnhancedLauncher(QMainWindow):
    """Enhanced launcher combining RDAdmin functionality with RDX controls"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("🔥 RDX Enhanced RDAdmin Control Center")
        self.setMinimumSize(800, 600)
        
        # Setup UI
        self.setup_ui()
        
        # Check system status
        self.check_system_status()
        
    def setup_ui(self):
        """Setup the user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main layout
        main_layout = QVBoxLayout(central_widget)
        
        # Header
        header = QLabel("🔥 RDX Enhanced RDAdmin Control Center")
        header.setAlignment(Qt.AlignCenter)
        header.setStyleSheet("""
            QLabel { 
                font-size: 18px; 
                font-weight: bold; 
                padding: 10px;
                background-color: #2c3e50;
                color: white;
                border-radius: 5px;
            }
        """)
        main_layout.addWidget(header)
        
        # Create splitter for left/right panels
        splitter = QSplitter(Qt.Horizontal)
        main_layout.addWidget(splitter)
        
        # Left panel - RDAdmin functions
        rdadmin_group = self.create_rdadmin_panel()
        splitter.addWidget(rdadmin_group)
        
        # Right panel - RDX controls
        rdx_group = self.create_rdx_panel()
        splitter.addWidget(rdx_group)
        
        # Status bar
        self.status_label = QLabel("Ready")
        self.status_label.setStyleSheet("padding: 5px; background-color: #ecf0f1;")
        main_layout.addWidget(self.status_label)
        
        # Set splitter proportions
        splitter.setSizes([400, 400])
        
    def create_rdadmin_panel(self):
        """Create RDAdmin functions panel"""
        group = QGroupBox("🎛️ RDAdmin Functions")
        group.setStyleSheet("""
            QGroupBox { 
                font-weight: bold; 
                font-size: 14px;
                margin-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px 0 5px;
            }
        """)
        
        layout = QGridLayout(group)
        
        # RDAdmin buttons
        buttons = [
            ("🏢 RDAdmin", "Launch main RDAdmin interface", self.launch_rdadmin),
            ("📚 RDLibrary", "Launch RDLibrary", self.launch_rdlibrary),
            ("🎵 RDAirPlay", "Launch RDAirPlay", self.launch_rdairplay),
            ("🎛️ RDPanel", "Launch RDPanel", self.launch_rdpanel),
            ("📝 RDLogEdit", "Launch RDLogEdit", self.launch_rdlogedit),
            ("📊 RDLogManager", "Launch RDLogManager", self.launch_rdlogmanager),
            ("🎯 RDCatch", "Launch RDCatch", self.launch_rdcatch),
            ("⚙️ System Config", "System configuration", self.launch_system_config),
        ]
        
        for i, (text, tooltip, handler) in enumerate(buttons):
            btn = QPushButton(text)
            btn.setToolTip(tooltip)
            btn.setMinimumHeight(40)
            btn.clicked.connect(handler)
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #3498db;
                    color: white;
                    border: none;
                    padding: 8px;
                    border-radius: 4px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background-color: #2980b9;
                }
                QPushButton:pressed {
                    background-color: #21618c;
                }
            """)
            layout.addWidget(btn, i // 2, i % 2)
            
        return group
        
    def create_rdx_panel(self):
        """Create RDX controls panel"""
        group = QGroupBox("🔥 RDX Audio Control")
        group.setStyleSheet("""
            QGroupBox { 
                font-weight: bold; 
                font-size: 14px;
                margin-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px 0 5px;
            }
        """)
        
        layout = QVBoxLayout(group)
        
        # RDX main controls
        rdx_buttons = QGridLayout()
        
        buttons = [
            ("🎚️ RDX GUI Control", "Launch RDX full GUI interface", self.launch_rdx_gui),
            ("🔍 Audio Device Scan", "Scan for audio devices", self.rdx_scan),
            ("🎭 Live Broadcast Profile", "Load live broadcast profile", self.rdx_live_profile),
            ("🏭 Production Profile", "Load production profile", self.rdx_production_profile),
            ("📡 Start HQ Stream", "Start high quality AAC+ stream", self.rdx_start_stream),
            ("⏹️ Stop Stream", "Stop streaming", self.rdx_stop_stream),
            ("📊 RDX Status", "Show RDX system status", self.rdx_status),
            ("🔧 Dependency Check", "Check RDX dependencies", self.rdx_deps_check),
        ]
        
        for i, (text, tooltip, handler) in enumerate(buttons):
            btn = QPushButton(text)
            btn.setToolTip(tooltip)
            btn.setMinimumHeight(40)
            btn.clicked.connect(handler)
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #e74c3c;
                    color: white;
                    border: none;
                    padding: 8px;
                    border-radius: 4px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background-color: #c0392b;
                }
                QPushButton:pressed {
                    background-color: #a93226;
                }
            """)
            rdx_buttons.addWidget(btn, i // 2, i % 2)
            
        layout.addLayout(rdx_buttons)
        
        # Status display
        self.rdx_status_display = QTextEdit()
        self.rdx_status_display.setMaximumHeight(150)
        self.rdx_status_display.setReadOnly(True)
        self.rdx_status_display.setStyleSheet("""
            QTextEdit {
                background-color: #2c3e50;
                color: #ecf0f1;
                font-family: monospace;
                font-size: 10px;
                border: 1px solid #34495e;
                border-radius: 4px;
            }
        """)
        layout.addWidget(QLabel("🔍 RDX Status Monitor:"))
        layout.addWidget(self.rdx_status_display)
        
        return group
        
    def check_system_status(self):
        """Check system status on startup"""
        status_parts = []
        
        # Check Rivendell
        if os.path.exists("/usr/bin/rdadmin"):
            status_parts.append("✅ Rivendell")
        else:
            status_parts.append("❌ Rivendell")
            
        # Check RDX
        if os.path.exists("/usr/local/bin/rdx-jack-helper"):
            status_parts.append("✅ RDX")
        else:
            status_parts.append("❌ RDX")
            
        # Check JACK
        if os.path.exists("/usr/bin/jackd"):
            status_parts.append("✅ JACK")
        else:
            status_parts.append("❌ JACK")
            
        self.status_label.setText(" | ".join(status_parts))
        
    def run_command(self, command, show_output=False):
        """Run a command and optionally show output"""
        try:
            if show_output:
                result = subprocess.run(command, shell=True, capture_output=True, text=True)
                if result.stdout:
                    self.rdx_status_display.append(f"$ {command}")
                    self.rdx_status_display.append(result.stdout)
                if result.stderr:
                    self.rdx_status_display.append(f"ERROR: {result.stderr}")
                return result.returncode == 0
            else:
                subprocess.Popen(command, shell=True)
                return True
        except Exception as e:
            if show_output:
                self.rdx_status_display.append(f"ERROR: {str(e)}")
            return False
            
    # RDAdmin launchers
    def launch_rdadmin(self):
        self.run_command("rdadmin &")
        
    def launch_rdlibrary(self):
        self.run_command("rdlibrary &")
        
    def launch_rdairplay(self):
        self.run_command("rdairplay &")
        
    def launch_rdpanel(self):
        self.run_command("rdpanel &")
        
    def launch_rdlogedit(self):
        self.run_command("rdlogedit &")
        
    def launch_rdlogmanager(self):
        self.run_command("rdlogmanager &")
        
    def launch_rdcatch(self):
        self.run_command("rdcatch &")
        
    def launch_system_config(self):
        self.run_command("rddbconfig &")
        
    # RDX functions
    def launch_rdx_gui(self):
        """Launch the full RDX GUI interface"""
        if os.path.exists("/usr/local/bin/rdx-gui-launcher"):
            self.run_command("rdx-gui-launcher &")
        else:
            QMessageBox.warning(self, "RDX GUI", "RDX GUI launcher not found. Please ensure RDX is properly installed.")
            
    def rdx_scan(self):
        self.run_command("rdx-jack-helper --scan", show_output=True)
        
    def rdx_live_profile(self):
        self.run_command("rdx-jack-helper --profile live-broadcast", show_output=True)
        
    def rdx_production_profile(self):
        self.run_command("rdx-jack-helper --profile production", show_output=True)
        
    def rdx_start_stream(self):
        self.run_command("rdx-stream start hq", show_output=True)
        
    def rdx_stop_stream(self):
        self.run_command("rdx-stream stop", show_output=True)
        
    def rdx_status(self):
        self.run_command("rdx-jack-helper --status", show_output=True)
        
    def rdx_deps_check(self):
        self.run_command("rdx-deps check", show_output=True)

def main():
    app = QApplication(sys.argv)
    app.setApplicationName("RDX Enhanced RDAdmin Launcher")
    
    # Set application style
    app.setStyle('Fusion')
    
    window = RDXEnhancedLauncher()
    window.show()
    
    sys.exit(app.exec_())

if __name__ == "__main__":
    main()