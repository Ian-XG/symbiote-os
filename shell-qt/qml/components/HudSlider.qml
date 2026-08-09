import QtQuick
import Symbiote

/* A slider you can actually aim at.
 *
 * The one in the media popup was 3px of track with a 3px handle and a hit area
 * the height of the track, which on a trackpad is a game rather than a control.
 * This one has a 20px grab band, keyboard steps, a wheel, and it commits
 * continuously while dragging so the value under your finger is the value the
 * system has.
 *
 * Still not QtQuick.Controls: pulling in the control set and restyling it costs
 * more than the ninety lines it would save, and every other control here is
 * drawn in the same vocabulary.
 */
Item {
    id: sl

    property string label: ""
    property int value: 0
    property int minimum: 0
    property int maximum: 100
    property int step: 5
    property string suffix: "%"
    property bool enabled: true

    /* The control has nothing to control — no audio device, no backlight.
       Distinct from disabled, and it says which rather than showing a dead
       slider at zero that looks like a setting somebody chose. */
    property bool absent: false
    property string absentText: ""

    /** Struck through and recoloured, without pretending the value changed. */
    property bool muted: false

    /** Anything to put at the right of the label row — a mute button, usually. */
    default property alias trailing: trailingHolder.data

    signal moved(int v)

    readonly property bool live: enabled && !absent
    readonly property real fraction: {
        var span = Math.max(1, maximum - minimum)
        return Math.max(0, Math.min(1, (value - minimum) / span))
    }

    implicitHeight: 44
    height: implicitHeight

    function commitAt(px) {
        var f = Math.max(0, Math.min(1, px / Math.max(1, track.width)))
        var v = Math.round(minimum + f * (maximum - minimum))
        // Snap to the step so dragging produces round numbers, not 63%.
        v = Math.round(v / sl.step) * sl.step
        v = Math.max(sl.minimum, Math.min(sl.maximum, v))
        if (v !== sl.value)
            sl.moved(v)
    }

    function nudge(delta) {
        var v = Math.max(sl.minimum, Math.min(sl.maximum, sl.value + delta))
        if (v !== sl.value)
            sl.moved(v)
    }

    // ── label row ──────────────────────────────────────────────
    Text {
        id: slLabel
        anchors.left: parent.left
        text: sl.label
        color: sl.absent ? Theme.textMuted : Theme.accent
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
        font.letterSpacing: Theme.trackWider
    }

    Row {
        anchors { right: parent.right; verticalCenter: slLabel.verticalCenter }
        spacing: Theme.space3

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sl.absent ? sl.absentText
                : sl.muted ? "MUTED  " + sl.value + sl.suffix
                : sl.value + sl.suffix
            color: sl.muted ? Theme.alert
                 : sl.absent ? Theme.textMuted : Theme.textBody
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
        }
        Item {
            id: trailingHolder
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    // ── track ──────────────────────────────────────────────────
    Item {
        id: track
        anchors { left: parent.left; right: parent.right; top: slLabel.bottom; topMargin: 14 }
        height: 20

        // The rail.
        Rectangle {
            id: rail
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 3
            color: Theme.line

            Rectangle {
                height: parent.height
                width: parent.width * sl.fraction
                color: sl.absent ? Theme.line
                     : sl.muted ? Theme.alert : Theme.accent
                // No animation while dragging: the fill must track the finger,
                // not chase it.
                Behavior on width {
                    enabled: !grab.pressed && Prefs.motionOn
                    NumberAnimation { duration: Prefs.dur(Theme.durFast) }
                }
            }
        }

        // Ticks, so the range reads as a range rather than a bare line.
        Row {
            visible: !sl.absent
            anchors { left: parent.left; right: parent.right; top: rail.bottom; topMargin: 4 }
            Repeater {
                model: 5
                Item {
                    width: track.width / 5
                    height: 3
                    Rectangle {
                        x: 0; width: 1; height: 3
                        color: Qt.rgba(1, 1, 1, 0.10)
                    }
                }
            }
        }

        // The handle: a bracketed bar, matching the HUD's own furniture.
        Item {
            id: handle
            visible: !sl.absent
            width: 9
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            x: (track.width - width) * sl.fraction
            Behavior on x {
                enabled: !grab.pressed && Prefs.motionOn
                NumberAnimation { duration: Prefs.dur(Theme.durFast) }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 3
                height: parent.height
                color: sl.muted ? Theme.alert : Theme.accent
            }
            // Grows under the cursor, so there is feedback before the drag.
            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height + 6
                color: "transparent"
                border.width: 1
                border.color: sl.muted ? Theme.alert : Theme.accent
                opacity: (hover.hovered || grab.pressed) ? 0.85 : 0
                Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
            }
        }

        HoverHandler { id: hover; enabled: sl.live; cursorShape: Qt.PointingHandCursor }

        MouseArea {
            id: grab
            anchors.fill: parent
            enabled: sl.live
            // Dragging and clicking are the same gesture.
            onPressed: function (mouse) { sl.commitAt(mouse.x) }
            onPositionChanged: function (mouse) { if (pressed) sl.commitAt(mouse.x) }
            onWheel: function (wheel) {
                sl.nudge(wheel.angleDelta.y > 0 ? sl.step : -sl.step)
            }
        }
    }

    // Arrow keys, once the slider has been clicked. Free, and the only way to
    // set an exact value without a mouse.
    focus: false
    Keys.onLeftPressed: sl.nudge(-sl.step)
    Keys.onRightPressed: sl.nudge(sl.step)
}
