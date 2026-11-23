// Système, maintenance et mises à jour : informations (Thomas Core) et diagnostic. Les mises à jour restent
// celles de Bazzite (en fond, appliquées au redémarrage) : rien de parallèle ici.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    Component.onCompleted: Controle.actualiserRapport()

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.Label { Kirigami.FormData.label: "Version :"; text: Controle.infos.version || "?" }
            QQC2.Label { Kirigami.FormData.label: "Canal de mises à jour :"; text: Controle.infos.canal || "?" }
            QQC2.Label { Kirigami.FormData.label: "Image suivie :"; text: Controle.infos.image_suivie || "?"; elide: Text.ElideMiddle }
            QQC2.Label { Kirigami.FormData.label: "Variante :"; text: Controle.infos.gpu_variant || "?" }
            QQC2.Label { Kirigami.FormData.label: "Carte graphique :"; text: (Controle.carte.detectees || "?") + (Controle.carte.conforme === "non" ? " (version conseillée : " + Controle.carte.conseil + ")" : "") }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.75
            text: "Les mises à jour se téléchargent en fond et s'appliquent au prochain redémarrage. La version précédente reste disponible au démarrage en cas de problème."
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
