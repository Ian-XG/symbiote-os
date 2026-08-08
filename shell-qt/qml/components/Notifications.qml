import QtQuick
import Symbiote

/* Transient messages, stacked above the taskbar.
 *
 * The shell used to say things in exactly one place: a red bar across the
 * bottom of the desktop, used for one kind of event (a launch that failed) and
 * for nothing else. Everything else happened silently — a network joined, a
 * device paired, a disk mounted, a process asked to quit. The operator had to
 * go and look at a panel to find out whether anything had worked.
 *
 * Newest at the bottom, nearest the bar, because that is where the eye already
 * is when something has just been clicked there.
 */
Item {
    id: root

    property real bottomInset: 0
    readonly property int maxVisible: 4

    ListModel { id: queue }

    /* `error` only changes the colour. It does not change whether the message
       is shown: a refusal the operator needs to read is not less important
       than a success. */
    function push(text, error) {
        if (!text)
            return
        queue.append({ body: String(text), isError: error === true })
        // Oldest first out, so a burst cannot push the newest off the screen.
        while (queue.count > root.maxVisible)
            queue.remove(0)
    }

    Column {
        anchors {
            right: parent.right; rightMargin: 18
            bottom: parent.bottom; bottomMargin: root.bottomInset + 12
        }
        spacing: 8

        Repeater {
            model: queue

            Item {
                id: toast
                required property int index
                required property string body
                required property bool isError

                width: label.implicitWidth + 34
                height: 36

                // Slides in from the right rather than appearing on top of
                // whatever the eye was reading.
                property real slide: 24
                Component.onCompleted: slide = 0
                Behavior on slide { NumberAnimation { duration: Theme.durMed
                                                      easing.type: Easing.OutCubic } }
                transform: Translate { x: toast.slide }

                opacity: 0
                Component.onDestruction: {}
                NumberAnimation on opacity {
                    to: 1; duration: Theme.durFast; running: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.bgVoid
                }
                Rectangle {
                    anchors.fill: parent
                    color: toast.isError ? Qt.rgba(1, 0.09, 0.27, 0.10) : Theme.tint(0.10)
                    border.width: 1
                    border.color: toast.isError ? Theme.alert : Theme.hairline
                }

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 2
                    color: toast.isError ? Theme.alert : Theme.accent
                }

                Text {
                    id: label
                    anchors { left: parent.left; leftMargin: 16
                              right: parent.right; rightMargin: 12
                              verticalCenter: parent.verticalCenter }
                    text: toast.body
                    color: toast.isError ? Theme.alert : Theme.textBody
                    font.family: Theme.mono
                    font.pixelSize: Theme.sizeXs
                    elide: Text.ElideRight
                }

                // Click to dismiss early.
                TapHandler { onTapped: queue.remove(toast.index) }

                /* Errors stay longer. A success is a confirmation you already
                   expected; a failure is something you have to read and decide
                   about. */
                Timer {
                    interval: toast.isError ? 9000 : 4500
                    running: true
                    onTriggered: if (toast.index < queue.count) queue.remove(toast.index)
                }
            }
        }
    }
}
