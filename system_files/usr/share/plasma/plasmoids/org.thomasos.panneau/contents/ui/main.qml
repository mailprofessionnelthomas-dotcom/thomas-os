/*
 * Panneau rapide Thomas OS : Wi-Fi, Bluetooth, volume, luminosité, dans un seul panneau vertical.
 * Chaque réglage est dans son propre fichier, chargé par un Loader : si un module de KDE manque ou change
 * (ex. pas de Bluetooth sur ce PC), seule sa ligne disparaît, le panneau reste utilisable.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

PlasmoidItem {
    id: racine
    Plasmoid.icon: "configure"
    toolTipMainText: "Réglages rapides"
    toolTipSubText: "Wi-Fi, Bluetooth, volume, luminosité"

    compactRepresentation: MouseArea {
        hoverEnabled: true
        onClicked: racine.expanded = !racine.expanded
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.round(Math.min(parent.width, parent.height) * 0.6)
            height: width
            source: "configure"
            active: parent.containsMouse
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: colonne.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumWidth: Layout.preferredWidth
        collapseMarginsHint: true

        ColumnLayout {
            id: colonne
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            PlasmaExtras.Heading {
                level: 4
                text: "Réglages rapides"
            }
            Repeater {
                model: ["Wifi.qml", "Bluetooth.qml", "Volume.qml", "Luminosite.qml"]
                delegate: Loader {
                    required property string modelData
                    Layout.fillWidth: true
                    source: modelData
                    visible: status === Loader.Ready && item && item.disponible
                    onStatusChanged: if (status === Loader.Error) console.warn("Panneau rapide : réglage indisponible", modelData)
                }
            }
            PC3.ToolButton {
                Layout.alignment: Qt.AlignRight
                icon.name: "preferences-system"
                text: "Tous les réglages"
                onClicked: { racine.expanded = false; KCMUtils.KCMLauncher.openSystemSettings("") }
            }
        }
    }
}
