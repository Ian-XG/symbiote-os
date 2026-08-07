#include "SystemMonitor.h"

#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QRegularExpression>
#include <QHostInfo>

#include <sys/statvfs.h>
#include <unistd.h>

namespace {

QString readAll(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readAll());
}

} // namespace

SystemMonitor::SystemMonitor(QObject *parent)
    : QObject(parent)
{
    readStatic();
    m_netClock.start();
    sample();

    // One second is short enough for the CPU delta to feel live and long
    // enough that sampling costs nothing measurable.
    connect(&m_timer, &QTimer::timeout, this, &SystemMonitor::sample);
    m_timer.start(1000);
}

void SystemMonitor::sample()
{
    readCpu();
    readMemory();
    readStorage();
    readThermal();
    readNetwork();
    emit changed();
}

void SystemMonitor::readStatic()
{
    m_hostname = QHostInfo::localHostName();

    const QString os = readAll(QStringLiteral("/etc/os-release"));
    QRegularExpression re(QStringLiteral("^PRETTY_NAME=\"?([^\"\n]+)\"?"),
                          QRegularExpression::MultilineOption);
    const auto m = re.match(os);
    m_edition = m.hasMatch() ? m.captured(1) : QStringLiteral("Symbiote OS");
}

void SystemMonitor::readCpu()
{
    const QString stat = readAll(QStringLiteral("/proc/stat"));
    if (stat.isEmpty())
        return;

    const QString first = stat.section('\n', 0, 0);
    const QStringList f = first.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
    if (f.size() < 8)
        return;

    // user nice system idle iowait irq softirq steal
    qint64 idle = f[4].toLongLong() + f[5].toLongLong();
    qint64 total = 0;
    for (int i = 1; i < f.size(); ++i)
        total += f[i].toLongLong();

    int usage = 0;
    if (m_prevTotal > 0) {
        const qint64 dIdle = idle - m_prevIdle;
        const qint64 dTotal = total - m_prevTotal;
        if (dTotal > 0)
            usage = qBound(0, int(((dTotal - dIdle) * 100) / dTotal), 100);
    }
    m_prevIdle = idle;
    m_prevTotal = total;

    // Core count and clock rarely change; read once and keep.
    if (!m_cpu.contains("cores")) {
        const QString info = readAll(QStringLiteral("/proc/cpuinfo"));
        m_cpu["cores"] = info.count(QRegularExpression("^processor\\s*:",
                                                       QRegularExpression::MultilineOption));
        QRegularExpression mhz(QStringLiteral("^cpu MHz\\s*:\\s*([\\d.]+)"),
                               QRegularExpression::MultilineOption);
        const auto mm = mhz.match(info);
        m_cpu["ghz"] = mm.hasMatch()
            ? QVariant(QString::number(mm.captured(1).toDouble() / 1000.0, 'f', 1).toDouble())
            : QVariant();
    }
    m_cpu["usage"] = usage;
}

void SystemMonitor::readMemory()
{
    const QString mi = readAll(QStringLiteral("/proc/meminfo"));
    auto kb = [&mi](const char *key) -> qint64 {
        QRegularExpression re(QStringLiteral("^%1:\\s+(\\d+) kB").arg(QLatin1String(key)),
                              QRegularExpression::MultilineOption);
        const auto m = re.match(mi);
        return m.hasMatch() ? m.captured(1).toLongLong() : 0;
    };

    const qint64 total = kb("MemTotal");
    const qint64 available = kb("MemAvailable");
    const qint64 used = total - available;

    m_memory["usedGb"] = QString::number(used / 1048576.0, 'f', 1).toDouble();
    m_memory["totalGb"] = QString::number(total / 1048576.0, 'f', 1).toDouble();
    m_memory["usage"] = total > 0 ? int((used * 100) / total) : 0;
}

void SystemMonitor::readStorage()
{
    struct statvfs s;
    if (statvfs("/", &s) != 0)
        return;

    const quint64 total = quint64(s.f_blocks) * s.f_frsize;
    const quint64 free = quint64(s.f_bavail) * s.f_frsize;
    const quint64 used = total - free;

    m_storage["totalGb"] = int(total / 1073741824ULL);
    m_storage["freeGb"] = int(free / 1073741824ULL);
    m_storage["usage"] = total > 0 ? int((used * 100) / total) : 0;
}

void SystemMonitor::readThermal()
{
    // Machines vary wildly here; prefer a zone that names itself as a CPU
    // package sensor, otherwise take the first readable one.
    QDir zones(QStringLiteral("/sys/class/thermal"));
    int best = -1;
    QString bestType;

    for (const QString &z : zones.entryList(QStringList{"thermal_zone*"}, QDir::Dirs)) {
        const QString base = zones.filePath(z);
        const QString type = readAll(base + "/type").trimmed();
        bool ok = false;
        const int milli = readAll(base + "/temp").trimmed().toInt(&ok);
        if (!ok)
            continue;

        const int celsius = milli / 1000;
        if (type.contains(QRegularExpression("pkg|cpu|coretemp|soc",
                                             QRegularExpression::CaseInsensitiveOption))) {
            best = celsius;
            bestType = type;
            break;
        }
        if (best < 0) {
            best = celsius;
            bestType = type;
        }
    }

    m_thermal["celsius"] = best >= 0 ? QVariant(best) : QVariant();
    m_thermal["type"] = bestType;

    // Fan speed, if any chip exposes one.
    QVariant rpm;
    QDir hwmon(QStringLiteral("/sys/class/hwmon"));
    for (const QString &h : hwmon.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        bool ok = false;
        const int v = readAll(hwmon.filePath(h) + "/fan1_input").trimmed().toInt(&ok);
        if (ok && v > 0) { rpm = v; break; }
    }
    m_thermal["fanRpm"] = rpm;
}

void SystemMonitor::readNetwork()
{
    const QString dev = readAll(QStringLiteral("/proc/net/dev"));
    if (dev.isEmpty())
        return;

    const qint64 elapsedMs = m_netClock.restart();
    if (elapsedMs <= 0)
        return;
    const double seconds = elapsedMs / 1000.0;

    QVariantMap out;
    const QStringList lines = dev.split('\n');
    for (int i = 2; i < lines.size(); ++i) {
        const QString line = lines[i].trimmed();
        const int colon = line.indexOf(':');
        if (colon < 0)
            continue;

        const QString iface = line.left(colon).trimmed();
        if (iface == QLatin1String("lo"))
            continue;

        const QStringList f = line.mid(colon + 1).split(QRegularExpression("\\s+"),
                                                        Qt::SkipEmptyParts);
        if (f.size() < 9)
            continue;

        const qint64 rx = f[0].toLongLong();
        const qint64 tx = f[8].toLongLong();

        if (m_prevNet.contains(iface)) {
            const NetSample &p = m_prevNet[iface];
            QVariantMap t;
            t["downMbs"] = QString::number((rx - p.rx) / seconds / 1048576.0, 'f', 1).toDouble();
            t["upMbs"] = QString::number((tx - p.tx) / seconds / 1048576.0, 'f', 1).toDouble();
            out[iface] = t;
        }
        m_prevNet[iface] = NetSample{rx, tx};
    }
    m_network = out;
}

QVariantMap SystemMonitor::primaryInterface() const
{
    QVariantMap best;
    double bestTotal = -1;
    for (auto it = m_network.constBegin(); it != m_network.constEnd(); ++it) {
        const QVariantMap t = it.value().toMap();
        const double total = t["downMbs"].toDouble() + t["upMbs"].toDouble();
        if (total > bestTotal) {
            bestTotal = total;
            best = t;
            best["name"] = it.key();
        }
    }
    return best;
}

QString SystemMonitor::kernel() const
{
    // /proc/sys/kernel/osrelease is what `uname -r` prints, without a fork.
    return readAll(QStringLiteral("/proc/sys/kernel/osrelease")).trimmed();
}

qreal SystemMonitor::load() const
{
    return readAll(QStringLiteral("/proc/loadavg")).section(' ', 0, 0).toDouble();
}

int SystemMonitor::taskCount() const
{
    /* Field 4 of /proc/loadavg is running/total. The total is every task the
       kernel knows about, which is more than the process list shows. */
    const QString runnable = readAll(QStringLiteral("/proc/loadavg")).section(' ', 3, 3);
    return runnable.section('/', 1, 1).toInt();
}

qint64 SystemMonitor::uptime() const
{
    const QString up = readAll(QStringLiteral("/proc/uptime"));
    return up.isEmpty() ? 0 : qint64(up.section(' ', 0, 0).toDouble());
}
