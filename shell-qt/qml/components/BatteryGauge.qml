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

    readonly property color tint: critical ? Theme.alert
                                : low ? Theme.accentBright
                                : charging ? Theme.accent
                                : Theme.textBody

    implicitWidth: cell.width + cap.width + (showLabel ? label.width + 7 : 0)
    implicitHeight: 14

    /* Running low pulses. The palette is monochrome green with red reserved
       for genuinely critical states, so colour alone cannot carry the warning:
       the "attention" green is brighter than the normal one, which reads as
       healthier rather than worse. Movement is unambiguous either way. */
    SequentialAnimation on opacity {
        running: root.low && root.present
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
                running: root.charging
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
