import QtQuick
import Symbiote

/* On or off, with a state you can see from across the room.
 *
 * The old one was a 34x16 outline with an 11px block that moved 17 pixels. On
 * the laptop panel that is the difference between on and off being roughly two
 * millimetres of travel in a colour that is already the interface's main hue —
 * so the only reliable way to read it was the 8px word beside it.
 */
Item {
    id: tog

    property bool on: false
    property bool enabled: true
    signal toggled()

    implicitWidth: 62
    implicitHeight: Theme.ctrlHeightSm
    width: implicitWidth
    height: implicitHeight

    HoverHandler { id: hover; enabled: tog.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: tog.enabled; onTapped: tog.toggled() }

    Rectangle {
        id: bed
        width: 38
        height: 20
        anchors.verticalCenter: parent.verticalCenter
        color: tog.on ? Theme.tint(0.14) : Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: !tog.enabled ? Theme.line
                    : tog.on ? Theme.accent
                    : hover.hovered ? Theme.textMuted : Theme.line
        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }
        Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }

        // The knob. Wider when on, so the state has a shape as well as a place.
        Rectangle {
            y: 3
            x: tog.on ? bed.width - width - 3 : 3
            width: tog.on ? 16 : 12
            height: 14
            color: !tog.enabled ? Theme.line : tog.on ? Theme.accent : Theme.textMuted
            Behavior on x { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                              easing.type: Theme.easeOut } }
            Behavior on width { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
            Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }
        }
    }

    Text {
        anchors { left: bed.right; leftMargin: Theme.space3; verticalCenter: parent.verticalCenter }
        text: tog.on ? "ON" : "OFF"
        color: !tog.enabled ? Theme.line : tog.on ? Theme.accent : Theme.textMuted
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
        font.letterSpacing: Theme.trackWide
    }
}
