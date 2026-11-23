import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.volume

RowLayout {
    readonly property var sortie: PreferredDevice.sink
    readonly property bool disponible: sortie !== null && sortie !== undefined
    Kirigami.Icon {
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        source: parent.disponible && !parent.sortie.muted ? "audio-volume-high" : "audio-volume-muted"
        MouseArea {
            anchors.fill: parent
            onClicked: if (parent.parent.disponible) parent.parent.sortie.muted = !parent.parent.sortie.muted
        }
    }
    PC3.Slider {
        Layout.fillWidth: true
        from: PulseAudio.MinimalVolume
        to: PulseAudio.NormalVolume
        value: parent.disponible ? parent.sortie.volume : 0
        onMoved: if (parent.disponible) parent.sortie.volume = value
    }
}
