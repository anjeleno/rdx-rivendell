/*
 * rdx_jack_manager.h
 *
 * Enhanced JACK Management for RDX (Rivendell Extended)
 * 
 * This provides advanced JACK device discovery, profile management,
 * and automatic audio routing beyond standard Rivendell capabilities.
 *
 * Copyright (C) 2025 RDX Project
 */

#ifndef RDX_JACK_MANAGER_H
#define RDX_JACK_MANAGER_H

#include <QObject>
#include <QMap>
#include <QStringList>
#include <QTimer>
#include <QDBusInterface>

#ifdef JACK
#include <jack/jack.h>
#endif

struct RdxAudioDevice {
    QString name;           // User-friendly name
    QString jack_name;      // JACK client name  
    QString alsa_name;      // ALSA device name
    int input_channels;     // Number of input channels
    int output_channels;    // Number of output channels
    QString device_type;    // "interface", "software", "bridge" 
    bool is_active;         // Currently connected to JACK
    QStringList capabilities; // "recording", "playback", "midi"
};

struct RdxJackProfile {
    QString name;           // Profile name (e.g., "Live Broadcast", "Production")
    QString description;    // User description
    QMap<QString, QString> connections; // source_port -> dest_port mappings
    QStringList auto_clients;          // Clients to auto-start
    bool auto_activate;     // Activate profile on startup
    QString patchbay_file;  // Optional QjackCtl patchbay file
};

class RdxJackManager : public QObject
{
    Q_OBJECT

public:
    explicit RdxJackManager(QObject *parent = nullptr);
    virtual ~RdxJackManager();

    // Device Discovery
    bool scanAudioDevices();
    QList<RdxAudioDevice> getAudioDevices() const;
    RdxAudioDevice getDeviceByName(const QString &name) const;
    
    // JACK Management
    bool isJackRunning() const;
    bool startJackWithDevice(const QString &device_name, const QMap<QString, QString> &options = QMap<QString, QString>());
    bool stopJack();
    QStringList getJackClients() const;
    QStringList getJackPorts(const QString &client_name = QString()) const;
    
    // Profile Management  
    bool loadProfile(const QString &profile_name);
    bool saveProfile(const RdxJackProfile &profile);
    bool deleteProfile(const QString &profile_name);
    QStringList getAvailableProfiles() const;
    RdxJackProfile getCurrentProfile() const;
    
    // Connection Management
    bool makeConnection(const QString &source_port, const QString &dest_port);
    bool breakConnection(const QString &source_port, const QString &dest_port);
    QMap<QString, QString> getCurrentConnections() const;
    
    // Routing Management
    bool setInputPriority(const QString &source_client, int priority);
    bool switchInputSource(const QString &new_source, const QString &target_client = "rivendell_0");
    bool preventAutoConnect(const QString &client_name);
    bool disconnectAllFrom(const QString &client_name);
    QStringList getInputSources() const;
    QString getCurrentInputSource(const QString &target_client = "rivendell_0") const;
    
    // Critical Connection Protection
    bool markConnectionCritical(const QString &source_port, const QString &dest_port);
    bool markClientCritical(const QString &client_name);
    bool isConnectionCritical(const QString &source_port, const QString &dest_port) const;
    bool isClientCritical(const QString &client_name) const;
    void setupDefaultCriticalConnections();
    void establishCriticalProcessingChain();
    bool establishProcessorChain(const QString &source_client, const QString &dest_client);
    
    // Service Integration
    bool startRivendellServices();
    bool startStereoTool(const QString &preset_file = QString());
    bool startLiquidsoap(const QString &script_file = QString());
    bool startIcecast();
    
signals:
    void deviceListChanged();
    void jackStatusChanged(bool running);
    void profileChanged(const QString &profile_name);
    void connectionChanged(const QString &source, const QString &dest, bool connected);
    void serviceStatusChanged(const QString &service, bool running);
    
private slots:
    void onJackStatusTimer();
    void onDeviceScanTimer();
    void onJackClientChange();
    
private:
    // Internal methods
    void initializeJack();
    void scanAlsaDevices();
    void loadProfilesFromConfig();
    void saveProfilesToConfig();
    bool executeJackCommand(const QStringList &args);
    
    // Member variables
    QMap<QString, RdxAudioDevice> m_audio_devices;
    QMap<QString, RdxJackProfile> m_profiles;
    QString m_current_profile;
    QTimer *m_jack_status_timer;
    QTimer *m_device_scan_timer;
    QDBusInterface *m_dbus_interface;
    bool m_jack_running;
    
    // Routing Management
    QMap<QString, int> m_input_priorities;     // Client -> priority mapping
    QStringList m_auto_connect_blacklist;      // Clients to prevent auto-connect
    QString m_active_input_source;             // Currently active input source
    QStringList m_previous_clients;            // Track client changes
    QTimer *m_client_monitor_timer;            // Monitor JACK client changes
    
    // Critical Connection Protection
    QStringList m_critical_connections;        // Protected connections (source:port -> dest:port)
    QStringList m_critical_clients;            // Clients that should never be disconnected
#ifdef JACK
    jack_client_t *m_jack_client;
#else
    void *m_jack_client; // Placeholder when JACK not available
#endif
};

#endif // RDX_JACK_MANAGER_H