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
    
    parser.process(app);
    
    qCDebug(rdxJack) << "Starting RDX JACK Helper Service";
    qCDebug(rdxJack) << "Version:" << app.applicationVersion();
    
#ifdef JACK
    qCDebug(rdxJack) << "JACK support: ENABLED";
#else
    qCDebug(rdxJack) << "JACK support: DISABLED";
#endif
    
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
    
    // Create service (with test mode option)
    RdxJackService service(parser.isSet(testOption));
    
    return app.exec();
}