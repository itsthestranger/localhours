import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

/**
 * EditProjectView: pushed onto the StackView when the user clicks ✏ on a project.
 */
Item {
    id: editRoot

    property var project: root.editingProject

    property string editName:  project ? project.name  : ""
    property string editColor: project ? project.color : "#3498db"
    property bool   showTotal: project ? ((project.display_preferences || {}).show_total_time || false) : true
    property bool   showToday: project ? ((project.display_preferences || {}).show_today       || false) : true
    property bool   showWeek:  project ? ((project.display_preferences || {}).show_week        || false) : false
    property bool   showMonth: project ? ((project.display_preferences || {}).show_month       || false) : false
    property bool   saveInProgress: false

    property string savedName:  ""
    property string savedColor: "#3498db"
    property bool   savedShowTotal: true
    property bool   savedShowToday: true
    property bool   savedShowWeek:  false
    property bool   savedShowMonth: false

    onProjectChanged: syncFromProject()

    function syncFromProject() {
        if (!project) return
        var prefs = project.display_preferences || {}
        editName  = project.name
        editColor = project.color
        showTotal = prefs.show_total_time || false
        showToday = prefs.show_today       || false
        showWeek  = prefs.show_week        || false
        showMonth = prefs.show_month       || false
        markCurrentStateSaved()
    }

    function markCurrentStateSaved() {
        savedName = editName
        savedColor = editColor
        savedShowTotal = showTotal
        savedShowToday = showToday
        savedShowWeek = showWeek
        savedShowMonth = showMonth
    }

    property bool isDirty: {
        if (!project) return false
        return editName  !== savedName  ||
               editColor !== savedColor ||
               showTotal !== savedShowTotal ||
               showToday !== savedShowToday ||
               showWeek  !== savedShowWeek ||
               showMonth !== savedShowMonth
    }

    function save() {
        if (!project || !isDirty || saveInProgress) return
        var targetProjectId = project.id
        saveInProgress = true
        root.cmdUpdateProject(targetProjectId, {
            name:  editName,
            color: editColor,
            display_preferences: {
                show_total_time: showTotal,
                show_today:      showToday,
                show_week:       showWeek,
                show_month:      showMonth
            }
        }, function(result) {
            editRoot.saveInProgress = false
            if (result && result.ok === true && editRoot.project && editRoot.project.id === targetProjectId) {
                editRoot.markCurrentStateSaved()
            }
        })
    }

    property int    editingSessionIndex: -1
    property string editSessionStart:    ""
    property string editSessionEnd:      ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // --- Header ---
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin:  Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.topMargin:   Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.ToolButton {
                icon.name: "arrow-left"
                onClicked: {
                    if (editRoot.isDirty) editRoot.save()
                    root.inListView = true
                    root.editingProject = null
                }
                QQC2.ToolTip {
                    visible: parent.hovered
                    text:    i18n("Back to project list")
                }
            }

            PlasmaExtras.Heading {
                level: 4
                text: project ? i18n("Edit: %1", project.name) : i18n("Edit Project")
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            QQC2.Label {
                visible: editRoot.isDirty && !editRoot.saveInProgress
                text: i18n("Unsaved")
                color: Kirigami.Theme.neutralTextColor
                font: Kirigami.Theme.smallFont
            }

            QQC2.Label {
                visible: editRoot.saveInProgress
                text: i18n("Saving...")
                color: Kirigami.Theme.neutralTextColor
                font: Kirigami.Theme.smallFont
            }

            QQC2.ToolButton {
                icon.name: "document-save"
                enabled: editRoot.isDirty && !editRoot.saveInProgress
                onClicked: editRoot.save()
                QQC2.ToolTip {
                    visible: parent.hovered
                    text:    i18n("Save changes")
                }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true }

        // --- Scrollable content ---
        QQC2.ScrollView {
            Layout.fillWidth:  true
            Layout.fillHeight: true
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: Kirigami.Units.smallSpacing

                // ── General Settings ─────────────────────────────────────────

                Kirigami.ListSectionHeader {
                    Layout.fillWidth: true
                    text: i18n("General Settings")
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin:  Kirigami.Units.smallSpacing * 2
                    Layout.rightMargin: Kirigami.Units.smallSpacing * 2
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: i18n("Name:")
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    }
                    QQC2.TextField {
                        Layout.fillWidth: true
                        text: editRoot.editName
                        onTextChanged: editRoot.editName = text
                        onEditingFinished: editRoot.save()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin:  Kirigami.Units.smallSpacing * 2
                    Layout.rightMargin: Kirigami.Units.smallSpacing * 2
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: i18n("Colour:")
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 6
                    }

                    Rectangle {
                        width:  Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                        radius: 3
                        color:  editRoot.editColor
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                    }

                    QQC2.TextField {
                        id: colorHexField
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                        text: editRoot.editColor
                        onEditingFinished: {
                            var val = text.startsWith("#") ? text : "#" + text
                            if (/^#[0-9a-fA-F]{6}$/.test(val)) {
                                editRoot.editColor = val
                                editRoot.save()
                            }
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.smallSpacing * 2 +
                                       Kirigami.Units.gridUnit * 6 +
                                       Kirigami.Units.smallSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing * 2
                    spacing: 4

                    Repeater {
                        model: [
                            "#e74c3c","#e67e22","#f1c40f","#2ecc71","#1abc9c",
                            "#3498db","#2980b9","#9b59b6","#8e44ad","#1793d1",
                            "#27ae60","#16a085","#d35400","#c0392b","#7f8c8d"
                        ]
                        delegate: Rectangle {
                            width: 16; height: 16; radius: 3
                            color: modelData
                            border.color: editRoot.editColor === modelData
                                ? Kirigami.Theme.highlightColor : "transparent"
                            border.width: 2
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    editRoot.editColor = modelData
                                    colorHexField.text = modelData
                                    editRoot.save()
                                }
                            }
                        }
                    }
                }

                // ── Display Preferences ──────────────────────────────────────

                Kirigami.ListSectionHeader {
                    Layout.fillWidth: true
                    text: i18n("Displayed Metrics")
                }

                Repeater {
                    model: [
                        { label: i18n("Show total time"),      get: function(){ return editRoot.showTotal }, set: function(v){ editRoot.showTotal = v } },
                        { label: i18n("Show today's time"),    get: function(){ return editRoot.showToday }, set: function(v){ editRoot.showToday = v } },
                        { label: i18n("Show this week's time"), get: function(){ return editRoot.showWeek },  set: function(v){ editRoot.showWeek  = v } },
                        { label: i18n("Show this month's time"), get: function(){ return editRoot.showMonth }, set: function(v){ editRoot.showMonth = v } }
                    ]
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin:  Kirigami.Units.smallSpacing * 2
                        Layout.rightMargin: Kirigami.Units.smallSpacing * 2

                        QQC2.Label {
                            text: modelData.label
                            Layout.fillWidth: true
                        }
                        QQC2.Switch {
                            checked: modelData.get()
                            onToggled: {
                                modelData.set(checked)
                                editRoot.save()
                            }
                        }
                    }
                }

                // ── Session History ──────────────────────────────────────────

                Kirigami.ListSectionHeader {
                    Layout.fillWidth: true
                    text: {
                        if (!editRoot.project) return i18n("Session History")
                        var n = (editRoot.project.sessions || []).length
                        return i18n("Session History (%1 sessions)", n)
                    }
                }

                Repeater {
                    model: editRoot.project ? editRoot.project.sessions : []
                    delegate: SessionRow {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.leftMargin:  Kirigami.Units.smallSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing

                        session:       modelData
                        sessionIndex:  index
                        projectId:     editRoot.project ? editRoot.project.id : ""
                        isEditing:     editRoot.editingSessionIndex === index

                        onRequestEdit:   editRoot.editingSessionIndex =
                            (editRoot.editingSessionIndex === index ? -1 : index)
                        onRequestDelete: {
                            sessionDeleteDialog.targetIndex = index
                            sessionDeleteDialog.open()
                        }
                        onCommitEdit: function(newStart, newEnd) {
                            root.cmdUpdateSession(projectId, sessionIndex, newStart, newEnd)
                            editRoot.editingSessionIndex = -1
                        }
                        onCancelEdit: editRoot.editingSessionIndex = -1
                    }
                }

                QQC2.Label {
                    visible: !editRoot.project || (editRoot.project.sessions || []).length === 0
                    text: i18n("No sessions recorded yet.")
                    color: Kirigami.Theme.disabledTextColor
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.topMargin:    Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Item { Layout.preferredHeight: Kirigami.Units.gridUnit }
            }
        }
    }

    Kirigami.PromptDialog {
        id: sessionDeleteDialog
        property int targetIndex: -1
        title: i18n("Delete Session")
        subtitle: i18n("Remove this session from the history? This cannot be undone.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            if (targetIndex >= 0 && editRoot.project)
                root.cmdDeleteSession(editRoot.project.id, targetIndex)
            targetIndex = -1
        }
        onRejected: targetIndex = -1
    }
}
