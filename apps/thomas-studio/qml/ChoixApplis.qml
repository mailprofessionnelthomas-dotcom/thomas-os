// Applis épinglées (barre) ou favoris (menu) : seulement les applis présentes dans Thomas OS.
// Une appli cochée s'ajoute à la fin ; l'ordre des autres est gardé.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasStudio

ColumnLayout {
    id: choix
    required property string sec
    readonly property var actuelles: (Studio.brouillon[sec] ? (Studio.brouillon[sec].epingles ?? "") : "").split(",").filter(a => a)
    function basculer(id, oui) {
        const l = actuelles.filter(a => a !== id)
        if (oui) l.push(id)
        Studio.changer(sec, "epingles", l.join(","))
    }

    spacing: 0
    Repeater {
        model: Studio.catalogue.applis ?? []
        delegate: QQC2.CheckBox {
            id: caseAppli
            required property string modelData
            readonly property var appli: Studio.appli(modelData)
            function etat() { return choix.actuelles.includes(modelData) }
            text: appli.nom
            icon.name: appli.icone
            checked: etat()
            onToggled: {
                choix.basculer(modelData, checked)
                checked = Qt.binding(etat)
            }
        }
    }
}
