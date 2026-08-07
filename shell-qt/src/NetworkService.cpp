#include "NetworkService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QDBusArgument>

namespace {

constexpr auto NM_SERVICE = "org.freedesktop.NetworkManager";
constexpr auto NM_PATH = "/org/freedesktop/NetworkManager";
constexpr auto NM_IFACE = "org.freedesktop.NetworkManager";
constexpr auto DEV_IFACE = "org.freedesktop.NetworkManager.Device";
constexpr auto WIFI_IFACE = "org.freedesktop.NetworkManager.Device.Wireless";
constexpr auto AP_IFACE = "org.freedesktop.NetworkManager.AccessPoint";
constexpr auto SETTINGS_PATH = "/org/freedesktop/NetworkManager/Settings";
constexpr auto SETTINGS_IFACE = "org.freedesktop.NetworkManager.Settings";

constexpr int DEVICE_TYPE_WIFI = 2;

QVariant prop(const QString &path, const QString &iface, const QString &name)
{
    QDBusInterface props(NM_SERVICE, path, "org.freedesktop.DBus.Properties",
                         QDBusConnection::systemBus());
    // Short timeout: a hung call must surface as an error, not a frozen panel.
    props.setTimeout(5000);
    QDBusReply<QVariant> r = props.call("Get", iface, name);
    return r.isValid() ? r.value() : QVariant();
}

} // namespace

NetworkService::NetworkService(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<QMap<QString, QVariantMap>>();

    refresh();
    connect(&m_timer, &QTimer::timeout, this, &NetworkService::refresh);
    m_timer.start(6000);
}

void NetworkService::setBusy(bool b)
{
    if (m_busy == b)
        return;
    m_busy = b;
    emit busyChanged();
}

void NetworkService::fail(const QString &why)
{
    m_lastError = why;
    setBusy(false);
    emit changed();
}

QDBusObjectPath NetworkService::wifiDevice()
{
    QDBusInterface nm(NM_SERVICE, NM_PATH, NM_IFACE, QDBusConnection::systemBus());
    nm.setTimeout(5000);
    QDBusReply<QList<QDBusObjectPath>> reply = nm.call("GetDevices");
    if (!reply.isValid())
        return {};

    for (const QDBusObjectPath &p : reply.value()) {
        if (prop(p.path(), DEV_IFACE, "DeviceType").toInt() == DEVICE_TYPE_WIFI) {
            m_device = prop(p.path(), DEV_IFACE, "Interface").toString();
            return p;
        }
    }
    return {};
}

void NetworkService::refresh()
{
    m_devicePath = wifiDevice();
    if (m_devicePath.path().isEmpty()) {
        // No adapter is a fact, not an error — a VM genuinely has none.
        m_available = false;
        m_enabled = false;
        m_networks.clear();
        emit changed();
        return;
    }

    m_available = true;
    m_enabled = prop(NM_PATH, NM_IFACE, "WirelessEnabled").toBool();

    QVariantList list;
    if (m_enabled) {
        QDBusInterface w(NM_SERVICE, m_devicePath.path(), WIFI_IFACE,
                         QDBusConnection::systemBus());
        w.setTimeout(5000);
        QDBusReply<QList<QDBusObjectPath>> aps = w.call("GetAllAccessPoints");

        const QVariant activeVar = prop(m_devicePath.path(), WIFI_IFACE, "ActiveAccessPoint");
        const QString activePath = activeVar.value<QDBusObjectPath>().path();

        // The same SSID often appears on several access points; keep the
        // strongest so the list reads as networks, not radios.
        QMap<QString, QVariantMap> best;
        if (aps.isValid()) {
            for (const QDBusObjectPath &ap : aps.value()) {
                const QByteArray ssidRaw = prop(ap.path(), AP_IFACE, "Ssid").toByteArray();
                const QString ssid = QString::fromUtf8(ssidRaw);
                if (ssid.isEmpty())
                    continue; // hidden network

                const int strength = prop(ap.path(), AP_IFACE, "Strength").toInt();
                const uint freq = prop(ap.path(), AP_IFACE, "Frequency").toUInt();
                const uint wpa = prop(ap.path(), AP_IFACE, "WpaFlags").toUInt();
                const uint rsn = prop(ap.path(), AP_IFACE, "RsnFlags").toUInt();

                QVariantMap n;
                n["ssid"] = ssid;
                n["strength"] = strength;
                n["band"] = freq > 4000 ? QStringLiteral("5 GHz") : QStringLiteral("2.4 GHz");
                n["secure"] = (wpa != 0 || rsn != 0);
                n["connected"] = (ap.path() == activePath);

                if (!best.contains(ssid) || best[ssid]["strength"].toInt() < strength)
                    best[ssid] = n;
            }
        }

        for (const auto &n : std::as_const(best))
            list.append(n);
        std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
            return a.toMap()["strength"].toInt() > b.toMap()["strength"].toInt();
        });
    }

    m_networks = list;
    m_lastError.clear();
    emit changed();
}

void NetworkService::scan()
{
    if (m_devicePath.path().isEmpty()) {
        fail(QStringLiteral("No wireless device"));
        return;
    }
    setBusy(true);

    QDBusInterface w(NM_SERVICE, m_devicePath.path(), WIFI_IFACE,
                     QDBusConnection::systemBus());
    w.setTimeout(8000);
    QDBusReply<void> r = w.call("RequestScan", QVariantMap());
    if (!r.isValid()) {
        const QString msg = r.error().message();
        // NM refuses a scan that is already running; that is not a failure.
        if (!msg.contains("Scanning", Qt::CaseInsensitive)
            && !msg.contains("AllowedError", Qt::CaseInsensitive)) {
            fail(msg);
            return;
        }
    }

    // Results arrive asynchronously; read back shortly.
    QTimer::singleShot(2500, this, [this] {
        setBusy(false);
        refresh();
    });
}

void NetworkService::connectTo(const QString &ssid, const QString &passphrase)
{
    if (m_devicePath.path().isEmpty()) {
        fail(QStringLiteral("No wireless device"));
        return;
    }
    setBusy(true);

    // Find the access point for this SSID.
    QDBusInterface w(NM_SERVICE, m_devicePath.path(), WIFI_IFACE,
                     QDBusConnection::systemBus());
    w.setTimeout(5000);
    QDBusReply<QList<QDBusObjectPath>> aps = w.call("GetAllAccessPoints");
    QDBusObjectPath apPath;
    if (aps.isValid()) {
        for (const QDBusObjectPath &ap : aps.value()) {
            if (QString::fromUtf8(prop(ap.path(), AP_IFACE, "Ssid").toByteArray()) == ssid) {
                apPath = ap;
                break;
            }
        }
    }
    if (apPath.path().isEmpty()) {
        fail(QStringLiteral("Network not visible: %1").arg(ssid));
        return;
    }

    // Reuse a saved profile when NetworkManager already has one, so a known
    // network does not need its password typed again.
    QDBusObjectPath saved;
    {
        QDBusInterface s(NM_SERVICE, SETTINGS_PATH, SETTINGS_IFACE,
                         QDBusConnection::systemBus());
        s.setTimeout(5000);
        QDBusReply<QList<QDBusObjectPath>> conns = s.call("ListConnections");
        if (conns.isValid()) {
            for (const QDBusObjectPath &c : conns.value()) {
                QDBusInterface ci(NM_SERVICE, c.path(),
                                  "org.freedesktop.NetworkManager.Settings.Connection",
                                  QDBusConnection::systemBus());
                ci.setTimeout(5000);
                QDBusReply<QMap<QString, QVariantMap>> cfg = ci.call("GetSettings");
                if (cfg.isValid() && cfg.value().value("connection").value("id").toString() == ssid) {
                    saved = c;
                    break;
                }
            }
        }
    }

    QDBusInterface nm(NM_SERVICE, NM_PATH, NM_IFACE, QDBusConnection::systemBus());
    nm.setTimeout(20000);

    QDBusMessage reply;
    if (!saved.path().isEmpty()) {
        reply = nm.call("ActivateConnection", QVariant::fromValue(saved),
                        QVariant::fromValue(m_devicePath), QVariant::fromValue(apPath));
    } else {
        QMap<QString, QVariantMap> settings;
        QVariantMap conn;
        conn["type"] = "802-11-wireless";
        conn["id"] = ssid;
        conn["autoconnect"] = true;
        settings["connection"] = conn;

        QVariantMap wireless;
        wireless["ssid"] = ssid.toUtf8();
        settings["802-11-wireless"] = wireless;

        if (!passphrase.isEmpty()) {
            QVariantMap sec;
            sec["key-mgmt"] = "wpa-psk";
            sec["psk"] = passphrase;
            settings["802-11-wireless-security"] = sec;
        }

        QVariantMap v4; v4["method"] = "auto"; settings["ipv4"] = v4;
        QVariantMap v6; v6["method"] = "auto"; settings["ipv6"] = v6;

        reply = nm.call("AddAndActivateConnection", QVariant::fromValue(settings),
                        QVariant::fromValue(m_devicePath), QVariant::fromValue(apPath));
    }

    if (reply.type() == QDBusMessage::ErrorMessage) {
        const QString msg = reply.errorMessage();
        // NM's wording for a bad passphrase is opaque; say the useful thing.
        fail(msg.contains("secret", Qt::CaseInsensitive) || msg.contains("key", Qt::CaseInsensitive)
                 ? QStringLiteral("Wrong password, or the network refused the connection.")
                 : msg);
        return;
    }

    QTimer::singleShot(2500, this, [this] {
        setBusy(false);
        refresh();
    });
}

void NetworkService::disconnect()
{
    if (m_devicePath.path().isEmpty())
        return;
    QDBusInterface d(NM_SERVICE, m_devicePath.path(), DEV_IFACE,
                     QDBusConnection::systemBus());
    d.setTimeout(5000);
    d.call("Disconnect");
    refresh();
}

void NetworkService::setEnabled(bool on)
{
    QDBusInterface props(NM_SERVICE, NM_PATH, "org.freedesktop.DBus.Properties",
                         QDBusConnection::systemBus());
    props.setTimeout(5000);
    props.call("Set", QString(NM_IFACE), QStringLiteral("WirelessEnabled"),
               QVariant::fromValue(QDBusVariant(on)));
    QTimer::singleShot(800, this, &NetworkService::refresh);
}
