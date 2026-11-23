import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.brightnesscontrolplugin

// Luminosité de l'écran (portables, et écrans de bureau qui l'acceptent). Caché si le PC ne la gère pas.
RowLayout {
    ScreenBrightnessControl { id: ecran }
    readonly property bool disponible: ecran.isBrightnessAvailable === true
    Kirigami.Icon {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        source: "brightness-high"
    }
    PC3.Slider {
        Layout.fillWidth: true
        from: 1
        to: Math.max(1, ecran.brightnessMax || 1)
        value: ecran.brightness || 1
        onMoved: ecran.brightness = value
    }
}
