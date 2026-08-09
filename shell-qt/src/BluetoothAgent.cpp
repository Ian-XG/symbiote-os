#include "BluetoothAgent.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>

namespace {
constexpr auto AGENT_PATH = "/org/symbiote/bluez/agent";
constexpr auto BLUEZ = "org.bluez";
/* KeyboardDisplay: this machine can show a code and type one. Claiming
   NoInputNoOutput would make BlueZ skip confirmation entirely — every pairing
   accepted in silence. */
constexpr auto CAPABILITY = "KeyboardDisplay";
}

BluetoothAgent::BluetoothAgent(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::systemBus();

    if (!bus.registerObject(QLatin1String(AGENT_PATH), this,
                            QDBusConnection::ExportAllSlots)) {
        qWarning("bluetooth: could not export the pairing agent on the bus");
        return;
    }

    QDBusInterface manager(BLUEZ, "/org/bluez", "org.bluez.AgentManager1", bus);
    manager.setTimeout(5000);

    QDBusMessage reply = manager.call("RegisterAgent",
                                      QVariant::fromValue(QDBusObjectPath(AGENT_PATH)),
                                      QString::fromLatin1(CAPABILITY));
    if (reply.type() == QDBusMessage::ErrorMessage) {
        // AlreadyExists is fine — a previous run of the shell left one behind.
        if (!reply.errorName().endsWith(QLatin1String("AlreadyExists"))) {
            qWarning("bluetooth: RegisterAgent failed: %s",
                     qPrintable(reply.errorMessage()));
            return;
        }
    }

    /* Without this BlueZ keeps whatever agent it had. bluetoothctl registers
       one on the same bus, and the last default wins. */
    reply = manager.call("RequestDefaultAgent",
                         QVariant::fromValue(QDBusObjectPath(AGENT_PATH)));
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning("bluetooth: RequestDefaultAgent failed: %s",
                 qPrintable(reply.errorMessage()));
        return;
    }

    m_registered = true;
    emit registeredChanged();
}

BluetoothAgent::~BluetoothAgent()
{
    if (m_registered) {
        QDBusInterface manager(BLUEZ, "/org/bluez", "org.bluez.AgentManager1",
                               QDBusConnection::systemBus());
        manager.setTimeout(2000);
        manager.call("UnregisterAgent", QVariant::fromValue(QDBusObjectPath(AGENT_PATH)));
    }
    QDBusConnection::systemBus().unregisterObject(QLatin1String(AGENT_PATH));
}

void BluetoothAgent::holdForAnswer()
{
    setDelayedReply(true);
    m_pendingCall = message();
    m_pending = true;
}

void BluetoothAgent::resolve(bool accept)
{
    if (!m_pending)
        return;
    m_pending = false;
    m_pendingIsInput = false;

    QDBusConnection bus = QDBusConnection::systemBus();
    if (accept) {
        bus.send(m_pendingCall.createReply());
    } else {
        bus.send(m_pendingCall.createErrorReply(
            QStringLiteral("org.bluez.Error.Rejected"),
            QStringLiteral("rejected by the operator")));
    }
    emit requestCleared();
}

void BluetoothAgent::submitInput(const QString &text)
{
    if (!m_pending || !m_pendingIsInput)
        return;

    QDBusConnection bus = QDBusConnection::systemBus();
    if (text.isEmpty()) {
        m_pending = false;
        m_pendingIsInput = false;
        bus.send(m_pendingCall.createErrorReply(
            QStringLiteral("org.bluez.Error.Rejected"),
            QStringLiteral("no code supplied")));
        emit requestCleared();
        return;
    }

    if (m_pendingIsNumeric) {
        bool ok = false;
        const uint passkey = text.toUInt(&ok);
        /* BlueZ takes a u here and rejects anything above six digits. Sending
           a malformed reply would leave the pairing hanging until it timed
           out, with nothing on screen to say why. */
        if (!ok || text.length() > 6)
            return;
        m_pending = false;
        m_pendingIsInput = false;
        bus.send(m_pendingCall.createReply(QVariant::fromValue(passkey)));
    } else {
        m_pending = false;
        m_pendingIsInput = false;
        bus.send(m_pendingCall.createReply(QVariant::fromValue(text)));
    }
    emit requestCleared();
}

void BluetoothAgent::Release()
{
    m_registered = false;
    emit registeredChanged();
}

void BluetoothAgent::Cancel()
{
    // The other end gave up. Drop the request without answering it.
    m_pending = false;
    m_pendingIsInput = false;
    emit requestCleared();
}

void BluetoothAgent::RequestConfirmation(const QDBusObjectPath &device, uint passkey)
{
    holdForAnswer();
    // Zero-padded: BlueZ passkeys are six digits and 001234 must not read as 1234.
    emit confirmationRequested(device.path(),
                               QStringLiteral("%1").arg(passkey, 6, 10, QLatin1Char('0')));
}

void BluetoothAgent::RequestAuthorization(const QDBusObjectPath &device)
{
    // No code to compare — the device is simply asking to be let in.
    holdForAnswer();
    emit confirmationRequested(device.path(), QString());
}

void BluetoothAgent::AuthorizeService(const QDBusObjectPath &device, const QString &uuid)
{
    Q_UNUSED(uuid)
    /* Asked every time a paired device connects a profile. Prompting here
       would mean confirming a headset each time it reconnects, so this is the
       one case that answers for itself — the device is already paired and
       trusted, which is the decision that mattered. */
    Q_UNUSED(device)
}

void BluetoothAgent::DisplayPasskey(const QDBusObjectPath &device, uint passkey, ushort entered)
{
    Q_UNUSED(entered)
    emit displayRequested(device.path(),
                          QStringLiteral("%1").arg(passkey, 6, 10, QLatin1Char('0')));
}

void BluetoothAgent::DisplayPinCode(const QDBusObjectPath &device, const QString &pincode)
{
    emit displayRequested(device.path(), pincode);
}

/* Legacy pairing: the device has no screen, and its PIN is printed on a label
   or fixed in its firmware. The shell used to reject these outright, because
   there was nowhere to type the code — which meant every older keyboard, car
   stereo and set of speakers was simply unpairable. There is a field now. */
QString BluetoothAgent::RequestPinCode(const QDBusObjectPath &device)
{
    holdForAnswer();
    m_pendingIsInput = true;
    m_pendingIsNumeric = false;
    emit inputRequested(device.path(), false);
    return QString();   // ignored: the reply is sent from submitInput()
}

uint BluetoothAgent::RequestPasskey(const QDBusObjectPath &device)
{
    holdForAnswer();
    m_pendingIsInput = true;
    m_pendingIsNumeric = true;
    emit inputRequested(device.path(), true);
    return 0;           // ignored: the reply is sent from submitInput()
}
