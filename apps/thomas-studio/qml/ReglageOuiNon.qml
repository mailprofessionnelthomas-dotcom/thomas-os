// Réglage oui / non.
import QtQuick
import QtQuick.Controls as QQC2
import ThomasStudio

QQC2.Switch {
    id: inter
    required property string sec
    required property string cle
    function etat() { return Studio.brouillon[sec] ? Studio.brouillon[sec][cle] === "oui" : false }

    checked: etat()
    onToggled: {
        Studio.changer(sec, cle, checked ? "oui" : "non")
        checked = Qt.binding(etat)
    }
}
