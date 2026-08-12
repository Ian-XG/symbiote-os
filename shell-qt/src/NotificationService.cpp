#include "NotificationService.h"

#include <QDBusConnection>

namespace {
constexpr auto SERVICE = "org.freedesktop.Notifications";
constexpr auto PATH = "/org/freedesktop/Notifications";

/* Urgency 2 is "critical" in the spec. Everything below it is ordinary. The
   desktop has one distinction to make — is this a failure — and this is it. */
constexpr int URGENCY_CRITICAL = 2;
} // namespace

NotificationService::NotificationService(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::sessionBus();

    if (!bus.registerObject(QLatin1String(PATH), this,
                            QDBusConnection::ExportAllSlots
                                | QDBusConnection::ExportAllSignals)) {
        qWarning("notifications: could not export the object on the session bus");
        return;
    }

    /* No QueueService, no ReplaceExistingService. If another daemon holds the
       name it is the one people are already reading; adding a second one that
       also draws every message helps nobody. */
    if (!bus.registerService(QLatin1String(SERVICE))) {
        qWarning("notifications: %s is already owned — not serving", SERVICE);
        bus.unregisterObject(QLatin1String(PATH));
        return;
    }

    m_active = true;
    emit activeChanged();
}

uint NotificationService::Notify(const QString &app_name, uint replaces_id,
                                 const QString &app_icon, const QString &summary,
                                 const QString &body, const QStringList &actions,
                                 const QVariantMap &hints, int expire_timeout)
{
    Q_UNUSED(app_icon)
    /* Actions are accepted and dropped. Rejecting the call because a sender
       offered buttons would lose the message entirely, and the message is the
       part that matters — GetCapabilities already tells anyone who asks that
       this desktop does not draw them. */
    Q_UNUSED(actions)

    const uint id = (replaces_id != 0) ? replaces_id : m_next++;

    bool error = false;
    const QVariant urgency = hints.value(QStringLiteral("urgency"));
    if (urgency.isValid() && urgency.toInt() >= URGENCY_CRITICAL)
        error = true;

    /* -1 means "let the server decide". Zero means "until dismissed", which
        this desktop has no way to express — there is nothing to click — so it
        is treated as the longest sensible show rather than pinned forever. */
    int timeoutMs = expire_timeout;
    if (timeoutMs < 0)
        timeoutMs = error ? 8000 : 5000;
    else if (timeoutMs == 0)
        timeoutMs = 15000;

    emit posted(id, app_name, summary, body, error, timeoutMs);
    return id;
}

void NotificationService::CloseNotification(uint id)
{
    emit revoked(id);
    // 3: closed by a call to CloseNotification.
    emit NotificationClosed(id, 3);
}

QStringList NotificationService::GetCapabilities()
{
    /* Only what is true. "actions" would make senders draw buttons this
       desktop cannot show; "body-markup" would print the tags at the
       operator; "persistence" would promise a history there is no window for. */
    return {QStringLiteral("body")};
}

QString NotificationService::GetServerInformation(QString &vendor, QString &version,
                                                  QString &spec_version)
{
    vendor = QStringLiteral("Symbiote OS");
    version = QStringLiteral("1.0");
    spec_version = QStringLiteral("1.2");
    return QStringLiteral("symbiote-shell");
}
