#include "TimeService.h"

#include <QDateTime>
#include <QProcess>
#include <QTimeZone>

namespace {

/* timedatectl's output is a block of "  Key: value" lines. Reading it with a
   parser rather than the JSON-ish variants keeps this to one dependency-free
   function, and the keys have been stable for a decade. */
QString field(const QString &blob, const QString &key)
{
    const QStringList lines = blob.split(QLatin1Char('\n'));
    for (const QString &line : lines) {
        const QString t = line.trimmed();
        if (t.startsWith(key + QLatin1Char(':')))
            return t.mid(key.size() + 1).trimmed();
    }
    return QString();
}

} // namespace

TimeService::TimeService(QObject *parent)
    : QObject(parent)
{
    /* Qt carries the IANA database, so the list needs no external command and
       cannot disagree with what QDateTime will do with the answer. */
    const QList<QByteArray> ids = QTimeZone::availableTimeZoneIds();
    m_zones.reserve(ids.size());
    for (const QByteArray &id : ids)
        m_zones << QString::fromUtf8(id);
    m_zones.sort();

    refresh();
    connect(&m_timer, &QTimer::timeout, this, &TimeService::refresh);
    /* Slow on purpose. Nothing here changes on its own except the NTP sync
       flag, and that settles within a minute of joining a network. */
    m_timer.start(30000);
}

void TimeService::refresh()
{
    const QString before = m_timezone + m_offset
                           + QString::number(m_ntpEnabled) + QString::number(m_ntpSynced);

    QProcess p;
    p.start(QStringLiteral("timedatectl"), {QStringLiteral("show")});
    if (p.waitForFinished(3000) && p.exitCode() == 0) {
        const QString out = QString::fromUtf8(p.readAllStandardOutput());
        /* `show` prints Key=value, one per line — the machine-readable form.
           `status` is the pretty one and is localised, which is exactly the
           sort of thing that parses fine until the image ships in Spanish. */
        for (const QString &line : out.split(QLatin1Char('\n'))) {
            const int eq = line.indexOf(QLatin1Char('='));
            if (eq < 0)
                continue;
            const QString k = line.left(eq);
            const QString v = line.mid(eq + 1).trimmed();
            if (k == QLatin1String("Timezone"))
                m_timezone = v;
            else if (k == QLatin1String("NTP"))
                m_ntpEnabled = (v == QLatin1String("yes"));
            else if (k == QLatin1String("NTPSynchronized"))
                m_ntpSynced = (v == QLatin1String("yes"));
        }
    } else {
        // No timedatectl: fall back to whatever Qt believes, read-only.
        m_timezone = QString::fromUtf8(QTimeZone::systemTimeZoneId());
    }

    const int secs = QDateTime::currentDateTime().offsetFromUtc();
    m_offset = QStringLiteral("UTC%1%2:%3")
                   .arg(secs < 0 ? QLatin1Char('-') : QLatin1Char('+'))
                   .arg(qAbs(secs) / 3600, 2, 10, QLatin1Char('0'))
                   .arg((qAbs(secs) % 3600) / 60, 2, 10, QLatin1Char('0'));

    if (before != m_timezone + m_offset
                      + QString::number(m_ntpEnabled) + QString::number(m_ntpSynced))
        emit changed();
}

bool TimeService::run(const QStringList &args)
{
    QProcess p;
    p.start(QStringLiteral("timedatectl"), args);
    if (!p.waitForFinished(5000)) {
        p.kill();
        m_lastError = QStringLiteral("timedatectl did not answer");
        emit changed();
        return false;
    }
    if (p.exitCode() != 0) {
        const QString err = QString::fromUtf8(p.readAllStandardError()).trimmed();
        m_lastError = err.isEmpty() ? QStringLiteral("the change was refused") : err;
        emit changed();
        return false;
    }
    m_lastError.clear();
    refresh();
    return true;
}

void TimeService::setTimezone(const QString &zone)
{
    /* Checked against the list rather than passed straight through. An unknown
       name makes timedatectl fail in a way that reads like a permissions
       problem, and the operator would be looking in the wrong place. */
    if (!m_zones.contains(zone)) {
        m_lastError = QStringLiteral("no such timezone: %1").arg(zone);
        emit changed();
        return;
    }
    run({QStringLiteral("set-timezone"), zone});
}

void TimeService::setNtp(bool on)
{
    run({QStringLiteral("set-ntp"), on ? QStringLiteral("true") : QStringLiteral("false")});
}

QStringList TimeService::search(const QString &text, int limit) const
{
    const QString needle = text.trimmed();
    QStringList out;

    if (needle.isEmpty()) {
        /* Nothing typed: offer the current zone and UTC, not the first forty
           names alphabetically — which are all in Africa and tell the operator
           nothing about what this box is doing. */
        if (!m_timezone.isEmpty())
            out << m_timezone;
        if (!out.contains(QStringLiteral("UTC")))
            out << QStringLiteral("UTC");
        return out;
    }

    for (const QString &z : m_zones) {
        if (z.contains(needle, Qt::CaseInsensitive)) {
            out << z;
            if (out.size() >= limit)
                break;
        }
    }
    return out;
}

void TimeService::clearError()
{
    if (m_lastError.isEmpty())
        return;
    m_lastError.clear();
    emit changed();
}
