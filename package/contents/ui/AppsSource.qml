// Provides the list of apps in a group and knows how to launch them.
//
// Three sources:
//  - "folder": the .desktop files (or symlinks to them) in a folder, sorted by name
//    or in a manual order (list of file names);
//  - "menuFavorites": the Plasma menu favorites, live, in menu order;
//  - "menuCategory": one category of the application menu (Internet, Office…), sub-folders flattened.
//
// Reading .desktop files and launching apps goes through the Kickoff/Kicker QML module
// (org.kde.plasma.private.kicker): localized name, icon, description, launch through KIO
// (ApplicationLauncherJob), so no "Open with… / Execute" confirmation dialog.
import QtQuick
import Qt.labs.folderlistmodel
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.private.kicker as Kicker

Item {
    id: src

    property string mode: "folder"
    property string folderPath: ""
    // Display name of the menu category (e.g. "Internet").
    property string category: ""
    // KActivities client id (one per widget instance).
    property string clientId: "io.github.erratos.appgroups"
    // Folder source: manual order (otherwise alphabetical) and the file names in that order.
    property bool manualOrder: false
    property var order: []

    readonly property bool menuMode: mode === "menuFavorites"
    readonly property bool categoryMode: mode === "menuCategory"
    readonly property bool folderMode: !menuMode && !categoryMode

    // Model to display: roles display (name), decoration (icon), description.
    readonly property var model: menuMode ? menuApps : categoryMode ? categoryModel : manualOrder ? folderApps : sortedFolderApps
    readonly property int count: model ? model.count : 0
    // Drag-and-drop reordering: folder or favorites (order specific to this widget).
    readonly property bool canReorder: folderMode || menuMode

    // Menu categories, for the settings page: [{ name, icon }].
    readonly property var categories: {
        rootModel.revision; // dependency: re-evaluated after each refresh
        const list = [];
        for (let i = 0; i < rootModel.count; ++i) {
            const ix = rootModel.index(i, 0);
            list.push({ name: rootModel.data(ix, Qt.DisplayRole), icon: rootModel.data(ix, Qt.DecorationRole) });
        }
        return list;
    }

    property var categoryModel: null

    // Launches the app at `row` (displayed order), or one of its actions.
    function trigger(row, actionId, argument) {
        const arg = argument === undefined ? null : argument;
        if (folderMode && !manualOrder) {
            const sourceRow = sortedFolderApps.mapToSource(sortedFolderApps.index(row, 0)).row;
            return folderApps.trigger(sourceRow, actionId || "", arg);
        }
        return model ? model.trigger(row, actionId || "", arg) : false;
    }

    function launch(row) {
        return trigger(row, "", null);
    }

    function reloadFiles() {
        const entries = [];
        for (let i = 0; i < files.count; ++i) {
            entries.push({ name: files.get(i, "fileName"), path: files.get(i, "filePath") });
        }
        if (manualOrder) {
            // Known files in the saved order, then new ones by file name.
            const rank = name => {
                const i = order.indexOf(name);
                return i < 0 ? order.length : i;
            };
            entries.sort((a, b) => (rank(a.name) - rank(b.name)) || a.name.localeCompare(b.name));
        }
        folderApps.favorites = entries.map(e => e.path);
    }

    // File names of the folder, in displayed order.
    function displayedFileNames() {
        // favorites returns "applications:/path/to/link.desktop", one entry per valid row.
        const favs = folderApps.favorites;
        const names = [];
        for (let i = 0; i < model.count; ++i) {
            const sourceRow = manualOrder ? i : sortedFolderApps.mapToSource(sortedFolderApps.index(i, 0)).row;
            const id = favs[sourceRow] || "";
            names.push(id.slice(id.lastIndexOf("/") + 1));
        }
        return names;
    }

    // Moves an app. Folder source: returns the new order (file names) to be saved.
    function move(from, to) {
        if (from === to || from < 0 || to < 0) {
            return null;
        }
        if (menuMode) {
            menuApps.moveRow(from, to);
            return null;
        }
        if (folderMode) {
            const names = displayedFileNames();
            const moved = names.splice(from, 1)[0];
            names.splice(to, 0, moved);
            return names;
        }
        return null;
    }

    onManualOrderChanged: reloadFiles()
    onOrderChanged: if (manualOrder) reloadFiles()

    function findCategory() {
        let found = null;
        for (let i = 0; i < rootModel.count; ++i) {
            if (rootModel.data(rootModel.index(i, 0), Qt.DisplayRole) === category) {
                found = rootModel.modelForRow(i);
                break;
            }
        }
        categoryModel = found;
    }

    // --- Folder ----------------------------------------------------------------

    FolderListModel {
        id: files
        // Watches the folder: adding or removing a link updates the group.
        folder: (src.folderMode && src.folderPath) ? "file://" + src.folderPath : ""
        showDirs: false
        showHidden: false
        nameFilters: ["*.desktop"]
        onCountChanged: src.reloadFiles()
        onStatusChanged: if (status === FolderListModel.Ready) src.reloadFiles()
    }

    Kicker.SimpleFavoritesModel {
        id: folderApps
    }

    KItemModels.KSortFilterProxyModel {
        id: sortedFolderApps
        sourceModel: folderApps
        sortRoleName: "display"
        sortCaseSensitivity: Qt.CaseInsensitive
        sortOrder: Qt.AscendingOrder
    }

    // --- Menu favorites --------------------------------------------------------

    Kicker.KAStatsFavoritesModel {
        id: menuApps
    }

    // --- Menu categories -------------------------------------------------------

    Kicker.RootModel {
        id: rootModel

        property int revision: 0
        property bool wanted: false
        // refresh() does nothing before the model has finished construction.
        property bool ready: false

        autoPopulate: false
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: false
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showRecentFolders: false
        showPowerSession: false
        showFavoritesPlaceholder: false

        // The menu changed (app installed, menu edited): find the category again.
        onRefreshed: {
            revision++;
            src.findCategory();
        }

        Component.onCompleted: {
            ready = true;
            if (wanted) {
                refresh();
            }
        }
    }

    // Loads the categories (costly) only when needed.
    function ensureRootModel() {
        if (!rootModel.wanted) {
            rootModel.wanted = true;
            if (rootModel.ready) {
                rootModel.refresh();
            }
        }
    }

    onCategoryChanged: findCategory()
    onCategoryModeChanged: if (categoryMode) ensureRootModel()
    onMenuModeChanged: if (menuMode) menuApps.initForClient(clientId)

    Component.onCompleted: {
        if (menuMode) {
            menuApps.initForClient(clientId);
        }
        if (categoryMode) {
            ensureRootModel();
        }
    }
}
