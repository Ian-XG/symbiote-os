import QtQuick
import Symbiote

/* Bluetooth: power the radio, scan, connect, forget.
 *
 * Devices appeared here and could not be connected to, for three reasons that
 * all had to go:
 *
 *  - The only action offered on a newly discovered device was PAIR. Connecting
 *    was a second click that appeared later, on a row that had meanwhile moved,
 *    and if you never pressed it the device sat paired and silent. There is one
 *    button now, and it pairs, trusts and connects.
 *
 *  - One global busy flag disabled every button on every row. While anything
 *    was working, nothing could be touched — and a call that never returned
 *    left the whole panel dead until the shell restarted.
 *
 *  - Devices that ask for a PIN were rejected outright, because there was
 *    nowhere to type one. Older keyboards, car stereos and speakers are almost
 *    all of these.
 */
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
            height: 54

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
                spacing: Theme.space3

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
        Item {
            width: parent.width
            height: Bluetooth.pendingPath !== "" ? prompt.height + Theme.space3 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                                   easing.type: Theme.easeOut } }

            Rectangle {
                id: prompt
                width: parent.width
                y: Theme.space3
                height: Bluetooth.pendingNeedsInput ? 96 : 66
                color: Theme.tint(0.08)
                border.width: 1
                border.color: Theme.accent

                Column {
                    anchors { left: parent.left; leftMargin: 12; top: parent.top; topMargin: 11
                              right: promptButtons.left; rightMargin: 12 }
                    spacing: 5

                    Text {
                        width: parent.width
                        text: Bluetooth.pendingNeedsInput
                              ? (Bluetooth.pendingInputNumeric
                                 ? "Type the passkey shown on the other device"
                                 : "Type the device's PIN — usually 0000 or 1234, "
                                   + "or printed on a label")
                              : Bluetooth.pendingNeedsAnswer
                              ? (Bluetooth.pendingCode ? "Confirm this code matches the other device"
                                                       : "Allow this device to pair?")
                              : "Type this code on the other device"
                        color: Theme.textBody
                        font.family: Theme.mono
                        font.pixelSize: Theme.sizeXs
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        visible: Bluetooth.pendingCode !== ""
                        text: Bluetooth.pendingCode
                        color: Theme.accent
                        font.family: Theme.mono
                        font.pixelSize: Theme.sizeLg
                        font.letterSpacing: Theme.trackWidest
                    }
                    HudField {
                        id: pinField
                        visible: Bluetooth.pendingNeedsInput
                        width: 180
                        label: "pin"
                        placeholder: Bluetooth.pendingInputNumeric ? "digits" : "code"
                        numeric: Bluetooth.pendingInputNumeric
                        maximumLength: 16
                        onAccepted: function (t) { Bluetooth.submitPairingCode(t) }
                    }
                }

                Row {
                    id: promptButtons
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space3

                    HudButton {
                        visible: Bluetooth.pendingNeedsInput
                        text: "SEND"
                        onClicked: Bluetooth.submitPairingCode(pinField.text)
                    }
                    HudButton {
                        visible: Bluetooth.pendingNeedsAnswer
                        text: "CONFIRM"
                        onClicked: Bluetooth.confirmPairing(true)
                    }
                    HudButton {
                        visible: Bluetooth.pendingNeedsAnswer || Bluetooth.pendingNeedsInput
                        text: "REJECT"
                        danger: true
                        onClicked: {
                            if (Bluetooth.pendingNeedsInput) Bluetooth.submitPairingCode("")
                            else Bluetooth.confirmPairing(false)
                        }
                    }
                }
            }
        }

        // ── error ──────────────────────────────────────────────
        Item {
            width: parent.width
            height: Bluetooth.lastError !== "" ? btErrBox.height + Theme.space3 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }

            Rectangle {
                id: btErrBox
                width: parent.width
                y: Theme.space3
                height: btErr.implicitHeight + 20
                color: Qt.rgba(1, 0.09, 0.27, 0.08)
                border.width: 1
                border.color: Theme.alert
                Text {
                    id: btErr
                    anchors { fill: parent; margins: 10 }
                    text: Bluetooth.lastError
                    color: Theme.alert
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                }
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
            width: parent.width
            topPadding: 18
            text: "Nothing found yet. Press SCAN, and put the device into pairing mode."
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
            wrapMode: Text.WordWrap
        }

        // ── device list ────────────────────────────────────────
        ListView {
            id: btList
            width: parent.width
            height: Math.max(0, root.height - y)
            clip: true
            model: Bluetooth.powered ? Bluetooth.devices : []
            interactive: contentHeight > height

            displaced: Transition {
                NumberAnimation { properties: "y"; duration: Prefs.dur(Theme.durFast)
                                  easing.type: Theme.easeOut }
            }

            delegate: Column {
                id: devRow
                required property var modelData
                width: ListView.view.width

                readonly property bool isSel: root.selected === devRow.modelData.path
                // Only this row is busy; every other row stays usable.
                readonly property bool working: Bluetooth.busy
                                                && Bluetooth.busyPath === devRow.modelData.path

                Item {
                    width: parent.width
                    height: 36

                    HoverHandler { id: devHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root.selected = devRow.isSel ? "" : devRow.modelData.path
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: devRow.isSel ? Theme.tint(0.09)
                             : devHover.hovered ? Theme.tint(0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    }
                    Rectangle {
                        visible: devRow.modelData.connected
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: Theme.accent
                    }

                    Row {
                        anchors { left: parent.left; leftMargin: Theme.space3
                                  verticalCenter: parent.verticalCenter }
                        spacing: Theme.space3

                        // Same four-bar read as Wi-Fi. RSSI is dBm: -50 is
                        // across the desk, -90 is barely there.
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
                                    color: {
                                        if (devRow.modelData.rssi === undefined
                                            || devRow.modelData.rssi === null)
                                            return Theme.line
                                        var q = Math.max(0, Math.min(100,
                                                    2 * (devRow.modelData.rssi + 100)))
                                        return index < Math.max(1, Math.ceil(q / 25))
                                               ? Theme.accent : Theme.line
                                    }
                                }
                            }
                        }
                        Text {
                            text: devRow.modelData.name
                            color: devRow.modelData.connected ? Theme.accent : Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            visible: devRow.modelData.paired && !devRow.modelData.connected
                            anchors.verticalCenter: parent.verticalCenter
                            width: pairedTag.implicitWidth + 10
                            height: 14
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.line
                            Text {
                                id: pairedTag
                                anchors.centerIn: parent
                                text: "PAIRED"
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: 7
                                font.letterSpacing: 0.8
                            }
                        }
                    }

                    Row {
                        anchors { right: parent.right; rightMargin: Theme.space3
                                  verticalCenter: parent.verticalCenter }
                        spacing: Theme.space4
                        Text {
                            text: devRow.modelData.icon || "device"
                            color: Theme.textMuted
                            font.family: Theme.mono; font.pixelSize: Theme.size2xs
                        }
                        Text {
                            text: (devRow.modelData.rssi === undefined
                                   || devRow.modelData.rssi === null)
                                  ? "—" : devRow.modelData.rssi + " dBm"
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
                    height: devRow.isSel ? 46 : 0
                    clip: true
                    visible: height > 0
                    Behavior on height { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                                           easing.type: Theme.easeOut } }

                    Text {
                        anchors { left: parent.left; leftMargin: Theme.space3
                                  verticalCenter: parent.verticalCenter }
                        text: devRow.modelData.address
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                    }

                    Row {
                        anchors { right: parent.right; rightMargin: Theme.space3
                                  verticalCenter: parent.verticalCenter }
                        spacing: Theme.space3

                        /* One button. It pairs first when it has to — which is
                           the whole difference between a device you can list
                           and a device you can use. */
                        HudButton {
                            visible: !devRow.modelData.connected
                            text: "CONNECT"
                            busy: devRow.working
                            busyText: devRow.modelData.paired ? "CONNECTING…" : "PAIRING…"
                            onClicked: Bluetooth.connectDevice(devRow.modelData.path)
                        }
                        HudButton {
                            visible: devRow.modelData.connected
                            text: "DISCONNECT"
                            busy: devRow.working
                            busyText: "…"
                            onClicked: Bluetooth.disconnectDevice(devRow.modelData.path)
                        }
                        HudButton {
                            visible: devRow.modelData.paired
                            text: "FORGET"
                            danger: true
                            onClicked: {
                                root.selected = ""
                                Bluetooth.forget(devRow.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }
}
