# App Group — a Plasma 6 widget

A small panel icon that opens a popup with a group of apps. One click on the icon opens the popup;
one click on an app launches it and closes the popup. Put several instances side by side in the panel,
one per group (e.g. *Favorites*, *Messaging*, *Editors*), each with its own icon and title.

Pure QML: nothing to compile, so nothing breaks when Plasma is updated.

## Features

- **Three sources per group**
  - a **folder** of `.desktop` files or symlinks to them (watched: add or remove a link and the group
    updates);
  - a **category of the application menu** (Internet, Office, Games…), sub-folders flattened;
  - the **application menu favorites**, live.
- **Panel icon**: any icon from the theme, a 2×2 tile of the first four apps, or the first *N* apps
  side by side.
- **Popup**: grid or list layout, icon size from 16 to 96 px, number of columns, maximum visible rows,
  names on or off, app description (tooltip in grid layout, subtitle in list layout), title (centered),
  optional search field (type right after opening, <kbd>Enter</kbd> launches the first match),
  keyboard navigation, option to keep the popup open after launching.
- **Right-click on an app** (or the <kbd>Menu</kbd> key): the app's own actions from its `.desktop`
  file (*New window*, *Quit*…), *Edit application…*, *Uninstall or manage add-ons…*,
  add to / remove from menu favorites, and *Remove from group* (folder groups: the link goes to the
  **trash**, never deleted for good).
- **Drag and drop from outside**: drop an app from the application menu, the desktop or Dolphin onto the
  panel icon or into the popup. Folder group → a symlink is created in the folder; favorites group → the
  app becomes a menu favorite.
- **Manual order**: drag an app onto another one inside the popup. Folder groups remember the order
  in the widget settings (*Sort alphabetically* in the widget's context menu goes back);
  the favorites group keeps an order specific to that widget, the menu's own order is untouched.
- Launching goes through KIO (`ApplicationLauncherJob`), like the application menu: no
  *"Open with… / Execute"* confirmation dialog, even when `kiorc` asks for one with scripts.
- Follows the Plasma theme (no hard-coded colors). Translations: English, French.

## Requirements

KDE Plasma 6 (developed and tested on Plasma 6.8, Qt 6.12, KDE Frameworks 6.31). Uses modules shipped
with Plasma: `org.kde.plasma.private.kicker`, `org.kde.plasma.plasma5support`, `org.kde.kitemmodels`,
`org.kde.iconthemes`, `org.kde.kcmutils`. Removing apps from a folder group uses `kioclient`
(part of `kde-cli-tools`).

## Install

```bash
git clone https://github.com/erratos/plasma-app-groups.git
```

```bash
kpackagetool6 --type Plasma/Applet --install plasma-app-groups/package
```

Then right-click the panel → *Add or Manage Widgets…* → **App Group**, once per group.
Open the widget settings to choose the title, icon and source.

### Update

```bash
kpackagetool6 --type Plasma/Applet --upgrade plasma-app-groups/package
```

```bash
systemctl --user restart plasma-plasmashell
```

Plasma keeps the old QML in memory until the shell restarts.

### Uninstall

```bash
kpackagetool6 --type Plasma/Applet --remove io.github.erratos.appgroups
```

## Folder groups

A folder group shows the `.desktop` files of a folder. If the folder setting is left empty, the widget
uses `~/.local/share/app-groups/<widget title>`. The easiest way to fill it is to drag apps from the
application menu into the popup. By hand:

```bash
mkdir -p ~/.local/share/app-groups/Editors
```

```bash
ln -s /usr/share/applications/org.kde.kate.desktop ~/.local/share/app-groups/Editors/
```

The link name **must end in `.desktop`**. Links can point to `/usr/share/applications`,
`~/.local/share/applications` or the Flatpak exports (`/var/lib/flatpak/exports/share/applications`).

## How it works

| File | Role |
|---|---|
| `package/metadata.json` | Widget id `io.github.erratos.appgroups`, name, version |
| `package/contents/config/main.xml` | Settings schema |
| `package/contents/config/config.qml` | Settings pages (*General*, *Appearance*) |
| `package/contents/ui/main.qml` | Panel icon, popup, context menu, drag and drop |
| `package/contents/ui/AppsSource.qml` | Reads a group (folder, menu category or favorites) and launches apps |
| `package/contents/ui/FileOps.qml` | Creates links (`ln -s`) and moves files to the trash (`kioclient`) |
| `package/contents/ui/configGeneral.qml` | *General* settings page |
| `package/contents/ui/configAppearance.qml` | *Appearance* settings page |
| `po/` | Translation template and translations |
| `scripts/update-translations.sh` | Extracts strings and compiles translations |
| `tests/apps-source.qml` | Prints what each source reads, outside the panel |

`AppsSource.qml` relies on the models of the Kickoff/Kicker QML module
(`org.kde.plasma.private.kicker`):

- `SimpleFavoritesModel` turns a list of `.desktop` paths into names, icons, descriptions and actions,
  and launches them;
- `RootModel` lists the menu categories;
- `KAStatsFavoritesModel` gives the menu favorites (stored by `kactivitymanagerd`).

This module is private API, but Plasma's own launchers and many third-party widgets use it. If a future
Plasma release changes it, the widget shows an empty group instead of breaking the panel; compare
`/usr/lib/qt6/qml/org/kde/plasma/private/kicker/kickerplugin.qmltypes` with the code.

QML has no file API, so `FileOps.qml` runs two shell commands through the plasma5support *executable*
engine, with every argument quoted.

## Development

Test the data layer outside the panel with the `qml` tool (Qt logs to the journal unless forced to
stderr):

```bash
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORMTHEME=kde QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qml tests/apps-source.qml
```

Check the QML:

```bash
/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml package/contents/ui/*.qml
```

### Translations

Strings are written in English inside `i18n()`. To add a language, copy `po/appgroups.pot` to
`po/<lang>.po` and translate it (or edit an existing `.po`), then run:

```bash
./scripts/update-translations.sh
```

It refreshes the template, merges it into every `.po` file and compiles them into
`package/contents/locale/<lang>/LC_MESSAGES/plasma_applet_io.github.erratos.appgroups.mo`.

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
