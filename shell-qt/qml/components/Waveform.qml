import QtQuick
import QtQuick.Shapes
import Symbiote

/* Throughput trace.
 *
 * It used to fall back to a seeded sine when no samples were bound — and
 * nothing ever bound any, so an idle machine showed a lazy wave rolling along
 * under the words "DOWN 0 MB/s". Decorative motion presented as measurement is
 * the same lie as a made-up number, so the fallback is gone: with no data the
 * trace is a flat line at zero, which is what an idle link looks like. */
Item {
    id: root

    property int samples: 40
    property bool critical: false
    property bool paused: false
    /** Real values, 0..1, oldest first. */
    property var series: []

    readonly property color tint: critical ? Theme.alert : Theme.accent

    function pointAt(i) {
        if (!series || series.length === 0)
            return 1
        // Right-align: the newest sample sits at the right edge.
        const idx = series.length - root.samples + i
        const v = idx < 0 ? 0 : series[idx]
        return 1 - Math.max(0, Math.min(1, v === undefined ? 0 : v))
    }

    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: root.tint
            strokeWidth: 1
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: {
                    var pts = []
                    var step = root.width / (root.samples - 1)
                    for (var i = 0; i < root.samples; i++) {
                        // Inset by a pixel so a flat zero trace is not clipped
                        // in half by the bottom edge.
                        pts.push(Qt.point(i * step,
                                          1 + root.pointAt(i) * (root.height - 2)))
                    }
                    return pts
                }
            }
        }
    }
}
