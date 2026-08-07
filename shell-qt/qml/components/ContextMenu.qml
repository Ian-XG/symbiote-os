import QtQuick
import Symbiote

/* Right-click menu, in the shell's own vocabulary rather than a toolkit's.
   Built from a plain list so a caller decides what a right-click means in its
   own context: the desktop offers different things from an icon. */
Item {
    id: root
    visible: false

    /* [{ label, action, danger, separator, enabled }] — `action` is the string
       handed back through picked(). */
    property var entries: []
    signal picked(string action)

    // Opened at a point in the parent's coordinates.
    function popup(x, y) {
        var w = sheet.width
        var h = sheet.height
        // Flip rather than run off the edge.
        sheet.x = (x + w > root.width) ? Math.max(0, x - w) : x
        sheet.y = (y + h > root.height) ? Math.max(0, y - h) : y
        root.visible = true
    }
    function dismiss() { root.visible = false }

    // Click-away. Covers the whole surface so the next click closes the menu.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismiss()
    }

    /* An Item wrapping a Column, not a Column.
       The backdrop used to be two `anchors.fill: parent` Rectangles declared
       inside the Column — and a Column positions every child in its vertical
       run, ignoring anchors. So the menu shipped with no background whatever:
       just floating text and separators over the wallpaper. */
    Item {
        id: sheet
        width: 210
        height: rows.height

        Rectangle {
            anchors.fill: parent
            color: Theme.bgVoid
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.panelStrong
            border.width: 1
            border.color: Theme.hairline
        }

        Column {
            id: rows
            width: parent.width

        // Opens with a short wipe, so it reads as arriving rather than blinking.
        transform: Scale {
            origin.x: 0; origin.y: 0
            yScale: root.visible ? 1 : 0.85
            Behavior on yScale { NumberAnimation { duration: Theme.durFast
                                                   easing.type: Easing.OutCubic } }
        }
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        Repeater {
            model: root.entries

            Item {
                id: entry
                required property var modelData
                width: rows.width
                height: modelData.separator ? 7 : 30

                readonly property bool usable: !modelData.separator
                                               && modelData.enabled !== false

                HoverHandler { id: entryHover; enabled: entry.usable }
                TapHandler {
                    enabled: entry.usable
                    onTapped: {
                        root.dismiss()
                        root.picked(entry.modelData.action)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: entryHover.hovered
                    color: Theme.tint(0.10)
                }

                Rectangle {
                    visible: entry.modelData.separator === true
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: 1
                    color: Theme.line
                }

                Text {
                    visible: !entry.modelData.separator
                    anchors { left: parent.left; leftMargin: 14
                              verticalCenter: parent.verticalCenter }
                    text: entry.modelData.label || ""
                    color: !entry.usable ? Theme.textMuted
                         : entry.modelData.danger ? Theme.alert
                         : entryHover.hovered ? Theme.accent : Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                    font.letterSpacing: Theme.trackWide
                }
            }
        }
        }
    }
}
