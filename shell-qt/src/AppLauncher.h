#pragma once
#include <QObject>
#include <QHash>
#include <QStringList>
#include <QProcess>
#include <QVariantList>
#include <QVariantMap>
#include <QSet>

/*
 * Real application launching.
 *
 * Arguments are passed as a list, never through a shell, so there is no
 * quoting to get wrong and no injection surface. Processes are detached so
 * restarting the shell does not close the user's windows, and stderr is kept
 * rather than discarded — silently dropping it is what made a failed launch
 * look like a dead icon.
 */
class AppLauncher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList openIds READ openIds NOTIFY openChanged)
    /* Launched but not yet on screen. Firefox takes about ten seconds to draw
       its first window on this hardware; without this the interface looks
       identical before and after the click, so people click again. */
    Q_PROPERTY(QStringList startingIds READ startingIds NOTIFY openChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY errorChanged)

public:
    explicit AppLauncher(QObject *parent = nullptr);

    /* Unique ids, not one entry per window: the taskbar shows one tile per
       application however many of its windows are open. */
    QStringList openIds() const;
    QStringList startingIds() const { return m_starting.values(); }
    QString lastError() const { return m_lastError; }

    /* Start the application, or do nothing if it is already running. This is
       what a keyboard shortcut and a single click on the dock use. */
    Q_INVOKABLE void launch(const QString &id);
    /* Start another copy, whether or not one is running.
     *
     * The launcher refused outright to run a second instance — one terminal,
     * one file manager, one browser window, and a click on a running tile
     * killed it instead. Wanting two terminals side by side is not an exotic
     * request; it is most of what a terminal is for. */
    Q_INVOKABLE void launchNew(const QString &id);
    /** How many copies of this application the shell has running. */
    Q_INVOKABLE int instanceCount(const QString &id) const;
    /* Closes the most recently started copy, not all of them. Closing every
       terminal because one tile was clicked is not something to do by
       accident. */
    Q_INVOKABLE void close(const QString &id);
    Q_INVOKABLE bool isInstalled(const QString &id) const;

    /* Everything the system actually installed, read from its XDG desktop
       entries. The curated list is nine tools chosen by hand; the image ships
       a few hundred, and a launcher that cannot find Wireshark while Wireshark
       is on the machine is lying about what the machine has. */
    Q_PROPERTY(QVariantList discovered READ discovered CONSTANT)
    QVariantList discovered() const { return m_discovered; }

    /* Command-line security tools that ship no desktop entry.
     *
     * Almost none of them do. nmap, sqlmap, hydra, aircrack-ng and the rest
     * are programs you type, so a launcher built purely from .desktop files
     * shows an image advertised as a security distribution with almost no
     * security tools in it. These are looked up on PATH and opened in a
     * terminal that stays after the command exits. */
    Q_PROPERTY(QVariantList tools READ tools CONSTANT)
    QVariantList tools() const { return m_tools; }

    /* The tool categories that actually have something in them, in the order
       they should be listed. Kali groups its menu this way and the shape is
       worth borrowing: an operator looks for "something that scans a network",
       not for a program whose name they already know. */
    Q_PROPERTY(QStringList toolCategories READ toolCategories CONSTANT)
    QStringList toolCategories() const { return m_toolCategories; }

    /* Every category, in order, whether or not this image has anything in it.
       The launcher merges the discovered tools with the curated ones, which
       live in QML, so it needs the ordering as well as the subset C++ can
       see. */
    Q_PROPERTY(QStringList categoryOrder READ categoryOrder CONSTANT)
    QStringList categoryOrder() const;
    /* Resolve an icon name from a desktop entry to a file on disk. Empty when
       nothing matches, which is the signal to fall back to a drawn glyph. */
    Q_INVOKABLE QString findIcon(const QString &name) const;

    /** Launch a discovered entry by its Exec line. */
    Q_INVOKABLE void launchCommand(const QString &id, const QString &exec);

    /* Open a command-line tool in a terminal that stays open afterwards.
       `probe` is the harmless invocation that prints its usage, so the window
       has something in it rather than a bare prompt. */
    Q_INVOKABLE void launchInTerminal(const QString &id, const QString &title,
                                      const QString &probe);


    /* Errors are read-only to QML deliberately — nothing outside should be
       able to invent one — but they do need clearing once shown, and
       assigning to a read-only property fails silently at runtime. It had
       been failing since the Wi-Fi panel first tried it. */
    Q_INVOKABLE void clearError();

signals:
    void openChanged();
    void errorChanged();

private:
    struct Entry { QString cmd; QStringList args; };
    QHash<QString, Entry> m_catalog;
    /* Multi: one application, many windows. This was a plain QHash, which
       structurally allowed exactly one process per id — the "already running,
       do nothing" checks were only enforcing what the container required. */
    QMultiHash<QString, QProcess *> m_open;
    /* Set only for the duration of launchNew(), so the launch paths skip their
       "one copy is enough" check. */
    bool m_forceNew = false;
    QString m_lastError;
    QVariantList m_discovered;
    QVariantList m_tools;
    QStringList m_toolCategories;
    QSet<QString> m_starting;

    void scanDesktopEntries();
    void scanCommandLineTools();
};
