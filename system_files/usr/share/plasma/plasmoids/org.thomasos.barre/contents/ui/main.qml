/*
 * Barre Thomas OS : applis épinglées et ouvertes autour du logo T.
 * Deux exemplaires (moitie = gauche / droite) entourent le menu (logo T) ; chacun montre sa moitié
 * de la MÊME liste (bibliothèque officielle des tâches de KDE, org.kde.taskmanager).
 * Survol : zoom + halo rouge. Appli ouverte : trait rouge dessous (plus long si c'est la fenêtre active).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: racine

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property string moitie: Plasmoid.configuration.moitie
    readonly property int epaisseur: vertical ? width : height
    readonly property int moitieCompte: Math.ceil(taches.count / 2)

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.VirtualDesktopInfo { id: bureaux }
    TaskManager.ActivityInfo { id: activites }

    TaskManager.TasksModel {
        id: taches
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: false
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        filterByVirtualDesktop: true
        filterByActivity: true
        filterNotMinimized: false
        launcherList: Plasmoid.configuration.launchers
        virtualDesktop: bureaux.currentDesktop
        activity: activites.currentActivity
        screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
    }

    function visibleIci(i) {
        if (moitie === "gauche") return i < moitieCompte
        if (moitie === "droite") return i >= moitieCompte
        return true
    }

    fullRepresentation: Item {
        Layout.preferredWidth: racine.vertical ? racine.epaisseur : rangee.implicitWidth
        Layout.preferredHeight: racine.vertical ? rangee.implicitHeight : racine.epaisseur
        Layout.minimumWidth: Layout.preferredWidth
        Layout.minimumHeight: Layout.preferredHeight

        Grid {
            id: rangee
            anchors.centerIn: parent
            rows: racine.vertical ? -1 : 1
            columns: racine.vertical ? 1 : -1
            spacing: Math.round(racine.epaisseur * 0.08)

            Repeater {
                model: taches
                delegate: Item {
                    id: tache
                    required property int index
                    required property var model
                    readonly property bool ouverte: model.IsWindow === true
                    readonly property bool active: model.IsActive === true
                    readonly property real taille: Math.round(racine.epaisseur * 0.6)

                    visible: racine.visibleIci(index)
                    width: visible ? Math.round(racine.epaisseur * 1.1) : 0
                    height: visible ? racine.epaisseur : 0

                    // publie la position de l'icône : la fenêtre se réduit vers elle (effet KWin)
                    function publier() {
                        if (!visible) return
                        const p = mapToGlobal(0, 0)
                        taches.requestPublishDelegateGeometry(taches.makeModelIndex(index), Qt.rect(p.x, p.y, width, height), tache)
                    }
                    onXChanged: publier()
                    onVisibleChanged: publier()
                    Component.onCompleted: publier()

                    Rectangle {  // halo rouge au survol
                        anchors.centerIn: icone
                        width: tache.taille * 1.5
                        height: width
                        radius: width / 2
                        color: Kirigami.Theme.highlightColor
                        opacity: zone.containsMouse ? 0.22 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Kirigami.Icon {
                        id: icone
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: racine.vertical ? 0 : -1
                        width: tache.taille
                        height: tache.taille
                        source: tache.model.decoration
                        scale: zone.containsMouse ? 1.3 : 1
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {  // trait rouge sous une appli ouverte
                        visible: tache.ouverte
                        color: Kirigami.Theme.highlightColor
                        radius: 1
                        width: racine.vertical ? 2 : (tache.active ? tache.taille * 0.7 : tache.taille * 0.35)
                        height: racine.vertical ? (tache.active ? tache.taille * 0.7 : tache.taille * 0.35) : 2
                        anchors.horizontalCenter: racine.vertical ? undefined : parent.horizontalCenter
                        anchors.verticalCenter: racine.vertical ? parent.verticalCenter : undefined
                        anchors.bottom: racine.vertical ? undefined : parent.bottom
                        anchors.bottomMargin: 2
                        anchors.left: racine.vertical ? parent.left : undefined
                        anchors.leftMargin: 2
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }

                    PlasmaCore.ToolTipArea {
                        anchors.fill: parent
                        mainText: tache.model.display || ""
                        subText: tache.ouverte ? "" : "Épinglée"
                    }

                    MouseArea {
                        id: zone
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: (souris) => {
                            const mi = taches.makeModelIndex(tache.index)
                            if (souris.button === Qt.MiddleButton) {
                                taches.requestNewInstance(mi)
                            } else if (souris.button === Qt.RightButton) {
                                menu.visualParent = tache
                                menu.openRelative()
                            } else if (tache.ouverte && tache.active && (tache.model.ChildCount || 0) < 2) {
                                taches.requestToggleMinimized(mi)
                            } else {
                                taches.requestActivate(mi)
                            }
                        }
                    }

                    PlasmaExtras.Menu {
                        id: menu
                        placement: racine.vertical ? PlasmaExtras.Menu.RightPosedTopAlignedPopup : PlasmaExtras.Menu.TopPosedLeftAlignedPopup
                        PlasmaExtras.MenuItem {
                            text: "Nouvelle fenêtre"
                            icon: "window-new"
                            onClicked: taches.requestNewInstance(taches.makeModelIndex(tache.index))
                        }
                        PlasmaExtras.MenuItem {
                            visible: tache.ouverte
                            text: "Fermer"
                            icon: "window-close"
                            onClicked: taches.requestClose(taches.makeModelIndex(tache.index))
                        }
                    }
                }
            }
        }
    }
}
