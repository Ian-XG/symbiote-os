#include "SecurityMonitor.h"

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

SecurityMonitor::SecurityMonitor(QObject *parent) : QObject(parent)
{
    sample();
    connect(&m_timer, &QTimer::timeout, this, &SecurityMonitor::sample);
    m_timer.start(8000);
}

QVariantMap SecurityMonitor::firewall()
{
    const QString nft = run("nft", {"list", "ruleset"});
    if (!nft.trimmed().isEmpty()) {
        const int rules = nft.count(QRegularExpression("^\\s*(accept|drop|reject|jump|goto)\\b",
                                                       QRegularExpression::MultilineOption));
        // A loaded but empty ruleset is permissive; that distinction matters.
        return rules > 0 ? row("Firewall", QString("ACTIVE (%1 rules)").arg(rules), "ok")
                         : row("Firewall", "LOADED, NO RULES", "attention");
    }

    const QString ipt = run("iptables-save", {});
    const int rules = ipt.count(QRegularExpression("^-A", QRegularExpression::MultilineOption));
    if (rules > 0)
        return row("Firewall", QString("ACTIVE (%1 rules)").arg(rules), "ok");

    return row("Firewall", "NOT RUNNING", "critical");
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
        m_updateCache = n == 0 ? row("Updates", "UP TO DATE", "ok")
                               : row("Updates", QString("%1 PENDING").arg(n), "attention");
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
    m_rows = QVariantList{ firewall(), vpn(), encryption(), updates(), ports() };
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
