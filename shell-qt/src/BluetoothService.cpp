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

/* Sort so the list reads the way an operator scans it: what is connected,
   then what is known, then whatever is loudest nearby. */
bool byUsefulness(const QVariant &a, const QVariant &b)
{
    const QVariantMap x = a.toMap();
    const QVariantMap y = b.toMap();
    if (x["connected"].toBool() != y["connected"].toBool())
        return x["connected"].toBool();
    if (x["paired"].toBool() != y["paired"].toBool())
        return x["paired"].toBool();
    // Absent RSSI means out of range, so it sorts last rather than as zero.
    const int rx = x["rssi"].isNull() ? -999 : x["rssi"].toInt();
    const int ry = y["rssi"].isNull() ? -999 : y["rssi"].toInt();
    return rx > ry;
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
    connect(m_agent, &BluetoothAgent::inputRequested, this,
            [this](const QString &path, bool numeric) {
        m_pendingPath = path;
        m_pendingCode.clear();
        m_pendingNeedsAnswer = false;
        m_pendingNeedsInput = true;
        m_pendingInputNumeric = numeric;
        emit pendingChanged();
    });
    connect(m_agent, &BluetoothAgent::requestCleared, this, [this] {
        m_pendingPath.clear();
        m_pendingCode.clear();
        m_pendingNeedsAnswer = false;
        m_pendingNeedsInput = false;
        m_pendingInputNumeric = false;
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

void BluetoothService::setBusy(bool b, const QString &path, const QString &action)
{
    if (m_busy == b && m_busyPath == path && m_busyAction == action)
        return;
    m_busy = b;
    m_busyPath = b ? path : QString();
    m_busyAction = b ? action : QString();
    emit busyChanged();
}

void BluetoothService::fail(const QString &why)
{
    m_lastError = why;
    setBusy(false);
    emit changed();
}

/* What BlueZ says, and what it means.
 *
 * These are the failures that actually turn up on a laptop, and every one of
 * them arrives as a D-Bus error name that tells the operator nothing. A device
 * that will not connect because its audio profile is not available is a
 * different problem from one that is out of range, and the fix is different
 * too — so the panel says which. */
QString BluetoothService::explain(const QString &name, const QString &message)
{
    const QString n = name.section(QLatin1Char('.'), -1);
    const QString m = message.toLower();

    if (m.contains(QLatin1String("br-connection-profile-unavailable"))
        || m.contains(QLatin1String("profile unavailable")))
        return QStringLiteral("Paired, but nothing on this system can use it. "
                              "For headphones that means the Bluetooth audio "
                              "profiles are missing — install libspa-0.2-bluetooth "
                              "and restart PipeWire.");
    if (m.contains(QLatin1String("page-timeout"))
        || m.contains(QLatin1String("br-connection-page-timeout")))
        return QStringLiteral("The device did not answer. It is out of range, "
                              "asleep, or connected to something else.");
    if (m.contains(QLatin1String("connection refused"))
        || m.contains(QLatin1String("busy")))
        return QStringLiteral("The device refused the connection — it is probably "
                              "already paired with another machine.");
    if (n == QLatin1String("AuthenticationCanceled")
        || n == QLatin1String("AuthenticationFailed")
        || n == QLatin1String("AuthenticationRejected"))
        return QStringLiteral("Pairing was rejected. Put the device back into "
                              "pairing mode and try again.");
    if (n == QLatin1String("AuthenticationTimeout"))
        return QStringLiteral("Pairing timed out. Most devices only stay in "
                              "pairing mode for about a minute.");
    if (n == QLatin1String("AlreadyExists") || n == QLatin1String("AlreadyConnected"))
        return QString();   // not a failure worth a red banner
    if (n == QLatin1String("NotReady"))
        return QStringLiteral("The adapter is not ready. Turn the radio off and "
                              "on again.");
    return message;
}

bool BluetoothService::isPaired(const QString &path) const
{
    for (const QVariant &d : m_devices) {
        const QVariantMap row = d.toMap();
        if (row.value("path").toString() == path)
            return row.value("paired").toBool();
    }
    return false;
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
    m_devices = found;
    if (m_present)
        m_lastError.clear();

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

void BluetoothService::submitPairingCode(const QString &text)
{
    if (m_agent)
        m_agent->submitInput(text);
}

void BluetoothService::setPowered(bool on)
{
    setBusy(true, m_adapterPath, QStringLiteral("power"));
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
    setBusy(true, path, method.toLower());

    QDBusInterface d(BLUEZ, path, DEVICE_IFACE, QDBusConnection::systemBus());
    d.setTimeout(timeoutMs);
    auto *watcher = new QDBusPendingCallWatcher(d.asyncCall(method), this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this](QDBusPendingCallWatcher *w) {
        const QDBusPendingReply<> reply = *w;
        if (reply.isError()) {
            const QString why = explain(reply.error().name(), reply.error().message());
            if (why.isEmpty())
                setBusy(false);
            else
                fail(why);
        } else {
            setBusy(false);
        }
        refresh();
        w->deleteLater();
    });
}

void BluetoothService::pair(const QString &path)
{
    setBusy(true, path, QStringLiteral("pair"));

    QDBusInterface d(BLUEZ, path, DEVICE_IFACE, QDBusConnection::systemBus());
    d.setTimeout(PAIR_TIMEOUT_MS);
    auto *watcher = new QDBusPendingCallWatcher(d.asyncCall("Pair"), this);

    connect(watcher, &QDBusPendingCallWatcher::finished, this,
            [this, path](QDBusPendingCallWatcher *w) {
        const QDBusPendingReply<> reply = *w;
        w->deleteLater();
        if (reply.isError()) {
            const QString why = explain(reply.error().name(), reply.error().message());
            // AlreadyExists means it was paired all along: carry on connecting.
            if (!why.isEmpty()) {
                fail(why);
                return;
            }
        }
        trustAndConnect(path);
    });
}

void BluetoothService::trustAndConnect(const QString &path)
{
    /* Trust before connecting, or the device has to be re-authorised on
       every reconnect — the reason a paired headset keeps going silent. */
    setTrusted(path, true);
    // Connecting negotiates profiles with the device; slower than a bus call.
    callDevice(path, QStringLiteral("Connect"), 20000);
}

void BluetoothService::setTrusted(const QString &path, bool trusted)
{
    QDBusInterface props(BLUEZ, path, PROPS_IFACE, QDBusConnection::systemBus());
    props.setTimeout(CALL_TIMEOUT_MS);
    props.asyncCall("Set", DEVICE_IFACE, "Trusted",
                    QVariant::fromValue(QDBusVariant(trusted)));
}

void BluetoothService::connectDevice(const QString &path)
{
    /* An unpaired device gets paired first.
     *
     * BlueZ's Connect() on a device it has never paired with fails with
     * "Device not paired" or, worse, half-succeeds and drops the link a second
     * later. The panel used to leave that second step to the operator: a
     * device found by a scan showed PAIR, and only after the list refreshed
     * did a CONNECT appear. Anything that went wrong between those two clicks
     * looked like a device that simply could not be connected to. */
    if (!isPaired(path)) {
        /* Discovery holds the radio and makes the connection attempt itself
           slower and less reliable; BlueZ documents stopping it before
           pairing. */
        if (m_discovering)
            stopDiscovery();
        pair(path);
        return;
    }
    trustAndConnect(path);
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
        const QString why = explain(reply.errorName(), reply.errorMessage());
        if (!why.isEmpty()) {
            fail(why);
            return;
        }
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
