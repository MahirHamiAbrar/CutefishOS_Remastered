# texteditor

`cutefish-editor`, a tabbed plain-text editor with syntax highlighting. Upstream is the archived cutefishs/texteditor, an unfinished Qt 5 prototype. We ported it to Qt 6 / KF6 and finished it: opening files, saving, a global menu, and file arguments ([../qt6-porting.md](../qt6-porting.md)). API reference: [api/texteditor.md](api/texteditor.md).

## Layout

```
src/main.cpp            QGuiApplication; registers DocumentHandler and FileHelper as
                        Cutefish.TextEditor 1.0; passes argv files as context property startupFiles
src/documenthandler.*   the editing backend for one document (derived from MauiKit's DocumentHandler)
                        also: DocumentAlert/Alerts (in-editor prompts), FileLoader (threaded file read)
src/highlightmodel.*    list of KSyntaxHighlighting definitions (unused by the QML for now)
src/texteditor.*        FileHelper: addPath(path) → newPath(path) signal
qml/main.qml            FishUI.Window: FishUI.TabBar + FishUI.TabView of TextEditor tabs,
                        Qt.labs.platform MenuBar (exported as the global menu), open and save dialogs
qml/TextEditor.qml      one tab: TextArea + line numbers + DocumentHandler
cutefish-editor.desktop Exec=cutefish-editor %F
```

## How it works

- **Starting:** `main.cpp` turns each command-line argument into a URL (`QUrl::fromUserInput`, relative to the current directory) and exposes the list as `startupFiles`. `main.qml`'s `Component.onCompleted` opens one tab per file, or an empty tab if there are none.
- **Tabs:** `addPath(url)` and `addTab()` add a `TextEditor` to `_tabView`. The tab's `fileUrl` is bound to its `DocumentHandler.fileUrl`.
- **Loading:** setting `DocumentHandler.fileUrl` calls `load()`. A `FileLoader` on a worker thread reads the file, and `fileReady(text, url)` fills the `QQuickTextDocument`. The encoding comes from a BOM if there is one, otherwise UTF-8 (`QStringConverter`; `QTextCodec` is gone in Qt 6).
- **Watching:** a `QFileSystemWatcher` flags `externallyModified`, and with `autoReload` it reloads.
- **Highlighting:** one static `KSyntaxHighlighting::Repository` is shared by every tab. The definition is picked from the file name (`formatName`), and the theme is the repository's default light or dark theme, chosen by how dark `backgroundColor` is (`isDark`). This follows `FishUI.Theme.darkMode`.
- **Saving:** File → Save calls the tab's `save()`, which calls `DocumentHandler.saveAs(fileUrl)`. A tab with no file opens the Save dialog first.
- **Menu:** a `Qt.labs.platform` `MenuBar` is exported over D-Bus, so the status bar shows File/… as the global menu ([../global-menu.md](../global-menu.md)). Shortcuts are the `StandardKey` ones.

## API

QML (`import Cutefish.TextEditor 1.0`):

- **`DocumentHandler`**
  - Bind `document` to a `TextArea.textDocument`, and `cursorPosition`, `selectionStart` and `selectionEnd` to the `TextArea`.
  - Read or write `fileUrl`; read `fileName`, `fileType`, `modified`, `externallyModified` and `lineCount`.
  - Presentation: `enableSyntaxHighlighting`, `formatName`, `theme`, `backgroundColor`, `fontFamily`, `fontSize` and `tabSpace`.
  - Methods: `load(url)`, `saveAs(url)`, `find(query, forward)`, `replace(query, value)`, `replaceAll(query, value)`, `toggleFold(line)` and `lineHeight(line)`.
  - Find options: `findWholeWords` and `findCaseSensitively`.
  - `alerts` is a model of prompts (for example "file changed on disk") with buttons; `DocumentAlert.triggerAction(i, alertIndex)` answers one.
- **`FileHelper`**: `addPath(path)` emits `newPath(path)`. The main window uses it to open a file from anywhere.
- `TextEditor.qml` functions: `save()`, `saveAs(url)`, `goToLine(line)` and `forceActiveFocus()`.

The complete list is in the API reference.

## Making changes

- New menu entries go in the `Platform.MenuBar` in `main.qml`. They appear in the global menu automatically.
- The editor font is `monospace`, which fontconfig maps to JetBrains Mono (`packaging/files/fonts/60-cutefish-fonts.conf`). Change it in `TextEditor.qml`.
- Needs `libkf6syntaxhighlighting-dev` to build and `qml6-module-qt-labs-platform` at runtime; keep `debian/control` in step with new imports.
