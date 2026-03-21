import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

/**
 * SessionRow: displays a single recorded session with edit and delete controls.
 */
Item {
    id: sessionRowRoot

    required property var    session
    required property int    sessionIndex
    required property string projectId
    required property bool   isEditing

    signal requestEdit()
    signal requestDelete()
    signal commitEdit(string newStart, string newEnd)
    signal cancelEdit()

    implicitHeight: contentCol.implicitHeight + Kirigami.Units.smallSpacing * 2
    height: implicitHeight

    property string localStart: ""
    property string localEnd:   ""

    onIsEditingChanged: {
        if (isEditing) {
            localStart = _utcToLocalIso(session.start)
            localEnd   = _utcToLocalIso(session.end)
        }
    }

    function _utcToLocalIso(isoUtc) {
        if (!isoUtc) return ""
        var d = new Date(isoUtc)
        var pad = function(n) { return String(n).padStart(2, "0") }
        return d.getFullYear()  + "-" + pad(d.getMonth()+1) + "-" + pad(d.getDate()) +
               " " + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds())
    }

    function _localIsoToUtc(localIso) {
        var normalized = localIso.trim().replace(" ", "T")
        var d = new Date(normalized)
        if (isNaN(d.getTime())) return null
        return d.toISOString().replace(/\.\d{3}Z$/, "Z")
    }

    Kirigami.Separator {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        opacity: 0.4
    }

    ColumnLayout {
        id: contentCol
        anchors {
            left: parent.left;   leftMargin:  Kirigami.Units.smallSpacing
            right: parent.right; rightMargin: Kirigami.Units.smallSpacing
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        // ── Normal (read-only) mode ──────────────────────────────────────────
        RowLayout {
            visible: !isEditing
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    QQC2.Label {
                        text: root.formatTimestamp(session.start)
                        font: Kirigami.Theme.smallFont
                    }
                    QQC2.Label {
                        text: "→"
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                    QQC2.Label {
                        text: root.formatTimestamp(session.end)
                        font: Kirigami.Theme.smallFont
                    }
                }

                QQC2.Label {
                    text: {
                        var s = new Date(session.start)
                        var e = new Date(session.end)
                        return root.formatDuration(Math.max(0, Math.floor((e - s) / 1000)))
                    }
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                }
            }

            QQC2.ToolButton {
                icon.name: "document-edit"
                flat: true
                onClicked: sessionRowRoot.requestEdit()
                QQC2.ToolTip {
                    visible: parent.hovered
                    text:    i18n("Edit session timestamps")
                }
            }

            QQC2.ToolButton {
                icon.name: "edit-delete"
                flat: true
                icon.color: Kirigami.Theme.negativeTextColor
                onClicked: sessionRowRoot.requestDelete()
                QQC2.ToolTip {
                    visible: parent.hovered
                    text:    i18n("Delete this session")
                }
            }
        }

        // ── Edit mode ────────────────────────────────────────────────────────
        ColumnLayout {
            visible: isEditing
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: i18n("Format: YYYY-MM-DD HH:MM:SS  (local time)")
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                QQC2.Label { text: i18n("Start:") }
                QQC2.TextField {
                    id: startField
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    text: sessionRowRoot.localStart
                    onTextChanged: sessionRowRoot.localStart = text
                    background: Rectangle {
                        color: _validateTs(startField.text)
                            ? Kirigami.Theme.backgroundColor
                            : Qt.rgba(Kirigami.Theme.negativeTextColor.r,
                                      Kirigami.Theme.negativeTextColor.g,
                                      Kirigami.Theme.negativeTextColor.b, 0.15)
                        radius: 4
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                    }
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing
                QQC2.Label { text: i18n("End:  ") }
                QQC2.TextField {
                    id: endField
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                    text: sessionRowRoot.localEnd
                    onTextChanged: sessionRowRoot.localEnd = text
                    background: Rectangle {
                        color: _validateTs(endField.text)
                            ? Kirigami.Theme.backgroundColor
                            : Qt.rgba(Kirigami.Theme.negativeTextColor.r,
                                      Kirigami.Theme.negativeTextColor.g,
                                      Kirigami.Theme.negativeTextColor.b, 0.15)
                        radius: 4
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                    }
                }
            }

            QQC2.Label {
                visible: text !== ""
                text: {
                    if (!_validateTs(startField.text)) return i18n("⚠ Start time is not a valid date/time.")
                    if (!_validateTs(endField.text))   return i18n("⚠ End time is not a valid date/time.")
                    var s = new Date(startField.text.replace(" ","T"))
                    var e = new Date(endField.text.replace(" ","T"))
                    if (e <= s) return i18n("⚠ End time must be after start time.")
                    return ""
                }
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.Button {
                    text: i18n("Save")
                    icon.name: "dialog-ok"
                    enabled: _canCommit()
                    onClicked: {
                        var utcStart = sessionRowRoot._localIsoToUtc(startField.text)
                        var utcEnd   = sessionRowRoot._localIsoToUtc(endField.text)
                        if (utcStart && utcEnd)
                            sessionRowRoot.commitEdit(utcStart, utcEnd)
                    }
                }

                QQC2.Button {
                    text: i18n("Cancel")
                    icon.name: "dialog-cancel"
                    onClicked: sessionRowRoot.cancelEdit()
                }
            }
        }
    }

    function _validateTs(str) {
        if (!str || !str.trim()) return false
        var d = new Date(str.trim().replace(" ", "T"))
        return !isNaN(d.getTime())
    }

    function _canCommit() {
        if (!_validateTs(startField.text)) return false
        if (!_validateTs(endField.text))   return false
        var s = new Date(startField.text.replace(" ","T"))
        var e = new Date(endField.text.replace(" ","T"))
        return e > s
    }
}
