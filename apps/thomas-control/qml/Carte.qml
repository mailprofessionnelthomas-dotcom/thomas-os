// Carte du tableau de bord : titre, valeur en %, jauge fine rouge.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: carte
    property string titre
    property string icone
    property real valeur: -1       // en %, -1 = indisponible
    property string detail
    signal ouvrir()

    showClickFeedback: true
    onClicked: ouvrir()

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Kirigami.Icon { source: carte.icone; implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth }
            QQC2.Label { text: carte.titre; font.bold: true; Layout.fillWidth: true }
            QQC2.Label { text: carte.valeur < 0 ? "—" : Math.round(carte.valeur) + " %"; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6 }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: 2
            color: Kirigami.Theme.alternateBackgroundColor
            Rectangle {
                width: carte.valeur < 0 ? 0 : parent.width * Math.min(1, carte.valeur / 100)
                height: parent.height
                radius: 2
                color: Kirigami.Theme.highlightColor
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
        QQC2.Label { text: carte.detail; opacity: 0.7; visible: text.length > 0; elide: Text.ElideRight; Layout.fillWidth: true }
    }
}
