import QtQuick
import Symbiote

/* Volume and brightness, as sliders you drag.
 *
 * There was no mute button. Muting was done by clicking the word VOLUME — an
 * undiscoverable gesture on a label that looks like a label, with nothing
 * anywhere saying it was possible. The tray icon changed colour to show the
 * state, which is not a state anyone can read: red-on-dark and green-on-dark
 * at 16px are the same icon to most people at a glance, and identical to
 * anyone colour-blind.
 */
Item {
    id: root
    signal dismissed()

    property string edge: "bottom"
    property real inset: 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismissed()
    }

    TraySheet {
        width: 340
        height: col.implicitHeight + 34
        edge: root.edge
        inset: root.inset
        shown: root.visible

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: 17; rightMargin: 17; topMargin: 17 }
            spacing: 18

            HudSlider {
                width: parent.width
                label: "VOLUME"
                value: Media.volume
                muted: Media.muted
                enabled: Media.audioAvailable
                absent: !Media.audioAvailable
                absentText: "no audio device"
                onMoved: function (v) { Media.setVolume(v) }

                /* The mute button, sitting in the slider's own label row where
                   the eye already is. Says which state it will put you in, not
                   which state you are in — a button labelled MUTE that means
                   "currently muted" is the classic way to make a control
                   unreadable. */
                HudButton {
                    text: Media.muted ? "UNMUTE" : "MUTE"
                    danger: Media.muted
                    enabled: Media.audioAvailable
                    onClicked: Media.setMuted(!Media.muted)
                }
            }

            HudSlider {
                width: parent.width
                label: "BRIGHTNESS"
                value: Media.brightness
                enabled: Media.backlightAvailable
                absent: !Media.backlightAvailable
                absentText: "no backlight — external display?"
                // 5% floor: a black panel hides the control that undoes it.
                minimum: 5
                onMoved: function (v) { Media.setBrightness(v) }
            }
        }
    }
}
