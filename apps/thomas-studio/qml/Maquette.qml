// « thomas-studio --apercu FICHIER.png STYLE » : dessine la maquette du style (comme dans le Studio),
// l'enregistre en PNG puis quitte. Sert aux tests : la maquette est comparée à la vraie capture du bureau.
import QtQuick
import QtQuick.Window
import ThomasStudio

Window {
    id: fen
    property string styleDemande
    property string fichierApercu
    property string ecran           // « 1920x1080 » ; vide = la taille de l'écran réel
    property bool menuOuvert: false
    property string tailleImage     // « 640x360 » : image réduite (aperçus de l'écran de bienvenue) ; vide = taille de l'écran
    readonly property var taille: /^(\d+)x(\d+)$/.exec(ecran)
    readonly property var reduite: /^(\d+)x(\d+)$/.exec(tailleImage)

    width: apercu.ecranL
    height: apercu.ecranH
    visible: true
    title: "Thomas Studio : maquette"
    color: "black"

    Apercu {  // taille fixe = l'écran : la fenêtre peut être rognée par le bureau, la photo de la maquette non
        id: apercu
        width: ecranL
        height: ecranH
        notification: true
        menuOuvert: fen.menuOuvert
        ecranL: fen.taille ? Number(fen.taille[1]) : (Screen.width > 0 ? Screen.width : 1920)
        ecranH: fen.taille ? Number(fen.taille[2]) : (Screen.height > 0 ? Screen.height : 1080)
    }
    Component.onCompleted: Studio.ouvrir(styleDemande)
    Connections {
        target: Studio
        function onStyleOuvert() { attente.start() }
        function onErreur(texte) {
            console.warn("Thomas Studio : " + texte)
            Qt.exit(1)
        }
    }
    Timer {  // le temps que le fond d'écran et les icônes soient chargés
        id: attente
        interval: 2000
        onTriggered: {
            const fini = r => Qt.exit(r.saveToFile(fen.fichierApercu) ? 0 : 1)
            const ok = fen.reduite ? apercu.grabToImage(fini, Qt.size(Number(fen.reduite[1]), Number(fen.reduite[2])))
                                   : apercu.grabToImage(fini)
            if (!ok) Qt.exit(1)
        }
    }
}
