import QtQuick
import Symbiote

/* On or off, as a switch you can read from across the room.
 *
 * The first version was a 34x16 rectangle with a square block that slid 17
 * pixels in a colour already used everywhere else, so the only reliable way to
 * tell its state was the 8px word beside it. This is a rounded pill with a
 * travelling knob — the shape people already read as a switch — that fills with
 * the accent when on and drains to a hollow outline when off. The state is the
 * fill and the knob's side, not a shade of green next to another shade of
 * green.
 */
Item {
    id: tog

    property bool on: false
    property bool enabled: true
    signal toggled()

    implicitWidth: bed.width + label.width + Theme.space3
    implicitHeight: 22
    width: implicitWidth
    height: implicitHeight

    HoverHandler { id: hover; enabled: tog.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: tog.enabled; onTapped: tog.toggled() }

    // The track. A full pill, not a rectangle — the rounded ends are most of
    // what makes it read as a switch rather than a checkbox.
    Rectangle {
        id: bed
        width: 40
        height: 22
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter

        color: !tog.enabled ? Qt.rgba(1, 1, 1, 0.04)
             : tog.on ? Theme.accent
             : Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: !tog.enabled ? Theme.line
                    : tog.on ? Theme.accent
                    : hover.hovered ? Theme.textMuted : Theme.line
        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }
        Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }

        // The knob. Dark against the filled track when on, so it stays visible
        // instead of vanishing into the accent it sits on.
        Rectangle {
            id: knob
            width: 16
            height: 16
            radius: height / 2
            y: (bed.height - height) / 2
            x: tog.on ? bed.width - width - 3 : 3
            color: !tog.enabled ? Theme.textMuted
                 : tog.on ? Theme.bgVoid : Theme.textMuted
            Behavior on x { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                              easing.type: Theme.easeOut } }
            Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }
        }
    }

    Text {
        id: label
        anchors { left: bed.right; leftMargin: Theme.space3; verticalCenter: parent.verticalCenter }
        text: tog.on ? "ON" : "OFF"
        color: !tog.enabled ? Theme.line : tog.on ? Theme.accent : Theme.textMuted
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
        font.letterSpacing: Theme.trackWide
    }
}
