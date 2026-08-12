#include "MediaService.h"

#include <QProcess>
#include <QFile>
#include <QDir>
#include <QRegularExpression>

namespace {

/** Run a command with a deadline; empty means it failed or hung. */
QString run(const QString &cmd, const QStringList &args, int timeoutMs = 2500)
{
    QProcess p;
    p.start(cmd, args);
    if (!p.waitForFinished(timeoutMs)) {
        p.kill();
        p.waitForFinished(300);
        return {};
    }
    return QString::fromUtf8(p.readAllStandardOutput());
}

constexpr auto SINK = "@DEFAULT_AUDIO_SINK@";

} // namespace

MediaService::MediaService(QObject *parent) : QObject(parent)
{
    findBacklight();
    refresh();
    connect(&m_timer, &QTimer::timeout, this, &MediaService::refresh);
    /* Something else can change the volume — a media key handled by the
       compositor, or an application's own mixer — so the value is polled
       rather than assumed to be whatever we last set. */
    m_timer.start(2000);
}

void MediaService::findBacklight()
{
    const QFileInfoList entries = QDir(QStringLiteral("/sys/class/backlight"))
                                      .entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &e : entries) {
        QFile maxFile(e.absoluteFilePath() + QStringLiteral("/max_brightness"));
        if (!maxFile.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;
        bool ok = false;
        const qint64 max = QString::fromUtf8(maxFile.readAll()).trimmed().toLongLong(&ok);
        if (!ok || max <= 0)
            continue;
        m_backlightPath = e.absoluteFilePath();
        m_backlightMax = max;
        // The first usable panel wins; a machine with two is rare and either
        // would be a guess.
        break;
    }
}

void MediaService::refresh()
{
    // ── volume ─────────────────────────────────────────────────
    // wpctl prints e.g. "Volume: 0.65" or "Volume: 0.65 [MUTED]".
    const QString out = run(QStringLiteral("wpctl"),
                            {QStringLiteral("get-volume"), QString::fromLatin1(SINK)});
    const bool wasAvailable = m_audioAvailable;
    const int prevVol = m_volume;
    const bool prevMuted = m_muted;

    static const QRegularExpression re(QStringLiteral("Volume:\\s*([0-9.]+)"));
    const auto m = re.match(out);
    if (m.hasMatch()) {
        m_audioAvailable = true;
        m_volume = qRound(m.captured(1).toDouble() * 100.0);
        m_muted = out.contains(QLatin1String("MUTED"));
    } else {
        // No PipeWire, or no sink. Reported as absent rather than as zero,
        // which would look like a volume the operator had set.
        m_audioAvailable = false;
    }

    // ── brightness ─────────────────────────────────────────────
    const int prevBright = m_brightness;
    if (!m_backlightPath.isEmpty()) {
        QFile f(m_backlightPath + QStringLiteral("/brightness"));
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            bool ok = false;
            const qint64 v = QString::fromUtf8(f.readAll()).trimmed().toLongLong(&ok);
            if (ok && m_backlightMax > 0)
                m_brightness = qRound(double(v) * 100.0 / double(m_backlightMax));
        }
    }

    if (wasAvailable != m_audioAvailable || prevVol != m_volume
        || prevMuted != m_muted || prevBright != m_brightness) {
        emit changed();
    }
}

void MediaService::setVolume(int percent)
{
    percent = qBound(0, percent, 100);
    run(QStringLiteral("wpctl"), {QStringLiteral("set-volume"),
                                  QString::fromLatin1(SINK),
                                  QStringLiteral("%1%").arg(percent)});
    m_volume = percent;

    /* Reaching for the volume while muted means "I want to hear this".
       Leaving the sink muted after a deliberate change is the behaviour that
       makes people conclude the slider is broken. Dragging to zero is the one
       case where silence was the actual request. */
    if (m_muted && percent > 0) {
        run(QStringLiteral("wpctl"), {QStringLiteral("set-mute"),
                                      QString::fromLatin1(SINK),
                                      QStringLiteral("0")});
        m_muted = false;
    }
    emit changed();
}

void MediaService::toggleMute()
{
    setMuted(!m_muted);
}

void MediaService::setMuted(bool muted)
{
    run(QStringLiteral("wpctl"), {QStringLiteral("set-mute"),
                                  QString::fromLatin1(SINK),
                                  muted ? QStringLiteral("1") : QStringLiteral("0")});
    m_muted = muted;
    emit changed();
    /* Read back rather than trust the write: another mixer may have muted the
       sink at the same moment, and the panel should show what is true. */
    refresh();
}

void MediaService::stepVolume(int delta)
{
    setVolume(m_volume + delta);
}

void MediaService::setBrightness(int percent)
{
    if (m_backlightPath.isEmpty() || m_backlightMax <= 0)
        return;
    /* Never all the way to zero. A backlight at 0 is a black screen with no
       way to see the control that would bring it back. */
    percent = qBound(5, percent, 100);
    const qint64 raw = qRound(double(percent) * double(m_backlightMax) / 100.0);

    QFile f(m_backlightPath + QStringLiteral("/brightness"));
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        f.write(QByteArray::number(raw));
        f.close();
    } else {
        // The udev rule did not apply, or this is not the panel's own node.
        run(QStringLiteral("brightnessctl"),
            {QStringLiteral("set"), QStringLiteral("%1%").arg(percent)});
    }

    m_brightness = percent;
    emit changed();
}

void MediaService::stepBrightness(int delta)
{
    setBrightness(m_brightness + delta);
}
