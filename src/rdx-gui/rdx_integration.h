// rdx_integration.h
//
// RDAdmin Integration Header for RDX
// Provides functions to integrate RDX controls into existing RDAdmin interface
//
//   (C) Copyright 2025 RDX Development Team
//

#ifndef RDX_INTEGRATION_H
#define RDX_INTEGRATION_H

#include <QPushButton>
#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QCheckBox>
#include <QLabel>
#include <QMessageBox>
#include <QProcess>
#include <QThread>
#include <QApplication>

#include <rdstation.h>

class RdxIntegration
{
 public:
  // Main integration function - adds RDX button to RDAdmin
  static void addRdxButtonToRdAdmin(QWidget *parent, RDStation *station);
  
  // Launch the complete RDX control dialog
  static void launchRdxDialog(QWidget *parent, RDStation *station);
  
  // Check if RDX service is installed and running
  static bool checkRdxService();
  
  // Installation dialogs
  static void showRdxInstallationDialog(QWidget *parent);
  static void performQuickRdxInstall(QWidget *parent);
  static void performCustomRdxInstall(QWidget *parent);
  static void performCustomInstallWithTools(QWidget *parent, const QStringList &tools);
  static void showManualInstallInstructions(QWidget *parent);
  
 private:
  RdxIntegration() {} // Static class - no instances
};

// Convenience macro for adding RDX to existing RDAdmin code
#define ADD_RDX_BUTTON(parent, station) RdxIntegration::addRdxButtonToRdAdmin(parent, station)

#endif // RDX_INTEGRATION_H