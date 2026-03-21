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
    property string activeProjectId: ""

    onProjectChanged: {
        if (!project) {
            activeProjectId = ""
            clearSessionEdit()
            return
        }
        var switchedProject = activeProjectId !== project.id
        activeProjectId = project.id
        if (switchedProject || (!isDirty && !saveInProgress)) {
            syncFromProject()
        }
        syncEditingSessionSelection()
    }

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
    property string editingSessionStartKey: ""
    property string editingSessionEndKey: ""
    property string editSessionStart:    ""
    property string editSessionEnd:      ""

    function clearSessionEdit() {
        editingSessionIndex = -1
        editingSessionStartKey = ""
        editingSessionEndKey = ""
    }

    function resolveSessionIndex(startIso, endIso, preferredIndex) {
        if (!project) return -1
        var sessions = project.sessions || []

        if (preferredIndex >= 0 && preferredIndex < sessions.length) {
            var preferred = sessions[preferredIndex]
            if (preferred.start === startIso && preferred.end === endIso) {
                return preferredIndex
            }
        }

        for (var i = 0; i < sessions.length; i++) {
            if (sessions[i].start === startIso && sessions[i].end === endIso) {
                return i
            }
        }
        return -1
    }

    function syncEditingSessionSelection() {
        if (editingSessionStartKey === "" && editingSessionEndKey === "") {
            editingSessionIndex = -1
            return
        }
        var resolved = resolveSessionIndex(
            editingSessionStartKey,
            editingSessionEndKey,
            editingSessionIndex
        )
        if (resolved >= 0) {
            editingSessionIndex = resolved
        } else {
            clearSessionEdit()
        }
    }

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
                    root.closeProjectEditor()
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

                        onRequestEdit: {
                            if (editRoot.editingSessionIndex === index) {
                                editRoot.clearSessionEdit()
                            } else {
                                editRoot.editingSessionIndex = index
                                editRoot.editingSessionStartKey = modelData.start
                                editRoot.editingSessionEndKey = modelData.end
                            }
                        }
                        onRequestDelete: {
                            sessionDeleteDialog.targetIndex = index
                            sessionDeleteDialog.targetStart = modelData.start
                            sessionDeleteDialog.targetEnd = modelData.end
                            sessionDeleteDialog.open()
                        }
                        onCommitEdit: function(newStart, newEnd) {
                            var resolvedIndex = editRoot.resolveSessionIndex(
                                modelData.start,
                                modelData.end,
                                sessionIndex
                            )
                            if (resolvedIndex >= 0) {
                                root.cmdUpdateSession(projectId, resolvedIndex, newStart, newEnd)
                            } else {
                                console.warn("[LocalHours] Session changed before save; ignoring stale edit commit.")
                            }
                            editRoot.clearSessionEdit()
                        }
                        onCancelEdit: editRoot.clearSessionEdit()
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
        property string targetStart: ""
        property string targetEnd: ""
        title: i18n("Delete Session")
        subtitle: i18n("Remove this session from the history? This cannot be undone.")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            var resolvedIndex = editRoot.resolveSessionIndex(targetStart, targetEnd, targetIndex)
            if (resolvedIndex >= 0 && editRoot.project) {
                root.cmdDeleteSession(editRoot.project.id, resolvedIndex)
            } else {
                console.warn("[LocalHours] Session changed before delete confirmation; ignoring stale delete.")
            }
            targetIndex = -1
            targetStart = ""
            targetEnd = ""
            editRoot.clearSessionEdit()
        }
        onRejected: {
            targetIndex = -1
            targetStart = ""
            targetEnd = ""
        }
    }
}
