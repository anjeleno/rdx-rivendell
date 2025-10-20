/*
 * rdx_jack_manager.cpp
 *
 * Enhanced JACK Management Implementation for RDX
 *
 * Copyright (C) 2025 RDX Project
 */

#include "rdx/rdx_jack_manager.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QXmlStreamReader>
#include <QXmlStreamWriter>

#ifdef JACK
#include <jack/jack.h>
#endif

#include <alsa/asoundlib.h>

RdxJackManager::RdxJackManager(QObject *parent)
    : QObject(parent)
    , m_current_profile("default")
    , m_jack_running(false)
    , m_jack_client(nullptr)
{
    // Initialize timers
    m_jack_status_timer = new QTimer(this);
    m_jack_status_timer->setInterval(2000); // Check every 2 seconds
    connect(m_jack_status_timer, &QTimer::timeout, this, &RdxJackManager::onJackStatusTimer);
    
    m_device_scan_timer = new QTimer(this);  
    m_device_scan_timer->setInterval(10000); // Scan every 10 seconds
    connect(m_device_scan_timer, &QTimer::timeout, this, &RdxJackManager::onDeviceScanTimer);
    
    // Initialize D-Bus interface for system communication
    m_dbus_interface = new QDBusInterface("org.rdx.jack", "/org/rdx/jack", 
                                         "org.rdx.jack", QDBusConnection::systemBus(), this);
    
    // Load configuration
    loadProfilesFromConfig();
    
    // Start monitoring
    m_jack_status_timer->start();
    m_device_scan_timer->start();
    
    // Initial scans
    scanAudioDevices();
    onJackStatusTimer();
    
    qDebug() << "RdxJackManager initialized";
}

RdxJackManager::~RdxJackManager()
{
#ifdef JACK
    if (m_jack_client) {
        jack_client_close(m_jack_client);
    }
#endif
}

bool RdxJackManager::scanAudioDevices()
{
    m_audio_devices.clear();
    
    // Scan ALSA devices
    scanAlsaDevices();
    
    // If JACK is running, get JACK clients
    if (isJackRunning()) {
        QStringList clients = getJackClients();
        
        for (const QString &client : clients) {
            if (client == "system") {
                // Update system device with JACK info
                if (m_audio_devices.contains("system")) {
                    m_audio_devices["system"].is_active = true;
                }
            } else {
                // Add software JACK clients
                RdxAudioDevice device;
                device.name = client;
                device.jack_name = client;
                device.device_type = "software";
                device.is_active = true;
                
                QStringList ports = getJackPorts(client);
                device.input_channels = ports.filter("in").size();
                device.output_channels = ports.filter("out").size();
                
                m_audio_devices[client] = device;
            }
        }
    }
    
    emit deviceListChanged();
    return true;
}

void RdxJackManager::scanAlsaDevices()
{
    int card = -1;
    
    // Enumerate ALSA cards
    while (snd_card_next(&card) >= 0 && card >= 0) {
        char *name = nullptr;
        char *longname = nullptr;
        
        if (snd_card_get_name(card, &name) == 0 && 
            snd_card_get_longname(card, &longname) == 0) {
            
            RdxAudioDevice device;
            device.name = QString::fromUtf8(longname);
            device.alsa_name = QString("hw:%1").arg(card);
            device.device_type = "interface";
            device.is_active = false;
            
            // Check for playback/capture capabilities
            QString card_path = QString("/proc/asound/card%1/pcm0p/info").arg(card);
            if (QFile::exists(card_path)) {
                device.capabilities << "playback";
                device.output_channels = 2; // Default assumption
            }
            
            card_path = QString("/proc/asound/card%1/pcm0c/info").arg(card);
            if (QFile::exists(card_path)) {
                device.capabilities << "recording"; 
                device.input_channels = 2; // Default assumption
            }
            
            m_audio_devices[device.alsa_name] = device;
            
            free(name);
            free(longname);
        }
    }
}

QList<RdxAudioDevice> RdxJackManager::getAudioDevices() const
{
    return m_audio_devices.values();
}

RdxAudioDevice RdxJackManager::getDeviceByName(const QString &name) const
{
    return m_audio_devices.value(name);
}

bool RdxJackManager::isJackRunning() const
{
#ifdef JACK
    jack_status_t status;
    jack_client_t *test_client = jack_client_open("rdx_test", JackNoStartServer, &status);
    if (test_client) {
        jack_client_close(test_client);
        return true;
    }
    
    // Debug output for troubleshooting
    qDebug() << "JACK connection failed, status:" << QString::number(status, 16);
    if (status & JackServerError) qDebug() << "  - Server error";
    if (status & JackNoSuchClient) qDebug() << "  - No such client"; 
    if (status & JackLoadFailure) qDebug() << "  - Load failure";
    if (status & JackInitFailure) qDebug() << "  - Init failure";
    if (status & JackShmFailure) qDebug() << "  - Shared memory failure";
    if (status & JackVersionError) qDebug() << "  - Version error";
    if (status & JackBackendError) qDebug() << "  - Backend error";
    if (status & JackClientZombie) qDebug() << "  - Client zombie";
#endif
    return false;
}

QStringList RdxJackManager::getJackClients() const
{
    QStringList clients;
    
#ifdef JACK
    if (!m_jack_client) {
        return clients;
    }
    
    const char **jack_clients = jack_get_ports(m_jack_client, nullptr, nullptr, 0);
    if (jack_clients) {
        for (int i = 0; jack_clients[i]; ++i) {
            QString port = QString::fromUtf8(jack_clients[i]);
            QString client = port.split(':').first();
            if (!clients.contains(client)) {
                clients << client;
            }
        }
        jack_free(jack_clients);
    }
#endif
    
    return clients;
}

QStringList RdxJackManager::getJackPorts(const QString &client_name) const
{
    QStringList ports;
    
#ifdef JACK
    if (!m_jack_client) {
        return ports;
    }
    
    QString pattern = client_name.isEmpty() ? QString() : client_name + ":";
    const char **jack_ports = jack_get_ports(m_jack_client, 
                                           pattern.isEmpty() ? nullptr : pattern.toUtf8().constData(),
                                           nullptr, 0);
    if (jack_ports) {
        for (int i = 0; jack_ports[i]; ++i) {
            ports << QString::fromUtf8(jack_ports[i]);
        }
        jack_free(jack_ports);
    }
#endif
    
    return ports;
}

bool RdxJackManager::startJackWithDevice(const QString &device_name, const QMap<QString, QString> &options)
{
    if (isJackRunning()) {
        qDebug() << "JACK already running";
        return true;
    }
    
    RdxAudioDevice device = getDeviceByName(device_name);
    if (device.name.isEmpty()) {
        qWarning() << "Device not found:" << device_name;
        return false;
    }
    
    QStringList args;
    args << "jackd";
    args << "-d" << "alsa";
    args << "-d" << device.alsa_name;
    
    // Apply options
    if (options.contains("sample_rate")) {
        args << "-r" << options["sample_rate"];
    } else {
        args << "-r" << "48000"; // Default to 48kHz
    }
    
    if (options.contains("buffer_size")) {
        args << "-p" << options["buffer_size"];
    } else {
        args << "-p" << "512"; // Default buffer
    }
    
    if (options.contains("periods")) {
        args << "-n" << options["periods"];  
    } else {
        args << "-n" << "3"; // Default periods
    }
    
    return executeJackCommand(args);
}

bool RdxJackManager::executeJackCommand(const QStringList &args)
{
    QProcess process;
    process.setProcessEnvironment(QProcessEnvironment::systemEnvironment());
    
    QString program = args.first();
    QStringList arguments = args;
    arguments.removeFirst();
    
    qDebug() << "Executing:" << program << arguments.join(" ");
    
    process.start(program, arguments);
    if (!process.waitForStarted(5000)) {
        qWarning() << "Failed to start:" << program;
        return false;
    }
    
    // Don't wait for JACK to finish - it runs as daemon
    return true;
}

void RdxJackManager::onJackStatusTimer()
{
    bool was_running = m_jack_running;
    m_jack_running = isJackRunning();
    
    if (was_running != m_jack_running) {
        emit jackStatusChanged(m_jack_running);
        
        // Initialize JACK client connection when JACK starts
        if (m_jack_running && !m_jack_client) {
            initializeJack();
        }
    }
}

void RdxJackManager::onDeviceScanTimer()
{
    scanAudioDevices();
}

void RdxJackManager::initializeJack()
{
#ifdef JACK
    if (m_jack_client) {
        return; // Already connected
    }
    
    m_jack_client = jack_client_open("rdx_manager", JackNoStartServer, nullptr);
    if (m_jack_client) {
        qDebug() << "Connected to JACK as rdx_manager";
    } else {
        qWarning() << "Failed to connect to JACK";
    }
#endif
}

void RdxJackManager::loadProfilesFromConfig()
{
    QString config_dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    QString config_file = config_dir + "/rdx/jack-profiles.xml";
    
    QFile file(config_file);
    if (!file.exists()) {
        // Create default profile
        RdxJackProfile default_profile;
        default_profile.name = "default";
        default_profile.description = "Default RDX JACK Configuration";
        default_profile.auto_activate = true;
        m_profiles["default"] = default_profile;
        return;
    }
    
    // TODO: Implement XML parsing for profiles
    qDebug() << "Loading profiles from:" << config_file;
}

QStringList RdxJackManager::getAvailableProfiles() const
{
    return m_profiles.keys();
}

bool RdxJackManager::loadProfile(const QString &profile_name)
{
    if (!m_profiles.contains(profile_name)) {
        qWarning() << "Profile not found:" << profile_name;
        return false;
    }
    
    m_current_profile = profile_name;
    
    // TODO: Apply profile settings
    qDebug() << "Loaded profile:" << profile_name;
    
    emit profileChanged(profile_name);
    return true;
}

RdxJackProfile RdxJackManager::getCurrentProfile() const
{
    return m_profiles.value(m_current_profile);
}

bool RdxJackManager::saveProfile(const RdxJackProfile &profile)
{
    m_profiles[profile.name] = profile;
    saveProfilesToConfig();
    return true;
}

bool RdxJackManager::deleteProfile(const QString &profile_name)
{
    if (profile_name == "default") {
        qWarning() << "Cannot delete default profile";
        return false;
    }
    
    m_profiles.remove(profile_name);
    saveProfilesToConfig();
    return true;
}

bool RdxJackManager::makeConnection(const QString &source_port, const QString &dest_port)
{
#ifdef JACK
    if (m_jack_client) {
        int result = jack_connect(m_jack_client, source_port.toUtf8().constData(), 
                                 dest_port.toUtf8().constData());
        if (result == 0) {
            emit connectionChanged(source_port, dest_port, true);
            return true;
        }
    }
#endif
    return false;
}

bool RdxJackManager::breakConnection(const QString &source_port, const QString &dest_port)
{
#ifdef JACK
    if (m_jack_client) {
        int result = jack_disconnect(m_jack_client, source_port.toUtf8().constData(),
                                   dest_port.toUtf8().constData());
        if (result == 0) {
            emit connectionChanged(source_port, dest_port, false);
            return true;
        }
    }
#endif
    return false;
}

QMap<QString, QString> RdxJackManager::getCurrentConnections() const
{
    QMap<QString, QString> connections;
    
#ifdef JACK
    if (!m_jack_client) {
        return connections;
    }
    
    const char **ports = jack_get_ports(m_jack_client, nullptr, nullptr, JackPortIsOutput);
    if (ports) {
        for (int i = 0; ports[i]; ++i) {
            jack_port_t *port = jack_port_by_name(m_jack_client, ports[i]);
            if (port) {
                const char **connected = jack_port_get_connections(port);
                if (connected) {
                    for (int j = 0; connected[j]; ++j) {
                        connections[QString::fromUtf8(ports[i])] = QString::fromUtf8(connected[j]);
                    }
                    jack_free(connected);
                }
            }
        }
        jack_free(ports);
    }
#endif
    
    return connections;
}

bool RdxJackManager::startRivendellServices()
{
    // TODO: Start Rivendell services via systemd/service manager
    qDebug() << "Starting Rivendell services";
    return true;
}

bool RdxJackManager::startStereoTool(const QString &preset_file)
{
    QStringList args;
    args << "/usr/local/bin/stereo_tool_gui_jack_64_1030";
    if (!preset_file.isEmpty()) {
        args << "--preset" << preset_file;
    }
    
    return executeJackCommand(args);
}

bool RdxJackManager::startLiquidsoap(const QString &script_file)
{
    QStringList args;
    args << "liquidsoap";
    if (!script_file.isEmpty()) {
        args << script_file;
    } else {
        args << "/home/rd/radio.liq"; // Default script
    }
    
    return executeJackCommand(args);
}

bool RdxJackManager::startIcecast()
{
    QProcess process;
    process.start("systemctl", QStringList() << "start" << "icecast2");
    return process.waitForFinished(5000) && process.exitCode() == 0;
}

void RdxJackManager::saveProfilesToConfig()
{
    QString config_dir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    QDir().mkpath(config_dir + "/rdx");
    QString config_file = config_dir + "/rdx/jack-profiles.xml";
    
    // TODO: Implement XML writing for profiles
    qDebug() << "Saving profiles to:" << config_file;
}