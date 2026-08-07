import QtQuick
import Symbiote

/* Plain-language status rows, coloured by severity.
   The model is a list of { label, value, state } where state is one of
   ok / attention / critical / idle. Nothing here is decorative: every row is a
   fact read from the system. */
Column {
    id: root
    property var rows: []
    width: parent ? parent.width : 300
    spacing: 0

    Repeater {
        model: root.rows

        Item {
            required property var modelData
            required property int index

            width: root.width
            height: 26

            Text {
                text: modelData.label
                color: Theme.textBody
                font.family: Theme.mono
                font.pixelSize: Theme.sizeXs
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 6

                Rectangle {
                    width: 5; height: 5; radius: 2.5
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.stateColor(modelData.state)

                    // Anything needing attention pulses; steady states do not,
                    // so movement always means something.
                    SequentialAnimation on opacity {
                        running: modelData.state === "critical" || modelData.state === "attention"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: Theme.durPulse / 2 }
                        NumberAnimation { to: 1.0;  duration: Theme.durPulse / 2 }
                    }
                }

                Text {
                    text: modelData.value
                    color: Theme.stateColor(modelData.state)
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                visible: index < root.rows.length - 1
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Qt.rgba(1, 1, 1, 0.04)
            }
        }
    }
}
