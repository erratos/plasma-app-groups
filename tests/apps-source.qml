// Prints what AppsSource reads for each source, then quits.
// Usage (from the repository root):
//   QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORMTHEME=kde QT_QPA_PLATFORM=offscreen \
//     /usr/lib/qt6/bin/qml tests/apps-source.qml
import QtQuick
import QtCore
import "../package/contents/ui" as AppGroups

Window {
    readonly property string home: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace(/^file:\/\//, "")

    AppGroups.AppsSource {
        id: folder
        mode: "folder"
        // Any folder containing .desktop files or links to them.
        folderPath: "/usr/share/applications"
    }

    AppGroups.AppsSource {
        id: category
        mode: "menuCategory"
    }

    AppGroups.AppsSource {
        id: favorites
        mode: "menuFavorites"
        clientId: "io.github.erratos.appgroups.test"
    }

    function names(source, max) {
        const out = [];
        for (let i = 0; i < Math.min(source.count, max); ++i) {
            out.push(source.model.data(source.model.index(i, 0), Qt.DisplayRole));
        }
        return out.join(" | ");
    }

    Timer {
        interval: 2500
        running: true
        onTriggered: {
            console.warn("folder:", folder.count, "apps —", names(folder, 5), "…");
            console.warn("categories:", category.categories.map(c => c.name).join(", "));
            category.category = category.categories.length ? category.categories[0].name : "";
            console.warn("first category:", category.count, "apps —", names(category, 5), "…");
            console.warn("menu favorites:", favorites.count, "apps —", names(favorites, 5), "…");
            Qt.quit();
        }
    }
}
