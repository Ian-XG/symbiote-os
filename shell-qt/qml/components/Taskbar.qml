import QtQuick
import Symbiote

/* The taskbar, on whichever edge it has been put.
 *
 * Two things were wrong with it.
 *
 * The pinned row was centred on the bar and the open-window list was anchored
 * between that row and the tray. So the more was pinned, the less room the
 * window list had — and since the centred row grows in both directions, past a
 * certain point the space between it and the tray went to zero and the window
 * list was simply not drawn, or drawn under the clock. Open windows are the
 * part of a taskbar people actually use, and they were the part that got
 * squeezed out.
 *
 * And it could only ever be at the bottom. A 16:9 laptop panel has vertical
 * pixels to spare in neither direction, and 72 of them at the bottom is a real
 * cost; on the side it is width, of which there is plenty.
 *
 * So the bar is three zones — launcher and pinned, then windows, then the tray
 * — laid out along whichever axis it is on. The window zone takes what is left
 * after the two fixed ends and scrolls inside itself. It cannot be covered,
 * because nothing is on top of it.
 */
Item {
    id: root

    /** "bottom" | "top" | "left" | "right" */
    property string edge: "bottom"
    readonly property bool vertical: edge === "left" || edge === "right"
    /** The whole bar, label column included. */
    property int thickness: 72
    /* Just the band the icons sit in. On a vertical bar the rest is the column
       the names are written in, and sizing buttons from the full thickness
       made them half as big again as they should be, with the spacing to
       match. */
    property int band: 72

    /* A sensible default for a bar filling one edge of its parent. Both real
       callers override all four of x, y, width and height with plain
       geometry — see the note in Main.qml about what anchoring this thing per
       edge used to do to the screen. */
    height: vertical ? (parent ? parent.height : 0) : thickness
    width: vertical ? thickness : (parent ? parent.width : 0)

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
    /* Middle click. The convention on every dock that has more than one window
       per application, and the only way to get a second terminal without going
       through a context menu. */
    signal newWindowRequested(string id)
    signal contextRequested(string id, real sx, real sy)
    signal wifiRequested()
    signal powerRequested()
    signal mediaRequested()
    signal menuToggled()

    property bool mediaOpen: false
    property bool powerOpen: false
    property bool wifiConnected: false
    property bool wifiAvailable: false
    property string wifiSsid: ""
    property bool wifiOpen: false

    // Icon buttons scale with the bar rather than staying 46px on a 88px bar.
    readonly property int cell: Math.round(root.band * 0.64)
    readonly property int iconSize: Math.max(16, Math.round(cell * 0.46))

    // ── the bar itself ─────────────────────────────────────────
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
    }
    // The hairline goes on whichever side faces the desktop.
    Rectangle {
        color: Theme.hairline
        width: root.vertical ? 1 : root.width
        height: root.vertical ? root.height : 1
        /* Plain coordinates. Four anchors that switch on the edge is the
           pattern that made the bar itself cover the screen when it moved;
           the same pattern here would have painted a hairline the size of
           the desktop across everything. */
        x: root.edge === "left" ? root.width - 1 : 0
        y: root.edge === "top" ? root.height - 1 : 0
    }

    // ── zone one: the mark, then what is pinned ────────────────
    Item {
        id: leadZone
        // Always the near corner, so this needs no anchors at all.
        x: 0
        y: 0
        width: root.vertical ? root.thickness : lead.width + 22
        height: root.vertical ? lead.height + 20 : root.thickness

        Grid {
            id: lead
            /* On a vertical bar the icons centre in the band, not in the whole
               width — the rest of the width is the column their names are
               written in, and centring across both put every icon halfway into
               its own label. */
            anchors.verticalCenter: parent.verticalCenter
            /* Centred with a coordinate rather than a switching anchor: on a
               vertical bar within the icon band, on a horizontal one within
               the zone. The old form also read `x: ... : x`, a binding on
               itself, which QML resolves by leaving x wherever it happened to
               be — so after a move the zone's contents kept the offset from
               the layout they had just left. */
            x: root.vertical ? Math.round((root.band - width) / 2)
                             : Math.round((parent.width - width) / 2)
            /* Grid rather than a Row and a Column with the same children
               written out twice.

               Only `columns` is ever set, and it is never zero.
               Setting rows and columns together looked tidy and was a trap:
               the two bindings do not update in the same instant, so moving
               the bar between a horizontal edge and a vertical one passed
               through a moment where both read 1. A Grid told it has one row
               and one column drops everything past the first item — the bar
               kept its shape and its background and simply came back empty.
               One column stacks; a column count past the item count is a row. */
            columns: root.vertical ? 1 : 99
            flow: Grid.LeftToRight
            spacing: 4

            // The launcher mark.
            Item {
                width: root.cell
                height: root.cell

                HoverHandler { id: menuHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.menuToggled() }

                /* No frame. The mark is a shape with its own silhouette, and
                   boxing it made the corner look like a button with a sticker
                   on it. The hover state is the mark itself brightening and
                   growing slightly, which is what a physical thing does when
                   you reach for it.

                   Everything else in the interface stays drawn in line art;
                   this is the one bitmap, because it is the product's own
                   object and not an idea to redraw. */
                Image {
                    anchors.centerIn: parent
                    width: Math.round(root.cell * 0.65)
                    height: width
                    source: "qrc:/assets/symbiote-128.png"
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    sourceSize.width: 128
                    sourceSize.height: 128
                    opacity: (menuHover.hovered || root.launcherOpen) ? 1.0 : 0.78
                    scale: (menuHover.hovered || root.launcherOpen) ? 1.12 : 1.0
                    Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
                    Behavior on scale { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                                          easing.type: Theme.easeOut } }
                }
            }

            // A rule between the mark and what is pinned.
            Item {
                width: root.vertical ? root.cell : 9
                height: root.vertical ? 9 : root.cell
                Rectangle {
                    anchors.centerIn: parent
                    width: root.vertical ? root.cell * 0.55 : 1
                    height: root.vertical ? 1 : root.cell * 0.5
                    color: Theme.line
                }
            }

            Repeater {
                model: {
                    var out = []
                    for (var i = 0; i < Prefs.taskbarIds.length; i++) {
                        var a = Prefs.appById(Prefs.taskbarIds[i])
                        if (a) out.push(a)
                    }
                    return out
                }

                delegate: Item {
                    id: pin
                    required property var modelData
                    width: root.cell
                    height: root.cell

                    readonly property bool isOpen: root.openIds.indexOf(pin.modelData.id) !== -1
                    readonly property bool isStarting: root.startingIds.indexOf(pin.modelData.id) !== -1
                    readonly property bool lit: pinHover.hovered || isOpen || isStarting

                    HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.launched(pin.modelData.id) }
                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: root.newWindowRequested(pin.modelData.id)
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: function (point) {
                            var g = pin.mapToItem(null, point.position.x, point.position.y)
                            root.contextRequested(pin.modelData.id, g.x, g.y)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: pinHover.hovered ? Theme.tint(0.08) : "transparent"
                        border.width: 1
                        border.color: pinHover.hovered ? Theme.tint(0.10) : "transparent"
                        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    }

                    // Drawn glyphs, not the app's initial letter — a row of
                    // bare capitals told you nothing about what each does.
                    AppIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        width: root.iconSize; height: root.iconSize
                        glyph: pin.modelData.glyph
                        source: Prefs.iconPaths[pin.modelData.id] || ""
                        lit: pin.lit
                        stroke: pin.lit ? Theme.accent : Theme.textMuted
                    }

                    // Open indicator: a bar, wide when running.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                        width: (pin.isOpen || pin.isStarting) ? 14 : 4
                        height: 2
                        color: (pin.isOpen || pin.isStarting) ? Theme.accent : Theme.line
                        Behavior on width { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
                        SequentialAnimation on opacity {
                            running: pin.isStarting && Prefs.motionOn
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 520 }
                            NumberAnimation { to: 1.0;  duration: 520 }
                        }
                    }

                    // The name, once there is somewhere to put it.
                    Text {
                        visible: root.vertical && Prefs.taskbarLabels
                        anchors { left: parent.right; leftMargin: 8
                                  verticalCenter: parent.verticalCenter }
                        width: root.thickness - root.band - 12
                        text: pin.modelData.short || pin.modelData.title
                        color: pin.lit ? Theme.accent : Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                        font.letterSpacing: Theme.trackWide
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ── zone three: the tray ───────────────────────────────────
    Item {
        id: trayZone
        // Always the far corner. Same reasoning as leadZone.
        width: root.vertical ? root.thickness : tray.width + 30
        height: root.vertical ? tray.height + 22 : root.thickness
        x: root.width - width
        y: root.height - height

        Grid {
            id: tray
            anchors.verticalCenter: parent.verticalCenter
            /* Centred with a coordinate rather than a switching anchor: on a
               vertical bar within the icon band, on a horizontal one within
               the zone. The old form also read `x: ... : x`, a binding on
               itself, which QML resolves by leaving x wherever it happened to
               be — so after a move the zone's contents kept the offset from
               the layout they had just left. */
            x: root.vertical ? Math.round((root.band - width) / 2)
                             : Math.round((parent.width - width) / 2)
            /* Grid rather than a Row and a Column with the same children
               written out twice.

               Only `columns` is ever set, and it is never zero.
               Setting rows and columns together looked tidy and was a trap:
               the two bindings do not update in the same instant, so moving
               the bar between a horizontal edge and a vertical one passed
               through a moment where both read 1. A Grid told it has one row
               and one column drops everything past the first item — the bar
               kept its shape and its background and simply came back empty.
               One column stacks; a column count past the item count is a row. */
            columns: root.vertical ? 1 : 99
            flow: Grid.LeftToRight
            spacing: root.vertical ? 8 : 13
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            TrayBadge {
                label: "VPN"
                on: root.vpnUp
            }

            /* Wi-Fi. The tray used to print the interface name and nothing
               else — no way in, and "wlp3s0" tells an operator nothing about
               whether they are online. */
            TrayButton {
                id: wifiButton
                active: root.wifiOpen
                glyph: "wifi"
                lit: root.wifiConnected
                text: root.vertical ? "" : (root.wifiConnected ? root.wifiSsid
                                          : root.wifiAvailable ? "not connected" : "no adapter")
                onClicked: root.wifiRequested()
            }

            /* Only shown when there is a radio. A machine without Bluetooth
               should say nothing about it rather than carry a dead badge. */
            TrayButton {
                visible: Bluetooth.present
                glyph: "bluetooth"
                lit: Bluetooth.powered || root.btOpen
                text: {
                    var n = 0
                    for (var i = 0; i < Bluetooth.devices.length; i++)
                        if (Bluetooth.devices[i].connected) n++
                    return n ? String(n) : ""
                }
                onClicked: root.bluetoothRequested()
            }

            // Labelled. An unlabelled percentage next to the battery's
            // percentage told you nothing about which was which.
            Text {
                visible: !root.vertical
                text: "CPU " + root.cpu + "%"
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
            }
            BatteryGauge {
                visible: root.batteryPresent
                percent: root.battery
                charging: root.batteryCharging
                present: root.batteryPresent
            }

            /* Volume and brightness. Neither existed anywhere in the
               interface before, and the icon is now the mute state as well:
               colour alone is not a state anyone can read reliably. */
            TrayButton {
                visible: Media.audioAvailable || Media.backlightAvailable
                active: root.mediaOpen
                glyph: Media.muted ? "mute" : "volume"
                lit: !Media.muted
                danger: Media.muted
                onClicked: root.mediaRequested()
                /* Right-click mutes without opening anything. The taskbar is
                   where people reach when a video starts playing loudly. */
                onSecondaryClicked: Media.setMuted(!Media.muted)
            }

            /* The way out. There was none: on a live image the only exit was
               the power button on the case, which is how you corrupt a USB
               stick. */
            TrayButton {
                active: root.powerOpen
                glyph: "power"
                danger: true
                onClicked: root.powerRequested()
            }

            /* Date over time.
               Horizontal: "SUN 09 AUG" above the clock, right-aligned in the
               corner. Vertical: that date is wider than a 52px dock, so it is
               broken into its three words stacked, each small and centred, over
               the time — the only way the clock fits the strip without being
               unreadably small or running off the edge. */
            Column {
                spacing: root.vertical ? 0 : 1

                // The wide, one-line date, for the horizontal bar only.
                Text {
                    visible: !root.vertical
                    anchors.right: parent.right
                    text: root.date
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    font.letterSpacing: Theme.trackWide
                }

                // The same date, stacked, for the dock.
                Repeater {
                    model: root.vertical ? root.date.split(" ") : []
                    Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: 7
                        font.letterSpacing: 0.5
                    }
                }

                Item { visible: root.vertical; width: 1; height: 3 }

                Text {
                    // Centred on a vertical bar, right-aligned on a horizontal
                    // one — as a coordinate, for the reason above.
                    x: root.vertical ? Math.round((parent.width - width) / 2)
                                     : parent.width - width
                    text: root.clock
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: root.vertical ? Theme.sizeXs : Theme.sizeMd
                    font.letterSpacing: root.vertical ? 0.5 : Theme.trackWide
                }
            }
        }
    }

    /* ── zone two: what is open ─────────────────────────────────
       Bounded by the other two zones and nothing else, so it cannot be
       covered by them however much is pinned. It scrolls when it runs out of
       room, which is the honest failure: too many windows for the bar, rather
       than windows that quietly vanish. */
    Item {
        id: windowZone
        anchors {
            left: root.vertical ? parent.left : leadZone.right
            right: root.vertical ? parent.right : trayZone.left
            top: root.vertical ? leadZone.bottom : parent.top
            bottom: root.vertical ? trayZone.top : parent.bottom
            leftMargin: root.vertical ? 8 : 10
            rightMargin: root.vertical ? 8 : 10
            topMargin: root.vertical ? 6 : 0
            bottomMargin: root.vertical ? 6 : 0
        }
        clip: true
        visible: Windows.available && Windows.windows.length > 0

        ListView {
            id: winList
            anchors.centerIn: parent
            width: root.vertical ? parent.width : Math.min(parent.width, contentWidth)
            height: root.vertical ? Math.min(parent.height, contentHeight) : 32
            orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
            model: Windows.windows
            spacing: 4
            clip: true
            interactive: root.vertical ? contentHeight > height : contentWidth > width
            boundsBehavior: Flickable.StopAtBounds

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: Prefs.dur(Theme.durFast)
                                  easing.type: Theme.easeOut }
            }
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1
                                  duration: Prefs.dur(Theme.durFast) }
            }

            delegate: Item {
                id: winButton
                required property var modelData

                /* Elastic, within limits. One window gets a readable name;
                   nine get abbreviations rather than nine windows of which
                   four are off the end of the bar. */
                readonly property real ideal: winLabel.implicitWidth + 24
                width: root.vertical
                       ? winList.width
                       : Math.max(46, Math.min(168, Math.min(ideal,
                              (windowZone.width - (Windows.windows.length - 1) * 4)
                              / Math.max(1, Windows.windows.length))))
                height: root.vertical ? 28 : 32

                HoverHandler { id: winHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    // Clicking the focused window puts it away, as everywhere else.
                    onTapped: winButton.modelData.activated
                              ? Windows.minimize(winButton.modelData.key)
                              : Windows.activate(winButton.modelData.key)
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: Windows.closeWindow(winButton.modelData.key)
                }

                Rectangle {
                    anchors.fill: parent
                    color: winButton.modelData.activated ? Theme.tint(0.14)
                         : winHover.hovered ? Theme.tint(0.07) : "transparent"
                    border.width: 1
                    border.color: winButton.modelData.activated ? Theme.accent : Theme.line
                    Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                }

                // Focused, minimised or merely open — stated by a mark, not
                // only by a shade of the accent.
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 2
                    color: winButton.modelData.activated ? Theme.accent
                         : winButton.modelData.minimized ? Theme.line : Theme.tint(0.35)
                }

                Text {
                    id: winLabel
                    anchors { left: parent.left; leftMargin: 9
                              right: parent.right; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    text: winButton.modelData.title
                    color: winButton.modelData.minimized ? Theme.textMuted
                         : winButton.modelData.activated ? Theme.accent : Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    elide: Text.ElideRight
                    // Minimised is stated by the label going quiet, not by an
                    // extra badge competing with the open-app dots.
                    opacity: winButton.modelData.minimized ? 0.55 : 1
                }
            }
        }

        // More windows than fit. Better than silently dropping them.
        Text {
            visible: winList.interactive
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "›"
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.sizeMd
        }
    }

    /* Opening Settings on the Bluetooth section. The tray badge used to be a
       label with nothing behind it: the radio's state was visible and
       unreachable. */
    /* The badge opened Settings on its section. That works, but it is the whole
       window for what is usually one action — turn the radio on, pick a device.
       Wi-Fi, sound and power all answer from the tray; this now does too. */
    signal bluetoothRequested()

    property bool btOpen: false

    // ── tray furniture ─────────────────────────────────────────
    component TrayButton: Item {
        id: tb
        property string glyph: ""
        property string text: ""
        property bool lit: false
        property bool active: false
        property bool danger: false
        signal clicked()
        signal secondaryClicked()

        readonly property color hue: tb.danger ? Theme.alert : Theme.accent

        width: root.vertical ? Math.max(30, root.cell * 0.62)
                             : (tbRow.implicitWidth + 14)
        height: root.vertical ? Math.max(30, root.cell * 0.62) : 27

        HoverHandler { id: tbHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tb.clicked() }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: tb.secondaryClicked() }

        Rectangle {
            anchors.fill: parent
            color: (tbHover.hovered || tb.active) ? Theme.tint(0.10) : "transparent"
            border.width: 1
            border.color: (tbHover.hovered || tb.active) ? tb.hue : "transparent"
            Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
            Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
        }

        Row {
            id: tbRow
            anchors.centerIn: parent
            spacing: 6
            GlyphIcon {
                width: 16; height: 16
                anchors.verticalCenter: parent.verticalCenter
                glyph: tb.glyph
                stroke: tb.danger && (tbHover.hovered || tb.active) ? Theme.alert
                      : tb.danger && tb.lit ? Theme.textMuted
                      : tb.lit ? Theme.accent
                      : (tbHover.hovered || tb.active) ? Theme.accent
                      : Theme.textMuted
            }
            Text {
                visible: tb.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: tb.text
                color: tb.lit ? Theme.accent : Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                elide: Text.ElideRight
                // Long SSIDs must not push the clock off the bar.
                width: Math.min(implicitWidth, 110)
            }
        }
    }

    component TrayBadge: Rectangle {
        id: badge
        property string label: ""
        property bool on: false

        width: badgeText.implicitWidth + 16
        height: 20
        color: "transparent"
        border.width: 1
        border.color: badge.on ? Theme.accent : Theme.line

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: badge.label
            color: badge.on ? Theme.accent : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            font.letterSpacing: Theme.trackWide
        }
    }
}
