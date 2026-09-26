# filemanager

`cutefish-filemanager` ("Files"): the file manager, plus the QML module that draws desktop icons inside the shell. Upstream is cutefishos/filemanager. Our changes: the window uses the system translucency, and the sidebar tint follows the blur setting. API reference: [api/filemanager.md](api/filemanager.md).

## Layout

```
main.cpp, application.*   single instance (D-Bus com.cutefish.FileManager /FileManager), CLI options
window.*                  QQmlApplicationEngine per window, loads qrc:/qml/main.qml
qmltypes.*                registers the QML types as "Cutefish.FileManager 1.0" (drag and drop as "Cutefish.DragDrop"),
                          and the image providers "thumbnailer" and "icontheme"
model/
  foldermodel.*           THE model: one directory listing (KIO), selection, clipboard, drag and drop,
                          file operations, history, filters, sorting, archive jobs
  dirlister.*             KDirLister subclass feeding FolderModel
  placesmodel.*, placesitem.*   sidebar: Home, Downloads, … and Solid devices (mount, eject)
  pathbarmodel.*          breadcrumb bar
  positioner.*            free icon positions on the desktop
cio/                      file jobs: copy/move (cfilejob), size (cfilesizejob), archives (archivejob)
helper/                   Fm (helpers for QML), FileLauncher, PathHistory, ShortCut, KeyboardSearchManager, DateHelper
mimetype/                 MimeAppManager + XdgDesktopFile: "Open with", default apps
thumbnailer/              ThumbnailProvider ("image://thumbnailer/…") + ThumbnailCache (~/.cache/thumbnails)
dialogs/                  file properties, open with
draganddrop/, widgets/    QML DropArea/MimeData; rubber band selection, ItemViewAdapter
desktop/                  D-Bus client for the dock (reserved space)
desktopplugin/            QML module org.cutefish.filemanager.desktop: DesktopView (used by the shell)
qml/                      main.qml, FolderPage (one tab), Folder{Grid,List}View, SideBar, PathBar,
                          FolderTabBar, context menus, dialogs, GlobalSettings, Desktop/Main.qml
tests/                    Qt Test: places model, tabs, lifecycle
```

## How it works

- **Starting:** `Application` claims `com.cutefish.FileManager`.
  - A second `cutefish-filemanager [paths]` forwards its request to the running instance (`openFiles`, `moveToTrash`, `emptyTrash`) and exits.
  - Options: `-e/--empty-trash` and `--mtr/--move-to-trash <files>`.
- **Windows and tabs:** `main.qml` is a `FishUI.Window` containing `SideBar`, `FolderTabBar` and one `FolderPage` per tab. Each `FolderPage` owns a `FolderModel` and shows it as `FolderGridView` or `FolderListView`.
- **Listing:** `FolderModel.url` makes the `DirLister` (KIO) list the directory. Items carry name, icon, MIME type, size, dates and a `thumbnail` URL.
  - Icons come from `image://icontheme/<name>` (FishUI).
  - Thumbnails come from `image://thumbnailer/`, which uses `QImageReader` and caches the results under `~/.cache/thumbnails/`, following the freedesktop layout.
- **Actions:** all through `FolderModel`: `newFolder`, `newTextFile`, `rename`, `copy`, `cut`, `paste`, `deleteSelected`, `moveSelectedToTrash`, `openSelected`, `showOpenWithDialog`, `undo`, `goBack`, `goForward` and `up`. Copy and move run as KIO jobs; archives run through `cio/archivejob` (`archiveBusy`, `archiveProgress`, …).
- **Settings:** view mode, sort and icon size live in `~/.config/cutefishos/cutefish-filemanager.conf` (`GlobalSettings.qml`). The path is pinned because the shell loads the same QML for the desktop and would otherwise use a different file.

## The desktop module

`desktopplugin/` builds `org.cutefish.filemanager.desktop` (`DesktopView`, a `QQuickItem` bound to a `screen`). The shell's `DesktopSurface` hosts one per screen ([shell.md](shell.md)). `DesktopView` loads `qml/Desktop/Main.qml`, the same `FolderModel`-based icon grid, with `isDesktop: true` and `Positioner` for free placement. So **desktop icons are Files code, running inside the shell process**. After changing it, restart the shell, not just Files.

## D-Bus

`com.cutefish.FileManager /FileManager`: `openFiles(QStringList)`, `moveToTrash(QStringList)` and `emptyTrash()`. The dock's Trash uses the last two.

## Making changes

- **A new file action:** a `Q_INVOKABLE` on `FolderModel` (it has the selection), an entry in `FolderContextMenu.qml` or `OptionsMenu.qml`, and a shortcut in `helper/shortcut.*` if needed.
- **A new place in the sidebar:** `model/placesmodel.cpp`.
- **Sidebar look:** `qml/SideBar.qml`. Its tint sits on top of the translucent window background, and it must stay light, or the sidebar turns opaque ([fishui.md](fishui.md)).
- **Tests:** `tests/` builds with `-DFILEMANAGER_BUILD_TESTS=ON` (off by default) and runs offscreen under `ctest`.
