import QtQuick
import Symbiote

/* Wi-Fi: scan, pick a network, join it.
 *
 * The password field used to be unconditional: every secure network showed one
 * whether or not NetworkManager already held the key. So joining a network you
 * had joined that morning meant typing the password again, and the natural
 * conclusion was that the machine forgets. It does not — the profile was
 * always saved; the panel simply never asked whether one existed.
 *
 * A known network now shows JOIN, and the field only appears when there is
 * genuinely nothing to try, or when you ask for it because the saved key is
 * wrong.
 */
Item {
    id: root

    property string selected: ""
    property string passphrase: ""
    /** Set when the operator asks to replace the key of a network we know. */
    property string retyping: ""

    function connectedSsid() {
        for (var i = 0; i < Network.networks.length; i++)
            if (Network.networks[i].connected) return Network.networks[i].ssid
        return ""
    }

    Column {
        anchors.fill: parent
        spacing: 0

        // ── header ─────────────────────────────────────────────
        Item {
            width: parent.width
            height: 54

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: "Wi-Fi"
                    color: Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeSm
                }
                Text {
                    text: {
                        if (!Network.available) return "no adapter"
                        var conn = root.connectedSsid()
                        return Network.device
                             + (conn ? " · connected to " + conn
                                     : Network.enabled ? " · not connected" : " · radio off")
                    }
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space3

                HudButton {
                    visible: Network.available
                    text: Network.enabled ? "TURN OFF" : "TURN ON"
                    onClicked: Network.setEnabled(!Network.enabled)
                }
                HudButton {
                    visible: Network.available && Network.enabled
                    text: "SCAN"
                    busy: Network.busy && Network.busySsid === ""
                    busyText: "SCANNING…"
                    onClicked: Network.scan()
                }
                HudButton {
                    visible: root.connectedSsid() !== ""
                    text: "DISCONNECT"
                    danger: true
                    onClicked: Network.disconnect()
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        // ── error ──────────────────────────────────────────────
        Item {
            width: parent.width
            height: Network.lastError !== "" ? errBox.height + Theme.space3 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }

            Rectangle {
                id: errBox
                width: parent.width
                height: errText.implicitHeight + 20
                y: Theme.space3
                color: Qt.rgba(1, 0.09, 0.27, 0.08)
                border.width: 1
                border.color: Theme.alert
                Text {
                    id: errText
                    anchors { fill: parent; margins: 10 }
                    text: Network.lastError
                    color: Theme.alert
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    wrapMode: Text.WordWrap
                }
            }
        }

        Text {
            visible: !Network.available
            width: parent.width
            topPadding: 18
            text: "This machine has no wireless device, or its driver did not load. "
                + "A wired connection still works."
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
            wrapMode: Text.WordWrap
        }

        Text {
            visible: Network.available && Network.enabled && Network.networks.length === 0
            width: parent.width
            topPadding: 18
            text: "No networks found yet. Press SCAN — the first sweep after boot takes a moment."
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
            wrapMode: Text.WordWrap
        }

        // ── network list ───────────────────────────────────────
        ListView {
            id: list
            width: parent.width
            height: Math.max(0, root.height - y)
            clip: true
            model: Network.enabled ? Network.networks : []
            interactive: contentHeight > height
            spacing: 0

            /* Rows slide apart when one expands rather than jumping. With a
               dozen networks in range the list re-laying out instantly makes
               it impossible to tell whether you opened the row you meant. */
            displaced: Transition {
                NumberAnimation { properties: "y"; duration: Prefs.dur(Theme.durFast)
                                  easing.type: Theme.easeOut }
            }

            delegate: Column {
                id: netRow
                required property var modelData
                width: ListView.view.width

                readonly property bool isSel: root.selected === netRow.modelData.ssid
                readonly property bool working: Network.busy
                                                && Network.busySsid === netRow.modelData.ssid
                // Ask for a key only when there is no saved one, or the
                // operator said the saved one is wrong.
                readonly property bool needsKey: netRow.modelData.secure
                                                 && (!netRow.modelData.saved
                                                     || root.retyping === netRow.modelData.ssid)

                Item {
                    width: parent.width
                    height: 36

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            Network.clearError()
                            root.passphrase = ""
                            root.retyping = ""
                            root.selected = netRow.isSel ? "" : netRow.modelData.ssid
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: netRow.isSel ? Theme.tint(0.09)
                             : rowHover.hovered ? Theme.tint(0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    }
                    Rectangle {
                        visible: netRow.modelData.connected
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: Theme.accent
                    }

                    Row {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left
                                  leftMargin: Theme.space3 }
                        spacing: Theme.space3

                        // Four bars beat a number for signal at a glance.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: 4
                                Rectangle {
                                    required property int index
                                    width: 3
                                    height: 4 + index * 3
                                    anchors.bottom: parent.bottom
                                    color: index < Math.max(1, Math.ceil(netRow.modelData.strength / 25))
                                           ? Theme.accent : Theme.line
                                }
                            }
                        }
                        Text {
                            text: netRow.modelData.ssid
                            color: netRow.modelData.connected ? Theme.accent : Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        /* The whole fix, made visible. A row that says SAVED is
                           a row that will not ask for a password. */
                        Rectangle {
                            visible: netRow.modelData.saved && !netRow.modelData.connected
                            anchors.verticalCenter: parent.verticalCenter
                            width: savedTag.implicitWidth + 10
                            height: 14
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.line
                            Text {
                                id: savedTag
                                anchors.centerIn: parent
                                text: "SAVED"
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: 7
                                font.letterSpacing: 0.8
                            }
                        }
                    }

                    Row {
                        anchors { verticalCenter: parent.verticalCenter; right: parent.right
                                  rightMargin: Theme.space3 }
                        spacing: Theme.space4
                        Text {
                            text: netRow.modelData.band; color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                        Text {
                            text: netRow.modelData.secure ? "WPA" : "OPEN"; color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                        Text {
                            text: netRow.modelData.strength + "%"; color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(1, 1, 1, 0.04)
                    }
                }

                // ── the expanded row ───────────────────────────
                Item {
                    width: parent.width
                    height: netRow.isSel ? (netRow.needsKey ? 82 : 46) : 0
                    clip: true
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                                           easing.type: Theme.easeOut } }

                    Column {
                        anchors { left: parent.left; right: parent.right; top: parent.top
                                  leftMargin: Theme.space3; rightMargin: Theme.space3
                                  topMargin: Theme.space2 }
                        spacing: Theme.space3

                        HudField {
                            visible: netRow.needsKey
                            width: parent.width
                            label: "key"
                            placeholder: "network password"
                            password: true
                            onEdited: function (t) { root.passphrase = t }
                            onAccepted: function (t) {
                                if (t.length) Network.connectTo(netRow.modelData.ssid, t)
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: Theme.space3

                            /* Offered only for a saved network, and it is the
                               escape hatch from the fix above: if the password
                               changed at the other end, this is how you say so
                               without having to forget the network first. */
                            HudButton {
                                visible: netRow.modelData.saved && !netRow.modelData.connected
                                         && root.retyping !== netRow.modelData.ssid
                                text: "NEW PASSWORD"
                                variant: "ghost"
                                onClicked: {
                                    root.passphrase = ""
                                    root.retyping = netRow.modelData.ssid
                                }
                            }
                            HudButton {
                                visible: netRow.modelData.saved
                                text: "FORGET"
                                danger: true
                                onClicked: {
                                    root.selected = ""
                                    root.retyping = ""
                                    Network.forget(netRow.modelData.ssid)
                                }
                            }
                            HudButton {
                                visible: !netRow.modelData.connected
                                text: netRow.modelData.saved && !netRow.needsKey ? "JOIN" : "CONNECT"
                                busy: netRow.working
                                busyText: "CONNECTING…"
                                enabled: !netRow.needsKey || root.passphrase.length > 0
                                         || !netRow.modelData.secure
                                onClicked: Network.connectTo(netRow.modelData.ssid,
                                                             netRow.needsKey ? root.passphrase : "")
                            }
                        }
                    }
                }
            }

            // Saved networks are only saved for this session on a live boot.
            footer: Item {
                width: list.width
                height: Network.available && !Network.profilesPersist() ? 52 : 0
                visible: height > 0
                Rectangle {
                    anchors { fill: parent; topMargin: Theme.space4 }
                    color: Theme.tint(0.05)
                    border.width: 1
                    border.color: Theme.hairline
                    Text {
                        anchors { fill: parent; margins: 9 }
                        text: "Networks joined here are remembered until you reboot. This is a "
                            + "live image with no persistent storage — add one and they keep."
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
