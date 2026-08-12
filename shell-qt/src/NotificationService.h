#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantMap>

/*
 * org.freedesktop.Notifications, so applications can say something.
 *
 * The desktop already had somewhere to put a message — a stack above the
 * taskbar, with a colour for failures — and only the shell could ever put one
 * there. Nothing implemented the bus name every application on Linux uses to
 * raise a notification, so a download finishing, a disk being ready to remove,
 * a background job failing: all of it happened in silence. `notify-send` was
 * not even installed, which is a fair summary of the situation.
 *
 * This is the small, honest half of the spec:
 *
 *  - Notify and CloseNotification work, with replacement by id.
 *  - GetCapabilities reports "body" and nothing more, because that is the
 *    truth. Claiming "actions" would make applications draw buttons that this
 *    desktop has nowhere to put and that would never be clicked; claiming
 *    "body-markup" would print raw tags at the operator.
 *  - Urgency is read, and only to decide whether the message is shown in the
 *    error colour. Timeouts are honoured when given.
 *
 * The service is claimed with no queueing and no replacement. If something
 * else on the bus already owns the name, that thing is the notification
 * daemon and this quietly is not — two daemons both showing every message is
 * worse than one showing them.
 */
class NotificationService : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
    /** False when the bus name belonged to something else. */
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit NotificationService(QObject *parent = nullptr);

    bool active() const { return m_active; }

signals:
    /* A message to show. `id` identifies it so a later Notify can replace it
       in place — progress dialogs rewrite the same notification repeatedly. */
    void posted(uint id, const QString &appName, const QString &summary,
                const QString &body, bool error, int timeoutMs);
    void revoked(uint id);

    void activeChanged();

    // org.freedesktop.Notifications
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &actionKey);

public slots:
    uint Notify(const QString &app_name, uint replaces_id, const QString &app_icon,
                const QString &summary, const QString &body,
                const QStringList &actions, const QVariantMap &hints,
                int expire_timeout);
    void CloseNotification(uint id);
    QStringList GetCapabilities();
    QString GetServerInformation(QString &vendor, QString &version, QString &spec_version);

private:
    bool m_active = false;
    uint m_next = 1;
};
