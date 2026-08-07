import QtQuick
import Symbiote

/* Bluetooth: power the radio, scan, pair, connect, forget.
   The Qt port had no Bluetooth at all — the taskbar could only ever report
   "NO ADAPTER" because nothing was reading org.bluez. */
Item {
    id: root

    property string selected: ""

    // Scanning is a state, not a background chore: leaving discovery running
    // drains the radio and floods the list, so it stops when you leave.
    Component.onDestruction: Bluetooth.stopDiscovery()

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
                    text: "Bluetooth"
                    color: Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeSm
                }
                Text {
                    text: {
                        if (!Bluetooth.present)
                            return "no adapter"
                        var conn = 0
                        for (var i = 0; i < Bluetooth.devices.length; i++)
                            if (Bluetooth.devices[i].connected) conn++
                        return (Bluetooth.adapterName || "adapter")
                             + (!Bluetooth.powered ? " · radio off"
                                : conn ? " · " + conn + " connected"
                                : Bluetooth.discovering ? " · scanning" : " · idle")
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
                    visible: Bluetooth.present
                    text: Bluetooth.powered ? "TURN OFF" : "TURN ON"
                    onClicked: Bluetooth.setPowered(!Bluetooth.powered)
                }
                HudButton {
                    visible: Bluetooth.present && Bluetooth.powered
                    text: Bluetooth.discovering ? "STOP SCAN" : "SCAN"
                    onClicked: Bluetooth.discovering ? Bluetooth.stopDiscovery()
                                                     : Bluetooth.startDiscovery()
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }
        }

        /* Pairing prompt. BlueZ asks the agent whether to allow a pairing and
           holds the call open until it is answered; this is where that answer
           comes from. Nothing is auto-accepted — otherwise anything in range
           could pair itself with the laptop sitting on a desk. */
        Rectangle {
            visible: Bluetooth.pendingPath !== ""
            width: parent.width
            height: visible ? 62 : 0
            color: Theme.tint(0.08)
            border.width: 1
            border.color: Theme.accent

            Column {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text {
                    text: Bluetooth.pendingNeedsAnswer
                          ? (Bluetooth.pendingCode ? "Confirm this code matches the other device"
                                                   : "Allow this device to pair?")
                          : "Type this code on the other device"
                    color: Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                }
                Text {
                    visible: Bluetooth.pendingCode !== ""
                    text: Bluetooth.pendingCode
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeLg
                    font.letterSpacing: Theme.trackWidest
                }
            }

            Row {
                visible: Bluetooth.pendingNeedsAnswer
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8
                HudButton {
                    text: "CONFIRM"
                    onClicked: Bluetooth.confirmPairing(true)
                }
                HudButton {
                    text: "REJECT"
                    danger: true
                    onClicked: Bluetooth.confirmPairing(false)
                }
            }
        }

        // ── error ──────────────────────────────────────────────
        Rectangle {
            visible: Bluetooth.lastError !== ""
            width: parent.width
            height: visible ? btErr.implicitHeight + 18 : 0
            color: Qt.rgba(1, 0.09, 0.27, 0.08)
            border.width: 1
            border.color: Theme.alert
            Text {
                id: btErr
                anchors { fill: parent; margins: 9 }
                text: Bluetooth.lastError
                color: Theme.alert
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                wrapMode: Text.WordWrap
            }
        }

        /* Naming the likeliest cause matters here: on a Mac the radio is a
           Broadcom part whose firmware Apple ships and Debian cannot. Without
           this the panel just looks broken. */
        Text {
            visible: !Bluetooth.present
            width: parent.width
            topPadding: 18
            text: "No Bluetooth adapter is present, or its firmware did not load. "
                + "Macs need a Broadcom blob that Debian cannot redistribute; "
                + "a USB dongle works without it."
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
            wrapMode: Text.WordWrap
        }

        Text {
            visible: Bluetooth.present && Bluetooth.powered
                     && Bluetooth.devices.length === 0
            topPadding: 18
            text: "Nothing found yet. Press SCAN, and put the device into pairing mode."
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
        }

        // ── device list ────────────────────────────────────────
        ListView {
            width: parent.width
            height: Math.min(260, contentHeight)
            clip: true
            model: Bluetooth.powered ? Bluetooth.devices : []
            interactive: contentHeight > height

            delegate: Column {
                required property var modelData
                width: ListView.view.width

                Item {
                    width: parent.width
                    height: 34

                    readonly property bool isSel: root.selected === modelData.path

                    TapHandler {
                        onTapped: root.selected = parent.isSel ? "" : modelData.path
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: parent.isSel ? Theme.tint(0.08) : "transparent"
                    }

                    Row {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        spacing: 9

                        // Same four-bar read as Wi-Fi. RSSI is dBm: -50 is
                        // across the desk, -90 is barely there.
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Repeater {
                                model: 4
                                Rectangle {
                                    width: 3
                                    height: 4 + index * 3
                                    anchors.bottom: parent.bottom
                                    color: {
                                        if (modelData.rssi === undefined || modelData.rssi === null)
                                            return Theme.line
                                        var q = Math.max(0, Math.min(100, 2 * (modelData.rssi + 100)))
                                        return index < Math.max(1, Math.ceil(q / 25))
                                               ? Theme.accent : Theme.line
                                    }
                                }
                            }
                        }
                        Text {
                            text: (modelData.connected ? "● " : "") + modelData.name
                            color: modelData.connected ? Theme.accent : Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 10
                        Text {
                            text: modelData.icon || "device"
                            color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                        Text {
                            text: modelData.paired ? "PAIRED" : "NEW"
                            color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                        Text {
                            text: (modelData.rssi === undefined || modelData.rssi === null)
                                  ? "—" : modelData.rssi + " dBm"
                            color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(1, 1, 1, 0.04)
                    }
                }

                // ── actions ────────────────────────────────────
                Item {
                    width: parent.width
                    height: visible ? 40 : 0
                    visible: root.selected === modelData.path

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: modelData.address
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                    }

                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 8

                        HudButton {
                            visible: !modelData.paired
                            text: Bluetooth.busy ? "PAIRING…" : "PAIR"
                            enabled: !Bluetooth.busy
                            onClicked: Bluetooth.pair(modelData.path)
                        }
                        HudButton {
                            visible: modelData.paired && !modelData.connected
                            text: Bluetooth.busy ? "CONNECTING…" : "CONNECT"
                            enabled: !Bluetooth.busy
                            onClicked: Bluetooth.connectDevice(modelData.path)
                        }
                        HudButton {
                            visible: modelData.connected
                            text: "DISCONNECT"
                            onClicked: Bluetooth.disconnectDevice(modelData.path)
                        }
                        HudButton {
                            visible: modelData.paired
                            text: "FORGET"
                            danger: true
                            onClicked: {
                                root.selected = ""
                                Bluetooth.forget(modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }

    // Same local button as the Wi-Fi panel: no control set pulled in for four
    // buttons.
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
