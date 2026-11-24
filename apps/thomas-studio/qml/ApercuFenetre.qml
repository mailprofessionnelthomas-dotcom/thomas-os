// Une fenêtre d'appli dans l'aperçu (façon Dolphin) : barre de titre et boutons comme Breeze,
// couleurs du schéma KDE que le moteur génère (fond = « fenêtres », vue = un peu plus claire, sélection = principale).
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ThomasStudio

Item {
    id: f
    required property var theme
    property bool active: true
    property string titre: "Dossier personnel — Dolphin"
    readonly property real r: theme.px(theme.coinsFen)
    readonly property real titreH: theme.px(30)
    readonly property string ombre: theme.v("fenetres", "ombre", "moyenne")
    readonly property real force: theme.n("fenetres", "force_ombre", 50) / 100
    readonly property real bordure: theme.px(({ aucune: 0, fine: 1, normale: 3 })[theme.v("fenetres", "bordures", "normale")] ?? 0)
    readonly property color texte: active ? theme.cTexte : theme.cInactif
    readonly property color selTexte: theme.lum(theme.principale) < 0.6 ? "white" : "black"

    opacity: active ? 1 : theme.n("fenetres", "opacite_inactive", 100) / 100

    Repeater {  // ombre : quelques couches transparentes (pas d'effet graphique : rendu identique partout)
        model: f.ombre === "aucune" ? 0 : 4
        delegate: Rectangle {
            required property int index
            readonly property real taille: f.theme.px(({ petite: 6, moyenne: 12, grande: 20, enorme: 32 })[f.ombre] ?? 12) * (index + 1) / 4
            x: -taille
            y: -taille * 0.4
            width: f.width + 2 * taille
            height: f.height + 2 * taille
            radius: f.r + taille
            color: Qt.rgba(0, 0, 0, f.force * 0.14)
        }
    }
    Rectangle {  // cadre de la fenêtre (Breeze : même couleur que la barre de titre)
        anchors.fill: parent
        anchors.margins: -f.bordure
        visible: f.bordure > 0
        radius: f.r + f.bordure
        color: f.theme.cFen
        border.width: 1
        border.color: f.theme.mix(f.theme.cFen, f.theme.cTexte, 0.18)
    }
    Rectangle {
        id: corps
        anchors.fill: parent
        radius: f.r
        color: f.theme.cFen

        Component {
            id: boutonTitre
            Kirigami.Icon {
                required property string modelData
                width: f.theme.px(16)
                height: width
                source: ({ M: "system-file-manager", S: "window-pin", F: "window-keep-above", H: "help-contextual",
                           I: "window-minimize", A: "window-maximize", X: "window-close" })[modelData] ?? "window"
                isMask: modelData !== "M"
                color: f.texte
            }
        }
        Item {
            id: barreTitre
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: f.titreH
            Row {
                anchors { left: parent.left; leftMargin: f.theme.px(9); verticalCenter: parent.verticalCenter }
                spacing: f.theme.px(8)
                Repeater { model: f.theme.v("fenetres", "boutons_gauche", "").split(""); delegate: boutonTitre }
            }
            Text {
                anchors.centerIn: parent
                text: f.titre
                color: f.texte
                font.family: f.theme.police
                font.weight: Math.min(f.theme.poids + 200, 700)
                font.pixelSize: f.theme.txt
            }
            Row {
                anchors { right: parent.right; rightMargin: f.theme.px(9); verticalCenter: parent.verticalCenter }
                spacing: f.theme.px(8)
                Repeater { model: f.theme.v("fenetres", "boutons_droite", "X").split(""); delegate: boutonTitre }
            }
        }
        Row {  // barre d'outils
            id: outils
            anchors { left: parent.left; right: parent.right; top: barreTitre.bottom; leftMargin: f.theme.px(10) }
            height: f.theme.px(38)
            spacing: f.theme.px(14)
            Repeater {
                model: ["go-previous", "go-next", "view-list-icons", "view-list-details", "edit-find"]
                delegate: Kirigami.Icon {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: f.theme.px(18)
                    height: width
                    source: modelData
                    isMask: true
                    color: f.texte
                }
            }
        }
        Column {  // emplacements (à gauche)
            id: lieux
            anchors { left: parent.left; top: outils.bottom; leftMargin: f.theme.px(6) }
            width: f.theme.px(200)
            spacing: f.theme.px(2)
            Repeater {
                model: [["user-home", "Dossier personnel"], ["folder-documents", "Documents"], ["folder-pictures", "Images"],
                        ["folder-music", "Musique"], ["folder-download", "Téléchargements"], ["user-trash", "Corbeille"]]
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: lieux.width - f.theme.px(6)
                    height: f.theme.px(30)
                    radius: f.theme.px(4)
                    color: index === 0 ? f.theme.principale : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: f.theme.px(8); verticalCenter: parent.verticalCenter }
                        spacing: f.theme.px(8)
                        Kirigami.Icon { width: f.theme.px(18); height: width; source: modelData[0] }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[1]
                            color: index === 0 ? f.selTexte : f.texte
                            font.family: f.theme.police
                            font.weight: f.theme.poids
                            font.pixelSize: f.theme.txt
                        }
                    }
                }
            }
        }
        Rectangle {  // vue principale (un peu plus claire que la fenêtre)
            anchors { left: lieux.right; right: parent.right; top: outils.bottom; bottom: parent.bottom }
            color: f.theme.cVue
            bottomRightRadius: f.r
            Grid {
                anchors { fill: parent; margins: f.theme.px(18) }
                columns: Math.max(1, Math.floor(width / f.theme.px(110)))
                spacing: f.theme.px(12)
                Repeater {
                    model: ["Bureau", "Documents", "Images", "Jeux", "Musique", "Projets", "Téléchargements", "Vidéos"]
                    delegate: Column {
                        required property string modelData
                        width: f.theme.px(96)
                        spacing: f.theme.px(4)
                        Item {  // dossier dessiné : Breeze colore ses dossiers avec la couleur principale du style
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: f.theme.px(56)
                            height: f.theme.px(46)
                            Rectangle {
                                width: parent.width * 0.42
                                height: parent.height * 0.3
                                radius: f.theme.px(3)
                                color: Qt.darker(f.theme.principale, 1.3)
                            }
                            Rectangle {
                                y: parent.height * 0.14
                                width: parent.width
                                height: parent.height * 0.86
                                radius: f.theme.px(4)
                                color: f.theme.principale
                            }
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: modelData
                            color: f.texte
                            font.family: f.theme.police
                            font.weight: f.theme.poids
                            font.pixelSize: f.theme.txt
                        }
                    }
                }
            }
        }
    }
}
