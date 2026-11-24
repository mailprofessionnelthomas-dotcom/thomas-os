// Maquette du bureau avec le style en cours d'édition : fond, horloge, barre(s), fenêtres, menu et notification.
// Repère = la taille de ton écran (ecranL × ecranH, en pixels) mise à l'échelle : la barre, le menu et les fenêtres y ont
// leur vraie taille en pixels ; les widgets suivent la règle du moteur (placés sur 1920×1080 puis étirés à l'écran).
// Elle suit les règles du moteur (thomas-style) : mêmes dispositions que son script Plasma, mêmes couleurs que le
// schéma KDE qu'il génère.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ThomasStudio

Item {
    id: ap
    property bool menuOuvert: false
    property bool notification: false
    property real ecranL: Screen.width > 0 ? Screen.width : 1920
    property real ecranH: Screen.height > 0 ? Screen.height : 1080
    readonly property real sx: ecranL / 1920
    readonly property real sy: ecranH / 1080
    clip: true

    readonly property var s: Studio.brouillon
    readonly property var cat: Studio.catalogue
    function v(sec, cle, d) { const x = s && s[sec] ? s[sec][cle] : undefined; return (x === undefined || x === "") ? d : x }
    function n(sec, cle, d) { const x = parseFloat(v(sec, cle, "")); return isNaN(x) ? d : x }
    function oui(sec, cle) { return v(sec, cle, "non") === "oui" }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    function px(x) { return x * k }

    readonly property real k: width / ecranL
    // ----- couleurs -----
    readonly property color principale: v("couleurs", "principale", "#ff0000")
    readonly property color cBarre: v("couleurs", "barre", "#08080a")
    readonly property color cFen: v("couleurs", "fenetres", "#16171b")
    readonly property color cTexte: v("couleurs", "texte", "#f4f4f6")
    readonly property color cBord: v("couleurs", "bordure", v("couleurs", "principale", "#ff0000"))
    readonly property color cVue: mix(cFen, cTexte, 0.04)
    readonly property color cInactif: mix(cTexte, cFen, 0.45)
    readonly property color fondHaut: v("couleurs", "fond_haut", "#1a0003")
    readonly property color fondBas: v("bureau", "fond", "degrade") === "uni" ? fondHaut : v("couleurs", "fond_bas", "#050506")
    readonly property bool fondImage: v("bureau", "fond", "degrade") === "image" && Studio.fichierExiste(v("bureau", "fond_image", ""))
    readonly property color couleurHorloge: fondImage ? "white" : (lum(mix(fondHaut, fondBas, 0.3)) > 0.55 ? cTexte : "white")
    // ----- formes et effets -----
    readonly property real bw: n("effets", "epaisseur_bordure", 0)
    readonly property real coins: n("effets", "coins", 8)
    readonly property real coinsMenus: n("effets", "coins_menus", coins)
    readonly property real coinsFen: n("fenetres", "coins", coins)
    readonly property color fondBarre: alpha(cBarre, n("effets", "opacite", 85) / 100)
    readonly property color fondMenus: alpha(cBarre, n("effets", "opacite_menus", 85) / 100)
    // ----- texte : les applis utilisent « taille - 2 » points (comme le moteur) -----
    readonly property string police: cat.noms?.["texte.police"]?.[v("texte", "police", "manrope")] ?? "Manrope"
    readonly property real txt: Math.max(1, (n("texte", "taille", 12) - 2) * 4 / 3 * k)
    readonly property int poids: n("texte", "epaisseur_texte", 400)

    // ----- barres : mêmes dispositions que le script Plasma du moteur -----
    readonly property string dispo: v("barre", "disposition", "windows")
    readonly property real epBarre: n("barre", "epaisseur", 28)
    readonly property var g: {
        if (dispo === "capsule") return { bord: "bas", flot: true, fit: true, haut: false, ep: epBarre }
        if (dispo === "windows") return { bord: "bas", flot: false, fit: false, haut: false, ep: epBarre }
        if (dispo === "float") return { bord: "bas", flot: true, fit: true, haut: false, ep: epBarre }
        if (dispo === "vertical") return { bord: "gauche", flot: false, fit: false, haut: false, ep: epBarre + 6 }
        if (dispo === "macos") return { bord: "bas", flot: true, fit: true, haut: true, ep: epBarre + 12 }
        const bord = v("barre", "bord", "bas")
        return { bord: bord, flot: oui("barre", "flottante"), fit: v("barre", "longueur", "pleine") === "ajustee",
                 haut: oui("barre", "barre_haut") && bord !== "haut", ep: epBarre }
    }
    readonly property bool vertical: g.bord === "gauche" || g.bord === "droite"
    readonly property real marge: g.flot ? 8 : 0
    readonly property real hautFine: g.haut ? 24 : 0
    readonly property var applis: v("barre", "epingles", "").split(",").filter(a => a)
    readonly property var elements: {
        const e = [], a = applis
        const droite = () => { if (oui("barre", "panneau")) e.push({ t: "panneau" }); e.push({ t: "zone" }); e.push({ t: "horloge" }) }
        const taches = () => a.forEach((x, i) => e.push({ t: "appli", id: x, actif: i === 0 }))
        const logo = () => {
            const m = Math.ceil(a.length / 2)
            a.slice(0, m).forEach((x, i) => e.push({ t: "appli", id: x, actif: i === 0 }))
            e.push({ t: "logo" })
            a.slice(m).forEach(x => e.push({ t: "appli", id: x }))
        }
        if (dispo === "capsule") { logo(); droite() }
        else if (dispo === "windows") { e.push({ t: "espace" }); e.push({ t: "menu" }); taches(); e.push({ t: "espace" }); droite() }
        else if (dispo === "float") { e.push({ t: "menu" }); taches(); droite() }
        else if (dispo === "vertical") { e.push({ t: "menu" }); taches(); e.push({ t: "espace" }); droite() }
        else if (dispo === "macos") { taches() }
        else {
            if (!g.fit && v("barre", "alignement", "centre") === "centre") e.push({ t: "espace" })
            if (oui("barre", "logo_centre")) logo(); else { e.push({ t: "menu" }); taches() }
            if (oui("barre", "bureaux")) e.push({ t: "bureaux" })
            if (!g.fit) e.push({ t: "espace" })
            if (!g.haut) droite()
            if (oui("barre", "afficher_bureau")) e.push({ t: "montrer" })
        }
        return e
    }
    readonly property var elementsHaut: {
        const e = []
        if (dispo === "macos") e.push({ t: "menu" })
        e.push({ t: "appmenu" }); e.push({ t: "espace" })
        if (oui("barre", "panneau")) e.push({ t: "panneau" })
        e.push({ t: "zone" }); e.push({ t: "horloge" })
        return e
    }
    // longueur d'un élément le long de sa barre (repère 1920)
    function taille(t, ep, vert) {
        const c = ep - 8
        switch (t) {
        case "appli": case "menu": case "logo": return Math.round(c * 1.1) + 2
        case "panneau": return c
        case "zone": return c * 0.6 * 3 + 16
        case "horloge": return vert ? c : (oui("barre", "date") && ep >= 30 ? 88 : 56)
        case "bureaux": return c * 2.4
        case "montrer": return c * 0.6
        case "appmenu": return 300
        default: return 0
        }
    }
    readonly property real longueur: {
        const plein = vertical ? ecranH - hautFine - 2 * marge : ecranL - 2 * marge
        if (!g.fit) return plein
        let l = 8
        for (const e of elements) l += taille(e.t, g.ep, vertical)
        return Math.min(l, plein)
    }
    readonly property rect rb: {  // barre principale (en pixels de l'écran)
        const ep = g.ep, L = longueur
        if (g.bord === "bas") return Qt.rect((ecranL - L) / 2, ecranH - marge - ep, L, ep)
        if (g.bord === "haut") return Qt.rect((ecranL - L) / 2, marge, L, ep)
        return Qt.rect(g.bord === "gauche" ? marge : ecranL - marge - ep, hautFine + (ecranH - hautFine - L) / 2, ep, L)
    }
    readonly property rect zone: {  // place libre pour les fenêtres, le menu et les notifications
        const r = rb
        if (g.bord === "bas") return Qt.rect(0, hautFine, ecranL, r.y - hautFine)
        if (g.bord === "haut") return Qt.rect(0, r.y + r.height, ecranL, ecranH - r.y - r.height)
        if (g.bord === "gauche") return Qt.rect(r.x + r.width, hautFine, ecranL - r.x - r.width, ecranH - hautFine)
        return Qt.rect(0, hautFine, r.x, ecranH - hautFine)
    }
    // centre du bouton du menu le long de la barre : les espaces se partagent la place libre (comme dans Plasma)
    readonly property real centreMenu: {
        if (dispo === "macos") return 8 + taille("menu", 24, false) / 2
        const i = elements.findIndex(e => e.t === "menu" || e.t === "logo")
        const debut = vertical ? rb.y : rb.x
        if (i < 0) return debut
        let avant = 0, total = 0
        elements.forEach((e, j) => { const l = taille(e.t, g.ep, vertical); total += l; if (j < i) avant += l })
        const espaces = elements.filter(e => e.t === "espace").length
        const espacesAvant = elements.slice(0, i).filter(e => e.t === "espace").length
        const libre = Math.max(0, longueur - 8 - total)
        return debut + 4 + avant + (espaces ? libre * espacesAvant / espaces : 0) + taille(elements[i].t, g.ep, vertical) / 2
    }
    readonly property string typeMenu: v("menu", "type", "kickoff")
    readonly property rect rm: {  // menu ouvert
        if (typeMenu === "dash") return Qt.rect(0, 0, ecranL, ecranH)
        const w = typeMenu === "kickoff" ? n("menu", "largeur", 640) : 380
        const h = Math.min(typeMenu === "kickoff" ? n("menu", "hauteur", 560) : 540, ecranH - g.ep - 24)
        const m = 8, x = Math.min(Math.max(m, centreMenu - w / 2), ecranL - w - m)
        if (dispo === "macos") return Qt.rect(m, 24 + m, w, h)
        if (g.bord === "bas") return Qt.rect(x, rb.y - h - m, w, h)
        if (g.bord === "haut") return Qt.rect(x, rb.y + rb.height + m, w, h)
        const y = Math.min(Math.max(zone.y + m, centreMenu - h / 2), ecranH - h - m)
        return Qt.rect(g.bord === "gauche" ? rb.x + rb.width + m : rb.x - w - m, y, w, h)
    }
    readonly property rect rn: {  // notification
        const w = 380, h = 104, m = 12, p = v("notifications", "position", "bas-droite")
        const aDroite = p !== "bas-gauche" && p !== "haut-gauche", enHaut = p.startsWith("haut")
        return Qt.rect(aDroite ? zone.x + zone.width - w - m : zone.x + m, enHaut ? zone.y + m : zone.y + zone.height - h - m, w, h)
    }
    readonly property var widgetsBureau: {
        const out = []
        for (const m of v("bureau", "widgets", "").split(";")) {
            const p = m.trim().split(/\s+/)
            if (p.length === 5) out.push({ type: p[0], x: +p[1], y: +p[2], l: +p[3], h: +p[4] })
        }
        if (!out.length && oui("bureau", "horloge")) out.push({ type: "horloge-thomas", x: 48, y: 40, l: 620, h: 170 })
        return out
    }
    readonly property real tailleIcones: (cat.tailles_icones ?? [16, 22, 32, 48, 64, 128])[n("bureau", "taille_icones", 3)] ?? 48

    // ----- fond d'écran : image si elle existe, sinon dégradé ou couleur unie (même règle que le moteur) -----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: ap.fondHaut }
            GradientStop { position: 1; color: ap.fondBas }
        }
    }
    Image {
        anchors.fill: parent
        visible: ap.fondImage && status === Image.Ready
        source: ap.fondImage ? "file://" + ap.v("bureau", "fond_image", "") : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1920
        sourceSize.height: 1080
    }

    // ----- widgets du bureau -----
    Repeater {
        model: ap.widgetsBureau
        delegate: Item {  // placés sur 1920×1080 puis étirés à l'écran, comme le fait le moteur
            required property var modelData
            x: ap.px(modelData.x * ap.sx)
            y: ap.px(modelData.y * ap.sy)
            width: ap.px(modelData.l * ap.sx)
            height: ap.px(modelData.h * ap.sy)
            Column {  // grande horloge (même mise en page que le widget org.thomasos.horloge)
                visible: modelData.type === "horloge-thomas"
                spacing: ap.px(4)
                Text {
                    readonly property int heure: new Date().getHours()
                    text: (heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir").toUpperCase()
                    color: ap.couleurHorloge
                    font.family: ap.police
                    font.pixelSize: Math.max(1, ap.px(14))
                    font.letterSpacing: ap.px(3.5)
                }
                Row {
                    spacing: ap.px(20)
                    Text {
                        text: Qt.formatTime(new Date(), "HH:mm")
                        color: ap.couleurHorloge
                        font.family: ap.police
                        font.pixelSize: Math.max(1, ap.px(76))
                        font.weight: Font.Light
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, ap.px(1))
                        height: ap.px(52)
                        color: ap.couleurHorloge
                        opacity: 0.6
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: new Date().toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM").toUpperCase()
                        color: ap.couleurHorloge
                        font.family: ap.police
                        font.pixelSize: Math.max(1, ap.px(16))
                        font.weight: Font.Medium
                        font.letterSpacing: ap.px(3)
                    }
                }
            }
            Rectangle {  // autres widgets : cadre du thème, avec leur nom
                visible: modelData.type !== "horloge-thomas"
                anchors.fill: parent
                color: ap.fondMenus
                radius: ap.px(ap.coinsMenus)
                border.width: ap.bw > 0 ? Math.max(1, ap.px(ap.bw)) : 0
                border.color: ap.cBord
                Text {
                    anchors.centerIn: parent
                    text: modelData.type
                    color: ap.cTexte
                    font.family: ap.police
                    font.pixelSize: ap.txt
                }
            }
        }
    }
    Column {  // icônes du bureau
        x: ap.px(ap.zone.x + 8)
        y: ap.px(ap.zone.y + 8)
        visible: ap.oui("bureau", "icones")
        spacing: ap.px(8)
        Repeater {
            model: ap.v("bureau", "icones_liste", "").split(",").filter(a => a)
            delegate: Column {
                required property string modelData
                width: ap.px(Math.max(ap.tailleIcones + 36, ap.tailleIcones * 1.6))
                Kirigami.Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: ap.px(ap.tailleIcones)
                    height: width
                    source: Studio.appli(modelData).icone
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Studio.appli(modelData).nom
                    color: "white"
                    font.family: ap.police
                    font.pixelSize: ap.txt
                }
            }
        }
    }

    // ----- fenêtres : une en arrière-plan (opacité des fenêtres inactives), une active -----
    ApercuFenetre {
        theme: ap
        active: false
        titre: "Documents — Okular"
        x: ap.px(ap.zone.x + ap.zone.width * 0.47)
        y: ap.px(ap.zone.y + ap.zone.height * 0.07)
        width: ap.px(ap.zone.width * 0.42)
        height: ap.px(ap.zone.height * 0.5)
    }
    ApercuFenetre {
        theme: ap
        x: ap.px(ap.zone.x + ap.zone.width * 0.16)
        y: ap.px(ap.zone.y + ap.zone.height * 0.2)
        width: ap.px(ap.zone.width * 0.5)
        height: ap.px(ap.zone.height * 0.6)
    }

    // ----- barres -----
    Rectangle {  // barre fine du haut (macOS, ou barre libre avec « barre du haut »)
        visible: ap.g.haut
        width: parent.width
        height: ap.px(24)
        color: ap.fondBarre
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: ap.px(4)
            anchors.rightMargin: ap.px(4)
            spacing: 0
            Repeater {
                model: ap.elementsHaut
                delegate: ElementBarre { theme: ap; epaisseur: 24; vertical: false }
            }
        }
    }
    Rectangle {  // barre principale
        x: ap.px(ap.rb.x)
        y: ap.px(ap.rb.y)
        width: ap.px(ap.rb.width)
        height: ap.px(ap.rb.height)
        color: ap.fondBarre
        radius: ap.g.flot ? Math.min(ap.px(ap.coins), Math.min(width, height) / 2) : 0
        border.width: ap.bw > 0 ? Math.max(1, ap.px(ap.bw)) : 0
        border.color: ap.cBord
        GridLayout {
            anchors.fill: parent
            anchors.margins: ap.px(4)
            flow: ap.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: ap.vertical ? -1 : 1
            columns: ap.vertical ? 1 : -1
            rowSpacing: 0
            columnSpacing: 0
            Repeater {
                model: ap.elements
                delegate: ElementBarre { theme: ap }
            }
        }
    }

    // ----- menu ouvert -----
    Rectangle {
        id: menu
        visible: ap.menuOuvert
        x: ap.px(ap.rm.x)
        y: ap.px(ap.rm.y)
        width: ap.px(ap.rm.width)
        height: ap.px(ap.rm.height)
        color: ap.fondMenus
        radius: ap.typeMenu === "dash" ? 0 : ap.px(ap.coinsMenus)
        border.width: ap.bw > 0 && ap.typeMenu !== "dash" ? Math.max(1, ap.px(ap.bw)) : 0
        border.color: ap.cBord
        readonly property var favoris: ap.v("menu", "epingles", "").split(",").filter(a => a)
        readonly property bool enListe: ap.typeMenu === "kicker" || (ap.typeMenu === "kickoff" && ap.v("menu", "favoris", "grille") === "liste")
        readonly property bool categories: ap.typeMenu === "kickoff"
        readonly property bool catADroite: ap.v("menu", "cote", "gauche") === "droite"

        Rectangle {  // recherche
            id: recherche
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: ap.px(ap.typeMenu === "dash" ? 120 : 12) }
            height: ap.px(34)
            radius: ap.px(Math.min(ap.coinsMenus, 17))
            color: ap.alpha(ap.cTexte, 0.08)
            border.width: 1
            border.color: ap.alpha(ap.cTexte, 0.15)
            Text {
                anchors { left: parent.left; leftMargin: ap.px(12); verticalCenter: parent.verticalCenter }
                text: "Rechercher…"
                color: ap.cInactif
                font.family: ap.police
                font.pixelSize: ap.txt
            }
        }
        Column {  // catégories (menu complet)
            id: cats
            visible: menu.categories
            width: visible ? ap.px(180) : 0
            anchors { top: recherche.bottom; topMargin: ap.px(12) }
            x: menu.catADroite ? menu.width - width - ap.px(8) : ap.px(8)
            spacing: ap.px(2)
            Repeater {
                model: ["Favoris", "Toutes les applis", "Bureautique", "Internet", "Jeux", "Multimédia", "Système"]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: cats.width
                    height: ap.px(30)
                    radius: ap.px(4)
                    color: index === 0 ? ap.principale : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: ap.px(10); verticalCenter: parent.verticalCenter }
                        text: modelData
                        color: index === 0 ? (ap.lum(ap.principale) < 0.6 ? "white" : "black") : ap.cTexte
                        font.family: ap.police
                        font.weight: ap.poids
                        font.pixelSize: ap.txt
                    }
                }
            }
        }
        Grid {  // favoris
            id: grilleFavoris
            anchors { top: recherche.bottom; topMargin: ap.px(12) }
            x: menu.categories && !menu.catADroite ? cats.width + ap.px(20) : ap.px(ap.typeMenu === "dash" ? 120 : 12)
            width: menu.width - x - (menu.categories && menu.catADroite ? cats.width + ap.px(20) : ap.px(12))
            columns: menu.enListe ? 1 : Math.max(1, Math.floor(width / ap.px(ap.typeMenu === "dash" ? 150 : 104)))
            spacing: ap.px(8)
            Repeater {
                model: menu.favoris
                delegate: Item {
                    required property string modelData
                    readonly property bool enListe: menu.enListe
                    width: enListe ? grilleFavoris.width : ap.px(ap.typeMenu === "dash" ? 142 : 96)
                    height: enListe ? ap.px(34) : ap.px(ap.typeMenu === "dash" ? 120 : 84)
                    Kirigami.Icon {
                        id: ic
                        width: parent.enListe ? ap.px(24) : ap.px(ap.typeMenu === "dash" ? 64 : 44)
                        height: width
                        x: parent.enListe ? ap.px(6) : (parent.width - width) / 2
                        y: parent.enListe ? (parent.height - height) / 2 : ap.px(4)
                        source: Studio.appli(modelData).icone
                    }
                    Text {
                        x: parent.enListe ? ic.x + ic.width + ap.px(10) : 0
                        y: parent.enListe ? (parent.height - height) / 2 : ic.y + ic.height + ap.px(6)
                        width: parent.enListe ? parent.width - x : parent.width
                        horizontalAlignment: parent.enListe ? Text.AlignLeft : Text.AlignHCenter
                        elide: Text.ElideRight
                        text: Studio.appli(modelData).nom
                        color: ap.cTexte
                        font.family: ap.police
                        font.weight: ap.poids
                        font.pixelSize: ap.txt
                    }
                }
            }
        }
        Row {  // en bas : verrouiller, se déconnecter, éteindre
            anchors { right: parent.right; bottom: parent.bottom; margins: ap.px(14) }
            spacing: ap.px(16)
            Repeater {
                model: ["system-lock-screen", "system-log-out", "system-shutdown"]
                delegate: Kirigami.Icon {
                    required property string modelData
                    width: ap.px(20)
                    height: width
                    source: modelData
                    isMask: true
                    color: ap.cTexte
                }
            }
        }
    }

    // ----- notification -----
    Rectangle {
        visible: ap.notification
        x: ap.px(ap.rn.x)
        y: ap.px(ap.rn.y)
        width: ap.px(ap.rn.width)
        height: ap.px(ap.rn.height)
        color: ap.fondMenus
        radius: ap.px(ap.coinsMenus)
        border.width: ap.bw > 0 ? Math.max(1, ap.px(ap.bw)) : 0
        border.color: ap.cBord
        Kirigami.Icon {
            id: icNotif
            anchors { left: parent.left; leftMargin: ap.px(14); verticalCenter: parent.verticalCenter }
            width: ap.px(44)
            height: width
            source: "thomas-os"
        }
        Column {
            anchors { left: icNotif.right; leftMargin: ap.px(12); right: parent.right; rightMargin: ap.px(14); verticalCenter: parent.verticalCenter }
            spacing: ap.px(3)
            Text {
                text: "Thomas OS · maintenant"
                color: ap.cInactif
                font.family: ap.police
                font.pixelSize: ap.txt * 0.9
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: "Notification de test"
                color: ap.cTexte
                font.family: ap.police
                font.weight: Font.DemiBold
                font.pixelSize: ap.txt * 1.05
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: ap.cat.noms?.["notifications.position"]?.[ap.v("notifications", "position", "bas-droite")] + ", " + ap.v("notifications", "duree", "5") + " secondes"
                color: ap.cTexte
                font.family: ap.police
                font.weight: ap.poids
                font.pixelSize: ap.txt
            }
        }
    }
}
