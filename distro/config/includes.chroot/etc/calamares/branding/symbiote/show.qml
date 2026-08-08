import QtQuick 2.5
import calamares.slideshow 1.0

/* The installer's slideshow. Deliberately plain: someone reading this is
   waiting for a disk to be written and wants to know what they are getting,
   not to be sold to. */
Presentation {
    id: presentation

    Timer {
        interval: 12000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#080808" }
        Column {
            anchors.centerIn: parent
            spacing: 18
            Text {
                text: "SYMBIOTE OS"
                color: "#00ff88"
                font.family: "JetBrains Mono"
                font.pixelSize: 34
                font.letterSpacing: 8
            }
            Text {
                text: "Debian underneath. Everything the interface shows is measured."
                color: "#c8c8c8"
                font.family: "JetBrains Mono"
                font.pixelSize: 14
            }
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#080808" }
        Column {
            anchors.centerIn: parent
            spacing: 14
            Text {
                text: "AFTER INSTALLING"
                color: "#00ff88"
                font.family: "JetBrains Mono"
                font.pixelSize: 22
                font.letterSpacing: 5
            }
            Text {
                text: "Super            applications\n" +
                      "Ctrl+Alt+T       terminal\n" +
                      "Super+W          wireless\n" +
                      "Super+L          session and power\n" +
                      "Escape           close the top panel"
                color: "#c8c8c8"
                font.family: "JetBrains Mono"
                font.pixelSize: 14
                lineHeight: 1.6
            }
        }
    }
}
