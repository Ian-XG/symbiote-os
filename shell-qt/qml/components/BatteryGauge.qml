import QtQuick
import QtQuick.Shapes
import Symbiote

/* The battery, drawn rather than spelled out.
 *
 * It used to be the digits "77%" in grey next to the clock, which reads the
 * same at 77% and at 7% — the one moment the number matters is the one moment
 * it does not stand out. Here the cell fills and drains, the colour changes at
 * the thresholds that mean something, and charging is a bolt rather than a
 * word buried in a tooltip nobody opens. */
Item {
    id: root

    property int percent: 100
    property bool charging: false
    property bool present: true
    /** Time to empty or to full, straight from UPower. Empty when unknown. */
    property string remaining: ""
    property bool showLabel: true

    readonly property bool low: percent <= 20 && !charging
    readonly property bool critical: percent <= 10 && !charging

    /* Amber for low, via the same token every other "attention" uses.
       This read Theme.accentBright, which is the brighter green -- so a
       battery under 20% glowed harder than a healthy one. The note below was
       written when the palette had no amber and claimed the problem was fixed
       at the source; it was fixed for everything that goes through
       Theme.stateColor, and this component does not, so the one place the
       fault was first noticed kept it. */
    readonly property color tint: critical ? Theme.alert
                                : low ? Theme.warn
                                : charging ? Theme.accent
                                : Theme.textBody

    implicitWidth: cell.width + cap.width + (showLabel ? label.width + 7 : 0)
    implicitHeight: 14

    /* Running low pulses, as well as changing colour.
       This note used to say colour could not carry the warning at all: the
       "attention" shade was a brighter green than the healthy one, so a nearly
       flat battery glowed like a compliment. That is fixed at the source --
       attention is amber now -- and the pulse stays because motion says the
       same thing again, and says it to someone who cannot tell the two hues
       apart. */
    SequentialAnimation on opacity {
        running: root.low && root.present && Prefs.motionOn
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: Theme.durPulse / 2 }
        NumberAnimation { to: 1.0;  duration: Theme.durPulse / 2 }
    }

    Rectangle {
        id: cell
        width: 26
        height: 13
        anchors.verticalCenter: parent.verticalCenter
        color: "transparent"
        border.width: 1
        border.color: root.tint

        // Charge level. Inset by the border so it never overlaps it.
        Rectangle {
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 4
            width: Math.max(1, (parent.width - 4) * Math.max(0, Math.min(100, root.percent)) / 100)
            color: root.tint
            opacity: root.charging ? 0.45 : 0.85
            Behavior on width { NumberAnimation { duration: Theme.durMed
                                                  easing.type: Easing.OutCubic } }

            /* Charging reads as motion, not as a static colour: the fill
               breathes while power is going in. */
            SequentialAnimation on opacity {
                running: root.charging && Prefs.motionOn
                loops: Animation.Infinite
                NumberAnimation { to: 0.8; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.3; duration: 1100; easing.type: Easing.InOutSine }
            }
        }

        // Bolt, drawn over the fill so it stays legible at any level.
        Shape {
            anchors.fill: parent
            visible: root.charging
            ShapePath {
                strokeColor: Theme.bgVoid
                strokeWidth: 2.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: [Qt.point(15, 2), Qt.point(11, 7),
                           Qt.point(14, 7), Qt.point(11, 11)]
                }
            }
            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 1.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: [Qt.point(15, 2), Qt.point(11, 7),
                           Qt.point(14, 7), Qt.point(11, 11)]
                }
            }
        }
    }

    // Terminal nub.
    Rectangle {
        id: cap
        anchors { left: cell.right; verticalCenter: parent.verticalCenter }
        width: 2
        height: 5
        color: root.tint
    }

    Text {
        id: label
        visible: root.showLabel
        anchors { left: cap.right; leftMargin: 7; verticalCenter: parent.verticalCenter }
        text: root.present ? root.percent + "%" : "AC"
        color: root.tint
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
    }
}
