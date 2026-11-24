// Thomas Welcome : 7 étapes au 1er démarrage (bienvenue, connexion, carte graphique, confidentialité, style,
// préférences, raccourcis). Fermer la fenêtre compte comme « fini » : elle se rouvre depuis le menu.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasWelcome

Kirigami.ApplicationWindow {
    id: fenetre
    property string dossierCapture  // tests : photo de chaque étape, puis quitter
    property bool fini: false
    property int etapeCapture: 0
    readonly property int nbEtapes: etapes.count
    readonly property var c: Bienvenue.carte
    readonly property var i: Bienvenue.infos
    readonly property var noms: ({ amd: "AMD", nvidia: "NVIDIA", intel: "Intel" })

    title: "Bienvenue dans Thomas OS"
    width: Kirigami.Units.gridUnit * 52
    height: Kirigami.Units.gridUnit * 36
    minimumWidth: Kirigami.Units.gridUnit * 40
    minimumHeight: Kirigami.Units.gridUnit * 30
    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.None

    onClosing: close => {
        if (!fini && dossierCapture === "") {
            close.accepted = false
            fini = true
            Bienvenue.terminer()
        }
    }
    Connections {
        target: Bienvenue
        function onErreur(message) { fenetre.showPassiveNotification(message, "long") }
    }

    // tests : chaque étape affichée, photographiée, puis la suivante
    Timer {
        id: montrer
        interval: 2000
        running: fenetre.dossierCapture !== ""
        onTriggered: {
            etapes.currentIndex = fenetre.etapeCapture
            photographier.start()
        }
    }
    Timer {
        id: photographier
        interval: 1500
        onTriggered: {
            const ok = fenetre.pageStack.grabToImage(r => {
                r.saveToFile(fenetre.dossierCapture + "/etape-" + (fenetre.etapeCapture + 1) + ".png")
                fenetre.etapeCapture += 1
                if (fenetre.etapeCapture < fenetre.nbEtapes) montrer.start()
                else Qt.exit(0)
            })
            if (!ok) Qt.exit(1)
        }
    }

    pageStack.initialPage: Kirigami.Page {
        padding: Kirigami.Units.gridUnit * 1.5

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            Row {  // où on en est
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: fenetre.nbEtapes
                    delegate: Rectangle {
                        required property int index
                        width: index === etapes.currentIndex ? Kirigami.Units.gridUnit * 1.6 : Kirigami.Units.gridUnit * 0.5
                        height: Kirigami.Units.gridUnit * 0.5
                        radius: height / 2
                        color: index <= etapes.currentIndex ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
            }

            StackLayout {
                id: etapes
                Layout.fillWidth: true
                Layout.fillHeight: true

                Etape {
                    titre: "Bienvenue dans Thomas OS"
                    icone: "thomas-os"
                    texte: "Ton PC est prêt. En quelques étapes, on vérifie la connexion et la carte graphique, puis tu choisis ton style. Tout se change plus tard dans Thomas Control et Thomas Studio."
                    Kirigami.Icon {
                        source: "thomas-os"
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 7
                    }
                    QQC2.Label {
                        Layout.alignment: Qt.AlignHCenter
                        // une installation sur un numéro de version précis (test) ne suit pas de canal
                        text: "Version " + (fenetre.i.version ?? "?") + " · mises à jour : "
                              + (/^\d{8}\.\d+$/.test(fenetre.i.canal ?? "") ? "version figée" : "canal « " + (fenetre.i.canal ?? "?") + " »")
                        color: Kirigami.Theme.disabledTextColor
                    }
                    Point { texte: "Le système se met à jour tout seul, en arrière-plan. La version d'avant reste disponible au démarrage du PC." }
                    Point { texte: "Tes fichiers et tes réglages ne sont jamais touchés par une mise à jour." }
                }

                Etape {
                    id: etapeReseau
                    readonly property bool connecte: Bienvenue.reseau.etat === "connecte"
                    titre: "Connexion à Internet"
                    icone: "network-wireless"
                    texte: "Internet sert aux mises à jour et aux applis : elles s'installent toutes seules dès que tu es connecté."
                    Point {
                        visible: etapeReseau.connecte
                        texte: Bienvenue.reseau.type === "wifi" ? "Connecté en Wi-Fi (« " + Bienvenue.reseau.nom + " »)." : "Connecté par câble."
                    }
                    Point {
                        visible: !etapeReseau.connecte
                        icone: "dialog-warning"
                        couleur: Kirigami.Theme.neutralTextColor
                        texte: Bienvenue.reseau.etat === "inconnu" ? "État de la connexion inconnu." : "Pas encore connecté : branche un câble ou choisis un Wi-Fi."
                    }
                    QQC2.Button {
                        text: "Choisir un réseau Wi-Fi…"
                        icon.name: "network-wireless"
                        visible: Bienvenue.reglageExiste("kcm_networkmanagement")
                        onClicked: Bienvenue.ouvrirReglage("kcm_networkmanagement")
                    }
                    Timer {
                        interval: 3000
                        repeat: true
                        running: etapes.currentIndex === 1
                        onTriggered: Bienvenue.actualiserReseau()
                    }
                }

                Etape {
                    id: etapeMateriel
                    readonly property var detectees: (fenetre.c.detectees ?? "").split(",").filter(x => fenetre.noms[x])
                    readonly property string image: (fenetre.c.conseil ?? "").split(" ")[0]
                    // version inconnue (info.env absent) : on ne conseille rien plutôt qu'une commande fausse
                    readonly property bool aChanger: fenetre.c.conforme === "non" && (fenetre.c.variante ?? "?") !== "?"
                                                     && (fenetre.i.image_ref ?? "") !== ""
                    readonly property string commande: "sudo bootc switch " + (fenetre.i.image_ref ?? "").replace(/[^/]*$/, image) + ":"
                                                       + (["stable", "testing"].includes(fenetre.i.canal) ? fenetre.i.canal : "stable")
                    titre: "Carte graphique"
                    icone: "video-display"
                    texte: "Thomas OS existe en 3 versions selon la carte graphique (AMD/Intel, NVIDIA récente, NVIDIA ancienne). On vérifie que c'est la bonne."
                    Point {
                        visible: etapeMateriel.detectees.length > 0
                        icone: "video-display"
                        couleur: Kirigami.Theme.textColor
                        texte: "Carte détectée : <b>" + etapeMateriel.detectees.map(x => fenetre.noms[x]).join(" + ") + "</b>"
                    }
                    Point {
                        visible: etapeMateriel.detectees.length === 0
                        icone: "dialog-information"
                        couleur: Kirigami.Theme.neutralTextColor
                        texte: "Aucune carte AMD, NVIDIA ou Intel reconnue (c'est normal dans une machine virtuelle)."
                    }
                    Point {
                        visible: fenetre.c.conforme === "oui"
                        texte: "La bonne version de Thomas OS est installée (" + (fenetre.c.variante ?? "?") + ")."
                    }
                    Kirigami.InlineMessage {
                        Layout.fillWidth: true
                        visible: etapeMateriel.aChanger
                        type: Kirigami.MessageType.Warning
                        text: "Cette version (" + (fenetre.c.variante ?? "?") + ") n'est pas faite pour ta carte. Il te faut : " + (fenetre.c.conseil ?? "?")
                              + ". Pour changer : ouvre Konsole, tape la commande ci-dessous, puis redémarre. Bientôt, Thomas Control le fera en un clic."
                    }
                    QQC2.TextField {
                        Layout.fillWidth: true
                        visible: etapeMateriel.aChanger
                        readOnly: true
                        text: etapeMateriel.commande
                        font.family: "monospace"
                    }
                }

                Etape {
                    titre: "Confidentialité"
                    icone: "security-high"
                    texte: "Ce que Thomas OS fait, et ne fait pas, avec tes données :"
                    Point { texte: "Aucun compte en ligne n'est demandé : ton compte reste sur ce PC." }
                    Point { texte: "Le compteur d'utilisation de Fedora est coupé." }
                    Point { texte: "Les applis viennent de Flathub, sans compte." }
                    Point { texte: "Les mises à jour viennent du dépôt de Thomas OS sur GitHub." }
                }

                Etape {
                    titre: "Ton style"
                    icone: "preferences-desktop-theme-global"
                    texte: "Choisis un look : il s'applique tout de suite (quelques secondes). Tu pourras tout changer avec Thomas Studio."
                    GridView {
                        id: grille
                        readonly property int colonnes: Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 10)))
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
                        clip: true
                        cellWidth: Math.floor(width / colonnes)
                        cellHeight: Math.round((cellWidth - Kirigami.Units.largeSpacing) * 0.5625) + Kirigami.Units.gridUnit * 2.2
                        model: Bienvenue.styles
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                        delegate: Item {
                            id: carte
                            required property var modelData
                            readonly property bool actuel: modelData.id === Bienvenue.styleActuel
                            width: grille.cellWidth
                            height: grille.cellHeight
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                radius: 6
                                color: carte.actuel ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : "transparent"
                                border.width: carte.actuel ? 2 : 1
                                border.color: carte.actuel ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2)
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Image {
                                            id: vignette
                                            anchors.fill: parent
                                            source: Bienvenue.apercu(carte.modelData.id)
                                            fillMode: Image.PreserveAspectFit
                                            sourceSize.width: 480
                                            asynchronous: true
                                        }
                                        Kirigami.Icon {  // pas de maquette pour ce style (style perso) : une icône
                                            visible: vignette.status !== Image.Ready
                                            anchors.centerIn: parent
                                            width: Kirigami.Units.iconSizes.large
                                            height: width
                                            source: "preferences-desktop-theme-global"
                                        }
                                    }
                                    QQC2.Label {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        text: carte.modelData.nom
                                        font.bold: carte.actuel
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !Bienvenue.application
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bienvenue.appliquerStyle(carte.modelData.id)
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        QQC2.BusyIndicator {
                            running: Bienvenue.application
                            visible: running
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                            Layout.preferredWidth: Layout.preferredHeight
                        }
                        QQC2.Label {
                            visible: Bienvenue.application
                            text: "Application du style…"
                        }
                        Item { Layout.fillWidth: true }
                        QQC2.Button {
                            text: "Ouvrir Thomas Studio"
                            icon.name: "draw-brush"
                            visible: Bienvenue.programmeExiste("thomas-studio")
                            onClicked: Bienvenue.lancer("thomas-studio")
                        }
                    }
                }

                Etape {
                    titre: "Tes préférences"
                    icone: "preferences-system"
                    texte: "Les réglages les plus utiles au début. Chacun s'ouvre dans sa fenêtre."
                    Repeater {
                        model: [["kcm_regionandlang", "Langue et région", "preferences-desktop-locale"],
                                ["kcm_keyboard", "Clavier", "input-keyboard"],
                                ["kcm_componentchooser", "Applis par défaut (navigateur, lecteur…)", "preferences-desktop-default-applications"],
                                ["kcm_kscreen", "Écrans", "video-display"],
                                ["kcm_users", "Ton compte (photo, mot de passe)", "system-users"]].filter(k => Bienvenue.reglageExiste(k[0]))
                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            Layout.fillWidth: true
                            icon.name: modelData[2]
                            text: modelData[1]
                            onClicked: Bienvenue.ouvrirReglage(modelData[0])
                        }
                    }
                    QQC2.ItemDelegate {
                        Layout.fillWidth: true
                        visible: Bienvenue.programmeExiste("thomas-control")
                        icon.name: "thomas-os"
                        text: "Thomas Control : l'état du PC et tous les réglages"
                        onClicked: Bienvenue.lancer("thomas-control")
                    }
                }

                Etape {
                    titre: "C'est prêt !"
                    icone: "checkmark"
                    texte: "Quelques raccourcis à connaître :"
                    Point { icone: "input-keyboard"; couleur: Kirigami.Theme.textColor; texte: "<b>Alt+Espace</b> : le menu des applis" }
                    Point { icone: "input-keyboard"; couleur: Kirigami.Theme.textColor; texte: "<b>Alt+F2</b> : chercher une appli, un fichier, faire un calcul" }
                    Point { icone: "input-keyboard"; couleur: Kirigami.Theme.textColor; texte: "<b>Windows+E</b> : tes fichiers (Dolphin)" }
                    Point {
                        icone: "dialog-information"
                        couleur: Kirigami.Theme.textColor
                        texte: "Cet écran se rouvre quand tu veux : menu → « Bienvenue dans Thomas OS »."
                    }
                }
            }

            RowLayout {  // navigation
                Layout.fillWidth: true
                QQC2.Button {
                    text: "Précédent"
                    icon.name: "go-previous"
                    visible: etapes.currentIndex > 0
                    onClicked: etapes.currentIndex -= 1
                }
                Item { Layout.fillWidth: true }
                QQC2.Label {
                    text: "Étape " + (etapes.currentIndex + 1) + " sur " + fenetre.nbEtapes
                    color: Kirigami.Theme.disabledTextColor
                }
                QQC2.Button {
                    readonly property bool derniere: etapes.currentIndex === fenetre.nbEtapes - 1
                    text: derniere ? "Commencer" : "Suivant"
                    icon.name: derniere ? "checkmark" : "go-next"
                    highlighted: true
                    onClicked: {
                        if (!derniere) {
                            etapes.currentIndex += 1
                        } else {
                            fenetre.fini = true
                            Bienvenue.terminer()
                        }
                    }
                }
            }
        }
    }
}
