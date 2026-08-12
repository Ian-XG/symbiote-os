#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>

/*
 * The system clock's timezone, and whether it is being kept in step.
 *
 * A live image has no idea where it is. Nothing set a zone, so the machine ran
 * on UTC and the clock in the corner of the desktop was simply wrong — seven
 * hours out, in the case that found this — with no screen anywhere in the
 * system offering to correct it. A clock that is confidently wrong is worse
 * than no clock; it is the one part of a desktop everybody trusts without
 * checking.
 *
 * Deliberately not geolocated. Working out where the machine is would mean
 * asking a server on the internet, on first boot, from an image whose whole
 * point is security work. The operator picks the zone.
 *
 * timedatectl does the work: it owns /etc/localtime, tells NTP about the
 * change, and goes through polkit, so it is also the one route that behaves
 * correctly on a session without logind.
 */
class TimeService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString timezone READ timezone NOTIFY changed)
    /** The offset as a person reads it: "UTC+02:00". */
    Q_PROPERTY(QString offset READ offset NOTIFY changed)
    Q_PROPERTY(bool ntpEnabled READ ntpEnabled NOTIFY changed)
    Q_PROPERTY(bool ntpSynced READ ntpSynced NOTIFY changed)
    /** Every zone the system knows, sorted. Read once — it is a static list. */
    Q_PROPERTY(QStringList zones READ zones CONSTANT)
    Q_PROPERTY(QString lastError READ lastError NOTIFY changed)

public:
    explicit TimeService(QObject *parent = nullptr);

    QString timezone() const { return m_timezone; }
    QString offset() const { return m_offset; }
    bool ntpEnabled() const { return m_ntpEnabled; }
    bool ntpSynced() const { return m_ntpSynced; }
    QStringList zones() const { return m_zones; }
    QString lastError() const { return m_lastError; }

    /** Set the zone, as an IANA name such as "America/Mexico_City". */
    Q_INVOKABLE void setTimezone(const QString &zone);
    /** Turn network time on or off. */
    Q_INVOKABLE void setNtp(bool on);
    /* The zones whose name contains `text`, capped so the list stays a list.
       There are over four hundred of them; showing all of them is a wall. */
    Q_INVOKABLE QStringList search(const QString &text, int limit = 40) const;
    Q_INVOKABLE void clearError();

signals:
    void changed();

private slots:
    void refresh();

private:
    bool run(const QStringList &args);

    QString m_timezone;
    QString m_offset;
    bool m_ntpEnabled = false;
    bool m_ntpSynced = false;
    QStringList m_zones;
    QString m_lastError;
    QTimer m_timer;
};
