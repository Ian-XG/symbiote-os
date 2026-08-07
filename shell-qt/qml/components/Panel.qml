import QtQuick
import Symbiote

/* The framed module every readout sits in. Title left, code right, corner
   brackets, hairline border, glass tint over the wallpaper. */
Item {
    id: root

    property string title: ""
    property string code: ""
    property bool active: false
    /** Stretch the body to the panel's height instead of hugging its content. */
    property bool stretch: false
    default property alias content: body.data

    // childrenRect, not implicitHeight: a plain Item's implicitHeight is always
    // 0 regardless of what it contains, so every panel collapsed to its header.
    // A stretched panel is given its height by the parent, so asking the body
    // how tall it wants to be would close the loop: body height <- panel
    // height <- body childrenRect.
    implicitHeight: header.height + (stretch ? 0 : body.childrenRect.height)
        + Theme.space5 * 2 + (title || code ? Theme.space4 : 0)

    Rectangle {
        anchors.fill: parent
        color: Theme.panel
        border.width: 1
        border.color: root.active ? Theme.hairline : Theme.line
    }

    Brackets {
        color: root.active ? Theme.accent : Theme.tint(0.10)
    }

    Item {
        id: header
        visible: root.title !== "" || root.code !== ""
        height: visible ? label.implicitHeight : 0
        anchors {
            top: parent.top; topMargin: Theme.space5
            left: parent.left; leftMargin: Theme.space5
            right: parent.right; rightMargin: Theme.space5
        }

        Text {
            id: label
            text: root.title
            color: Theme.accent
            font.family: Theme.mono
            font.pixelSize: Theme.sizeXs
            font.letterSpacing: Theme.trackWider
            anchors.left: parent.left
        }
        Text {
            text: root.code
            color: Theme.textMuted
            font.family: Theme.mono
            font.pixelSize: Theme.size2xs
            anchors.right: parent.right
            anchors.baseline: label.baseline
        }
    }

    Item {
        id: body
        anchors {
            top: header.visible ? header.bottom : parent.top
            topMargin: header.visible ? Theme.space4 : Theme.space5
            left: parent.left; leftMargin: Theme.space5
            right: parent.right; rightMargin: Theme.space5
            bottom: root.stretch ? parent.bottom : undefined
            bottomMargin: Theme.space5
        }
        height: root.stretch ? undefined : childrenRect.height
        clip: true
    }
}
