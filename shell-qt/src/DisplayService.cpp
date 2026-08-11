#include "DisplayService.h"

#include <QGuiApplication>
#include <QProcess>
#include <QScreen>
#include <QStandardPaths>
#include <QTimer>

namespace {

/* wlr-randr wants the connector name — "DP-1", "eDP-1". Qt reports the same
   string on Wayland, so no translation table is needed; if that ever stops
   being true the panel degrades to read-only rather than moving the wrong
   screen, because wlr-randr rejects a name it does not know. */
QString modeString(const QScreen *s)
{
    return QStringLiteral("%1x%2@%3")
        .arg(s->size().width())
        .arg(s->size().height())
        .arg(int(s->refreshRate() + 0.5));
}

} // namespace

DisplayService::DisplayService(QObject *parent)
    : QObject(parent)
{
    m_manageable = haveWlrRandr();

    rescan();
    connect(qApp, &QGuiApplication::screenAdded, this, &DisplayService::rescan);
    connect(qApp, &QGuiApplication::screenRemoved, this, &DisplayService::rescan);
    connect(qApp, &QGuiApplication::primaryScreenChanged, this, &DisplayService::rescan);
}

bool DisplayService::haveWlrRandr()
{
    return !QStandardPaths::findExecutable(QStringLiteral("wlr-randr")).isEmpty();
}

void DisplayService::rescan()
{
    m_screens.clear();

    const QScreen *primary = qApp->primaryScreen();
    const QList<QScreen *> list = qApp->screens();

    int index = 0;
    for (QScreen *s : list) {
        ++index;
        QVariantMap row;
        /* Connector name where there is one. Some backends report none — the
           offscreen platform never does — and an unnamed row reads as a blank
           space where a heading should be, so number it instead. */
        row["name"] = s->name().isEmpty()
                          ? QStringLiteral("DISPLAY %1").arg(index)
                          : s->name();
        // The model string, when the monitor bothers to report one.
        row["model"] = s->model().isEmpty() ? s->manufacturer() : s->model();
        row["x"] = s->geometry().x();
        row["y"] = s->geometry().y();
        row["width"] = s->geometry().width();
        row["height"] = s->geometry().height();
        row["scale"] = s->devicePixelRatio();
        row["refresh"] = int(s->refreshRate() + 0.5);
        row["primary"] = (s == primary);
        row["mode"] = modeString(s);
        /* Geometry as the user reads it off a spec sheet, for the label. */
        row["label"] = QStringLiteral("%1 × %2")
                           .arg(s->geometry().width())
                           .arg(s->geometry().height());
        m_screens.append(row);
    }

    /* Qt settles a hot-plugged output's geometry a moment after announcing it,
       so the first read can carry the old size. One late re-read costs nothing
       and stops a freshly attached monitor showing the wrong resolution until
       something else happens to refresh the panel. */
    static bool second = false;
    if (!second) {
        second = true;
        QTimer::singleShot(800, this, [this] { second = false; rescan(); });
    }

    emit changed();
}

bool DisplayService::run(const QStringList &args)
{
    if (!m_manageable) {
        m_lastError = QStringLiteral("wlr-randr is not installed");
        emit changed();
        return false;
    }

    QProcess p;
    p.start(QStringLiteral("wlr-randr"), args);
    if (!p.waitForFinished(4000)) {
        p.kill();
        m_lastError = QStringLiteral("wlr-randr did not answer");
        emit changed();
        return false;
    }
    if (p.exitCode() != 0) {
        const QString err = QString::fromUtf8(p.readAllStandardError()).trimmed();
        m_lastError = err.isEmpty() ? QStringLiteral("wlr-randr refused the change") : err;
        emit changed();
        return false;
    }

    m_lastError.clear();
    /* The compositor reconfigures asynchronously and Qt hears about it over
       the wire; give it a beat before reading the new layout back. */
    QTimer::singleShot(500, this, &DisplayService::rescan);
    return true;
}

void DisplayService::setEnabled(const QString &name, bool on)
{
    /* Refuse to black out the only display. wlr-randr will do it, the session
       becomes unusable, and there is then no screen on which to undo it. */
    if (!on && m_screens.size() < 2) {
        m_lastError = QStringLiteral("that is the only display");
        emit changed();
        return;
    }
    run({QStringLiteral("--output"), name,
         on ? QStringLiteral("--on") : QStringLiteral("--off")});
}

void DisplayService::setMode(const QString &name, const QString &mode)
{
    run({QStringLiteral("--output"), name, QStringLiteral("--mode"), mode});
}

void DisplayService::setScale(const QString &name, qreal scale)
{
    run({QStringLiteral("--output"), name,
         QStringLiteral("--scale"), QString::number(scale, 'f', 2)});
}

void DisplayService::arrangeHorizontally(const QStringList &order)
{
    /* One invocation for the lot. Done as a sequence of calls, the compositor
       applies each in turn and the outputs overlap in between — the desktop
       visibly jumps about, and a failure halfway leaves a bad layout. */
    QStringList args;
    int x = 0;
    for (const QString &name : order) {
        int w = 0;
        for (const QVariant &v : m_screens) {
            const QVariantMap m = v.toMap();
            if (m.value("name").toString() == name) {
                w = m.value("width").toInt();
                break;
            }
        }
        if (w <= 0)
            continue;
        args << QStringLiteral("--output") << name
             << QStringLiteral("--pos") << QStringLiteral("%1,0").arg(x);
        x += w;
    }
    if (!args.isEmpty())
        run(args);
}

void DisplayService::mirrorAll()
{
    QStringList args;
    for (const QVariant &v : m_screens) {
        const QString name = v.toMap().value("name").toString();
        args << QStringLiteral("--output") << name
             << QStringLiteral("--pos") << QStringLiteral("0,0");
    }
    if (!args.isEmpty())
        run(args);
}

void DisplayService::clearError()
{
    if (m_lastError.isEmpty())
        return;
    m_lastError.clear();
    emit changed();
}
