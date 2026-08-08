#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QHash>
#include <QElapsedTimer>

/*
 * Top processes by CPU, from procfs.
 *
 * CPU time in /proc is cumulative, so a percentage only exists as a delta
 * between two samples. The first sample has no delta, so it ranks by memory
 * instead of showing a column of zeros.
 */
class ProcessMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList top READ top NOTIFY changed)

public:
    /* Ask a process to quit. Returns an empty string on success, or the reason
       it was refused or failed — the panel shows that text rather than leaving
       the operator to guess why nothing happened.

       SIGTERM, then SIGKILL after a grace period: a process that is asked
       politely gets to save first. */
    Q_INVOKABLE QString terminate(int pid);

public:
    explicit ProcessMonitor(QObject *parent = nullptr);
    QVariantList top() const { return m_top; }

signals:
    void changed();

private slots:
    void sample();

private:
    QVariantList m_top;
    QHash<int, qint64> m_prevTicks;
    QElapsedTimer m_clock;
    QTimer m_timer;
    int m_limit = 8;
};
