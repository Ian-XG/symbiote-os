import QtQuick
import Symbiote

/* The tray's Bluetooth menu.
   Wraps the same BluetoothPanel the Settings tab uses. Until now the only way
   to pair anything was Settings → BLUETOOTH, which is three clicks and a
   guess; the badge in the tray showed the radio and did nothing when pressed. */
Item {
    id: root
    signal dismissed()

    property real bottomInset: 0

    // Click-away.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismissed()
    }

    Item {
        id: sheet
        width: 420
        height: 440
        anchors {
            right: parent.right; rightMargin: 18
            bottom: parent.bottom; bottomMargin: root.bottomInset + 8
        }

        // Swallow clicks so the click-away behind does not close it.
        MouseArea { anchors.fill: parent }

        // Rises from the bar rather than appearing.
        transform: Translate {
            y: root.visible ? 0 : 12
            Behavior on y { NumberAnimation { duration: Theme.durMed
                                              easing.type: Easing.OutCubic } }
        }
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        Rectangle {
            anchors.fill: parent
            // Fully opaque. At 96% the panel behind bled through the text,
            // which is what made the Settings window unreadable on the laptop.
            color: Theme.bgVoid
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.panelStrong
            border.width: 1
            border.color: Theme.hairline
        }
        Brackets { color: Theme.accent }

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
                HoverHandler { id: closeHover }
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
