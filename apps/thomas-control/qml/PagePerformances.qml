// Performances : températures (Thomas Core, toutes les 3 s pendant que la page est ouverte) et profil d'énergie.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    Component.onCompleted: {
        Controle.actualiserTemperatures()
        Controle.actualiserEnergie()
    }
    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: Controle.actualiserTemperatures()
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { text: "Températures"; level: 2 }
        QQC2.Label {
            Layout.fillWidth: true
            visible: Controle.temperatures.length === 0
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Aucun capteur de température lisible sur ce PC (c'est normal dans une machine virtuelle)."
        }
        Repeater {
            model: Controle.temperatures
            delegate: RowLayout {
                required property var modelData
                readonly property bool chaud: modelData.valeur >= modelData.seuil
                Layout.fillWidth: true
                QQC2.Label { text: modelData.nom; Layout.preferredWidth: Kirigami.Units.gridUnit * 12; elide: Text.ElideRight }
                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: modelData.limite > 0 ? modelData.limite : 100
                    value: modelData.valeur
                }
                QQC2.Label {
                    text: Math.round(modelData.valeur) + " °C"
                    color: chaud ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    font.bold: chaud
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 3.5
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Si un composant approche sa limite, Thomas OS te prévient par une notification (vérifié toutes les 2 minutes)."
        }

        Kirigami.Heading { text: "Profil d'énergie"; level: 2 }
        QQC2.Label {
            Layout.fillWidth: true
            visible: !Controle.energie.service
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Pas de service d'énergie sur ce PC."
        }
        RowLayout {
            visible: !!Controle.energie.service
            Repeater {
                model: [["power-saver", "Économie", "battery-profile-powersave"], ["balanced", "Équilibré", "battery-profile-balanced"],
                        ["performance", "Performance", "battery-profile-performance"]]
                       .filter(p => (Controle.energie.profils || "").split(",").includes(p[0]))
                delegate: QQC2.Button {
                    required property var modelData
                    text: modelData[1]
                    icon.name: modelData[2]
                    checkable: true
                    checked: Controle.energie.profil === modelData[0]
                    onClicked: {
                        Controle.choisirEnergie(modelData[0])
                        checked = Qt.binding(() => Controle.energie.profil === modelData[0])
                    }
                }
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: Controle.energie.jeu === "oui"
            wrapMode: Text.WordWrap
            text: "Un jeu tourne : le mode jeu maintient « Performance » jusqu'à la fin du jeu."
        }

        Kirigami.Heading { text: "Outils"; level: 2 }
        QQC2.ItemDelegate {
            Layout.fillWidth: true
            visible: Controle.programmeExiste("plasma-systemmonitor")
            icon.name: "utilities-system-monitor"
            text: "Moniteur système : processus, CPU, RAM, GPU, réseau, disques"
            onClicked: Controle.lancer("plasma-systemmonitor")
        }
    }
}
