#pragma once

#include <QObject>
#include <QVariantList>
#include <QHash>
#include <QTimer>

struct wl_display;
struct wl_registry;
struct wl_event_queue;
struct wl_seat;
struct wl_output;
struct wl_array;
struct zwlr_foreign_toplevel_manager_v1;
struct zwlr_foreign_toplevel_handle_v1;

/*
 * What is actually open.
 *
 * The taskbar listed the applications that had been pinned to it and nothing
 * else — two Firefox windows were indistinguishable, and a window nobody had
 * pinned did not exist as far as the bar was concerned. Only the compositor
 * knows what is on screen, and the way to ask is a Wayland protocol.
 *
 * `ext-foreign-toplevel-list-v1` is the standardised one and is packaged, but
 * it is read-only: it will tell you a window's title and never let you focus
 * it. This uses wlroots' older management protocol, which labwc also
 * implements, because a list you cannot click is a label rather than a
 * taskbar.
 */
class ToplevelManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList windows READ windows NOTIFY changed)
    /** False when the compositor does not offer the protocol at all. */
    Q_PROPERTY(bool available READ available NOTIFY changed)

public:
    explicit ToplevelManager(QObject *parent = nullptr);
    ~ToplevelManager() override;

    QVariantList windows() const { return m_windows; }
    bool available() const { return m_manager != nullptr; }

    /** Raise and focus a window. `key` is the opaque id from `windows`. */
    Q_INVOKABLE void activate(const QString &key);
    Q_INVOKABLE void closeWindow(const QString &key);
    Q_INVOKABLE void minimize(const QString &key);

signals:
    void changed();

private:
    struct Entry {
        zwlr_foreign_toplevel_handle_v1 *handle = nullptr;
        QString title;
        QString appId;
        bool activated = false;
        bool minimized = false;
        bool maximized = false;
    };

    void rebuild();

    // Wayland listeners need C linkage and a void* — these forward into the
    // instance, and are the only reason any of this is static.
    static void onGlobal(void *data, wl_registry *r, uint32_t name,
                         const char *iface, uint32_t version);
    static void onGlobalRemove(void *data, wl_registry *r, uint32_t name);
    static void onToplevel(void *data, zwlr_foreign_toplevel_manager_v1 *m,
                           zwlr_foreign_toplevel_handle_v1 *h);
    static void onFinished(void *data, zwlr_foreign_toplevel_manager_v1 *m);

    static void hTitle(void *data, zwlr_foreign_toplevel_handle_v1 *h, const char *t);
    static void hAppId(void *data, zwlr_foreign_toplevel_handle_v1 *h, const char *a);
    static void hOutputEnter(void *, zwlr_foreign_toplevel_handle_v1 *, wl_output *) {}
    static void hOutputLeave(void *, zwlr_foreign_toplevel_handle_v1 *, wl_output *) {}
    static void hState(void *data, zwlr_foreign_toplevel_handle_v1 *h, wl_array *state);
    static void hDone(void *data, zwlr_foreign_toplevel_handle_v1 *h);
    static void hClosed(void *data, zwlr_foreign_toplevel_handle_v1 *h);
    static void hParent(void *, zwlr_foreign_toplevel_handle_v1 *,
                        zwlr_foreign_toplevel_handle_v1 *) {}

    wl_display *m_display = nullptr;
    wl_event_queue *m_queue = nullptr;
    wl_registry *m_registry = nullptr;
    wl_seat *m_seat = nullptr;
    zwlr_foreign_toplevel_manager_v1 *m_manager = nullptr;

    QHash<zwlr_foreign_toplevel_handle_v1 *, Entry> m_entries;
    QVariantList m_windows;

    /* Qt owns the socket and does the reading; this only drains what has
       already been sorted into our queue. Dispatching the display directly
       would fight Qt for the same file descriptor. */
    QTimer m_pump;
};
