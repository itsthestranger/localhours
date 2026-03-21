import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configPage

    // These property aliases automatically bind to plasmoid configuration
    property alias cfg_dataFilePath: filePathField.text
    property alias cfg_maxSessionHours: maxHoursSpinBox.value

    Kirigami.FormLayout {
        id: formLayout
        anchors.left: parent.left
        anchors.right: parent.right

        // --- Data File Path ---
        RowLayout {
            Kirigami.FormData.label: i18n("Data file path:")
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: filePathField
                Layout.fillWidth: true
                placeholderText: i18n("Default: ~/.local/share/localhours/data.json")
                QQC2.ToolTip {
                    visible: parent.hovered
                    text: i18n("Leave empty to use the default path (~/.local/share/localhours/data.json).\nChange this if you want to store data in a synced folder (e.g. Nextcloud).")
                }
            }

            QQC2.Button {
                icon.name: "document-open"
                QQC2.ToolTip {
                    visible: hovered
                    text: i18n("Clear to use default path")
                }
                onClicked: filePathField.text = ""
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Session Failsafe")
        }

        // --- Max Session Hours ---
        ColumnLayout {
            Kirigami.FormData.label: i18n("Maximum session hours:")
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.SpinBox {
                    id: maxHoursSpinBox
                    from: 0
                    to: 72
                    editable: true
                    QQC2.ToolTip {
                        visible: parent.hovered
                        text: i18n("If a session runs longer than this without being stopped,\nit will be automatically capped. Set to 0 to disable.")
                    }                
                }

                QQC2.Label {
                    text: maxHoursSpinBox.value === 0
                        ? i18n("hours  (disabled)")
                        : i18n("hours")
                    color: maxHoursSpinBox.value === 0
                        ? Kirigami.Theme.neutralTextColor
                        : Kirigami.Theme.textColor
                }
            }

            QQC2.Label {
                text: maxHoursSpinBox.value === 0
                    ? i18n("⚠ No cap: timers will run indefinitely if not stopped manually.")
                    : i18n("Sessions exceeding this limit are capped on daemon startup or hourly check.")
                font: Kirigami.Theme.smallFont
                color: maxHoursSpinBox.value === 0
                    ? Kirigami.Theme.neutralTextColor
                    : Kirigami.Theme.disabledTextColor
                wrapMode: Text.WordWrap
                Layout.maximumWidth: 400
            }
        }

        // --- Spacer and note ---
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            Kirigami.FormData.label: ""
            text: i18n("Note: Changes to data file path or max session hours take effect after\nrestarting the backend daemon:\n  systemctl --user restart localhours")
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 450
        }
    }
}
