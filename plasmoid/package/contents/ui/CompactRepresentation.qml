import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/**
 * CompactRepresentation: the icon visible in the panel / system tray.
 *
 *  - Idle:   Standard "chronometer" icon in the theme's default colour.
 *  - Active: The icon is tinted green.
 */
Item {
    id: compactRoot

    readonly property bool isTracking: root.activeTracking !== null

    Layout.minimumWidth:   Kirigami.Units.iconSizes.small
    Layout.minimumHeight:  Kirigami.Units.iconSizes.small
    Layout.preferredWidth: height
    Layout.preferredHeight: height

    Kirigami.Icon {
        id: icon
        anchors.fill: parent
        source: "chronometer"
        color:  compactRoot.isTracking ? "#2ecc71" : Kirigami.Theme.textColor
        isMask: true
        smooth: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.expanded = !root.expanded
    }
}
