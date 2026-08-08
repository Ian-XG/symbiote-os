#include "AppLauncher.h"
#include <QDateTime>

#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QTimer>
#include <QSet>

/* How long an application may take to put something on screen before the shell
   stops claiming it is still starting. Generous on purpose: reporting
   "started" while the user still sees nothing is the failure this exists to
   prevent, and an indicator that lingers is cheaper than one that lies. */
static constexpr int STARTING_GRACE_MS = 12000;

AppLauncher::AppLauncher(QObject *parent) : QObject(parent)
{
    m_catalog = {
        // Built into the shell: no binary, so nothing to look for on PATH.
        {"settings", {"", {}}},
        {"files",    {"nautilus", {"--new-window"}}},
        /* Calamares needs root and asks polkit for it itself; the wrapper is
           what the Debian package installs for exactly that. */
        {"install",  {"calamares-install-debian", {}}},
        {"terminal", {"foot", {}}},
        {"browser",  {"firefox", {}}},
        {"trash",    {"nautilus", {"trash:///"}}},
        // CLI tools open inside a terminal that stays after the command exits,
        // rather than flashing a window and vanishing.
        {"nmap",     {"foot", {"-T", "Network Scan", "sh", "-c", "nmap --help; exec ${SHELL:-sh}"}}},
        {"vuln",     {"foot", {"-T", "Vuln Scanner", "sh", "-c", "nikto -Help 2>&1 | head -20; exec ${SHELL:-sh}"}}},
        {"monitor",  {"foot", {"-T", "Monitor", "sh", "-c", "exec top"}}},
        {"firewall", {"foot", {"-T", "Firewall", "sh", "-c", "nft list ruleset 2>&1 | head -40; exec ${SHELL:-sh}"}}},
    };

    scanDesktopEntries();
}

/* Find a real icon file for an application.
 *
 * The shell's own furniture — settings, trash, power, the session — stays
 * drawn in the HUD's line vocabulary. Third-party applications get their own
 * icon, because a wall of identical outlines tells you nothing about which one
 * is Firefox.
 *
 * A deliberately small XDG icon lookup: the themes in preference order, then
 * the sizes, then the legacy pixmaps directory. PNG before SVG, since PNG
 * needs no extra Qt plugin to load.
 */
QString AppLauncher::findIcon(const QString &name) const
{
    if (name.isEmpty())
        return QString();

    // An absolute path in Icon= is allowed and means exactly what it says.
    if (name.startsWith(QLatin1Char('/')))
        return QFile::exists(name) ? name : QString();

    static const QStringList themes = {
        QStringLiteral("hicolor"), QStringLiteral("Adwaita"),
        QStringLiteral("gnome"), QStringLiteral("breeze")
    };
    // Largest first: these are drawn at 24-30px but on a 2x panel that is 60.
    static const QStringList sizes = {
        QStringLiteral("128x128"), QStringLiteral("96x96"),
        QStringLiteral("64x64"), QStringLiteral("48x48"),
        QStringLiteral("scalable"), QStringLiteral("32x32")
    };
    static const QStringList exts = {
        QStringLiteral("png"), QStringLiteral("svg"), QStringLiteral("xpm")
    };
    static const QStringList roots = {
        QStringLiteral("/usr/share/icons"),
        QStringLiteral("/usr/local/share/icons"),
        QDir::homePath() + QStringLiteral("/.local/share/icons")
    };

    for (const QString &root : roots) {
        for (const QString &theme : themes) {
            for (const QString &size : sizes) {
                for (const QString &ext : exts) {
                    const QString path = QStringLiteral("%1/%2/%3/apps/%4.%5")
                                             .arg(root, theme, size, name, ext);
                    if (QFile::exists(path))
                        return path;
                }
            }
        }
    }

    for (const QString &ext : exts) {
        const QString path = QStringLiteral("/usr/share/pixmaps/%1.%2").arg(name, ext);
        if (QFile::exists(path))
            return path;
    }

    return QString();
}

/* Pick one of the shell's drawn glyphs for a discovered application.
 *
 * Everything here is drawn in the same line vocabulary — no theme icons, no
 * colour — so hundreds of entries would otherwise all wear the same window
 * outline and the grid would be a wall of identical squares. Categories come
 * from the desktop entry itself and are the closest thing to a declared
 * purpose; the binary name catches the well-known tools whose categories are
 * too generic to help.
 */
static QString glyphFor(const QString &bin, const QString &categories,
                        const QString &name)
{
    const QString c = categories.toLower();
    const QString b = bin.toLower();
    const QString n = name.toLower();

    auto any = [](const QString &hay, std::initializer_list<const char *> needles) {
        for (const char *nd : needles)
            if (hay.contains(QLatin1String(nd)))
                return true;
        return false;
    };

    if (any(b, {"nmap", "zenmap", "wireshark", "tshark", "tcpdump", "masscan",
                "netdiscover", "kismet"})
        || any(n, {"scan", "packet", "capture"}))
        return QStringLiteral("radar");

    if (any(b, {"nikto", "sqlmap", "dirb", "gobuster", "hydra", "john",
                "hashcat", "metasploit", "burp"})
        || any(n, {"vuln", "exploit", "crack", "brute"}))
        return QStringLiteral("bug");

    if (any(b, {"ufw", "gufw", "firewall", "openvpn", "wireguard", "proxychains"})
        || any(c, {"security"}))
        return QStringLiteral("shield");

    if (any(b, {"foot", "xterm", "alacritty", "kitty", "konsole", "gnome-terminal"})
        || any(c, {"terminalemulator"}))
        return QStringLiteral("terminal");

    if (any(b, {"firefox", "chromium", "chrome", "epiphany", "brave"})
        || any(c, {"webbrowser"}))
        return QStringLiteral("browser");

    if (any(b, {"nautilus", "thunar", "dolphin", "pcmanfm", "nemo"})
        || any(c, {"filemanager"}))
        return QStringLiteral("files");

    if (any(b, {"htop", "top", "gnome-system-monitor", "baobab"})
        || any(c, {"monitor"}))
        return QStringLiteral("pulse");

    if (any(c, {"settings", "preferences", "hardwaresettings"}))
        return QStringLiteral("settings");

    // Nothing recognised: the plain window outline.
    return QStringLiteral("app");
}

/* Reads the freedesktop desktop-entry files. Deliberately a small parser
   rather than a dependency: the fields that matter here are Name, Exec, and
   the two flags that say "do not show me". */
void AppLauncher::scanDesktopEntries()
{
    const QStringList dirs = {
        QStringLiteral("/usr/share/applications"),
        QStringLiteral("/usr/local/share/applications"),
        QDir::homePath() + QStringLiteral("/.local/share/applications")
    };

    QSet<QString> seen;
    for (const QString &dir : dirs) {
        const QFileInfoList files = QDir(dir).entryInfoList({QStringLiteral("*.desktop")},
                                                            QDir::Files);
        for (const QFileInfo &fi : files) {
            QFile f(fi.absoluteFilePath());
            if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
                continue;

            QString name, exec, categories, iconName;
            bool hidden = false, inDesktopEntry = false;
            QTextStream in(&f);
            while (!in.atEnd()) {
                const QString line = in.readLine().trimmed();
                if (line.startsWith(QLatin1Char('['))) {
                    // Only the main group; the Actions groups have their own Name/Exec.
                    inDesktopEntry = (line == QLatin1String("[Desktop Entry]"));
                    continue;
                }
                if (!inDesktopEntry)
                    continue;
                if (line.startsWith(QLatin1String("Name=")) && name.isEmpty())
                    name = line.mid(5);
                else if (line.startsWith(QLatin1String("Exec=")) && exec.isEmpty())
                    exec = line.mid(5);
                else if (line.startsWith(QLatin1String("Categories=")))
                    categories = line.mid(11);
                else if (line.startsWith(QLatin1String("Icon=")) && iconName.isEmpty())
                    iconName = line.mid(5);
                else if (line == QLatin1String("NoDisplay=true")
                         || line == QLatin1String("Hidden=true"))
                    hidden = true;
                else if (line.startsWith(QLatin1String("Type="))
                         && line.mid(5) != QLatin1String("Application"))
                    hidden = true;
            }

            if (hidden || name.isEmpty() || exec.isEmpty())
                continue;

            /* Strip the field codes (%f, %U, …). They are placeholders for
               files being opened, and passing them through literally makes the
               program receive an argument called "%U". */
            exec.remove(QRegularExpression(QStringLiteral("%[a-zA-Z]")));
            exec = exec.trimmed();
            if (exec.isEmpty())
                continue;

            // The binary has to exist; a stale entry is worse than no entry.
            const QString bin = exec.split(QLatin1Char(' '), Qt::SkipEmptyParts).value(0);
            if (QStandardPaths::findExecutable(bin).isEmpty())
                continue;

            const QString key = name.toLower();
            if (seen.contains(key))
                continue;
            seen.insert(key);

            QVariantMap row;
            row["id"] = QStringLiteral("xdg:") + fi.completeBaseName();
            row["title"] = name.toUpper();
            row["short"] = name.toUpper();
            row["exec"] = exec;
            row["categories"] = categories;
            row["glyph"] = glyphFor(bin, categories, name);
            // Empty when the theme has nothing: QML falls back to the glyph.
            row["icon"] = findIcon(iconName);
            row["code"] = bin.left(8).toUpper();
            m_discovered.append(row);
        }
    }

    std::sort(m_discovered.begin(), m_discovered.end(),
              [](const QVariant &a, const QVariant &b) {
        return a.toMap()["title"].toString() < b.toMap()["title"].toString();
    });
}

void AppLauncher::launchCommand(const QString &id, const QString &exec)
{
    const QStringList parts = exec.split(QLatin1Char(' '), Qt::SkipEmptyParts);
    if (parts.isEmpty())
        return;
    if (m_open.contains(id))
        return;

    auto *p = new QProcess(this);
    auto env = QProcessEnvironment::systemEnvironment();
    env.insert("GDK_BACKEND", "wayland");
    env.insert("QT_QPA_PLATFORM", "wayland");
    p->setProcessEnvironment(env);
    p->setProcessChannelMode(QProcess::SeparateChannels);

    connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this, id, p](int, QProcess::ExitStatus) {
        m_open.remove(id);
        m_starting.remove(id);
        p->deleteLater();
        emit openChanged();
    });

    p->start(parts.first(), parts.mid(1));
    m_open.insert(id, p);

    m_starting.insert(id);
    QTimer::singleShot(STARTING_GRACE_MS, this, [this, id] {
        if (m_starting.remove(id))
            emit openChanged();
    });
    emit openChanged();
}



bool AppLauncher::isInstalled(const QString &id) const
{
    if (!m_catalog.contains(id))
        return false;
    // An empty command means the shell provides it itself.
    if (m_catalog[id].cmd.isEmpty())
        return true;
    return !QStandardPaths::findExecutable(m_catalog[id].cmd).isEmpty();
}

void AppLauncher::launch(const QString &id)
{
    if (!m_catalog.contains(id)) {
        m_lastError = QStringLiteral("Unknown app: %1").arg(id);
        emit errorChanged();
        return;
    }
    if (m_open.contains(id))
        return;

    const Entry &e = m_catalog[id];
    if (QStandardPaths::findExecutable(e.cmd).isEmpty()) {
        m_lastError = QStringLiteral("%1 is not installed").arg(e.cmd);
        emit errorChanged();
        return;
    }

    auto *p = new QProcess(this);
    auto env = QProcessEnvironment::systemEnvironment();
    env.insert("GDK_BACKEND", "wayland");
    env.insert("QT_QPA_PLATFORM", "wayland");
    p->setProcessEnvironment(env);
    p->setProcessChannelMode(QProcess::SeparateChannels);

    connect(p, &QProcess::errorOccurred, this, [this, id, p](QProcess::ProcessError) {
        /* "execve: Input/output error" means the kernel could not read the
           program off the disk. On a live image that is the medium failing,
           not the application — the desktop keeps running because it is
           already in memory, and only new launches die. Saying so is the
           difference between a diagnosis and a riddle. */
        const QString why = p->errorString();
        m_lastError = why.contains(QLatin1String("Input/output error"))
            ? QStringLiteral("%1 could not be read from the boot medium. "
                             "The USB stick is failing or was flashed "
                             "incompletely — reflash it, ideally on another "
                             "stick.").arg(id)
            : QStringLiteral("%1: %2").arg(id, why);
        m_open.remove(id);
        m_starting.remove(id);
        emit errorChanged();
        emit openChanged();
    });

    connect(p, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this, id, p](int code, QProcess::ExitStatus) {
        // Dying immediately means it never really started; a later exit is the
        // user closing the window, which is not a failure.
        if (code != 0 && p->property("startedAt").toLongLong()
                + 5000 > QDateTime::currentMSecsSinceEpoch()) {
            /* Warnings are not failures. foot writes "compositor does not
               implement the XDG toplevel icon protocol" and "slave exited with
               signal 1 (Hangup)" on an ordinary close, and both were being
               raised as a red banner across the desktop. Keep only lines that
               are not self-declared warnings; if nothing is left, the process
               had nothing to complain about worth showing. */
            const QString raw = QString::fromUtf8(p->readAllStandardError()).trimmed();
            QStringList real;
            const QStringList lines = raw.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const QString &line : lines) {
                const QString l = line.trimmed();
                if (l.contains(QLatin1String("warn:"), Qt::CaseInsensitive)
                    || l.startsWith(QLatin1String("Warning"), Qt::CaseInsensitive)
                    || l.startsWith(QLatin1String("WARNING"))) {
                    continue;
                }
                real << l;
            }
            if (!real.isEmpty()) {
                m_lastError = QStringLiteral("%1: %2").arg(id, real.last());
                emit errorChanged();
            }
        }
        m_open.remove(id);
        m_starting.remove(id);
        p->deleteLater();
        emit openChanged();
    });

    p->setProperty("startedAt", QDateTime::currentMSecsSinceEpoch());
    p->start(e.cmd, e.args);
    m_open.insert(id, p);

    m_starting.insert(id);
    QTimer::singleShot(STARTING_GRACE_MS, this, [this, id] {
        if (m_starting.remove(id))
            emit openChanged();
    });
    emit openChanged();
}

void AppLauncher::close(const QString &id)
{
    if (!m_open.contains(id))
        return;
    QProcess *p = m_open[id];
    p->terminate();                 // SIGTERM so the app can save
    QTimer::singleShot(3000, p, [p] {
        if (p->state() != QProcess::NotRunning)
            p->kill();
    });
}

void AppLauncher::clearError()
{
    if (m_lastError.isEmpty())
        return;
    m_lastError.clear();
    emit errorChanged();
}
