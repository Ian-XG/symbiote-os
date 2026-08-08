import QtQuick
import QtQuick.Shapes
import Symbiote

/* The desktop glyphs, drawn rather than taken from an icon set.
 *
 * The first QML port lost most of their detail — the folder had no manifest
 * lines, the globe was a bare circle with no meridian, the dial had no inner
 * ring, the bin had no slats. Generic outlines read as "some app" and looked
 * borrowed next to the hologram; this is the same vocabulary as the rest of
 * the HUD: thin strokes, angular geometry, concentric rings. */
Shape {
    id: root

    property string glyph: ""
    property color stroke: Theme.textBody
    property real thin: 1.0
    property real bold: 1.3

    // Everything is authored in a 30x30 box and scaled from there.
    readonly property real u: Math.min(width, height) / 30

    layer.enabled: layersSafe
    layer.smooth: true

    function p(x, y) { return Qt.point(x * u, y * u) }

    function circle(cxv, cyv, r, steps) {
        var out = []
        for (var i = 0; i <= (steps || 40); i++) {
            var a = (i / (steps || 40)) * Math.PI * 2
            out.push(p(cxv + Math.cos(a) * r, cyv + Math.sin(a) * r))
        }
        return out
    }

    /* An arc of `r` about a point, drawn upward — the shape of a signal fan.
       Angles run 225..315 with y pointing down, which is the top half. */
    function fan(cxv, cyv, r) {
        var out = []
        for (var i = 0; i <= 14; i++) {
            var a = (225 + (i / 14) * 90) * Math.PI / 180
            out.push(p(cxv + Math.cos(a) * r, cyv + Math.sin(a) * r))
        }
        return out
    }

    function ellipse(cxv, cyv, rx, ry, steps) {
        var out = []
        for (var i = 0; i <= (steps || 40); i++) {
            var a = (i / (steps || 40)) * Math.PI * 2
            out.push(p(cxv + Math.cos(a) * rx, cyv + Math.sin(a) * ry))
        }
        return out
    }

    // ── main outline ───────────────────────────────────────────
    ShapePath {
        strokeColor: root.stroke
        strokeWidth: root.bold
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.MiterJoin

        PathPolyline {
            path: {
                switch (root.glyph) {
                case "files":
                    // Angular folder, not a rounded document.
                    return [root.p(3, 25), root.p(3, 7), root.p(11, 7),
                            root.p(13.5, 10.5), root.p(27, 10.5), root.p(27, 25),
                            root.p(3, 25)]
                case "browser":
                    /* A globe wrapped by a tail. The bare circle-with-meridian
                       was "a browser", not "Firefox" — it read as any browser
                       at all, which is what made it unrecognisable. */
                    return root.circle(15, 15, 10.5)
                case "settings":
                    return root.circle(15, 15, 10.5)
                case "trash":
                    return [root.p(7.5, 9.5), root.p(9.5, 26),
                            root.p(20.5, 26), root.p(22.5, 9.5)]
                case "terminal":
                    // Window frame; the prompt is drawn in the detail pass.
                    return [root.p(3, 6), root.p(27, 6), root.p(27, 24),
                            root.p(3, 24), root.p(3, 6)]
                case "radar":
                    return root.circle(15, 15, 12)
                case "shield":
                    return [root.p(15, 3), root.p(25, 7), root.p(25, 15),
                            root.p(15, 27), root.p(5, 15), root.p(5, 7),
                            root.p(15, 3)]
                case "bug":
                    return root.ellipse(15, 17, 6.5, 7)
                case "wifi":
                    return root.fan(15, 23, 13)
                case "app":
                    // A plain window: shared by everything discovered from a
                    // desktop entry, which has no glyph of its own here.
                    return [root.p(4, 6), root.p(26, 6), root.p(26, 24),
                            root.p(4, 24), root.p(4, 6)]
                case "power":
                    return root.circle(15, 16, 10)
                case "install":
                    // A disk with an arrow going into it.
                    return [root.p(4, 19), root.p(4, 25), root.p(26, 25), root.p(26, 19)]
                case "agent":
                    // A core with satellites: something that reasons and acts.
                    return root.circle(15, 15, 5.5)
                case "volume":
                    // Speaker cone.
                    return [root.p(4, 12), root.p(9, 12), root.p(15, 6),
                            root.p(15, 24), root.p(9, 18), root.p(4, 18),
                            root.p(4, 12)]
                case "bluetooth":
                    // The runic B: two triangles sharing a vertical stem.
                    return [root.p(10, 9), root.p(20, 20), root.p(15, 24.5),
                            root.p(15, 5.5), root.p(20, 10), root.p(10, 21)]
                }
                return []
            }
        }
    }

    // ── inner detail ───────────────────────────────────────────
    ShapePath {
        strokeColor: root.stroke
        strokeWidth: root.thin
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap

        PathMultiline {
            paths: {
                switch (root.glyph) {
                case "files":
                    // Divider plus a short manifest of records.
                    return [[root.p(3, 15), root.p(27, 15)],
                            [root.p(7, 19), root.p(14, 19)],
                            [root.p(7, 22), root.p(11, 22)],
                            [root.p(23, 18.5), root.p(26, 18.5)],
                            [root.p(23, 18.5), root.p(23, 21.5)],
                            [root.p(26, 18.5), root.p(26, 21.5)],
                            [root.p(23, 21.5), root.p(26, 21.5)]]
                case "settings": {
                    // Radial ticks, like the gauges.
                    var out = []
                    for (var i = 0; i < 8; i++) {
                        var a = (i / 8) * Math.PI * 2
                        out.push([root.p(15 + Math.cos(a) * 10.5, 15 + Math.sin(a) * 10.5),
                                  root.p(15 + Math.cos(a) * 13.5, 15 + Math.sin(a) * 13.5)])
                    }
                    return out
                }
                case "trash":
                    // Lid, handle, and slats.
                    return [[root.p(4, 9.5), root.p(26, 9.5)],
                            [root.p(12, 9.5), root.p(12, 6), root.p(18, 6), root.p(18, 9.5)],
                            [root.p(12.5, 13.5), root.p(12.5, 22)],
                            [root.p(15, 13.5), root.p(15, 22)],
                            [root.p(17.5, 13.5), root.p(17.5, 22)]]
                case "terminal":
                    // A chevron prompt and its cursor.
                    return [[root.p(7, 11), root.p(11, 15), root.p(7, 19)],
                            [root.p(13, 19), root.p(20, 19)]]
                case "radar": {
                    /* A closed sweep wedge, not two lines from the centre —
                       a long hand and a short one is a clock face. Plus a
                       return blip off the axis. */
                    var out = [[root.p(15, 15), root.p(23.5, 6.5)],
                               [root.p(15, 15), root.p(26.4, 12)],
                               [root.p(15, 3), root.p(15, 6)],
                               [root.p(15, 24), root.p(15, 27)],
                               [root.p(3, 15), root.p(6, 15)],
                               [root.p(24, 15), root.p(27, 15)],
                               [root.p(19.5, 19), root.p(21, 20.5)]]
                    // Arc closing the wedge.
                    var arc = []
                    for (var j = 0; j <= 8; j++) {
                        var aa = -Math.PI / 4 + (j / 8) * (Math.PI / 4 - Math.PI / 12)
                        arc.push(root.p(15 + Math.cos(aa) * 12, 15 + Math.sin(aa) * 12))
                    }
                    out.push(arc)
                    return out
                }
                case "bug":
                    /* Legs bend, and the body has a seam and a head. Straight
                       spokes radiating from a blob read as a sun, which is what
                       the first pass drew. */
                    return [[root.p(8.8, 12), root.p(5.5, 10.5), root.p(4, 7.5)],
                            [root.p(8.5, 16), root.p(4.5, 16)],
                            [root.p(8.8, 20), root.p(5.5, 21.5), root.p(4, 24.5)],
                            [root.p(21.2, 12), root.p(24.5, 10.5), root.p(26, 7.5)],
                            [root.p(21.5, 16), root.p(25.5, 16)],
                            [root.p(21.2, 20), root.p(24.5, 21.5), root.p(26, 24.5)],
                            [root.p(15, 8.5), root.p(15, 24)],
                            [root.p(11.5, 6.5), root.p(9.5, 3.5)],
                            [root.p(18.5, 6.5), root.p(20.5, 3.5)]]
                case "shield":
                    return [[root.p(15, 10), root.p(15, 19)],
                            [root.p(11, 14), root.p(19, 14)]]
                case "wifi":
                    return [root.fan(15, 23, 8.5), root.fan(15, 23, 4),
                            [root.p(14.2, 22.6), root.p(15.8, 22.6),
                             root.p(15.8, 24.2), root.p(14.2, 24.2),
                             root.p(14.2, 22.6)]]
                case "app":
                    return [[root.p(4, 11), root.p(26, 11)],
                            [root.p(8, 8.5), root.p(9.5, 8.5)],
                            [root.p(11.5, 8.5), root.p(13, 8.5)]]
                case "power":
                    // The standby mark: a broken ring with a stem.
                    return [[root.p(15, 4), root.p(15, 14)]]
                case "agent": {
                    var out = []
                    for (var q = 0; q < 3; q++) {
                        var aa = (q / 3) * Math.PI * 2 - Math.PI / 2
                        out.push([root.p(15 + Math.cos(aa) * 6.5, 15 + Math.sin(aa) * 6.5),
                                  root.p(15 + Math.cos(aa) * 11, 15 + Math.sin(aa) * 11)])
                        // The satellite itself.
                        var sx = 15 + Math.cos(aa) * 12.5
                        var sy = 15 + Math.sin(aa) * 12.5
                        out.push([root.p(sx - 1.6, sy - 1.6), root.p(sx + 1.6, sy - 1.6),
                                  root.p(sx + 1.6, sy + 1.6), root.p(sx - 1.6, sy + 1.6),
                                  root.p(sx - 1.6, sy - 1.6)])
                    }
                    return out
                }
                case "volume":
                    // Two waves; the mute state is drawn by the caller's colour.
                    return [root.fan(15, 15, 6.5), root.fan(15, 15, 10)]
                case "install":
                    return [[root.p(15, 3), root.p(15, 16)],
                            [root.p(10, 11), root.p(15, 16), root.p(20, 11)],
                            [root.p(8, 22), root.p(11, 22)]]
                case "pulse":
                    // An oscilloscope beat: the monitor.
                    return [[root.p(3, 15), root.p(9, 15), root.p(12, 7),
                             root.p(16, 23), root.p(19, 15), root.p(27, 15)]]
                }
                return []
            }
        }
    }

    // ── curved detail (the globe's meridian and latitudes) ─────
    ShapePath {
        strokeColor: root.stroke
        strokeWidth: root.thin
        fillColor: "transparent"
        PathPolyline {
            path: root.glyph === "browser" ? root.ellipse(15, 15, 4.4, 10.5) : []
        }
    }
    ShapePath {
        strokeColor: root.stroke
        strokeWidth: root.thin
        fillColor: "transparent"
        PathMultiline {
            paths: root.glyph !== "browser" ? [] : [
                [root.p(5.4, 12), root.p(24.6, 12)],
                [root.p(5.4, 18), root.p(24.6, 18)]
            ]
        }
    }

    /* The tail: an arc sweeping up and over the globe, closing to a point.
       That silhouette is what makes the mark read as Firefox at 16px. */
    ShapePath {
        strokeColor: root.stroke
        strokeWidth: root.bold
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathPolyline {
            path: {
                if (root.glyph !== "browser")
                    return []
                var out = []
                // Sweeps from the lower left, around the top, to a tip at the
                // upper right — the flame curling over the globe.
                for (var i = 0; i <= 26; i++) {
                    var t = i / 26
                    var a = Math.PI * (0.88 - 1.28 * t)
                    var r = 13.6 - 4.0 * t * t
                    out.push(root.p(15 + Math.cos(a) * r, 15 - Math.sin(a) * r * 0.94))
                }
                return out
            }
        }
    }

    // ── inner ring (the dial's core) ───────────────────────────
    ShapePath {
        strokeColor: root.stroke
        strokeWidth: root.thin
        fillColor: "transparent"
        PathPolyline {
            path: root.glyph === "settings" ? root.circle(15, 15, 4.5, 28)
                : root.glyph === "radar"    ? root.circle(15, 15, 7.5, 28)
                : []
        }
    }
}
