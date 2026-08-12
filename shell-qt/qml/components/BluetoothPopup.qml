import QtQuick
import Symbiote

/* The tray's Bluetooth menu.
   Wraps the same BluetoothPanel the Settings tab uses, for the same reason the
   Wi-Fi one does: a second implementation would drift, and it would be this
   one. Until now the badge in the tray reported that a radio existed and did
   nothing at all when pressed — pairing anything meant going through Settings. */
Item {
    id: root
    signal dismissed()

    property string edge: "bottom"
    property real inset: 0

    // Click-away.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismissed()
    }

    TraySheet {
        width: 460
        height: Math.min(500, root.height - root.inset - 40)
        edge: root.edge
        inset: root.inset
        shown: root.visible

        Item {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            height: 20

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "BLUETOOTH"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: Theme.sizeXs
                font.letterSpacing: Theme.trackWider
            }

            Item {
                width: 20; height: 20
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.dismissed() }
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: closeHover.hovered ? Theme.accent : Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeMd
                }
            }
        }

        BluetoothPanel {
            anchors {
                top: head.bottom; topMargin: 4
                left: parent.left; leftMargin: 16
                right: parent.right; rightMargin: 16
                bottom: parent.bottom; bottomMargin: 16
            }
            clip: true
        }
    }
}
