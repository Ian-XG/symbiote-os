#include "ToplevelManager.h"

#include <QGuiApplication>
#include <QtGui/qguiapplication_platform.h>

#include <wayland-client.h>
#include "wlr-foreign-toplevel-management-client-protocol.h"

ToplevelManager::ToplevelManager(QObject *parent) : QObject(parent)
{
    auto *wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
    if (!wayland) {
        // Not on Wayland — running offscreen for a capture, or under X.
        return;
    }

    m_display = wayland->display();
    m_seat = wayland->seat();
    if (!m_display)
        return;

    /* A private queue. Sharing Qt's default queue would mean our callbacks
       run at whatever moment Qt happens to dispatch, from whichever thread it
       chooses. */
    m_queue = wl_display_create_queue(m_display);

    m_registry = wl_display_get_registry(m_display);
    wl_proxy_set_queue(reinterpret_cast<wl_proxy *>(m_registry), m_queue);

    static const wl_registry_listener listener = {
        ToplevelManager::onGlobal, ToplevelManager::onGlobalRemove
    };
    wl_registry_add_listener(m_registry, &listener, this);

    /* One roundtrip so the globals are known before the first frame. Bounded
       and at startup only; the periodic pump below never blocks. */
    wl_display_roundtrip_queue(m_display, m_queue);

    connect(&m_pump, &QTimer::timeout, this, [this] {
        if (m_display && m_queue)
            wl_display_dispatch_queue_pending(m_display, m_queue);
    });
    // Window titles change when a tab changes; four times a second is plenty
    // and costs nothing when nothing has happened.
    m_pump.start(250);
}

ToplevelManager::~ToplevelManager()
{
    for (auto it = m_entries.begin(); it != m_entries.end(); ++it)
        zwlr_foreign_toplevel_handle_v1_destroy(it.key());
    if (m_manager)
        zwlr_foreign_toplevel_manager_v1_stop(m_manager);
    if (m_registry)
        wl_registry_destroy(m_registry);
    if (m_queue)
        wl_event_queue_destroy(m_queue);
}

// ── registry ───────────────────────────────────────────────────────────────

void ToplevelManager::onGlobal(void *data, wl_registry *registry, uint32_t name,
                               const char *iface, uint32_t version)
{
    auto *self = static_cast<ToplevelManager *>(data);

    if (qstrcmp(iface, zwlr_foreign_toplevel_manager_v1_interface.name) != 0)
        return;

    /* Bind no higher than we were built against: asking for a newer version
       than the generated code understands is a protocol error, which kills
       the client outright. */
    const uint32_t want = qMin<uint32_t>(version, 3);
    self->m_manager = static_cast<zwlr_foreign_toplevel_manager_v1 *>(
        wl_registry_bind(registry, name,
                         &zwlr_foreign_toplevel_manager_v1_interface, want));

    static const zwlr_foreign_toplevel_manager_v1_listener listener = {
        ToplevelManager::onToplevel, ToplevelManager::onFinished
    };
    zwlr_foreign_toplevel_manager_v1_add_listener(self->m_manager, &listener, self);
    emit self->changed();
}

void ToplevelManager::onGlobalRemove(void *, wl_registry *, uint32_t) {}

// ── toplevels ──────────────────────────────────────────────────────────────

void ToplevelManager::onToplevel(void *data, zwlr_foreign_toplevel_manager_v1 *,
                                 zwlr_foreign_toplevel_handle_v1 *handle)
{
    auto *self = static_cast<ToplevelManager *>(data);

    static const zwlr_foreign_toplevel_handle_v1_listener listener = {
        ToplevelManager::hTitle,      ToplevelManager::hAppId,
        ToplevelManager::hOutputEnter, ToplevelManager::hOutputLeave,
        ToplevelManager::hState,      ToplevelManager::hDone,
        ToplevelManager::hClosed,     ToplevelManager::hParent
    };

    self->m_entries.insert(handle, Entry{handle, QString(), QString(), false, false, false});
    zwlr_foreign_toplevel_handle_v1_add_listener(handle, &listener, self);
}

void ToplevelManager::onFinished(void *data, zwlr_foreign_toplevel_manager_v1 *)
{
    auto *self = static_cast<ToplevelManager *>(data);
    self->m_manager = nullptr;
    self->m_entries.clear();
    self->rebuild();
}

void ToplevelManager::hTitle(void *data, zwlr_foreign_toplevel_handle_v1 *h, const char *t)
{
    auto *self = static_cast<ToplevelManager *>(data);
    if (auto it = self->m_entries.find(h); it != self->m_entries.end())
        it->title = QString::fromUtf8(t);
}

void ToplevelManager::hAppId(void *data, zwlr_foreign_toplevel_handle_v1 *h, const char *a)
{
    auto *self = static_cast<ToplevelManager *>(data);
    if (auto it = self->m_entries.find(h); it != self->m_entries.end())
        it->appId = QString::fromUtf8(a);
}

void ToplevelManager::hState(void *data, zwlr_foreign_toplevel_handle_v1 *h, wl_array *state)
{
    auto *self = static_cast<ToplevelManager *>(data);
    auto it = self->m_entries.find(h);
    if (it == self->m_entries.end())
        return;

    it->activated = it->minimized = it->maximized = false;
    // The state arrives as a flat array of uint32 enum values.
    const auto *begin = static_cast<const uint32_t *>(state->data);
    const size_t count = state->size / sizeof(uint32_t);
    for (size_t i = 0; i < count; ++i) {
        switch (begin[i]) {
        case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_ACTIVATED: it->activated = true; break;
        case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MINIMIZED: it->minimized = true; break;
        case ZWLR_FOREIGN_TOPLEVEL_HANDLE_V1_STATE_MAXIMIZED: it->maximized = true; break;
        default: break;
        }
    }
}

/* `done` is the compositor saying "that batch of property changes is
   complete". Rebuilding on every individual title or state event instead would
   show the list mid-update. */
void ToplevelManager::hDone(void *data, zwlr_foreign_toplevel_handle_v1 *)
{
    static_cast<ToplevelManager *>(data)->rebuild();
}

void ToplevelManager::hClosed(void *data, zwlr_foreign_toplevel_handle_v1 *h)
{
    auto *self = static_cast<ToplevelManager *>(data);
    self->m_entries.remove(h);
    zwlr_foreign_toplevel_handle_v1_destroy(h);
    self->rebuild();
}

// ── exposed model ──────────────────────────────────────────────────────────

void ToplevelManager::rebuild()
{
    QVariantList out;
    for (auto it = m_entries.constBegin(); it != m_entries.constEnd(); ++it) {
        const Entry &e = it.value();
        // A window with neither a title nor an app id has not finished
        // announcing itself; showing a blank button helps nobody.
        if (e.title.isEmpty() && e.appId.isEmpty())
            continue;

        QVariantMap m;
        // The pointer, as an opaque key. QML never dereferences it; it hands
        // it straight back to activate().
        m["key"] = QString::number(reinterpret_cast<quintptr>(e.handle), 16);
        m["title"] = e.title.isEmpty() ? e.appId : e.title;
        m["appId"] = e.appId;
        m["activated"] = e.activated;
        m["minimized"] = e.minimized;
        out.append(m);
    }

    std::sort(out.begin(), out.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap()["title"].toString().localeAwareCompare(
                   b.toMap()["title"].toString()) < 0;
    });

    if (out == m_windows)
        return;
    m_windows = out;
    emit changed();
}

void ToplevelManager::activate(const QString &key)
{
    bool ok = false;
    auto *h = reinterpret_cast<zwlr_foreign_toplevel_handle_v1 *>(key.toULongLong(&ok, 16));
    if (!ok || !m_entries.contains(h) || !m_seat)
        return;
    /* Unminimise first: activating a minimised window on labwc raises it
       without restoring it, which looks like the click did nothing. */
    if (m_entries[h].minimized)
        zwlr_foreign_toplevel_handle_v1_unset_minimized(h);
    zwlr_foreign_toplevel_handle_v1_activate(h, m_seat);
    wl_display_flush(m_display);
}

void ToplevelManager::closeWindow(const QString &key)
{
    bool ok = false;
    auto *h = reinterpret_cast<zwlr_foreign_toplevel_handle_v1 *>(key.toULongLong(&ok, 16));
    if (!ok || !m_entries.contains(h))
        return;
    zwlr_foreign_toplevel_handle_v1_close(h);
    wl_display_flush(m_display);
}

void ToplevelManager::minimize(const QString &key)
{
    bool ok = false;
    auto *h = reinterpret_cast<zwlr_foreign_toplevel_handle_v1 *>(key.toULongLong(&ok, 16));
    if (!ok || !m_entries.contains(h))
        return;
    zwlr_foreign_toplevel_handle_v1_set_minimized(h);
    wl_display_flush(m_display);
}
