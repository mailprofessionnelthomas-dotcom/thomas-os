// Une ligne avec une icône : « ce qui est vrai sur ce PC ».
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

RowLayout {
    id: point
    property string icone: "checkmark"
    property string texte
    property color couleur: Kirigami.Theme.positiveTextColor

    Layout.fillWidth: true
    spacing: Kirigami.Units.mediumSpacing
    Kirigami.Icon {
        source: point.icone
        color: point.couleur
        isMask: true
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        Layout.alignment: Qt.AlignTop
    }
    QQC2.Label {
        text: point.texte
        wrapMode: Text.WordWrap
        textFormat: Text.StyledText
        Layout.fillWidth: true
    }
}
