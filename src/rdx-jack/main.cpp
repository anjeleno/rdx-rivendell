/*
 * main.cpp
 *
 * RDX JACK Helper Service - Main Entry Point
 *
 * Copyright (C) 2025 RDX Project
 */

#include <QCoreApplication>
#include <QCommandLineParser>
#include <QDebug>
#include <QLoggingCategory>
#include <QThread>

#include "rdx_jack_service.h"

Q_LOGGING_CATEGORY(rdxJack, "rdx.jack")

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    
    app.setApplicationName("rdx-jack-helper");
    app.setApplicationVersion("1.0.0");
    app.setOrganizationName("RDX Project");
    
    // Command line parsing
    QCommandLineParser parser;
    parser.setApplicationDescription("RDX Enhanced JACK Management Service");
    parser.addHelpOption();
    parser.addVersionOption();
    
    QCommandLineOption testOption(QStringList() << "t" << "test", 
                                 "Run in test mode without D-Bus service");
    parser.addOption(testOption);
    
    QCommandLineOption scanOption(QStringList() << "s" << "scan", 
                                 "Scan and display audio devices then exit");
    parser.addOption(scanOption);
    
    QCommandLineOption profileOption(QStringList() << "p" << "profile", 
                                   "Load and activate specified profile", "profile_name");
    parser.addOption(profileOption);
    
    QCommandLineOption listProfilesOption(QStringList() << "l" << "list-profiles", 
                                        "List all available profiles");
    parser.addOption(listProfilesOption);
    
    QCommandLineOption switchInputOption(QStringList() << "i" << "switch-input", 
                                       "Switch input source to specified client", "client_name");
    parser.addOption(switchInputOption);
    
    QCommandLineOption listSourcesOption(QStringList() << "ls" << "list-sources", 
                                       "List available input sources with priorities");
    parser.addOption(listSourcesOption);
    
    QCommandLineOption disconnectOption(QStringList() << "d" << "disconnect", 
                                      "Disconnect all connections from specified client", "client_name");
    parser.addOption(disconnectOption);
    
    parser.process(app);
    
    qCDebug(rdxJack) << "Starting RDX JACK Helper Service";
    qCDebug(rdxJack) << "Version:" << app.applicationVersion();
    
#ifdef JACK
    qCDebug(rdxJack) << "JACK support: ENABLED";
#else
    qCDebug(rdxJack) << "JACK support: DISABLED";
#endif
    
    // Handle list profiles mode
    if (parser.isSet(listProfilesOption)) {
        RdxJackManager manager;
        
        qInfo() << "=== Available Profiles ===";
        QStringList profiles = manager.getAvailableProfiles();
        if (profiles.isEmpty()) {
            qInfo() << "No profiles configured";
        } else {
            for (const QString &profile : profiles) {
                RdxJackProfile p = manager.getCurrentProfile();
                qInfo() << "Profile:" << profile;
                if (profile == "default") {
                    qInfo() << "  Description: Default RDX configuration";
                    qInfo() << "  Auto-activate: Yes";
                }
                qInfo() << "";
            }
        }
        return 0;
    }
    
    // Handle scan-only mode
    if (parser.isSet(scanOption)) {
        RdxJackManager manager;
        manager.scanAudioDevices();
        
        qInfo() << "=== Audio Devices ===";
        for (const auto &device : manager.getAudioDevices()) {
            qInfo() << "Device:" << device.name;
            qInfo() << "  ALSA:" << device.alsa_name;
            qInfo() << "  Type:" << device.device_type;
            qInfo() << "  Inputs:" << device.input_channels;
            qInfo() << "  Outputs:" << device.output_channels;
            qInfo() << "  Active:" << (device.is_active ? "Yes" : "No");
            qInfo() << "";
        }
        
        qInfo() << "JACK Status:" << (manager.isJackRunning() ? "Running" : "Not Running");
        return 0;
    }
    
    // Handle profile loading
    if (parser.isSet(profileOption)) {
        QString profileName = parser.value(profileOption);
        RdxJackManager manager;
        
        qInfo() << "=== Loading Profile:" << profileName << "===";
        
        if (manager.loadProfile(profileName)) {
            qInfo() << "✅ Profile loaded successfully!";
            qInfo() << "🔄 Waiting for services to start...";
            
            // Wait with event loop processing to allow timers to fire
            QEventLoop loop;
            QTimer::singleShot(4000, &loop, &QEventLoop::quit);
            loop.exec();
            
            manager.scanAudioDevices();
            qInfo() << "\n=== Post-Profile Device Status ===";
            for (const auto &device : manager.getAudioDevices()) {
                qInfo() << "Device:" << device.name << (device.is_active ? "✅" : "❌");
            }
        } else {
            qCritical() << "❌ Failed to load profile:" << profileName;
            return 1;
        }
        return 0;
    }
    
    // Handle routing commands
    if (parser.isSet(listSourcesOption)) {
        RdxJackManager manager;
        QStringList sources = manager.getInputSources();
        
        qInfo() << "=== Available Input Sources ===";
        QString current = manager.getCurrentInputSource();
        for (const QString &source : sources) {
            QString indicator = (source == current) ? " ✅" : "";
            qInfo() << source << indicator;
        }
        return 0;
    }
    
    if (parser.isSet(switchInputOption)) {
        QString sourceName = parser.value(switchInputOption);
        RdxJackManager manager;
        
        qInfo() << "🔀 Switching input to:" << sourceName;
        if (manager.switchInputSource(sourceName)) {
            qInfo() << "✅ Input switched successfully!";
        } else {
            qCritical() << "❌ Failed to switch input to:" << sourceName;
            return 1;
        }
        return 0;
    }
    
    if (parser.isSet(disconnectOption)) {
        QString clientName = parser.value(disconnectOption);
        RdxJackManager manager;
        
        qInfo() << "🔌 Disconnecting all connections for:" << clientName;
        if (manager.disconnectAllFrom(clientName)) {
            qInfo() << "✅ Disconnected successfully!";
        } else {
            qCritical() << "❌ Failed to disconnect:" << clientName;
            return 1;
        }
        return 0;
    }
    
    // Create service (with test mode option)
    RdxJackService service(parser.isSet(testOption));
    
    return app.exec();
}