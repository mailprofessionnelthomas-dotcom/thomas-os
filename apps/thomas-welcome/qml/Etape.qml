// Une étape de l'écran de bienvenue : icône, titre, explication, puis son contenu.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: etape
    property string titre
    property string icone
    property string texte
    default property alias contenu: zone.data

    spacing: Kirigami.Units.largeSpacing

    RowLayout {
        spacing: Kirigami.Units.largeSpacing
        Kirigami.Icon {
            source: etape.icone
            Layout.preferredWidth: Kirigami.Units.iconSizes.large
            Layout.preferredHeight: Kirigami.Units.iconSizes.large
        }
        Kirigami.Heading {
            text: etape.titre
            level: 1
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
    QQC2.Label {
        visible: etape.texte !== ""
        text: etape.texte
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    ColumnLayout {
        id: zone
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Kirigami.Units.mediumSpacing
    }
}
