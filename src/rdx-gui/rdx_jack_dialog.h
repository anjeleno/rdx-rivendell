// rdx_jack_dialog.h
//
// RDX Intelligent JACK Configuration Dialog for RDAdmin
// Provides complete GUI control of RDX intelligent routing system
//
//   (C) Copyright 2025 RDX Development Team
//   Based on Rivendell's edit_jack dialog architecture
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//

#ifndef RDX_JACK_DIALOG_H
#define RDX_JACK_DIALOG_H

#include <QCheckBox>
#include <QComboBox>
#include <QGroupBox>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QProgressBar>
#include <QPushButton>
#include <QSpinBox>
#include <QTabWidget>
#include <QTextEdit>
#include <QTimer>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QGridLayout>

#include <rddialog.h>
#include <rdstation.h>

class RdxJackDialog : public RDDialog
{
 Q_OBJECT
 public:
  RdxJackDialog(RDStation *station, QWidget *parent=0);
  RdxJackDialog(QWidget *parent=0);  // Standalone constructor
  QSize sizeHint() const;
  QSizePolicy sizePolicy() const;

 private slots:
  // Profile Management
  void profileChanged();
  void loadProfile();
  void saveProfile();
  void resetProfile();
  
  // Input Source Management
  void inputSourceChanged();
  void switchInputSource();
  void refreshInputSources();
  
  // Service Management  
  void serviceToggled(const QString &serviceName, bool enabled);
  void startService(const QString &serviceName);
  void stopService(const QString &serviceName);
  void restartService(const QString &serviceName);
  
  // JACK Device Management
  void refreshJackDevices();
  void connectDevices();
  void disconnectDevices();
  void showConnectionMatrix();
  
  // Critical Connection Management
  void addCriticalConnection();
  void removeCriticalConnection(); 
  void editCriticalConnection();
  
  // AAC+ Streaming Management
  void startAACStream();
  void stopAACStream();
  void configureAACStream();
  void testAACStream();
  void updateStreamStatus();
  
  // Real-time Updates
  void updateStatus();
  void updateConnections();
  void updateServiceStatus();
  
  // Actions
  void scanSystem();
  void emergencyDisconnect();
  void exportConfiguration();
  void importConfiguration();
  
  // Dialog Management
  void okData();
  void cancelData();
  void applyData();

 protected:
  void resizeEvent(QResizeEvent *e);
  void showEvent(QShowEvent *e);

 private:
  void setupProfileTab();
  void setupInputTab();
  void setupServicesTab();
  void setupConnectionsTab();
  void setupMonitoringTab();
  void setupStreamingTab();
  void setupAdvancedTab();
  
  void updateProfileUI();
  void updateInputUI();
  void updateServicesUI();
  void updateConnectionsUI();
  void updateMonitoringUI();
  void updateStreamingUI();
  
  void initializeDialog();  // Shared initialization method
  
  bool connectToRdxService();
  void disconnectFromRdxService();
  QString executeRdxCommand(const QString &command);
  
  // Main UI
  QTabWidget *main_tab_widget;
  
  // Profile Management Tab
  QGroupBox *profile_group;
  QComboBox *profile_combo;
  QPushButton *profile_load_button;
  QPushButton *profile_save_button; 
  QPushButton *profile_reset_button;
  QTextEdit *profile_description_edit;
  
  // Input Source Management Tab
  QGroupBox *input_group;
  QComboBox *input_source_combo;
  QPushButton *input_switch_button;
  QPushButton *input_refresh_button;
  QListWidget *available_sources_list;
  QLabel *current_source_label;
  QProgressBar *input_level_bar;
  
  // Service Management Tab
  QGroupBox *services_group;
  QListWidget *services_list;
  QPushButton *service_start_button;
  QPushButton *service_stop_button;
  QPushButton *service_restart_button;
  QTextEdit *service_log_edit;
  
  // Connections Tab
  QGroupBox *connections_group;
  QListWidget *jack_devices_list;
  QPushButton *connect_button;
  QPushButton *disconnect_button;
  QPushButton *matrix_button;
  QListWidget *critical_connections_list;
  QPushButton *add_critical_button;
  QPushButton *remove_critical_button;
  QPushButton *edit_critical_button;
  
  // Monitoring Tab
  QGroupBox *monitoring_group;
  QTextEdit *status_display;
  QProgressBar *cpu_usage_bar;
  QLabel *xruns_label;
  QLabel *latency_label;
  QLabel *sample_rate_label;
  QPushButton *scan_button;
  QPushButton *emergency_button;
  
  // AAC+ Streaming Tab
  QGroupBox *streaming_group;
  QLineEdit *stream_url_edit;
  QSpinBox *stream_bitrate_spin;
  QComboBox *stream_format_combo;
  QComboBox *stream_quality_combo;
  QPushButton *stream_start_button;
  QPushButton *stream_stop_button;
  QPushButton *stream_test_button;
  QLabel *stream_status_label;
  QTextEdit *stream_log_edit;
  QCheckBox *stream_auto_reconnect_check;
  
  // Advanced Tab
  QGroupBox *advanced_group;
  QCheckBox *auto_routing_check;
  QCheckBox *critical_protection_check;
  QSpinBox *scan_interval_spin;
  QLineEdit *rdx_service_path_edit;
  QPushButton *export_button;
  QPushButton *import_button;
  
  // Dialog Buttons
  QPushButton *ok_button;
  QPushButton *cancel_button;
  QPushButton *apply_button;
  
  // Data
  RDStation *rdx_station;
  QTimer *update_timer;
  QString current_profile;
  QString current_input_source;
  QStringList available_profiles;
  QStringList available_services;
  QStringList jack_devices;
  QStringList critical_connections;
  
  // Status tracking
  bool rdx_service_connected;
  bool auto_update_enabled;
  bool aac_stream_active;
  QString current_stream_url;
  int stream_process_id;
};

#endif // RDX_JACK_DIALOG_H