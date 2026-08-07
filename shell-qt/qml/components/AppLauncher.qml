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
        readonly property int rows: Math.max(1, Math.ceil(root.visibleApps.length / 4))
        height: Math.min(root.height - root.bottomInset - 24,
                         18 + header.height + 14 + rows * 84 + 18)
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

        GridView {
            id: grid
            anchors {
                top: header.bottom; topMargin: 14
                left: parent.left; leftMargin: 18
                right: parent.right; rightMargin: 18
                bottom: parent.bottom; bottomMargin: 18
            }
            cellWidth: (width - 1) / 4
            cellHeight: 84
            clip: true
            model: root.visibleApps

            delegate: Item {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight

                Item {
                    id: tile
                    anchors { fill: parent; margins: 3 }

                    /* Asked once, at build time of the delegate: the installed
                       set cannot change while the shell runs. Without this a
                       missing binary was only discovered by clicking it and
                       reading an error — the grid claimed every tool was there. */
                    /* Settings lives inside the shell — there is no binary to
                       find, so asking the PATH about it answered "NOT
                       INSTALLED" for something sitting on the desktop. */
                    /* Discovered entries were already checked against PATH
                       when they were read, so they are installed by
                       construction. */
                    readonly property bool installed: modelData.exec !== undefined
                                                      || modelData.id === "settings"
                                                      || Apps.isInstalled(modelData.id)

                    HoverHandler { id: tileHover; enabled: tile.installed }
                    TapHandler {
                        enabled: tile.installed
                        onTapped: root.launched(modelData.id, modelData.exec || "")
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
                            glyph: modelData.glyph
                            // Discovered entries carry their own resolved path;
                            // curated ones look theirs up in Prefs.
                            source: modelData.icon !== undefined
                                    ? modelData.icon
                                    : (Prefs.iconPaths[modelData.id] || "")
                            lit: tileHover.hovered || tile.installed
                            stroke: !tile.installed ? Theme.textMuted
                                  : tileHover.hovered ? Theme.accent : Theme.textBody
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.title
                            color: !tile.installed ? Theme.textMuted
                                 : tileHover.hovered ? Theme.accent : Theme.textBody
                            font.family: Theme.mono
                            font.pixelSize: 7
                            font.letterSpacing: 0.6
                        }
                        Text {
                            visible: !tile.installed
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "NOT INSTALLED"
                            color: Theme.textMuted
                            font.family: Theme.mono
                            font.pixelSize: 6
                            font.letterSpacing: 0.5
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
}
