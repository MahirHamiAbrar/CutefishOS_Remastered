# screenshot

`cutefish-screenshot`: freezes the screen, lets the user drag a selection, then saves it to the Desktop or copies it to the clipboard. Upstream is cutefishos/screenshot (Qt 5, X11). We ported it to Qt 6 and to KWin's `ScreenShot2` D-Bus API, because on Wayland no client may read the screen itself ([../qt6-porting.md](../qt6-porting.md)). API reference: [api/screenshot.md](api/screenshot.md).

## Layout

```
src/main.cpp              parses -d/--delay <ms>, claims com.cutefish.Screenshot (single instance), translations
src/screenshotview.{h,cpp} ScreenshotView: QQuickView that captures, shows and saves
qml/main.qml              full-screen frozen image, dimmed, with a selection rectangle and a toolbar
qml/ImageButton.qml       toolbar button
cutefish-screenshot.desktop  declares the ScreenShot2 permission (see below)
```

## How it works

1. **Starting:** `main.cpp` registers `com.cutefish.Screenshot` on the session bus. If that name is taken, another instance is running, and this one exits. With `-d N` it waits N ms first; the status bar's Control Center passes `-d 500` so its own popup has closed.
2. **Capturing** (`captureScreen`):
   - make a pipe and call `org.kde.KWin /org/kde/KWin/ScreenShot2` `CaptureScreen(outputName, options, fd)`;
   - KWin writes raw pixels into the pipe and replies with `width`, `height`, `stride` and `format`;
   - the pixels become a `QImage` of the primary screen, in device pixels;
   - it is saved to a temporary PNG in the per-user runtime directory (`tmpFile()`), not in the shared `/tmp`.
3. **Showing:** the view goes frameless and full screen on that output. `main.qml` shows the PNG and lets the user draw and move a selection; arrow keys nudge it and Escape quits. The QML multiplies the selection by `Screen.devicePixelRatio`, since the image is in device pixels.
4. **Output:**
   - `saveFile(rect)` crops and writes `~/Desktop/Screenshot_yyyyMMdd_hhmmss.png`;
   - `copyToClipboard(rect)` puts the crop on the clipboard.

   Both send a desktop notification (`org.freedesktop.Notifications`) and quit. The temporary file (`$XDG_RUNTIME_DIR/cutefish-screenshot.png`) is removed after saving or copying; Escape leaves it, and the next capture overwrites it.

### The KWin permission

KWin serves `org.kde.KWin.ScreenShot2` only to programs whose desktop file lists it in `X-KDE-DBUS-Restricted-Interfaces`. KWin finds that desktop file by comparing the caller's executable with `Exec`'s program as an **absolute path**, so `Exec=/usr/bin/cutefish-screenshot` must stay absolute. Without this line, every capture fails with an authorization error. The same rule applies to any new app that needs a restricted KWin interface.

## API

`ScreenshotView` is exposed to QML as the context property `view`:

| Member | Meaning |
|---|---|
| `QString tmpFile()` | Path of the frozen screen PNG |
| `void saveFile(QRect rect)` | Crop (device pixels) and save to the Desktop, notify, quit |
| `void copyToClipboard(QRect rect)` | Crop and copy to the clipboard, notify, quit |
| `void quit()` | Quit without saving |
| `signal refresh()` | The capture is ready; QML reloads the image |

From C++, `start()` captures now and `delay(ms)` captures after a pause.

## Making changes

- **Capturing all outputs:** only the primary screen is captured today. For multi-display support, call `CaptureScreen` per `QScreen` and open one view per output, or use `CaptureWorkspace`.
- **Save location or format:** change `saveFile`.
- Launching with a delay from other code: `cutefish-screenshot -d <ms>`.
