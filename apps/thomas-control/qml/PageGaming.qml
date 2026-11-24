// Gaming : mode jeu automatique (profil d'énergie « performance » pendant un jeu) et ce qui ne marche pas sous Linux.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    Component.onCompleted: Controle.actualiserEnergie()
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: Controle.actualiserEnergie()
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.Switch {
                Kirigami.FormData.label: "Mode jeu automatique :"
                checked: Controle.jeuAuto
                onToggled: {
                    Controle.changerJeuAuto(checked)
                    checked = Qt.binding(() => Controle.jeuAuto)
                }
            }
            QQC2.Label {
                Kirigami.FormData.label: "En ce moment :"
                text: Controle.energie.jeu === "oui" ? "un jeu tourne, profil « performance »"
                                                      : "pas de jeu en cours (profil « " + (Controle.energie.profil || "?") + " »)"
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Quand un jeu tourne (Steam, Lutris, Heroic, Sober pour Roblox, Prism Launcher pour Minecraft), Thomas OS passe le profil d'énergie en « performance », puis remet le profil d'avant à la fin du jeu. Rien d'autre n'est changé. La vérification prend quelques millisecondes toutes les 15 secondes."
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Information
            text: "Gain pas encore mesuré : il se mesure sur ton PC, en jeu (images par seconde avec et sans le mode jeu)."
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Warning
            text: "Ne marchent pas sous Linux : FACEIT et les jeux à anti-triche noyau (Valorant…). Garde Windows pour eux."
        }
        QQC2.ItemDelegate {
            Layout.fillWidth: true
            visible: Controle.programmeExiste("plasma-systemmonitor")
            icon.name: "utilities-system-monitor"
            text: "Moniteur système (pour voir CPU et GPU pendant un jeu)"
            onClicked: Controle.lancer("plasma-systemmonitor")
        }
    }
}
