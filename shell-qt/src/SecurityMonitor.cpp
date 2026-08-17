#include "SecurityMonitor.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusObjectPath>

#include <QProcess>
#include <QFile>
#include <QDir>
#include <QDateTime>
#include <QRegularExpression>

namespace {

QVariantMap row(const QString &label, const QString &value, const QString &state)
{
    QVariantMap m;
    m["label"] = label;
    m["value"] = value;
    m["state"] = state;
    return m;
}

/** Run a command with a hard deadline; empty result means it failed or hung. */
QString run(const QString &cmd, const QStringList &args, int timeoutMs = 4000)
{
    QProcess p;
    p.start(cmd, args);
    if (!p.waitForFinished(timeoutMs)) {
        p.kill();
        p.waitForFinished(500);
        return {};
    }
    if (p.exitStatus() != QProcess::NormalExit)
        return {};
    return QString::fromUtf8(p.readAllStandardOutput());
}

} // namespace

/* Health of the medium the system booted from.
 *
 * A failing USB stick does not announce itself. What it does is return read
 * errors for pages that are not already in memory — so the desktop keeps
 * running perfectly while every attempt to *start* something dies with
 * "execve: Input/output error", which reads like a bug in the shell and is
 * not one.
 *
 * The SCSI layer counts these per device and exposes the count without root.
 * Surfacing it turns an unexplainable failure into a diagnosis. */
QVariantMap SecurityMonitor::medium()
{
    qint64 total = 0;
    bool sawCounter = false;

    const QFileInfoList disks = QDir(QStringLiteral("/sys/block")).entryInfoList(
        QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &d : disks) {
        /* Optical devices are excluded. A CD-ROM — including the virtual one
           a VM presents — counts ordinary check conditions from enumeration
           as errors, so a healthy machine reports a handful and this row
           would sit permanently red. Which is how the first version of it
           behaved. */
        if (d.fileName().startsWith(QLatin1String("sr")))
            continue;

        QFile f(d.absoluteFilePath() + QStringLiteral("/device/ioerr_cnt"));
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
            continue;
        sawCounter = true;
        bool ok = false;
        // Hexadecimal, which is not obvious and reads as a suspiciously large
        // decimal if you assume otherwise.
        const qint64 n = QString::fromUtf8(f.readAll()).trimmed().toLongLong(&ok, 16);
        if (ok)
            total += n;
    }

    if (!sawCounter)
        return row(QStringLiteral("Boot medium"), QStringLiteral("NOT REPORTED"),
                   QStringLiteral("idle"));

    /* Baselined at first sample. What matters is not how many errors a device
       has ever logged, but whether it is logging them now: a stick that is
       failing keeps producing them, and one that logged a few during boot and
       stopped is fine. */
    if (m_mediumBaseline < 0) {
        m_mediumBaseline = total;
        return row(QStringLiteral("Boot medium"), QStringLiteral("HEALTHY"),
                   QStringLiteral("ok"));
    }

    const qint64 since = total - m_mediumBaseline;
    if (since <= 0)
        return row(QStringLiteral("Boot medium"), QStringLiteral("HEALTHY"),
                   QStringLiteral("ok"));

    return row(QStringLiteral("Boot medium"),
               QStringLiteral("%1 READ ERRORS").arg(since),
               QStringLiteral("critical"));
}

SecurityMonitor::SecurityMonitor(QObject *parent) : QObject(parent)
{
    sample();
    connect(&m_timer, &QTimer::timeout, this, &SecurityMonitor::sample);
    m_timer.start(8000);
}

/* Ask systemd, not the kernel.
 *
 * This row reported "NOT RUNNING" on every boot the shell has ever had, and it
 * was never looking at the firewall: reading the nftables ruleset needs
 * CAP_NET_ADMIN, and the shell runs as an ordinary user. `nft list ruleset`
 * returned "Operation not permitted", the code saw empty output, and printed
 * a red NOT RUNNING — a confident answer to a question it could not ask.
 *
 * systemd's unit state is readable by anyone on the system bus, so that is
 * what gets asked. It answers a slightly different question — is the firewall
 * service up — but it answers it truthfully, which the old check did not.
 */
QVariantMap SecurityMonitor::firewall()
{
    QDBusInterface systemd(QStringLiteral("org.freedesktop.systemd1"),
                           QStringLiteral("/org/freedesktop/systemd1"),
                           QStringLiteral("org.freedesktop.systemd1.Manager"),
                           QDBusConnection::systemBus());
    systemd.setTimeout(3000);

    const QStringList units = { QStringLiteral("nftables.service"),
                                QStringLiteral("ufw.service"),
                                QStringLiteral("firewalld.service") };

    bool reachedSystemd = false;
    for (const QString &unit : units) {
        QDBusReply<QString> state = systemd.call(QStringLiteral("GetUnitFileState"), unit);
        if (!state.isValid())
            continue;              // unit not installed
        reachedSystemd = true;

        QDBusReply<QDBusObjectPath> path = systemd.call(QStringLiteral("GetUnit"), unit);
        if (!path.isValid())
            continue;              // installed but never started

        QDBusInterface props(QStringLiteral("org.freedesktop.systemd1"), path.value().path(),
                             QStringLiteral("org.freedesktop.DBus.Properties"),
                             QDBusConnection::systemBus());
        props.setTimeout(3000);
        const QDBusReply<QVariant> active =
            props.call(QStringLiteral("Get"), QStringLiteral("org.freedesktop.systemd1.Unit"),
                       QStringLiteral("ActiveState"));
        if (!active.isValid())
            continue;

        const QString value = active.value().toString();
        const QString name = unit.section(QLatin1Char('.'), 0, 0).toUpper();
        if (value == QLatin1String("active"))
            return row("Firewall", QStringLiteral("ACTIVE · %1").arg(name), "ok");
        if (value == QLatin1String("activating"))
            return row("Firewall", QStringLiteral("STARTING · %1").arg(name), "attention");
        return row("Firewall", QStringLiteral("%1 · %2").arg(value.toUpper(), name), "critical");
    }

    /* Distinguish "no firewall" from "could not ask". Claiming the machine is
       exposed because the bus was unreachable is the mistake this replaced. */
    return reachedSystemd ? row("Firewall", "NOT RUNNING", "critical")
                          : row("Firewall", "UNKNOWN", "idle");
}

QVariantMap SecurityMonitor::vpn()
{
    QDir net(QStringLiteral("/sys/class/net"));
    const auto ifaces = net.entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::System);
    for (const QString &n : ifaces) {
        if (!QRegularExpression("^(tun|tap|wg|ppp)\\d*").match(n).hasMatch())
            continue;
        QFile f(net.filePath(n) + "/operstate");
        if (f.open(QIODevice::ReadOnly)) {
            const QString st = QString::fromUtf8(f.readAll()).trimmed();
            if (st == "up" || st == "unknown")
                return row("VPN", QString("UP (%1)").arg(n), "ok");
        }
    }
    return row("VPN", "NOT CONNECTED", "idle");
}

QVariantMap SecurityMonitor::encryption()
{
    QDir blocks(QStringLiteral("/sys/block"));
    for (const QString &b : blocks.entryList(QStringList{"dm-*"}, QDir::Dirs)) {
        QFile f(blocks.filePath(b) + "/dm/uuid");
        if (f.open(QIODevice::ReadOnly)
            && QString::fromUtf8(f.readAll()).startsWith("CRYPT-"))
            return row("Disk encryption", "ON (LUKS)", "ok");
    }
    // A live image runs from squashfs; there is nothing to encrypt yet.
    return row("Disk encryption", "OFF", "idle");
}

/* How stale apt's package lists are, in days, or -1 when there are none.
 *
 * The newest file wins: apt refreshes them together, so the most recent write
 * is when this machine last learnt what exists. */
int SecurityMonitor::listsAgeDays()
{
    QDateTime newest;
    const QFileInfoList files = QDir("/var/lib/apt/lists")
        .entryInfoList({"*_Packages", "*_InRelease", "*_Release"}, QDir::Files);
    for (const QFileInfo &fi : files)
        if (!newest.isValid() || fi.lastModified() > newest)
            newest = fi.lastModified();

    if (!newest.isValid())
        return -1;
    return int(newest.daysTo(QDateTime::currentDateTime()));
}

QVariantMap SecurityMonitor::updates()
{
    // apt is slow and the answer barely moves, so it is cached for ten minutes.
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    if (!m_updateCache.isEmpty() && now - m_updateCheckedAt < 600)
        return m_updateCache;

    const QString out = run("apt-get", {"-s", "-o", "Debug::NoLocking=1", "upgrade"}, 15000);
    if (out.isEmpty()) {
        m_updateCache = row("Updates", "UNKNOWN", "idle");
    } else {
        const int n = out.count(QRegularExpression("^Inst ", QRegularExpression::MultilineOption));
        if (n > 0) {
            m_updateCache = row("Updates", QString("%1 PENDING").arg(n), "attention");
        } else {
            /* Zero pending is only as good as the catalogue it was measured
               against, and on a live image that catalogue is frozen at build
               time. apt compares what is installed against /var/lib/apt/lists,
               which is written once when the image is made and never again
               unless somebody runs apt update. So an image three months old
               says "UP TO DATE" with total confidence while three months of
               security updates exist -- true on the day it was built and
               quietly false afterwards, which is the worst way for a security
               panel to be wrong.
               The age of the lists is the missing half of the answer. */
            const int days = listsAgeDays();
            if (days < 0) {
                /* No package lists at all, so apt had nothing to compare
                   against and its zero means nothing. Saying "up to date"
                   here was the same lie in the other direction -- the first
                   draft of this did exactly that, and the build container,
                   which ships no lists, is where it showed. */
                m_updateCache = row("Updates", "UNKNOWN", "idle");
            } else if (days <= 7) {
                m_updateCache = row("Updates", "UP TO DATE", "ok");
            } else {
                m_updateCache = row("Updates", QString("LISTS %1d OLD").arg(days),
                                    "attention");
            }
        }
    }
    m_updateCheckedAt = now;
    return m_updateCache;
}

QVariantMap SecurityMonitor::ports()
{
    QFile f(QStringLiteral("/proc/net/tcp"));
    if (!f.open(QIODevice::ReadOnly))
        return row("Open ports", "UNKNOWN", "idle");

    int open = 0;
    const QStringList lines = QString::fromUtf8(f.readAll()).split('\n');
    for (int i = 1; i < lines.size(); ++i) {
        const QStringList fields = lines[i].trimmed().split(QRegularExpression("\\s+"),
                                                            Qt::SkipEmptyParts);
        if (fields.size() < 4)
            continue;
        if (fields[3] != QLatin1String("0A"))       // 0A = LISTEN
            continue;
        if (fields[1].section(':', 0, 0) == QLatin1String("00000000"))
            ++open;                                  // bound to all interfaces
    }
    return open == 0 ? row("Open ports", "NONE EXPOSED", "ok")
                     : row("Open ports", QString("%1 LISTENING").arg(open), "attention");
}

void SecurityMonitor::sample()
{
    m_rows = QVariantList{ firewall(), vpn(), encryption(), updates(), ports(), medium() };
    emit changed();
}

int SecurityMonitor::okCount() const
{
    int n = 0;
    for (const QVariant &r : m_rows)
        if (r.toMap()["state"].toString() == QLatin1String("ok"))
            ++n;
    return n;
}
