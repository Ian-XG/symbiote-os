import QtQuick
import Symbiote

/* An application's icon: its own if it has one, the shell's drawn glyph if not.
 *
 * The split is deliberate. Anything that belongs to the system — settings,
 * trash, the session, the shell's own tools — stays drawn in the HUD's line
 * vocabulary, because those are concepts this interface owns. Installed
 * applications get their real icon, because a column of identical outlines
 * cannot tell you which one is Firefox.
 */
Item {
    id: root

    property string glyph: ""
    /** Absolute path to a real icon, or empty to use the glyph. */
    property string source: ""
    property color stroke: Theme.textBody
    /* Dim the real icon when the tile is not lit, so a colour logo does not
       shout over a monochrome bar. */
    property bool lit: true

    readonly property bool usingImage: source !== "" && image.status === Image.Ready

    Image {
        id: image
        anchors.fill: parent
        source: root.source ? "file://" + root.source : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        // Requested at the size it is drawn, so a 128px PNG is not resampled
        // from full size on every repaint.
        sourceSize.width: Math.round(width * 2)
        sourceSize.height: Math.round(height * 2)
        visible: root.usingImage
        opacity: root.lit ? 1.0 : 0.72
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    GlyphIcon {
        anchors.fill: parent
        visible: !root.usingImage
        glyph: root.glyph
        stroke: root.stroke
    }
}
