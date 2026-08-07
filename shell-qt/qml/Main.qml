import QtQuick
import QtQuick.Window
import Symbiote

/* The desktop: icon column, the symbiont mass, a status rail, a taskbar.
   Lays out at the display's real size — no fixed artboard scaled to fit, which
   is what rendered the 8-11px type at half size on a high-density panel. */
Window {
    id: win
    visible: true
    visibility: Window.FullScreen
    color: Theme.bgVoid
    title: "Symbiote Shell"

    // main.cpp picks a scale from the panel's pixel width; Prefs can override
    // it live, so a wrong guess is a click to fix rather than a rebuild.
    readonly property real s: Prefs.scaleMode === "auto" ? uiScale : Number(Prefs.scaleMode)
    readonly property int railWidth: 340 * s
    readonly property int iconColWidth: 124 * s

    property bool settingsOpen: false
    property bool launcherOpen: false
    property bool wifiOpen: false
    property bool powerOpen: false
    property string clockText: ""

    property string menuTargetId: ""

    function openDesktopMenu(gx, gy) {
        iconMenu.dismiss()
        desktopMenu.entries = [
            { label: "OPEN TERMINAL", action: "terminal" },
            { label: "APPLICATIONS", action: "launcher" },
            { separator: true },
            { label: Prefs.grid ? "HIDE GRID" : "SHOW GRID", action: "grid" },
            { label: Prefs.scanline ? "HIDE SCAN LINE" : "SHOW SCAN LINE", action: "scanline" },
            { label: Prefs.vignette ? "HIDE VIGNETTE" : "SHOW VIGNETTE", action: "vignette" },
            { label: Prefs.spin ? "STOP ROTATION" : "START ROTATION", action: "spin" },
            { separator: true },
            { label: Theme.blue ? "ACCENT: TOXIN GREEN" : "ACCENT: SIGNAL BLUE", action: "accent" },
            { label: "SETTINGS", action: "settings" },
            { separator: true },
            { label: "SESSION / POWER", action: "power" }
        ]
        desktopMenu.popup(gx, gy)
    }

    function openIconMenu(id, gx, gy) {
        desktopMenu.dismiss()
        win.menuTargetId = id
        var onDesktop = Prefs.desktopIds.indexOf(id) !== -1
        var onTaskbar = Prefs.taskbarIds.indexOf(id) !== -1
        desktopMenu.dismiss()
        iconMenu.entries = [
            { label: Apps.openIds.indexOf(id) !== -1 ? "CLOSE" : "OPEN", action: "open" },
            { separator: true },
            { label: onTaskbar ? "UNPIN FROM TASKBAR" : "PIN TO TASKBAR", action: "pinbar" },
            { label: onDesktop ? "REMOVE FROM DESKTOP" : "ADD TO DESKTOP",
              action: "pindesk", danger: onDesktop }
        ]
        iconMenu.popup(gx, gy)
    }
    property string dateText: ""

    // Only ever set by a capture run; see SYMBIOTE_OPEN in main.cpp.
    Component.onCompleted: {
        // "settings", "settings:BLUETOOTH", or "launcher".
        if (accentAtStart === "signal" || accentAtStart === "toxin")
            Theme.accentMode = accentAtStart
        var parts = String(openAtStart).split(":")
        if (parts[0] === "settings") {
            settingsOpen = true
            if (parts.length > 1) settingsPanel.section = parts[1]
        } else if (parts[0] === "launcher") {
            launcherOpen = true
        } else if (parts[0] === "wifi") {
            wifiOpen = true
        } else if (parts[0] === "power") {
            powerOpen = true
        } else if (parts[0] === "ctx") {
            // Deferred: the capture path resizes the window after the QML
            // loads, so at this point it has no useful size yet.
            ctxPreview.start()
        }
    }

    // ── wallpaper ──────────────────────────────────────────────
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: Prefs.grid
        // Painted once: a static grid does not need to be a live scene.
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = Theme.gridLine
            ctx.lineWidth = 1
            var step = 32 * win.s
            for (var x = 0; x < width; x += step) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
            }
            for (var y = 0; y < height; y += step) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }

    // Repaint the wallpaper when the accent changes, otherwise the grid keeps
    // the old palette until something else forces a repaint.
    Connections {
        target: Theme
        function onAccentModeChanged() { gridCanvas.requestPaint() }
    }

    // Darkens the edges so the rail and icons sit on something, not on a void.
    Rectangle {
        anchors.fill: parent
        visible: Prefs.vignette
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    // A slow sweep down the screen. Purely atmosphere, and cheap: one
    // translated rectangle, no repaint.
    Rectangle {
        visible: Prefs.scanline
        width: parent.width
        height: 180 * win.s
        z: 40
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.wash }
            GradientStop { position: 1.0; color: "transparent" }
        }
        NumberAnimation on y {
            from: -180 * win.s
            to: win.height
            duration: 8000
            loops: Animation.Infinite
            running: Prefs.scanline
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            win.clockText = Qt.formatTime(now,
                        (Prefs.clock24 ? "HH:mm" : "hh:mm") + (Prefs.seconds ? ":ss" : "")
                        + (Prefs.clock24 ? "" : " AP"))
            win.dateText = Qt.formatDate(now, "ddd dd MMM").toUpperCase()
        }
    }

    // ── desktop icons ──────────────────────────────────────────
    DesktopIcons {
        id: icons
        anchors { left: parent.left; top: parent.top; margins: 20 * win.s }
        /* Above the marquee surface. Same z, and the surface — declared later —
           would sit on top and swallow every click on an icon. */
        z: 2
        width: win.iconColWidth
        openIds: Apps.openIds
        onContextRequested: function (id, sx, sy) { win.openIconMenu(id, sx, sy) }
        onActivated: function (id) {
            if (id === "settings")
                win.settingsOpen = !win.settingsOpen
            else if (Apps.openIds.indexOf(id) !== -1)
                Apps.close(id)
            else
                Apps.launch(id)
        }
    }

    /* Desktop surface: rubber-band selection and the desktop menu.
       Below every panel, above the wallpaper — dragging over the rail or the
       taskbar must not start a marquee. */
    MouseArea {
        id: surface
        anchors { left: parent.left; right: rail.left; top: parent.top; bottom: taskbar.top }
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 1

        property real ox: 0
        property real oy: 0
        property bool dragging: false

        onPressed: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                var g = surface.mapToItem(null, mouse.x, mouse.y)
                win.openDesktopMenu(g.x, g.y)
                return
            }
            desktopMenu.dismiss()
            iconMenu.dismiss()
            ox = mouse.x; oy = mouse.y
            marquee.x = mouse.x; marquee.y = mouse.y
            marquee.width = 0; marquee.height = 0
            dragging = true
        }
        onPositionChanged: function (mouse) {
            if (!dragging) return
            marquee.x = Math.min(ox, mouse.x)
            marquee.y = Math.min(oy, mouse.y)
            marquee.width = Math.abs(mouse.x - ox)
            marquee.height = Math.abs(mouse.y - oy)
            // A click is a click, not a zero-sized drag.
            if (marquee.width > 3 || marquee.height > 3) {
                var p = surface.mapToItem(icons, marquee.x, marquee.y)
                icons.selectedIds = icons.idsInRect(p.x, p.y, marquee.width, marquee.height)
            }
        }
        onReleased: {
            if (dragging && marquee.width < 4 && marquee.height < 4)
                icons.selectedIds = []      // a bare click clears the selection
            dragging = false
        }

        Rectangle {
            id: marquee
            visible: surface.dragging && (width > 3 || height > 3)
            color: Theme.tint(0.10)
            border.width: 1
            border.color: Theme.accent
        }
    }

    // ── the symbiont mass ──────────────────────────────────────
    Hologram {
        id: holo
        /* Centred on the display, not on the stage. The stage is what is left
           between the icon column and the rail, and centring in it put the
           mass visibly left of the screen's middle — which is what it looked
           like, because it was. */
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: stage.verticalCenter
        /* Sized off the stage, but capped. Filling the stage made it a
           background texture rather than a centrepiece — at 1920x1080 it
           reached almost from the icon column to the rail. Two thirds of the
           stage height leaves the surrounding void the design asks for. */
        visible: Prefs.holoDetail !== "off"
        width: Math.max(280, Math.min(stage.height * (holo.coarse ? 0.54 : 0.66),
                                      stage.width * (holo.coarse ? 0.45 : 0.55),
                                      620 * win.s))
        height: width

        /* Stops when nobody is looking at it: covered by a window, or on
           battery. The Electron build measured this animation costing a whole
           core; here it is cheap, but a still hologram on battery is still
           cheaper than a moving one. */
        /* Only stops when asked to, or when something is actually covering it.
           It used to stop on battery and whenever any app was open — on a
           laptop running from a USB stick that meant it never moved once, and
           the only clue was the word PAUSED in 8px type. Saving a little CPU is
           not worth the centrepiece looking broken. */
        paused: !Prefs.spin || win.settingsOpen || win.launcherOpen
    }

    Item {
        id: stage
        anchors {
            left: icons.right; leftMargin: 20 * win.s
            right: rail.left; rightMargin: 20 * win.s
            top: parent.top; topMargin: 20 * win.s
            bottom: taskbar.top; bottomMargin: 20 * win.s
        }
    }

    // ── status rail ────────────────────────────────────────────
    /* PROCESSES takes the leftover height, down to a floor of four rows. Sized
       purely by what was left, an 800px-tall screen gave it 45px and it showed
       nothing at all; below the floor the rail scrolls instead, which is the
       honest failure — the panel is short, not empty. */
    Flickable {
        id: rail
        contentHeight: Math.max(height, railCol.height + 16 * win.s + procPanel.height)
        boundsBehavior: Flickable.StopAtBounds
        width: win.railWidth
        anchors {
            right: parent.right; rightMargin: 20 * win.s
            top: parent.top; topMargin: 20 * win.s
            bottom: taskbar.top; bottomMargin: 20 * win.s
        }
        clip: true

        Column {
            id: railCol
            width: rail.width
            anchors.top: parent.top
            spacing: 16 * win.s

            Panel {
                width: parent.width
                title: "SYSTEM"
                code: "LIVE"
                active: true
                Column {
                    width: parent.width
                    spacing: 7
                    MicroReadout {
                        code: System.cpu.cores + " CORES"
                              + (System.cpu.ghz ? " · " + System.cpu.ghz + " GHz" : "")
                        label: "PROCESSOR"
                        value: System.cpu.usage + "%"
                        filled: Math.max(1, Math.round(System.cpu.usage / 12.5))
                    }
                    MicroReadout {
                        code: System.memory.usedGb + " / " + System.memory.totalGb + " GB"
                        label: "MEMORY"
                        value: System.memory.usage + "%"
                        filled: Math.max(1, Math.round(System.memory.usage / 12.5))
                    }
                    MicroReadout {
                        code: System.storage.freeGb + " / " + System.storage.totalGb + " GB FREE"
                        label: "STORAGE"
                        value: System.storage.usage + "%"
                        filled: Math.max(1, Math.round(System.storage.usage / 12.5))
                    }
                    MicroReadout {
                        code: System.thermal.fanRpm ? "FAN " + System.thermal.fanRpm + " RPM" : "NO FAN DATA"
                        label: "TEMPERATURE"
                        value: System.thermal.celsius === undefined || System.thermal.celsius === null
                               ? "NO SENSOR" : System.thermal.celsius + "°C"
                        filled: System.thermal.celsius ? Math.round(System.thermal.celsius / 12.5) : 0
                        critical: System.thermal.celsius > 85
                    }
                    /* Not a MicroReadout. The eight-segment bar every other
                       row uses made a battery at 12% look much like one at
                       37%, and rounding put a segment on the board at 0%. */
                    Item {
                        width: parent.width
                        height: 34

                        Text {
                            id: battCode
                            anchors.left: parent.left
                            text: !Power.present ? "NO BATTERY"
                                : Power.onAc ? (Power.remaining ? Power.remaining + " TO FULL"
                                                                : "CHARGING")
                                : (Power.remaining ? Power.remaining + " REMAINING"
                                                   : Power.state.toUpperCase())
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: Theme.size2xs
                            font.letterSpacing: Theme.trackWide
                        }
                        Text {
                            anchors { left: parent.left; top: battCode.bottom; topMargin: 1 }
                            text: "BATTERY"
                            color: Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                            font.letterSpacing: Theme.trackWide
                        }
                        BatteryGauge {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            percent: Power.present ? Power.percent : 100
                            charging: Power.onAc
                            present: Power.present
                        }
                    }
                }
            }

            Panel {
                width: parent.width
                title: "NETWORK"
                code: {
                    var p = System.primaryInterface()
                    return p && p.name ? p.name.toUpperCase() : "NO LINK"
                }
                Column {
                    width: parent.width
                    spacing: 8
                    Waveform {
                        id: netTrace
                        width: parent.width
                        height: 40 * win.s

                        /* Real throughput, scaled against the highest rate seen
                           this session so a 2 MB/s burst on a quiet link is
                           still visible. */
                        property real peak: 0.25

                        Connections {
                            target: System
                            function onChanged() {
                                var p = System.primaryInterface()
                                var total = (p.downMbs || 0) + (p.upMbs || 0)
                                netTrace.peak = Math.max(netTrace.peak, total)
                                var h = netTrace.series.slice(-59)
                                h.push(total / netTrace.peak)
                                netTrace.series = h
                            }
                        }
                    }
                    Item {
                        width: parent.width
                        height: downText.implicitHeight
                        Text {
                            id: downText
                            anchors.left: parent.left
                            text: "DOWN " + (System.primaryInterface().downMbs || 0) + " MB/s"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                        }
                        Text {
                            anchors.right: parent.right
                            text: "UP " + (System.primaryInterface().upMbs || 0) + " MB/s"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: Theme.sizeXs
                        }
                    }
                }
            }

            Panel {
                width: parent.width
                title: "SECURITY"
                code: Security.okCount + " CHECKS OK"
                StatusList {
                    width: parent.width
                    rows: Security.rows
                }
            }

        }

        Panel {
            id: procPanel
            anchors {
                left: parent.left; right: parent.right
                top: railCol.bottom; topMargin: 16 * win.s
            }
            height: Math.max(150 * win.s,
                             rail.height - railCol.height - 16 * win.s)
            stretch: true
            title: "PROCESSES"
            code: procList.shown + " OF " + Processes.top.length
            active: true
            ProcessList {
                id: procList
                anchors.fill: parent
                rows: Processes.top
            }
        }
    }

    // ── app launcher ───────────────────────────────────────────
    AppLauncher {
        anchors.fill: parent
        bottomInset: taskbar.height
        visible: win.launcherOpen
        z: 55
        onLaunched: function (id, exec) {
            win.launcherOpen = false
            if (id === "settings") win.settingsOpen = true
            // Discovered entries carry their own command; curated ones do not.
            else if (exec) Apps.launchCommand(id, exec)
            else if (Apps.openIds.indexOf(id) !== -1) Apps.close(id)
            else Apps.launch(id)
        }
        onDismissed: win.launcherOpen = false
    }

    Timer {
        id: ctxPreview
        interval: 900
        onTriggered: win.openDesktopMenu(win.width * 0.28, win.height * 0.22)
    }

    // ── wireless popup ─────────────────────────────────────────
    WifiPopup {
        anchors.fill: parent
        bottomInset: taskbar.height
        visible: win.wifiOpen
        z: 60
        onDismissed: win.wifiOpen = false
    }

    PowerMenu {
        anchors.fill: parent
        bottomInset: taskbar.height
        visible: win.powerOpen
        z: 62
        onDismissed: win.powerOpen = false
    }

    // ── context menus ──────────────────────────────────────────
    ContextMenu {
        id: desktopMenu
        anchors.fill: parent
        z: 70
        onPicked: function (action) {
            switch (action) {
            case "terminal":  Apps.launch("terminal"); break
            case "launcher":  win.launcherOpen = true; break
            case "grid":      Prefs.grid = !Prefs.grid; break
            case "scanline":  Prefs.scanline = !Prefs.scanline; break
            case "vignette":  Prefs.vignette = !Prefs.vignette; break
            case "spin":      Prefs.spin = !Prefs.spin; break
            case "accent":    Theme.accentMode = Theme.blue ? "toxin" : "signal"; break
            case "settings":  win.settingsOpen = true; break
            case "power":     win.powerOpen = true; break
            }
        }
    }

    ContextMenu {
        id: iconMenu
        anchors.fill: parent
        z: 71
        onPicked: function (action) {
            var id = win.menuTargetId
            if (!id) return
            switch (action) {
            case "open":
                if (id === "settings") win.settingsOpen = true
                else if (Apps.openIds.indexOf(id) !== -1) Apps.close(id)
                else Apps.launch(id)
                break
            case "pinbar":  Prefs.toggleIn("taskbar", id); break
            case "pindesk": Prefs.toggleIn("desktop", id); break
            }
        }
    }

    // ── settings ───────────────────────────────────────────────
    SettingsWindow {
        id: settingsPanel
        visible: win.settingsOpen
        anchors.centerIn: parent
        width: Math.min(780 * win.s, win.width - 80)
        height: Math.min(560 * win.s, win.height - 160)
        onClosed: win.settingsOpen = false
    }

    // ── launch errors ──────────────────────────────────────────
    Rectangle {
        visible: Apps.lastError !== ""
        anchors { horizontalCenter: parent.horizontalCenter; bottom: taskbar.top; bottomMargin: 16 }
        width: errLabel.width + 36
        height: 38
        color: Qt.rgba(0.08, 0, 0.02, 0.92)
        border.width: 1
        border.color: Theme.alert
        Text {
            id: errLabel
            anchors.centerIn: parent
            text: Apps.lastError
            color: Theme.alert
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
        }
        // A failed launch that says nothing is what made the icons feel dead.
        Timer {
            interval: 6000
            running: Apps.lastError !== ""
            onTriggered: Apps.lastError = ""
        }
    }

    // ── taskbar ────────────────────────────────────────────────
    Taskbar {
        id: taskbar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        openIds: Apps.openIds
        clock: win.clockText
        date: win.dateText
        vpnUp: {
            for (var i = 0; i < Security.rows.length; i++)
                if (Security.rows[i].label === "VPN")
                    return Security.rows[i].state === "ok"
            return false
        }
        ifaceName: {
            var p = System.primaryInterface()
            return p && p.name ? p.name : ""
        }
        cpu: System.cpu.usage
        battery: Power.percent
        batteryPresent: Power.present
        batteryCharging: Power.onAc
        onLaunched: function (id) {
            if (Apps.openIds.indexOf(id) !== -1) Apps.close(id)
            else Apps.launch(id)
        }
        onMenuToggled: win.launcherOpen = !win.launcherOpen
        onWifiRequested: win.wifiOpen = !win.wifiOpen
        onPowerRequested: win.powerOpen = !win.powerOpen
        powerOpen: win.powerOpen
        wifiOpen: win.wifiOpen
        wifiAvailable: Network.available
        wifiConnected: {
            for (var i = 0; i < Network.networks.length; i++)
                if (Network.networks[i].connected) return true
            return false
        }
        wifiSsid: {
            for (var i = 0; i < Network.networks.length; i++)
                if (Network.networks[i].connected) return Network.networks[i].ssid
            return ""
        }
        onContextRequested: function (id, sx, sy) { win.openIconMenu(id, sx, sy) }
    }
}
