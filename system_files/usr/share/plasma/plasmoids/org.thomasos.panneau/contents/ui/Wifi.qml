import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.networkmanagement as PlasmaNM

RowLayout {
    readonly property bool disponible: appareils.wirelessDeviceAvailable
    PlasmaNM.EnabledConnections { id: actives }
    PlasmaNM.Handler { id: reseau }
    PlasmaNM.AvailableDevices { id: appareils }
    Kirigami.Icon {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        source: actives.wirelessEnabled ? "network-wireless-on" : "network-wireless-off"
    }
    PC3.Label { text: "Wi-Fi"; Layout.fillWidth: true }
    PC3.Switch {
        checked: actives.wirelessEnabled
        onToggled: reseau.enableWireless(checked)
    }
}
