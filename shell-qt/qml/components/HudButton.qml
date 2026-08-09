import QtQuick
import Symbiote

/* The button, once.
 *
 * There were three of these — one inside NetworkPanel, one inside
 * BluetoothPanel, one improvised in PowerMenu — each a private `component
 * HudButton` with its own padding, its own hover tint and its own idea of what
 * a disabled button looks like. They had already drifted: two of them were 28
 * high and one was 26, and only one of the three dimmed its border when
 * disabled. A control that appears in four panels belongs in one file.
 */
Item {
    id: btn

    property string text: ""
    /** "outline" (default) · "solid" · "ghost" */
    property string variant: "outline"
    property bool danger: false
    property bool enabled: true
    /* Waiting on something. Reads as disabled, but says why: a button that
       greys out with no explanation looks broken rather than busy. */
    property bool busy: false
    property string busyText: ""
    /** Fills whatever it is put in, rather than hugging its label. */
    property bool fill: false

    signal clicked()

    readonly property bool live: enabled && !busy
    readonly property color hue: danger ? Theme.alert : Theme.accent

    implicitWidth: label.implicitWidth + 26
    implicitHeight: Theme.ctrlHeight
    width: fill ? (parent ? parent.width : implicitWidth) : implicitWidth
    height: implicitHeight

    HoverHandler { id: hover; enabled: btn.live; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: tap
        enabled: btn.live
        onTapped: btn.clicked()
    }

    Rectangle {
        anchors.fill: parent
        color: !btn.live ? "transparent"
             : btn.variant === "solid" ? Theme.tint(tap.pressed ? 0.26 : hover.hovered ? 0.18 : 0.12)
             : tap.pressed ? Theme.tint(0.16)
             : hover.hovered ? Theme.tint(0.08)
             : "transparent"
        border.width: btn.variant === "ghost" ? 0 : 1
        border.color: !btn.live ? Theme.line : btn.hue
        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
        Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.busy && btn.busyText ? btn.busyText : btn.text
        color: !btn.live ? Theme.textMuted : btn.hue
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
        font.letterSpacing: Theme.trackWide
    }

    /* A busy button paces rather than freezes. Without it the only difference
       between "working" and "dead" is a word, and people click again. */
    SequentialAnimation on opacity {
        running: btn.busy && Prefs.motionOn
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 620; easing.type: Theme.easeStandard }
        NumberAnimation { to: 1.0;  duration: 620; easing.type: Theme.easeStandard }
        onStopped: btn.opacity = 1
    }
}
