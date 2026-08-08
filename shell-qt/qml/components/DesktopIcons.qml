import QtQuick
import QtQuick.Shapes
import Symbiote

/* Folders and apps on the wallpaper. Single click opens — double click is the
   desktop convention, but here selection drives nothing, so a single click
   that only highlighted made the icons feel broken. */
Column {
    id: root
    spacing: 10

    property var items: {
        var out = []
        for (var i = 0; i < Prefs.desktopIds.length; i++) {
            var a = Prefs.appById(Prefs.desktopIds[i])
            if (a) out.push(a)
        }
        return out
    }
    property var openIds: []
    property var startingIds: []
    property var selectedIds: []
    signal activated(string id)
    signal contextRequested(string id, real sx, real sy)

    function isSelected(id) { return selectedIds.indexOf(id) !== -1 }

    /* Which icons fall inside a rubber band, in this column's coordinates.
       The marquee lives on the desktop and does not know where the icons are,
       so it asks. */
    function idsInRect(x, y, w, h) {
        var hits = []
        for (var i = 0; i < cells.count; i++) {
            var c = cells.itemAt(i)
            if (!c) continue
            if (c.x < x + w && c.x + c.width > x && c.y < y + h && c.y + c.height > y)
                hits.push(c.modelData.id)
        }
        return hits
    }

    Repeater {
        id: cells
        model: root.items

        Item {
            id: cell
            required property var modelData
            width: 96
            height: 88

            readonly property bool isOpen: root.openIds.indexOf(modelData.id) !== -1
            readonly property bool isStarting: root.startingIds.indexOf(modelData.id) !== -1
            readonly property bool selected: root.isSelected(modelData.id)
            readonly property bool lit: hover.hovered || isOpen || selected

            HoverHandler { id: hover }
            TapHandler { onTapped: root.activated(cell.modelData.id) }
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: function (point) {
                    var g = cell.mapToItem(null, point.position.x, point.position.y)
                    root.contextRequested(cell.modelData.id, g.x, g.y)
                }
            }

            Rectangle {
                id: frame
                width: 62; height: 62
                anchors.horizontalCenter: parent.horizontalCenter
                color: cell.selected ? Theme.tint(0.14)
                     : cell.lit ? Theme.tint(0.08) : Theme.tint(0.02)
                border.width: cell.selected ? 1 : 0
                border.color: Theme.accent
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                Brackets {
                    size: 9
                    color: cell.lit ? Theme.accent : Theme.line
                }

                AppIcon {
                    anchors.centerIn: parent
                    width: 30; height: 30
                    glyph: cell.modelData.glyph
                    source: Prefs.iconPaths[cell.modelData.id] || ""
                    lit: cell.lit
                    stroke: cell.lit ? Theme.accent : Theme.textBody
                }

                /* Open is a steady dot; starting is the same dot pulsing. One
                   mark, two states — the icon does not change shape under the
                   cursor mid-click. */
                Rectangle {
                    visible: cell.isOpen || cell.isStarting
                    width: 4; height: 4
                    color: Theme.accent
                    anchors { top: parent.top; right: parent.right; margins: 5 }
                    SequentialAnimation on opacity {
                        running: cell.isStarting
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 520 }
                        NumberAnimation { to: 1.0; duration: 520 }
                    }
                }

                Text {
                    visible: cell.isStarting
                    anchors { bottom: parent.bottom; right: parent.right; margins: 4 }
                    text: "···"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: 8
                }

                Text {
                    text: cell.modelData.code || ""
                    color: Theme.textMuted
                    opacity: cell.lit ? 0.9 : 0.45
                    font.family: Theme.mono
                    font.pixelSize: 6
                    anchors { bottom: parent.bottom; left: parent.left; margins: 4 }
                }
            }

            Text {
                text: cell.modelData.short || cell.modelData.title
                color: cell.lit ? Theme.accent : Theme.textBody
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: 1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: frame.bottom
                anchors.topMargin: 7
            }
        }
    }
}
