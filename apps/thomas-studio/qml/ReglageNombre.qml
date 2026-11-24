// Réglage chiffré : curseur borné par les limites du moteur. « auto » : valeur vide = même valeur qu'un autre réglage.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasStudio

RowLayout {
    id: reglage
    required property string sec
    required property string cle
    property string unite: ""
    property int pas: 1
    property var etiquettes: null      // ex. tailles en pixels pour un numéro de taille
    property bool auto: false
    property string texteAuto: "Auto"
    property real valeurAuto: 0
    readonly property var lim: Studio.catalogue.limites ? Studio.limites(cle) : [0, 100]
    readonly property string brut: Studio.brouillon[sec] ? (Studio.brouillon[sec][cle] ?? "") : ""
    readonly property bool estAuto: auto && brut === ""
    function lire() { return estAuto ? valeurAuto : Number(brut) }

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing

    QQC2.CheckBox {
        visible: reglage.auto
        text: reglage.texteAuto
        checked: reglage.estAuto
        onToggled: {
            Studio.changer(reglage.sec, reglage.cle, checked ? "" : String(Math.round(curseur.value)))
            checked = Qt.binding(() => reglage.estAuto)
        }
    }
    QQC2.Slider {
        id: curseur
        Layout.fillWidth: true
        Layout.minimumWidth: Kirigami.Units.gridUnit * 6
        from: reglage.lim[0]
        to: reglage.lim[1]
        stepSize: reglage.pas
        snapMode: QQC2.Slider.SnapAlways
        enabled: !reglage.estAuto
        value: reglage.lire()
        onMoved: {
            Studio.changer(reglage.sec, reglage.cle, String(Math.round(value)))
            value = Qt.binding(reglage.lire)
        }
    }
    QQC2.Label {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 3
        horizontalAlignment: Text.AlignRight
        text: (reglage.etiquettes ? reglage.etiquettes[Math.round(curseur.value)] : Math.round(curseur.value)) + reglage.unite
    }
}
