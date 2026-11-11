import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.iconthemes as KIconThemes
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property string cfg_source
    property string cfg_folder
    property string cfg_category
    property string cfg_icon
    property string cfg_iconStyle
    property alias cfg_rowIconCount: rowCountBox.value
    property string cfg_sortMode
    property alias cfg_title: titleField.text

    // Only used to list the menu categories.
    AppsSource {
        id: menu
        mode: "menuCategory"
    }

    // Two independent radio groups (otherwise every radio button of the form is exclusive).
    ButtonGroup { id: panelIconGroup }
    ButtonGroup { id: sourceGroup }

    Kirigami.FormLayout {
        TextField {
            id: titleField
            Kirigami.FormData.label: i18n("Title:")
            placeholderText: i18n("e.g. Messaging")
        }

        Button {
            Kirigami.FormData.label: i18n("Icon:")
            implicitWidth: Kirigami.Units.iconSizes.large + Kirigami.Units.largeSpacing * 2
            implicitHeight: implicitWidth
            icon.name: page.cfg_icon || "view-app-grid-symbolic"
            icon.width: Kirigami.Units.iconSizes.large
            icon.height: Kirigami.Units.iconSizes.large
            onClicked: iconDialog.open()

            KIconThemes.IconDialog {
                id: iconDialog
                onIconNameChanged: name => {
                    if (name) {
                        page.cfg_icon = name;
                    }
                }
            }
        }

        RadioButton {
            ButtonGroup.group: panelIconGroup
            Kirigami.FormData.label: i18n("In the panel:")
            text: i18n("The chosen icon")
            checked: page.cfg_iconStyle !== "composite" && page.cfg_iconStyle !== "row"
            onToggled: if (checked) page.cfg_iconStyle = "icon"
        }
        RadioButton {
            ButtonGroup.group: panelIconGroup
            text: i18n("A 2×2 tile with the first 4 apps")
            checked: page.cfg_iconStyle === "composite"
            onToggled: if (checked) page.cfg_iconStyle = "composite"
        }
        RowLayout {
            RadioButton {
                id: rowRadio
                ButtonGroup.group: panelIconGroup
                text: i18n("The first apps side by side:")
                checked: page.cfg_iconStyle === "row"
                onToggled: if (checked) page.cfg_iconStyle = "row"
            }
            SpinBox {
                id: rowCountBox
                enabled: rowRadio.checked
                from: 1
                to: 8
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RadioButton {
            id: folderRadio
            ButtonGroup.group: sourceGroup
            Kirigami.FormData.label: i18n("Apps:")
            text: i18n(".desktop links in a folder")
            checked: page.cfg_source !== "menuFavorites" && page.cfg_source !== "menuCategory"
            onToggled: if (checked) page.cfg_source = "folder"
        }

        RowLayout {
            enabled: folderRadio.checked
            TextField {
                id: folderField
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                text: page.cfg_folder
                placeholderText: "~/.local/share/app-groups/" + (titleField.text || i18n("<title>"))
                onTextEdited: page.cfg_folder = text
            }
            Button {
                icon.name: "document-open-folder"
                text: i18n("Choose…")
                onClicked: folderDialog.open()
            }
        }

        ComboBox {
            enabled: folderRadio.checked
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18n("Alphabetical order"), value: "alpha" },
                { text: i18n("Manual order (drag apps in the popup)"), value: "manual" },
            ]
            onActivated: page.cfg_sortMode = currentValue
            Component.onCompleted: currentIndex = page.cfg_sortMode === "manual" ? 1 : 0
        }

        Label {
            visible: folderRadio.checked && folderField.text === ""
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.Wrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: i18n("Empty: the folder named after the widget title, in ~/.local/share/app-groups/.")
        }

        RadioButton {
            id: categoryRadio
            ButtonGroup.group: sourceGroup
            text: i18n("A category of the application menu")
            checked: page.cfg_source === "menuCategory"
            onToggled: if (checked) page.cfg_source = "menuCategory"
        }

        ComboBox {
            id: categoryBox
            enabled: categoryRadio.checked
            Layout.minimumWidth: Kirigami.Units.gridUnit * 14
            model: menu.categories
            textRole: "name"
            valueRole: "name"
            displayText: currentIndex < 0 ? (page.cfg_category || i18n("Choose…")) : currentText
            onActivated: page.cfg_category = currentValue
            // Resync once the list arrives (loaded lazily).
            onModelChanged: currentIndex = indexOfValue(page.cfg_category)
            Component.onCompleted: currentIndex = indexOfValue(page.cfg_category)

            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: ListView.view ? ListView.view.width : implicitWidth
                text: modelData.name
                icon.name: modelData.icon
                highlighted: categoryBox.highlightedIndex === index
            }
        }

        RadioButton {
            ButtonGroup.group: sourceGroup
            text: i18n("Application menu favorites")
            checked: page.cfg_source === "menuFavorites"
            onToggled: if (checked) page.cfg_source = "menuFavorites"
        }
    }

    FolderDialog {
        id: folderDialog
        onAccepted: {
            const path = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""));
            page.cfg_folder = path;
            folderField.text = path;
        }
    }
}
