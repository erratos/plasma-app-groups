// Small file operations for a folder group: create a link, move to trash.
// QML has no file API, so this goes through the plasma5support "executable" engine.
import QtQuick
import org.kde.plasma.plasma5support as P5Support

P5Support.DataSource {
    id: ops

    engine: "executable"
    connectedSources: []

    // Quotes an argument for the shell.
    function quote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function run(cmd) {
        connectSource(cmd);
    }

    // Symlink `folder/<file name>` pointing to `target` (never overwrites an existing link).
    function link(target, folder) {
        const name = target.slice(target.lastIndexOf("/") + 1);
        run("mkdir -p -- " + quote(folder) + " && ln -s -- " + quote(target) + " " + quote(folder + "/" + name));
    }

    // To the trash (recoverable), never a permanent deletion.
    function trash(path) {
        run("kioclient --noninteractive move " + quote("file://" + path) + " trash:/");
    }

    onNewData: (sourceName, data) => {
        if (data["exit code"] !== 0) {
            console.warn("appgroups:", sourceName, "→", data["stderr"]);
        }
        disconnectSource(sourceName);
    }
}
