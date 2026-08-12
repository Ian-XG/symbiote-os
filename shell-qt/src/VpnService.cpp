#include "VpnService.h"

#include <QFileInfo>
#include <QProcess>

namespace {

/* nmcli's terse output: fields separated by colons, one record per line. The
   human-readable table is localised and column-aligned, both of which make it
   the wrong thing to parse. */
QStringList terseFields(const QString &line)
{
    QStringList out;
    QString cur;
    bool esc = false;
    for (const QChar c : line) {
        if (esc) {
            // nmcli escapes a literal colon in a value as "\:".
            cur.append(c);
            esc = false;
        } else if (c == QLatin1Char('\\')) {
            esc = true;
        } else if (c == QLatin1Char(':')) {
            out << cur;
            cur.clear();
        } else {
            cur.append(c);
        }
    }
    out << cur;
    return out;
}

} // namespace

VpnService::VpnService(QObject *parent)
    : QObject(parent)
{
    refresh();
    connect(&m_timer, &QTimer::timeout, this, &VpnService::refresh);
    /* A VPN goes up or down on a timescale of seconds and almost always
       because somebody here asked it to, so this is a safety net rather than
       the main path — every action refreshes on completion. */
    m_timer.start(5000);
}

bool VpnService::run(const QStringList &args, QString *output)
{
    QProcess p;
    p.start(QStringLiteral("nmcli"), args);
    if (!p.waitForFinished(20000)) {
        p.kill();
        m_lastError = QStringLiteral("NetworkManager did not answer");
        return false;
    }
    if (output)
        *output = QString::fromUtf8(p.readAllStandardOutput());
    if (p.exitCode() != 0) {
        const QString err = QString::fromUtf8(p.readAllStandardError()).trimmed();
        m_lastError = err.isEmpty() ? QStringLiteral("the VPN call was refused") : err;
        return false;
    }
    return true;
}

void VpnService::refresh()
{
    const QVariantList before = m_connections;
    const QString beforeActive = m_activeName;

    QString out;
    QProcess p;
    p.start(QStringLiteral("nmcli"),
            {QStringLiteral("-t"), QStringLiteral("-f"),
             QStringLiteral("NAME,UUID,TYPE,ACTIVE"),
             QStringLiteral("connection"), QStringLiteral("show")});
    if (!p.waitForFinished(5000)) {
        p.kill();
        return;
    }
    out = QString::fromUtf8(p.readAllStandardOutput());

    QVariantList rows;
    QString active;
    for (const QString &line : out.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
        const QStringList f = terseFields(line);
        if (f.size() < 4)
            continue;
        const QString type = f[2];
        /* Both are VPNs to the operator; NetworkManager models WireGuard as a
           device type rather than as a VPN, so filtering on "vpn" alone would
           hide exactly the profiles most providers now hand out. */
        if (type != QLatin1String("vpn") && type != QLatin1String("wireguard"))
            continue;

        QVariantMap row;
        row["name"] = f[0];
        row["uuid"] = f[1];
        row["type"] = (type == QLatin1String("wireguard")) ? QStringLiteral("WIREGUARD")
                                                           : QStringLiteral("OPENVPN");
        const bool up = (f[3] == QLatin1String("yes"));
        row["active"] = up;
        if (up)
            active = f[0];
        rows << row;
    }

    m_connections = rows;
    m_activeName = active;

    /* Compared whole. This poll runs every five seconds, and re-emitting when
       nothing moved would rebuild the list's delegates under the operator —
       the same fault the Bluetooth list had. */
    if (before != m_connections || beforeActive != m_activeName)
        emit changed();
}

void VpnService::activate(const QString &uuid)
{
    m_busy = true;
    emit changed();
    /* Only one at a time. Two tunnels up at once is a routing argument nobody
       wins, and the second one usually appears to work while sending nothing
       through it. */
    for (const QVariant &v : m_connections) {
        const QVariantMap m = v.toMap();
        if (m.value("active").toBool() && m.value("uuid").toString() != uuid)
            run({QStringLiteral("connection"), QStringLiteral("down"),
                 QStringLiteral("uuid"), m.value("uuid").toString()});
    }
    if (run({QStringLiteral("connection"), QStringLiteral("up"),
             QStringLiteral("uuid"), uuid}))
        m_lastError.clear();
    m_busy = false;
    refresh();
}

void VpnService::deactivate(const QString &uuid)
{
    m_busy = true;
    emit changed();
    if (run({QStringLiteral("connection"), QStringLiteral("down"),
             QStringLiteral("uuid"), uuid}))
        m_lastError.clear();
    m_busy = false;
    refresh();
}

void VpnService::importProfile(const QString &path)
{
    QString clean = path.trimmed();
    // Dragged or pasted paths arrive quoted, and a quoted path is not a path.
    if (clean.startsWith(QLatin1Char('"')) && clean.endsWith(QLatin1Char('"')))
        clean = clean.mid(1, clean.size() - 2);
    if (clean.startsWith(QLatin1String("file://")))
        clean = clean.mid(7);
    if (clean.startsWith(QLatin1Char('~')))
        clean = qEnvironmentVariable("HOME") + clean.mid(1);

    const QFileInfo fi(clean);
    if (!fi.exists() || !fi.isFile()) {
        m_lastError = QStringLiteral("no file at %1").arg(clean);
        emit changed();
        return;
    }

    const QString suffix = fi.suffix().toLower();
    QString type;
    if (suffix == QLatin1String("ovpn"))
        type = QStringLiteral("openvpn");
    else if (suffix == QLatin1String("conf"))
        type = QStringLiteral("wireguard");
    else {
        /* Named rather than guessed. Importing an .ovpn as WireGuard fails
           with a parse error thirty lines deep, which reads like a corrupt
           file rather than the wrong kind of file. */
        m_lastError = QStringLiteral("expected a .ovpn or a WireGuard .conf, got .%1")
                          .arg(suffix.isEmpty() ? QStringLiteral("(none)") : suffix);
        emit changed();
        return;
    }

    m_busy = true;
    emit changed();
    if (run({QStringLiteral("connection"), QStringLiteral("import"),
             QStringLiteral("type"), type, QStringLiteral("file"), clean}))
        m_lastError.clear();
    m_busy = false;
    refresh();
}

void VpnService::forget(const QString &uuid)
{
    if (run({QStringLiteral("connection"), QStringLiteral("delete"),
             QStringLiteral("uuid"), uuid}))
        m_lastError.clear();
    refresh();
}

void VpnService::clearError()
{
    if (m_lastError.isEmpty())
        return;
    m_lastError.clear();
    emit changed();
}
