// Réseau : diagnostic (mesurer seulement, rien n'est changé) et pages de réglages réseau de KDE.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ScrollablePage {
    id: page
    property var categorie: ({})
    readonly property var t: Controle.testReseau
    function verdict(ms) {
        if (ms === undefined) return ""
        return ms < 30 ? " · très bon pour jouer en ligne" : ms < 70 ? " · correct" : " · élevé (jeux en ligne moins réactifs)"
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { text: "Diagnostic de la connexion"; level: 2 }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Mesure seulement : rien n'est changé dans tes réglages."
        }
        RowLayout {
            QQC2.Button {
                text: "Tester la connexion"
                icon.name: "network-connect"
                enabled: !Controle.mesureEnCours
                onClicked: Controle.lancerTestReseau()
            }
            QQC2.Button {
                text: "Mesurer le débit (25 Mo)"
                icon.name: "download"
                enabled: !Controle.mesureEnCours
                onClicked: Controle.lancerTestDebit()
            }
            QQC2.BusyIndicator {
                running: Controle.mesureEnCours
                visible: running
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                Layout.preferredWidth: Layout.preferredHeight
            }
        }
        Kirigami.FormLayout {
            Layout.fillWidth: true
            visible: Object.keys(page.t).length > 0
            QQC2.Label {
                Kirigami.FormData.label: "Connexion :"
                text: page.t.etat === "connecte" ? (page.t.type === "wifi" ? "Wi-Fi « " + page.t.nom + " »" : "câble") : (page.t.etat === "deconnecte" ? "aucune" : "?")
            }
            QQC2.Label {
                Kirigami.FormData.label: "Temps de réponse :"
                visible: page.t.latence_ms !== undefined
                text: page.t.latence_ms + " ms (de " + page.t.latence_min + " à " + page.t.latence_max + ")" + page.verdict(Number(page.t.latence_ms))
            }
            QQC2.Label {
                Kirigami.FormData.label: "Stabilité :"
                visible: page.t.pertes !== undefined
                text: "écart " + (page.t.gigue_ms ?? "?") + " ms · échecs " + page.t.pertes
            }
            QQC2.Label {
                Kirigami.FormData.label: "Noms de domaine (DNS) :"
                visible: page.t.dns_ms !== undefined
                text: page.t.dns_ms === "échec" ? "échec" : page.t.dns_ms + " ms"
            }
            QQC2.Label {
                Kirigami.FormData.label: "Signal Wi-Fi :"
                visible: page.t.signal !== undefined
                text: page.t.signal + " %"
            }
            QQC2.Label {
                Kirigami.FormData.label: "Débit descendant :"
                visible: page.t.debit_mbps !== undefined
                text: page.t.debit_mbps + " Mbit/s (" + (page.t.mo ?? "?") + " Mo en " + (page.t.secondes ?? "?") + " s)"
            }
        }

        Kirigami.Heading { text: "Réglages réseau"; level: 2 }
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
    }
}
