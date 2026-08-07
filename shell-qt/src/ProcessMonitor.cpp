#include "ProcessMonitor.h"

#include <QDir>
#include <QFile>
#include <algorithm>
#include <unistd.h>

ProcessMonitor::ProcessMonitor(QObject *parent) : QObject(parent)
{
    m_clock.start();
    sample();
    connect(&m_timer, &QTimer::timeout, this, &ProcessMonitor::sample);
    m_timer.start(3000);
}

void ProcessMonitor::sample()
{
    const long hz = sysconf(_SC_CLK_TCK) > 0 ? sysconf(_SC_CLK_TCK) : 100;
    const qint64 elapsedMs = m_clock.restart();
    const double seconds = elapsedMs / 1000.0;

    struct Row { int pid; QString name; double cpu; int rssMb; };
    QList<Row> rows;
    QHash<int, qint64> current;

    QDir proc(QStringLiteral("/proc"));
    const auto entries = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot);

    for (const QString &e : entries) {
        bool isPid = false;
        const int pid = e.toInt(&isPid);
        if (!isPid)
            continue;

        QFile f(QStringLiteral("/proc/%1/stat").arg(pid));
        if (!f.open(QIODevice::ReadOnly))
            continue;                       // exited between listing and reading
        const QString stat = QString::fromUtf8(f.readAll());

        // comm can contain spaces and parentheses, so split around the LAST ')'
        const int close = stat.lastIndexOf(')');
        const int open = stat.indexOf('(');
        if (close < 0 || open < 0)
            continue;
        const QString comm = stat.mid(open + 1, close - open - 1);
        const QStringList rest = stat.mid(close + 2).split(' ', Qt::SkipEmptyParts);
        if (rest.size() < 22)
            continue;

        const qint64 ticks = rest[11].toLongLong() + rest[12].toLongLong();
        const qint64 rssPages = rest[21].toLongLong();
        current.insert(pid, ticks);

        double cpu = 0;
        if (m_prevTicks.contains(pid) && seconds > 0)
            cpu = double(ticks - m_prevTicks[pid]) / hz / seconds * 100.0;

        rows.append({pid, comm, qMax(0.0, cpu), int(rssPages * 4096 / 1048576)});
    }

    const bool haveCpu = std::any_of(rows.cbegin(), rows.cend(),
                                     [](const Row &r) { return r.cpu > 0; });
    std::sort(rows.begin(), rows.end(), [haveCpu](const Row &a, const Row &b) {
        return haveCpu ? a.cpu > b.cpu : a.rssMb > b.rssMb;
    });

    QVariantList out;
    for (int i = 0; i < qMin(m_limit, int(rows.size())); ++i) {
        QVariantMap m;
        m["pid"] = rows[i].pid;
        m["name"] = rows[i].name;
        m["cpu"] = QString::number(rows[i].cpu, 'f', 1).toDouble();
        m["rssMb"] = rows[i].rssMb;
        out.append(m);
    }

    m_prevTicks = current;
    m_top = out;
    emit changed();
}
