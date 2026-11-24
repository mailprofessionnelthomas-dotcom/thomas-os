// Thomas Control : fenêtre principale. Barre latérale (icônes + noms) à gauche, contenu à droite.
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import ThomasControl

Kirigami.ApplicationWindow {
    id: fenetre
    title: "Thomas Control"
    width: Kirigami.Units.gridUnit * 56
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 34
    minimumHeight: Kirigami.Units.gridUnit * 24

    // Catégories de la vision. kcms = pages de réglages KDE ouvertes telles quelles (on ne les recode pas).
    readonly property var categories: [
        { nom: "Accueil", icone: "go-home", page: "accueil" },
        { nom: "Système", icone: "computer", page: "systeme" },
        { nom: "Apparence", icone: "preferences-desktop-theme-global", page: "apparence" },
        { nom: "Matériel", icone: "preferences-devices-tree", kcms: [
            ["kcm_kscreen", "Écrans", "Résolution, échelle, fréquence"], ["kcm_pulseaudio", "Son", "Sorties, entrées, volumes"],
            ["kcm_mouse", "Souris", "Vitesse, boutons"], ["kcm_touchpad", "Pavé tactile", ""],
            ["kcm_keyboard", "Clavier", "Disposition, répétition"], ["kcm_gamecontroller", "Manettes", ""],
            ["kcm_printer_manager", "Imprimantes", ""]] },
        { nom: "Réseau", icone: "network-wired", kcms: [
            ["kcm_networkmanagement", "Connexions", "Wi-Fi, filaire, VPN"], ["kcm_bluetooth", "Bluetooth", "Appareils"],
            ["kcm_proxy", "Proxy", ""]] },
        { nom: "Applications", icone: "applications-all", kcms: [
            ["kcm_componentchooser", "Applis par défaut", "Navigateur, mail, lecteur…"],
            ["kcm_autostart", "Démarrage automatique", "Ce qui se lance à l'ouverture de session"],
            ["kcm_filetypes", "Types de fichiers", ""], ["kcm_flatpak", "Permissions des applis", "Flatpak"]] },
        { nom: "Sécurité", icone: "security-high", kcms: [
            ["kcm_users", "Comptes", "Utilisateurs, mot de passe"], ["kcm_screenlocker", "Verrouillage", ""],
            ["kcm_firewall", "Pare-feu", ""], ["kcm_kwallet5", "Portefeuille", ""]] },
        { nom: "Stockage", icone: "drive-harddisk", kcms: [
            ["kcm_device_automounter", "Disques amovibles", "Montage automatique"], ["kcm_trash", "Corbeille", ""]],
          programmes: [["filelight", "Occupation du disque"], ["partitionmanager", "Partitions"]] },
        { nom: "Performances", icone: "speedometer", programmes: [["plasma-systemmonitor", "Moniteur système (processus, CPU, RAM, GPU, réseau, disques)"]] },
        { nom: "Gaming", icone: "input-gaming", bientot: "Mode jeu automatique : prévu (phase 8), mesuré avant/après." },
        { nom: "Énergie", icone: "battery-full", kcms: [["kcm_powerdevilprofilesconfig", "Économie d'énergie", "Veille, écran"]] },
        { nom: "Maintenance", icone: "tools", page: "systeme" },
        { nom: "Mises à jour", icone: "update-none", page: "systeme" }
    ]

    globalDrawer: Kirigami.GlobalDrawer {
        modal: false
        collapsible: false
        showHeaderWhenCollapsed: true
        header: Kirigami.AbstractApplicationHeader {
            contentItem: Kirigami.Heading {
                text: "Thomas Control"
                level: 2
                leftPadding: Kirigami.Units.largeSpacing
            }
        }
        actions: fenetre.categories.map(c => actionCategorie.createObject(fenetre, { categorie: c }))
    }

    Component {
        id: actionCategorie
        Kirigami.Action {
            property var categorie
            text: categorie.nom
            icon.name: categorie.icone
            onTriggered: fenetre.ouvrir(categorie)
        }
    }

    function ouvrir(c) {
        const pages = { accueil: "PageAccueil.qml", systeme: "PageSysteme.qml", apparence: "PageApparence.qml" }
        if (c.page) {
            pageStack.replace(Qt.resolvedUrl(pages[c.page]), { title: c.nom })
        } else {
            pageStack.replace(Qt.resolvedUrl("PageCategorie.qml"), { title: c.nom, categorie: c })
        }
    }

    Connections {
        target: Controle
        function onErreur(message) { fenetre.showPassiveNotification(message) }
    }

    // page d'accueil déclarée ici (et non créée à partir d'un fichier) : elle n'est jamais orpheline
    pageStack.initialPage: PageAccueil {}
}
