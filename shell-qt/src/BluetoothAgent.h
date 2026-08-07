#pragma once

#include <QObject>
#include <QDBusContext>
#include <QDBusMessage>
#include <QDBusObjectPath>

/*
 * The BlueZ pairing agent.
 *
 * Pairing is a conversation, not a call. When something asks to pair, BlueZ
 * turns round and asks the *agent* whether to allow it — to confirm a six
 * digit code, to supply a PIN, to authorise a profile. With no agent
 * registered there is nobody to ask, so BlueZ rejects the attempt outright.
 *
 * That is why the shell could list devices and never join one: discovery is
 * unauthenticated and worked, and every Pair() call died with no agent to
 * answer for it. The Electron build had one; the Qt port shipped without.
 *
 * Registered as KeyboardDisplay, which is the honest description of this
 * machine: it has a screen to show a code on and a keyboard to type one with.
 *
 * Nothing here auto-accepts. A silent yes would let anything in range pair
 * itself while the laptop sat on a desk.
 */
class BluetoothAgent : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.bluez.Agent1")

public:
    explicit BluetoothAgent(QObject *parent = nullptr);
    ~BluetoothAgent() override;

    /** True once BlueZ has accepted us as the default agent. */
    bool registered() const { return m_registered; }

    /** Answer whatever request is outstanding. */
    void resolve(bool accept);

signals:
    /* Something needs the operator. `code` is the passkey to compare, or empty
       when the device only wants a yes. */
    void confirmationRequested(const QString &devicePath, const QString &code);
    /* A code to read off the screen and type into the other device. */
    void displayRequested(const QString &devicePath, const QString &code);
    void requestCleared();
    void registeredChanged();

public slots:
    // org.bluez.Agent1
    void Release();
    void Cancel();
    void RequestConfirmation(const QDBusObjectPath &device, uint passkey);
    void AuthorizeService(const QDBusObjectPath &device, const QString &uuid);
    void RequestAuthorization(const QDBusObjectPath &device);
    void DisplayPasskey(const QDBusObjectPath &device, uint passkey, ushort entered);
    void DisplayPinCode(const QDBusObjectPath &device, const QString &pincode);
    QString RequestPinCode(const QDBusObjectPath &device);
    uint RequestPasskey(const QDBusObjectPath &device);

private:
    /* Hold BlueZ's call open while the operator decides, then answer it. A
       plain return would accept or reject before anyone had seen the code. */
    void holdForAnswer();

    bool m_registered = false;
    bool m_pending = false;
    QDBusMessage m_pendingCall;
};
