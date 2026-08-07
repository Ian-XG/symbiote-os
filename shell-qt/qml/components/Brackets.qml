import QtQuick
import Symbiote

/* Corner brackets, the frame device used everywhere instead of closed boxes.
   Four L-shapes rather than a border, so the frame stays open at the edges. */
Item {
    id: root
    anchors.fill: parent

    property color color: Theme.accent
    property int size: Theme.bracket
    property int thickness: 1

    Repeater {
        model: [
            { hx: 0, hy: 0, dx:  1, dy:  1 },  // top-left
            { hx: 1, hy: 0, dx: -1, dy:  1 },  // top-right
            { hx: 0, hy: 1, dx:  1, dy: -1 },  // bottom-left
            { hx: 1, hy: 1, dx: -1, dy: -1 }   // bottom-right
        ]

        Item {
            required property var modelData
            x: modelData.hx * (root.width - root.size)
            y: modelData.hy * (root.height - root.size)
            width: root.size
            height: root.size

            // horizontal arm
            Rectangle {
                width: parent.width
                height: root.thickness
                color: root.color
                anchors.left: modelData.dx > 0 ? parent.left : undefined
                anchors.right: modelData.dx > 0 ? undefined : parent.right
                anchors.top: modelData.dy > 0 ? parent.top : undefined
                anchors.bottom: modelData.dy > 0 ? undefined : parent.bottom
            }
            // vertical arm
            Rectangle {
                width: root.thickness
                height: parent.height
                color: root.color
                anchors.left: modelData.dx > 0 ? parent.left : undefined
                anchors.right: modelData.dx > 0 ? undefined : parent.right
                anchors.top: modelData.dy > 0 ? parent.top : undefined
                anchors.bottom: modelData.dy > 0 ? undefined : parent.bottom
            }
        }
    }
}
