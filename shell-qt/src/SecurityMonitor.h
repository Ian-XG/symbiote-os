#pragma once
#include <QObject>
#include <QTimer>
#include <QVariantList>

/*
 * Real security posture. Every row is read from the machine; anything that
 * cannot be established reports "unknown" rather than guessing. The panel this
 * feeds used to be driven by UI switches, which meant it reported whatever had
 * last been clicked — a screen claiming "Firewall: ACTIVE" with no firewall
 * running is worse than no screen.
 */
class SecurityMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList rows READ rows NOTIFY changed)
    Q_PROPERTY(int okCount READ okCount NOTIFY changed)

public:
    explicit SecurityMonitor(QObject *parent = nullptr);
    QVariantList rows() const { return m_rows; }
    int okCount() const;

signals:
    void changed();

private slots:
    void sample();

private:
    QVariantMap firewall();
    QVariantMap vpn();
    QVariantMap encryption();
    QVariantMap updates();
    QVariantMap ports();
    QVariantMap medium();
    /* Errors the device had already logged when the shell started. Only what
       accumulates after that means anything. */
    qint64 m_mediumBaseline = -1;

    QVariantList m_rows;
    QTimer m_timer;
    /** Age of apt's package lists in days, or -1 when it has none. */
    static int listsAgeDays();

    QVariantMap m_updateCache;
    qint64 m_updateCheckedAt = 0;
};
