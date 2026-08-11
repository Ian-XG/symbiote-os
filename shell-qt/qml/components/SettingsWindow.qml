import QtQuick
import Symbiote

/* Settings.
 *
 * Every control here acts on something real: the ones that only changed a
 * label — a "Firewall" switch that never touched the firewall — are gone.
 *
 * Three things were wrong with it as a window, independent of what it
 * contained:
 *
 *  - Nothing swallowed clicks. The window drew on top of the desktop but the
 *    desktop's marquee MouseArea was still underneath it, so pressing on any
 *    empty part of Settings started a rubber-band selection on the desktop and
 *    dragging inside the window selected desktop icons. That is most of what
 *    "Settings does not respond properly" was.
 *
 *  - Nothing scrolled. The body clipped, so any section taller than the window
 *    simply had its bottom rows amputated, with no indication they existed.
 *
 *  - The nine sections lived in a horizontally scrolling tab strip that had to
 *    be dragged sideways to reach the last two. A fixed list down the side has
 *    room for all of them and shows where you are.
 */
Item {
    id: root
    signal closed()

    property string section: "APPEARANCE"

    /* Order matters: what people change often at the top, what only reports
       at the bottom. `key` is what the capture harness and Main.qml address. */
    readonly property var sections: [
        { key: "APPEARANCE", label: "APPEARANCE", glyph: "settings" },
        { key: "TASKBAR",    label: "TASKBAR",    glyph: "app" },
        { key: "SOUND & DISPLAY", label: "SOUND & DISPLAY", glyph: "volume" },
        { key: "SCREENS",    label: "SCREENS",    glyph: "app" },
        { key: "NETWORK",    label: "NETWORK",    glyph: "wifi" },
        { key: "BLUETOOTH",  label: "BLUETOOTH",  glyph: "bluetooth" },
        { key: "KEYBOARD",   label: "KEYBOARD",   glyph: "terminal" },
        { key: "SHORTCUTS",  label: "SHORTCUTS",  glyph: "terminal" },
        { key: "SYSTEM",     label: "SYSTEM",     glyph: "pulse" },
        { key: "SECURITY",   label: "SECURITY",   glyph: "shield" },
        { key: "ABOUT",      label: "ABOUT",      glyph: "agent" }
    ]

    function indexOfSection(key) {
        for (var i = 0; i < sections.length; i++)
            if (sections[i].key === key) return i
        return 0
    }

    /* Which way the next section should come in from. A transition that always
       slides the same way tells you a change happened; one that follows the
       direction of travel tells you which way you moved through the list. */
    property int lastIndex: 0
    property int travel: 1
    onSectionChanged: {
        var i = indexOfSection(section)
        travel = i >= lastIndex ? 1 : -1
        lastIndex = i
        bodyScroll.contentY = 0
    }

    /* Draggable, and it has to be: the window is centred on the desktop and
       covers the hologram and half the status rail, with no way to see what a
       setting was doing to either. */
    property real dragX: 0
    property real dragY: 0
    transform: Translate { x: root.dragX; y: root.dragY }

    // ── the window itself ──────────────────────────────────────
    /* Swallows everything. Accepting both buttons matters: the desktop's own
       right-click menu was opening from under the Settings window. */
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onWheel: function (wheel) { wheel.accepted = true }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgVoid
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.width: 1
        border.color: Theme.hairline
    }
    Brackets { color: Theme.accent }

    // Arrives rather than appears.
    opacity: root.visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durMed) } }

    // ── title bar ──────────────────────────────────────────────
    Item {
        id: titleBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 46

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeAllCursor
            property real ox: 0
            property real oy: 0
            onPressed: function (mouse) { ox = mouse.x; oy = mouse.y }
            onPositionChanged: function (mouse) {
                if (!pressed) return
                root.dragX += mouse.x - ox
                root.dragY += mouse.y - oy
            }
            // Double-click puts it back in the middle, which is the only way
            // out of having dragged it somewhere unhelpful.
            onDoubleClicked: { root.dragX = 0; root.dragY = 0 }
        }

        Row {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            spacing: Theme.space4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "SETTINGS"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: Theme.sizeXs
                font.letterSpacing: Theme.trackWider
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 12
                color: Theme.line
            }
            // Says where you are without making you find the highlighted row.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.section
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
            }
        }

        Item {
            width: 28; height: 28
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.closed() }
            Rectangle {
                anchors.fill: parent
                color: closeHover.hovered ? Qt.rgba(1, 0.09, 0.27, 0.15) : "transparent"
                border.width: 1
                border.color: closeHover.hovered ? Theme.alert : Theme.line
                Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
            }
            Text {
                anchors.centerIn: parent
                text: "×"
                color: closeHover.hovered ? Theme.alert : Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.sizeMd
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 1
            color: Theme.line
        }
    }

    // ── section list ───────────────────────────────────────────
    Item {
        id: nav
        anchors { left: parent.left; top: titleBar.bottom; bottom: parent.bottom }
        width: 176

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.28)
        }
        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1
            color: Theme.line
        }

        /* The marker travels between rows rather than being redrawn on each
           one. It is the same object moving, which is what makes the list feel
           like a place you are in rather than ten states it can be in. */
        Rectangle {
            id: marker
            width: 2
            height: 34
            x: 0
            y: 10 + root.indexOfSection(root.section) * 34
            color: Theme.accent
            Behavior on y { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                              easing.type: Theme.easeOut } }
        }

        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 10 }

            Repeater {
                model: root.sections

                delegate: Item {
                    id: navRow
                    required property var modelData
                    width: nav.width
                    height: 34

                    readonly property bool on: navRow.modelData.key === root.section

                    HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.section = navRow.modelData.key }

                    Rectangle {
                        anchors.fill: parent
                        color: navRow.on ? Theme.tint(0.09)
                             : navHover.hovered ? Theme.tint(0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    }

                    GlyphIcon {
                        anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                        width: 14; height: 14
                        glyph: navRow.modelData.glyph
                        stroke: navRow.on ? Theme.accent
                              : navHover.hovered ? Theme.textBody : Theme.textMuted
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 40; right: parent.right
                                  rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: navRow.modelData.label
                        color: navRow.on ? Theme.accent
                             : navHover.hovered ? Theme.textBody : Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                        font.letterSpacing: Theme.trackWide
                        elide: Text.ElideRight
                        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    }
                }
            }
        }

        // What this boot actually is, at the foot of the list.
        Column {
            anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 12
                      bottom: parent.bottom; bottomMargin: 14 }
            spacing: 3
            Text {
                text: "SYMBIOTE OS"
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
            }
            Text {
                text: Store.persistent() ? "persistent" : "live · not persistent"
                color: Store.persistent() ? Theme.textMuted : Theme.alert
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
            }
        }
    }

    // ── body ───────────────────────────────────────────────────
    Flickable {
        id: bodyScroll
        anchors {
            left: nav.right; leftMargin: 22
            right: parent.right; rightMargin: 22
            top: titleBar.bottom; topMargin: 6
            bottom: parent.bottom; bottomMargin: 18
        }
        clip: true
        contentHeight: pages.height
        boundsBehavior: Flickable.StopAtBounds
        // Only scrolls when there is something to scroll to.
        interactive: contentHeight > height

        Item {
            id: pages
            width: bodyScroll.width
            /* As tall as whatever is on screen. Sections are stacked at the
               same position and only one is shown, so the height follows the
               visible one rather than the tallest. */
            height: {
                for (var i = 0; i < children.length; i++)
                    if (children[i].shown) return children[i].implicitHeight + 24
                return bodyScroll.height
            }

            // APPEARANCE ───────────────────────────────────────
            Section {
                shown: root.section === "APPEARANCE"

                SettingGroup {
                    title: "PALETTE"
                    SettingRow {
                        label: "Accent colour"
                        hint: "Recolours the whole shell. Red stays reserved for critical states."
                        HudSegmented {
                            options: [{ v: "toxin", t: "TOXIN GREEN" }, { v: "signal", t: "SIGNAL BLUE" }]
                            current: Theme.accentMode
                            onPicked: function (v) { Theme.accentMode = v }
                        }
                    }
                    SettingRow {
                        label: "Interface scale"
                        hint: "Doubled automatically on high-density panels. Change it if the text is the wrong size."
                        HudDropdown {
                            options: [{ v: "auto", t: "AUTOMATIC" }, { v: "1", t: "1×" },
                                      { v: "1.25", t: "1.25×" }, { v: "1.5", t: "1.5×" },
                                      { v: "2", t: "2×" }]
                            current: Prefs.scaleMode
                            onPicked: function (v) { Prefs.scaleMode = v }
                        }
                    }
                }

                SettingGroup {
                    title: "DESKTOP"
                    SettingRow {
                        label: "Scan line"
                        hint: "Sweeping highlight across the screen"
                        HudToggle { on: Prefs.scanline; onToggled: Prefs.scanline = !Prefs.scanline }
                    }
                    SettingRow {
                        label: "Background grid"
                        hint: "Technical grid behind the desktop"
                        HudToggle { on: Prefs.grid; onToggled: Prefs.grid = !Prefs.grid }
                    }
                    SettingRow {
                        label: "Screen vignette"
                        hint: "Darkens the edges of the display"
                        HudToggle { on: Prefs.vignette; onToggled: Prefs.vignette = !Prefs.vignette }
                    }
                }

                SettingGroup {
                    title: "MOTION"
                    SettingRow {
                        label: "Interface animation"
                        hint: "Reduced keeps the fades and drops the movement. Off is instant — "
                            + "worth it on a machine with no GPU, where every transition is "
                            + "rasterised by the processor."
                        HudDropdown {
                            options: [{ v: "full", t: "FULL" }, { v: "reduced", t: "REDUCED" },
                                      { v: "off", t: "OFF" }]
                            current: Prefs.motion
                            onPicked: function (v) { Prefs.motion = v }
                        }
                    }
                    SettingRow {
                        label: "Hologram detail"
                        hint: "Two thirds of the shell's CPU when there is no GPU to draw it. "
                            + "Auto reduces it on machines without one."
                        HudDropdown {
                            options: [{ v: "auto", t: "AUTOMATIC" }, { v: "full", t: "FULL" },
                                      { v: "reduced", t: "REDUCED" }, { v: "off", t: "OFF" }]
                            current: Prefs.holoDetail
                            onPicked: function (v) { Prefs.holoDetail = v }
                        }
                    }
                    SettingRow {
                        label: "Hologram rotation"
                        hint: "Stops only while a panel is covering it."
                        separator: false
                        HudToggle { on: Prefs.spin; onToggled: Prefs.spin = !Prefs.spin }
                    }
                }
            }

            // TASKBAR ──────────────────────────────────────────
            Section {
                shown: root.section === "TASKBAR"

                SettingGroup {
                    title: "POSITION"
                    note: "default: bottom"

                    SettingRow {
                        label: "Edge"
                        hint: "Where the bar lives. On a 16:9 laptop panel vertical pixels are "
                            + "the scarce ones, and a bar down the side gives back seventy of them."
                        stacked: true
                        EdgePicker {
                            current: Prefs.taskbarEdge
                            onPicked: function (v) { Prefs.taskbarEdge = v }
                        }
                    }
                    SettingRow {
                        label: "Thickness"
                        hint: "How much room the bar takes from the desktop"
                        HudSegmented {
                            options: [{ v: "compact", t: "COMPACT" }, { v: "normal", t: "NORMAL" },
                                      { v: "large", t: "LARGE" }]
                            current: Prefs.taskbarSize
                            onPicked: function (v) { Prefs.taskbarSize = v }
                        }
                    }
                    SettingRow {
                        label: "Window titles"
                        hint: "Names beside the open windows rather than icons alone. "
                            + "On a vertical bar this is what the extra width is for."
                        separator: false
                        HudToggle { on: Prefs.taskbarLabels
                                    onToggled: Prefs.taskbarLabels = !Prefs.taskbarLabels }
                    }
                }

                SettingGroup {
                    title: "PINNED"
                    note: Prefs.taskbarIds.length + " on the bar"

                    Repeater {
                        model: Prefs.apps
                        delegate: Item {
                            id: pinRow
                            required property var modelData
                            width: parent.width
                            height: 34

                            readonly property bool pinned: Prefs.taskbarIds.indexOf(pinRow.modelData.id) !== -1

                            HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Prefs.toggleIn("taskbar", pinRow.modelData.id) }

                            Rectangle {
                                anchors.fill: parent
                                color: pinHover.hovered ? Theme.tint(0.05) : "transparent"
                            }
                            AppIcon {
                                anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                                width: 16; height: 16
                                glyph: pinRow.modelData.glyph
                                source: Prefs.iconPaths[pinRow.modelData.id] || ""
                                lit: pinRow.pinned
                                stroke: pinRow.pinned ? Theme.accent : Theme.textMuted
                            }
                            Text {
                                anchors { left: parent.left; leftMargin: 32; verticalCenter: parent.verticalCenter }
                                text: pinRow.modelData.title
                                color: pinRow.pinned ? Theme.textBody : Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.sizeXs
                            }
                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: pinRow.pinned ? "ON BAR" : "—"
                                color: pinRow.pinned ? Theme.accent : Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.size2xs
                                font.letterSpacing: Theme.trackWide
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

            // SOUND & DISPLAY ──────────────────────────────────
            Section {
                shown: root.section === "SOUND & DISPLAY"

                SettingGroup {
                    title: "OUTPUT"
                    SettingRow {
                        label: "Volume"
                        hint: Media.audioAvailable
                              ? "Output level. The laptop's own volume keys change this too."
                              : "No audio device found."
                        stacked: true
                        HudSlider {
                            width: parent ? parent.width : 300
                            label: "LEVEL"
                            value: Media.volume
                            muted: Media.muted
                            enabled: Media.audioAvailable
                            absent: !Media.audioAvailable
                            absentText: "no audio device"
                            onMoved: function (v) { Media.setVolume(v) }

                            HudButton {
                                text: Media.muted ? "UNMUTE" : "MUTE"
                                danger: Media.muted
                                enabled: Media.audioAvailable
                                onClicked: Media.setMuted(!Media.muted)
                            }
                        }
                    }
                }

                SettingGroup {
                    title: "DISPLAY"
                    SettingRow {
                        label: "Screen brightness"
                        hint: Media.backlightAvailable
                              ? "Never goes fully dark — an unlit panel hides the control that undoes it."
                              : "No backlight on this machine, or an external display."
                        stacked: true
                        separator: false
                        HudSlider {
                            width: parent ? parent.width : 300
                            label: "BACKLIGHT"
                            value: Media.brightness
                            minimum: 5
                            enabled: Media.backlightAvailable
                            absent: !Media.backlightAvailable
                            absentText: "no backlight — external display?"
                            onMoved: function (v) { Media.setBrightness(v) }
                        }
                    }
                }
            }

            // SCREENS ──────────────────────────────────────────
            /* Monitors, and where they sit relative to each other. There was
               nowhere in the shell to see a second display, let alone move it,
               so a laptop plugged into a monitor got whatever arrangement the
               compositor guessed at and no way to change it. */
            Section {
                shown: root.section === "SCREENS"

                SettingGroup {
                    title: "ATTACHED"

                    Repeater {
                        model: Displays.screens

                        delegate: Item {
                            id: scr
                            required property var modelData
                            width: parent ? parent.width : 300
                            height: 58

                            Text {
                                id: scrName
                                anchors { left: parent.left; top: parent.top; topMargin: 6 }
                                text: scr.modelData.name
                                      + (scr.modelData.primary ? "   ·   PRIMARY" : "")
                                color: scr.modelData.primary ? Theme.accent : Theme.text
                                font.family: Theme.mono
                                font.pixelSize: Theme.sizeXs
                                font.letterSpacing: Theme.trackWide
                            }

                            Text {
                                anchors { left: parent.left; top: scrName.bottom; topMargin: 4 }
                                text: {
                                    var m = scr.modelData
                                    var bits = [m.label + " at " + m.refresh + " Hz"]
                                    if (m.scale !== 1) bits.push("scale " + m.scale + "×")
                                    bits.push("at " + m.x + "," + m.y)
                                    if (m.model) bits.push(m.model)
                                    return bits.join("   ")
                                }
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.size2xs
                            }

                            HudButton {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: "TURN OFF"
                                danger: true
                                // The primary is never offered: switching off the
                                // screen holding the panel leaves nothing to undo it with.
                                visible: Displays.manageable && !scr.modelData.primary
                                onClicked: Displays.setEnabled(scr.modelData.name, false)
                            }

                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 1
                                color: Theme.hairline
                            }
                        }
                    }

                    SettingRow {
                        label: "Arrangement"
                        hint: Displays.manageable
                              ? "Side by side puts them in the order listed above, tops aligned."
                              : "wlr-randr is not installed, so the layout can only be read, not changed."
                        separator: false
                        enabled: Displays.manageable && Displays.count > 1

                        /* Wrapped in a Row on purpose: SettingRow places one
                           control against its right edge, so two of them land
                           on the same spot and print over each other. */
                        Row {
                            spacing: 8

                            HudButton {
                                text: "SIDE BY SIDE"
                                enabled: Displays.manageable && Displays.count > 1
                                onClicked: {
                                    var order = []
                                    for (var i = 0; i < Displays.screens.length; i++)
                                        order.push(Displays.screens[i].name)
                                    Displays.arrangeHorizontally(order)
                                }
                            }

                            HudButton {
                                text: "MIRROR"
                                enabled: Displays.manageable && Displays.count > 1
                                onClicked: Displays.mirrorAll()
                            }
                        }
                    }
                }

                SettingGroup {
                    title: "NOTES"
                    visible: Displays.count < 2 || Displays.lastError !== ""

                    SettingRow {
                        visible: Displays.count < 2
                        label: "One display"
                        hint: "Only one monitor is attached. Plug in another and it appears here, "
                              + "with its own wallpaper and taskbar, straight away — no restart."
                        separator: false
                        enabled: false
                    }

                    SettingRow {
                        visible: Displays.lastError !== ""
                        label: "Last error"
                        hint: Displays.lastError
                        separator: false
                        HudButton {
                            text: "DISMISS"
                            onClicked: Displays.clearError()
                        }
                    }
                }
            }

            // KEYBOARD ─────────────────────────────────────────
            Section {
                shown: root.section === "KEYBOARD"

                SettingGroup {
                    title: "LAYOUT"
                    SettingRow {
                        label: "Keyboard layout"
                        hint: "Where the symbols are. On the wrong layout a Wi-Fi password fails "
                            + "as though it were wrong, because the characters are masked."
                        HudDropdown {
                            options: {
                                var out = []
                                for (var i = 0; i < Keyboard.layouts.length; i++)
                                    out.push({ v: Keyboard.layouts[i].code,
                                               t: Keyboard.layouts[i].name })
                                return out
                            }
                            current: Keyboard.pendingLayout
                            onPicked: function (v) { Keyboard.setLayout(v) }
                        }
                    }

                    /* Stated rather than hidden. A wlroots compositor cannot
                       change its keymap while running, and a control that
                       silently does nothing until some later reboot is worse
                       than one that says so. */
                    Notice {
                        visible: Keyboard.restartNeeded
                        text: "Saved, but not yet in effect. The compositor reads the layout once, "
                            + "at start. Sign out and back in (Super+L → LOG OUT) to apply it."
                    }
                }
            }

            // SHORTCUTS ────────────────────────────────────────
            Section {
                shown: root.section === "SHORTCUTS"

                SettingGroup {
                    title: "KEYS"
                    note: "13 bindings"

                    Text {
                        width: parent.width
                        topPadding: 4
                        bottomPadding: 10
                        text: "Nothing in the interface announced these, so until now they only "
                            + "existed if somebody told you."
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        /* Written out by hand, and it has to match Main.qml's
                           Shortcut declarations — a reference that drifts from
                           the bindings is worse than none. */
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

                        delegate: Item {
                            id: keyRow
                            required property var modelData
                            width: parent.width
                            height: 30

                            Rectangle {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                width: keyLabel.implicitWidth + 18
                                height: 20
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.width: 1
                                border.color: Theme.line
                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: keyRow.modelData.k
                                    color: Theme.accent
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.size2xs
                                }
                            }
                            Text {
                                anchors { left: parent.left; leftMargin: 150
                                          verticalCenter: parent.verticalCenter }
                                text: keyRow.modelData.v
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

            // NETWORK ──────────────────────────────────────────
            Section {
                shown: root.section === "NETWORK"
                NetworkPanel {
                    width: parent.width
                    height: Math.max(340, bodyScroll.height - 20)
                }
            }

            // BLUETOOTH ────────────────────────────────────────
            Section {
                shown: root.section === "BLUETOOTH"
                BluetoothPanel {
                    width: parent.width
                    height: Math.max(340, bodyScroll.height - 20)
                }
            }

            // SYSTEM ───────────────────────────────────────────
            Section {
                shown: root.section === "SYSTEM"

                SettingGroup {
                    title: "IDENTITY"
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
                        separator: false
                        Text {
                            text: System.edition
                            color: Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                        }
                    }
                }

                SettingGroup {
                    title: "CLOCK"
                    SettingRow {
                        label: "24-hour clock"
                        hint: "Affects the taskbar clock"
                        HudToggle { on: Prefs.clock24; onToggled: Prefs.clock24 = !Prefs.clock24 }
                    }
                    SettingRow {
                        label: "Show seconds"
                        hint: "Taskbar clock precision"
                        separator: false
                        HudToggle { on: Prefs.seconds; onToggled: Prefs.seconds = !Prefs.seconds }
                    }
                }
            }

            // SECURITY ─────────────────────────────────────────
            Section {
                shown: root.section === "SECURITY"

                SettingGroup {
                    title: "THIS BOOT"
                    note: Security.okCount + " checks ok"

                    /* States what is actually true of this boot rather than
                       assuming. Settings that quietly evaporate on reboot are
                       worse than settings that tell you they will. */
                    Notice {
                        alert: !Store.persistent()
                        text: Store.persistent()
                            ? "Persistent storage is active. Settings, pinned icons, saved Wi-Fi "
                              + "networks and files written to your home directory survive a reboot."
                            : "No persistent storage. Everything changed this session — settings, "
                              + "pinned icons, joined networks, saved files — is lost on reboot. To "
                              + "fix that, open a terminal and run:  sudo symbiote-persist list"
                    }

                    StatusList {
                        width: parent.width
                        rows: Security.rows
                    }
                }
            }

            // ABOUT ────────────────────────────────────────────
            Section {
                shown: root.section === "ABOUT"

                SettingGroup {
                    title: "MACHINE"

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
                            { k: "Shell", v: "Symbiote Shell (Qt) 0.2" },
                            { k: "Licence", v: "MIT OR GPL-3.0-or-later" },
                            { k: "Settings file", v: Store.path() },
                            { k: "Persistence", v: Store.persistent()
                                ? "active" : "none — changes are lost on reboot" }
                        ]

                        delegate: Item {
                            id: aboutRow
                            required property var modelData
                            width: parent.width
                            height: 30
                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: aboutRow.modelData.k
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.sizeXs
                            }
                            Text {
                                anchors { right: parent.right; left: parent.left; leftMargin: 140
                                          verticalCenter: parent.verticalCenter }
                                horizontalAlignment: Text.AlignRight
                                text: aboutRow.modelData.v
                                color: Theme.textBody
                                font.family: Theme.mono
                                font.pixelSize: Theme.sizeXs
                                elide: Text.ElideMiddle
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
        }
    }

    // A scrollbar, so a section that continues below the fold says so.
    Rectangle {
        visible: bodyScroll.interactive
        anchors { right: parent.right; rightMargin: 8 }
        y: bodyScroll.y + (bodyScroll.contentY / Math.max(1, bodyScroll.contentHeight))
                          * bodyScroll.height
        width: 2
        height: Math.max(24, bodyScroll.height * (bodyScroll.height
                         / Math.max(1, bodyScroll.contentHeight)))
        color: Theme.tint(0.35)
    }

    /* ── section container ──────────────────────────────────────
       Sections cross-fade and slide in the direction of travel. The window had
       no transitions anywhere, which made every change of section feel like a
       redraw rather than a move. */
    component Section: Column {
        id: page
        property bool shown: false

        width: pages.width
        // Not merely transparent: an invisible section still takes clicks, and
        // a stack of ten of them meant the top one swallowed everything.
        visible: opacity > 0.01
        enabled: shown
        opacity: shown ? 1 : 0
        spacing: Theme.space6

        Behavior on opacity {
            NumberAnimation { duration: Prefs.dur(Theme.durMed); easing.type: Theme.easeOut }
        }
        transform: Translate {
            x: page.shown || !Prefs.motionMoves ? 0 : root.travel * Theme.slide * 2
            y: page.shown || !Prefs.motionMoves ? 0 : Theme.slide
            Behavior on x { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                              easing.type: Theme.easeOut } }
            Behavior on y { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                              easing.type: Theme.easeOut } }
        }
    }

    /* A boxed statement. Three panels were drawing this by hand with slightly
       different padding and two different ideas of what "this is a problem"
       looks like. */
    component Notice: Rectangle {
        id: notice
        property string text: ""
        property bool alert: false

        width: parent ? parent.width : 400
        height: visible ? noticeText.implicitHeight + 22 : 0
        color: notice.alert ? Qt.rgba(1, 0.09, 0.27, 0.06) : Theme.tint(0.06)
        border.width: 1
        border.color: notice.alert ? Theme.alert : Theme.hairline

        Text {
            id: noticeText
            anchors { fill: parent; margins: 11 }
            text: notice.text
            color: notice.alert ? Theme.alert : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            wrapMode: Text.WordWrap
            lineHeight: 1.4
        }
    }

    /* ── the edge picker ────────────────────────────────────────
       A dropdown reading "LEFT / RIGHT / TOP / BOTTOM" makes you translate a
       word into a place. Four positions around a rectangle do not: the control
       is a small picture of the screen, and you click the side you want the
       bar on. */
    component EdgePicker: Item {
        id: picker
        property string current: "bottom"
        signal picked(string v)

        width: 214
        // The caption lives inside the control's own height. Anchored below it
        // instead, it sat outside the bounds the row measures and printed
        // itself over the next setting's label.
        height: 140

        Rectangle {
            id: screen
            width: parent.width
            height: 118
            color: Qt.rgba(0, 0, 0, 0.35)
            border.width: 1
            border.color: Theme.line
        }

        /* The desktop inside, shrinking away from whichever edge is chosen.
           Positioned rather than anchored: anchor margins cannot carry a
           Behavior, and the point of this control is that you watch the
           desktop give up the space. */
        Rectangle {
            x: picker.current === "left" ? 30 : 5
            y: picker.current === "top" ? 22 : 5
            width: screen.width - x - (picker.current === "right" ? 30 : 5)
            height: screen.height - y - (picker.current === "bottom" ? 22 : 5)
            color: Theme.tint(0.05)
            border.width: 1
            border.color: Theme.hairline
            Behavior on x { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                              easing.type: Theme.easeOut } }
            Behavior on y { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                              easing.type: Theme.easeOut } }
            Behavior on width { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                                  easing.type: Theme.easeOut } }
            Behavior on height { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                                   easing.type: Theme.easeOut } }
        }

        Repeater {
            model: [
                { v: "top",    x: 5,   y: 5,   w: 204, h: 17 },
                { v: "bottom", x: 5,   y: 96,  w: 204, h: 17 },
                { v: "left",   x: 5,   y: 5,   w: 25,  h: 108 },
                { v: "right",  x: 184, y: 5,   w: 25,  h: 108 }
            ]

            delegate: Item {
                id: edge
                required property var modelData
                x: edge.modelData.x
                y: edge.modelData.y
                width: edge.modelData.w
                height: edge.modelData.h
                z: (edge.modelData.v === "left" || edge.modelData.v === "right") ? 2 : 1

                readonly property bool on: edge.modelData.v === picker.current

                HoverHandler { id: edgeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: picker.picked(edge.modelData.v) }

                Rectangle {
                    anchors.fill: parent
                    color: edge.on ? Theme.tint(0.30)
                         : edgeHover.hovered ? Theme.tint(0.14) : Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: edge.on ? Theme.accent
                                : edgeHover.hovered ? Theme.textMuted : "transparent"
                    Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }
                }

                // Three dots, so a strip reads as a bar rather than a border.
                Row {
                    anchors.centerIn: parent
                    spacing: 3
                    rotation: (edge.modelData.v === "left" || edge.modelData.v === "right") ? 90 : 0
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 4; height: 4
                            color: edge.on ? Theme.accent : Theme.textMuted
                        }
                    }
                }
            }
        }

        Text {
            anchors { left: parent.left; top: screen.bottom; topMargin: 7 }
            text: picker.current.toUpperCase()
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            font.letterSpacing: Theme.trackWide
        }
    }
}
