import QtQuick
import QtQuick.Window
import Symbiote

/*
 * The desktop on a monitor that is not the primary one.
 *
 * The shell was a single fullscreen window. On a two-monitor desk that meant
 * one panel had a desktop and the other had nothing at all — no wallpaper, no
 * taskbar, no clock. Windows could be dragged there, but once there they were
 * unreachable from the bar, because the bar was on the other screen.
 *
 * This is deliberately not a second copy of the whole shell. The hologram, the
 * status rail and the icon column belong in one place; duplicated across three
 * monitors they would be noise, and three live holograms is three times the
 * work for one machine's worth of information. What a second screen needs is
 * the wallpaper, so it looks like part of the same desktop, and a taskbar, so
 * the windows on it can be reached.
 *
 * Anything that opens a panel — the menu, Wi-Fi, power — hands off to the
 * primary window rather than opening a second copy here.
 */
Window {
    id: sec

    property var targetScreen: null
    // Everything the taskbar needs, passed down rather than read globally, so
    // this file has no opinion about where the primary window keeps its state.
    property real s: 1
    property string clockText: ""
    property string dateText: ""
    property bool launcherOpen: false

    signal menuToggled()
    signal wifiRequested()
    signal powerRequested()
    signal mediaRequested()

    screen: targetScreen
    visible: true
    visibility: Window.FullScreen
    color: Theme.bgVoid
    title: "Symbiote Shell"
    flags: Qt.Window

    readonly property real barSize: Prefs.taskbarThickness * sec.s

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: Prefs.grid
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = Theme.gridLine
            ctx.lineWidth = 1
            var step = 32 * sec.s
            for (var x = 0; x < width; x += step) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
            }
            for (var y = 0; y < height; y += step) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }

    Connections {
        target: Theme
        function onAccentModeChanged() { gridCanvas.requestPaint() }
    }

    Rectangle {
        anchors.fill: parent
        visible: Prefs.vignette
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.55; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    /* Names the monitor, faintly, in the middle of the empty area. On a desk
       with three identical panels this is the only way to tell which one the
       arrangement in Settings is talking about. */
    Text {
        anchors.centerIn: parent
        text: sec.targetScreen ? sec.targetScreen.name : ""
        color: Theme.textFaint
        font.family: Theme.mono
        font.pixelSize: 48 * sec.s
        font.letterSpacing: Theme.trackWider
        opacity: 0.25
    }

    Taskbar {
        edge: Prefs.taskbarEdge
        thickness: sec.barSize
        band: Prefs.taskbarBase * sec.s
        // Geometry, not anchors — see the note in Main.qml.
        width:  Prefs.taskbarVertical ? sec.barSize : sec.width
        height: Prefs.taskbarVertical ? sec.height : sec.barSize
        x: Prefs.taskbarEdge === "right"  ? sec.width  - sec.barSize : 0
        y: Prefs.taskbarEdge === "bottom" ? sec.height - sec.barSize : 0
        z: 30
        openIds: Apps.openIds
        startingIds: Apps.startingIds
        clock: sec.clockText
        date: sec.dateText
        launcherOpen: sec.launcherOpen
        cpu: System.cpu.usage
        battery: Power.percent
        batteryPresent: Power.present
        batteryCharging: Power.onAc
        wifiConnected: Network.connected
        wifiAvailable: Network.available
        wifiSsid: Network.ssid
        onLaunched: function (id) {
            if (Apps.openIds.indexOf(id) !== -1) Apps.close(id)
            else Apps.launch(id)
        }
        // Panels belong to the primary window; this only asks for them.
        onMenuToggled: sec.menuToggled()
        onWifiRequested: sec.wifiRequested()
        onPowerRequested: sec.powerRequested()
        onMediaRequested: sec.mediaRequested()
    }
}
