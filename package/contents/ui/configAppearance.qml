import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property string cfg_displayMode
    property int cfg_iconSize
    property alias cfg_columns: columnsBox.value
    property alias cfg_maxRows: maxRowsBox.value
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_showDescriptions: showDescriptions.checked
    property alias cfg_showHeading: showHeading.checked
    property alias cfg_showSearch: showSearch.checked
    property alias cfg_closeOnLaunch: closeOnLaunch.checked

    readonly property bool listMode: cfg_displayMode === "list"

    ButtonGroup { id: layoutGroup }

    Kirigami.FormLayout {
        RadioButton {
            ButtonGroup.group: layoutGroup
            Kirigami.FormData.label: i18n("Layout:")
            text: i18n("Grid (icon above the name)")
            checked: !page.listMode
            onToggled: if (checked) page.cfg_displayMode = "grid"
        }
        RadioButton {
            ButtonGroup.group: layoutGroup
            text: i18n("List (icon left of the name)")
            checked: page.listMode
            onToggled: if (checked) page.cfg_displayMode = "list"
        }

        ComboBox {
            id: iconSizeBox
            Kirigami.FormData.label: i18n("Icon size:")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Small (16 px)"), value: 16 },
                { text: i18n("Small-medium (22 px)"), value: 22 },
                { text: i18n("Medium (32 px)"), value: 32 },
                { text: i18n("Large (48 px)"), value: 48 },
                { text: i18n("Huge (64 px)"), value: 64 },
                { text: i18n("Enormous (96 px)"), value: 96 },
            ]
            onActivated: page.cfg_iconSize = currentValue
            Component.onCompleted: {
                const i = indexOfValue(page.cfg_iconSize);
                currentIndex = i >= 0 ? i : 3;
            }
        }

        SpinBox {
            id: columnsBox
            Kirigami.FormData.label: i18n("Columns:")
            from: 1
            to: 12
        }

        SpinBox {
            id: maxRowsBox
            Kirigami.FormData.label: i18n("Visible rows at most:")
            from: 1
            to: 20
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: showLabels
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("App names")
            enabled: !page.listMode
        }
        CheckBox {
            id: showDescriptions
            text: page.listMode ? i18n("Description, below the name") : i18n("Description, as a tooltip")
        }
        CheckBox {
            id: showHeading
            text: i18n("Title at the top of the popup")
        }
        CheckBox {
            id: showSearch
            text: i18n("A search field (type right after opening)")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        CheckBox {
            id: closeOnLaunch
            Kirigami.FormData.label: i18n("Behavior:")
            text: i18n("Close the popup after launching an app")
        }
    }
}
