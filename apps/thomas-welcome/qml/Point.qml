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
    // icône d'une seule couleur (coche, clavier) ; false pour une icône en couleurs (information, attention)
    readonly property bool masque: icone === "checkmark" || icone === "input-keyboard"

    Layout.fillWidth: true
    spacing: Kirigami.Units.mediumSpacing
    Kirigami.Icon {
        source: point.icone
        color: point.masque ? point.couleur : "transparent"
        isMask: point.masque
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
