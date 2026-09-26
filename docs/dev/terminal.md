# terminal

`cutefish-terminal`: a tabbed terminal emulator. The QML UI sits on QMLTermWidget, the QML port of qtermwidget/Konsole that cool-retro-term also uses, vendored in `qmltermwidget/`. Upstream is cutefishos/terminal, ported to Qt 6 on 2026-09-23 against an unpublished FishUI. Our FishUI therefore gained the controls Terminal expects (setback 31). Our only change here is the default font, Fantasque Sans Mono. API reference: [api/terminal.md](api/terminal.md).

## Layout

```
src/main.cpp          QApplication, -w/--workdir, -e/--execute, context properties, loads qrc:/qml/main.qml
src/processhelper.*   "Process": open URLs, the file manager, new windows (through AppRuntime)
src/utils.*           "Utils": clipboard text
src/fonts.*           "Fonts": monospace font families for the settings dialog
src/qml/
  main.qml            FishUI.Window: TabBar + one Terminal per tab, find bar, shortcuts
  Terminal.qml        one tab: QMLTermWidget + QMLTermSession, context menu, links, paste guard
  TabBar.qml, FindBar.qml, SettingsDialog.qml, ExitPromptDialog.qml
  GlobalSettings.qml  QtCore Settings → ~/.config/cutefish/terminal.conf
qmltermwidget/        QML module Cutefish.TermWidget (plugin: QMLTermWidget, QMLTermSession)
  lib/                the terminal engine (Konsole): Vt102Emulation, Screen, History, Pty/kpty, ColorScheme, KeyboardTranslator
  lib/color-schemes/  *.colorscheme files
  lib/kb-layouts/     *.keytab key bindings
  src/                QML plugin + QMLTermScrollbar.qml
```

It builds `../cutefish-framework/applications` (static) for launching through AppRuntime.

## How it works

- **Starting:**
  - `-e cmd args…` runs a command instead of the shell. Everything after `-e` is split off before option parsing. A single argument containing spaces is run as `$SHELL -c "<line>"`, as xterm does.
  - `-w dir` sets the start directory.
  - Both reach QML as `StartupCommand` and `StartupDirectory`.
- **A tab** (`Terminal.qml`):
  - `QMLTermSession` owns the pty and the child process. It sets `shellProgram`/`shellProgramArgs` from the command, or uses `$SHELL`, which is fish by default on this system.
  - `QMLTermWidget` renders it with `colorScheme`, `font.family` and `font.pointSize`.
  - The tab title follows the session title, unless the user renamed the tab.
- **Settings** (`GlobalSettings.qml`, all live):
  - `fontName` ("Fantasque Sans Mono"), `fontPointSize`;
  - `colorScheme` ("TokyoNight"), `opacity` (0.85), `blur`;
  - `blinkingCursor`, `cursorShape`, `scrollbackLines`, `visualBell`, `confirmMultilinePaste`;
  - window size.
- **Look:** the window is a `FishUI.Window` whose background follows the terminal's colour scheme and its own `opacity` setting, not the system window opacity. Popups and the find bar take their accent and error colours from the scheme.
- **Closing:** with a foreground process running (`session.hasActiveProcess`), `ExitPromptDialog` asks first.

## APIs used from QML

- **`Cutefish.TermWidget`:**
  - `QMLTermSession`: `startShellProgram()`, `sendText(text)`, `clearScrollback()`, `resetTerminal()`; properties `title`, `currentDir`, `hasActiveProcess`, `foregroundProcessName`, `historySize`, `kbScheme`, `initialWorkingDirectory`, `shellProgram`, `shellProgramArgs`;
  - `QMLTermWidget`: `session`, `colorScheme`, `font`, `fontMetrics`, selection and search, `copyClipboard()`, `pasteClipboard()`.

  The full list is in the API reference.
- **`Process`** (`ProcessHelper`):
  - `openUrl(url)`, `openFileManager(url)`, `showInFileManager(path)`;
  - `newWindow(directory)`, `startDetached(program, args)`;
  - `existingPath(text, baseDir)` turns clicked text into a file path.
- **`Utils.text()` / `setText()`**: the clipboard.
- **`Fonts`**: the list of monospace families.

## Making changes

- **Adding a colour scheme:** drop a `.colorscheme` file into `qmltermwidget/lib/color-schemes/`; `THEMES.md` explains the format.
- **Changing default settings:** edit `GlobalSettings.qml`. Existing users keep what's in their `terminal.conf`.
- **Testing after a FishUI change:** Terminal uses more of FishUI than any other app. Start it and open its Settings dialog from a shell, then read the QML warnings.
