#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class BluetoothAgent;

/*
 * Bluetooth through BlueZ, over QtDBus.
 *
 * The Qt port shipped without this: the shell had a Bluetooth row that could
 * only ever say "NO ADAPTER", because nothing was reading org.bluez. This is
 * the BlueZ side of the Electron bridge, rewritten against QtDBus.
 *
 * BlueZ exposes everything through ObjectManager under /org/bluez: adapters
 * are org.bluez.Adapter1, devices org.bluez.Device1. There are no per-object
 * lists to walk — one GetManagedObjects call returns the whole tree.
 *
 * Two hard-won details from the Electron build are preserved:
 *
 *  - Check /sys/class/bluetooth before touching D-Bus. With no radio present
 *    BlueZ does not reject the call, it simply never answers, so the only
 *    thing that fired was the timeout and the panel showed a red ERROR for
 *    what is really just a machine without Bluetooth.
 *
 *  - Every call carries a short timeout. A hung bus call must surface as an
 *    error, never as a frozen panel.
 */
class BluetoothService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool present READ present NOTIFY changed)
    Q_PROPERTY(bool powered READ powered NOTIFY changed)
    Q_PROPERTY(bool discovering READ discovering NOTIFY changed)
    Q_PROPERTY(QString adapterName READ adapterName NOTIFY changed)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY changed)
    Q_PROPERTY(QString lastError READ lastError NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    /* Which device the outstanding call is for, and what it is doing.
     *
     * A single global `busy` flag disabled every button on every row at once,
     * so while one headset was pairing nothing else could be touched — and a
     * call that never came back left the whole panel dead. The panel now only
     * greys the row that is actually working. */
    Q_PROPERTY(QString busyPath READ busyPath NOTIFY busyChanged)
    Q_PROPERTY(QString busyAction READ busyAction NOTIFY busyChanged)
    /* A pairing request waiting on the operator. Empty when there is none. */
    Q_PROPERTY(QString pendingPath READ pendingPath NOTIFY pendingChanged)
    Q_PROPERTY(QString pendingCode READ pendingCode NOTIFY pendingChanged)
    Q_PROPERTY(bool pendingNeedsAnswer READ pendingNeedsAnswer NOTIFY pendingChanged)
    /* The device wants a code typed in rather than confirmed — the label on an
       older keyboard or car stereo. `pendingInputNumeric` is true when BlueZ
       will only take digits. */
    Q_PROPERTY(bool pendingNeedsInput READ pendingNeedsInput NOTIFY pendingChanged)
    Q_PROPERTY(bool pendingInputNumeric READ pendingInputNumeric NOTIFY pendingChanged)

public:
    explicit BluetoothService(QObject *parent = nullptr);

    bool present() const { return m_present; }
    bool powered() const { return m_powered; }
    bool discovering() const { return m_discovering; }
    QString adapterName() const { return m_adapterName; }
    QVariantList devices() const { return m_devices; }
    QString lastError() const { return m_lastError; }
    bool busy() const { return m_busy; }
    QString busyPath() const { return m_busyPath; }
    QString busyAction() const { return m_busyAction; }
    QString pendingPath() const { return m_pendingPath; }
    QString pendingCode() const { return m_pendingCode; }
    bool pendingNeedsAnswer() const { return m_pendingNeedsAnswer; }
    bool pendingNeedsInput() const { return m_pendingNeedsInput; }
    bool pendingInputNumeric() const { return m_pendingInputNumeric; }

    /** Answer an outstanding pairing confirmation. */
    Q_INVOKABLE void confirmPairing(bool accept);
    /** Answer one that wants a code typed in. Empty text rejects it. */
    Q_INVOKABLE void submitPairingCode(const QString &text);

    Q_INVOKABLE void setPowered(bool on);
    Q_INVOKABLE void startDiscovery();
    Q_INVOKABLE void stopDiscovery();
    /** Pair, trust, then connect — the order BlueZ needs for audio devices. */
    Q_INVOKABLE void pair(const QString &path);
    /* One action for "use this device", whatever state it is in.
     *
     * The panel used to offer PAIR on a new device and CONNECT on a paired
     * one, which meant a device found by a scan had to be paired, watched
     * until the row changed, and then connected in a second click — and if
     * the pair succeeded but the connect was never pressed, the headset sat
     * there paired and silent. Nobody wants to pair a device; they want to use
     * it. This pairs when it must, trusts, and connects. */
    Q_INVOKABLE void connectDevice(const QString &path);
    Q_INVOKABLE void disconnectDevice(const QString &path);
    /** Mark a device as trusted, so it may reconnect without being authorised. */
    Q_INVOKABLE void setTrusted(const QString &path, bool trusted);
    /** Forget: BlueZ drops the device and its keys from the adapter. */
    Q_INVOKABLE void forget(const QString &path);


    /* Errors are read-only to QML deliberately — nothing outside should be
       able to invent one — but they do need clearing once shown, and
       assigning to a read-only property fails silently at runtime. It had
       been failing since the Wi-Fi panel first tried it. */
    Q_INVOKABLE void clearError();

signals:
    void changed();
    void busyChanged();
    void pendingChanged();

private slots:
    void refresh();

private:
    /* True when the kernel has a Bluetooth class at all. Cheap, and it is what
       keeps a machine with no radio from reporting an error. */
    static bool radioPresent();

    bool setAdapterProp(const QString &prop, const QVariant &value);
    void callDevice(const QString &path, const QString &method, int timeoutMs);
    void setBusy(bool b, const QString &path = QString(),
                 const QString &action = QString());
    void fail(const QString &why);
    /** Is this device known to BlueZ as paired right now? */
    bool isPaired(const QString &path) const;
    /* Finish what connectDevice() started: trust, connect, report. Separate
       because pairing arrives asynchronously and this is the continuation. */
    void trustAndConnect(const QString &path);

    /* BlueZ's error names are accurate and useless to read. This turns the
       handful that actually happen into something that names the cause. */
    static QString explain(const QString &name, const QString &message);

    bool m_present = false;
    bool m_powered = false;
    bool m_discovering = false;
    bool m_busy = false;
    QString m_busyPath;
    QString m_busyAction;
    QString m_adapterPath;
    QString m_adapterName;
    QString m_lastError;
    QVariantList m_devices;

    BluetoothAgent *m_agent = nullptr;
    QString m_pendingPath;
    QString m_pendingCode;
    bool m_pendingNeedsAnswer = false;
    bool m_pendingNeedsInput = false;
    bool m_pendingInputNumeric = false;

    QTimer m_timer;
};
