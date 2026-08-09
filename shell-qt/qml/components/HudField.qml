import QtQuick
import Symbiote

/* A text field: the search box, the Wi-Fi passphrase, the pairing PIN.
   Three hand-built copies of this existed, and only one of them showed a
   placeholder, which is why the Wi-Fi password box was an unlabelled black
   rectangle unless you already knew what it was for. */
Item {
    id: field

    property string label: ""
    property string placeholder: ""
    property alias text: input.text
    property bool password: false
    property bool enabled: true
    /** Digits only — a Bluetooth passkey, which BlueZ will not take otherwise. */
    property bool numeric: false
    property int maximumLength: 32767

    signal accepted(string text)
    signal edited(string text)
    /* Escape, forwarded. A focused TextInput consumes the key before the
       window's own Shortcut sees it, which is why the launcher could only be
       closed with the mouse once you had clicked in the search box. */
    signal escaped()

    function clear() { input.text = "" }
    function focusInput() { input.forceActiveFocus() }

    implicitHeight: Theme.ctrlHeight
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceSunk
        border.width: 1
        border.color: !field.enabled ? Theme.line
                    : input.activeFocus ? Theme.accent
                    : hover.hovered ? Theme.textMuted : Theme.line
        Behavior on border.color { ColorAnimation { duration: Prefs.dur(Theme.durFast) } }
    }

    HoverHandler { id: hover; enabled: field.enabled; cursorShape: Qt.IBeamCursor }
    TapHandler { enabled: field.enabled; onTapped: input.forceActiveFocus() }

    Text {
        id: tag
        visible: field.label !== ""
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        text: field.label
        color: Theme.accent
        font.family: Theme.mono
        font.pixelSize: Theme.sizeSm
    }

    TextInput {
        id: input
        enabled: field.enabled
        anchors { left: tag.visible ? tag.right : parent.left
                  leftMargin: tag.visible ? 8 : 10
                  right: parent.right; rightMargin: 10
                  verticalCenter: parent.verticalCenter }
        echoMode: field.password ? TextInput.Password : TextInput.Normal
        color: Theme.accent
        selectionColor: Theme.tint(0.35)
        selectedTextColor: Theme.bgVoid
        font.family: Theme.mono
        font.pixelSize: Theme.sizeSm
        maximumLength: field.maximumLength
        validator: field.numeric ? digits : null
        clip: true
        onTextChanged: field.edited(text)
        onAccepted: field.accepted(text)
        Keys.onEscapePressed: field.escaped()
    }

    IntValidator { id: digits; bottom: 0; top: 999999 }

    Text {
        visible: input.text === ""
        anchors { left: input.left; verticalCenter: parent.verticalCenter }
        text: field.placeholder
        color: Theme.textMuted
        font.family: Theme.mono
        font.pixelSize: Theme.sizeSm
    }
}
