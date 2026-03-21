import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

/**
 * ProjectListView
 *
 * Layout (top to bottom in a ColumnLayout):
 *   ┌──────────────────────────────────┐
 *   │  Header bar               [+/✕] │  ← fixed height
 *   ├──────────────────────────────────┤
 *   │  Add-project form (optional)     │  ← sizeToContents, visible only when adding
 *   ├──────────────────────────────────┤
 *   │  Project list  OR  Placeholder   │  ← fillHeight, mutually exclusive visibility
 *   └──────────────────────────────────┘
 *
 * Key design decisions:
 *   - The add form is a SEPARATE ColumnLayout item that sizes to its content.
 *     It is NOT fillHeight. This prevents it from fighting with the list for space
 *     and prevents buttons from going off-screen.
 *   - The placeholder and the scrollview are mutually exclusive (only one visible at
 *     a time). Both declare Layout.fillHeight: true; QML ColumnLayout only allocates
 *     fill space to visible items, so whichever one is showing gets all remaining
 *     space.
 *   - The ListView delegate uses `root.projects[index]` instead of `modelData` to
 *     bypass Qt6's required-property model-role binding, which fails for plain JS
 *     arrays where the role name would have to be "project".
 */
Item {
    id: listViewRoot

    property bool   showAddForm:     false
    property string newProjectName:  ""
    property string newProjectColor: "#3498db"
    property var    pendingDeleteProject: null

    // ── Root layout ────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Header ──────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth:   true
            Layout.leftMargin:  Kirigami.Units.smallSpacing * 2
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin:   Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                level: 3
                text: i18n("LocalHours")
            }

            // Live tracking badge — hidden while add form is open to save space
            QQC2.Label {
                visible: root.activeTracking !== null && !listViewRoot.showAddForm
                text: {
                    if (!root.activeTracking) return ""
                    var p = root.projects.find(function(x) {
                        return x.id === root.activeTracking.project_id
                    })
                    return (p ? p.name : "?") + "  •  " +
                           root.formatDuration(root.elapsedSeconds)
                }
                color: "#2ecc71"
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Kirigami.Units.gridUnit * 10
            }

            Item {
                Layout.fillWidth: true
            }

            // [+] becomes [✕] while the form is open
            QQC2.ToolButton {
                icon.name: listViewRoot.showAddForm ? "dialog-cancel" : "list-add"
                onClicked: {
                    if (listViewRoot.showAddForm) {
                        listViewRoot.showAddForm    = false
                        listViewRoot.newProjectName = ""
                    } else {
                        listViewRoot.newProjectName  = ""
                        listViewRoot.newProjectColor = "#3498db"
                        listViewRoot.showAddForm     = true
                    }
                }
                QQC2.ToolTip {
                    visible: parent.hovered
                    text: listViewRoot.showAddForm ? i18n("Cancel") : i18n("Add new project")
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // ── Add-project form ─────────────────────────────────────────────────
        // This is a plain ColumnLayout that sizes to its own content — no
        // fillHeight here. It only appears when showAddForm is true.
        // When hidden, it takes zero space (visible: false is respected by
        // ColumnLayout for height allocation).
        ColumnLayout {
            id: addForm
            visible: listViewRoot.showAddForm
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing * 2
            spacing: Kirigami.Units.smallSpacing

            // ── Name row ──────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label { text: i18n("Name:") }

                QQC2.TextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: i18n("Project name…")
                    text: listViewRoot.newProjectName
                    onTextChanged: listViewRoot.newProjectName = text
                    // Auto-focus as soon as the form becomes visible
                    onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
                    Keys.onReturnPressed: addForm.doCreate()
                    Keys.onEscapePressed: {
                        listViewRoot.showAddForm    = false
                        listViewRoot.newProjectName = ""
                    }
                }
            }

            // ── Colour row ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label { text: i18n("Colour:") }

                // Preview swatch
                Rectangle {
                    width:  Kirigami.Units.iconSizes.small
                    height: Kirigami.Units.iconSizes.small
                    radius: 3
                    color:  listViewRoot.newProjectColor
                    border.color: Kirigami.Theme.disabledTextColor
                    border.width: 1
                }

                // Colour swatches — a simple Flow; compact enough to fit in one row
                // at typical popup widths (≥ 22*gridUnit).
                Flow {
                    Layout.fillWidth: true
                    spacing: 3

                    Repeater {
                        model: ["#e74c3c","#e67e22","#f1c40f","#2ecc71","#1abc9c",
                                "#3498db","#2980b9","#9b59b6","#8e44ad","#1793d1",
                                "#27ae60","#16a085","#d35400","#c0392b","#7f8c8d"]
                        delegate: Rectangle {
                            width: 18; height: 18; radius: 3
                            color: modelData
                            border.color: listViewRoot.newProjectColor === modelData
                                ? Kirigami.Theme.highlightColor : "transparent"
                            border.width: 2
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: listViewRoot.newProjectColor = modelData
                            }
                        }
                    }
                }
            }

            // ── Action buttons ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    text: i18n("Create")
                    icon.name: "dialog-ok"
                    enabled: listViewRoot.newProjectName.trim() !== ""
                    Layout.fillWidth: true
                    onClicked: addForm.doCreate()
                }

                QQC2.Button {
                    text: i18n("Cancel")
                    icon.name: "dialog-cancel"
                    onClicked: {
                        listViewRoot.showAddForm    = false
                        listViewRoot.newProjectName = ""
                    }
                }
            }

            function doCreate() {
                var name = listViewRoot.newProjectName.trim()
                if (name === "") return
                root.cmdAddProject(name, listViewRoot.newProjectColor)
                listViewRoot.showAddForm    = false
                listViewRoot.newProjectName = ""
            }
        }

        Kirigami.Separator {
            visible: listViewRoot.showAddForm
            Layout.fillWidth: true
        }

        // ── Empty-state placeholder ──────────────────────────────────────────
        // fillHeight: true — visible only when no projects AND form not open.
        // When invisible, ColumnLayout gives this zero height.
        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible: root.projects.length === 0 && !listViewRoot.showAddForm
            iconName: "chronometer"
            text: i18n("No projects yet")
            explanation: i18n("Click + to create your first project.")
            helpfulAction: Kirigami.Action {
                text: i18n("Add project")
                icon.name: "list-add"
                onTriggered: {
                    listViewRoot.newProjectName  = ""
                    listViewRoot.newProjectColor = "#3498db"
                    listViewRoot.showAddForm     = true
                }
            }
        }

        // ── Project list ─────────────────────────────────────────────────────
        // fillHeight: true — visible only when there are projects AND form not open.
        QQC2.ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            visible: root.projects.length > 0 && !listViewRoot.showAddForm
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            clip: true

            ListView {
                id: projectList
                model: root.projects
                clip: true

                // Use root.projects[index] instead of modelData.
                // This bypasses Qt6 required-property role-binding which fails for
                // plain JS arrays (the array has no "project" role, only "modelData").
                delegate: ProjectRow {
                    width: projectList.width
                    project: root.projects[index]
                    onDeleteRequested: function(proj) {
                        listViewRoot.pendingDeleteProject = proj
                        deleteConfirmDialog.open()
                    }
                }

                footer: Item { height: Kirigami.Units.smallSpacing }
            }
        }
    }

    // ── Delete confirmation dialog ────────────────────────────────────────────
    Kirigami.PromptDialog {
        id: deleteConfirmDialog
        title: i18n("Delete Project")
        subtitle: listViewRoot.pendingDeleteProject
            ? i18n("Delete \"%1\" and all its tracked time? This cannot be undone.",
                   listViewRoot.pendingDeleteProject.name)
            : ""
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            if (listViewRoot.pendingDeleteProject) {
                root.cmdDeleteProject(listViewRoot.pendingDeleteProject.id)
                listViewRoot.pendingDeleteProject = null
            }
        }
        onRejected: {
            listViewRoot.pendingDeleteProject = null
        }
    }
}
