import QtQuick
import Symbiote

/* One metric: what it is, how much, the detail, and a level bar.
 *
 * The order matters and it used to be wrong. Code, value and label were all
 * set at the same 8px, so there was no hierarchy at all -- three pieces of
 * text differing only in colour. Worse, the label sat on its own line *below*
 * the row holding the value, so the two halves of a single fact ("processor"
 * and "10%") were split across two lines and two ends of the panel. Reading
 * one meter meant three eye movements.
 *
 * A readout on a HUD is glanced at, not studied. The number is the thing being
 * looked for, so it is the largest and it sits on the same baseline as the
 * name of what it measures. The detail line -- core count, capacity -- is
 * context and goes quiet underneath.
 */
Item {
    id: root

    property string code: ""
    property string label: ""
    property string value: ""
    property int filled: 0
    property int segments: 8
    property bool critical: false
    property bool compact: true
    /* False when there is no reading at all -- no sensor, no such device.
     * "NO SENSOR" was drawn in the same accent green as "41°C" and sat over a
     * full eight-segment meter reading zero, so an absent sensor looked like a
     * cold one: a healthy number and a bar at the bottom of its range. An
     * absence is not a measurement and should not be dressed as one. */
    property bool known: true

    readonly property color tint: critical ? Theme.alert : Theme.accent

    implicitHeight: col.implicitHeight
    width: parent ? parent.width : 200

    Column {
        id: col
        width: parent.width
        spacing: 2

        // Name and number, one baseline. The pair that is actually read.
        Item {
            width: parent.width
            height: Math.max(nameText.implicitHeight, valueText.implicitHeight)

            Text {
                id: nameText
                anchors { left: parent.left; baseline: valueText.baseline }
                text: root.label
                color: root.critical ? Theme.alert : Theme.textBody
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
            }
            Text {
                id: valueText
                anchors { right: parent.right; top: parent.top }
                text: root.value
                color: root.known ? root.tint : Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.sizeSm
            }
        }

        // Context, and quiet about it.
        Text {
            width: parent.width
            visible: root.code !== ""
            text: root.code
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            visible: root.known
            spacing: 2
            topPadding: 2
            Repeater {
                model: root.segments
                Rectangle {
                    width: (root.width - (root.segments - 1) * 2) / root.segments
                    height: root.compact ? 3 : 4
                    /* The empty track was Theme.line, which is very nearly the
                       background: a meter reading 1 of 8 looked like a single
                       floating dash rather than a bar with one segment lit.
                       A faint accent wash keeps the full length visible, so
                       the filled part is read as a proportion. */
                    color: index < root.filled ? root.tint : Theme.tint(0.10)
                }
            }
        }
    }
}
