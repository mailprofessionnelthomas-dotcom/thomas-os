// Système et mises à jour : informations (Thomas Core), canal de mises à jour, variante (carte graphique) et
// « redémarrer sur Windows » (aide système org.thomasos.Systeme : le mot de passe administrateur est demandé par la
// fenêtre de KDE quand il faut). Les mises à jour restent celles de Bazzite (en fond, appliquées au redémarrage).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    id: page

    readonly property var canaux: ["stable", "testing"]
    readonly property var variantes: ["thomas-os", "thomas-os-nvidia", "thomas-os-nvidia-legacy"]
    readonly property string travail: Controle.systeme.travail || ""
    readonly property bool occupe: travail !== "" || Controle.attenteSysteme

    Component.onCompleted: Controle.actualiserSysteme()

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.Label { Kirigami.FormData.label: "Version :"; text: Controle.infos.version || "?" }
            QQC2.Label { Kirigami.FormData.label: "Image suivie :"; text: Controle.infos.image_suivie || "?"; elide: Text.ElideMiddle }
            QQC2.Label { Kirigami.FormData.label: "Carte graphique :"; text: (Controle.carte.detectees || "?") + (Controle.carte.conforme === "non" ? " (version conseillée : " + Controle.carte.conseil + ")" : "") }

            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Mises à jour" }
            RowLayout {
                Kirigami.FormData.label: "Canal :"
                QQC2.ComboBox {
                    id: choixCanal
                    model: page.canaux
                    currentIndex: Math.max(0, page.canaux.indexOf(Controle.systeme.canal || "stable"))
                    enabled: !page.occupe
                }
                QQC2.Button {
                    text: "Changer"
                    icon.name: "system-software-update"
                    enabled: !page.occupe && Controle.systeme.canal !== undefined && choixCanal.currentText !== Controle.systeme.canal
                    onClicked: Controle.changerCanal(choixCanal.currentText)
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                opacity: 0.75
                text: "stable : les versions validées (conseillé). testing : les nouveautés d'abord, testées en machine virtuelle."
            }
            RowLayout {
                Kirigami.FormData.label: "Variante :"
                QQC2.ComboBox {
                    id: choixVariante
                    model: page.variantes
                    currentIndex: Math.max(0, page.variantes.indexOf(Controle.systeme.variante || "thomas-os"))
                    enabled: !page.occupe
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
                }
                QQC2.Button {
                    text: "Changer"
                    icon.name: "video-display"
                    enabled: !page.occupe && Controle.systeme.variante !== undefined && choixVariante.currentText !== Controle.systeme.variante
                    onClicked: Controle.changerVariante(choixVariante.currentText)
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                opacity: 0.75
                text: "thomas-os : AMD, Intel. thomas-os-nvidia : NVIDIA GTX 16xx et RTX. thomas-os-nvidia-legacy : NVIDIA GTX 900 et 1000."
            }
        }

        QQC2.BusyIndicator {
            visible: page.occupe
            running: visible
            Layout.alignment: Qt.AlignHCenter
        }
        QQC2.Label {
            Layout.fillWidth: true
            visible: page.occupe
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: page.travail !== "" ? "Téléchargement en cours (tu peux continuer à utiliser le PC)… " + Controle.progressionSysteme
                                      : "En attente de l'autorisation (mot de passe administrateur)…"
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: (Controle.systeme.en_attente || "") !== "" && !page.occupe
            type: Kirigami.MessageType.Positive
            text: "Changement prêt (" + (Controle.systeme.en_attente || "") + ") : il s'appliquera au prochain redémarrage. La version actuelle reste disponible au démarrage en cas de problème."
        }

        Kirigami.Separator { Layout.fillWidth: true }
        RowLayout {
            Layout.fillWidth: true
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Controle.systeme.windows === "oui"
                      ? "Windows est sur ce PC (" + Controle.systeme.windows_nom + "). Pour FACEIT et les jeux à anti-triche noyau, redémarre dessus."
                      : "Windows n'a pas été trouvé dans les entrées de démarrage de ce PC."
            }
            QQC2.Button {
                text: "Redémarrer sur Windows"
                icon.name: "system-reboot"
                visible: Controle.systeme.windows === "oui"
                enabled: !page.occupe
                onClicked: confirmation.open()
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.75
            text: "Les mises à jour se téléchargent en fond et s'appliquent au prochain redémarrage. La version précédente reste disponible au démarrage en cas de problème. Le diagnostic est dans « Maintenance »."
        }
    }

    Kirigami.PromptDialog {
        id: confirmation
        title: "Redémarrer sur Windows ?"
        subtitle: "Enregistre ton travail d'abord. Le PC redémarre une fois sur Windows ; au démarrage suivant, Thomas OS revient par défaut."
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: Controle.redemarrerWindows()
    }
}
