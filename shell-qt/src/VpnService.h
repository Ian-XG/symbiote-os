#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>

/*
 * VPN connections, through NetworkManager.
 *
 * The security panel had a VPN row that could only ever say NOT CONNECTED,
 * because nothing was reading the VPN state and there was no way to start one.
 *
 * Deliberately provider-neutral. The obvious move was to preinstall Mullvad
 * and Proton's own clients, which means adding two third-party apt
 * repositories and their signing keys to an image built for security work, and
 * still leaving out everyone else's provider. NetworkManager already knows how
 * to run OpenVPN and WireGuard; a profile from any provider — Mullvad, Proton,
 * a corporate gateway — imports and then behaves like every other connection.
 *
 * nmcli rather than the D-Bus API. Importing a profile means parsing an .ovpn
 * or a wg-quick file into NetworkManager's own settings format, and nmcli is
 * the supported implementation of that; reimplementing it against D-Bus would
 * be several hundred lines to arrive at the same place with more bugs.
 */
class VpnService : public QObject
{
    Q_OBJECT
    /** One entry per configured VPN: name, uuid, type, active. */
    Q_PROPERTY(QVariantList connections READ connections NOTIFY changed)
    Q_PROPERTY(bool anyActive READ anyActive NOTIFY changed)
    /** The name of whichever one is up, or empty. */
    Q_PROPERTY(QString activeName READ activeName NOTIFY changed)
    Q_PROPERTY(QString lastError READ lastError NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)

public:
    explicit VpnService(QObject *parent = nullptr);

    QVariantList connections() const { return m_connections; }
    bool anyActive() const { return !m_activeName.isEmpty(); }
    QString activeName() const { return m_activeName; }
    QString lastError() const { return m_lastError; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE void activate(const QString &uuid);
    Q_INVOKABLE void deactivate(const QString &uuid);
    /* Import a profile. Takes the path to an .ovpn or a wg-quick .conf and
       works out which from the extension, because those are the two things a
       provider hands out and telling them apart is not the operator's job. */
    Q_INVOKABLE void importProfile(const QString &path);
    Q_INVOKABLE void forget(const QString &uuid);
    Q_INVOKABLE void clearError();

signals:
    void changed();

private slots:
    void refresh();

private:
    bool run(const QStringList &args, QString *output = nullptr);

    QVariantList m_connections;
    QString m_activeName;
    QString m_lastError;
    bool m_busy = false;
    QTimer m_timer;
};
