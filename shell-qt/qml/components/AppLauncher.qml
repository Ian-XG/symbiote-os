import QtQuick
import Symbiote

/* Searchable app grid, opened from MENU.
   In the first Qt port that button opened Settings, because this did not exist
   yet — so most of the installed tools were unreachable. */
Item {
    id: root
    signal launched(string id, string exec)
    signal dismissed()

    property string query: ""
    /* How much of the bottom edge the taskbar owns. Anchoring the sheet to the
       window's own bottom put it underneath the taskbar, covering the MENU
       button that opened it. */
    property real bottomInset: 0

    /* The nine curated tools, then everything the machine actually installed.
       Keeping them in one list means the search box searches both — the
       curated ones are just the ones with a drawn glyph and a short name. */
    readonly property var catalog: Prefs.apps.concat(Apps.discovered)

    function matches(app) {
        if (root.query === "")
            return true
        const q = root.query.toLowerCase()
        return app.title.toLowerCase().indexOf(q) !== -1 || app.id.indexOf(q) !== -1
    }

    readonly property var visibleApps: catalog.filter(matches)

    /* Grouped, not one alphabetical run. Nine curated tools fitted in a flat
       grid; a few hundred discovered ones do not, and scrolling past a
       hundred identical tiles to reach a text editor is not a launcher. */
    readonly property var groups: {
        var sys = [], recon = [], defense = [], other = []
        for (var i = 0; i < visibleApps.length; i++) {
            var a = visibleApps[i]
            var g = a.glyph
            if (a.exec === undefined)
                (g === "radar" || g === "bug") ? recon.push(a)
                : (g === "shield" || g === "pulse") ? defense.push(a)
                : sys.push(a)
            else
                (g === "radar" || g === "bug") ? recon.push(a)
                : (g === "shield") ? defense.push(a)
                : other.push(a)
        }
        var out = []
        if (sys.length)     out.push({ name: "SYSTEM",    apps: sys })
        if (recon.length)   out.push({ name: "RECON",     apps: recon })
        if (defense.length) out.push({ name: "DEFENSE",   apps: defense })
        if (other.length)   out.push({ name: "INSTALLED", apps: other })
        return out
    }

    // click-away
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    Item {
        id: sheet
        width: 560
        /* Measured from the row count, not from GridView.contentHeight — the
           view reports the height of its whole content area, which left the
           sheet with a band of empty panel under the last row. */
        /* Grows with the content up to whatever room is left above the bar.
           With a few hundred applications this hits the ceiling and the list
           scrolls, which is the point of grouping them. */
        readonly property int rows: Math.max(1, Math.ceil(root.visibleApps.length / 4))
        height: Math.min(root.height - root.bottomInset - 24,
                         18 + header.height + 14 + rows * 84 + root.groups.length * 26 + 18)
        anchors { left: parent.left; leftMargin: 18
                  bottom: parent.bottom; bottomMargin: root.bottomInset + 8 }

        // Swallow clicks so the click-away below does not close it.
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.fill: parent
            color: Theme.bgVoid
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.panelStrong
            border.width: 1
            border.color: Theme.hairline
        }
        Brackets { color: Theme.accent }

        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            height: 60

            Text {
                text: "APPLICATIONS"
                color: Theme.accent
                font.family: Theme.mono
                font.pixelSize: Theme.sizeXs
                font.letterSpacing: Theme.trackWider
            }
            Text {
                anchors.right: parent.right
                text: root.visibleApps.length + "/" + root.catalog.length + " INDEXED"
                color: Theme.textMuted
                font.family: Theme.mono
                font.pixelSize: Theme.size2xs
            }

            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 28
                color: Qt.rgba(0, 0, 0, 0.4)
                border.width: 1
                border.color: search.activeFocus ? Theme.accent : Theme.line

                Text {
                    id: searchLabel
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "search"
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeSm
                }
                TextInput {
                    id: search
                    anchors { left: searchLabel.right; leftMargin: 8; right: parent.right
                              rightMargin: 10; verticalCenter: parent.verticalCenter }
                    focus: true
                    color: Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeSm
                    onTextChanged: root.query = text
                    Keys.onEscapePressed: root.dismissed()
                }
                Text {
                    visible: search.text === ""
                    anchors { left: searchLabel.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: "filter applications"
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeSm
                }
            }
        }

        Flickable {
            id: grid
            anchors {
                top: header.bottom; topMargin: 14
                left: parent.left; leftMargin: 18
                right: parent.right; rightMargin: 18
                bottom: parent.bottom; bottomMargin: 18
            }
            clip: true
            contentHeight: groupCol.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: groupCol
                width: grid.width
                spacing: 10

                Repeater {
                    model: root.groups

                    Column {
                        required property var modelData
                        width: groupCol.width
                        spacing: 4

                        Text {
                            text: modelData.name + "  ·  " + modelData.apps.length
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: Theme.size2xs
                            font.letterSpacing: Theme.trackWider
                            topPadding: 4
                        }

                        Grid {
                            columns: 4
                            spacing: 0
                            Repeater {
                                model: parent.parent.modelData.apps
                                delegate: appTile
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.visibleApps.length === 0
            anchors.centerIn: parent
            text: "NO MATCH — \"" + root.query + "\""
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
        }
    }
    /* One tile, used by every group. Defined once here rather than repeated
       per group — the groups differ in what they contain, not in how a tile
       looks. */
    Component {
        id: appTile

        Item {
            id: cell
            required property var modelData
            width: (sheet.width - 36) / 4
            height: 84

            Item {
                id: tile
                anchors { fill: parent; margins: 3 }

                /* Discovered entries were checked against PATH when they were
                   read, so they are installed by construction. Settings lives
                   inside the shell and has no binary to find. */
                readonly property bool installed: cell.modelData.exec !== undefined
                                                  || cell.modelData.id === "settings"
                                                  || Apps.isInstalled(cell.modelData.id)

                HoverHandler { id: tileHover; enabled: tile.installed }
                TapHandler {
                    enabled: tile.installed
                    onTapped: root.launched(cell.modelData.id, cell.modelData.exec || "")
                }

                Rectangle {
                    anchors.fill: parent
                    color: tileHover.hovered ? Theme.tint(0.08) : "transparent"
                    border.width: 1
                    border.color: !tile.installed ? Qt.rgba(1, 1, 1, 0.05)
                                : tileHover.hovered ? Theme.accent : Theme.line
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 7
                    AppIcon {
                        width: 24; height: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        glyph: cell.modelData.glyph
                        source: cell.modelData.icon !== undefined
                                ? cell.modelData.icon
                                : (Prefs.iconPaths[cell.modelData.id] || "")
                        lit: tileHover.hovered || tile.installed
                        stroke: !tile.installed ? Theme.textMuted
                              : tileHover.hovered ? Theme.accent : Theme.textBody
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: cell.width - 10
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.short || cell.modelData.title
                        color: !tile.installed ? Theme.textMuted
                             : tileHover.hovered ? Theme.accent : Theme.textBody
                        font.family: Theme.mono
                        font.pixelSize: 7
                        font.letterSpacing: 0.6
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: !tile.installed
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
}
