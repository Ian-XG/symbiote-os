#include "NetworkService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QDBusArgument>
#include <QFile>

namespace {

constexpr auto NM_SERVICE = "org.freedesktop.NetworkManager";
constexpr auto NM_PATH = "/org/freedesktop/NetworkManager";
constexpr auto NM_IFACE = "org.freedesktop.NetworkManager";
constexpr auto DEV_IFACE = "org.freedesktop.NetworkManager.Device";
constexpr auto WIFI_IFACE = "org.freedesktop.NetworkManager.Device.Wireless";
constexpr auto AP_IFACE = "org.freedesktop.NetworkManager.AccessPoint";
constexpr auto SETTINGS_PATH = "/org/freedesktop/NetworkManager/Settings";
constexpr auto SETTINGS_IFACE = "org.freedesktop.NetworkManager.Settings";
constexpr auto CONN_IFACE = "org.freedesktop.NetworkManager.Settings.Connection";

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

/* The SSID a saved profile is for.
 *
 * Read from 802-11-wireless.ssid, which is the network's actual name in bytes,
 * not from connection.id. The id is a label a human can rename — NetworkManager
 * itself writes "MyNet 1" when a second profile appears — so matching on it
 * meant a saved network could stop being recognised as saved, and the panel
 * asked for the password of a network whose password it already had.
 */
QString profileSsid(const QMap<QString, QVariantMap> &cfg)
{
    const QVariant raw = cfg.value(QStringLiteral("802-11-wireless"))
                            .value(QStringLiteral("ssid"));
    if (raw.isValid()) {
        const QByteArray bytes = raw.typeId() == QMetaType::QByteArray
                                     ? raw.toByteArray()
                                     : raw.toString().toUtf8();
        if (!bytes.isEmpty())
            return QString::fromUtf8(bytes);
    }
    // A profile with no wireless section is not a Wi-Fi profile at all.
    return QString();
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

void NetworkService::setBusy(bool b, const QString &ssid)
{
    if (m_busy == b && m_busySsid == ssid)
        return;
    m_busy = b;
    m_busySsid = b ? ssid : QString();
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

QList<QDBusObjectPath> NetworkService::savedProfiles(const QString &ssid) const
{
    QList<QDBusObjectPath> out;
    QDBusInterface s(NM_SERVICE, SETTINGS_PATH, SETTINGS_IFACE,
                     QDBusConnection::systemBus());
    s.setTimeout(5000);
    QDBusReply<QList<QDBusObjectPath>> conns = s.call("ListConnections");
    if (!conns.isValid())
        return out;

    for (const QDBusObjectPath &c : conns.value()) {
        QDBusInterface ci(NM_SERVICE, c.path(), CONN_IFACE, QDBusConnection::systemBus());
        ci.setTimeout(5000);
        QDBusReply<QMap<QString, QVariantMap>> cfg = ci.call("GetSettings");
        if (cfg.isValid() && profileSsid(cfg.value()) == ssid)
            out.append(c);
    }
    return out;
}

void NetworkService::reloadSaved()
{
    /* Two blocking bus calls per stored profile, so not on every poll.
     *
     * The network list refreshes every six seconds; the set of saved profiles
     * changes when somebody joins or forgets a network, which this service is
     * told about directly. Rescanning it thirty times a minute would spend
     * real time on the bus to learn nothing — and each of those calls carries
     * a five-second timeout, so a wedged NetworkManager would stall the
     * interface rather than the poll. */
    m_savedAge = 0;

    QSet<QString> found;

    QDBusInterface s(NM_SERVICE, SETTINGS_PATH, SETTINGS_IFACE,
                     QDBusConnection::systemBus());
    s.setTimeout(5000);
    QDBusReply<QList<QDBusObjectPath>> conns = s.call("ListConnections");
    if (conns.isValid()) {
        for (const QDBusObjectPath &c : conns.value()) {
            QDBusInterface ci(NM_SERVICE, c.path(), CONN_IFACE, QDBusConnection::systemBus());
            ci.setTimeout(5000);
            QDBusReply<QMap<QString, QVariantMap>> cfg = ci.call("GetSettings");
            if (!cfg.isValid())
                continue;
            const QString ssid = profileSsid(cfg.value());
            if (!ssid.isEmpty())
                found.insert(ssid);
        }
    }

    m_saved = found;
}

bool NetworkService::isSaved(const QString &ssid) const
{
    return m_saved.contains(ssid);
}

bool NetworkService::profilesPersist() const
{
    /* NetworkManager writes profiles to /etc/NetworkManager/system-connections.
       On a live boot that directory is part of the union overlay, and unless a
       persistence volume is mounted the upper layer is RAM. */
    QFile mounts(QStringLiteral("/proc/mounts"));
    if (!mounts.open(QIODevice::ReadOnly | QIODevice::Text))
        return true;   // not a live boot we can reason about; assume a real disk
    const QString all = QString::fromUtf8(mounts.readAll());
    if (!all.contains(QLatin1String("/lib/live/mount")))
        return true;   // installed system
    return all.contains(QLatin1String("persistence"));
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

    // Roughly every half minute, or straight after anything that changes it.
    if (m_savedAge++ >= 5)
        reloadSaved();

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
                /* The whole point of the rework: the row knows whether this
                   network is already known, so it can offer JOIN rather than a
                   password field for a password NetworkManager already has. */
                n["saved"] = m_saved.contains(ssid);

                if (!best.contains(ssid) || best[ssid]["strength"].toInt() < strength)
                    best[ssid] = n;
            }
        }

        for (const auto &n : std::as_const(best))
            list.append(n);
        std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
            const QVariantMap x = a.toMap();
            const QVariantMap y = b.toMap();
            // Connected first, then known networks, then by signal.
            if (x["connected"].toBool() != y["connected"].toBool())
                return x["connected"].toBool();
            if (x["saved"].toBool() != y["saved"].toBool())
                return x["saved"].toBool();
            return x["strength"].toInt() > y["strength"].toInt();
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

void NetworkService::restoreAutoconnect()
{
    if (m_devicePath.path().isEmpty())
        return;
    QDBusInterface props(NM_SERVICE, m_devicePath.path(),
                         "org.freedesktop.DBus.Properties", QDBusConnection::systemBus());
    props.setTimeout(5000);
    props.asyncCall("Set", QString(DEV_IFACE), QStringLiteral("Autoconnect"),
                    QVariant::fromValue(QDBusVariant(true)));
}

void NetworkService::connectTo(const QString &ssid, const QString &passphrase)
{
    if (m_devicePath.path().isEmpty()) {
        fail(QStringLiteral("No wireless device"));
        return;
    }
    setBusy(true, ssid);

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

    /* A saved profile is reused whenever one exists and no new passphrase was
       typed. Typing one means "that saved secret is wrong" — so the profile is
       rewritten rather than reactivated with the key that just failed. */
    const QList<QDBusObjectPath> saved = savedProfiles(ssid);
    QDBusObjectPath reuse;
    if (!saved.isEmpty() && passphrase.isEmpty())
        reuse = saved.first();

    // A device left blocked by an earlier manual disconnect refuses to
    // activate anything at all, with an error that names neither cause.
    restoreAutoconnect();

    QDBusInterface nm(NM_SERVICE, NM_PATH, NM_IFACE, QDBusConnection::systemBus());
    nm.setTimeout(20000);

    QDBusMessage reply;
    if (!reuse.path().isEmpty()) {
        reply = nm.call("ActivateConnection", QVariant::fromValue(reuse),
                        QVariant::fromValue(m_devicePath), QVariant::fromValue(apPath));
    } else {
        /* Replacing the secret of a network that is already known: drop the old
           profiles first, or NetworkManager keeps both and autoconnect may pick
           the one with the password that does not work. */
        if (!saved.isEmpty()) {
            for (const QDBusObjectPath &c : saved) {
                QDBusInterface ci(NM_SERVICE, c.path(), CONN_IFACE,
                                  QDBusConnection::systemBus());
                ci.setTimeout(5000);
                ci.call("Delete");
            }
        }

        QMap<QString, QVariantMap> settings;
        QVariantMap conn;
        conn["type"] = "802-11-wireless";
        conn["id"] = ssid;
        conn["autoconnect"] = true;
        /* Explicit, because the default is only "as high as anything else".
           A network the operator joined by hand should win over one that
           happens to be in range. */
        conn["autoconnect-priority"] = 10;
        settings["connection"] = conn;

        QVariantMap wireless;
        wireless["ssid"] = ssid.toUtf8();
        settings["802-11-wireless"] = wireless;

        if (!passphrase.isEmpty()) {
            QVariantMap sec;
            sec["key-mgmt"] = "wpa-psk";
            sec["psk"] = passphrase;
            /* 0 = store the secret in the profile. Without it NetworkManager
               may keep the key in memory only, and the network stops being
               joinable the moment the daemon restarts — which looks exactly
               like a password that was never saved. */
            sec["psk-flags"] = 0u;
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
        reloadSaved();
        refresh();
    });
}

void NetworkService::forget(const QString &ssid)
{
    const QList<QDBusObjectPath> saved = savedProfiles(ssid);
    if (saved.isEmpty())
        return;

    setBusy(true, ssid);
    for (const QDBusObjectPath &c : saved) {
        QDBusInterface ci(NM_SERVICE, c.path(), CONN_IFACE, QDBusConnection::systemBus());
        ci.setTimeout(5000);
        const QDBusMessage reply = ci.call("Delete");
        if (reply.type() == QDBusMessage::ErrorMessage) {
            fail(reply.errorMessage());
            return;
        }
    }
    setBusy(false);
    reloadSaved();
    refresh();
}

void NetworkService::disconnect()
{
    if (m_devicePath.path().isEmpty())
        return;
    QDBusInterface d(NM_SERVICE, m_devicePath.path(), DEV_IFACE,
                     QDBusConnection::systemBus());
    d.setTimeout(5000);
    d.call("Disconnect");

    /* NetworkManager blocks autoconnect on the device after a manual
       disconnect and keeps it blocked until something explicitly says
       otherwise. Left alone, a network you joined and then left never comes
       back on its own — the profile is still saved, it simply never gets
       used, which is indistinguishable from having been forgotten. */
    QTimer::singleShot(600, this, [this] {
        restoreAutoconnect();
        refresh();
    });
    refresh();
}

void NetworkService::setEnabled(bool on)
{
    QDBusInterface props(NM_SERVICE, NM_PATH, "org.freedesktop.DBus.Properties",
                         QDBusConnection::systemBus());
    props.setTimeout(5000);
    props.call("Set", QString(NM_IFACE), QStringLiteral("WirelessEnabled"),
               QVariant::fromValue(QDBusVariant(on)));
    if (on)
        QTimer::singleShot(600, this, &NetworkService::restoreAutoconnect);
    QTimer::singleShot(800, this, &NetworkService::refresh);
}

void NetworkService::clearError()
{
    if (m_lastError.isEmpty())
        return;
    m_lastError.clear();
    emit changed();
}
