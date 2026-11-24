// Un élément d'une barre de l'aperçu : appli, menu (logo T), panneau rapide, icônes système, horloge…
// Les tailles viennent d'Apercu.taille() : la même règle sert à mesurer la barre et à la dessiner.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ThomasStudio

Item {
    id: e
    required property var modelData
    required property var theme
    property real epaisseur: theme.g.ep
    property bool vertical: theme.vertical
    readonly property string t: modelData.t
    readonly property real k: theme.k
    readonly property real cote: Math.max(1, (epaisseur - 8) * k)
    readonly property real longueur: theme.taille(t, epaisseur, vertical) * k
    readonly property bool avecDate: theme.oui("barre", "date") && !vertical && epaisseur >= 30

    Layout.fillWidth: t === "espace" && !vertical
    Layout.fillHeight: t === "espace" && vertical
    Layout.preferredWidth: vertical ? cote : longueur
    Layout.preferredHeight: vertical ? longueur : cote
    Layout.alignment: Qt.AlignCenter

    Kirigami.Icon {
        visible: ["appli", "menu", "logo", "panneau", "montrer"].includes(e.t)
        anchors.centerIn: parent
        width: e.cote * (e.t === "logo" ? 0.8 : 0.6)
        height: width
        source: e.t === "appli" ? Studio.appli(e.modelData.id).icone
              : e.t === "panneau" ? "configure" : e.t === "montrer" ? "user-desktop" : "thomas-os"
        isMask: e.t === "panneau"
        color: e.theme.cTexte
    }
    Rectangle {  // trait sous l'appli ouverte (celle de la fenêtre de l'aperçu)
        visible: e.t === "appli" && e.modelData.actif === true
        color: e.theme.principale
        radius: 1
        width: e.vertical ? Math.max(1, 2 * e.k) : e.cote * 0.42
        height: e.vertical ? e.cote * 0.42 : Math.max(1, 2 * e.k)
        anchors.horizontalCenter: e.vertical ? undefined : parent.horizontalCenter
        anchors.bottom: e.vertical ? undefined : parent.bottom
        anchors.left: e.vertical ? parent.left : undefined
        anchors.verticalCenter: e.vertical ? parent.verticalCenter : undefined
    }
    Row {  // icônes système (réseau, son, notifications)
        visible: e.t === "zone"
        anchors.centerIn: parent
        spacing: e.cote * 0.2
        Repeater {
            model: ["network-wireless-signal-excellent", "audio-volume-high", "notifications"]
            delegate: Kirigami.Icon {
                required property string modelData
                width: e.cote * 0.5
                height: width
                source: modelData
                isMask: true
                color: e.theme.cTexte
            }
        }
    }
    Column {
        visible: e.t === "horloge"
        anchors.centerIn: parent
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(new Date(), "HH:mm")
            color: e.theme.cTexte
            font.family: e.theme.police
            font.weight: e.theme.poids
            font.pixelSize: Math.max(1, Math.min(e.theme.txt * 1.05, e.cote * (e.avecDate ? 0.42 : 0.6)))
        }
        Text {
            visible: e.avecDate
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(new Date(), "dd/MM/yyyy")
            color: e.theme.cTexte
            font.family: e.theme.police
            font.weight: e.theme.poids
            font.pixelSize: Math.max(1, Math.min(e.theme.txt * 0.85, e.cote * 0.34))
        }
    }
    Row {  // bureaux virtuels
        visible: e.t === "bureaux"
        anchors.centerIn: parent
        spacing: e.cote * 0.12
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: e.cote * 0.45
                height: e.cote * 0.32
                color: index === 0 ? e.theme.alpha(e.theme.principale, 0.5) : "transparent"
                border.color: e.theme.cInactif
                border.width: 1
            }
        }
    }
    Text {  // menu des applis (barre fine du haut)
        visible: e.t === "appmenu"
        anchors.verticalCenter: parent.verticalCenter
        x: e.k * 8
        text: "Fichier     Édition     Affichage     Aide"
        color: e.theme.cTexte
        font.family: e.theme.police
        font.weight: e.theme.poids
        font.pixelSize: Math.max(1, Math.min(e.theme.txt, e.cote * 0.75))
    }
}
