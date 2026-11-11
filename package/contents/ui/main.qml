import QtQuick
import QtQuick.Layouts
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property string homePath: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")
    // Empty folder setting = ~/.local/share/app-groups/<title>
    readonly property string folderPath: {
        const p = cfg.folder;
        if (!p) {
            return homePath + "/.local/share/app-groups/" + cfg.title;
        }
        return p.startsWith("~") ? homePath + p.slice(1) : p;
    }

    readonly property bool listMode: cfg.displayMode === "list"
    readonly property bool showLabels: listMode || cfg.showLabels
    readonly property bool compositeIcon: cfg.iconStyle === "composite" && apps.count > 0
    readonly property bool rowIcon: cfg.iconStyle === "row" && apps.count > 0
    readonly property int rowIconCount: Math.max(1, Math.min(cfg.rowIconCount, apps.count))
    readonly property bool verticalPanel: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // Apps can be dropped on folder groups (creates a link) and on favorites (adds a favorite).
    readonly property bool acceptsDrops: apps.folderMode || apps.menuMode

    Plasmoid.icon: cfg.icon || "view-app-grid-symbolic"
    Plasmoid.title: cfg.title
    toolTipMainText: cfg.title
    toolTipSubText: ""

    preferredRepresentation: compactRepresentation
    switchWidth: Kirigami.Units.gridUnit * 8
    switchHeight: Kirigami.Units.gridUnit * 6
    // Dragging an app over the icon opens the popup.
    expandedOnDragHover: true

    AppsSource {
        id: apps
        mode: root.cfg.source
        folderPath: root.folderPath
        category: root.cfg.category
        clientId: Plasmoid.metaData.pluginId + ".favorites.instance-" + Plasmoid.id
        manualOrder: root.cfg.sortMode === "manual"
        order: root.cfg.order
    }

    // Menu favorites, for "Add to / Remove from favorites".
    Kicker.KAStatsFavoritesModel {
        id: menuFavorites
        Component.onCompleted: initForClient(Plasmoid.metaData.pluginId + ".favorites.toggle-" + Plasmoid.id)
    }

    FileOps {
        id: fileOps
    }

    // Search filter, on top of the source.
    KItemModels.KSortFilterProxyModel {
        id: filtered
        sourceModel: apps.model
        filterRoleName: "display"
        filterCaseSensitivity: Qt.CaseInsensitive
    }

    function sourceRow(row) {
        return filtered.mapToSource(filtered.index(row, 0)).row;
    }

    function launch(row) {
        if (row < 0 || row >= filtered.count) {
            return;
        }
        if (apps.launch(sourceRow(row)) && cfg.closeOnLaunch) {
            root.expanded = false;
        }
    }

    function triggerAction(row, actionId, argument) {
        if (apps.trigger(sourceRow(row), actionId, argument) && cfg.closeOnLaunch) {
            root.expanded = false;
        }
    }

    function moveApp(from, to) {
        const order = apps.move(sourceRow(from), sourceRow(to));
        if (order) {
            cfg.order = order;
            cfg.sortMode = "manual";
        }
    }

    // Menu favorite id ("applications:name.desktop") of an app.
    function menuFavoriteId(app) {
        if (apps.menuMode) {
            return app.favoriteId;
        }
        const url = String(app.url || "");
        return url.endsWith(".desktop") ? "applications:" + url.slice(url.lastIndexOf("/") + 1) : "";
    }

    // Path of the link (or file) inside the group folder.
    function groupFilePath(app) {
        const id = String(app.favoriteId || "");
        return id.startsWith("applications:/") ? id.slice("applications:".length) : "";
    }

    function removeFromGroup(app) {
        if (apps.menuMode) {
            menuFavorites.removeFavorite(app.favoriteId);
        } else if (apps.folderMode) {
            const path = groupFilePath(app);
            if (path) {
                fileOps.trash(path);
            }
        }
    }

    // Dropped apps (from the menu, the desktop, Dolphin…).
    function addUrls(urls) {
        for (const u of urls) {
            const s = u.toString();
            let path = "";
            if (s.startsWith("file://")) {
                path = decodeURIComponent(s.slice("file://".length));
            }
            if (!path.endsWith(".desktop")) {
                continue;
            }
            const name = path.slice(path.lastIndexOf("/") + 1);
            if (apps.folderMode) {
                if (!path.startsWith(root.folderPath + "/")) {
                    fileOps.link(path, root.folderPath);
                }
            } else if (apps.menuMode) {
                menuFavorites.addFavorite("applications:" + name);
            }
        }
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open group folder")
            icon.name: "folder-open-symbolic"
            visible: apps.folderMode
            onTriggered: Qt.openUrlExternally("file://" + root.folderPath)
        },
        PlasmaCore.Action {
            text: i18n("Sort alphabetically")
            icon.name: "view-sort-ascending-name"
            visible: apps.folderMode && root.cfg.sortMode === "manual"
            onTriggered: root.cfg.sortMode = "alpha"
        }
    ]

    compactRepresentation: MouseArea {
        id: compact

        property bool wasExpanded: false

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        // Row of apps: the widget grows along the panel.
        readonly property real rowLength: root.rowIconCount * rowIconSize + (root.rowIconCount - 1) * Kirigami.Units.smallSpacing
        readonly property real rowIconSize: root.verticalPanel ? width : height

        // Tile: a square as thick as the panel (otherwise the panel only grants the minimum width).
        readonly property real along: root.rowIcon ? rowLength : root.compositeIcon ? rowIconSize : Kirigami.Units.iconSizes.small

        Layout.minimumWidth: root.verticalPanel ? Kirigami.Units.iconSizes.small : along
        Layout.minimumHeight: root.verticalPanel ? along : Kirigami.Units.iconSizes.small
        Layout.preferredWidth: Layout.minimumWidth
        Layout.preferredHeight: Layout.minimumHeight

        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        Kirigami.Icon {
            anchors.fill: parent
            visible: !root.compositeIcon && !root.rowIcon
            source: Plasmoid.icon
            active: compact.containsMouse || root.expanded
        }

        // Composite icon: the first four apps of the group, on a tile.
        Rectangle {
            id: tile

            readonly property int pad: Math.max(1, Math.round(width * 0.04))
            readonly property int gap: Math.max(1, Math.round(width * 0.04))
            readonly property color base: Kirigami.Theme.textColor

            visible: root.compositeIcon
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(base.r, base.g, base.b, (compact.containsMouse || root.expanded) ? 0.22 : 0.12)

            Grid {
                anchors.fill: parent
                anchors.margins: tile.pad
                columns: 2
                spacing: tile.gap

                Repeater {
                    model: root.compositeIcon ? apps.model : null
                    delegate: Kirigami.Icon {
                        required property int index
                        required property var model
                        visible: index < 4
                        width: Math.floor((tile.width - tile.pad * 2 - tile.gap) / 2)
                        height: width
                        source: model.decoration
                    }
                }
            }
        }

        // Side by side: the first apps of the group, in a row.
        Grid {
            visible: root.rowIcon
            anchors.centerIn: parent
            columns: root.verticalPanel ? 1 : root.rowIconCount
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.rowIcon ? apps.model : null
                delegate: Kirigami.Icon {
                    required property int index
                    required property var model
                    visible: index < root.rowIconCount
                    width: compact.rowIconSize
                    height: width
                    source: model.decoration
                    active: compact.containsMouse || root.expanded
                }
            }
        }

        DropArea {
            anchors.fill: parent
            enabled: root.acceptsDrops
            onEntered: drag => {
                if (drag.hasUrls) {
                    root.expanded = true;
                }
            }
            onDropped: drop => {
                if (drop.hasUrls) {
                    root.addUrls(drop.urls);
                    drop.accept(Qt.LinkAction);
                }
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: full

        readonly property int iconSize: root.cfg.iconSize
        readonly property int lineHeight: Math.ceil(fontMetrics.height)
        readonly property bool showSubtitle: root.listMode && root.cfg.showDescriptions
        readonly property int count: filtered.count

        readonly property int columns: Math.max(1, Math.min(root.cfg.columns, Math.max(1, apps.count)))
        readonly property int cellWidth: {
            if (root.listMode) {
                return iconSize + Kirigami.Units.gridUnit * (showSubtitle ? 14 : 9);
            }
            if (!root.showLabels) {
                return iconSize + Kirigami.Units.largeSpacing * 2;
            }
            return Math.max(Kirigami.Units.gridUnit * 5, iconSize + Kirigami.Units.gridUnit * 2);
        }
        readonly property int cellHeight: {
            const pad = Kirigami.Units.smallSpacing * 2;
            if (root.listMode) {
                return Math.max(iconSize, lineHeight * (showSubtitle ? 2 : 1)) + pad * 2;
            }
            return iconSize + pad * 2 + (root.showLabels ? lineHeight * 2 + Kirigami.Units.smallSpacing : 0);
        }
        readonly property int rows: Math.max(1, Math.ceil(apps.count / columns))

        Layout.preferredWidth: columns * cellWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredHeight: Math.min(rows, root.cfg.maxRows) * cellHeight
            + (header && header.visible ? header.implicitHeight : 0) + Kirigami.Units.smallSpacing * 2
        Layout.minimumWidth: Math.min(Layout.preferredWidth, Kirigami.Units.gridUnit * 10)
        Layout.minimumHeight: cellHeight

        collapseMarginsHint: true

        FontMetrics {
            id: fontMetrics
            font: Kirigami.Theme.defaultFont
        }

        // On open: focus the search field (or the grid); on close: clear the search.
        Connections {
            target: root
            function onExpandedChanged() {
                if (root.expanded) {
                    grid.currentIndex = -1;
                    if (root.cfg.showSearch) {
                        search.forceActiveFocus();
                    } else {
                        grid.forceActiveFocus();
                    }
                } else {
                    search.text = "";
                }
            }
        }

        // --- Context menu of an app ---------------------------------------------

        property var contextMenu: null

        Component {
            id: menuComponent
            PlasmaExtras.Menu {
                onStatusChanged: if (status === PlasmaExtras.Menu.Closed) Qt.callLater(destroy)
            }
        }

        Component {
            id: menuItemComponent
            PlasmaExtras.MenuItem {}
        }

        function addItem(menu, props, onClick) {
            const item = menuItemComponent.createObject(menu, props);
            if (onClick) {
                item.clicked.connect(onClick);
            }
            menu.addMenuItem(item);
        }

        function openContextMenu(cell) {
            if (contextMenu) {
                contextMenu.destroy();
            }
            const app = cell.model;
            const row = cell.index;
            const menu = menuComponent.createObject(full);
            contextMenu = menu;

            // App actions ("New window", "Quit"…) and menu actions (edit, manage).
            let lastWasSeparator = true;
            for (const action of (app.actionList || [])) {
                if (action.type === "separator") {
                    if (!lastWasSeparator) {
                        addItem(menu, { separator: true });
                        lastWasSeparator = true;
                    }
                    continue;
                }
                addItem(menu, { text: action.text, icon: action.icon || "" },
                        () => root.triggerAction(row, action.actionId, action.actionArgument));
                lastWasSeparator = false;
            }
            if (!lastWasSeparator) {
                addItem(menu, { separator: true });
            }

            const favId = root.menuFavoriteId(app);
            if (favId && !apps.menuMode) {
                if (menuFavorites.isFavorite(favId)) {
                    addItem(menu, { text: i18n("Remove from menu favorites"), icon: "bookmark-remove" },
                            () => menuFavorites.removeFavorite(favId));
                } else {
                    addItem(menu, { text: i18n("Add to menu favorites"), icon: "bookmark-new" },
                            () => menuFavorites.addFavorite(favId));
                }
            }
            if (apps.menuMode) {
                addItem(menu, { text: i18n("Remove from menu favorites"), icon: "bookmark-remove" },
                        () => root.removeFromGroup(app));
            } else if (apps.folderMode && root.groupFilePath(app)) {
                addItem(menu, { text: i18n("Remove from group (to trash)"), icon: "list-remove" },
                        () => root.removeFromGroup(app));
            }

            menu.visualParent = cell;
            menu.open(cell.mouseX, cell.mouseY);
        }

        // --- Header: title and search -------------------------------------------

        header: PlasmaExtras.PlasmoidHeading {
            visible: root.cfg.showHeading || root.cfg.showSearch

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    visible: root.cfg.showHeading && root.cfg.title !== ""
                    level: 3
                    text: root.cfg.title
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                PlasmaExtras.SearchField {
                    id: search
                    Layout.fillWidth: true
                    visible: root.cfg.showSearch
                    onTextChanged: {
                        filtered.filterString = text;
                        grid.currentIndex = text ? 0 : -1;
                    }
                    Keys.onReturnPressed: root.launch(Math.max(0, grid.currentIndex))
                    Keys.onEnterPressed: root.launch(Math.max(0, grid.currentIndex))
                    Keys.onDownPressed: {
                        grid.forceActiveFocus();
                        if (grid.currentIndex < 0) {
                            grid.currentIndex = 0;
                        }
                    }
                }
            }
        }

        // --- Grid ---------------------------------------------------------------

        PlasmaComponents.ScrollView {
            anchors.fill: parent

            GridView {
                id: grid

                // Reordering: drag an app onto another one (not while searching).
                readonly property bool reorderEnabled: apps.canReorder && search.text === ""
                property int dragFrom: -1
                property int dropIndex: -1
                property point ghostPos: Qt.point(0, 0)
                property var ghostIcon: null

                model: filtered
                cellWidth: full.cellWidth
                cellHeight: full.cellHeight
                focus: true
                clip: true
                keyNavigationWraps: true
                currentIndex: -1
                highlight: PlasmaExtras.Highlight {
                    visible: grid.dragFrom < 0
                }
                highlightMoveDuration: 0

                Keys.onReturnPressed: root.launch(currentIndex)
                Keys.onEnterPressed: root.launch(currentIndex)
                Keys.onMenuPressed: if (currentItem) full.openContextMenu(currentItem)
                Keys.onUpPressed: event => {
                    if (search.visible && currentIndex < full.columns) {
                        search.forceActiveFocus();
                    } else {
                        event.accepted = false;
                    }
                }

                delegate: MouseArea {
                    id: cell

                    required property int index
                    required property var model
                    readonly property string description: model.description || ""

                    property point pressPos
                    property bool dragging: false
                    property bool suppressClick: false

                    width: grid.cellWidth
                    height: grid.cellHeight
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    // The view must not steal the gesture: it is used for reordering.
                    preventStealing: grid.reorderEnabled
                    opacity: grid.dragFrom === index ? 0.35 : 1

                    onEntered: if (grid.dragFrom < 0) grid.currentIndex = index

                    onPressed: mouse => {
                        pressPos = Qt.point(mouse.x, mouse.y);
                        suppressClick = false;
                    }
                    onPositionChanged: mouse => {
                        if (!(mouse.buttons & Qt.LeftButton) || !grid.reorderEnabled) {
                            return;
                        }
                        if (!dragging) {
                            const dist = Math.abs(mouse.x - pressPos.x) + Math.abs(mouse.y - pressPos.y);
                            if (dist < Qt.styleHints.startDragDistance) {
                                return;
                            }
                            dragging = true;
                            grid.dragFrom = index;
                            grid.ghostIcon = model.decoration;
                        }
                        const p = mapToItem(grid.contentItem, mouse.x, mouse.y);
                        grid.ghostPos = p;
                        grid.dropIndex = grid.indexAt(p.x, p.y);
                    }
                    onReleased: mouse => {
                        if (!dragging) {
                            return;
                        }
                        dragging = false;
                        suppressClick = true;
                        const from = grid.dragFrom;
                        const to = grid.dropIndex;
                        grid.dragFrom = -1;
                        grid.dropIndex = -1;
                        if (to >= 0 && to !== from) {
                            root.moveApp(from, to);
                        }
                    }
                    onCanceled: {
                        dragging = false;
                        grid.dragFrom = -1;
                        grid.dropIndex = -1;
                    }
                    onClicked: mouse => {
                        if (suppressClick) {
                            return;
                        }
                        if (mouse.button === Qt.RightButton) {
                            full.openContextMenu(cell);
                        } else {
                            root.launch(index);
                        }
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: cell.model.display
                    Accessible.description: cell.description

                    PlasmaComponents.ToolTip.visible: !root.listMode && cell.containsMouse && grid.dragFrom < 0
                        && (!root.showLabels || (root.cfg.showDescriptions && cell.description !== ""))
                    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay
                    PlasmaComponents.ToolTip.text: {
                        const desc = root.cfg.showDescriptions ? cell.description : "";
                        if (root.showLabels) {
                            return desc;
                        }
                        return desc ? cell.model.display + "\n" + desc : cell.model.display;
                    }

                    // Target slot while reordering.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        visible: grid.dragFrom >= 0 && grid.dropIndex === cell.index && cell.index !== grid.dragFrom
                        color: "transparent"
                        radius: Kirigami.Units.cornerRadius
                        border.width: 2
                        border.color: Kirigami.Theme.highlightColor
                    }

                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing * 2
                        columns: root.listMode ? 2 : 1
                        rowSpacing: Kirigami.Units.smallSpacing
                        columnSpacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            Layout.alignment: root.listMode ? Qt.AlignVCenter : Qt.AlignHCenter
                            Layout.preferredWidth: full.iconSize
                            Layout.preferredHeight: full.iconSize
                            source: cell.model.decoration
                            active: cell.containsMouse
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: !root.listMode
                            Layout.alignment: root.listMode ? Qt.AlignVCenter : Qt.AlignTop
                            visible: root.showLabels
                            spacing: 0

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: cell.model.display
                                horizontalAlignment: root.listMode ? Text.AlignLeft : Text.AlignHCenter
                                wrapMode: root.listMode ? Text.NoWrap : Text.Wrap
                                maximumLineCount: root.listMode ? 1 : 2
                                elide: Text.ElideRight
                            }

                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: full.showSubtitle && text !== ""
                                text: cell.description
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                            }
                        }
                    }
                }

                // Icon following the pointer while reordering.
                Kirigami.Icon {
                    parent: grid.contentItem
                    visible: grid.dragFrom >= 0
                    z: 10
                    width: full.iconSize
                    height: full.iconSize
                    x: grid.ghostPos.x - width / 2
                    y: grid.ghostPos.y - height / 2
                    source: grid.ghostIcon
                    opacity: 0.85
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: full.count === 0
                    iconName: search.text ? "edit-none" : "application-x-desktop"
                    text: search.text ? i18n("No results")
                        : apps.categoryMode && !apps.model ? i18n("Category not found")
                        : i18n("No apps in this group")
                    explanation: {
                        if (search.text) {
                            return "";
                        }
                        if (apps.menuMode) {
                            return i18n("Add favorites from the application menu, or drag apps here.");
                        }
                        if (apps.categoryMode) {
                            return i18n("Choose a category in the widget settings.");
                        }
                        return i18n("Drag apps here from the application menu, or put .desktop links in %1", root.folderPath);
                    }
                }
            }
        }

        // Apps dropped from outside (menu, desktop, Dolphin).
        DropArea {
            id: dropArea
            anchors.fill: parent
            enabled: root.acceptsDrops
            keys: ["text/uri-list"]
            onDropped: drop => {
                root.addUrls(drop.urls);
                drop.accept(Qt.LinkAction);
            }

            Rectangle {
                anchors.fill: parent
                visible: dropArea.containsDrag
                color: "transparent"
                radius: Kirigami.Units.cornerRadius
                border.width: 2
                border.color: Kirigami.Theme.highlightColor
            }
        }
    }
}
