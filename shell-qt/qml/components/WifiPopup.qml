import QtQuick
import Symbiote

/* The tray's Wi-Fi menu.
   Wraps the same NetworkPanel the Settings tab uses rather than growing a
   second network implementation — one of them would drift, and it would be
   this one, since nobody opens Settings to join a network. */
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
        width: 440
        height: Math.min(440, root.height - root.inset - 40)
        edge: root.edge
        inset: root.inset
        shown: root.visible

        Item {
            id: head
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            height: 20

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "WIRELESS"
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

        NetworkPanel {
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
