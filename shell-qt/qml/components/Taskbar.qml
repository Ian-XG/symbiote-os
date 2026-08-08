import QtQuick
import QtQuick.Shapes
import Symbiote

/* Full-width taskbar: launcher, pinned apps, system tray. */
Item {
    id: root
    height: 72

    property var openIds: []
    property var startingIds: []
    property string clock: ""
    property string date: ""
    property bool vpnUp: false
    property string ifaceName: ""
    property int cpu: 0
    property int battery: 100
    property bool batteryPresent: false
    property bool batteryCharging: false
    property bool launcherOpen: false

    signal launched(string id)
    signal contextRequested(string id, real sx, real sy)
    signal wifiRequested()
    signal powerRequested()
    signal mediaRequested()

    property bool mediaOpen: false

    property bool powerOpen: false

    property bool wifiConnected: false
    property bool wifiAvailable: false
    property string wifiSsid: ""
    property bool wifiOpen: false
    signal menuToggled()

    Rectangle {
        anchors.fill: parent
        /* A near-black base carrying a faint accent tint, rather than one
           hand-mixed dark green — which stayed green in blue mode. The base
           does the separating from the desktop; the tint only colours it. */
        color: Qt.rgba(0, 0, 0, 0.72)
        Rectangle {
            anchors.fill: parent
            color: Theme.tint(0.05)
        }
        Rectangle {
            width: parent.width; height: 1
            color: Theme.hairline
        }
    }

    // ── launcher ───────────────────────────────────────────────
    Item {
        id: menuButton
        // Square, because it is now a single icon rather than an icon and a word.
        width: 46
        height: 46
        anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }

        HoverHandler { id: menuHover }
        TapHandler { onTapped: root.menuToggled() }

        Rectangle {
            anchors.fill: parent
            color: (menuHover.hovered || root.launcherOpen)
                   ? Theme.tint(0.08) : "transparent"
            border.width: 1
            border.color: (menuHover.hovered || root.launcherOpen)
                          ? Theme.accent : Theme.tint(0.10)
        }

        /* The mass itself. This corner is where a system puts its mark, and
           the shell had a generic app-grid there — correct as a convention,
           anonymous as an identity. Everything else in the interface stays
           drawn in line art; this is the one bitmap, because it is the
           product's own object and not an idea to redraw. */
        Image {
            id: menuRow
            anchors.centerIn: parent
            width: 26; height: 26
            source: "qrc:/assets/symbiote-64.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            sourceSize.width: 64
            sourceSize.height: 64
            // Dimmed until wanted, so it sits in the bar rather than shouting
            // from it.
            opacity: (menuHover.hovered || root.launcherOpen) ? 1.0 : 0.82
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }
    }

    // ── pinned apps ────────────────────────────────────────────
    Row {
        id: pinnedRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: {
                var out = []
                for (var i = 0; i < Prefs.taskbarIds.length; i++) {
                    var a = Prefs.appById(Prefs.taskbarIds[i])
                    if (a) out.push(a)
                }
                return out
            }

            Item {
                id: icon
                required property var modelData
                width: 46; height: 46

                readonly property bool isOpen: root.openIds.indexOf(modelData.id) !== -1
                readonly property bool isStarting: root.startingIds.indexOf(modelData.id) !== -1
                readonly property bool lit: iconHover.hovered || isOpen || isStarting

                HoverHandler { id: iconHover }
                TapHandler { onTapped: root.launched(icon.modelData.id) }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: function (point) {
                        var g = icon.mapToItem(null, point.position.x, point.position.y)
                        root.contextRequested(icon.modelData.id, g.x, g.y)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: iconHover.hovered ? Theme.tint(0.08) : "transparent"
                    border.width: 1
                    border.color: iconHover.hovered ? Theme.tint(0.10) : "transparent"
                }

                // Drawn glyphs, not the app's initial letter — a row of bare
                // capitals told you nothing about what each button does.
                AppIcon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -3
                    width: 22; height: 22
                    glyph: icon.modelData.glyph
                    source: Prefs.iconPaths[icon.modelData.id] || ""
                    lit: icon.lit
                    stroke: icon.lit ? Theme.accent : Theme.textMuted
                }

                // Open indicator: a bar, wide when running.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    width: (icon.isOpen || icon.isStarting) ? 14 : 4
                    height: 2
                    color: (icon.isOpen || icon.isStarting) ? Theme.accent : Theme.line
                    Behavior on width { NumberAnimation { duration: Theme.durFast } }
                    SequentialAnimation on opacity {
                        running: icon.isStarting
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 520 }
                        NumberAnimation { to: 1.0;  duration: 520 }
                    }
                }
            }
        }
    }

    /* Open windows, between the pinned launchers and the tray.
       The bar used to show only what had been pinned to it: two Firefox
       windows were one button, and a window nobody had pinned did not appear
       at all. These come from the compositor. */
    /* Bounded on both sides and clipped. A Row grows with its content and had
       no right edge, so a fourth window pushed the list under the clock. */
    Item {
        anchors { left: pinnedRow.right; leftMargin: 16
                  right: tray.left; rightMargin: 16
                  verticalCenter: parent.verticalCenter }
        height: 30
        clip: true
        visible: Windows.available && Windows.windows.length > 0

    Row {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: 4

        Rectangle {
            width: 1; height: 22
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.line
        }

        Repeater {
            model: Windows.windows

            Item {
                id: winButton
                required property var modelData
                width: Math.min(150, winLabel.implicitWidth + 22)
                height: 30
                anchors.verticalCenter: parent.verticalCenter

                HoverHandler { id: winHover }
                TapHandler {
                    // Clicking the focused window puts it away, as everywhere else.
                    onTapped: modelData.activated ? Windows.minimize(modelData.key)
                                                  : Windows.activate(modelData.key)
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: Windows.closeWindow(winButton.modelData.key)
                }

                Rectangle {
                    anchors.fill: parent
                    color: modelData.activated ? Theme.tint(0.12)
                         : winHover.hovered ? Theme.tint(0.06) : "transparent"
                    border.width: 1
                    border.color: modelData.activated ? Theme.accent : Theme.line
                }

                Text {
                    id: winLabel
                    anchors { left: parent.left; leftMargin: 10
                              right: parent.right; rightMargin: 10
                              verticalCenter: parent.verticalCenter }
                    text: winButton.modelData.title
                    color: modelData.minimized ? Theme.textMuted
                         : modelData.activated ? Theme.accent : Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    elide: Text.ElideRight
                    // Minimised is stated by the label going quiet, not by an
                    // extra badge competing with the open-app dots below.
                    opacity: modelData.minimized ? 0.55 : 1
                }
            }
        }
    }

    }

    // ── tray ───────────────────────────────────────────────────
    Row {
        id: tray
        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
        spacing: 14

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: vpnText.width + 16
            height: 20
            color: "transparent"
            border.width: 1
            border.color: root.vpnUp ? Theme.accent : Theme.line
            Text {
                id: vpnText
                anchors.centerIn: parent
                text: "VPN"
                color: root.vpnUp ? Theme.accent : Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
            }
        }

        /* Wi-Fi. The tray used to print the interface name and nothing else —
           no way in, and "wlp3s0" tells an operator nothing about whether they
           are online. */
        Item {
            id: wifiButton
            anchors.verticalCenter: parent.verticalCenter
            width: wifiRow.width + 14
            height: 26

            HoverHandler { id: wifiHover }
            TapHandler { onTapped: root.wifiRequested() }

            Rectangle {
                anchors.fill: parent
                color: (wifiHover.hovered || root.wifiOpen) ? Theme.tint(0.08) : "transparent"
                border.width: 1
                border.color: (wifiHover.hovered || root.wifiOpen)
                              ? Theme.accent : "transparent"
            }

            Row {
                id: wifiRow
                anchors.centerIn: parent
                spacing: 6
                GlyphIcon {
                    width: 16; height: 16
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "wifi"
                    stroke: root.wifiConnected ? Theme.accent : Theme.textMuted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.wifiConnected ? root.wifiSsid
                        : root.wifiAvailable ? "not connected" : "no adapter"
                    color: root.wifiConnected ? Theme.accent : Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    elide: Text.ElideRight
                    // Long SSIDs must not push the clock off the bar.
                    width: Math.min(implicitWidth, 110)
                }
            }
        }

        /* Only shown when there is a radio. A machine without Bluetooth should
           say nothing about it rather than carry a permanently dead badge. */
        Rectangle {
            visible: Bluetooth.present
            anchors.verticalCenter: parent.verticalCenter
            width: btText.width + 16
            height: 20
            color: "transparent"
            border.width: 1
            border.color: Bluetooth.powered ? Theme.accent : Theme.line
            Row {
                id: btText
                anchors.centerIn: parent
                spacing: 5
                GlyphIcon {
                    width: 14; height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "bluetooth"
                    stroke: Bluetooth.powered ? Theme.accent : Theme.textMuted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: {
                        var n = 0
                        for (var i = 0; i < Bluetooth.devices.length; i++)
                            if (Bluetooth.devices[i].connected) n++
                        return n ? String(n) : ""
                    }
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                }
            }
        }

        // Labelled. An unlabelled percentage sitting next to the battery's
        // percentage told you nothing about which was which.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CPU " + root.cpu + "%"
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            font.letterSpacing: Theme.trackWide
        }
        BatteryGauge {
            visible: root.batteryPresent
            anchors.verticalCenter: parent.verticalCenter
            percent: root.battery
            charging: root.batteryCharging
            present: root.batteryPresent
        }
        /* Volume and brightness. Neither existed anywhere in the interface. */
        Item {
            width: 26; height: 26
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.audioAvailable || Media.backlightAvailable
            HoverHandler { id: mediaHover }
            TapHandler { onTapped: root.mediaRequested() }
            Rectangle {
                anchors.fill: parent
                color: (mediaHover.hovered || root.mediaOpen) ? Theme.tint(0.10) : "transparent"
                border.width: 1
                border.color: (mediaHover.hovered || root.mediaOpen)
                              ? Theme.accent : "transparent"
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: 16; height: 16
                glyph: "volume"
                // Muted is stated by the icon turning red, not by a slash that
                // would be three pixels at this size.
                stroke: Media.muted ? Theme.alert
                      : (mediaHover.hovered || root.mediaOpen) ? Theme.accent
                      : Theme.textMuted
            }
        }

        /* The way out. There was none: on a live image the only exit was the
           power button on the case, which is how you corrupt a USB stick. */
        Item {
            width: 26; height: 26
            anchors.verticalCenter: parent.verticalCenter
            HoverHandler { id: powerHover }
            TapHandler { onTapped: root.powerRequested() }
            Rectangle {
                anchors.fill: parent
                color: (powerHover.hovered || root.powerOpen) ? Theme.tint(0.10) : "transparent"
                border.width: 1
                border.color: (powerHover.hovered || root.powerOpen)
                              ? Theme.alert : "transparent"
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: 16; height: 16
                glyph: "power"
                stroke: (powerHover.hovered || root.powerOpen) ? Theme.alert : Theme.textMuted
            }
        }

        // Date over time, right-aligned in the corner.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                anchors.right: parent.right
                text: root.date
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
            }
            Text {
                anchors.right: parent.right
                text: root.clock
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: Theme.sizeMd
                font.letterSpacing: Theme.trackWide
            }
        }
    }
}
