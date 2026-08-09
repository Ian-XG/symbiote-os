import QtQuick
import Symbiote

/* The launcher: everything on the machine, in two drawers.
 *
 * It used to be one grid with four ad-hoc groups — SYSTEM, RECON, DEFENSE,
 * INSTALLED — derived from which drawn glyph an entry happened to have. That
 * held for the nine curated tools it was written for. It does not hold for a
 * few hundred desktop entries plus every command-line tool in the image: a text
 * editor and a password cracker landed in the same bucket, and INSTALLED became
 * a wall of identical tiles you scrolled past rather than searched.
 *
 * So: APPS and TOOLS are separate, and TOOLS is divided the way Kali divides
 * its menu, because that vocabulary is the one anyone doing this work already
 * has. You look for "something that sniffs traffic", not for a program whose
 * name you would have to know in advance.
 *
 * Search still crosses both drawers. Knowing the name is the one case where
 * categories are in the way.
 */
Item {
    id: root
    signal launched(string id, string exec)
    /** A command-line tool: no window of its own, so the shell opens one. */
    signal launchedTool(string id, string title, string probe)
    signal dismissed()

    property string query: ""

    /* Which corner the sheet grows from. The launcher button moves with the
       taskbar, and a panel that opens at the bottom left while its button is
       at the top right is a panel that came from nowhere. */
    property string edge: "bottom"
    property real inset: 0

    /** "apps" | "tools" */
    property string mode: "apps"
    property string category: ""

    // Everything, in one list, with the two axes already on each entry.
    readonly property var catalog: Prefs.apps.concat(Apps.discovered).concat(Apps.tools)

    function matches(app) {
        if (root.query === "")
            return true
        const q = root.query.toLowerCase()
        return app.title.toLowerCase().indexOf(q) !== -1
            || String(app.id).toLowerCase().indexOf(q) !== -1
            || String(app.category || "").toLowerCase().indexOf(q) !== -1
    }

    readonly property bool searching: query !== ""

    // Search ignores the drawers; browsing respects them.
    readonly property var pool: {
        var out = []
        for (var i = 0; i < catalog.length; i++) {
            var a = catalog[i]
            if (!matches(a)) continue
            if (!root.searching) {
                var isTool = a.kind === "tool"
                if (root.mode === "tools" && !isTool) continue
                if (root.mode === "apps" && isTool) continue
                if (root.mode === "tools" && root.category !== ""
                    && a.category !== root.category) continue
            }
            out.push(a)
        }
        return out
    }

    readonly property int toolCount: {
        var n = 0
        for (var i = 0; i < catalog.length; i++)
            if (catalog[i].kind === "tool") n++
        return n
    }
    readonly property int appCount: catalog.length - toolCount

    /* The categories with something in them, in Kali's order. Computed from
       the merged catalogue rather than taken from the service: the curated
       tools live in QML and the service cannot see them. */
    readonly property var categories: {
        var counts = {}
        for (var i = 0; i < catalog.length; i++) {
            var a = catalog[i]
            if (a.kind !== "tool") continue
            if (root.searching && !matches(a)) continue
            var c = a.category || "OTHER"
            counts[c] = (counts[c] || 0) + 1
        }
        var order = Apps.categoryOrder
        var out = [{ v: "", t: "ALL TOOLS", n: root.toolCount }]
        for (var j = 0; j < order.length; j++)
            if (counts[order[j]])
                out.push({ v: order[j], t: order[j], n: counts[order[j]] })
        return out
    }

    // Only the tools drawer has anything to filter by.
    readonly property bool sidebarVisible: mode === "tools" && !searching

    onModeChanged: category = ""

    // click-away
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.dismissed()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.42)
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
    }

    // ── the sheet ──────────────────────────────────────────────
    /* Sized to what is in it, up to a ceiling.
       A fixed 540 left the applications drawer as a mostly empty box with two
       rows of tiles floating at the top of it — the panel looked broken rather
       than roomy. Past the ceiling the grid scrolls, which is the point of
       having categories at all. */
    readonly property int sheetWidth: Math.min(760, width - 36)
    readonly property int gridWidth: sheetWidth - 36 - (sidebarVisible ? 152 : 0)
    readonly property int columns: Math.max(1, Math.floor(gridWidth / 118))
    readonly property int rowsNeeded: Math.max(1, Math.ceil(pool.length / columns))

    Item {
        id: sheet
        width: root.sheetWidth
        height: Math.min(540,
                         Math.max(root.sidebarVisible ? 372 : 232,
                                  112 + root.rowsNeeded * 86),
                         root.height - root.inset - 36)
        Behavior on height {
            enabled: Prefs.motionOn
            NumberAnimation { duration: Prefs.dur(Theme.durFast); easing.type: Theme.easeOut }
        }

        // Anchored to the corner the launcher button is actually in.
        x: root.edge === "right" ? root.width - width - root.inset - 12 : 18
        y: root.edge === "top" ? root.inset + 12 : root.height - height - root.inset - 12

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onWheel: function (wheel) { wheel.accepted = true }
        }

        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Prefs.dur(Theme.durFast) } }
        transform: Translate {
            y: root.visible || !Prefs.motionMoves
               ? 0 : (root.edge === "top" ? -Theme.slide : Theme.slide)
            Behavior on y { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                              easing.type: Theme.easeOut } }
        }

        Rectangle { anchors.fill: parent; color: Theme.bgVoid }
        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            border.width: 1
            border.color: Theme.hairline
        }
        Brackets { color: Theme.accent }

        // ── header ─────────────────────────────────────────────
        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            height: 62

            Row {
                id: modeTabs
                spacing: 0

                Repeater {
                    model: [{ v: "apps", t: "APPLICATIONS" }, { v: "tools", t: "TOOLS" }]

                    delegate: Item {
                        id: tab
                        required property var modelData
                        readonly property bool on: tab.modelData.v === root.mode

                        width: tabLabel.implicitWidth + countLabel.implicitWidth + 32
                        height: 24

                        HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.mode = tab.modelData.v }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 7
                            Text {
                                id: tabLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.t
                                color: tab.on ? Theme.accent
                                     : tabHover.hovered ? Theme.textBody : Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.sizeXs
                                font.letterSpacing: Theme.trackWider
                                Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }
                            }
                            Text {
                                id: countLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.v === "tools" ? root.toolCount : root.appCount
                                color: Theme.textMuted
                                font.family: Theme.mono
                                font.pixelSize: Theme.size2xs
                            }
                        }
                    }
                }
            }

            /* One rule that slides between the two tabs. Two rules that each
               fade would say "something changed"; this says which way. */
            Rectangle {
                id: tabRule
                y: 24
                width: root.mode === "tools" ? toolsTabWidth : appsTabWidth
                x: root.mode === "tools" ? appsTabWidth : 0
                height: 2
                color: Theme.accent

                readonly property real appsTabWidth: modeTabs.children.length > 0
                    ? modeTabs.children[0].width : 120
                readonly property real toolsTabWidth: modeTabs.children.length > 1
                    ? modeTabs.children[1].width : 90

                Behavior on x { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                                  easing.type: Theme.easeOut } }
                Behavior on width { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                                      easing.type: Theme.easeOut } }
            }

            Text {
                anchors { right: parent.right; top: parent.top }
                text: root.pool.length + " OF " + root.catalog.length
                    + (root.searching ? " MATCHING" : " INDEXED")
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
            }

            HudField {
                id: search
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                label: "search"
                placeholder: "filter everything — apps and tools"
                onEdited: function (t) { root.query = t }
                // Escape reaches the window's own binding only when nothing has
                // keyboard focus, and the search box always does.
                onEscaped: root.dismissed()
            }
        }

        // ── category sidebar ───────────────────────────────────
        Item {
            id: sidebar
            anchors { left: parent.left; leftMargin: 18
                      top: header.bottom; topMargin: 14
                      bottom: parent.bottom; bottomMargin: 18 }
            width: root.sidebarVisible ? 148 : 0
            clip: true
            visible: width > 0
            Behavior on width { NumberAnimation { duration: Prefs.dur(Theme.durMed)
                                                  easing.type: Theme.easeOut } }

            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 1
                color: Theme.line
            }

            ListView {
                anchors { fill: parent; rightMargin: 12 }
                clip: true
                model: root.categories
                interactive: contentHeight > height

                delegate: Item {
                    id: catRow
                    required property var modelData
                    width: ListView.view.width
                    height: 27

                    readonly property bool on: catRow.modelData.v === root.category

                    HoverHandler { id: catHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.category = catRow.modelData.v }

                    Rectangle {
                        anchors.fill: parent
                        color: catRow.on ? Theme.tint(0.10)
                             : catHover.hovered ? Theme.tint(0.05) : "transparent"
                        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    }
                    Rectangle {
                        visible: catRow.on
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: Theme.accent
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 10; right: catCount.left
                                  rightMargin: 6; verticalCenter: parent.verticalCenter }
                        text: catRow.modelData.t
                        color: catRow.on ? Theme.accent
                             : catHover.hovered ? Theme.textBody : Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: Theme.size2xs
                        font.letterSpacing: Theme.trackWide
                        elide: Text.ElideRight
                    }
                    Text {
                        id: catCount
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: catRow.modelData.n
                        color: Theme.textMuted
                        font.family: Theme.mono
                        font.pixelSize: 7
                    }
                }
            }
        }

        // ── the grid ───────────────────────────────────────────
        GridView {
            id: grid
            anchors { left: sidebar.right; leftMargin: root.sidebarVisible ? 4 : 18
                      right: parent.right; rightMargin: 18
                      top: header.bottom; topMargin: 14
                      bottom: parent.bottom; bottomMargin: 18 }
            clip: true
            model: root.pool
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 118)))
            cellHeight: 86
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 400

            /* Tiles fade in where they land rather than the whole grid being
               replaced. Switching drawer or category otherwise reads as the
               panel blinking. */
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1
                                  duration: Prefs.dur(Theme.durFast) }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: Prefs.dur(Theme.durFast)
                                  easing.type: Theme.easeOut }
            }

            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight

                /* Discovered entries were checked against PATH when they were
                   read, and command-line tools likewise, so both are installed
                   by construction. Settings lives inside the shell and has no
                   binary to find. */
                readonly property bool installed: cell.modelData.exec !== undefined
                                                  || cell.modelData.bin !== undefined
                                                  || cell.modelData.id === "settings"
                                                  || Apps.isInstalled(cell.modelData.id)
                readonly property bool isOpen: Apps.openIds.indexOf(cell.modelData.id) !== -1

                Item {
                    id: tile
                    anchors { fill: parent; margins: 3 }

                    HoverHandler { id: tileHover; enabled: cell.installed
                                   cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        enabled: cell.installed
                        onTapped: {
                            if (cell.modelData.bin !== undefined)
                                root.launchedTool(cell.modelData.id, cell.modelData.title,
                                                  cell.modelData.probe || "")
                            else
                                root.launched(cell.modelData.id, cell.modelData.exec || "")
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: tileHover.hovered ? Theme.tint(0.09) : "transparent"
                        border.width: 1
                        border.color: !cell.installed ? Qt.rgba(1, 1, 1, 0.05)
                                    : tileHover.hovered ? Theme.accent
                                    : cell.isOpen ? Theme.tint(0.35) : Theme.line
                        Behavior on color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                        Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durInstant) } }
                    }

                    // Running, so the launcher does not offer to start what is
                    // already there.
                    Rectangle {
                        visible: cell.isOpen
                        anchors { right: parent.right; top: parent.top; margins: 4 }
                        width: 4; height: 4
                        color: Theme.accent
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        AppIcon {
                            width: 24; height: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            glyph: cell.modelData.glyph
                            source: cell.modelData.icon !== undefined
                                    ? cell.modelData.icon
                                    : (Prefs.iconPaths[cell.modelData.id] || "")
                            lit: tileHover.hovered || cell.installed
                            stroke: !cell.installed ? Theme.textMuted
                                  : tileHover.hovered ? Theme.accent : Theme.textBody
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tile.width - 10
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.modelData.short || cell.modelData.title
                            color: !cell.installed ? Theme.textMuted
                                 : tileHover.hovered ? Theme.accent : Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: 7
                            font.letterSpacing: 0.6
                            elide: Text.ElideRight
                        }
                        // Where a tool sits, on the tile itself. When a search
                        // crosses both drawers this is the only thing that says
                        // what kind of result you are looking at.
                        Text {
                            visible: cell.modelData.kind === "tool"
                                     && (root.searching || root.category === "")
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.modelData.category || "TOOL"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 6
                            font.letterSpacing: 0.5
                        }
                        Text {
                            visible: !cell.installed
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "NOT INSTALLED"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 6
                        }
                    }
                }
            }
        }

        Text {
            visible: root.pool.length === 0
            anchors.centerIn: grid
            text: root.searching ? "NO MATCH — \"" + root.query + "\""
                                 : "NOTHING IN THIS CATEGORY"
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            font.letterSpacing: Theme.trackWide
        }
    }

    // Focus the search box whenever the launcher opens, and clear what was
    // typed last time — a stale filter looks like a launcher with no apps in it.
    onVisibleChanged: {
        if (visible) {
            search.clear()
            root.query = ""
            root.category = ""
            search.focusInput()
        }
    }
}
