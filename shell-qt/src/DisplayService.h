#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>

/*
 * The displays attached to this machine, and the ability to rearrange them.
 *
 * The shell was written as one fullscreen window on the primary screen. Plug
 * in a second monitor and it stayed exactly that: the desktop on one panel and
 * bare compositor grey on the other — no wallpaper, no taskbar, no clock, and
 * no way to move a window there except by dragging it into the void and hoping.
 * Two things were missing, and this covers the second of them.
 *
 *  - `screens` is what Qt knows: one entry per output, so the QML can put a
 *    surface on every one of them. It is refreshed on screenAdded/screenRemoved
 *    rather than polled, because a monitor appears the instant it is plugged in
 *    and a desktop that notices thirty seconds later reads as broken.
 *
 *  - The setters drive wlr-randr. labwc speaks wlr-output-management, which is
 *    the protocol a compositor exposes for exactly this, and wlr-randr is its
 *    reference client. Talking the protocol directly from here would mean a
 *    second private Wayland queue and a few hundred lines to say what one
 *    command already says; if wlr-randr is missing, `manageable` is false and
 *    the panel says so rather than offering buttons that do nothing.
 */
class DisplayService : public QObject
{
    Q_OBJECT
    /* One map per output: name, description, geometry, scale, primary, plus
       the modes it can be set to. */
    Q_PROPERTY(QVariantList screens READ screens NOTIFY changed)
    Q_PROPERTY(int count READ count NOTIFY changed)
    /* The screen the desktop belongs on, named by Qt itself.
     *
     * The QML used to work this out from the window's own `screen` property
       and fall back to "treat every screen as secondary" when that was not yet
       known. On a MacBook whose internal panel enumerates as DP-3 that fallback
       fired and painted a second desktop over the first. This is authoritative
       and it is empty only when Qt has no screens at all. */
    Q_PROPERTY(QString primaryName READ primaryName NOTIFY changed)
    /** False when wlr-randr is not installed: read-only, and say why. */
    Q_PROPERTY(bool manageable READ manageable CONSTANT)
    Q_PROPERTY(QString lastError READ lastError NOTIFY changed)

public:
    explicit DisplayService(QObject *parent = nullptr);

    QVariantList screens() const { return m_screens; }
    int count() const { return m_screens.size(); }
    QString primaryName() const { return m_primaryName; }
    bool manageable() const { return m_manageable; }
    QString lastError() const { return m_lastError; }

    /** Turn an output on or off. Refuses to switch off the last one. */
    Q_INVOKABLE void setEnabled(const QString &name, bool on);
    /** Set an output's mode, as "1920x1080@60" or "1920x1080". */
    Q_INVOKABLE void setMode(const QString &name, const QString &mode);
    /** Per-output scale factor, for a high-density panel beside a normal one. */
    Q_INVOKABLE void setScale(const QString &name, qreal scale);
    /** Lay the outputs left to right in the given order, tops aligned. */
    Q_INVOKABLE void arrangeHorizontally(const QStringList &order);
    /** Point every output at the same origin, so they show the same thing. */
    Q_INVOKABLE void mirrorAll();
    Q_INVOKABLE void clearError();

signals:
    void changed();

private slots:
    void rescan();

private:
    /* Runs wlr-randr and reports whether it worked. Synchronous, but only ever
       from a button press, and it returns in milliseconds. */
    bool run(const QStringList &args);
    static bool haveWlrRandr();

    QVariantList m_screens;
    QString m_primaryName;
    bool m_manageable = false;
    QString m_lastError;
};
