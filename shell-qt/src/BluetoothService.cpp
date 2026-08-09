#include "BluetoothService.h"
#include "BluetoothAgent.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusMetaType>
#include <QDBusArgument>
#include <QDBusObjectPath>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>

namespace {

constexpr auto BLUEZ = "org.bluez";
constexpr auto ADAPTER_IFACE = "org.bluez.Adapter1";
constexpr auto DEVICE_IFACE = "org.bluez.Device1";
constexpr auto PROPS_IFACE = "org.freedesktop.DBus.Properties";
constexpr auto OM_IFACE = "org.freedesktop.DBus.ObjectManager";

// BlueZ's own type for GetManagedObjects.
using ManagedObjects = QMap<QDBusObjectPath, QMap<QString, QVariantMap>>;

constexpr int CALL_TIMEOUT_MS = 5000;
/* Pairing waits on the other device's user, not on the bus. Thirty seconds is
   roughly how long a headset stays in pairing mode. */
constexpr int PAIR_TIMEOUT_MS = 30000;

ManagedObjects managedObjects(bool *ok)
{
    QDBusInterface om(BLUEZ, "/", OM_IFACE, QDBusConnection::systemBus());
    om.setTimeout(CALL_TIMEOUT_MS);
    QDBusReply<ManagedObjects> reply = om.call("GetManagedObjects");
    if (ok)
        *ok = reply.isValid();
    return reply.isValid() ? reply.value() : ManagedObjects();
}

/* Connected first, then paired, then alphabetical.
 *
 * Deliberately NOT by signal strength. RSSI moves by several dBm every few
 * seconds while discovery is running, so sorting on it reordered the list on
 * every refresh — you would reach for a device and it had already swapped
 * places with its neighbour. Signal is still shown; it just does not decide
 * where a row lives. */
bool byUsefulness(const QVariant &a, const QVariant &b)
{
    const QVariantMap x = a.toMap();
    const QVariantMap y = b.toMap();
    if (x["connected"].toBool() != y["connected"].toBool())
        return x["connected"].toBool();
    if (x["paired"].toBool() != y["paired"].toBool())
        return x["paired"].toBool();
    const int byName = x["name"].toString().localeAwareCompare(y["name"].toString());
    if (byName != 0)
        return byName < 0;
    // Address as the tie-break: two devices can share a name, and the order
    // has to be the same on every refresh or the list still shuffles.
    return x["address"].toString() < y["address"].toString();
}

/* Whether a refresh is worth telling the interface about.
 *
 * Assigning a new list to a ListView's model destroys and rebuilds every
 * delegate. Doing that every four seconds because a signal reading drifted by
 * 2 dBm made the list unusable: any row you were about to click could be
 * rebuilt out from under the press. */
bool meaningfullyDifferent(const QVariantList &a, const QVariantList &b)
{
    if (a.size() != b.size())
        return true;
    for (int i = 0; i < a.size(); ++i) {
        const QVariantMap x = a[i].toMap();
        const QVariantMap y = b[i].toMap();
        if (x["path"] != y["path"] || x["name"] != y["name"]
            || x["paired"] != y["paired"] || x["connected"] != y["connected"]
            || x["trusted"] != y["trusted"]) {
            return true;
        }
        // Signal only counts as news when it actually moved.
        const int rx = x["rssi"].isNull() ? -999 : x["rssi"].toInt();
        const int ry = y["rssi"].isNull() ? -999 : y["rssi"].toInt();
        if (qAbs(rx - ry) >= 10)
            return true;
    }
    return false;
}

} // namespace

BluetoothService::BluetoothService(QObject *parent)
    : QObject(parent)
{
    qDBusRegisterMetaType<QMap<QString, QVariantMap>>();
    qDBusRegisterMetaType<ManagedObjects>();

    /* Registered up front, not on first pair: BlueZ needs an agent in place
       before a device asks anything, and registering takes one bus call. */
    m_agent = new BluetoothAgent(this);
    connect(m_agent, &BluetoothAgent::confirmationRequested, this,
            [this](const QString &path, const QString &code) {
        m_pendingPath = path;
        m_pendingCode = code;
        m_pendingNeedsAnswer = true;
        emit pendingChanged();
    });
    connect(m_agent, &BluetoothAgent::displayRequested, this,
            [this](const QString &path, const QString &code) {
        // Nothing to answer — this is a code to read off and type elsewhere.
        m_pendingPath = path;
        m_pendingCode = code;
        m_pendingNeedsAnswer = false;
        emit pendingChanged();
    });
    connect(m_agent, &BluetoothAgent::requestCleared, this, [this] {
        m_pendingPath.clear();
        m_pendingCode.clear();
        m_pendingNeedsAnswer = false;
        emit pendingChanged();
    });

    refresh();
    connect(&m_timer, &QTimer::timeout, this, &BluetoothService::refresh);
    // Faster while scanning: discovery results are the only thing that moves.
    m_timer.start(4000);
}

bool BluetoothService::radioPresent()
{
    return !QDir("/sys/class/bluetooth").entryList(QDir::NoDotAndDotDot | QDir::AllEntries).isEmpty();
}

void BluetoothService::setBusy(bool b)
{
    if (m_busy == b)
        return;
    m_busy = b;
    emit busyChanged();
}

void BluetoothService::fail(const QString &why)
{
    m_lastError = why;
    setBusy(false);
    emit changed();
}

void BluetoothService::refresh()
{
    if (!radioPresent()) {
        /* No radio is a fact about the machine, not a failure. Reported as
           "no adapter" in grey rather than a red error. */
        m_present = false;
        m_powered = false;
        m_discovering = false;
        m_adapterPath.clear();
        m_adapterName.clear();
        m_devices.clear();
        m_lastError.clear();
        emit changed();
        return;
    }

    bool ok = false;
    const ManagedObjects objects = managedObjects(&ok);
    if (!ok) {
        // A radio the kernel sees but bluetoothd does not is worth saying aloud.
        m_present = false;
        m_devices.clear();
        fail(QStringLiteral("bluez not responding"));
        return;
    }

    const bool wasPowered = m_powered;
    const bool wasDiscovering = m_discovering;
    const bool wasPresent = m_present;

    QString adapterPath;
    QVariantMap adapter;
    QVariantList found;

    for (auto it = objects.constBegin(); it != objects.constEnd(); ++it) {
        const QMap<QString, QVariantMap> &ifaces = it.value();

        if (adapterPath.isEmpty() && ifaces.contains(ADAPTER_IFACE)) {
            adapterPath = it.key().path();
            adapter = ifaces.value(ADAPTER_IFACE);
        }

        if (!ifaces.contains(DEVICE_IFACE))
            continue;

        const QVariantMap d = ifaces.value(DEVICE_IFACE);
        QVariantMap row;
        row["path"] = it.key().path();
        row["address"] = d.value("Address").toString();
        // Name is absent until the device has been queried; Alias always exists.
        row["name"] = d.contains("Name") ? d.value("Name").toString()
                    : d.contains("Alias") ? d.value("Alias").toString()
                                          : d.value("Address").toString();
        row["paired"] = d.value("Paired", false).toBool();
        row["trusted"] = d.value("Trusted", false).toBool();
        row["connected"] = d.value("Connected", false).toBool();
        row["icon"] = d.value("Icon").toString();
        // RSSI only exists while the device is in range during discovery.
        row["rssi"] = d.contains("RSSI") ? QVariant(d.value("RSSI").toInt()) : QVariant();
        found.append(row);
    }

    std::sort(found.begin(), found.end(), byUsefulness);

    m_present = !adapterPath.isEmpty();
    m_adapterPath = adapterPath;
    m_adapterName = adapter.value("Alias", adapter.value("Name")).toString();
    m_powered = adapter.value("Powered", false).toBool();
    m_discovering = adapter.value("Discovering", false).toBool();
    const bool listChanged = meaningfullyDifferent(m_devices, found);
    m_devices = found;
    if (m_present)
        m_lastError.clear();

    /* Adapter state always goes out; the device list only when it really
       moved, so the view is not rebuilt under the operator's hands. */
    if (listChanged || wasPowered != m_powered || wasDiscovering != m_discovering
        || wasPresent != m_present)
        emit changed();
}

bool BluetoothService::setAdapterProp(const QString &prop, const QVariant &value)
{
    if (m_adapterPath.isEmpty()) {
        fail(QStringLiteral("no bluetooth adapter"));
        return false;
    }
    QDBusInterface props(BLUEZ, m_adapterPath, PROPS_IFACE, QDBusConnection::systemBus());
    props.setTimeout(CALL_TIMEOUT_MS);
    const QDBusMessage reply = props.call("Set", ADAPTER_IFACE, prop,
                                          QVariant::fromValue(QDBusVariant(value)));
    if (reply.type() == QDBusMessage::ErrorMessage) {
        fail(reply.errorMessage());
        return false;
    }
    return true;
}

void BluetoothService::confirmPairing(bool accept)
{
    if (m_agent)
        m_agent->resolve(accept);
}

void BluetoothService::setPowered(bool on)
{
    setBusy(true);
    if (setAdapterProp(QStringLiteral("Powered"), on))
        setBusy(false);
    refresh();
}

void BluetoothService::startDiscovery()
{
    if (m_adapterPath.isEmpty()) {
        fail(QStringLiteral("no bluetooth adapter"));
        return;
    }
    if (m_discovering)
        return;
    // Discovery on an unpowered adapter fails; power it first.
    if (!m_powered && !setAdapterProp(QStringLiteral("Powered"), true))
        return;

    QDBusInterface a(BLUEZ, m_adapterPath, ADAPTER_IFACE, QDBusConnection::systemBus());
    a.setTimeout(CALL_TIMEOUT_MS);
    const QDBusMessage reply = a.call("StartDiscovery");
    if (reply.type() == QDBusMessage::ErrorMessage) {
        fail(reply.errorMessage());
        return;
    }
    refresh();
}

void BluetoothService::stopDiscovery()
{
    if (m_adapterPath.isEmpty() || !m_discovering)
        return;
    QDBusInterface a(BLUEZ, m_adapterPath, ADAPTER_IFACE, QDBusConnection::systemBus());
    a.setTimeout(CALL_TIMEOUT_MS);
    // Another client may still hold discovery open; that is not our error.
    a.call("StopDiscovery");
    refresh();
}

/* Asynchronous, and it has to be.
 *
 * Pairing waits on a person pressing a button on a headset — up to thirty
 * seconds. A blocking QDBusInterface::call() holds the GUI thread for all of
 * it, so the panel would show "PAIRING…" and then not repaint at all: the
 * spinner frozen, the clock stopped, clicks ignored. Every call that can take
 * longer than a bus round trip goes through a pending-call watcher instead. */
void BluetoothService::callDevice(const QString &path, const QString &method, int timeoutMs)
{
    setBusy(true);

    QDBusInterface d(BLUEZ, path, DEVICE_IFACE, QDBusConnection::systemBus());
    d.setTimeout(timeoutMs);
    auto *watcher = new QDBusPendingCallWatcher(d.asyncCall(method), this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this](QDBusPendingCallWatcher *w) {
        const QDBusPendingReply<> reply = *w;
        if (reply.isError())
            fail(reply.error().message());
        else
            setBusy(false);
        refresh();
        w->deleteLater();
    });
}

void BluetoothService::pair(const QString &path)
{
    setBusy(true);

    QDBusInterface d(BLUEZ, path, DEVICE_IFACE, QDBusConnection::systemBus());
    d.setTimeout(PAIR_TIMEOUT_MS);
    auto *watcher = new QDBusPendingCallWatcher(d.asyncCall("Pair"), this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, path](QDBusPendingCallWatcher *w) {
        const QDBusPendingReply<> reply = *w;
        w->deleteLater();
        if (reply.isError()) {
            fail(reply.error().message());
            return;
        }

        /* Trust before connecting, or the device has to be re-authorised on
           every reconnect — the reason a paired headset keeps going silent. */
        QDBusInterface props(BLUEZ, path, PROPS_IFACE, QDBusConnection::systemBus());
        props.setTimeout(CALL_TIMEOUT_MS);
        props.asyncCall("Set", DEVICE_IFACE, "Trusted",
                        QVariant::fromValue(QDBusVariant(true)));

        setBusy(false);
        connectDevice(path);
    });
}

void BluetoothService::connectDevice(const QString &path)
{
    // Connecting negotiates profiles with the device; slower than a bus call.
    callDevice(path, QStringLiteral("Connect"), 20000);
}

void BluetoothService::disconnectDevice(const QString &path)
{
    callDevice(path, QStringLiteral("Disconnect"), CALL_TIMEOUT_MS);
}

void BluetoothService::forget(const QString &path)
{
    if (m_adapterPath.isEmpty()) {
        fail(QStringLiteral("no bluetooth adapter"));
        return;
    }
    QDBusInterface a(BLUEZ, m_adapterPath, ADAPTER_IFACE, QDBusConnection::systemBus());
    a.setTimeout(CALL_TIMEOUT_MS);
    const QDBusMessage reply = a.call("RemoveDevice", QVariant::fromValue(QDBusObjectPath(path)));
    if (reply.type() == QDBusMessage::ErrorMessage) {
        fail(reply.errorMessage());
        return;
    }
    refresh();
}

void BluetoothService::clearError()
{
    if (m_lastError.isEmpty())
        return;
    m_lastError.clear();
    emit changed();
}
