// Horloge Thomas OS : salut + grosse heure fine + date, comme l'écran d'accueil de la télé de Thomas.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property date maintenant: new Date()
    readonly property color couleur: Plasmoid.configuration.couleur || "#ffffff"

    function salut(h) {
        return h < 5 || h >= 22 ? "Bonne nuit" : h < 12 ? "Bonjour" : h < 18 ? "Bon après-midi" : "Bonsoir"
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.maintenant = new Date()
    }

    // collée en haut à gauche du cadre du widget (sinon Plasma la centre et elle descend)
    fullRepresentation: Item {
      ColumnLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: 4

        Text {
            text: root.salut(root.maintenant.getHours()).toUpperCase()
            color: root.couleur
            font.pixelSize: 14
            font.letterSpacing: 3.5
            style: Text.Raised
            styleColor: "#40000000"
        }

        RowLayout {
            spacing: 20

            Text {
                text: Qt.formatTime(root.maintenant, "HH:mm")
                color: root.couleur
                font.pixelSize: 76
                font.weight: Font.Light
                style: Text.Raised
                styleColor: "#40000000"
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 52
                color: root.couleur
                opacity: 0.6
            }

            Text {
                text: root.maintenant.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM").toUpperCase()
                color: root.couleur
                font.pixelSize: 16
                font.weight: Font.Medium
                font.letterSpacing: 3
                style: Text.Raised
                styleColor: "#40000000"
            }
        }
      }
    }
}
