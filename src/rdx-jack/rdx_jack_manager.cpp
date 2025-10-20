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
#include <QThread>
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
    
    m_client_monitor_timer = new QTimer(this);
    m_client_monitor_timer->setInterval(1000); // Monitor client changes every second
    connect(m_client_monitor_timer, &QTimer::timeout, this, &RdxJackManager::onJackClientChange);
    
    // Initialize D-Bus interface for system communication
    m_dbus_interface = new QDBusInterface("org.rdx.jack", "/org/rdx/jack", 
                                         "org.rdx.jack", QDBusConnection::systemBus(), this);
    
    // Load configuration
    loadProfilesFromConfig();
    
    // Start monitoring
    m_jack_status_timer->start();
    m_device_scan_timer->start();
    m_client_monitor_timer->start();
    
    // Setup critical connection protection
    setupDefaultCriticalConnections();
    
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
        
        // Create live-broadcast profile for testing
        RdxJackProfile live_profile;
        live_profile.name = "live-broadcast";
        live_profile.description = "Live on-air broadcasting with processing chain";
        live_profile.auto_activate = true;
        live_profile.auto_clients << "stereo_tool_gui_jack_64_1030" << "liquidsoap";
        
        // Add some basic connections
        live_profile.connections["rivendell_0:playout_0L"] = "stereo_tool_gui_jack_64_1030:in_1";
        live_profile.connections["rivendell_0:playout_0R"] = "stereo_tool_gui_jack_64_1030:in_2";
        live_profile.connections["stereo_tool_gui_jack_64_1030:out_l"] = "liquidsoap:in_0";
        live_profile.connections["stereo_tool_gui_jack_64_1030:out_r"] = "liquidsoap:in_1";
        
        m_profiles["live-broadcast"] = live_profile;
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
    
    RdxJackProfile profile = m_profiles[profile_name];
    m_current_profile = profile_name;
    
    qInfo() << "📋 Loading profile:" << profile_name;
    
    // 1. Prevent auto-connections for key clients
    preventAutoConnect("stereo_tool_gui_jack_64_1030");
    preventAutoConnect("system");
    
    // 2. Set input priorities based on profile
    if (profile_name == "live-broadcast") {
        setInputPriority("system", 100);        // Physical inputs highest
        setInputPriority("vlc", 80);            // VLC second
        setInputPriority("liquidsoap", 60);     // Liquidsoap third
    } else if (profile_name == "production") {
        setInputPriority("vlc", 100);           // VLC highest for production
        setInputPriority("system", 80);         // Physical second
        setInputPriority("liquidsoap", 60);     // Liquidsoap third
    } else if (profile_name == "automation") {
        setInputPriority("liquidsoap", 100);    // Liquidsoap highest for automation
        setInputPriority("vlc", 80);            // VLC second
        setInputPriority("system", 60);         // Physical lowest
    }
    
    // 3. Start services if specified
    if (profile.auto_clients.contains("stereo_tool")) {
        if (startStereoTool()) {
            qInfo() << "✅ Stereo Tool started for profile:" << profile_name;
        }
    }
    
    if (profile.auto_clients.contains("liquidsoap")) {
        if (startLiquidsoap()) {
            qInfo() << "✅ Liquidsoap started for profile:" << profile_name;
        }
    }
    
    // 4. Setup critical processing chain and optional input auto-routing
    QTimer::singleShot(2000, this, [this, profile_name]() {
        // First: Always establish critical processing chain
        establishCriticalProcessingChain();
        
        // Second: Handle input routing based on profile
        RdxJackProfile profile = m_profiles[profile_name];
        if (profile.auto_activate) {
            QStringList sources = getInputSources();
            QString vlc_source = "";
            
            // Look for VLC first (preferred auto-route)
            for (const QString &source : sources) {
                if (source.contains("vlc", Qt::CaseInsensitive)) {
                    vlc_source = source;
                    break;
                }
            }
            
            if (!vlc_source.isEmpty()) {
                switchInputSource(vlc_source, "rivendell_0");
                qInfo() << "� Auto-routed VLC to Rivendell:" << vlc_source;
            } else {
                qInfo() << "👀 No VLC detected - Rivendell input available for manual routing";
                qInfo() << "🎛️ Use --switch-input <source> to connect input source";
            }
        } else {
            qInfo() << "👀 Manual input mode for profile:" << profile_name;
            qInfo() << "🎛️ Use --switch-input to select input source";
        }
    });
    
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
    qInfo() << "🎛️  Starting Stereo Tool with preset:" << preset_file;
    
    QString stereo_tool_path = "/home/rd/imports/APPS/stereo_tool_gui_jack_64_1030";
    if (!QFile::exists(stereo_tool_path)) {
        qWarning() << "❌ Stereo Tool not found at:" << stereo_tool_path;
        return false;
    }
    
    qInfo() << "✅ Stereo Tool binary found, starting...";
    
    // Check if Stereo Tool is already running
    QStringList clients = getJackClients();
    if (clients.contains("stereo_tool_gui_jack_64_1030")) {
        qInfo() << "✅ Stereo Tool already running in JACK";
        emit serviceStatusChanged("stereo_tool", true);
        return true;
    }
    
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    
    // Ensure JACK environment variables are set
    env.insert("JACK_PROMISCUOUS_SERVER", "audio");
    env.insert("JACK_NO_AUDIO_RESERVATION", "1");
    process->setProcessEnvironment(env);
    
    QStringList args;
    if (!preset_file.isEmpty() && QFile::exists(preset_file)) {
        args << "--preset" << preset_file;
    }
    
    qInfo() << "🚀 Launching:" << stereo_tool_path;
    process->start(stereo_tool_path, args);
    
    if (!process->waitForStarted(5000)) {
        qWarning() << "❌ Failed to start Stereo Tool:" << process->errorString();
        delete process;
        return false;
    }
    
    qInfo() << "✅ Stereo Tool started, PID:" << process->processId();
    emit serviceStatusChanged("stereo_tool", true);
    return true;
}

bool RdxJackManager::startLiquidsoap(const QString &script_file)
{
    QString script_path = script_file.isEmpty() ? "/home/rd/radio.liq" : script_file;
    qInfo() << "🌊 Starting Liquidsoap with script:" << script_path;
    
    if (!QFile::exists(script_path)) {
        qWarning() << "❌ Liquidsoap script not found:" << script_path;
        return false;
    }
    
    // Check if Liquidsoap is already running
    QStringList clients = getJackClients();
    if (clients.contains("liquidsoap")) {
        qInfo() << "✅ Liquidsoap already running in JACK";
        emit serviceStatusChanged("liquidsoap", true);
        return true;
    }
    
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("JACK_PROMISCUOUS_SERVER", "audio");
    process->setProcessEnvironment(env);
    
    QStringList args;
    args << script_path;
    
    qInfo() << "🚀 Launching Liquidsoap...";
    process->start("liquidsoap", args);
    
    if (!process->waitForStarted(5000)) {
        qWarning() << "❌ Failed to start Liquidsoap:" << process->errorString();
        delete process;
        return false;
    }
    
    qInfo() << "✅ Liquidsoap started, PID:" << process->processId();
    emit serviceStatusChanged("liquidsoap", true);
    return true;
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

// ===== ROUTING MANAGEMENT METHODS =====

bool RdxJackManager::setInputPriority(const QString &source_client, int priority)
{
    qInfo() << "🎯 Setting input priority for" << source_client << "to" << priority;
    m_input_priorities[source_client] = priority;
    return true;
}

bool RdxJackManager::switchInputSource(const QString &new_source, const QString &target_client)
{
    qInfo() << "🔀 Switching input source to" << new_source << "for target" << target_client;
    
    // SAFELY disconnect ONLY input sources to target's record ports
    // NEVER touch output connections that could interrupt live broadcast
    QStringList target_input_ports = getJackPorts(target_client);
    for (const QString &port : target_input_ports) {
        // Only touch record/input ports, NEVER playout/output ports
        if (port.contains("record") && !port.contains("playout")) {
            QProcess process;
            process.start("jack_lsp", QStringList() << "-c" << port);
            process.waitForFinished(3000);
            
            QString output = process.readAllStandardOutput();
            QStringList lines = output.split('\n', Qt::SkipEmptyParts);
            
            for (const QString &line : lines) {
                if (line.trimmed().startsWith(port)) {
                    continue; // Skip the port name line
                }
                
                QString connected_source = line.trimmed();
                if (!connected_source.isEmpty()) {
                    // CRITICAL PROTECTION: Never disconnect critical connections
                    if (isConnectionCritical(connected_source, port)) {
                        qWarning() << "🛡️ PROTECTED: Skipping critical connection:" << connected_source << "→" << port;
                        continue;
                    }
                    
                    // SAFETY: Only disconnect INPUT sources, never OUTPUT destinations  
                    if (connected_source.contains("capture") || connected_source.contains("out") || 
                        connected_source.contains("vlc") || connected_source.contains("liquidsoap")) {
                        if (breakConnection(connected_source, port)) {
                            qInfo() << "🔌 Safely cleared input:" << connected_source << "→" << port;
                        }
                    } else {
                        qInfo() << "⚠️ Skipping unknown source (safety):" << connected_source << "→" << port;
                    }
                }
            }
        }
    }
    
    // Find the new source ports
    QStringList source_ports = getJackPorts(new_source);
    QStringList target_ports = getJackPorts(target_client);
    
    qInfo() << "🔍 Found source ports for" << new_source << ":" << source_ports;
    qInfo() << "🔍 Found target ports for" << target_client << ":" << target_ports;
    
    if (source_ports.isEmpty()) {
        qWarning() << "❌ No ports found for source:" << new_source;
        return false;
    }
    
    if (target_ports.isEmpty()) {
        qWarning() << "❌ No ports found for target:" << target_client;
        return false;
    }
    
    // Connect source outputs to target inputs with proper port matching
    bool success = true;
    
    // Get actual output and input ports with correct JACK semantics
    QStringList source_outputs;
    QStringList target_inputs;
    
    // Source outputs: ports that produce audio (capture ports, playout ports)
    for (const QString &port : source_ports) {
        if (port.contains("capture") || port.contains("playout") || 
            port.contains("output") || port.contains("out")) {
            source_outputs.append(port);
        }
    }
    
    // Target inputs: ports that receive audio (record ports, input ports)
    for (const QString &port : target_ports) {
        if (port.contains("record") || port.contains("input") || 
            port.contains("in")) {
            target_inputs.append(port);
        }
    }
    
    qInfo() << "🔍 Source outputs:" << source_outputs;
    qInfo() << "🔍 Target inputs:" << target_inputs;
    
    // Connect matching channels
    for (int i = 0; i < qMin(source_outputs.size(), target_inputs.size()); ++i) {
        QString source_port = source_outputs[i];
        QString target_port = target_inputs[i];
        
        qInfo() << "🔗 Attempting to connect:" << source_port << "→" << target_port;
        if (makeConnection(source_port, target_port)) {
            qInfo() << "✅ Connected" << source_port << "→" << target_port;
        } else {
            qWarning() << "❌ Failed to connect" << source_port << "→" << target_port;
            success = false;
        }
    }
    
    if (success) {
        m_active_input_source = new_source;
        qInfo() << "✅ Input switched to:" << new_source;
    }
    
    return success;
}

bool RdxJackManager::preventAutoConnect(const QString &client_name)
{
    qInfo() << "🚫 Adding" << client_name << "to auto-connect blacklist";
    
    if (!m_auto_connect_blacklist.contains(client_name)) {
        m_auto_connect_blacklist.append(client_name);
    }
    
    // Disconnect any existing auto-connections
    return disconnectAllFrom(client_name);
}

bool RdxJackManager::disconnectAllFrom(const QString &client_name)
{
    qInfo() << "🔌 Safely disconnecting connections for" << client_name << "(preserving critical outputs)";
    
    // CRITICAL PROTECTION: Never disconnect critical broadcast clients
    if (isClientCritical(client_name)) {
        qWarning() << "🛡️ CRITICAL: Refusing to disconnect protected client:" << client_name;
        return false;
    }
    
    QStringList client_ports = getJackPorts(client_name);
    bool success = true;
    
    for (const QString &port : client_ports) {
        // Get current connections for this port
        QProcess process;
        process.start("jack_lsp", QStringList() << "-c" << port);
        process.waitForFinished(3000);
        
        QString output = process.readAllStandardOutput();
        QStringList lines = output.split('\n', Qt::SkipEmptyParts);
        
        for (const QString &line : lines) {
            if (line.trimmed().startsWith(port)) {
                continue; // Skip the port name line
            }
            
            QString connected_port = line.trimmed();
            if (!connected_port.isEmpty()) {
                if (port.contains(":out")) {
                    // This is an output port, check if connection is critical
                    if (isConnectionCritical(port, connected_port)) {
                        qWarning() << "🛡️ PROTECTED: Skipping critical connection:" << port << "→" << connected_port;
                        continue;
                    }
                    if (breakConnection(port, connected_port)) {
                        qInfo() << "✅ Disconnected" << port << "→" << connected_port;
                    } else {
                        qWarning() << "❌ Failed to disconnect" << port << "→" << connected_port;
                        success = false;
                    }
                } else if (port.contains(":in")) {
                    // This is an input port, check if connection is critical
                    if (isConnectionCritical(connected_port, port)) {
                        qWarning() << "🛡️ PROTECTED: Skipping critical connection:" << connected_port << "→" << port;
                        continue;
                    }
                    if (breakConnection(connected_port, port)) {
                        qInfo() << "✅ Disconnected" << connected_port << "→" << port;
                    } else {
                        qWarning() << "❌ Failed to disconnect" << connected_port << "→" << port;
                        success = false;
                    }
                }
            }
        }
    }
    
    return success;
}

QStringList RdxJackManager::getInputSources() const
{
    QStringList sources;
    QStringList all_clients = getJackClients();
    
    for (const QString &client : all_clients) {
        // Check if client has output ports (can be an input source)
        QStringList ports = getJackPorts(client);
        for (const QString &port : ports) {
            if (port.contains(":out")) {
                sources.append(client);
                break;
            }
        }
    }
    
    // Sort by priority
    std::sort(sources.begin(), sources.end(), [this](const QString &a, const QString &b) {
        return m_input_priorities.value(a, 0) > m_input_priorities.value(b, 0);
    });
    
    return sources;
}

QString RdxJackManager::getCurrentInputSource(const QString &target_client) const
{
    // Check what's currently connected to the target client's input
    QStringList target_ports = getJackPorts(target_client);
    
    for (const QString &port : target_ports) {
        if (port.contains(":in")) {
            QProcess process;
            process.start("jack_lsp", QStringList() << "-c" << port);
            process.waitForFinished(3000);
            
            QString output = process.readAllStandardOutput();
            QStringList lines = output.split('\n', Qt::SkipEmptyParts);
            
            for (const QString &line : lines) {
                if (line.trimmed().startsWith(port)) {
                    continue;
                }
                
                QString connected_port = line.trimmed();
                if (!connected_port.isEmpty()) {
                    // Extract client name from port
                    return connected_port.split(':')[0];
                }
            }
        }
    }
    
    return QString();
}

// ===== INTELLIGENT CLIENT MONITORING =====

void RdxJackManager::onJackClientChange()
{
    if (!isJackRunning()) {
        return;
    }
    
    QStringList current_clients = getJackClients();
    
    // Find new clients (appeared since last check)
    for (const QString &client : current_clients) {
        if (!m_previous_clients.contains(client)) {
            qInfo() << "👀 New JACK client detected:" << client;
            
            // Smart auto-connection rules
            if (client.contains("vlc", Qt::CaseInsensitive)) {
                qInfo() << "🎵 VLC detected - checking if auto-routing is appropriate";
                
                // Only auto-route VLC if no other input is currently active
                QString current_input = getCurrentInputSource("rivendell_0");
                if (current_input.isEmpty() || current_input.contains("vlc", Qt::CaseInsensitive)) {
                    qInfo() << "🎵 Auto-routing VLC to Rivendell (intentional media playback)";
                    QTimer::singleShot(500, this, [this, client]() {
                        if (switchInputSource(client, "rivendell_0")) {
                            qInfo() << "✅ VLC auto-routed successfully";
                        }
                    });
                } else {
                    qInfo() << "ℹ️ VLC available but" << current_input << "is active - use --switch-input vlc to change";
                }
            }
            else if (client.contains("system")) {
                qInfo() << "🎤 System audio detected - respecting user/preset control";
                qInfo() << "💡 Use --switch-input system or enable auto_activate in profile";
            }
            else if (client.contains("stereo_tool", Qt::CaseInsensitive)) {
                qInfo() << "🎛️ Stereo Tool connected - preventing auto-capture routing";
                preventAutoConnect(client);
            }
            else {
                qInfo() << "🔗 Unknown client:" << client << "- monitoring only";
            }
        }
    }
    
    // Find removed clients
    for (const QString &client : m_previous_clients) {
        if (!current_clients.contains(client)) {
            qInfo() << "👋 JACK client disconnected:" << client;
            
            // If the active source disappeared, suggest alternatives
            if (client == m_active_input_source) {
                qWarning() << "⚠️ Active input source disconnected:" << client;
                QStringList available = getInputSources();
                if (!available.isEmpty()) {
                    qInfo() << "💡 Available alternatives:" << available.join(", ");
                    qInfo() << "💡 Use --switch-input <source> to select new input";
                }
            }
        }
    }
    
    m_previous_clients = current_clients;
}

// ===== CRITICAL CONNECTION PROTECTION =====

void RdxJackManager::setupDefaultCriticalConnections()
{
    qInfo() << "🛡️ Setting up critical connection protection...";
    
    // Mark critical clients that should never have their connections disturbed
    markClientCritical("stereo_tool");           // Audio processing chain
    markClientCritical("liquidsoap");            // Streaming output
    markClientCritical("icecast");               // Streaming server
    
    // Mark critical connection patterns (will be checked dynamically)
    // These represent the processing chain that must not be interrupted
    qInfo() << "🛡️ Critical clients protected: stereo_tool, liquidsoap, icecast";
    qInfo() << "🛡️ Rivendell playout connections are always protected";
}

bool RdxJackManager::markConnectionCritical(const QString &source_port, const QString &dest_port)
{
    QString connection_key = source_port + " -> " + dest_port;
    if (!m_critical_connections.contains(connection_key)) {
        m_critical_connections.append(connection_key);
        qInfo() << "🛡️ Marked critical connection:" << connection_key;
        return true;
    }
    return false;
}

bool RdxJackManager::markClientCritical(const QString &client_name)
{
    if (!m_critical_clients.contains(client_name)) {
        m_critical_clients.append(client_name);
        return true;
    }
    return false;
}

bool RdxJackManager::isConnectionCritical(const QString &source_port, const QString &dest_port) const
{
    QString connection_key = source_port + " -> " + dest_port;
    
    // Check explicit critical connections
    if (m_critical_connections.contains(connection_key)) {
        return true;
    }
    
    // Check if either client is critical
    QString source_client = source_port.split(':')[0];
    QString dest_client = dest_port.split(':')[0];
    
    if (isClientCritical(source_client) || isClientCritical(dest_client)) {
        return true;
    }
    
    // Always protect rivendell playout outputs
    if (source_port.contains("rivendell") && source_port.contains("playout")) {
        return true;
    }
    
    // Always protect stereo_tool processing chain
    if ((source_port.contains("rivendell") && dest_port.contains("stereo_tool")) ||
        (source_port.contains("stereo_tool") && dest_port.contains("liquidsoap")) ||
        (source_port.contains("liquidsoap") && dest_port.contains("icecast"))) {
        return true;
    }
    
    return false;
}

bool RdxJackManager::isClientCritical(const QString &client_name) const
{
    // Check explicit critical clients
    for (const QString &critical : m_critical_clients) {
        if (client_name.contains(critical, Qt::CaseInsensitive)) {
            return true;
        }
    }
    
    // Always protect rivendell playout
    if (client_name.contains("rivendell") && client_name.contains("playout")) {
        return true;
    }
    
    return false;
}

void RdxJackManager::establishCriticalProcessingChain()
{
    qInfo() << "� Smart detection: Analyzing current JACK clients for processing chain...";
    
    // Step 1: Auto-detect audio processing clients
    QStringList all_clients = getJackClients();
    QStringList processors, streamers;
    
    for (const QString &client : all_clients) {
        // Detect audio processors
        if (client.contains("stereo_tool", Qt::CaseInsensitive) || 
            client.contains("jack_rack", Qt::CaseInsensitive) ||
            client.contains("carla", Qt::CaseInsensitive) ||
            client.contains("non_mixer", Qt::CaseInsensitive)) {
            processors.append(client);
        }
        
        // Detect streaming clients
        if (client.contains("liquidsoap", Qt::CaseInsensitive) ||
            client.contains("glasscoder", Qt::CaseInsensitive) ||
            client.contains("darkice", Qt::CaseInsensitive) ||
            client.contains("butt", Qt::CaseInsensitive) ||
            client.contains("icecast", Qt::CaseInsensitive)) {
            streamers.append(client);
        }
    }
    
    qInfo() << "🎛️ Detected processors:" << (processors.isEmpty() ? "None" : processors.join(", "));
    qInfo() << "📡 Detected streamers:" << (streamers.isEmpty() ? "None" : streamers.join(", "));
    
    // Step 2: Establish critical chain based on what's detected
    if (!processors.isEmpty()) {
        establishProcessorChain("rivendell_0", processors.first());
    } else {
        qInfo() << "ℹ️ No audio processors detected - Rivendell direct output available";
    }
    
    if (!processors.isEmpty() && !streamers.isEmpty()) {
        establishProcessorChain(processors.first(), streamers.first());
    } else if (!streamers.isEmpty()) {
        establishProcessorChain("rivendell_0", streamers.first());
    }
    
    qInfo() << "✅ Adaptive processing chain established based on detected hardware";
}

bool RdxJackManager::establishProcessorChain(const QString &source_client, const QString &dest_client)
{
    qInfo() << "🔗 Connecting processing chain:" << source_client << "→" << dest_client;
    
    QStringList source_ports = getJackPorts(source_client);
    QStringList dest_ports = getJackPorts(dest_client);
    
    // Smart port matching with flexible patterns
    QStringList source_outputs, dest_inputs;
    
    // Find output ports (flexible pattern matching)
    for (const QString &port : source_ports) {
        if (port.contains("playout") || port.contains("output") || 
            port.contains("out") || port.endsWith("L") || port.endsWith("R")) {
            source_outputs.append(port);
        }
    }
    
    // Find input ports (flexible pattern matching) 
    for (const QString &port : dest_ports) {
        if (port.contains("input") || port.contains("in") || 
            port.contains("record") || port.endsWith("L") || port.endsWith("R")) {
            dest_inputs.append(port);
        }
    }
    
    qInfo() << "🔍 Source outputs:" << source_outputs;
    qInfo() << "🔍 Dest inputs:" << dest_inputs;
    
    // Make connections and mark as critical
    bool success = false;
    for (int i = 0; i < qMin(source_outputs.size(), dest_inputs.size()); ++i) {
        QString source_port = source_outputs[i];
        QString dest_port = dest_inputs[i];
        
        if (makeConnection(source_port, dest_port)) {
            markConnectionCritical(source_port, dest_port);
            qInfo() << "🛡️ CRITICAL CHAIN:" << source_port << "→" << dest_port;
            success = true;
        }
    }
    
    return success;
}