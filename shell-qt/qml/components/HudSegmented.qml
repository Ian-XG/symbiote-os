import QtQuick
import Symbiote

/* A row of mutually exclusive boxes. Right for two to four options; past that
   use HudDropdown, which is why that exists.

   Lifted out of SettingsWindow so the Wi-Fi and Bluetooth panels can use the
   same control instead of each growing their own. */
Row {
    id: seg

    /** [{ v: "toxin", t: "TOXIN GREEN" }, …] */
    property var options: []
    property string current: ""
    property bool enabled: true
    signal picked(string v)

    spacing: 6

    Repeater {
        model: seg.options

        /* Addressed by id, not by walking `parent`. A Repeater reparents its
           delegates to the Row, so `parent.parent` landed on the row above and
           the comparison was against undefined — no segment ever showed as
           selected, including the accent the shell was actually using. */
        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool on: cell.modelData.v === seg.current

            width: segLabel.implicitWidth + 22
            height: Theme.ctrlHeight

            HoverHandler { id: segHover; enabled: seg.enabled; cursorShape: Qt.PointingHandCursor }
            TapHandler { enabled: seg.enabled; onTapped: seg.picked(cell.modelData.v) }

            Rectangle {
                anchors.fill: parent
                color: cell.on ? Theme.tint(0.12)
                     : segHover.hovered ? Theme.tint(0.06) : "transparent"
                border.width: 1
                border.color: !seg.enabled ? Theme.line
                            : cell.on ? Theme.accent
                            : segHover.hovered ? Theme.textMuted : Theme.line
                Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
            }

            // A rule under the chosen one, so selection survives being read in
            // a hurry: the tint alone is a shade apart from the hover state.
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 2
                color: Theme.accent
                opacity: cell.on ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
            }

            Text {
                id: segLabel
                anchors.centerIn: parent
                text: cell.modelData.t
                color: !seg.enabled ? Theme.line
                     : cell.on ? Theme.accent
                     : segHover.hovered ? Theme.textBody : Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
            }
        }
    }
}
