// rdx_integration.cpp  
//
// RDAdmin Integration for RDX - Adds RDX button to main RDAdmin interface
// Provides seamless access to RDX intelligent routing from within RDAdmin
//
//   (C) Copyright 2025 RDX Development Team
//

#include <QMessageBox>
#include <QProcess>

#include "rdx_integration.h"
#include "rdx_jack_dialog.h"

// Function to add to RDAdmin main window
void RdxIntegration::addRdxButtonToRdAdmin(QWidget *parent, RDStation *station)
{
  // Create RDX button in main RDAdmin interface
  QPushButton *rdx_button = new QPushButton("🔥 RDX Audio Control", parent);
  rdx_button->setMinimumSize(200, 40);
  rdx_button->setStyleSheet(
    "QPushButton {"
    "  background: qlineargradient(x1: 0, y1: 0, x2: 0, y2: 1, "
    "    stop: 0 #ff6b35, stop: 1 #f7931e);"
    "  color: white;"
    "  font-weight: bold;"
    "  font-size: 14px;"
    "  border: 2px solid #d35400;"
    "  border-radius: 8px;"
    "}"
    "QPushButton:hover {"
    "  background: qlineargradient(x1: 0, y1: 0, x2: 0, y2: 1, "
    "    stop: 0 #ff7f50, stop: 1 #ff8c42);"
    "}"
    "QPushButton:pressed {"
    "  background: qlineargradient(x1: 0, y1: 0, x2: 0, y2: 1, "
    "    stop: 0 #e55100, stop: 1 #d84315);"
    "}"
  );
  
  // Connect to launch RDX dialog
  QObject::connect(rdx_button, &QPushButton::clicked, [parent, station]() {
    launchRdxDialog(parent, station);
  });
  
  // Add tooltip
  rdx_button->setToolTip(
    "RDX Intelligent Audio Routing Control\n\n"
    "• Profile-based audio management\n"
    "• Smart input source switching\n" 
    "• Service orchestration\n"
    "• Critical connection protection\n"
    "• Real-time JACK monitoring"
  );
}

// Launch the comprehensive RDX control dialog
void RdxIntegration::launchRdxDialog(QWidget *parent, RDStation *station)
{
  // Check if RDX service is available
  if (!checkRdxService()) {
    int ret = QMessageBox::question(parent, "RDX Not Installed",
      "RDX Intelligent Audio Routing system is not installed on this station.\n\n"
      "RDX provides:\n"
      "• Intelligent JACK device discovery and routing\n"
      "• Critical connection protection for broadcast safety\n"
      "• Profile-based service orchestration\n"
      "• Smart hardware detection and management\n\n"
      "Would you like to install RDX now?",
      QMessageBox::Yes | QMessageBox::No, QMessageBox::Yes);
      
    if (ret == QMessageBox::Yes) {
      showRdxInstallationDialog(parent);
    }
    return;
  }
  
  // Launch full RDX control dialog
  RdxJackDialog dialog(station, parent);
  dialog.exec();
}

bool RdxIntegration::checkRdxService()
{
  // Check if RDX service is installed and available
  QProcess process;
  process.start("which", QStringList() << "rdx-jack-helper");
  process.waitForFinished(3000);
  
  if (process.exitCode() != 0) {
    return false;
  }
  
  // Check if service is running
  process.start("systemctl", QStringList() << "is-active" << "rdx-jack-helper");
  process.waitForFinished(3000);
  
  return (process.exitCode() == 0);
}

void RdxIntegration::showRdxInstallationDialog(QWidget *parent)
{
  QMessageBox install_dialog(parent);
  install_dialog.setWindowTitle("Install RDX Audio System");
  install_dialog.setIcon(QMessageBox::Information);
  
  install_dialog.setText(
    "<h3>🔥 Install RDX Intelligent Audio Routing</h3>"
    "<p><b>RDX enhances Rivendell with broadcast-grade intelligent audio management:</b></p>"
    "<ul>"
    "<li>🧠 <b>Smart Auto-Routing:</b> VLC auto-connects, conflict prevention</li>"
    "<li>🛡️ <b>Critical Protection:</b> Never interrupts live broadcast audio</li>"
    "<li>🎛️ <b>Profile Management:</b> One-command setup for different scenarios</li>"
    "<li>🔍 <b>Hardware Detection:</b> Automatic discovery of processors and streamers</li>"
    "<li>⚡ <b>Real-Time Monitoring:</b> Live JACK connection management</li>"
    "</ul>"
    "<p><b>Installation options:</b></p>"
  );
  
  QPushButton *quick_install = install_dialog.addButton("Quick Install", QMessageBox::ActionRole);
  QPushButton *custom_install = install_dialog.addButton("Custom Install", QMessageBox::ActionRole);
  QPushButton *manual_install = install_dialog.addButton("Manual Install", QMessageBox::ActionRole);
  QPushButton *cancel = install_dialog.addButton("Cancel", QMessageBox::RejectRole);
  
  install_dialog.setDefaultButton(quick_install);
  
  install_dialog.exec();
  
  if (install_dialog.clickedButton() == quick_install) {
    performQuickRdxInstall(parent);
  } else if (install_dialog.clickedButton() == custom_install) {
    performCustomRdxInstall(parent);
  } else if (install_dialog.clickedButton() == manual_install) {
    showManualInstallInstructions(parent);
  }
}

void RdxIntegration::performQuickRdxInstall(QWidget *parent)
{
  QMessageBox progress(parent);
  progress.setWindowTitle("Installing RDX");
  progress.setText("🔥 Installing RDX Intelligent Audio Routing System...\n\nThis may take a few minutes.");
  progress.setStandardButtons(QMessageBox::NoButton);
  progress.show();
  
  QProcess install_process;
  install_process.start("bash", QStringList() << "-c" << 
    "cd /tmp && "
    "wget -q https://github.com/anjeleno/rdx-rivendell/archive/main.tar.gz && "
    "tar -xzf main.tar.gz && "
    "cd rdx-rivendell-main && "
    "./scripts/install-rdx.sh --auto-install-broadcast"
  );
  
  // Show progress while installing
  while (install_process.state() != QProcess::NotRunning) {
    QApplication::processEvents();
    QThread::msleep(100);
  }
  
  progress.close();
  
  if (install_process.exitCode() == 0) {
    QMessageBox::information(parent, "RDX Installation Complete",
      "🎉 RDX has been successfully installed!\n\n"
      "✅ Intelligent audio routing is now active\n"
      "✅ Service will start automatically with Rivendell\n"
      "✅ RDX control panel is ready to use\n\n"
      "Click 'RDX Audio Control' to access all features.");
  } else {
    QMessageBox::warning(parent, "Installation Failed",
      "❌ RDX installation failed.\n\n"
      "Please check your internet connection and try again,\n"
      "or use the manual installation method.");
  }
}

void RdxIntegration::performCustomRdxInstall(QWidget *parent)
{
  // Launch custom installation dialog with broadcast tool selection
  QMessageBox custom_dialog(parent);
  custom_dialog.setWindowTitle("RDX Custom Installation");
  custom_dialog.setText(
    "<h3>🛒 Select RDX Components to Install</h3>"
    "<p>Choose which broadcast tools to install with RDX:</p>"
  );
  
  // Add checkboxes for different components
  QWidget *widget = new QWidget();
  QVBoxLayout *layout = new QVBoxLayout(widget);
  
  QCheckBox *liquidsoap_check = new QCheckBox("🌊 Liquidsoap (Advanced streaming automation)", widget);
  QCheckBox *icecast_check = new QCheckBox("🧊 Icecast2 (Streaming server)", widget);
  QCheckBox *vlc_check = new QCheckBox("🎥 VLC Media Player (Essential for RDX)", widget);
  QCheckBox *darkice_check = new QCheckBox("🌙 DarkIce (Simple streaming encoder)", widget);
  QCheckBox *glasscoder_check = new QCheckBox("🔮 GlassCoder (Multi-format encoder)", widget);
  
  // Set recommended defaults
  liquidsoap_check->setChecked(true);
  icecast_check->setChecked(true);
  vlc_check->setChecked(true);
  
  layout->addWidget(liquidsoap_check);
  layout->addWidget(icecast_check);
  layout->addWidget(vlc_check);
  layout->addWidget(darkice_check);
  layout->addWidget(glasscoder_check);
  
  // Add note about Stereo Tool
  QLabel *note_label = new QLabel(
    "<i>📡 Stereo Tool requires separate download from thimeo.com</i>", widget);
  note_label->setStyleSheet("color: gray; font-size: 11px;");
  layout->addWidget(note_label);
  
  custom_dialog.layout()->addWidget(widget);
  
  QPushButton *install_selected = custom_dialog.addButton("Install Selected", QMessageBox::ActionRole);
  QPushButton *cancel = custom_dialog.addButton("Cancel", QMessageBox::RejectRole);
  
  custom_dialog.exec();
  
  if (custom_dialog.clickedButton() == install_selected) {
    // Build custom installation command based on selections
    QStringList selected_tools;
    if (liquidsoap_check->isChecked()) selected_tools << "liquidsoap";
    if (icecast_check->isChecked()) selected_tools << "icecast2";
    if (vlc_check->isChecked()) selected_tools << "vlc";
    if (darkice_check->isChecked()) selected_tools << "darkice";
    if (glasscoder_check->isChecked()) selected_tools << "glasscoder";
    
    performCustomInstallWithTools(parent, selected_tools);
  }
}

void RdxIntegration::showManualInstallInstructions(QWidget *parent)
{
  QMessageBox manual_dialog(parent);
  manual_dialog.setWindowTitle("RDX Manual Installation");
  manual_dialog.setIcon(QMessageBox::Information);
  
  manual_dialog.setText(
    "<h3>📋 Manual RDX Installation Instructions</h3>"
    "<p><b>For advanced users who want full control:</b></p>"
  );
  
  manual_dialog.setDetailedText(
    "# Manual RDX Installation\n\n"
    "## Download RDX Source:\n"
    "git clone https://github.com/anjeleno/rdx-rivendell.git\n"
    "cd rdx-rivendell\n\n"
    "## Interactive Installation:\n"
    "./scripts/install-rdx.sh\n"
    "# Follow prompts to select broadcast tools\n\n"
    "## Quick Installation (recommended tools):\n"
    "./scripts/install-rdx.sh --auto-install-broadcast\n\n"
    "## Core Only (no broadcast tools):\n"
    "./scripts/install-rdx.sh --skip-broadcast-tools\n\n"
    "## Integration with rivendell-installer:\n"
    "# Copy rdx-integration.sh functions to rivendell-auto-install.sh\n"
    "# Add RDX installation steps to main sequence\n\n"
    "## VM Deployment:\n"
    "./scripts/create-deployment-packages.sh\n"
    "# Creates packages for different deployment scenarios\n\n"
    "## Verification:\n"
    "rdx-jack-helper --scan\n"
    "systemctl status rdx-jack-helper\n\n"
    "## Documentation:\n"
    "# See README.md and CHANGELOG.md for complete feature list\n"
    "# Check docs/ directory for detailed architecture information"
  );
  
  manual_dialog.exec();
}