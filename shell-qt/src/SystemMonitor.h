#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include <QHash>
#include <QElapsedTimer>

/*
 * CPU, memory, storage, thermal and throughput, read from procfs and sysfs.
 *
 * Same sources as the Node bridge it replaces — /proc/stat deltas, /proc/
 * meminfo, statvfs, /sys/class/thermal, /proc/net/dev — but in-process, so a
 * reading costs a file read rather than an IPC round trip.
 */
class SystemMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap cpu READ cpu NOTIFY changed)
    Q_PROPERTY(QVariantMap memory READ memory NOTIFY changed)
    Q_PROPERTY(QVariantMap storage READ storage NOTIFY changed)
    Q_PROPERTY(QVariantMap thermal READ thermal NOTIFY changed)
    Q_PROPERTY(QVariantMap network READ network NOTIFY changed)
    Q_PROPERTY(QString hostname READ hostname CONSTANT)
    Q_PROPERTY(QString edition READ edition CONSTANT)
    Q_PROPERTY(qint64 uptime READ uptime NOTIFY changed)
    /* Kernel release and the 1-minute load average. Read for the callouts
       around the hologram, which in the design carried invented figures
       ("97.2% BIND"); these are the real equivalents. */
    Q_PROPERTY(QString kernel READ kernel CONSTANT)
    Q_PROPERTY(qreal load READ load NOTIFY changed)
    Q_PROPERTY(int taskCount READ taskCount NOTIFY changed)

public:
    explicit SystemMonitor(QObject *parent = nullptr);

    QVariantMap cpu() const { return m_cpu; }
    QVariantMap memory() const { return m_memory; }
    QVariantMap storage() const { return m_storage; }
    QVariantMap thermal() const { return m_thermal; }
    QVariantMap network() const { return m_network; }
    QString hostname() const { return m_hostname; }
    QString edition() const { return m_edition; }
    qint64 uptime() const;
    QString kernel() const;
    qreal load() const;
    int taskCount() const;

    /** Busiest interface, for the NETWORK panel's headline figures. */
    Q_INVOKABLE QVariantMap primaryInterface() const;

signals:
    void changed();

private slots:
    void sample();

private:
    void readCpu();
    void readMemory();
    void readStorage();
    void readThermal();
    void readNetwork();
    void readStatic();

    QVariantMap m_cpu, m_memory, m_storage, m_thermal, m_network;
    QString m_hostname, m_edition;

    // Cumulative counters need a previous sample to become a rate.
    qint64 m_prevIdle = 0, m_prevTotal = 0;
    struct NetSample { qint64 rx = 0, tx = 0; };
    QHash<QString, NetSample> m_prevNet;
    QElapsedTimer m_netClock;

    QTimer m_timer;
};
