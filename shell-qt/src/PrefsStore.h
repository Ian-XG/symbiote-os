#pragma once

#include <QObject>
#include <QSettings>
#include <QStandardPaths>
#include <QDir>

/*
 * Where the operator's choices live between runs.
 *
 * Everything in Settings — the accent, the scale, which icons are on the
 * desktop, what is pinned to the bar — was held in QML properties and lost the
 * moment the shell restarted. On a live image that was academic; with a
 * persistence partition it is the difference between settings that mean
 * something and settings that are theatre.
 *
 * Deliberately dumb: a flat key/value file. Nothing here is worth a schema,
 * and a corrupt file should cost the defaults, not the session.
 */
class PrefsStore : public QObject
{
    Q_OBJECT

public:
    explicit PrefsStore(QObject *parent = nullptr)
        : QObject(parent)
        , m_settings(configPath(), QSettings::IniFormat)
    {
    }

    Q_INVOKABLE QVariant value(const QString &key, const QVariant &fallback) const
    {
        return m_settings.value(key, fallback);
    }

    Q_INVOKABLE void setValue(const QString &key, const QVariant &v)
    {
        if (m_settings.value(key) == v)
            return;
        m_settings.setValue(key, v);
        /* Written through on every change rather than at exit. A shell that is
           killed — or a machine whose power button is held — must not be the
           reason a setting is forgotten. */
        m_settings.sync();
    }

    /** Where the file actually is, for the About panel to state plainly. */
    Q_INVOKABLE QString path() const { return m_settings.fileName(); }

    /** True when the file survives a reboot, which on a live image it may not. */
    Q_INVOKABLE bool persistent() const
    {
        // live-boot mounts the persistence overlay over /; if the config
        // directory is on a tmpfs, nothing written here outlives the session.
        QFile mounts(QStringLiteral("/proc/mounts"));
        if (!mounts.open(QIODevice::ReadOnly | QIODevice::Text))
            return false;
        const QString all = QString::fromUtf8(mounts.readAll());
        return all.contains(QLatin1String("/lib/live/mount/persistence"))
               || all.contains(QLatin1String("persistence"));
    }

private:
    static QString configPath()
    {
        const QString dir =
            QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
        QDir().mkpath(dir);
        return dir + QStringLiteral("/shell.conf");
    }

    QSettings m_settings;
};
