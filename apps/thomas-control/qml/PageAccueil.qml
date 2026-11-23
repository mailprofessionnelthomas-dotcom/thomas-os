// Accueil : tableau de bord CPU, GPU, RAM, stockage en temps réel (capteurs de KDE, comme le moniteur système).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Capteurs
import ThomasControl

Kirigami.ScrollablePage {
    title: "Accueil"

    Capteurs.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 1000 }
    Capteurs.Sensor { id: gpu; sensorId: "gpu/all/usage"; updateRateLimit: 1000 }
    Capteurs.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: 1000 }
    Capteurs.Sensor { id: ramTexte; sensorId: "memory/physical/used"; updateRateLimit: 2000 }
    Capteurs.Sensor { id: disque; sensorId: "disk/all/usedPercent"; updateRateLimit: 5000 }

    function nombre(s) { return (s.value === undefined || s.value === null || isNaN(s.value)) ? -1 : s.value }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            text: Controle.coreDisponible ? "Thomas OS " + (Controle.infos.version || "") : "Thomas OS"
            level: 1
        }
        QQC2.Label {
            text: Controle.coreDisponible
                  ? "Canal de mises à jour : " + (Controle.infos.canal || "?") + " · variante " + (Controle.infos.gpu_variant || "?")
                  : "Service Thomas Core indisponible : les informations système ne sont pas affichées."
            opacity: 0.75
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: Controle.carte.conforme === "non"
            type: Kirigami.MessageType.Warning
            text: "Carte graphique détectée : " + (Controle.carte.detectees || "?") + ". Version conseillée : " + (Controle.carte.conseil || "?") + "."
        }

        GridLayout {
            columns: width > Kirigami.Units.gridUnit * 30 ? 2 : 1
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.largeSpacing
            Layout.fillWidth: true

            Carte { Layout.fillWidth: true; titre: "Processeur"; icone: "cpu"; valeur: nombre(cpu); onOuvrir: Controle.lancer("plasma-systemmonitor") }
            Carte { Layout.fillWidth: true; titre: "Carte graphique"; icone: "video-display"; valeur: nombre(gpu)
                    detail: Controle.carte.detectees ? "Détectée : " + Controle.carte.detectees : ""; onOuvrir: Controle.lancer("plasma-systemmonitor") }
            Carte { Layout.fillWidth: true; titre: "Mémoire"; icone: "memory"; valeur: nombre(ram)
                    detail: ramTexte.formattedValue || ""; onOuvrir: Controle.lancer("plasma-systemmonitor") }
            Carte { Layout.fillWidth: true; titre: "Stockage"; icone: "drive-harddisk"; valeur: nombre(disque); onOuvrir: Controle.lancer("filelight") }
        }
    }
}
