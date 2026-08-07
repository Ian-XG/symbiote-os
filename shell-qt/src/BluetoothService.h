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
    /* A pairing request waiting on the operator. Empty when there is none. */
    Q_PROPERTY(QString pendingPath READ pendingPath NOTIFY pendingChanged)
    Q_PROPERTY(QString pendingCode READ pendingCode NOTIFY pendingChanged)
    Q_PROPERTY(bool pendingNeedsAnswer READ pendingNeedsAnswer NOTIFY pendingChanged)

public:
    explicit BluetoothService(QObject *parent = nullptr);

    bool present() const { return m_present; }
    bool powered() const { return m_powered; }
    bool discovering() const { return m_discovering; }
    QString adapterName() const { return m_adapterName; }
    QVariantList devices() const { return m_devices; }
    QString lastError() const { return m_lastError; }
    bool busy() const { return m_busy; }
    QString pendingPath() const { return m_pendingPath; }
    QString pendingCode() const { return m_pendingCode; }
    bool pendingNeedsAnswer() const { return m_pendingNeedsAnswer; }

    /** Answer an outstanding pairing confirmation. */
    Q_INVOKABLE void confirmPairing(bool accept);

    Q_INVOKABLE void setPowered(bool on);
    Q_INVOKABLE void startDiscovery();
    Q_INVOKABLE void stopDiscovery();
    /** Pair, trust, then connect — the order BlueZ needs for audio devices. */
    Q_INVOKABLE void pair(const QString &path);
    Q_INVOKABLE void connectDevice(const QString &path);
    Q_INVOKABLE void disconnectDevice(const QString &path);
    /** Forget: BlueZ drops the device and its keys from the adapter. */
    Q_INVOKABLE void forget(const QString &path);

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
    void setBusy(bool b);
    void fail(const QString &why);

    bool m_present = false;
    bool m_powered = false;
    bool m_discovering = false;
    bool m_busy = false;
    QString m_adapterPath;
    QString m_adapterName;
    QString m_lastError;
    QVariantList m_devices;

    BluetoothAgent *m_agent = nullptr;
    QString m_pendingPath;
    QString m_pendingCode;
    bool m_pendingNeedsAnswer = false;

    QTimer m_timer;
};
