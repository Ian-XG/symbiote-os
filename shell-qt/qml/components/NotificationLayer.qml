import QtQuick
import QtQuick.Window
import Symbiote

/*
 * The surface notifications are drawn on, above every other window.
 *
 * The stack used to live inside the desktop window, and the desktop window is
 * pinned to the bottom of the stacking order — that is what makes it a
 * wallpaper rather than a window. So a notification was only visible when
 * nothing was covering that corner of the screen. The shell had just been
 * taught to answer org.freedesktop.Notifications for every application on the
 * machine, and the answer was being painted underneath them.
 *
 * Three deliberate choices, all of them about not breaking the desktop:
 *
 *  - It exists only while there is something to show. An always-on-top surface
 *    that is always present is a permanent chance of eating a click; one that
 *    appears for a few seconds is a brief one, and a bug in it announces
 *    itself immediately rather than a week later.
 *
 *  - WindowTransparentForInput, so pointer events go through to whatever is
 *    behind. A toast is something to read, never something to click.
 *
 *  - Sized to the stack, not to the screen. If the input region ever fails to
 *    apply, the damage is one small rectangle over empty desktop instead of
 *    an invisible sheet over the whole display.
 *
 * The title is load-bearing: labwc matches window rules on it, and rc.xml uses
 * it to put this window on top while the desktop windows — same application,
 * same app_id, titled "Symbiote Shell" — stay at the bottom.
 */
Window {
    id: layer

    property real bottomInset: 0
    property var targetScreen: null

    function push(text, error) { stack.push(text, error) }

    screen: targetScreen
    title: "Symbiote Notifications"
    flags: Qt.Window | Qt.FramelessWindowHint
           | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput
    color: "transparent"
    visible: stack.count > 0

    readonly property int pad: 18
    width: 460
    height: Math.max(1, stack.implicitHeight) + layer.pad

    /* Bottom right of its screen, clear of the taskbar. Computed from the
       screen rather than anchored, because a Window has no parent to anchor
       to — and read from `screen` so this lands correctly on whichever
       monitor it was given. */
    x: (layer.screen ? layer.screen.virtualX + layer.screen.width : Screen.width)
       - layer.width - layer.pad
    y: (layer.screen ? layer.screen.virtualY + layer.screen.height : Screen.height)
       - layer.height - layer.bottomInset - 12

    Notifications {
        id: stack
        anchors.fill: parent
        // The offset is the window's own edge now; the taskbar is cleared by
        // where the window sits, not by padding inside it.
        bottomInset: 0
    }
}
