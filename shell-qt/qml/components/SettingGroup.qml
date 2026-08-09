import QtQuick
import Symbiote

/* A titled group of settings.
 *
 * The old Settings put nine to eleven rows in one undifferentiated column, so
 * "Scan line", "Background grid" and "Hologram detail" read as a list of
 * unrelated switches rather than as three answers to the same question. A
 * heading and a boundary cost nothing and turn a list into a structure.
 */
Item {
    id: group

    property string title: ""
    property string note: ""
    default property alias content: body.data

    width: parent ? parent.width : 400
    implicitHeight: head.height + body.childrenRect.height + Theme.space5
    height: implicitHeight

    Item {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: group.title === "" ? 0 : 30
        visible: group.title !== ""

        Text {
            id: headText
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: group.title
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            font.letterSpacing: Theme.trackWidest
        }
        // A rule running out from the heading: the HUD's own way of saying
        // "this band belongs together".
        Rectangle {
            anchors { left: headText.right; leftMargin: Theme.space4
                      right: noteText.visible ? noteText.left : parent.right
                      rightMargin: noteText.visible ? Theme.space4 : 0
                      verticalCenter: headText.verticalCenter }
            height: 1
            color: Theme.hairline
        }
        Text {
            id: noteText
            visible: group.note !== ""
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: group.note
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
        }
    }

    Column {
        id: body
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Theme.space2 }
    }
}
