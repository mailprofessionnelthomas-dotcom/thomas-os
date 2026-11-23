// Apparence : choix du style Thomas OS (appliqué par Thomas Core) et réglages KDE d'apparence.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    title: "Apparence"

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { text: "Style"; level: 2 }
        Repeater {
            model: Controle.styles
            delegate: QQC2.RadioDelegate {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.nom
                checked: modelData.id === Controle.styleActuel
                onClicked: Controle.appliquerStyle(modelData.id)
            }
        }
        RowLayout {
            QQC2.Button { text: "Revenir au style de base"; icon.name: "edit-undo"; onClicked: Controle.styleDeSecours() }
            QQC2.Button { text: "Créer un style (Studio)"; icon.name: "draw-brush"; enabled: Controle.programmeExiste("thomas-studio")
                          onClicked: Controle.lancer("thomas-studio") }
        }

        Kirigami.Heading { text: "Réglages KDE"; level: 2 }
        Repeater {
            model: [["kcm_colors", "Couleurs"], ["kcm_fonts", "Polices"], ["kcm_icons", "Icônes"], ["kcm_cursortheme", "Curseur"],
                    ["kcm_notifications", "Notifications"], ["kcm_kwin_virtualdesktops", "Bureaux virtuels"],
                    ["kcm_keys", "Raccourcis clavier"], ["kcm_kwindecoration", "Barres de titre des fenêtres"]]
                   .filter(k => Controle.reglageExiste(k[0]))
            delegate: QQC2.ItemDelegate {
                required property var modelData
                Layout.fillWidth: true
                icon.name: "configure"
                text: modelData[1]
                onClicked: Controle.ouvrirReglage(modelData[0])
            }
        }
    }
}
