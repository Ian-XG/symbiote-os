pragma Singleton
import QtQuick

/* User preferences that affect how the shell looks and behaves.
 *
 * Kept apart from Theme: Theme is the design's vocabulary, this is what the
 * operator has chosen. Everything here drives something real — the toggles the
 * Electron build shipped with that only changed a label are not repeated. */
QtObject {
    id: prefs

    /* Loaded once at startup, then written through on every change.
     *
     * `loaded` guards the write-back: without it, assigning the stored values
     * during startup would immediately write each one straight back, and any
     * default that failed to load would overwrite the saved value with the
     * default. */
    property bool loaded: false

    Component.onCompleted: {
        scanline   = Store.value("appearance/scanline",  scanline)
        grid       = Store.value("appearance/grid",      grid)
        vignette   = Store.value("appearance/vignette",  vignette)
        spin       = Store.value("appearance/spin",      spin)
        scaleMode  = Store.value("appearance/scaleMode", scaleMode)
        holoDetail = Store.value("appearance/holoDetail", holoDetail)
        clock24    = Store.value("system/clock24",       clock24)
        seconds    = Store.value("system/seconds",       seconds)
        motion     = Store.value("appearance/motion",    motion)

        taskbarEdge = Store.value("layout/taskbarEdge", taskbarEdge)
        taskbarSize = Store.value("layout/taskbarSize", taskbarSize)
        taskbarLabels = Store.value("layout/taskbarLabels", taskbarLabels)

        var d = Store.value("layout/desktopIds", "")
        if (d) desktopIds = String(d).split(",")
        var t = Store.value("layout/taskbarIds", "")
        if (t) taskbarIds = String(t).split(",")

        loaded = true
    }

    onScanlineChanged:   if (loaded) Store.setValue("appearance/scanline", scanline)
    onGridChanged:       if (loaded) Store.setValue("appearance/grid", grid)
    onVignetteChanged:   if (loaded) Store.setValue("appearance/vignette", vignette)
    onSpinChanged:       if (loaded) Store.setValue("appearance/spin", spin)
    onScaleModeChanged:  if (loaded) Store.setValue("appearance/scaleMode", scaleMode)
    onHoloDetailChanged: if (loaded) Store.setValue("appearance/holoDetail", holoDetail)
    onClock24Changed:    if (loaded) Store.setValue("system/clock24", clock24)
    onSecondsChanged:    if (loaded) Store.setValue("system/seconds", seconds)
    onMotionChanged:     if (loaded) Store.setValue("appearance/motion", motion)
    onDesktopIdsChanged: if (loaded) Store.setValue("layout/desktopIds", desktopIds.join(","))
    onTaskbarIdsChanged: if (loaded) Store.setValue("layout/taskbarIds", taskbarIds.join(","))
    onTaskbarEdgeChanged:   if (loaded) Store.setValue("layout/taskbarEdge", taskbarEdge)
    onTaskbarSizeChanged:   if (loaded) Store.setValue("layout/taskbarSize", taskbarSize)
    onTaskbarLabelsChanged: if (loaded) Store.setValue("layout/taskbarLabels", taskbarLabels)

    // Appearance
    property bool scanline: true
    property bool grid: true
    property bool vignette: true

    /* Permission to animate the hologram, not a command to. It still stops
       when a window covers it or the machine is on battery — the process panel
       measured that animation costing a full core under Electron. */
    property bool spin: true

    /* How much of the mass to draw: "auto" | "full" | "reduced" | "off".
       Auto means full with a GPU and reduced without, which is right for the
       machines measured — but the hologram is two thirds of the shell's CPU
       under software rasterisation, and unseen hardware may need it lower
       still. Exposed for the same reason as scaleMode: a wrong guess should
       cost a click, not a rebuild. */
    property string holoDetail: "auto"

    /* "auto" defers to the density heuristic in main.cpp; a number overrides
       it. Exposed because a wrong guess on unseen hardware would otherwise
       mean rebuilding the image to read the screen. */
    property string scaleMode: "auto"

    /* Whether panels animate at all: "full" | "reduced" | "off".
     *
     * Reduced keeps the fades and drops the movement, which is what a
     * vestibular sensitivity needs and also what a machine rasterising every
     * frame in software wants. Off is instant. This is a real switch, not a
     * politeness: the transitions are the most expensive thing the shell draws
     * after the hologram. */
    property string motion: "full"

    readonly property bool motionOn: motion !== "off"
    readonly property bool motionMoves: motion === "full"
    /** A duration, honouring the motion setting. Use everywhere instead of Theme.dur*. */
    function dur(ms) { return motion === "off" ? 0 : (motion === "reduced" ? Math.round(ms * 0.6) : ms) }

    /* ── the taskbar ────────────────────────────────────────────
     *
     * Which edge it lives on: "bottom" | "top" | "left" | "right".
     * Bottom by default, because that is where a taskbar has been on every
     * system most people have used, and a default that surprises is a bad
     * default however defensible. The other three exist because on a 16:9
     * laptop panel vertical pixels are the scarce ones, and a bar down the
     * side gives back 72 of them. */
    property string taskbarEdge: "bottom"

    readonly property bool taskbarVertical: taskbarEdge === "left" || taskbarEdge === "right"

    /** "compact" | "normal" | "large" — how thick the bar is. */
    property string taskbarSize: "normal"

    /* The band the icons live in. Kept apart from the label column, because
       the buttons are sized from this: sized from the whole bar instead, a
       vertical bar with labels turned on grew 97px icons with 50px of air
       between them.

       A vertical bar is deliberately slimmer than a horizontal one. Down the
       side it is a dock, not a taskbar: a strip of icons, closer to what a
       phone or a tiling desktop puts there than to the wide Windows bar. A
       horizontal bar carries the clock and the tray inline and needs the
       height; a vertical one stacks them and does not. */
    readonly property int taskbarBase: taskbarVertical
        ? (taskbarSize === "compact" ? 44 : taskbarSize === "large" ? 60 : 52)
        : (taskbarSize === "compact" ? 54 : taskbarSize === "large" ? 88 : 72)

    /* Extra width a vertical bar takes to write app and window names in.
       Narrower than before, and only when asked for: the labels are an option
       on the dock, not the reason it is as wide as it is. */
    readonly property int taskbarLabelWidth: (taskbarVertical && taskbarLabels) ? 76 : 0

    readonly property int taskbarThickness: taskbarBase + taskbarLabelWidth

    /* Window titles beside the icons, rather than icons alone. Off by default
       on the dock: a strip of icons is the point of putting the bar on its
       side, and the names widen it back towards the horizontal bar it was
       meant to be slimmer than. */
    property bool taskbarLabels: false

    /* The one catalogue. It used to be written out three times — desktop,
       taskbar, launcher — which is why nothing could be pinned or removed:
       there was no single list to edit.
     *
     * `kind` and `category` are what the launcher sorts on, and they mean the
     * same here as they do for a discovered entry: an app is something you
     * use, a tool is something you point at a target. The categories are
     * Kali's, so that a tool found here and a tool found on PATH land in the
     * same drawer. */
    readonly property var apps: [
        /* No iconName. The file manager happens to be Nautilus, but what the
           operator is clicking is this desktop's Files — a system concept, so
           it stays in the line vocabulary like Settings and Trash.
           It carried iconName: "org.gnome.Nautilus" and appeared to be drawn,
           which was an accident: Qt could not decode the SVG and fell through
           to the glyph. Installing the SVG plugin fixed the decoding and the
           blue GNOME icon appeared in the dock, looking like a regression
           because it was one. */
        { id: "files",    glyph: "files",    title: "FILE MANAGER", short: "FILES",    code: "FS_00",  kind: "app",  category: "" },
        { id: "terminal", glyph: "terminal", title: "TERMINAL",     short: "TERMINAL", code: "TTY_04", kind: "app",  category: "" },
        { id: "browser",  glyph: "browser",  title: "FIREFOX",      short: "FIREFOX",  code: "NET_01", kind: "app",  category: "", iconName: "firefox-esr" },
        { id: "settings", glyph: "settings", title: "SETTINGS",     short: "SETTINGS", code: "SYS_02", kind: "app",  category: "" },
        { id: "trash",    glyph: "trash",    title: "TRASH",        short: "TRASH",    code: "BIN_03", kind: "app",  category: "" },
        { id: "monitor",  glyph: "pulse",    title: "MONITOR",      short: "MONITOR",  code: "DEF_21", kind: "app",  category: "" },
        { id: "install",  glyph: "install",  title: "INSTALL SYSTEM", short: "INSTALL", code: "SYS_09", kind: "app", category: "" },
        { id: "nmap",     glyph: "radar",    title: "NETWORK SCAN", short: "SCAN",     code: "REC_10", kind: "tool", category: "RECON" },
        { id: "vuln",     glyph: "bug",      title: "VULN SCANNER", short: "VULN",     code: "REC_11", kind: "tool", category: "VULNERABILITY" },
        { id: "firewall", glyph: "shield",   title: "FIREWALL",     short: "FIREWALL", code: "DEF_20", kind: "tool", category: "DEFENSE" },
        { id: "pentai",   glyph: "agent",    title: "PENTAI",       short: "PENTAI",   code: "AI_30",  kind: "tool", category: "ASSISTANT" }
    ]

    /* Resolved once. Entries without an iconName, or whose icon the theme does
       not have, come back empty and fall through to the drawn glyph. */
    readonly property var iconPaths: {
        var out = {}
        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]
            out[a.id] = a.iconName ? Apps.findIcon(a.iconName) : ""
        }
        return out
    }

    function appById(id) {
        for (var i = 0; i < apps.length; i++)
            if (apps[i].id === id) return apps[i]
        return null
    }

    // What the operator has chosen to keep where. Both are editable.
    property var desktopIds: ["files", "browser", "settings", "trash"]
    property var taskbarIds: ["files", "terminal", "browser", "nmap",
                              "vuln", "firewall", "monitor"]

    function toggleIn(listName, id) {
        var list = (listName === "desktop" ? desktopIds : taskbarIds).slice()
        var i = list.indexOf(id)
        if (i === -1) list.push(id); else list.splice(i, 1)
        if (listName === "desktop") desktopIds = list; else taskbarIds = list
    }

    // System
    property bool clock24: true
    property bool seconds: true
}
