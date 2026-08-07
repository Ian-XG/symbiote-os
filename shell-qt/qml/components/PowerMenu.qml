import QtQuick
import Symbiote

/* Shutdown, restart, log out — with a confirmation step.
   These are one click away from losing whatever is open, and on a live image
   from losing everything, so none of them fire on the first press. */
Item {
    id: root
    signal dismissed()

    property real bottomInset: 0
    property string armed: ""

    onVisibleChanged: if (!visible) armed = ""

    /* Centred and dimmed, not a sheet in the corner. These three actions end
       the session, and on a live image that means losing everything not
       written elsewhere — worth stopping the room for, rather than tucking
       into an edge like a tray menu. */
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismissed()
    }

    Item {
        id: sheet
        width: 320
        height: col.height + 34
        anchors.centerIn: parent

        // Arrives with a small lift rather than blinking into place.
        transform: Scale {
            origin.x: sheet.width / 2; origin.y: sheet.height / 2
            xScale: root.visible ? 1 : 0.96
            yScale: root.visible ? 1 : 0.96
            Behavior on xScale { NumberAnimation { duration: Theme.durFast
                                                   easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: Theme.durFast
                                                   easing.type: Easing.OutCubic } }
        }
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

        MouseArea { anchors.fill: parent }

        Rectangle { anchors.fill: parent; color: Theme.bgVoid }
        Rectangle {
            anchors.fill: parent
            color: Theme.panelStrong
            border.width: 1
            border.color: Theme.hairline
        }
        Brackets { color: Theme.accent }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 18 }

            Text {
                x: 18
                text: "SESSION"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWider
                bottomPadding: 8
            }

            Repeater {
                model: [
                    { key: "logout",   label: "LOG OUT",  confirm: "CONFIRM LOG OUT" },
                    { key: "restart",  label: "RESTART",  confirm: "CONFIRM RESTART" },
                    { key: "shutdown", label: "SHUT DOWN", confirm: "CONFIRM SHUT DOWN",
                      danger: true }
                ]

                Item {
                    id: row
                    required property var modelData
                    width: col.width
                    height: 38

                    readonly property bool isArmed: root.armed === modelData.key

                    HoverHandler { id: rowHover }
                    TapHandler {
                        onTapped: {
                            if (!row.isArmed) {
                                // First press arms; second commits.
                                root.armed = row.modelData.key
                                return
                            }
                            root.dismissed()
                            if (row.modelData.key === "shutdown") PowerActions.powerOff()
                            else if (row.modelData.key === "restart") PowerActions.restart()
                            else PowerActions.logOut()
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: row.isArmed ? Qt.rgba(1, 0.09, 0.27, 0.12)
                             : rowHover.hovered ? Theme.tint(0.10) : "transparent"
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 18
                                  verticalCenter: parent.verticalCenter }
                        text: row.isArmed ? row.modelData.confirm : row.modelData.label
                        color: row.isArmed ? Theme.alert
                             : row.modelData.danger ? Theme.textBody
                             : rowHover.hovered ? Theme.accent : Theme.textBody
                        font.family: Theme.mono
                        font.pixelSize: Theme.sizeXs
                        font.letterSpacing: Theme.trackWide
                    }
                }
            }

            Item {
                width: col.width
                height: 34
                HoverHandler { id: cancelHover }
                TapHandler { onTapped: root.dismissed() }
                Rectangle {
                    anchors.fill: parent
                    color: cancelHover.hovered ? Theme.tint(0.08) : "transparent"
                }
                Text {
                    anchors { left: parent.left; leftMargin: 18
                              verticalCenter: parent.verticalCenter }
                    text: "CANCEL"
                    color: cancelHover.hovered ? Theme.accent : Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                    font.letterSpacing: Theme.trackWide
                }
            }
        }
    }
}
