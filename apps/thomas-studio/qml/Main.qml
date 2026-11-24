// Thomas Studio : choisir un style, le modifier (à gauche), voir le résultat tout de suite (à droite),
// l'enregistrer, l'appliquer, l'annuler, le partager. Tout passe par Thomas Core.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import ThomasStudio

Kirigami.ApplicationWindow {
    id: fenetre
    property string styleDemande
    property string fichierCapture  // tests : photo de la fenêtre après 4 s, puis quitter
    property string aOuvrir: ""  // style choisi pendant qu'il reste des changements non enregistrés
    readonly property var st: Studio.brouillon
    function val(sec, cle) { return st[sec] ? (st[sec][cle] ?? "") : "" }
    function demanderOuverture(id) {
        if (Studio.modifie) {
            aOuvrir = id
            perdre.open()
        } else {
            Studio.ouvrir(id)
        }
    }

    title: "Thomas Studio"
    width: Kirigami.Units.gridUnit * 64
    height: Kirigami.Units.gridUnit * 40
    minimumWidth: Kirigami.Units.gridUnit * 44
    minimumHeight: Kirigami.Units.gridUnit * 28

    Component.onCompleted: Studio.ouvrir(styleDemande)
    Timer {
        running: fenetre.fichierCapture !== ""
        interval: 4000
        onTriggered: fenetre.contentItem.grabToImage(r => Qt.exit(r.saveToFile(fenetre.fichierCapture) ? 0 : 1))
    }

    Connections {
        target: Studio
        function onErreur(texte) { fenetre.showPassiveNotification(texte, "long") }
        function onMessage(texte) { fenetre.showPassiveNotification(texte) }
        function onCorrige(corrections) {
            bandeau.corrections = corrections
            bandeau.visible = corrections.length > 0
        }
    }

    FileDialog {
        id: choixImage
        title: "Image de fond"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: Studio.changer("bureau", "fond_image", Studio.cheminLocal(selectedFile))
    }
    FileDialog {
        id: choixImport
        title: "Importer un style"
        nameFilters: ["Styles Thomas OS (*.conf *.json)"]
        onAccepted: Studio.importer(selectedFile)
    }
    FileDialog {
        id: choixExport
        title: "Exporter le style"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "conf"
        nameFilters: ["Style Thomas OS (*.conf)"]
        onAccepted: Studio.exporter(selectedFile)
    }
    QQC2.Dialog {
        id: dlgNouveau
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Nouveau style"
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onOpened: { champNom.text = ""; champNom.forceActiveFocus() }
        onAccepted: Studio.nouveau(champNom.text)
        ColumnLayout {
            QQC2.Label { text: "Il part des réglages affichés. Donne-lui un nom :" }
            QQC2.TextField {
                id: champNom
                Layout.fillWidth: true
                placeholderText: "Mon style"
                onAccepted: dlgNouveau.accept()
            }
        }
    }
    QQC2.Dialog {
        id: perdre
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: "Changements non enregistrés"
        standardButtons: QQC2.Dialog.Discard | QQC2.Dialog.Cancel
        onDiscarded: { close(); Studio.ouvrir(fenetre.aOuvrir) }
        QQC2.Label { text: "Ouvrir un autre style fait perdre les changements en cours." }
    }
    QQC2.Dialog {
        id: dlgSupprimer
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: Studio.origine === "modifie" ? "Revenir à l'original ?" : "Retirer ce style ?"
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        onAccepted: Studio.supprimer()
        QQC2.Label {
            text: Studio.origine === "modifie" ? "Tes modifications de ce style sont mises de côté et il redevient comme à l'origine."
                                               : "Le style est retiré de la liste. Une copie reste dans ~/.config/thomas-os/corbeille."
            wrapMode: Text.WordWrap
        }
    }

    pageStack.initialPage: Kirigami.Page {
        id: page
        title: "Thomas Studio"
        actions: [
            Kirigami.Action {
                text: "Enregistrer"
                icon.name: "document-save"
                enabled: Studio.modifie && !Studio.occupe
                onTriggered: Studio.enregistrer(false)
            },
            Kirigami.Action {
                text: "Appliquer"
                icon.name: "dialog-ok-apply"
                enabled: Studio.idEdite !== "" && !Studio.occupe
                onTriggered: Studio.appliquer()
            },
            Kirigami.Action {
                text: "Annuler le dernier changement"
                icon.name: "edit-undo"
                enabled: Studio.peutAnnuler && !Studio.occupe
                onTriggered: Studio.annuler()
            },
            Kirigami.Action {
                text: "Nouveau…"
                icon.name: "document-new"
                onTriggered: dlgNouveau.open()
            },
            Kirigami.Action {
                text: "Importer…"
                icon.name: "document-import"
                onTriggered: choixImport.open()
            },
            Kirigami.Action {
                text: "Exporter…"
                icon.name: "document-export"
                enabled: !Studio.modifie && Studio.origine !== "nouveau"
                onTriggered: {
                    choixExport.currentFile = Studio.fichierExport()
                    choixExport.open()
                }
            },
            Kirigami.Action {
                text: Studio.origine === "modifie" ? "Revenir à l'original" : "Retirer ce style"
                icon.name: Studio.origine === "modifie" ? "edit-reset" : "edit-delete"
                enabled: Studio.origine === "modifie" || Studio.origine === "perso"
                onTriggered: dlgSupprimer.open()
            }
        ]

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                QQC2.Label { text: "Style" }
                QQC2.ComboBox {
                    id: choixStyle
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    model: Studio.styles
                    textRole: "nom"
                    valueRole: "id"
                    function position() { return Studio.styles.findIndex(x => x.id === Studio.idEdite) }
                    currentIndex: position()
                    displayText: Studio.origine === "nouveau" ? fenetre.val("style", "nom") + " (nouveau)" : currentText
                    onActivated: {
                        const id = currentValue
                        currentIndex = Qt.binding(position)
                        if (id !== Studio.idEdite) fenetre.demanderOuverture(id)
                    }
                }
                QQC2.Label {
                    text: ({ systeme: "fourni par Thomas OS", modifie: "fourni par Thomas OS, modifié par toi",
                             perso: "créé par toi", nouveau: "pas encore enregistré" })[Studio.origine] ?? ""
                    color: Kirigami.Theme.disabledTextColor
                }
                QQC2.Label {
                    visible: Studio.idEdite !== "" && Studio.idEdite === Studio.styleActuel
                    text: "· appliqué en ce moment"
                    color: Kirigami.Theme.positiveTextColor
                }
                Item { Layout.fillWidth: true }
                QQC2.BusyIndicator {
                    running: Studio.occupe
                    visible: running
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.5
                    Layout.preferredWidth: Layout.preferredHeight
                }
                QQC2.Label { text: "Nom" }
                QQC2.TextField {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    text: fenetre.val("style", "nom")
                    onEditingFinished: {
                        Studio.changer("style", "nom", text.trim())
                        text = Qt.binding(() => fenetre.val("style", "nom"))
                    }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: !Studio.coreDisponible
                type: Kirigami.MessageType.Error
                text: "Thomas Core ne répond pas : les styles ne peuvent être ni lus ni enregistrés."
            }
            Kirigami.InlineMessage {
                id: bandeau
                property var corrections: []
                Layout.fillWidth: true
                visible: false
                type: Kirigami.MessageType.Information
                showCloseButton: true
                text: "Corrigé à l'enregistrement : " + corrections.join(" · ")
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.largeSpacing

                // ----- réglages -----
                ColumnLayout {
                    Layout.fillHeight: true
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 19
                    spacing: 0

                    QQC2.TabBar {
                        id: onglets
                        Layout.fillWidth: true
                        QQC2.TabButton { text: "Couleurs"; width: implicitWidth }
                        QQC2.TabButton { text: "Formes"; width: implicitWidth }
                        QQC2.TabButton { text: "Barre"; width: implicitWidth }
                        QQC2.TabButton { text: "Menu"; width: implicitWidth }
                        QQC2.TabButton { text: "Fenêtres"; width: implicitWidth }
                        QQC2.TabButton { text: "Bureau"; width: implicitWidth }
                        QQC2.TabButton { text: "Texte"; width: implicitWidth }
                    }

                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: onglets.currentIndex

                        Onglet {
                            ReglageCouleur { sec: "couleurs"; cle: "principale"; Kirigami.FormData.label: "Couleur principale" }
                            ReglageCouleur { sec: "couleurs"; cle: "barre"; Kirigami.FormData.label: "Barre et menus" }
                            ReglageCouleur { sec: "couleurs"; cle: "fenetres"; Kirigami.FormData.label: "Fenêtres" }
                            ReglageCouleur { sec: "couleurs"; cle: "texte"; Kirigami.FormData.label: "Texte" }
                            ReglageCouleur {
                                sec: "couleurs"; cle: "bordure"; Kirigami.FormData.label: "Bordures"
                                auto: true; texteAuto: "Comme la principale"; couleurAuto: fenetre.val("couleurs", "principale")
                            }
                        }
                        Onglet {
                            ReglageNombre { sec: "effets"; cle: "coins"; unite: " px"; Kirigami.FormData.label: "Coins de la barre" }
                            ReglageNombre {
                                sec: "effets"; cle: "coins_menus"; unite: " px"; Kirigami.FormData.label: "Coins des menus"
                                auto: true; texteAuto: "Comme la barre"; valeurAuto: Number(fenetre.val("effets", "coins"))
                            }
                            ReglageNombre { sec: "effets"; cle: "epaisseur_bordure"; unite: " px"; Kirigami.FormData.label: "Épaisseur des bordures" }
                            ReglageNombre { sec: "effets"; cle: "opacite"; unite: " %"; Kirigami.FormData.label: "Opacité de la barre" }
                            ReglageNombre { sec: "effets"; cle: "opacite_menus"; unite: " %"; Kirigami.FormData.label: "Opacité des menus" }
                            ReglageNombre { sec: "effets"; cle: "flou"; Kirigami.FormData.label: "Flou derrière la barre" }
                            ReglageChoix { sec: "effets"; cle: "animations"; Kirigami.FormData.label: "Animations" }
                        }
                        Onglet {
                            ReglageChoix { sec: "barre"; cle: "disposition"; Kirigami.FormData.label: "Disposition" }
                            ReglageNombre { sec: "barre"; cle: "epaisseur"; unite: " px"; Kirigami.FormData.label: "Épaisseur" }
                            ReglageOuiNon { sec: "barre"; cle: "panneau"; Kirigami.FormData.label: "Panneau rapide (Wi-Fi, son…)" }
                            ReglageOuiNon { sec: "barre"; cle: "date"; Kirigami.FormData.label: "Date sous l'heure" }
                            Kirigami.Separator {
                                Kirigami.FormData.isSection: true
                                Kirigami.FormData.label: "Barre libre"
                                visible: fenetre.val("barre", "disposition") === "studio"
                            }
                            QQC2.Label {
                                visible: fenetre.val("barre", "disposition") !== "studio"
                                text: "Choisis la disposition « Celle du Studio » pour placer la barre comme tu veux."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                color: Kirigami.Theme.disabledTextColor
                            }
                            ReglageChoix { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "bord"; Kirigami.FormData.label: "Bord de l'écran" }
                            ReglageOuiNon { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "flottante"; Kirigami.FormData.label: "Flottante" }
                            ReglageChoix { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "longueur"; Kirigami.FormData.label: "Longueur" }
                            ReglageChoix { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "alignement"; Kirigami.FormData.label: "Applis" }
                            ReglageChoix { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "masquage"; Kirigami.FormData.label: "Masquage" }
                            ReglageOuiNon { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "logo_centre"; Kirigami.FormData.label: "Logo T au centre" }
                            ReglageOuiNon { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "bureaux"; Kirigami.FormData.label: "Bureaux virtuels" }
                            ReglageOuiNon { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "afficher_bureau"; Kirigami.FormData.label: "Bouton « bureau »" }
                            ReglageOuiNon { visible: fenetre.val("barre", "disposition") === "studio"; sec: "barre"; cle: "barre_haut"; Kirigami.FormData.label: "Barre fine en haut" }
                            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Applis épinglées" }
                            ChoixApplis { sec: "barre" }
                        }
                        Onglet {
                            ReglageChoix { sec: "menu"; cle: "type"; Kirigami.FormData.label: "Type de menu" }
                            QQC2.TextField {
                                Kirigami.FormData.label: "Raccourci clavier"
                                placeholderText: "Alt+Space"
                                text: fenetre.val("menu", "raccourci")
                                onEditingFinished: {
                                    Studio.changer("menu", "raccourci", text.trim())
                                    text = Qt.binding(() => fenetre.val("menu", "raccourci"))
                                }
                            }
                            ReglageNombre { visible: fenetre.val("menu", "type") === "kickoff"; sec: "menu"; cle: "largeur"; pas: 10; unite: " px"; Kirigami.FormData.label: "Largeur" }
                            ReglageNombre { visible: fenetre.val("menu", "type") === "kickoff"; sec: "menu"; cle: "hauteur"; pas: 10; unite: " px"; Kirigami.FormData.label: "Hauteur" }
                            ReglageChoix { visible: fenetre.val("menu", "type") === "kickoff"; sec: "menu"; cle: "favoris"; Kirigami.FormData.label: "Favoris" }
                            ReglageChoix { visible: fenetre.val("menu", "type") === "kickoff"; sec: "menu"; cle: "cote"; Kirigami.FormData.label: "Catégories" }
                            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Favoris du menu" }
                            ChoixApplis { sec: "menu" }
                        }
                        Onglet {
                            ReglageChoix { sec: "fenetres"; cle: "bordures"; Kirigami.FormData.label: "Bordures" }
                            ReglageNombre {
                                sec: "fenetres"; cle: "coins"; unite: " px"; Kirigami.FormData.label: "Coins"
                                auto: true; texteAuto: "Comme la barre"; valeurAuto: Number(fenetre.val("effets", "coins"))
                            }
                            ReglageChoix { sec: "fenetres"; cle: "ombre"; Kirigami.FormData.label: "Ombre" }
                            ReglageNombre { sec: "fenetres"; cle: "force_ombre"; unite: " %"; Kirigami.FormData.label: "Force de l'ombre" }
                            ReglageNombre { sec: "fenetres"; cle: "opacite_inactive"; unite: " %"; Kirigami.FormData.label: "Fenêtres en arrière-plan" }
                            ReglageNombre { sec: "fenetres"; cle: "opacite_deplacement"; unite: " %"; Kirigami.FormData.label: "Pendant un déplacement" }
                            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Boutons des fenêtres" }
                            BoutonsFenetre {}
                            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Notifications" }
                            ReglageChoix { sec: "notifications"; cle: "position"; Kirigami.FormData.label: "Position" }
                            ReglageNombre { sec: "notifications"; cle: "duree"; unite: " s"; Kirigami.FormData.label: "Durée" }
                        }
                        Onglet {
                            ReglageChoix { sec: "bureau"; cle: "fond"; Kirigami.FormData.label: "Fond d'écran" }
                            RowLayout {
                                Kirigami.FormData.label: "Image"
                                visible: fenetre.val("bureau", "fond") === "image"
                                QQC2.Label {
                                    text: fenetre.val("bureau", "fond_image").split("/").pop() || "aucune"
                                    elide: Text.ElideMiddle
                                    Layout.maximumWidth: Kirigami.Units.gridUnit * 10
                                }
                                QQC2.Button { text: "Choisir…"; icon.name: "document-open"; onClicked: choixImage.open() }
                            }
                            ReglageCouleur {
                                visible: fenetre.val("bureau", "fond") !== "image"
                                sec: "couleurs"; cle: "fond_haut"
                                Kirigami.FormData.label: fenetre.val("bureau", "fond") === "uni" ? "Couleur" : "Haut du dégradé"
                            }
                            ReglageCouleur {
                                visible: fenetre.val("bureau", "fond") === "degrade"
                                sec: "couleurs"; cle: "fond_bas"; Kirigami.FormData.label: "Bas du dégradé"
                            }
                            ReglageOuiNon { sec: "bureau"; cle: "horloge"; Kirigami.FormData.label: "Grande horloge" }
                            ReglageOuiNon { sec: "bureau"; cle: "icones"; Kirigami.FormData.label: "Icônes sur le bureau" }
                            ReglageNombre {
                                visible: fenetre.val("bureau", "icones") === "oui"
                                sec: "bureau"; cle: "taille_icones"; Kirigami.FormData.label: "Taille des icônes"
                                etiquettes: (Studio.catalogue.tailles_icones ?? []).map(t => t + " px")
                            }
                            QQC2.Label {
                                text: "Les widgets du bureau se placent pour l'instant avec le Studio web (studio/index.html)."
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }
                        Onglet {
                            ReglageChoix { sec: "texte"; cle: "police"; Kirigami.FormData.label: "Police" }
                            ReglageNombre { sec: "texte"; cle: "taille"; unite: " pt"; Kirigami.FormData.label: "Taille" }
                            ReglageNombre {
                                sec: "texte"; cle: "epaisseur_texte"; pas: 100; Kirigami.FormData.label: "Épaisseur"
                                etiquettes: ({ 300: "Fine", 400: "Normale", 500: "Moyenne" })
                            }
                            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Système" }
                            ReglageChoix { sec: "systeme"; cle: "icones"; Kirigami.FormData.label: "Pack d'icônes" }
                            ReglageChoix { sec: "systeme"; cle: "curseur"; Kirigami.FormData.label: "Curseur" }
                            ReglageNombre { sec: "systeme"; cle: "taille_curseur"; unite: " px"; Kirigami.FormData.label: "Taille du curseur" }
                        }
                    }
                }

                // ----- aperçu -----
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
                    spacing: Kirigami.Units.smallSpacing

                    Apercu {
                        id: apercu
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * apercu.EH / apercu.EL
                        menuOuvert: voirMenu.checked
                        notification: voirNotif.checked
                    }
                    RowLayout {
                        QQC2.CheckBox { id: voirMenu; text: "Menu ouvert" }
                        QQC2.CheckBox { id: voirNotif; text: "Notification"; checked: true }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                        text: "Maquette : elle suit les mêmes règles que Thomas OS. « Appliquer » montre le vrai résultat, « Annuler » revient en arrière."
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
