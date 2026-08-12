#pragma once

#include <QObject>
#include <QTimer>

/*
 * Volume and screen brightness.
 *
 * A laptop desktop without these is missing something people reach for every
 * day, and there was nowhere in the interface to change either. The keyboard's
 * own media keys did nothing, because nothing was listening.
 *
 * Volume goes through wpctl, which is WirePlumber's own tool and already
 * installed — talking to PipeWire directly would mean carrying a client
 * library to do what one command does.
 *
 * Brightness is written straight to sysfs. brightnessctl exists and is
 * installed as the fallback for machines where the sysfs node is not writable,
 * but on this one a udev rule hands the `video` group write access, and the
 * operator is in that group.
 */
class MediaService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int volume READ volume NOTIFY changed)
    Q_PROPERTY(bool muted READ muted NOTIFY changed)
    Q_PROPERTY(bool audioAvailable READ audioAvailable NOTIFY changed)

    Q_PROPERTY(int brightness READ brightness NOTIFY changed)
    Q_PROPERTY(bool backlightAvailable READ backlightAvailable NOTIFY changed)

public:
    explicit MediaService(QObject *parent = nullptr);

    int volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    bool audioAvailable() const { return m_audioAvailable; }

    int brightness() const { return m_brightness; }
    bool backlightAvailable() const { return !m_backlightPath.isEmpty(); }

    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void toggleMute();
    /* Say which state you want rather than asking for the other one.
       A toggle driven from a button that also reflects the state races with
       the two-second poll: press it twice quickly and the second press acts on
       a reading taken before the first one landed. */
    Q_INVOKABLE void setMuted(bool muted);
    Q_INVOKABLE void setBrightness(int percent);
    /** Nudge by a step, for the media keys. */
    Q_INVOKABLE void stepVolume(int delta);
    Q_INVOKABLE void stepBrightness(int delta);

signals:
    void changed();

private slots:
    void refresh();

private:
    void findBacklight();

    int m_volume = 0;
    bool m_muted = false;
    bool m_audioAvailable = false;

    QString m_backlightPath;
    qint64 m_backlightMax = 0;
    int m_brightness = 0;

    QTimer m_timer;
};
