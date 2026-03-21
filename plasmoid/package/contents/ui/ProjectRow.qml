import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/**
 * ProjectRow: one project entry in the list.
 *
 * ● Project Name                          [▶/■]  [✏]  [🗑]
 *   Total: 2h 30m  Today: 45m
 *
 * NOTE: project is NOT a required property so that ListView delegates can
 * bind it with `project: root.projects[index]` without hitting Qt6's
 * model-role auto-binding rules (which fail for plain JS arrays).
 */
Item {
    id: rowRoot

    // NOT required — bound explicitly from the delegate
    property var project: null

    // Emitted when the user clicks the delete button.
    // The parent delegate connects this to open the confirm dialog.
    signal deleteRequested(var proj)

    implicitHeight: project ? (rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2) : 0
    height: implicitHeight
    visible: project !== null

    readonly property bool isActive:
        project !== null &&
        root.activeTracking !== null &&
        root.activeTracking.project_id === project.id

    readonly property string metricLabel:
        project ? root.buildMetricLabel(project) : ""

    // ── Bottom separator ───────────────────────────────────────────────────────
    Kirigami.Separator {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
    }

    RowLayout {
        id: rowLayout
        anchors {
            left:           parent.left
            right:          parent.right
            leftMargin:     Kirigami.Units.smallSpacing * 2
            rightMargin:    Kirigami.Units.smallSpacing
            verticalCenter: parent.verticalCenter
        }
        spacing: Kirigami.Units.smallSpacing

        // ── Colour dot ─────────────────────────────────────────────────────────
        Rectangle {
            width:  12
            height: 12
            radius: 6
            color:  (project && project.color) ? project.color : "#3498db"

            Rectangle {
                anchors.centerIn: parent
                width:  parent.width  + 6
                height: parent.height + 6
                radius: width / 2
                color:  "transparent"
                border.color: (project && project.color) ? project.color : "#3498db"
                border.width: 1.5
                opacity: rowRoot.isActive ? 0.7 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }

        // ── Name + metrics ──────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            QQC2.Label {
                text: (project && project.name) ? project.name : ""
                font.bold: rowRoot.isActive
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            QQC2.Label {
                visible: rowRoot.metricLabel !== ""
                text:    rowRoot.metricLabel
                font:    Kirigami.Theme.smallFont
                color:   Kirigami.Theme.disabledTextColor
                elide:   Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // ── Start / Stop ────────────────────────────────────────────────────────
        QQC2.ToolButton {
            icon.name:  rowRoot.isActive ? "media-playback-stop"
                                         : "media-playback-start"
            icon.color: rowRoot.isActive ? "#e74c3c" : "#2ecc71"
            enabled: project !== null
            onClicked: {
                if (!project) return
                if (rowRoot.isActive) {
                    root.cmdStopTracker()
                } else {
                    root.cmdStartTracker(project.id)
                }
            }
            QQC2.ToolTip {
                visible: parent.hovered
                text:    rowRoot.isActive ? i18n("Stop tracking")
                                          : i18n("Start tracking")
            }
        }

        // ── Edit ────────────────────────────────────────────────────────────────
        QQC2.ToolButton {
            icon.name: "document-edit"
            enabled:   project !== null
            onClicked: {
                if (!project) return
                root.editingProject = project
                root.inListView = false
            }
            QQC2.ToolTip {
                visible: parent.hovered
                text:    i18n("Edit project")
            }
        }

        // ── Delete ──────────────────────────────────────────────────────────────
        QQC2.ToolButton {
            icon.name:  "edit-delete"
            icon.color: Kirigami.Theme.negativeTextColor
            enabled:    project !== null
            onClicked: {
                if (!project) return
                rowRoot.deleteRequested(project)
            }
            QQC2.ToolTip {
                visible: parent.hovered
                text:    i18n("Delete project")
            }
        }
    }
}
