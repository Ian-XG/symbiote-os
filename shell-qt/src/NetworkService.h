#pragma once

#include <QObject>
#include <QSet>
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
    /** The SSID a connect or forget is currently working on, for the row to say so. */
    Q_PROPERTY(QString busySsid READ busySsid NOTIFY busyChanged)

public:
    explicit NetworkService(QObject *parent = nullptr);

    bool available() const { return m_available; }
    bool enabled() const { return m_enabled; }
    QString device() const { return m_device; }
    QVariantList networks() const { return m_networks; }
    QString lastError() const { return m_lastError; }
    bool busy() const { return m_busy; }
    QString busySsid() const { return m_busySsid; }

    /** Ask the adapter to re-scan. NetworkManager rate-limits this. */
    Q_INVOKABLE void scan();
    /* Join a network.
     *
     * An empty passphrase is not "this network is open" — it means "use
     * whatever NetworkManager already knows about this SSID". A saved profile
     * carries its own secret in NM's keyring, so a known network joins without
     * anyone typing anything, which is the entire point of saving it.
     */
    Q_INVOKABLE void connectTo(const QString &ssid, const QString &passphrase);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void setEnabled(bool on);

    /** Delete every saved profile for an SSID, so the next join asks again. */
    Q_INVOKABLE void forget(const QString &ssid);

    /** True when NetworkManager holds a saved profile for this SSID. */
    Q_INVOKABLE bool isSaved(const QString &ssid) const;

    /* Whether anything saved here outlives a reboot. On a live image without a
       persistence partition NM's profile directory is a tmpfs, and a network
       joined today is genuinely gone tomorrow — worth saying rather than
       letting it look like a bug in this panel. */
    Q_INVOKABLE bool profilesPersist() const;

    /* Errors are read-only to QML deliberately — nothing outside should be
       able to invent one — but they do need clearing once shown, and
       assigning to a read-only property fails silently at runtime. It had
       been failing since the Wi-Fi panel first tried it. */
    Q_INVOKABLE void clearError();

signals:
    void changed();
    void busyChanged();

private slots:
    void refresh();

private:
    QDBusObjectPath wifiDevice();
    void setBusy(bool b, const QString &ssid = QString());
    void fail(const QString &why);

    /** Every saved profile whose 802-11-wireless.ssid matches. */
    QList<QDBusObjectPath> savedProfiles(const QString &ssid) const;
    /** Refresh m_saved from NetworkManager's settings service. */
    void reloadSaved();
    /* Undo the autoconnect block NetworkManager sets on a manual disconnect.
       Without this, disconnecting once means the network never comes back by
       itself — which reads as "it forgot my password" even though the profile
       is still there. */
    void restoreAutoconnect();

    bool m_available = false;
    bool m_enabled = false;
    bool m_busy = false;
    QString m_device;
    QString m_busySsid;
    QString m_lastError;
    QVariantList m_networks;
    QDBusObjectPath m_devicePath;
    /** SSIDs NetworkManager has a profile for. */
    QSet<QString> m_saved;
    /** Polls since the profile list was last read; see reloadSaved(). */
    int m_savedAge = 99;

    QTimer m_timer;
};
