#include "PowerService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>

namespace {
constexpr auto UPOWER = "org.freedesktop.UPower";
constexpr auto DISPLAY_DEVICE = "/org/freedesktop/UPower/devices/DisplayDevice";
constexpr auto DEVICE_IFACE = "org.freedesktop.UPower.Device";

QString human(qint64 seconds)
{
    if (seconds <= 0)
        return {};
    const qint64 h = seconds / 3600;
    const qint64 m = (seconds % 3600) / 60;
    return h > 0 ? QString("%1h %2m").arg(h).arg(m) : QString("%1m").arg(m);
}
} // namespace

PowerService::PowerService(QObject *parent) : QObject(parent)
{
    sample();
    connect(&m_timer, &QTimer::timeout, this, &PowerService::sample);
    m_timer.start(10000);
}

void PowerService::sample()
{
    QDBusInterface props(UPOWER, DISPLAY_DEVICE, "org.freedesktop.DBus.Properties",
                         QDBusConnection::systemBus());
    props.setTimeout(4000);

    auto get = [&props](const char *name) -> QVariant {
        QDBusReply<QVariant> r = props.call("Get", QString(DEVICE_IFACE), QString(name));
        return r.isValid() ? r.value() : QVariant();
    };

    const QVariant presentVar = get("IsPresent");
    if (!presentVar.isValid()) {
        // No UPower at all (a minimal container): do not invent a battery.
        m_present = false;
        m_onAc = true;
        emit changed();
        return;
    }

    m_present = presentVar.toBool();
    if (!m_present) {
        m_onAc = true;
        emit changed();
        return;
    }

    m_percent = int(get("Percentage").toDouble() + 0.5);

    // UPower device state enum
    switch (get("State").toUInt()) {
    case 1: m_state = "charging";  break;
    case 2: m_state = "discharging"; break;
    case 3: m_state = "empty";     break;
    case 4: m_state = "full";      break;
    default: m_state = "unknown";  break;
    }

    m_onAc = (m_state == "charging" || m_state == "full");
    m_remaining = human(m_onAc ? get("TimeToFull").toLongLong()
                               : get("TimeToEmpty").toLongLong());
    emit changed();
}
