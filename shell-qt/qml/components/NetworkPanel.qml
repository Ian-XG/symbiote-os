import QtQuick
import Symbiote

/* Wi-Fi: scan, pick a network, type the password, connect.
   The service could do all of this from the start; for a long time nothing in
   the interface called it, which on a laptop means no internet. */
Item {
    id: root

    property string selected: ""
    property string passphrase: ""

    Column {
        anchors.fill: parent
        spacing: 0

        // ── header ─────────────────────────────────────────────
        Item {
            width: parent.width
            height: 52

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
                        var conn = ""
                        for (var i = 0; i < Network.networks.length; i++)
                            if (Network.networks[i].connected) conn = Network.networks[i].ssid
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
                spacing: 8

                HudButton {
                    visible: Network.available
                    text: Network.enabled ? "TURN OFF" : "TURN ON"
                    onClicked: Network.setEnabled(!Network.enabled)
                }
                HudButton {
                    visible: Network.available && Network.enabled
                    text: Network.busy ? "SCANNING…" : "SCAN"
                    enabled: !Network.busy
                    onClicked: Network.scan()
                }
                HudButton {
                    visible: {
                        for (var i = 0; i < Network.networks.length; i++)
                            if (Network.networks[i].connected) return true
                        return false
                    }
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
        Rectangle {
            visible: Network.lastError !== ""
            width: parent.width
            height: visible ? errText.implicitHeight + 18 : 0
            color: Qt.rgba(1, 0.09, 0.27, 0.08)
            border.width: 1
            border.color: Theme.alert
            Text {
                id: errText
                anchors { fill: parent; margins: 9 }
                text: Network.lastError
                color: Theme.alert
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                wrapMode: Text.WordWrap
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
            topPadding: 18
            text: "No networks found yet. Press SCAN — the first sweep after boot takes a moment."
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
        }

        // ── network list ───────────────────────────────────────
        ListView {
            width: parent.width
            height: Math.min(260, contentHeight)
            clip: true
            model: Network.enabled ? Network.networks : []
            interactive: contentHeight > height

            delegate: Column {
                required property var modelData
                width: ListView.view.width

                Item {
                    width: parent.width
                    height: 34

                    readonly property bool isSel: root.selected === modelData.ssid

                    TapHandler {
                        onTapped: {
                            Network.clearError()
                            root.passphrase = ""
                            root.selected = parent.isSel ? "" : modelData.ssid
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: parent.isSel ? Theme.tint(0.08) : "transparent"
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        spacing: 9

                        // Four bars beat a number for signal at a glance.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: 4
                                Rectangle {
                                    width: 3
                                    height: 4 + index * 3
                                    anchors.bottom: parent.bottom
                                    color: index < Math.max(1, Math.ceil(modelData.strength / 25))
                                           ? Theme.accent : Theme.line
                                }
                            }
                        }
                        Text {
                            text: (modelData.connected ? "● " : "") + modelData.ssid
                            color: modelData.connected ? Theme.accent : Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        spacing: 10
                        Text {
                            text: modelData.band; color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                        Text {
                            text: modelData.secure ? "WPA" : "OPEN"; color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                        Text {
                            text: modelData.strength + "%"; color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(1, 1, 1, 0.04)
                    }
                }

                // ── connect row ────────────────────────────────
                Item {
                    width: parent.width
                    height: visible ? 40 : 0
                    visible: root.selected === modelData.ssid && !modelData.connected

                    Rectangle {
                        visible: modelData.secure
                        anchors { left: parent.left; right: connectBtn.left; rightMargin: 8
                                  verticalCenter: parent.verticalCenter }
                        height: 28
                        color: Qt.rgba(0, 0, 0, 0.4)
                        border.width: 1
                        border.color: pwField.activeFocus ? Theme.accent : Theme.line

                        Text {
                            id: keyLabel
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "key"
                            color: Theme.accent
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeSm
                        }
                        TextInput {
                            id: pwField
                            anchors { left: keyLabel.right; leftMargin: 8; right: parent.right
                                      rightMargin: 10; verticalCenter: parent.verticalCenter }
                            echoMode: TextInput.Password
                            color: Theme.accent
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeSm
                            onTextChanged: root.passphrase = text
                            onAccepted: if (text.length) Network.connectTo(modelData.ssid, text)
                        }
                    }

                    HudButton {
                        id: connectBtn
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: Network.busy ? "CONNECTING…" : "CONNECT"
                        enabled: !Network.busy && (!modelData.secure || root.passphrase.length > 0)
                        onClicked: Network.connectTo(modelData.ssid, root.passphrase)
                    }
                }
            }
        }
    }

    // Small local button so the panel does not pull in a whole control set.
    component HudButton: Item {
        id: btn
        property string text: ""
        property bool danger: false
        property bool enabled: true
        signal clicked()

        width: btnLabel.width + 24
        height: 28

        HoverHandler { id: btnHover; enabled: btn.enabled }
        TapHandler { enabled: btn.enabled; onTapped: btn.clicked() }

        Rectangle {
            anchors.fill: parent
            color: btnHover.hovered ? Theme.tint(0.08) : "transparent"
            border.width: 1
            border.color: !btn.enabled ? Theme.line
                        : btn.danger ? Theme.alert : Theme.accent
        }
        Text {
            id: btnLabel
            anchors.centerIn: parent
            text: btn.text
            color: !btn.enabled ? Theme.textMuted : btn.danger ? Theme.alert : Theme.accent
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            font.letterSpacing: Theme.trackWide
        }
    }
}
