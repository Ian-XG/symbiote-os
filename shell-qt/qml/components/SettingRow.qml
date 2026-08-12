import QtQuick
import Symbiote

/* One setting: what it is on the left, the control on the right.
 *
 * Pulled out of SettingsWindow, where it was an inline `component` and so
 * unavailable to the Wi-Fi and Bluetooth panels — which is why those two grew
 * their own layouts and look like a different program.
 *
 * The height is measured rather than fixed at 52. A hint that wrapped to three
 * lines used to run out of the bottom of its row and under the one below it.
 */
Item {
    id: row

    property string label: ""
    property string hint: ""
    /** Puts the control on its own line, for anything full-width (a slider). */
    property bool stacked: false
    property bool enabled: true
    property bool separator: true

    default property alias control: holder.data

    width: parent ? parent.width : 400
    implicitHeight: stacked
        ? textCol.implicitHeight + holder.childrenRect.height + Theme.space5 + Theme.space4
        : Math.max(Theme.rowHeight, textCol.implicitHeight + Theme.space5)
    height: implicitHeight

    opacity: enabled ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }

    Column {
        id: textCol
        anchors {
            left: parent.left
            top: parent.top; topMargin: Theme.space3
            right: row.stacked ? parent.right : holder.left
            rightMargin: row.stacked ? 0 : Theme.space5
        }
        spacing: 3

        Text {
            width: parent.width
            text: row.label
            color: Theme.textBody
            font.family: Theme.mono
            font.pixelSize: Theme.sizeSm
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: row.hint
            visible: text !== ""
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            wrapMode: Text.WordWrap
            lineHeight: 1.35
        }
    }

    Item {
        id: holder
        anchors {
            right: parent.right
            left: row.stacked ? parent.left : undefined
            top: row.stacked ? textCol.bottom : undefined
            topMargin: row.stacked ? Theme.space4 : 0
            verticalCenter: row.stacked ? undefined : parent.verticalCenter
        }
        width: row.stacked ? undefined : childrenRect.width
        height: childrenRect.height
    }

    Rectangle {
        visible: row.separator
        anchors.bottom: parent.bottom
        width: parent.width; height: 1
        color: Qt.rgba(1, 1, 1, 0.05)
    }
}
