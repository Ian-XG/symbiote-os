import QtQuick
import Symbiote

/* Settings. Every control acts on something real: the ones that only changed a
   label — a "Firewall" switch that never touched the firewall — are gone, and
   what replaced them reports the system's actual state. */
Item {
    id: root
    signal closed()

    property string section: "APPEARANCE"
    readonly property var sections: ["APPEARANCE", "SOUND & DISPLAY", "NETWORK",
                                     "BLUETOOTH", "KEYBOARD", "SHORTCUTS",
                                     "SYSTEM", "SECURITY", "ABOUT"]

    /* Two layers. The panel tint alone is 58% alpha, which is right for a HUD
       card sitting on the desktop but not for a window you have to read: the
       hologram showed straight through the labels. An opaque base goes under
       it, so the glassmorphism stays without costing legibility. */
    Rectangle {
        anchors.fill: parent
        color: Theme.bgVoid
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.panelStrong
        border.width: 1
        border.color: Theme.hairline
    }
    Brackets { color: Theme.accent }

    // ── title bar ──────────────────────────────────────────────
    Item {
        id: titleBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 44

        Text {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            text: "SETTINGS"
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
            font.letterSpacing: Theme.trackWider
        }

        Item {
            width: 28; height: 28
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            HoverHandler { id: closeHover }
            TapHandler { onTapped: root.closed() }
            Rectangle {
                anchors.fill: parent
                color: closeHover.hovered ? Qt.rgba(1, 0.09, 0.27, 0.15) : "transparent"
                border.width: 1
                border.color: closeHover.hovered ? Theme.alert : Theme.line
            }
            Text {
                anchors.centerIn: parent
                text: "×"
                color: closeHover.hovered ? Theme.alert : Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.sizeMd
            }
        }
    }

    /* ── tabs ───────────────────────────────────────────────────
       Scrollable. A plain Row simply ran past the window edge, and the last
       two sections could not be reached at all. */
    Flickable {
        id: tabs
        anchors { left: parent.left; leftMargin: 18; right: parent.right
                  rightMargin: 18; top: titleBar.bottom }
        height: 38
        contentWidth: tabRow.width
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

    Row {
        id: tabRow
        spacing: 2

        Repeater {
            model: root.sections
            Item {
                required property string modelData
                /* Padded. The clickable area used to be the text glyphs
                   exactly, with dead gaps between labels, so changing tab was
                   a game of hitting letters. */
                width: tabLabel.width + 22
                height: 38
                HoverHandler { id: tabHover }
                TapHandler { onTapped: root.section = parent.modelData }

                Rectangle {
                    anchors.fill: parent
                    visible: tabHover.hovered && root.section !== parent.modelData
                    color: Theme.tint(0.07)
                }

                Text {
                    id: tabLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData
                    color: root.section === parent.modelData ? Theme.accent
                         : tabHover.hovered ? Theme.textBody : Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeSm
                    font.letterSpacing: Theme.trackWider
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    visible: root.section === parent.modelData
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: Theme.accent
                }
            }
        }
    }

    }

    Rectangle {
        id: tabRule
        anchors { left: parent.left; right: parent.right; top: tabs.bottom }
        height: 1
        color: Theme.line
    }

    // ── body ───────────────────────────────────────────────────
    Item {
        id: body
        anchors {
            top: tabRule.bottom; topMargin: 8
            left: parent.left; leftMargin: 18
            right: parent.right; rightMargin: 18
            bottom: parent.bottom; bottomMargin: 18
        }
        clip: true

        // APPEARANCE — every control here changes something visible
        Section {
            shown: root.section === "APPEARANCE"
            Column {
            width: parent.width

            SettingRow {
                label: "Accent colour"
                hint: "Recolours the whole shell. Red stays reserved for critical states."
                Segmented {
                    options: [{ v: "toxin", t: "TOXIN GREEN" }, { v: "signal", t: "SIGNAL BLUE" }]
                    current: Theme.accentMode
                    onPicked: function (v) { Theme.accentMode = v }
                }
            }
            SettingRow {
                label: "Interface scale"
                hint: "Doubled automatically on high-density panels. Change it if the text is the wrong size."
                Segmented {
                    options: [{ v: "auto", t: "AUTO" }, { v: "1", t: "1×" },
                              { v: "1.5", t: "1.5×" }, { v: "2", t: "2×" }]
                    current: Prefs.scaleMode
                    onPicked: function (v) { Prefs.scaleMode = v }
                }
            }
            SettingRow {
                label: "Scan line"
                hint: "Sweeping highlight across the screen"
                Toggle { on: Prefs.scanline; onToggled: Prefs.scanline = !Prefs.scanline }
            }
            SettingRow {
                label: "Background grid"
                hint: "Technical grid behind the desktop"
                Toggle { on: Prefs.grid; onToggled: Prefs.grid = !Prefs.grid }
            }
            SettingRow {
                label: "Screen vignette"
                hint: "Darkens the edges of the display"
                Toggle { on: Prefs.vignette; onToggled: Prefs.vignette = !Prefs.vignette }
            }
            SettingRow {
                label: "Hologram detail"
                hint: "Two thirds of the shell's CPU when there is no GPU to draw it. "
                    + "Auto reduces it on machines without one."
                Segmented {
                    options: [{ v: "auto", t: "AUTO" }, { v: "full", t: "FULL" },
                              { v: "reduced", t: "REDUCED" }, { v: "off", t: "OFF" }]
                    current: Prefs.holoDetail
                    onPicked: function (v) { Prefs.holoDetail = v }
                }
            }
            SettingRow {
                label: "Hologram rotation"
                hint: "Stops only while a panel is covering it."
                Toggle { on: Prefs.spin; onToggled: Prefs.spin = !Prefs.spin }
            }
            }
        }

        // SOUND & DISPLAY
        Section {
            shown: root.section === "SOUND & DISPLAY"
            Column {
            width: parent.width

            SettingRow {
                label: "Volume"
                hint: Media.audioAvailable ? "Output level. The laptop's own volume keys change this too."
                                           : "No audio device found."
                Segmented {
                    options: [{ v: "0", t: "MUTE" }, { v: "25", t: "25" },
                              { v: "50", t: "50" }, { v: "75", t: "75" },
                              { v: "100", t: "100" }]
                    // The nearest preset, so the row shows where you actually are.
                    current: !Media.audioAvailable ? ""
                           : Media.muted ? "0"
                           : String(Math.round(Media.volume / 25) * 25)
                    onPicked: function (v) {
                        if (v === "0") { if (!Media.muted) Media.toggleMute() }
                        else { if (Media.muted) Media.toggleMute(); Media.setVolume(Number(v)) }
                    }
                }
            }

            SettingRow {
                label: "Screen brightness"
                hint: Media.backlightAvailable
                      ? "Never goes fully dark — an unlit panel hides the control that undoes it."
                      : "No backlight on this machine, or an external display."
                Segmented {
                    options: [{ v: "20", t: "20" }, { v: "40", t: "40" },
                              { v: "60", t: "60" }, { v: "80", t: "80" },
                              { v: "100", t: "100" }]
                    current: !Media.backlightAvailable ? ""
                           : String(Math.max(20, Math.round(Media.brightness / 20) * 20))
                    onPicked: function (v) { Media.setBrightness(Number(v)) }
                }
            }
            }
        }

        // KEYBOARD
        Section {
            shown: root.section === "KEYBOARD"
            Column {
            width: parent.width
            spacing: 0

            SettingRow {
                label: "Layout"
                hint: "Where the symbols are. On the wrong layout a Wi-Fi password fails "
                    + "as though it were wrong, because the characters are masked."
                Segmented {
                    options: {
                        var out = []
                        for (var i = 0; i < Keyboard.layouts.length; i++)
                            out.push({ v: Keyboard.layouts[i].code,
                                       t: Keyboard.layouts[i].code.toUpperCase() })
                        return out
                    }
                    current: Keyboard.pendingLayout
                    onPicked: function (v) { Keyboard.setLayout(v) }
                }
            }

            Text {
                width: parent.width
                topPadding: 10
                text: {
                    var name = ""
                    for (var i = 0; i < Keyboard.layouts.length; i++)
                        if (Keyboard.layouts[i].code === Keyboard.pendingLayout)
                            name = Keyboard.layouts[i].name
                    return "Selected: " + (name || Keyboard.pendingLayout)
                }
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
            }

            /* Stated rather than hidden. A wlroots compositor cannot change
               its keymap while running, and a control that silently does
               nothing until some later reboot is worse than one that says so. */
            Rectangle {
                width: parent.width
                height: restartText.implicitHeight + 20
                visible: Keyboard.restartNeeded
                color: Theme.tint(0.06)
                border.width: 1
                border.color: Theme.accent
                Text {
                    id: restartText
                    anchors { fill: parent; margins: 10 }
                    text: "Saved, but not yet in effect. The compositor reads the layout once, "
                        + "at start. Sign out and back in (Super+L → LOG OUT) to apply it."
                    color: Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                }
            }
            }
        }

        // SHORTCUTS
        Section {
            shown: root.section === "SHORTCUTS"
            Column {
            width: parent.width

            Text {
                width: parent.width
                topPadding: 6
                bottomPadding: 10
                text: "Nothing in the interface announced these, so until now they only "
                    + "existed if somebody told you."
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                wrapMode: Text.WordWrap
            }

            Repeater {
                /* Written out by hand, and it has to match Main.qml's Shortcut
                   declarations — a reference that drifts from the bindings is
                   worse than none. */
                model: [
                    { k: "Super",        v: "Applications" },
                    { k: "Ctrl+Alt+T",   v: "Terminal" },
                    { k: "Super+E",      v: "File manager" },
                    { k: "Super+W",      v: "Wireless" },
                    { k: "Super+I",      v: "Settings" },
                    { k: "Super+L",      v: "Session and power" },
                    { k: "Super+Escape", v: "Lock the screen" },
                    { k: "Print",        v: "Screenshot" },
                    { k: "Shift+Print",  v: "Screenshot of a region" },
                    { k: "Escape",       v: "Close the top panel" },
                    { k: "Super+Return", v: "Terminal (compositor)" },
                    { k: "Alt+Tab",      v: "Switch window (compositor)" },
                    { k: "Ctrl+Alt+F2",  v: "Text console, if the desktop will not start" }
                ]

                Item {
                    required property var modelData
                    width: parent.width
                    height: 28

                    Rectangle {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: keyLabel.width + 16
                        height: 20
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.line
                        Text {
                            id: keyLabel
                            anchors.centerIn: parent
                            text: parent.parent.modelData.k
                            color: Theme.accent
                            font.family: Theme.mono
                            font.pixelSize: Theme.size2xs
                        }
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 150
                                  verticalCenter: parent.verticalCenter }
                        text: parent.modelData.v
                        color: Theme.textBody
                        font.family: Theme.mono
                        font.pixelSize: Theme.sizeXs
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(1, 1, 1, 0.04)
                    }
                }
            }
            }
        }

        // NETWORK
        NetworkPanel {
            visible: root.section === "NETWORK"
            anchors.fill: parent
        }

        // BLUETOOTH
        BluetoothPanel {
            visible: root.section === "BLUETOOTH"
            anchors.fill: parent
        }

        // SYSTEM
        Column {
            visible: root.section === "SYSTEM"
            width: parent.width
            SettingRow {
                label: "Device name"
                hint: "Read from the running system"
                Text {
                    text: System.hostname
                    color: Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                }
            }
            SettingRow {
                label: "Edition"
                hint: "From /etc/os-release"
                Text {
                    text: System.edition
                    color: Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                }
            }
            SettingRow {
                label: "24-hour clock"
                hint: "Affects the taskbar clock"
                Toggle { on: Prefs.clock24; onToggled: Prefs.clock24 = !Prefs.clock24 }
            }
            SettingRow {
                label: "Show seconds"
                hint: "Taskbar clock precision"
                Toggle { on: Prefs.seconds; onToggled: Prefs.seconds = !Prefs.seconds }
            }
        }

        // SECURITY — reports, does not pretend to control
        Column {
            visible: root.section === "SECURITY"
            width: parent.width
            spacing: 12

            Text {
                width: parent.width
                topPadding: 10
                text: "Read from the running system."
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                wrapMode: Text.WordWrap
                lineHeight: 1.5
            }

            /* States what is actually true of this boot rather than assuming.
               Settings that quietly evaporate on reboot are worse than
               settings that tell you they will. */
            Rectangle {
                width: parent.width
                height: persistText.implicitHeight + 20
                color: Store.persistent() ? Theme.tint(0.06)
                                          : Qt.rgba(1, 0.09, 0.27, 0.06)
                border.width: 1
                border.color: Store.persistent() ? Theme.hairline : Theme.alert

                Text {
                    id: persistText
                    anchors { fill: parent; margins: 10 }
                    text: Store.persistent()
                        ? "Persistent storage is active. Settings, pinned icons and files "
                          + "written to your home directory survive a reboot."
                        : "No persistent storage. Everything changed this session — settings, "
                          + "pinned icons, saved files — is lost on reboot. To fix that, open a "
                          + "terminal and run:  sudo symbiote-persist list"
                    color: Store.persistent() ? Theme.textMuted : Theme.alert
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                }
            }
            StatusList {
                width: parent.width
                rows: Security.rows
            }
        }

        // ABOUT — real hardware, not numbers typed into the source
        Column {
            visible: root.section === "ABOUT"
            width: parent.width

            Repeater {
                model: [
                    { k: "Device name", v: System.hostname },
                    { k: "Edition", v: System.edition },
                    { k: "Processor", v: System.cpu.cores + " cores"
                        + (System.cpu.ghz ? " · " + System.cpu.ghz + " GHz" : "") },
                    { k: "Memory", v: System.memory.totalGb + " GB" },
                    { k: "Storage", v: System.storage.totalGb + " GB" },
                    { k: "Uptime", v: Math.floor(System.uptime / 3600) + "h "
                        + Math.floor((System.uptime % 3600) / 60) + "m" },
                    { k: "Shell", v: "Symbiote Shell (Qt) 0.1" },
                    { k: "Licence", v: "MIT OR GPL-3.0-or-later" },
                    { k: "Settings file", v: Store.path() },
                    { k: "Persistence", v: Store.persistent() ? "active" : "none — changes are lost on reboot" }
                ]

                Item {
                    required property var modelData
                    width: parent.width
                    height: 30
                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: parent.modelData.k
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.sizeXs
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: parent.modelData.v
                        color: Theme.textBody
                        font.family: Theme.mono
                        font.pixelSize: Theme.sizeXs
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: 1
                        color: Qt.rgba(1, 1, 1, 0.05)
                    }
                }
            }
        }
    }

    /* Sections cross-fade and drift in rather than swapping instantly. The
       window had no transitions anywhere, which made every tab feel like a
       redraw instead of a move. */
    component Section: Item {
        property bool shown: false
        anchors.fill: parent
        visible: opacity > 0
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durMed
                                                easing.type: Easing.OutCubic } }
        transform: Translate {
            y: shownAnim
            Behavior on y { NumberAnimation { duration: Theme.durMed
                                              easing.type: Easing.OutCubic } }
        }
        property real shownAnim: shown ? 0 : 8
    }

    component Segmented: Row {
        id: seg
        property var options: []
        property string current: ""
        signal picked(string v)
        spacing: 6

        /* Addressed by id, not by walking `parent`. A Repeater reparents its
           delegates to the Row, so `parent.parent` landed on the row above and
           the comparison was against undefined — no segment ever showed as
           selected, including the accent the shell was actually using. */
        Repeater {
            model: seg.options
            Rectangle {
                required property var modelData
                readonly property bool on: modelData.v === seg.current
                width: segLabel.width + 20
                height: 26
                color: on ? Theme.tint(0.08) : "transparent"
                border.width: 1
                border.color: on ? Theme.accent : Theme.line
                TapHandler { onTapped: seg.picked(modelData.v) }
                Text {
                    id: segLabel
                    anchors.centerIn: parent
                    text: modelData.t
                    color: parent.on ? Theme.accent : Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.size2xs
                    font.letterSpacing: Theme.trackWide
                }
            }
        }
    }

    /* Ids, not `parent` walks. These two happened to be counted right, but the
       Segmented control above was off by one level and silently never marked
       anything as selected — the pattern is not worth keeping. */
    component Toggle: Item {
        id: tog
        property bool on: false
        signal toggled()
        width: 56; height: 20

        TapHandler { onTapped: tog.toggled() }

        Rectangle {
            width: 34; height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1
            border.color: tog.on ? Theme.accent : Theme.line
            Rectangle {
                width: 11; height: 11
                y: 2
                x: tog.on ? 19 : 2
                color: tog.on ? Theme.accent : Theme.textMuted
                Behavior on x { NumberAnimation { duration: Theme.durFast } }
            }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: tog.on ? "on" : "off"
            color: tog.on ? Theme.accent : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
        }
    }

    component SettingRow: Item {
        id: row
        property string label: ""
        property string hint: ""
        default property alias control: holder.data

        width: parent ? parent.width : 400
        height: 52

        Column {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: parent.width * 0.6
            spacing: 3
            Text {
                text: row.label
                color: Theme.textBody
                font.family: Theme.mono
                font.pixelSize: Theme.sizeSm
            }
            Text {
                text: row.hint
                visible: text !== ""
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                width: parent.width
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: holder
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: childrenRect.width
            height: childrenRect.height
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Qt.rgba(1, 1, 1, 0.05)
        }
    }
}
