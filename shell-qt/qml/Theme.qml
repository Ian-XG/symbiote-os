pragma Singleton
import QtQuick

/* The design tokens, one source for the whole shell.
   Mirrors tokens/colors.css and the .symbiote-hud scope from the design
   project, so the QML shell and the design preview stay the same design. */
QtObject {
    id: theme

    // ── surfaces ───────────────────────────────────────────────
    readonly property color bgVoid:       "#080808"
    readonly property color bgRaised:     "#0d120f"
    readonly property color panel:        blue ? Qt.rgba(0, 0.05, 0.08, 0.38)
                                               : Qt.rgba(0, 0.07, 0.04, 0.38)
    readonly property color panelStrong:  blue ? Qt.rgba(0, 0.07, 0.12, 0.58)
                                               : Qt.rgba(0, 0.10, 0.06, 0.58)
    readonly property color line:         "#1c1f1c"
    readonly property color gridLine:     blue ? Qt.rgba(0, 0.85, 1, 0.05)
                                               : Qt.rgba(0, 1, 0.53, 0.05)
    readonly property color wash:         blue ? Qt.rgba(0, 0.85, 1, 0.04)
                                               : Qt.rgba(0, 1, 0.53, 0.04)
    readonly property color hairline:     blue ? Qt.rgba(0, 0.85, 1, 0.14)
                                               : Qt.rgba(0, 1, 0.53, 0.14)

    // ── signal ─────────────────────────────────────────────────
    /* Two accents. The brief specifies toxin green; signal blue is the design
       system's own palette, kept switchable rather than forked. Every colour
       below derives from this, so one property recolours the whole shell. */
    property string accentMode: "toxin"          // "toxin" | "signal"

    // Remembered between runs, like everything else in Settings.
    property bool loaded: false
    Component.onCompleted: {
        accentMode = Store.value("appearance/accentMode", accentMode)
        loaded = true
    }
    onAccentModeChanged: if (loaded) Store.setValue("appearance/accentMode", accentMode)
    readonly property bool blue: accentMode === "signal"

    readonly property color accent:       blue ? "#00d9ff" : "#00ff88"
    readonly property color accentBright: blue ? "#2979ff" : "#1aff00"
    readonly property color accentDim:    blue ? "#0a2f4d" : "#04412a"
    readonly property color alert:        "#ff1744"    // critical stays red in both

    // ── text ───────────────────────────────────────────────────
    readonly property color textBody:     "#c8c8c8"
    readonly property color textMuted:    "#6b6f6b"

    // ── type ───────────────────────────────────────────────────
    readonly property string mono: "JetBrains Mono"
    readonly property int size2xs: 8
    readonly property int sizeXs:  9
    readonly property int sizeSm:  10
    readonly property int sizeBase: 11
    readonly property int sizeMd:  13
    readonly property int sizeLg:  16

    readonly property real trackWide:   1.2
    readonly property real trackWider:  2.2
    readonly property real trackWidest: 3.2

    // ── spacing ────────────────────────────────────────────────
    readonly property int space2: 4
    readonly property int space3: 8
    readonly property int space4: 12
    readonly property int space5: 16
    readonly property int space6: 20
    readonly property int space7: 28
    readonly property int bracket: 12

    /* ── control metrics ────────────────────────────────────────
       Every control in Settings was sized by hand where it was written: 26 high
       here, 28 there, 20 for a toggle. At a glance the column of controls
       looked ragged, and it was — nothing shared a height. */
    readonly property int ctrlHeight: 28
    readonly property int ctrlHeightSm: 22
    readonly property int rowHeight: 56

    /* ── surfaces ───────────────────────────────────────────────
       A window needs a floor you can read text on. The panel tint alone is
       58% alpha, which is right for a HUD card lying on the desktop and wrong
       for a dialogue — the hologram used to show through the labels. */
    readonly property color surface:      Qt.rgba(0.043, 0.055, 0.047, 0.96)
    readonly property color surfaceRaise: blue ? Qt.rgba(0.02, 0.06, 0.08, 1.0)
                                               : Qt.rgba(0.02, 0.07, 0.05, 1.0)
    readonly property color surfaceSunk:  Qt.rgba(0, 0, 0, 0.35)

    // ── motion ─────────────────────────────────────────────────
    /* Four durations, not a number picked per animation.
     *
     * The shell had two, and everything that was neither a hover nor a panel
     * fade guessed. Motion that does not share a scale reads as several
     * interfaces stapled together: a tab that takes 400ms next to a toggle
     * that takes 90 looks broken rather than deliberate. */
    readonly property int durInstant: 90     // state on a control under the cursor
    readonly property int durFast: 120       // hover, focus, small state
    readonly property int durMed: 280        // a panel arriving or leaving
    readonly property int durSlow: 420       // something moving across the screen
    readonly property int durPulse: 3200

    /* One easing curve for anything entering, one for anything leaving. Things
       arrive quickly and settle; things go away without ceremony. */
    readonly property int easeOut: Easing.OutCubic
    readonly property int easeIn: Easing.InCubic
    readonly property int easeStandard: Easing.InOutCubic

    // How far a panel travels while fading in. Enough to read as a direction.
    readonly property int slide: 10

    /* The accent at an arbitrary alpha. Hover tints, glows and washes were all
       written as literal rgba(0, 1, 0.53, ...) — the toxin green spelled out by
       hand — so switching to signal blue recoloured the strokes and left every
       fill and glow green, most visibly the hologram's nucleus. */
    function tint(a) { return Qt.rgba(accent.r, accent.g, accent.b, a) }
    /* A paler version of the accent, for the hot core of a glow. */
    function pale(a) {
        return Qt.rgba(accent.r + (1 - accent.r) * 0.6,
                       accent.g + (1 - accent.g) * 0.6,
                       accent.b + (1 - accent.b) * 0.6, a)
    }

    /* Severity is used in a dozen places; keeping the mapping here means a new
       state cannot drift between panels. */
    function stateColor(state) {
        switch (state) {
        case "ok":        return accent
        case "attention": return accentBright
        case "critical":  return alert
        case "idle":      return textMuted
        default:          return textMuted
        }
    }
}
