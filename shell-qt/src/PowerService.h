#pragma once
#include <QObject>
#include <QTimer>

/* Battery and AC state via UPower's DisplayDevice, which is its own aggregate
   of whatever batteries the machine has — so it works on a laptop with two
   packs and reports "not present" on a desktop instead of inventing one. */
class PowerService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool present READ present NOTIFY changed)
    Q_PROPERTY(bool onAc READ onAc NOTIFY changed)
    Q_PROPERTY(int percent READ percent NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString remaining READ remaining NOTIFY changed)

public:
    explicit PowerService(QObject *parent = nullptr);
    bool present() const { return m_present; }
    bool onAc() const { return m_onAc; }
    int percent() const { return m_percent; }
    QString state() const { return m_state; }
    QString remaining() const { return m_remaining; }

signals:
    void changed();

private slots:
    void sample();

private:
    bool m_present = false;
    bool m_onAc = true;
    int m_percent = 100;
    QString m_state = QStringLiteral("unknown");
    QString m_remaining;
    QTimer m_timer;
};
