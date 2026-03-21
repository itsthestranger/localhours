import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

/**
 * FullRepresentation: the popup shown when the icon is clicked.
 *
 * Uses a StackView to navigate between:
 *   - ProjectListView   (the default "home" screen)
 *   - EditProjectView   (edit name/colour/prefs/sessions for one project)
 *
 * Navigation is driven by root.inListView / root.editingProject.
 */
Item {
    id: fullRoot

    // Preferred popup size
    Layout.minimumWidth:  Kirigami.Units.gridUnit * 22
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18
    Layout.preferredWidth:  Kirigami.Units.gridUnit * 26
    Layout.preferredHeight: Kirigami.Units.gridUnit * 28
    Layout.maximumHeight: Kirigami.Units.gridUnit * 40

    // StackView drives the navigation
    QQC2.StackView {
        id: stack
        anchors.fill: parent

        // We manually push/pop rather than using pushEnter/popExit animations
        // to keep it snappy on lower-end hardware.
        pushEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        }
        pushExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 }
        }
        popEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        }
        popExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150 }
        }

        initialItem: ProjectListView { }
    }

    // React to root.inListView and root.editingProject changes
    Connections {
        target: root

        function onInListViewChanged() {
            if (root.inListView) {
                if (stack.depth > 1) stack.pop()
            } else {
                if (stack.depth === 1) {
                    stack.push(editComponent)
                }
            }
        }

        function onEditingProjectChanged() {
            if (!root.inListView && stack.depth === 1) {
                stack.push(editComponent)
            } else if (!root.inListView && stack.depth > 1) {
                // Already on edit page; the EditProjectView watches editingProject directly
            }
        }
    }

    Component {
        id: editComponent
        EditProjectView { }
    }

    // Daemon not available warning banner
    PlasmaExtras.PlaceholderMessage {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        visible: !root.daemonAvailable
        iconName: "dialog-warning"
        text: i18n("Daemon not running")
        explanation: i18n("Start it with:\nsystemctl --user start localhours")
    }
}
