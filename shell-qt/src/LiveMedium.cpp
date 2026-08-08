#include "LiveMedium.h"

#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>

namespace {

/* Smaller than this is not worth interrupting anybody for: a persistence
   overlay in a few hundred megabytes fills up almost immediately. */
constexpr qint64 MIN_USEFUL = 2LL * 1024 * 1024 * 1024;

QString readFirstLine(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(f.readLine()).trimmed();
}

} // namespace

LiveMedium::LiveMedium(QObject *parent) : QObject(parent)
{
    refresh();
    connect(&m_timer, &QTimer::timeout, this, &LiveMedium::refresh);
    // Slow: none of this changes unless somebody runs the tool.
    m_timer.start(15000);
}

void LiveMedium::refresh()
{
    const bool wasLive = m_live;
    const bool wasPersistent = m_persistent;
    const qint64 wasFree = m_freeBytes;

    QFile mounts(QStringLiteral("/proc/mounts"));
    if (!mounts.open(QIODevice::ReadOnly | QIODevice::Text))
        return;
    const QString all = QString::fromUtf8(mounts.readAll());

    // live-boot mounts the image here; on an installed system it does not exist.
    m_live = all.contains(QLatin1String("/run/live/medium"))
             || QDir(QStringLiteral("/run/live/medium")).exists();
    m_persistent = all.contains(QLatin1String("/run/live/persistence"));

    m_device.clear();
    m_freeBytes = 0;

    if (m_live && !m_persistent) {
        /* Which partition is the medium, and therefore which disk. The mount
           line names the partition; its parent is what has the free space. */
        static const QRegularExpression re(
            QStringLiteral("^(/dev/\\S+) /run/live/medium "),
            QRegularExpression::MultilineOption);
        const auto m = re.match(all);
        if (m.hasMatch()) {
            const QString part = QFileInfo(m.captured(1)).fileName();
            const QString parent =
                readFirstLine(QStringLiteral("/sys/class/block/%1/../dev").arg(part)).isEmpty()
                    ? QString() : QString();
            Q_UNUSED(parent)

            // /sys/class/block/sdb1/.. is the disk's directory.
            const QDir partDir(QStringLiteral("/sys/class/block/%1").arg(part));
            const QString diskName = QFileInfo(partDir.absolutePath()).dir().dirName();
            const QString disk = QDir(QStringLiteral("/sys/class/block/%1/..").arg(part))
                                     .canonicalPath()
                                     .section(QLatin1Char('/'), -1);
            Q_UNUSED(diskName)

            if (!disk.isEmpty() && disk != QLatin1String("block")) {
                m_device = QStringLiteral("/dev/") + disk;

                // Sizes are in 512-byte sectors regardless of the real block size.
                const qint64 total =
                    readFirstLine(QStringLiteral("/sys/class/block/%1/size").arg(disk)).toLongLong();

                // The end of the furthest partition, so free space is what is
                // past it rather than the difference of the sums — a gap in
                // the middle is not usable for this.
                qint64 lastEnd = 0;
                const QFileInfoList parts =
                    QDir(QStringLiteral("/sys/class/block/%1").arg(disk))
                        .entryInfoList(QStringList() << disk + QStringLiteral("*"),
                                       QDir::Dirs | QDir::NoDotAndDotDot);
                for (const QFileInfo &p : parts) {
                    const qint64 start =
                        readFirstLine(p.absoluteFilePath() + QStringLiteral("/start")).toLongLong();
                    const qint64 size =
                        readFirstLine(p.absoluteFilePath() + QStringLiteral("/size")).toLongLong();
                    lastEnd = qMax(lastEnd, start + size);
                }

                if (total > lastEnd && lastEnd > 0)
                    m_freeBytes = (total - lastEnd) * 512;
            }
        }
    }

    if (wasLive != m_live || wasPersistent != m_persistent || wasFree != m_freeBytes)
        emit changed();
}

QString LiveMedium::freeHuman() const
{
    const double gb = double(m_freeBytes) / (1024.0 * 1024.0 * 1024.0);
    if (gb >= 1.0)
        return QString::number(gb, 'f', gb >= 10 ? 0 : 1) + QStringLiteral(" GB");
    return QString::number(m_freeBytes / (1024 * 1024)) + QStringLiteral(" MB");
}

bool LiveMedium::canOffer() const
{
    return m_live && !m_persistent && m_freeBytes >= MIN_USEFUL;
}

void LiveMedium::openSetup()
{
    /* A terminal, not a silent command. The script names the device and its
       size and asks for the word ERASE, and that confirmation is the point —
       a one-click path to repartitioning the disk you booted from is not
       something to build. */
    QProcess::startDetached(QStringLiteral("foot"),
                            {QStringLiteral("-T"), QStringLiteral("Persistence"),
                             QStringLiteral("sh"), QStringLiteral("-c"),
                             QStringLiteral("sudo symbiote-persist auto; "
                                            "echo; exec ${SHELL:-sh}")});
}
