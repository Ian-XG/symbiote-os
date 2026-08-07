#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QDBusObjectPath>

/*
 * Wi-Fi through NetworkManager, over QtDBus.
 *
 * Replaces the Node dbus-next client, whose native usocket dependency never
 * built against current Node and left calls hanging with no error. QtDBus is
 * part of Qt, so there is no native module to fail.
 */
class NetworkService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool enabled READ enabled NOTIFY changed)
    Q_PROPERTY(QString device READ device NOTIFY changed)
    Q_PROPERTY(QVariantList networks READ networks NOTIFY changed)
    Q_PROPERTY(QString lastError READ lastError NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit NetworkService(QObject *parent = nullptr);

    bool available() const { return m_available; }
    bool enabled() const { return m_enabled; }
    QString device() const { return m_device; }
    QVariantList networks() const { return m_networks; }
    QString lastError() const { return m_lastError; }
    bool busy() const { return m_busy; }

    /** Ask the adapter to re-scan. NetworkManager rate-limits this. */
    Q_INVOKABLE void scan();
    /** Join a network. Empty passphrase for open networks. */
    Q_INVOKABLE void connectTo(const QString &ssid, const QString &passphrase);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void setEnabled(bool on);

signals:
    void changed();
    void busyChanged();

private slots:
    void refresh();

private:
    QDBusObjectPath wifiDevice();
    void setBusy(bool b);
    void fail(const QString &why);

    bool m_available = false;
    bool m_enabled = false;
    bool m_busy = false;
    QString m_device;
    QString m_lastError;
    QVariantList m_networks;
    QDBusObjectPath m_devicePath;

    QTimer m_timer;
};
