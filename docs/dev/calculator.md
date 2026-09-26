# calculator

`cutefish-calculator`, a small Qt 6 / QML calculator. Upstream is cutefishos/calculator (Qt 5), ported to Qt 6 by us ([../qt6-porting.md](../qt6-porting.md)). API reference: [api/calculator.md](api/calculator.md).

## Layout

```
main.cpp            QGuiApplication, registers CalcEngine, loads qrc:/qml/main.qml, translations
calcengine.{h,cpp}  the only QML-facing C++ class
engine/             expression evaluator from SpeedCrunch (Ariya Hidayat, 2004)
  evaluator.*       tokenizer, parser, compiler to opcodes, evaluation
  hmath.*, number.* arbitrary-precision numbers (HNumber)
  functions.*       built-in functions (sin, sqrt, …)
  constants.*       named constants
qml/
  main.qml          FishUI.Window: menu bar (About), Zone (display), StandardPad (keys)
  Zone.qml          display: expression TextField and result history; appendToTextField()
  StandardPad.qml   the 4×5 key grid; emits pressed(text)
  StandardButton.qml one key; emits clicked(text)
qml.qrc             QML compiled into the binary
translations/       *.ts, installed as /usr/share/cutefish-calculator/translations/<locale>.qm
cutefish-calculator.desktop
```

## How it works

1. A key in `StandardPad` emits `pressed(text)`. `main.qml` passes it to `zone.appendToTextField(text)`. `Zone` handles `=`, `C` (clears the expression, or the history when the expression is already empty) and `BACKSPACE`, and inserts anything else at the cursor. Enter and Return count as `=`.
2. On `=`, `main.qml`'s `calculate(evalText)` calls `calcEngine.eval(expr)`.
3. `CalcEngine::eval` maps the display operators (`×`, `÷`, full-width `＋`/`－`) to ASCII, then runs `Evaluator::setExpression` and `eval()`. It returns the result formatted with `HMath::formatFixed`. A successful result replaces the expression and is added to the history as `expr = result`. On an error it emits `failed("Error: …")` and returns `""`.

## API

`CalcEngine` is registered as `import Cutefish.Calculator 1.0`:

| Member | Meaning |
|---|---|
| `Q_INVOKABLE QString eval(const QString &expr)` | Evaluate; returns the formatted result, or `""` after emitting `failed` |
| `signal failed(QString errorString)` | Parse or evaluation error, already translated |

A context property `debug` (bool) is true in debug builds.

## Making changes

- **New key or function:** add a `StandardButton` in `StandardPad.qml`. If its label isn't something the evaluator understands, map it in `CalcEngine::eval`, the way `×` is. New functions go in `engine/functions.cpp`; the evaluator finds them by name.
- **Window look:** the root is `FishUI.Window`. Blur and translucency follow the system setting. Don't add a `WindowBlur` or a fixed `background.opacity`; that was the Qt 5 way, and `WindowBlur` no longer has `geometry` (setback 31).
- **Depends:** new `import`s in QML need the matching `qml6-module-*` in `debian/control`.
