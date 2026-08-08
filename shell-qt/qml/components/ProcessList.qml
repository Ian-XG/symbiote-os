import QtQuick
import Symbiote

/* What is actually running, ranked by CPU.
   Replaced a scripted "recent activity" feed of invented events — this is both
   true and more useful, since it is how you find what is eating the machine. */
Item {
    id: root
    property var rows: []

    readonly property int headerH: 18
    readonly property int rowH: 28
    /* Only whole rows. The panel used to cut the last one through the middle,
       which looked like a rendering fault rather than a list that ran out of
       room. */
    /* At least one row whenever there is one to show. On a 1280x800 panel the
       leftover height worked out to 45px, capacity computed to zero, and the
       panel sat there reserving space and listing nothing — "0 OF 8". A single
       clipped row is worse than none; no rows at all while processes exist is
       worse than both. */
    readonly property int capacity: Math.max(rows && rows.length ? 1 : 0,
                                             Math.floor((height - headerH) / rowH))
    readonly property int shown: Math.min(capacity, rows ? rows.length : 0)
    readonly property var visibleRows: rows ? rows.slice(0, shown) : []

    /* Right-click on a row. The panel told you what was eating the machine and
       gave you no way to act on it, which is half a feature. */
    signal contextRequested(int pid, string name, real sx, real sy)

    Column {
        anchors.fill: parent
        spacing: 0

        // header
        Item {
            width: parent.width
            height: root.headerH
            Text {
                text: "PROCESS"; color: Theme.textMuted
                font.family: Theme.mono; font.pixelSize: Theme.size2xs
                font.letterSpacing: Theme.trackWide
                anchors.left: parent.left
            }
            Text {
                text: "CPU"; color: Theme.textMuted
                font.family: Theme.mono; font.pixelSize: Theme.size2xs
                anchors.right: memHdr.left; anchors.rightMargin: 14
            }
            Text {
                id: memHdr
                text: "MEM"; color: Theme.textMuted
                font.family: Theme.mono; font.pixelSize: Theme.size2xs
                anchors.right: parent.right
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1
                color: Theme.line
            }
        }

        Text {
            visible: !root.rows || root.rows.length === 0
            text: "Reading /proc…"
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            topPadding: 10
        }

        Repeater {
            model: root.visibleRows

            Item {
                required property var modelData
                width: root.width
                height: root.rowH

                HoverHandler { id: rowHover }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: function (point) {
                        var g = parent.mapToItem(null, point.position.x, point.position.y)
                        root.contextRequested(modelData.pid, modelData.name, g.x, g.y)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: rowHover.hovered
                    color: Theme.tint(0.06)
                }

                readonly property bool hot: modelData.cpu > 60
                // Relative to the busiest process, so movement stays visible
                // even when nothing is near 100%.
                readonly property real peak: {
                    var m = 1
                    for (var i = 0; i < root.rows.length; i++)
                        m = Math.max(m, root.rows[i].cpu)
                    return m
                }

                Text {
                    id: nameText
                    text: modelData.name
                    color: parent.hot ? Theme.alert : Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                    elide: Text.ElideRight
                    anchors.left: parent.left
                    anchors.right: cpuText.left
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 4
                }
                Text {
                    id: cpuText
                    text: modelData.cpu.toFixed(1) + "%"
                    color: parent.hot ? Theme.alert : Theme.accent
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                    anchors.right: memText.left
                    anchors.rightMargin: 14
                    anchors.baseline: nameText.baseline
                }
                Text {
                    id: memText
                    text: modelData.rssMb >= 1024
                          ? (modelData.rssMb / 1024).toFixed(1) + "G"
                          : modelData.rssMb + "M"
                    color: Theme.textMuted
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                    anchors.right: parent.right
                    anchors.baseline: nameText.baseline
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: nameText.bottom
                    anchors.topMargin: 3
                    height: 2
                    color: Theme.line
                    Rectangle {
                        height: parent.height
                        width: Math.max(2, parent.width * (modelData.cpu / parent.parent.peak))
                        color: parent.parent.hot ? Theme.alert : Theme.accent
                    }
                }
            }
        }
    }
}
