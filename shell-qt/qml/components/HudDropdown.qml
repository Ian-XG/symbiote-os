import QtQuick
import QtQuick.Window
import Symbiote

/* A dropdown, which the shell had none of.
 *
 * Every choice in Settings was a Segmented row: one bordered box per option,
 * laid out across the panel. That is right for two or three options and wrong
 * for more — the keyboard layout row rendered one box per installed layout and
 * ran off the edge of the window, and the launcher's tool categories would do
 * the same. A list that grows needs a control that does not.
 *
 * The popup is reparented to the window's content item on the way up. Inside
 * the Settings body it would otherwise be clipped by the scroll area it lives
 * in, which is the failure that makes hand-rolled dropdowns feel broken: the
 * list opens and the bottom three entries are simply not there.
 */
Item {
    id: dd

    /** [{ v: "auto", t: "AUTO", hint: "…" }, …] */
    property var options: []
    property string current: ""
    property bool enabled: true
    /** Shown when `current` matches nothing — a value the system chose, say. */
    property string placeholder: "—"

    signal picked(string v)

    readonly property string currentText: {
        for (var i = 0; i < options.length; i++)
            if (options[i].v === current) return options[i].t
        return placeholder
    }

    property bool open: false

    implicitWidth: Math.max(132, Math.min(240, widest.implicitWidth + 46))
    implicitHeight: Theme.ctrlHeight
    width: implicitWidth
    height: implicitHeight

    // Measured, never drawn: the box is as wide as its longest option so the
    // control does not resize as the selection changes.
    Text {
        id: widest
        visible: false
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
        font.letterSpacing: Theme.trackWide
        text: {
            var longest = dd.placeholder
            for (var i = 0; i < dd.options.length; i++)
                if (String(dd.options[i].t).length > longest.length)
                    longest = dd.options[i].t
            return longest
        }
    }

    HoverHandler { id: hover; enabled: dd.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        enabled: dd.enabled
        onTapped: dd.open = !dd.open
    }

    Rectangle {
        anchors.fill: parent
        color: dd.open ? Theme.tint(0.10)
             : hover.hovered ? Theme.tint(0.06) : Qt.rgba(0, 0, 0, 0.35)
        border.width: 1
        border.color: !dd.enabled ? Theme.line
                    : (dd.open || hover.hovered) ? Theme.accent : Theme.line
        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
        Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
    }

    Text {
        anchors { left: parent.left; leftMargin: 10; right: caret.left; rightMargin: 8
                  verticalCenter: parent.verticalCenter }
        text: dd.currentText
        color: !dd.enabled ? Theme.textMuted : Theme.accent
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
        font.letterSpacing: Theme.trackWide
        elide: Text.ElideRight
    }

    // A chevron that turns over, so the open state is visible on the control
    // itself and not only in the list that may be off the bottom of a scroll.
    Canvas {
        id: caret
        width: 9; height: 6
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        rotation: dd.open ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                                 easing.type: Theme.easeOut } }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = dd.enabled ? Theme.accent : Theme.textMuted
            ctx.lineWidth = 1.2
            ctx.beginPath()
            ctx.moveTo(0.5, 1); ctx.lineTo(width / 2, height - 1); ctx.lineTo(width - 0.5, 1)
            ctx.stroke()
        }
        Connections {
            target: Theme
            function onAccentModeChanged() { caret.requestPaint() }
        }
    }

    // ── the list, hoisted out of whatever is clipping us ───────
    Item {
        id: overlay
        parent: dd.Window.contentItem
        visible: dd.open
        anchors.fill: parent
        z: 9000

        // Click-away. Anywhere outside the list closes it, including on the
        // control itself — the TapHandler above then reopens it, which is what
        // a second click on a dropdown should do.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: dd.open = false
        }

        Item {
            id: sheet
            /* Positioned in window coordinates every time it opens. Anchoring
               to the control is not possible once the popup lives somewhere
               else in the scene. */
            readonly property point origin: dd.open && dd.Window.contentItem
                ? dd.mapToItem(dd.Window.contentItem, 0, 0) : Qt.point(0, 0)
            readonly property real listHeight: Math.min(268, dd.options.length * 26 + 8)
            // Flips above the control when there is no room below.
            readonly property bool above: origin.y + dd.height + listHeight
                                          > (dd.Window.contentItem ? dd.Window.contentItem.height : 0) - 8

            x: origin.x
            y: above ? origin.y - listHeight - 2 : origin.y + dd.height + 2
            width: Math.max(dd.width, 148)
            height: listHeight

            MouseArea { anchors.fill: parent }

            Rectangle { anchors.fill: parent; color: Theme.bgVoid }
            Rectangle {
                anchors.fill: parent
                color: Theme.surfaceRaise
                border.width: 1
                border.color: Theme.accent
            }

            opacity: dd.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
            transform: Translate {
                y: dd.open || !Prefs.motionMoves ? 0 : (sheet.above ? 6 : -6)
                Behavior on y { NumberAnimation { duration: Prefs.dur(Theme.durFast)
                                                  easing.type: Theme.easeOut } }
            }

            ListView {
                anchors { fill: parent; margins: 4 }
                clip: true
                model: dd.options
                interactive: contentHeight > height
                currentIndex: -1

                /* Addressed by id throughout. Walking `parent` from inside a
                   delegate is how the Segmented control in Settings ended up
                   comparing against undefined and never marking anything as
                   selected — one level out and it fails silently. */
                delegate: Item {
                    id: row
                    required property var modelData
                    width: ListView.view.width
                    height: 26

                    readonly property bool on: row.modelData.v === dd.current

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            dd.open = false
                            if (!row.on)
                                dd.picked(row.modelData.v)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: row.on ? Theme.tint(0.12)
                             : rowHover.hovered ? Theme.tint(0.07) : "transparent"
                    }
                    // The selected row is marked, not merely tinted: a tint on
                    // a hovered row and a tint on the current row were the same
                    // colour, so the list forgot which one was chosen.
                    Rectangle {
                        visible: row.on
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: Theme.accent
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 10; right: parent.right
                                  rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: row.modelData.t
                        color: row.on ? Theme.accent
                             : rowHover.hovered ? Theme.textBody : Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                        font.letterSpacing: Theme.trackWide
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // A dropdown left open behind a closing panel would sit on the desktop
    // with nothing under it.
    onVisibleChanged: if (!visible) open = false
    Component.onDestruction: open = false
}
