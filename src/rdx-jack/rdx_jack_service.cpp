/*
 * rdx_jack_service.cpp
 *
 * D-Bus service for RDX JACK management
 *
 * Copyright (C) 2025 RDX Project
 */

#include "rdx_jack_service.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>
RdxJackService::RdxJackService(bool test_mode, QObject *parent)
    : QObject(parent)
    , m_manager(new RdxJackManager(this))
    , m_test_mode(test_mode)
    {
        if (m_test_mode) {
            qDebug() << "Running in test mode - D-Bus service disabled";
            return;
        }
        
        // Try to register D-Bus service
        QDBusConnection bus = QDBusConnection::systemBus();
        if (!bus.registerService("org.rdx.jack")) {
            qWarning() << "Could not register D-Bus service:" << bus.lastError().message();
            qWarning() << "Falling back to test mode. To fix this:";
            qWarning() << "  sudo cp config/dbus/org.rdx.jack.conf /etc/dbus-1/system.d/";
            qWarning() << "  sudo systemctl reload dbus";
            m_test_mode = true;
            return;
        }
        
        if (!bus.registerObject("/org/rdx/jack", this, QDBusConnection::ExportAllSlots)) {
            qWarning() << "Could not register D-Bus object:" << bus.lastError().message();
            qWarning() << "Falling back to test mode";
            m_test_mode = true;
            return;
        }
        
        qDebug() << "RDX JACK service started on D-Bus";
}

QStringList RdxJackService::getAudioDevices() const
{
    QStringList devices;
    for (const auto &device : m_manager->getAudioDevices()) {
        devices << device.name;
    }
    return devices;
}

bool RdxJackService::isJackRunning() const
{
    return m_manager->isJackRunning();
}

bool RdxJackService::startJackWithDevice(const QString &device_name)
{
    return m_manager->startJackWithDevice(device_name);
}

QStringList RdxJackService::getAvailableProfiles() const
{
    return m_manager->getAvailableProfiles();
}

bool RdxJackService::loadProfile(const QString &profile_name)
{
    return m_manager->loadProfile(profile_name);
}