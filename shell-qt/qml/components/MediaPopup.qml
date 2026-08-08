import QtQuick
import Symbiote

/* Volume and brightness, as sliders you drag.
   The desktop had neither, and the laptop's own media keys did nothing
   because the compositor was not forwarding them. */
Item {
    id: root
    signal dismissed()

    property real bottomInset: 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismissed()
    }

    Item {
        id: sheet
        width: 320
        height: col.height + 32
        anchors {
            right: parent.right; rightMargin: 18
            bottom: parent.bottom; bottomMargin: root.bottomInset + 8
        }

        MouseArea { anchors.fill: parent }

        Rectangle { anchors.fill: parent; color: Theme.bgVoid }
        Rectangle {
            anchors.fill: parent
            color: Theme.panelStrong
            border.width: 1
            border.color: Theme.hairline
        }
        Brackets { color: Theme.accent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top
                      leftMargin: 16; rightMargin: 16; topMargin: 16 }
            spacing: 16

            Slider {
                width: parent.width
                label: "VOLUME"
                value: Media.volume
                enabled: Media.audioAvailable
                muted: Media.muted
                absent: !Media.audioAvailable
                absentText: "no audio device"
                onMoved: function (v) { Media.setVolume(v) }
                onToggled: Media.toggleMute()
            }

            Slider {
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

    /* A local slider rather than QtQuick.Controls: the shell would otherwise
       pull in a whole control set and its styling for two of these. */
    component Slider: Item {
        id: sl
        property string label: ""
        property int value: 0
        property int minimum: 0
        property bool enabled: true
        property bool muted: false
        property bool absent: false
        property string absentText: ""
        signal moved(int v)
        signal toggled()

        height: 46

        Text {
            id: slLabel
            text: sl.label
            color: sl.absent ? Theme.textMuted : Theme.accent
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            font.letterSpacing: Theme.trackWider
        }

        Text {
            anchors.right: parent.right
            text: sl.absent ? sl.absentText
                : sl.muted ? "MUTED" : sl.value + "%"
            color: sl.muted ? Theme.alert
                 : sl.absent ? Theme.textMuted : Theme.textBody
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
        }

        Item {
            id: track
            anchors { left: parent.left; right: parent.right; top: slLabel.bottom
                      topMargin: 12 }
            height: 18

            Rectangle {
                anchors { left: parent.left; right: parent.right
                          verticalCenter: parent.verticalCenter }
                height: 3
                color: Theme.line

                Rectangle {
                    height: parent.height
                    width: parent.width * Math.max(0, Math.min(100, sl.value)) / 100
                    color: sl.absent ? Theme.line
                         : sl.muted ? Theme.alert : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                }
            }

            // The handle, so there is something to aim at.
            Rectangle {
                visible: !sl.absent
                width: 3; height: 14
                anchors.verticalCenter: parent.verticalCenter
                x: (track.width - width) * Math.max(0, Math.min(100, sl.value)) / 100
                color: sl.muted ? Theme.alert : Theme.accent
                Behavior on x { NumberAnimation { duration: Theme.durFast } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: sl.enabled && !sl.absent
                // Dragging and clicking are the same gesture here.
                onPositionChanged: if (pressed) commit(mouse.x)
                onPressed: commit(mouse.x)
                function commit(x) {
                    var v = Math.round(x / track.width * 100)
                    sl.moved(Math.max(sl.minimum, Math.min(100, v)))
                }
            }
        }

        // Clicking the label mutes, which is where people click.
        TapHandler {
            enabled: sl.enabled && !sl.absent && sl.label === "VOLUME"
            onTapped: sl.toggled()
        }
    }
}
