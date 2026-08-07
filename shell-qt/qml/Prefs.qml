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
    onDesktopIdsChanged: if (loaded) Store.setValue("layout/desktopIds", desktopIds.join(","))
    onTaskbarIdsChanged: if (loaded) Store.setValue("layout/taskbarIds", taskbarIds.join(","))

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

    /* The one catalogue. It used to be written out three times — desktop,
       taskbar, launcher — which is why nothing could be pinned or removed:
       there was no single list to edit. */
    readonly property var apps: [
        { id: "files",    glyph: "files",    title: "FILE MANAGER", short: "FILES",    code: "FS_00",  iconName: "org.gnome.Nautilus" },
        { id: "terminal", glyph: "terminal", title: "TERMINAL",     short: "TERMINAL", code: "TTY_04" },
        { id: "browser",  glyph: "browser",  title: "FIREFOX",      short: "FIREFOX",  code: "NET_01", iconName: "firefox-esr" },
        { id: "settings", glyph: "settings", title: "SETTINGS",     short: "SETTINGS", code: "SYS_02" },
        { id: "trash",    glyph: "trash",    title: "TRASH",        short: "TRASH",    code: "BIN_03" },
        { id: "nmap",     glyph: "radar",    title: "NETWORK SCAN", short: "SCAN",     code: "REC_10" },
        { id: "vuln",     glyph: "bug",      title: "VULN SCANNER", short: "VULN",     code: "REC_11" },
        { id: "firewall", glyph: "shield",   title: "FIREWALL",     short: "FIREWALL", code: "DEF_20" },
        { id: "monitor",  glyph: "pulse",    title: "MONITOR",      short: "MONITOR",  code: "DEF_21" }
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
