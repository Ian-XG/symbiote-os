import QtQuick
import Symbiote

/* One metric: a detail line, a name, a value, and a discrete level bar.
   Discrete rather than continuous because segments read at a glance in a way a
   smooth bar does not. */
Item {
    id: root

    property string code: ""
    property string label: ""
    property string value: ""
    property int filled: 0
    property int segments: 8
    property bool critical: false
    property bool compact: true

    readonly property color tint: critical ? Theme.alert : Theme.accent

    implicitHeight: col.implicitHeight
    width: parent ? parent.width : 200

    Column {
        id: col
        width: parent.width
        spacing: 3

        Item {
            width: parent.width
            height: codeText.implicitHeight
            Text {
                id: codeText
                text: root.code
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                anchors.left: parent.left
            }
            Text {
                text: root.value
                color: root.tint
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                anchors.right: parent.right
            }
        }

        Text {
            text: root.label
            color: root.critical ? Theme.alert : Theme.textBody
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
        }

        Row {
            width: parent.width
            spacing: 2
            Repeater {
                model: root.segments
                Rectangle {
                    width: (root.width - (root.segments - 1) * 2) / root.segments
                    height: root.compact ? 3 : 4
                    color: index < root.filled ? root.tint : Theme.line
                }
            }
        }
    }
}
