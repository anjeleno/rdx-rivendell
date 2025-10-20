/*
 * rdx_jack_service.h
 *
 * D-Bus service header for RDX JACK management
 *
 * Copyright (C) 2025 RDX Project
 */

#ifndef RDX_JACK_SERVICE_H
#define RDX_JACK_SERVICE_H

#include <QObject>
#include <QStringList>

#include "rdx/rdx_jack_manager.h"

class RdxJackService : public QObject
{
    Q_OBJECT

public:
    explicit RdxJackService(bool test_mode = false, QObject *parent = nullptr);

public slots:
    // D-Bus exposed methods
    QStringList getAudioDevices() const;
    bool isJackRunning() const;
    bool startJackWithDevice(const QString &device_name);
    QStringList getAvailableProfiles() const;
    bool loadProfile(const QString &profile_name);

private:
    RdxJackManager *m_manager;
    bool m_test_mode;
};

#endif // RDX_JACK_SERVICE_H