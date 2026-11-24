// Maintenance : nettoyage (automatique chaque semaine, ou maintenant avec ton mot de passe) et diagnostic.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    Component.onCompleted: {
        Controle.actualiserNettoyage()
        Controle.actualiserRapport()
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { text: "Nettoyage"; level: 2 }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Chaque semaine, Thomas OS retire les composants Flatpak que plus aucune appli n'utilise, et les miniatures d'images de plus de 30 jours. Jamais tes fichiers, jamais la version précédente du système (elle sert à revenir en arrière)."
        }
        QQC2.Label {
            Layout.fillWidth: true
            opacity: 0.75
            text: Controle.nettoyage.date
                  ? "Dernier nettoyage : " + new Date(Controle.nettoyage.date).toLocaleString(Qt.locale("fr_FR"), "d MMMM yyyy à HH:mm")
                    + " (" + Controle.nettoyage.libere_mo + " Mo libérés)"
                  : "Pas encore de nettoyage."
        }
        RowLayout {
            QQC2.Button {
                text: "Nettoyer maintenant"
                icon.name: "edit-clear-all"
                enabled: !Controle.nettoyageEnCours
                onClicked: Controle.nettoyer()
            }
            QQC2.BusyIndicator {
                running: Controle.nettoyageEnCours
                visible: running
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                Layout.preferredWidth: Layout.preferredHeight
            }
            QQC2.Label { text: "(ton mot de passe est demandé)"; opacity: 0.75 }
        }
        QQC2.ItemDelegate {
            Layout.fillWidth: true
            visible: Controle.programmeExiste("filelight")
            icon.name: "filelight"
            text: "Voir ce qui prend de la place (Filelight)"
            onClicked: Controle.lancer("filelight")
        }

        Kirigami.Heading { text: "Diagnostic"; level: 2 }
        QQC2.TextArea {
            Layout.fillWidth: true
            readOnly: true
            text: Controle.rapport || "…"
            font.family: "monospace"
        }
        QQC2.Button { text: "Relancer le diagnostic"; icon.name: "view-refresh"; onClicked: Controle.actualiserRapport() }
    }
}
