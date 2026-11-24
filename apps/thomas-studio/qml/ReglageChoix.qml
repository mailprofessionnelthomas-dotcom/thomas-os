// Réglage à choix : seulement les valeurs que le moteur accepte (catalogue de Thomas Core).
import QtQuick
import QtQuick.Controls as QQC2
import ThomasStudio

QQC2.ComboBox {
    id: choix
    required property string sec
    required property string cle
    readonly property var liste: Studio.catalogue.choix ? Studio.options(sec, cle) : []
    readonly property string valeur: Studio.brouillon[sec] ? (Studio.brouillon[sec][cle] ?? "") : ""
    function position() { return liste.findIndex(o => o.valeur === valeur) }

    model: liste
    textRole: "nom"
    valueRole: "valeur"
    currentIndex: position()
    onActivated: {
        Studio.changer(sec, cle, currentValue)
        currentIndex = Qt.binding(position)
    }
}
