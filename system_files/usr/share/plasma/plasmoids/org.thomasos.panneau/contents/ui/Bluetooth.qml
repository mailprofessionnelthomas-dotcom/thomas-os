import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.bluezqt as BluezQt

RowLayout {
    readonly property bool disponible: BluezQt.Manager.adapters.length > 0
    readonly property bool allume: !BluezQt.Manager.bluetoothBlocked
    Kirigami.Icon {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        source: parent.allume ? "network-bluetooth" : "network-bluetooth-inactive"
    }
    PC3.Label { text: "Bluetooth"; Layout.fillWidth: true }
    PC3.Switch {
        checked: parent.allume
        onToggled: {
            BluezQt.Manager.bluetoothBlocked = !checked
            for (let i = 0; i < BluezQt.Manager.adapters.length; ++i)
                BluezQt.Manager.adapters[i].powered = checked
        }
    }
}
