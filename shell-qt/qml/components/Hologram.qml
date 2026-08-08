import QtQuick
import QtQuick.Shapes
import Symbiote

/* The symbiont mass.
 *
 * Two things had to be got right, and the first version got neither.
 *
 * Rotation: Qt Quick's Rotation has no perspective projection, so `axis.y` on a
 * flat Shape squashes it to nothing and the mass simply vanished. The
 * orthographic projection of a sphere's meridian is just cos(angle) — each
 * plane narrows, crosses zero edge-on, and opens out mirrored on the way round.
 * One Scale transform per meridian, geometry untouched.
 *
 * Silhouette: every meridian of a sphere shares the same outline; only the
 * horizontal squash differs. Giving each its own noise seed — which is what the
 * second version did — produced a tangle of unrelated lumpy rings instead of a
 * body. So the outline is built once, and everything here is that one curve
 * transformed. The mass reads as solid because its meridians agree on where its
 * edge is. */
Item {
    id: root

    /* Measured: the mass is ~63% of the shell's CPU under software
       rasterisation, and the cost is compositing one layer per curve. Fewer
       curves is the only lever that moves it much, so a machine with no GPU
       gets a coarser cage. With one, the full count is free. */
    readonly property bool coarse: Prefs.holoDetail === "reduced"
        || (Prefs.holoDetail === "auto" && softwareRender)
    property int meridians: coarse ? 7 : 12
    property int latitudes: coarse ? 4 : 5
    property bool paused: false

    /* What the mass is actually showing.
     *
     * Everything else on this screen is measured; this was the one thing that
     * moved for its own sake. It is also the largest element on the display,
     * which is a lot of screen spent on decoration.
     *
     * Now it turns at the speed of the processor, breathes with memory
     * pressure, and its filaments quicken with network traffic. The caption
     * says so, because an interface that encodes data without naming it is
     * just a prettier kind of noise. */
    property real load: 0        // 0..1, processor
    property real memory: 0      // 0..1, memory in use
    property real traffic: 0     // 0..1, network relative to session peak
    property bool alert: false   // a security check is critical

    // Idle turns once in 45s; saturated, once in 9. Eased so a brief spike
    // does not make it lurch.
    readonly property int spinMs: Math.round(45000 - 36000 * Math.max(0, Math.min(1, load)))

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real unit: Math.min(width, height) / 100

    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: Math.PI * 2
        duration: root.spinMs
        loops: Animation.Infinite
        running: !root.paused
    }

    /* The prototype's silhouette, harmonic for harmonic — four terms at
       wobble 0.17 about a radius of 36, which is what gives the mass its
       lumpy, membranous edge.
       
       The one change from the prototype: a single shared seed. The prototype
       gave every meridian its own, which in a browser's real 3D transform
       still reads as one body; projected orthographically it read as a tangle
       of unrelated rings. Same curve, agreed on by all twelve planes. */
    /* The prototype used 0.17, but it gave every meridian a different seed, so
       the lumps landed in different places and averaged into a body. Sharing
       one seed — which is what stops the tangle — makes the lumps stack
       instead, and at 0.17 the silhouette collapses into a three-lobed star.
       Same four harmonics, a little over half the amplitude. */
    readonly property real wobble: 0.085
    readonly property var outline: {
        var pts = []
        var steps = 88
        var seed = 0.85
        for (var i = 0; i <= steps; i++) {
            var t = (i / steps) * Math.PI * 2
            var r = 36 * (1
                + wobble * 0.90 * Math.sin(3 * t + seed)
                + wobble * 0.55 * Math.sin(5 * t + seed * 1.7)
                + wobble * 0.30 * Math.sin(7 * t + seed * 0.4)
                + wobble * 0.18 * Math.sin(11 * t + seed * 2.3))
            pts.push(Qt.point(50 + Math.cos(t) * r, 50 + Math.sin(t) * r))
        }
        return pts
    }

    /* Scale the shared outline into pixels, optionally flattening it about the
       centre and sliding it down the axis — that is what turns a meridian into
       a latitude ring. */
    function ring(flatten, shift) {
        var out = []
        for (var i = 0; i < outline.length; i++) {
            out.push(Qt.point(outline[i].x * unit,
                              (50 + (outline[i].y - 50) * flatten + shift) * unit))
        }
        return out
    }

    readonly property var meridianPath: ring(1, 0)

    /* Both glows are Shapes, not Rectangles. A Rectangle's `Gradient` is a
       linear vertical ramp — bright at the top edge, clear at the bottom — so
       the previous version drew two domes lit from above instead of two
       spherical glows. Only Shapes have a radial fill. */

    // ── containment glow ───────────────────────────────────────
    Shape {
        id: glow
        anchors.fill: parent
        layer.enabled: layersSafe
        layer.smooth: true
        readonly property real r: Math.min(width, height) * 0.43
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: glow.width / 2;  centerY: glow.height / 2
                focalX: centerX;          focalY: centerY
                centerRadius: glow.r
                GradientStop { position: 0.0; color: Theme.tint(0.09) }
                GradientStop { position: 0.6; color: Theme.tint(0.025) }
                GradientStop { position: 1.0; color: "transparent" }
            }
            PathAngleArc {
                centerX: glow.width / 2; centerY: glow.height / 2
                radiusX: glow.r;         radiusY: glow.r
                startAngle: 0;           sweepAngle: 360
            }
        }
        opacity: 0.55
        SequentialAnimation on opacity {
            running: !root.paused
            loops: Animation.Infinite
            NumberAnimation { to: 0.8; duration: 2750; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.4; duration: 2750; easing.type: Easing.InOutSine }
        }
    }

    // ── fixed reticle ──────────────────────────────────────────
    Shape {
        anchors.fill: parent
        layer.enabled: layersSafe
        layer.smooth: true
        opacity: 0.4
        ShapePath {
            strokeColor: Theme.accent
            strokeWidth: 1
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathMultiline {
                paths: {
                    var out = []
                    for (var i = 0; i < 72; i++) {
                        var a = (i / 72) * Math.PI * 2
                        var major = (i % 6) === 0
                        var r0 = (major ? 45.5 : 47.2) * root.unit
                        var r1 = 48.6 * root.unit
                        out.push([
                            Qt.point(root.cx + Math.cos(a) * r0, root.cy + Math.sin(a) * r0),
                            Qt.point(root.cx + Math.cos(a) * r1, root.cy + Math.sin(a) * r1)
                        ])
                    }
                    return out
                }
            }
        }
    }

    /* Dashed containment ring at r=44, straight from the prototype. */
    Shape {
        anchors.fill: parent
        layer.enabled: layersSafe
        layer.smooth: true
        opacity: 0.5
        ShapePath {
            strokeColor: Theme.hairline
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [1, 3]
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.cx; centerY: root.cy
                radiusX: 44 * root.unit; radiusY: 44 * root.unit
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    /* Filaments: tendrils reaching out of the mass into the readouts around
       it. The prototype had six; the Qt port dropped them entirely, which is
       most of why it reads as a globe rather than as something alive. */
    Repeater {
        model: root.coarse ? 3 : 6

        Shape {
            id: fil
            anchors.fill: parent
            layer.enabled: layersSafe
            layer.smooth: true

            readonly property real a: (index / (root.coarse ? 3 : 6)) * Math.PI * 2 + 0.4
            readonly property real r0: 30 + (index % 3) * 3
            readonly property real r1: 44 + (index % 4) * 5
            // Flattened vertically, as in the prototype: they follow the
            // viewing tilt rather than radiating flat.
            readonly property real x0: 50 + Math.cos(a) * r0
            readonly property real y0: 50 + Math.sin(a) * r0 * 0.86
            readonly property real x1: 50 + Math.cos(a) * r1
            readonly property real y1: 50 + Math.sin(a) * r1 * 0.86
            readonly property real bend: (index % 2) ? 9 : -9

            opacity: 0.42
            SequentialAnimation on opacity {
                running: !root.paused
                loops: Animation.Infinite
                PauseAnimation { duration: fil.index * 400 }
                // 1600ms when the link is quiet, 320ms when it is saturated.
                NumberAnimation { to: 0.75
                                  duration: 1600 - 1280 * Math.max(0, Math.min(1, root.traffic))
                                  easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.30
                                  duration: 1600 - 1280 * Math.max(0, Math.min(1, root.traffic))
                                  easing.type: Easing.InOutSine }
            }

            ShapePath {
                strokeColor: Theme.accent
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathQuad {
                    x: fil.x1 * root.unit
                    y: fil.y1 * root.unit
                    controlX: ((fil.x0 + fil.x1) / 2 + fil.bend) * root.unit
                    controlY: ((fil.y0 + fil.y1) / 2 - fil.bend) * root.unit
                }
                startX: fil.x0 * root.unit
                startY: fil.y0 * root.unit
            }

            // Node at the tip, as in the prototype.
            Rectangle {
                x: fil.x1 * root.unit - 1.5
                y: fil.y1 * root.unit - 1.5
                width: 3; height: 3
                color: Theme.accent
            }
        }
    }

    // ── latitudes ──────────────────────────────────────────────
    // Drawn under the meridians: they are the body, the meridians the cage.
    Repeater {
        model: root.latitudes

        Shape {
            id: lat
            anchors.fill: parent
            layer.enabled: layersSafe
            layer.smooth: true

            // -1 at the south pole, +1 at the north.
            readonly property real k: (index - (root.latitudes - 1) / 2)
                                      / ((root.latitudes - 1) / 2)
            // Rings shrink towards the poles exactly as sin(latitude) does.
            readonly property real shrink: Math.sqrt(Math.max(0.06, 1 - k * k))
            readonly property bool equator: Math.abs(k) < 0.01

            opacity: equator ? 0.55 : 0.3

            ShapePath {
                strokeColor: Theme.accentBright
                strokeWidth: lat.equator ? 1.3 : 1
                fillColor: "transparent"
                PathPolyline {
                    // Seen from slightly above: flattened, and offset up the axis.
                    /* A latitude at angle f sits at y = -R sin f with radius
                       R cos f. Both axes therefore scale by `shrink`; the
                       earlier version flattened every ring by the same amount,
                       so the polar rings stayed full height and hung outside
                       the silhouette. */
                    path: {
                        var pts = root.ring(0.30 * lat.shrink, 0)
                        var out = []
                        var dy = -lat.k * 31 * root.unit
                        for (var i = 0; i < pts.length; i++) {
                            out.push(Qt.point(root.cx + (pts[i].x - root.cx) * lat.shrink,
                                              pts[i].y + dy))
                        }
                        return out
                    }
                }
            }
        }
    }

    // ── meridians ──────────────────────────────────────────────
    Repeater {
        model: root.meridians

        Shape {
            id: meridian
            anchors.fill: parent
            layer.enabled: layersSafe
            layer.smooth: true

            readonly property real offset: (index / root.meridians) * Math.PI
            readonly property real squash: Math.cos(root.phase + offset)
            readonly property bool spine: (index % 4) === 0

            transform: Scale {
                origin.x: root.cx
                xScale: meridian.squash
            }

            /* Edge-on planes fade rather than snapping to a hairline, which is
               what sells the rotation as depth instead of as flicker. */
            opacity: (spine ? 0.85 : 0.4) * (0.25 + 0.75 * Math.abs(squash))

            ShapePath {
                strokeColor: root.alert ? Theme.alert : Theme.accent
                strokeWidth: meridian.spine ? 1.5 : 1
                fillColor: "transparent"
                PathPolyline { path: root.meridianPath }
            }
        }
    }

    // ── nucleus ────────────────────────────────────────────────
    /* A glow, not a ball. Both earlier versions drew something opaque enough to
       read as a solid green marble sitting in front of the wireframe. */
    Shape {
        id: nucleus
        anchors.fill: parent
        layer.enabled: layersSafe
        layer.smooth: true
        /* Swells with memory in use: 11 units idle, 18 when full. Not
           readonly — a Behavior cannot animate a readonly property, and QML
           only says so at load time. */
        property real r: root.unit * (11 + 7 * Math.max(0, Math.min(1, root.memory)))
        Behavior on r { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.cx;  centerY: root.cy
                focalX: centerX;   focalY: centerY
                centerRadius: nucleus.r
                GradientStop { position: 0.0;  color: Theme.pale(0.55) }
                GradientStop { position: 0.28; color: Theme.tint(0.22) }
                GradientStop { position: 0.62; color: Theme.tint(0.05) }
                GradientStop { position: 1.0;  color: "transparent" }
            }
            PathAngleArc {
                centerX: root.cx;      centerY: root.cy
                radiusX: nucleus.r;    radiusY: nucleus.r
                startAngle: 0;         sweepAngle: 360
            }
        }
        SequentialAnimation on opacity {
            running: !root.paused
            loops: Animation.Infinite
            NumberAnimation { to: 0.5; duration: 1300; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: 1300; easing.type: Easing.InOutSine }
        }
    }

    /* Callouts, as in the approved design — but reading the machine.
       The design's versions said "MEMBRANE STABLE", "Δ 0.0041" and
       "97.2% BIND": invented numbers wrapped in technical-looking labels.
       Same frame, same typography, four facts. */
    component Callout: Column {
        property string code: ""
        property string value: ""
        property bool alignRight: false
        spacing: 2

        Row {
            spacing: 6
            layoutDirection: parent.alignRight ? Qt.RightToLeft : Qt.LeftToRight
            Rectangle {
                width: 5; height: 5
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.accent
                opacity: 0.7
            }
            Text {
                text: parent.parent.code
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: 7
                font.letterSpacing: Theme.trackWide
                opacity: 0.75
            }
        }
        Text {
            anchors.right: parent.alignRight ? parent.right : undefined
            text: parent.value
            color: root.alert ? Theme.alert : Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
        }
    }

    /* Pushed clear of the reticle in proportion to the mass, not by a fixed
       14px: on a 1280x800 panel the sphere is smaller, and the labels landed
       on top of the degree ticks with a tick mark reading as a minus sign in
       front of the uptime. */
    readonly property real calloutGap: -width * 0.17

    Callout {
        anchors { left: parent.left; leftMargin: root.calloutGap
                  top: parent.top; topMargin: root.height * 0.17 }
        code: "SYM_KERNEL"
        value: System.kernel
    }
    Callout {
        anchors { right: parent.right; rightMargin: root.calloutGap
                  top: parent.top; topMargin: root.height * 0.30 }
        alignRight: true
        code: "SYM_UPTIME"
        value: Math.floor(System.uptime / 3600) + "h "
             + Math.floor((System.uptime % 3600) / 60) + "m"
    }
    Callout {
        anchors { right: parent.right; rightMargin: root.calloutGap
                  bottom: parent.bottom; bottomMargin: root.height * 0.26 }
        alignRight: true
        code: "SYM_LOAD"
        value: System.load.toFixed(2) + " / 1 min"
    }
    Callout {
        anchors { left: parent.left; leftMargin: root.calloutGap
                  bottom: parent.bottom; bottomMargin: root.height * 0.19 }
        code: "SYM_TASKS"
        value: System.taskCount + " tasks"
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 6
        // No invented frame rate: the old label printed "60 FPS" regardless.
        /* Named, not decorative. If the shape carries data the caption has to
           say which, or it is decoration that merely looks informative. */
        text: root.paused
              ? "SYMBIONT MASS  //  PAUSED"
              : "SYMBIONT MASS  //  SPIN " + Math.round(root.load * 100) + "% CPU"
                + "   MASS " + Math.round(root.memory * 100) + "% MEM"
                + (root.traffic > 0.01 ? "   FLUX ACTIVE" : "")
        color: Theme.textMuted
        font.family: Theme.mono
        font.pixelSize: Theme.size2xs
        font.letterSpacing: Theme.trackWider
    }
}
