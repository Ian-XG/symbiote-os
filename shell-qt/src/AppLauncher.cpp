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
        {"vuln",     {"foot", {"-T", "Vuln Scanner", "sh", "-c", "wapiti --help 2>&1 | head -20; exec ${SHELL:-sh}"}}},
        {"monitor",  {"foot", {"-T", "Monitor", "sh", "-c", "exec top"}}},
        /* PentAI asks for a provider and a key on first run, so it opens in a
           terminal that stays after it exits — otherwise the wizard would
           flash past and the window would vanish. */
        {"pentai",   {"foot", {"-T", "PentAI", "sh", "-c",
                               "pentai; echo; echo '[PentAI exited]'; exec ${SHELL:-sh}"}}},
        {"firewall", {"foot", {"-T", "Firewall", "sh", "-c", "nft list ruleset 2>&1 | head -40; exec ${SHELL:-sh}"}}},
    };

    scanDesktopEntries();
    scanCommandLineTools();
}

/* ── how the launcher decides what something is ────────────────────────────
 *
 * Two axes, and they answer two different questions.
 *
 * `kind` is "app" or "tool": is this something you use, or something you point
 * at a target? A launcher that mixes a text editor in with a password cracker
 * on one alphabetical wall makes both harder to find, which is why Kali splits
 * its menu the same way.
 *
 * `category` is where a tool sits within that: what job it does, not what it is
 * called. An operator looking for a way to see traffic on the wire does not
 * know in advance whether this machine has tcpdump, tshark or both.
 *
 * The categories and their order are Kali's, because that vocabulary is the one
 * anyone doing this work already has. The names are shortened — a sidebar has
 * about eighteen characters, and "Information Gathering" is what the long form
 * would be truncated to anyway.
 */
namespace {

const char *const TOOL_CATEGORY_ORDER[] = {
    "RECON",          // information gathering
    "VULNERABILITY",  // vulnerability analysis
    "WEB",            // web application analysis
    "DATABASE",       // database assessment
    "PASSWORDS",      // password attacks
    "WIRELESS",       // wireless attacks
    "EXPLOITATION",   // exploitation tools
    "SNIFFING",       // sniffing and spoofing
    "POST",           // post exploitation
    "REVERSING",      // reverse engineering
    "FORENSICS",      // forensics
    "ANONYMITY",      // tunnels, VPNs, proxies
    "DEFENSE",        // the local machine's own posture
    "ASSISTANT",      // PentAI: reasons about the rest of this list
    "OTHER",
};

bool contains(const QString &hay, std::initializer_list<const char *> needles)
{
    for (const char *n : needles)
        if (hay.contains(QLatin1String(n)))
            return true;
    return false;
}

/* The security category a program belongs to, or an empty string when it is an
   ordinary application. Matched on the binary name first, because that is the
   one identifier that does not change between distributions. */
QString toolCategory(const QString &bin, const QString &categories, const QString &name)
{
    const QString b = bin.toLower();
    const QString c = categories.toLower();
    const QString n = name.toLower();

    if (contains(b, {"nmap", "zenmap", "masscan", "netdiscover", "whois", "dig",
                     "host", "nslookup", "dnsenum", "dnsrecon", "fierce",
                     "theharvester", "recon-ng", "amass", "arp-scan", "sublist3r",
                     "traceroute", "nbtscan", "onesixtyone", "snmpwalk"})
        || contains(n, {"port scan", "dns lookup", "network discovery"}))
        return QStringLiteral("RECON");

    if (contains(b, {"nikto", "openvas", "lynis", "nuclei", "wpscan", "legion",
                     "searchsploit", "vulscan"})
        || contains(n, {"vulnerability"}))
        return QStringLiteral("VULNERABILITY");

    if (contains(b, {"dirb", "gobuster", "ffuf", "feroxbuster", "wfuzz", "burp",
                     "zaproxy", "whatweb", "wafw00f", "commix", "skipfish",
                     "cadaver", "davtest"}))
        return QStringLiteral("WEB");

    if (contains(b, {"sqlmap", "sqlninja", "jsql", "mdb-", "sqlite3", "mysql",
                     "psql", "sqlitebrowser"}))
        return QStringLiteral("DATABASE");

    if (contains(b, {"hydra", "john", "hashcat", "medusa", "ncrack", "crunch",
                     "cewl", "hashid", "ophcrack", "chntpw", "patator",
                     "hash-identifier", "rsmangler", "wordlists"}))
        return QStringLiteral("PASSWORDS");

    if (contains(b, {"aircrack", "airodump", "aireplay", "airmon", "airbase",
                     "kismet", "reaver", "bully", "wifite", "fern", "mdk4",
                     "hcxdumptool", "hcxtools", "bettercap", "pixiewps"}))
        return QStringLiteral("WIRELESS");

    if (contains(b, {"msfconsole", "msfvenom", "metasploit", "armitage",
                     "beef", "exploitdb", "sqlbrute", "routersploit",
                     "setoolkit", "social-engineer"}))
        return QStringLiteral("EXPLOITATION");

    if (contains(b, {"wireshark", "tshark", "tcpdump", "ettercap", "dsniff",
                     "responder", "mitmproxy", "netsniff", "driftnet",
                     "sslsplit", "sslstrip", "macchanger", "arpspoof"}))
        return QStringLiteral("SNIFFING");

    if (contains(b, {"mimikatz", "powersploit", "empire", "weevely", "chisel",
                     "socat", "netcat", "nc", "ncat", "rlwrap", "pwncat"}))
        return QStringLiteral("POST");

    if (contains(b, {"ghidra", "radare2", "r2", "gdb", "objdump", "cutter",
                     "hexedit", "ltrace", "strace", "edb", "jadx", "apktool",
                     "binwalk", "hopper"}))
        return QStringLiteral("REVERSING");

    if (contains(b, {"autopsy", "sleuthkit", "volatility", "foremost", "scalpel",
                     "testdisk", "photorec", "bulk_extractor", "dc3dd",
                     "guymager", "exiftool", "steghide", "ddrescue"}))
        return QStringLiteral("FORENSICS");

    if (contains(b, {"openvpn", "wg", "wg-quick", "proxychains", "proxychains4",
                     "tor", "torbrowser", "obfs4proxy", "sshuttle"}))
        return QStringLiteral("ANONYMITY");

    if (contains(b, {"nft", "iptables", "ufw", "gufw", "firewalld", "aa-status",
                     "apparmor", "fail2ban", "clamav", "rkhunter", "chkrootkit",
                     "cryptsetup", "lynis"}))
        return QStringLiteral("DEFENSE");

    /* A desktop entry that declares itself Security but names nothing we
       recognise is still a tool — better in OTHER than filed as an ordinary
       application, where nobody hunting for it would look. */
    if (contains(c, {"security", "pentest", "forensic"}))
        return QStringLiteral("OTHER");

    return QString();
}

} // namespace

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

            const QString cat = toolCategory(bin, categories, name);
            row["kind"] = cat.isEmpty() ? QStringLiteral("app") : QStringLiteral("tool");
            row["category"] = cat;

            m_discovered.append(row);
        }
    }

    std::sort(m_discovered.begin(), m_discovered.end(),
              [](const QVariant &a, const QVariant &b) {
        return a.toMap()["title"].toString() < b.toMap()["title"].toString();
    });
}

/* The tools you type.
 *
 * Nearly every program in security.list.chroot ships no desktop entry, because
 * it has no window: nmap, sqlmap, hydra, aircrack-ng, tcpdump. Built purely
 * from .desktop files the launcher showed a distribution advertised as being
 * for security work with essentially no security tools in it — they were all
 * installed, and all invisible.
 *
 * Each entry names the binary to look for, where it belongs, and a probe: the
 * harmless invocation that prints its usage, so the terminal opens with the
 * tool's own help rather than a bare prompt. Nothing here is run at scan time;
 * the probe is the command the window starts with when the tile is clicked.
 *
 * Anything not installed is simply absent — the list is filtered against PATH,
 * so an image built without a package does not advertise it.
 */
void AppLauncher::scanCommandLineTools()
{
    struct Tool {
        const char *bin;
        const char *title;
        const char *category;
        const char *glyph;
        const char *probe;      // empty: just open a shell with the tool ready
        /* The icon this tool ships, when it ships one. Wireshark, Ghidra and
           Zenmap install a real icon into the theme and are recognised by it;
           the shell's drawn glyphs are for its own furniture and for the
           hundred tools that have no logo at all. Empty means "look under the
           binary's own name", which is where most of them put it. */
        const char *iconName;
    };

    static const Tool TOOLS[] = {
        // ── recon ─────────────────────────────────────────────────────────
        {"nmap",        "NMAP",         "RECON",         "radar",    "nmap --help", "nmap"},
        {"masscan",     "MASSCAN",      "RECON",         "radar",    "masscan --help 2>&1 | head -40", ""},
        {"whois",       "WHOIS",        "RECON",         "radar",    "whois --help 2>&1 | head -20", ""},
        {"dig",         "DIG",          "RECON",         "radar",    "dig -h 2>&1 | head -30", ""},
        {"host",        "HOST",         "RECON",         "radar",    "host 2>&1 | head -20", ""},
        {"dnsrecon",    "DNSRECON",     "RECON",         "radar",    "dnsrecon --help 2>&1 | head -30", ""},
        {"dnsenum",     "DNSENUM",      "RECON",         "radar",    "dnsenum --help 2>&1 | head -30", ""},
        {"theHarvester","THEHARVESTER", "RECON",         "radar",    "theHarvester --help 2>&1 | head -35", ""},
        {"netdiscover", "NETDISCOVER",  "RECON",         "radar",    "netdiscover -h 2>&1 | head -25", ""},
        {"arp-scan",    "ARP SCAN",     "RECON",         "radar",    "arp-scan --help 2>&1 | head -30", ""},
        {"fping",       "FPING",        "RECON",         "radar",    "fping -h 2>&1 | head -30", ""},
        {"traceroute",  "TRACEROUTE",   "RECON",         "radar",    "traceroute --help 2>&1 | head -25", ""},
        {"nbtscan",     "NBTSCAN",      "RECON",         "radar",    "nbtscan -h 2>&1 | head -25", ""},
        {"smbclient",   "SMBCLIENT",    "RECON",         "radar",    "smbclient --help 2>&1 | head -30", ""},

        // ── vulnerability ─────────────────────────────────────────────────
        {"nikto",       "NIKTO",        "VULNERABILITY", "bug",      "nikto -Help 2>&1 | head -30", ""},
        {"wapiti",      "WAPITI",       "VULNERABILITY", "bug",      "wapiti --help 2>&1 | head -30", ""},
        {"sslscan",     "SSLSCAN",      "VULNERABILITY", "bug",      "sslscan --help 2>&1 | head -30", ""},
        {"lynis",       "LYNIS",        "VULNERABILITY", "bug",      "lynis show help 2>&1 | head -30", ""},

        // ── web ───────────────────────────────────────────────────────────
        {"dirb",        "DIRB",         "WEB",           "bug",      "dirb 2>&1 | head -25", ""},
        {"gobuster",    "GOBUSTER",     "WEB",           "bug",      "gobuster --help 2>&1 | head -30", ""},
        {"ffuf",        "FFUF",         "WEB",           "bug",      "ffuf -h 2>&1 | head -40", ""},
        {"wfuzz",       "WFUZZ",        "WEB",           "bug",      "wfuzz --help 2>&1 | head -35", ""},
        {"whatweb",     "WHATWEB",      "WEB",           "bug",      "whatweb --help 2>&1 | head -30", ""},

        // ── database ──────────────────────────────────────────────────────
        {"sqlmap",      "SQLMAP",       "DATABASE",      "database", "sqlmap --help 2>&1 | head -40", ""},

        // ── passwords ─────────────────────────────────────────────────────
        {"hydra",       "HYDRA",        "PASSWORDS",     "key",      "hydra -h 2>&1 | head -40", ""},
        {"john",        "JOHN",         "PASSWORDS",     "key",      "john --help 2>&1 | head -35", ""},
        {"hashcat",     "HASHCAT",      "PASSWORDS",     "key",      "hashcat --help 2>&1 | head -40", "hashcat"},
        {"medusa",      "MEDUSA",       "PASSWORDS",     "key",      "medusa -h 2>&1 | head -35", ""},
        {"ncrack",      "NCRACK",       "PASSWORDS",     "key",      "ncrack --help 2>&1 | head -30", ""},
        {"crunch",      "CRUNCH",       "PASSWORDS",     "key",      "crunch 2>&1 | head -25", ""},
        {"cewl",        "CEWL",         "PASSWORDS",     "key",      "cewl --help 2>&1 | head -30", ""},

        // ── wireless ──────────────────────────────────────────────────────
        {"aircrack-ng", "AIRCRACK-NG",  "WIRELESS",      "wifi",     "aircrack-ng --help 2>&1 | head -35", ""},
        {"airodump-ng", "AIRODUMP-NG",  "WIRELESS",      "wifi",     "airodump-ng --help 2>&1 | head -35", ""},
        {"aireplay-ng", "AIREPLAY-NG",  "WIRELESS",      "wifi",     "aireplay-ng --help 2>&1 | head -35", ""},
        {"airmon-ng",   "AIRMON-NG",    "WIRELESS",      "wifi",     "airmon-ng --help 2>&1 | head -25", ""},
        {"reaver",      "REAVER",       "WIRELESS",      "wifi",     "reaver -h 2>&1 | head -30", ""},
        {"wifite",      "WIFITE",       "WIRELESS",      "wifi",     "wifite --help 2>&1 | head -35", ""},
        {"mdk4",        "MDK4",         "WIRELESS",      "wifi",     "mdk4 --help 2>&1 | head -30", ""},
        {"macchanger",  "MACCHANGER",   "WIRELESS",      "wifi",     "macchanger --help 2>&1 | head -25", ""},

        // ── sniffing ──────────────────────────────────────────────────────
        {"wireshark",   "WIRESHARK",    "SNIFFING",      "pulse",    "", "wireshark"},
        {"tshark",      "TSHARK",       "SNIFFING",      "pulse",    "tshark --help 2>&1 | head -35", ""},
        {"tcpdump",     "TCPDUMP",      "SNIFFING",      "pulse",    "tcpdump --help 2>&1 | head -30", ""},
        {"ettercap",    "ETTERCAP",     "SNIFFING",      "pulse",    "ettercap --help 2>&1 | head -30", "ettercap"},
        {"bettercap",   "BETTERCAP",    "SNIFFING",      "pulse",    "bettercap --help 2>&1 | head -30", ""},
        {"mitmproxy",   "MITMPROXY",    "SNIFFING",      "pulse",    "mitmproxy --help 2>&1 | head -30", ""},
        {"responder",   "RESPONDER",    "SNIFFING",      "pulse",    "responder --help 2>&1 | head -30", ""},

        // ── exploitation ──────────────────────────────────────────────────
        {"searchsploit","SEARCHSPLOIT", "EXPLOITATION",  "bug",      "searchsploit --help 2>&1 | head -30", ""},

        // ── post exploitation ─────────────────────────────────────────────
        {"ncat",        "NCAT",         "POST",          "terminal", "ncat --help 2>&1 | head -35", ""},
        {"nc",          "NETCAT",       "POST",          "terminal", "nc -h 2>&1 | head -25", ""},
        {"socat",       "SOCAT",        "POST",          "terminal", "socat -h 2>&1 | head -30", ""},
        {"rlwrap",      "RLWRAP",       "POST",          "terminal", "rlwrap --help 2>&1 | head -25", ""},

        // ── reverse engineering ───────────────────────────────────────────
        {"r2",          "RADARE2",      "REVERSING",     "bug",      "r2 -h 2>&1 | head -30", ""},
        {"gdb",         "GDB",          "REVERSING",     "bug",      "gdb --help 2>&1 | head -25", ""},
        {"ltrace",      "LTRACE",       "REVERSING",     "bug",      "ltrace --help 2>&1 | head -25", ""},
        {"strace",      "STRACE",       "REVERSING",     "bug",      "strace --help 2>&1 | head -25", ""},
        {"binwalk",     "BINWALK",      "REVERSING",     "bug",      "binwalk --help 2>&1 | head -35", ""},

        // ── forensics ─────────────────────────────────────────────────────
        {"foremost",    "FOREMOST",     "FORENSICS",     "bug",      "foremost -h 2>&1 | head -30", ""},
        {"testdisk",    "TESTDISK",     "FORENSICS",     "bug",      "testdisk /help 2>&1 | head -25", ""},
        {"exiftool",    "EXIFTOOL",     "FORENSICS",     "bug",      "exiftool 2>&1 | head -25", ""},
        {"steghide",    "STEGHIDE",     "FORENSICS",     "bug",      "steghide --help 2>&1 | head -30", ""},

        // ── anonymity ─────────────────────────────────────────────────────
        {"openvpn",     "OPENVPN",      "ANONYMITY",     "shield",   "openvpn --help 2>&1 | head -30", "openvpn"},
        {"wg",          "WIREGUARD",    "ANONYMITY",     "shield",   "wg --help 2>&1 | head -25", ""},
        {"proxychains4","PROXYCHAINS",  "ANONYMITY",     "shield",   "proxychains4 2>&1 | head -20", ""},
        {"tor",         "TOR",          "ANONYMITY",     "shield",   "tor --help 2>&1 | head -25", "tor"},

        // ── defense ───────────────────────────────────────────────────────
        {"nft",         "NFTABLES",     "DEFENSE",       "shield",   "nft list ruleset 2>&1 | head -40", ""},
        {"aa-status",   "APPARMOR",     "DEFENSE",       "shield",   "aa-status 2>&1 | head -30", ""},
        {"cryptsetup",  "CRYPTSETUP",   "DEFENSE",       "shield",   "cryptsetup --help 2>&1 | head -30", ""},

        /* ── the assistants ───────────────────────────────────────────────
           PentAI and Ollama both install a .desktop entry from their hooks,
           so they are already in the discovered list — but only if the hook
           ran, which needs network at build time. Naming them here as well
           means the launcher shows them in the ASSISTANT drawer even on an
           image where the entry did not get written, and the de-duplication
           below drops whichever copy the discovered list already has. */
        {"pentai",      "PENTAI",       "ASSISTANT",     "agent",    "pentai", ""},
        {"ollama",      "OLLAMA",       "ASSISTANT",     "agent",    "ollama-setup", ""},
    };

    /* Everything the curated list already covers, so a tool does not appear
       twice under two names.
     *
     * The curated entries do not name their tool as the command — they run
     * `foot -T "Network Scan" sh -c "nmap --help; …"` — so the binary has to be
     * dug out of the arguments. Without this the launcher showed both NETWORK
     * SCAN and NMAP, which are the same program with two labels. */
    QSet<QString> curated;
    for (auto it = m_catalog.constBegin(); it != m_catalog.constEnd(); ++it) {
        QStringList words = it.value().args;
        words.prepend(it.value().cmd);
        for (const QString &arg : std::as_const(words)) {
            const QStringList tokens = arg.split(QRegularExpression(QStringLiteral("[^A-Za-z0-9_.-]+")),
                                                 Qt::SkipEmptyParts);
            for (const QString &t : tokens)
                curated.insert(t);
        }
    }

    for (const Tool &t : TOOLS) {
        const QString bin = QString::fromLatin1(t.bin);
        if (QStandardPaths::findExecutable(bin).isEmpty())
            continue;   // not in this image

        /* Its own logo when it ships one. Most CLI tools ship none, and fall
           back to the drawn glyph; the few that do — Wireshark, Ettercap, Tor,
           OpenVPN, Nmap's Zenmap — are recognised by their real icon rather
           than wearing the shell's line art over their own brand. The lookup
           tries the declared name first, then the binary's own name, which is
           where a tool that installs an icon usually files it. */
        QString icon = findIcon(QString::fromLatin1(t.iconName));
        if (icon.isEmpty())
            icon = findIcon(bin);

        QVariantMap row;
        row["id"] = QStringLiteral("cli:") + bin;
        row["title"] = QString::fromLatin1(t.title);
        row["short"] = QString::fromLatin1(t.title);
        row["glyph"] = QString::fromLatin1(t.glyph);
        row["icon"] = icon;
        row["code"] = bin.left(8).toUpper();
        row["kind"] = QStringLiteral("tool");
        row["category"] = QString::fromLatin1(t.category);
        row["bin"] = bin;
        row["probe"] = QString::fromLatin1(t.probe);
        m_tools.append(row);
    }

    /* Wireshark and anything else with a real window is already in the
       discovered list; it stays there and is dropped from here, so the same
       program is not two tiles that behave differently. */
    for (int i = m_tools.size() - 1; i >= 0; --i) {
        const QString bin = m_tools.at(i).toMap().value("bin").toString();
        bool duplicate = curated.contains(bin);
        if (!duplicate) {
            for (const QVariant &d : std::as_const(m_discovered)) {
                const QString exec = d.toMap().value("exec").toString();
                if (exec.section(QLatin1Char(' '), 0, 0) == bin) {
                    duplicate = true;
                    break;
                }
            }
        }
        if (duplicate)
            m_tools.removeAt(i);
    }

    // The categories that are actually populated, in the order they read in.
    QSet<QString> present;
    for (const QVariant &t : std::as_const(m_tools))
        present.insert(t.toMap().value("category").toString());
    for (const QVariant &d : std::as_const(m_discovered)) {
        const QVariantMap row = d.toMap();
        if (row.value("kind").toString() == QLatin1String("tool"))
            present.insert(row.value("category").toString());
    }
    for (const char *c : TOOL_CATEGORY_ORDER) {
        const QString name = QString::fromLatin1(c);
        if (present.contains(name))
            m_toolCategories.append(name);
    }
}

QStringList AppLauncher::categoryOrder() const
{
    QStringList out;
    for (const char *c : TOOL_CATEGORY_ORDER)
        out.append(QString::fromLatin1(c));
    return out;
}

void AppLauncher::launchInTerminal(const QString &id, const QString &title,
                                   const QString &probe)
{
    if (m_open.contains(id))
        return;

    /* The shell stays after the command exits. A tool that prints its usage
       and vanishes is worse than useless: the window flashes and the operator
       is left wondering whether anything ran at all. */
    const QString script = probe.isEmpty()
        ? QStringLiteral("exec ${SHELL:-sh}")
        : QStringLiteral("%1; echo; exec ${SHELL:-sh}").arg(probe);

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

    p->start(QStringLiteral("foot"),
             {QStringLiteral("-T"), title, QStringLiteral("sh"),
              QStringLiteral("-c"), script});
    m_open.insert(id, p);

    m_starting.insert(id);
    QTimer::singleShot(STARTING_GRACE_MS, this, [this, id] {
        if (m_starting.remove(id))
            emit openChanged();
    });
    emit openChanged();
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
