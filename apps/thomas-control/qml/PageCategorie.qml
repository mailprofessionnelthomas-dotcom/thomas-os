// Page d'une catégorie : liste des réglages KDE et programmes correspondants (seulement ceux présents sur ce PC).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    id: page
    property var categorie: ({})

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !!page.categorie.bientot
            type: Kirigami.MessageType.Information
            text: page.categorie.bientot || ""
        }
        Repeater {
            model: (page.categorie.kcms || []).filter(k => Controle.reglageExiste(k[0]))
            delegate: QQC2.ItemDelegate {
                required property var modelData
                Layout.fillWidth: true
                icon.name: "configure"
                text: modelData[1] + (modelData[2] ? " — " + modelData[2] : "")
                onClicked: Controle.ouvrirReglage(modelData[0])
            }
        }
        Repeater {
            model: (page.categorie.programmes || []).filter(p => Controle.programmeExiste(p[0]))
            delegate: QQC2.ItemDelegate {
                required property var modelData
                Layout.fillWidth: true
                icon.name: modelData[0]
                text: modelData[1]
                onClicked: Controle.lancer(modelData[0])
            }
        }
    }
}
