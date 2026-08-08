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

    QStringList openIds() const { return m_open.keys(); }
    QStringList startingIds() const { return m_starting.values(); }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void launch(const QString &id);
    Q_INVOKABLE void close(const QString &id);
    Q_INVOKABLE bool isInstalled(const QString &id) const;

    /* Everything the system actually installed, read from its XDG desktop
       entries. The curated list is nine tools chosen by hand; the image ships
       a few hundred, and a launcher that cannot find Wireshark while Wireshark
       is on the machine is lying about what the machine has. */
    Q_PROPERTY(QVariantList discovered READ discovered CONSTANT)
    QVariantList discovered() const { return m_discovered; }
    /* Resolve an icon name from a desktop entry to a file on disk. Empty when
       nothing matches, which is the signal to fall back to a drawn glyph. */
    Q_INVOKABLE QString findIcon(const QString &name) const;

    /** Launch a discovered entry by its Exec line. */
    Q_INVOKABLE void launchCommand(const QString &id, const QString &exec);


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
    QHash<QString, QProcess *> m_open;
    QString m_lastError;
    QVariantList m_discovered;
    QSet<QString> m_starting;

    void scanDesktopEntries();
};
