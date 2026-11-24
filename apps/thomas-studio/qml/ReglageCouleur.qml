// Réglage de couleur : pastille (clic = sélecteur de couleur de KDE), code #rrggbb, couleurs de l'identité Thomas OS.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import ThomasStudio

RowLayout {
    id: reglage
    required property string sec
    required property string cle
    property bool auto: false
    property string texteAuto: "Automatique"
    property string couleurAuto: "#000000"
    readonly property string brut: Studio.brouillon[sec] ? (Studio.brouillon[sec][cle] ?? "") : ""
    readonly property bool estAuto: auto && brut === ""
    readonly property string valeur: estAuto ? couleurAuto : brut
    function choisir(c) { Studio.changer(sec, cle, c) }

    spacing: Kirigami.Units.smallSpacing

    Rectangle {
        implicitWidth: Kirigami.Units.gridUnit * 1.6
        implicitHeight: implicitWidth
        radius: 4
        color: reglage.valeur || "transparent"
        border.color: Kirigami.Theme.textColor
        border.width: 1
        opacity: reglage.estAuto ? 0.5 : 1
        MouseArea {
            anchors.fill: parent
            enabled: !reglage.estAuto
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                selecteur.selectedColor = reglage.valeur
                selecteur.open()
            }
        }
    }
    QQC2.TextField {
        id: code
        Layout.preferredWidth: Kirigami.Units.gridUnit * 5
        text: reglage.valeur
        enabled: !reglage.estAuto
        validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
        onEditingFinished: {
            if (acceptableInput) reglage.choisir(text.toLowerCase())
            text = Qt.binding(() => reglage.valeur)
        }
    }
    Repeater {
        model: Studio.palette
        delegate: Rectangle {
            id: pastille
            required property var modelData
            implicitWidth: Kirigami.Units.gridUnit * 0.9
            implicitHeight: implicitWidth
            radius: width / 2
            color: modelData.couleur
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1
            opacity: reglage.estAuto ? 0.4 : 1
            QQC2.ToolTip.text: modelData.nom
            QQC2.ToolTip.visible: zone.containsMouse
            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            MouseArea {
                id: zone
                anchors.fill: parent
                hoverEnabled: true
                enabled: !reglage.estAuto
                cursorShape: Qt.PointingHandCursor
                onClicked: reglage.choisir(pastille.modelData.couleur)
            }
        }
    }
    QQC2.CheckBox {
        visible: reglage.auto
        text: reglage.texteAuto
        checked: reglage.estAuto
        onToggled: {
            reglage.choisir(checked ? "" : reglage.couleurAuto)
            checked = Qt.binding(() => reglage.estAuto)
        }
    }
    ColorDialog {
        id: selecteur
        title: "Choisir une couleur"
        onAccepted: reglage.choisir(selectedColor.toString())
    }
}
