import QtQuick
import Symbiote

/* A panel that hangs off the tray, wherever the tray currently is.
 *
 * The Wi-Fi, media and power popups each anchored themselves to the bottom
 * right of the screen with a hard-coded `bottomInset` for the taskbar's height.
 * That was fine while the bar could only be at the bottom. Now that it can be
 * on any edge, three files would each need the same four-way arithmetic, and
 * they would drift — so it lives here once.
 *
 * The sheet also arrives from the direction of its own edge. A panel that
 * slides up from the bottom while its button is at the top of a left-hand bar
 * is a panel that came from nowhere.
 */
Item {
    id: sheet

    /** Which edge the taskbar is on: "bottom" | "top" | "left" | "right". */
    property string edge: "bottom"
    /** How much of that edge the taskbar owns. */
    property real inset: 0
    /** Whether the containing popup is showing; drives the arrival. */
    property bool shown: true

    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property int gap: 8
    readonly property int margin: 18

    default property alias content: holder.data

    x: {
        if (edge === "left") return inset + gap
        if (edge === "right") return parent.width - width - inset - gap
        return parent.width - width - margin
    }
    y: {
        if (edge === "top") return inset + gap
        if (edge === "bottom") return parent.height - height - inset - gap
        return parent.height - height - margin
    }

    // Swallows clicks so the click-away behind does not close it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onWheel: function (wheel) { wheel.accepted = true }
    }

    Rectangle {
        anchors.fill: parent
        // Fully opaque. At 96% the panel behind bled through the text, which
        // is what made the Settings window unreadable on the laptop.
        color: Theme.bgVoid
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: 1
        border.color: Theme.hairline
    }
    Brackets { color: Theme.accent }

    opacity: sheet.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }

    transform: Translate {
        x: sheet.shown || !Prefs.motionMoves ? 0
           : sheet.edge === "left" ? -Theme.slide
           : sheet.edge === "right" ? Theme.slide : 0
        y: sheet.shown || !Prefs.motionMoves ? 0
           : sheet.edge === "top" ? -Theme.slide
           : sheet.edge === "bottom" ? Theme.slide : 0
        Behavior on x { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                          easing.type: Theme.easeOut } }
        Behavior on y { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                          easing.type: Theme.easeOut } }
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
