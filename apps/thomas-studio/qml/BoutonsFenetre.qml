// Boutons des barres de titre : chacun absent, à gauche ou à droite (Fermer est toujours présent).
// Un bouton ajouté se place du côté du titre.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasStudio

ColumnLayout {
    id: boutons
    readonly property string gauche: Studio.brouillon.fenetres ? (Studio.brouillon.fenetres.boutons_gauche ?? "") : ""
    readonly property string droite: Studio.brouillon.fenetres ? (Studio.brouillon.fenetres.boutons_droite ?? "") : ""
    function cote(l) { return gauche.includes(l) ? 1 : (droite.includes(l) ? 2 : 0) }
    function placer(l, ou) {
        let g = gauche.replace(l, ""), d = droite.replace(l, "")
        if (ou === 1) g = g + l
        else if (ou === 2) d = l + d
        Studio.changer("fenetres", "boutons_gauche", g)
        Studio.changer("fenetres", "boutons_droite", d)
    }

    spacing: Kirigami.Units.smallSpacing
    Repeater {
        model: Studio.catalogue.boutons ?? []
        delegate: RowLayout {
            id: ligne
            required property var modelData
            readonly property string lettre: modelData[0]
            readonly property bool obligatoire: lettre === "X"
            function position() { return obligatoire ? Math.max(0, boutons.cote(lettre) - 1) : boutons.cote(lettre) }
            QQC2.Label {
                text: ligne.modelData[1]
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
            }
            QQC2.ComboBox {
                model: ligne.obligatoire ? ["À gauche", "À droite"] : ["Absent", "À gauche", "À droite"]
                currentIndex: ligne.position()
                onActivated: index => {
                    boutons.placer(ligne.lettre, ligne.obligatoire ? index + 1 : index)
                    currentIndex = Qt.binding(ligne.position)
                }
            }
        }
    }
}
