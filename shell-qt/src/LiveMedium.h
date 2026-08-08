#pragma once

#include <QObject>
#include <QTimer>

/*
 * The medium this system booted from, and whether anything written survives.
 *
 * A live image forgets everything on reboot. Persistence fixes that, but it
 * needs a writable partition labelled "persistence" — and a stick flashed with
 * dd or Etcher has the image bytes and then unallocated space, so there is
 * nowhere to write until somebody makes one.
 *
 * That "somebody" used to be a person who happened to know a command existed.
 * This finds the boot device, works out whether there is room, and lets the
 * interface offer it — the difference between a feature you discover and one
 * you have to be told about.
 *
 * It does not create anything. Repartitioning the medium you are running from
 * is not a thing to do on a single click, so the offer opens the existing
 * script, which names the device and its size and makes you type ERASE.
 */
class LiveMedium : public QObject
{
    Q_OBJECT
    /** True when running from live media rather than an installed system. */
    Q_PROPERTY(bool live READ live NOTIFY changed)
    Q_PROPERTY(bool persistent READ persistent NOTIFY changed)
    /** The whole disk the image was booted from, e.g. /dev/sdb. */
    Q_PROPERTY(QString device READ device NOTIFY changed)
    /** Unallocated bytes past the last partition. Zero when there is none. */
    Q_PROPERTY(qint64 freeBytes READ freeBytes NOTIFY changed)
    Q_PROPERTY(QString freeHuman READ freeHuman NOTIFY changed)
    /** Enough room to be worth offering. */
    Q_PROPERTY(bool canOffer READ canOffer NOTIFY changed)

public:
    explicit LiveMedium(QObject *parent = nullptr);

    bool live() const { return m_live; }
    bool persistent() const { return m_persistent; }
    QString device() const { return m_device; }
    qint64 freeBytes() const { return m_freeBytes; }
    QString freeHuman() const;
    bool canOffer() const;

    /** Open the persistence tool in a terminal. Confirmation stays in there. */
    Q_INVOKABLE void openSetup();

signals:
    void changed();

private slots:
    void refresh();

private:
    bool m_live = false;
    bool m_persistent = false;
    QString m_device;
    qint64 m_freeBytes = 0;

    QTimer m_timer;
};
