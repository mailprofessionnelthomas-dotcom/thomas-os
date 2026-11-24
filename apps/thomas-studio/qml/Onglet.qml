// Un onglet de réglages : formulaire KDE qui défile.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

QQC2.ScrollView {
    id: onglet
    default property alias contenu: formulaire.data
    contentWidth: availableWidth
    clip: true

    Kirigami.FormLayout {
        id: formulaire
        width: onglet.availableWidth
    }
}
