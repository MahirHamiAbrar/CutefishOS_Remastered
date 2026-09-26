#!/usr/bin/env python3
"""Generate docs/dev/api/<repo>.md: the API surface of each repo under src/.

Lists, per file, what other code can use:
  C++ headers  classes with their Q_PROPERTYs, Q_INVOKABLEs, public slots,
               signals and other public methods
  D-Bus XML    interfaces with their methods, properties and signals
  QML          files registered as types (qmldir, or components in controls/
               folders) with their root-level properties, signals and functions

Usage: scripts/gen-dev-api.py [repo ...]   (default: every repo with code)
Rerun after changing a repo; the hand-written guides in docs/dev/ link here.
"""
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC, OUT = ROOT / "src", ROOT / "docs" / "dev" / "api"
# Upstream trees too big to list whole: only the files our patches touch.
PATCHED_ONLY = {"kwin-ubuntu", "calamares-ubuntu"}
SKIP_DIRS = ("3rdparty/", "tests/", "test/", "autotests/", "obj-", "debian/")


def tracked(repo):
    out = subprocess.run(["git", "-C", str(SRC / repo), "ls-files"],
                         capture_output=True, text=True, check=True).stdout
    return [f for f in out.splitlines() if not any(s in f for s in SKIP_DIRS)]


def patched_files(repo):
    """Files changed by our commits on top of the imported upstream tree."""
    git = ["git", "-C", str(SRC / repo)]
    base = subprocess.run(git + ["rev-list", "--max-parents=0", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.split()[0]
    out = subprocess.run(git + ["diff", "--name-only", base, "HEAD"],
                         capture_output=True, text=True, check=True).stdout
    return [f for f in out.splitlines() if not f.startswith("debian/")]


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def cpp_classes(text):
    """Yield (name, bases, body) for each class/struct with a body."""
    for m in re.finditer(r"\b(class|struct)\s+(?:\w+_EXPORT\s+)?(\w+)\s*(?:final\s*)?"
                         r"(:\s*[^{;]+)?\{", text):
        depth, i = 1, m.end()
        while depth and i < len(text):
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        bases = re.sub(r"\s+", " ", (m.group(3) or "").lstrip(":").strip())
        yield m.group(2), bases, text[m.end():i - 1], m.group(1)


def top_level(body):
    """The class body with nested braces (inline bodies, enums) collapsed."""
    out, depth = [], 0
    for ch in body:
        if ch == "{":
            depth += 1
            if depth == 1:
                out.append(";")  # an inline body ends a declaration too
        elif ch == "}":
            depth -= 1
        elif depth == 0:
            out.append(ch)
    return "".join(out)


def clean(decl):
    decl = re.sub(r"\s+", " ", decl).strip()
    decl = re.sub(r"\)\s*:\s*\w+[({].*$", ")", decl)  # constructor init list
    decl = re.sub(r"\s*=\s*0$", "", decl)
    return decl.replace("Q_INVOKABLE ", "").replace("Q_SCRIPTABLE ", "").strip()


def cpp_section(path, text):
    text = strip_comments(text)
    lines = []
    for name, bases, body, kind in cpp_classes(text):
        if "Q_OBJECT" not in body and "Q_GADGET" not in body and kind == "struct":
            continue
        flat = top_level(body)
        props = [clean(p) for p in re.findall(r"Q_PROPERTY\s*\((.*?)\)\s*(?=\n|Q_|$)", body, re.S)]
        invokables, slots, signals, methods = [], [], [], []
        access = "private" if kind == "class" else "public"
        for part in re.split(r"(\b(?:public|protected|private)\s*(?:Q_SLOTS|slots)?\s*:|\b(?:Q_SIGNALS|signals)\s*:)",
                             flat):
            head = part.strip()
            if re.fullmatch(r"(public|protected|private)\s*(Q_SLOTS|slots)?\s*:", head) or \
               re.fullmatch(r"(Q_SIGNALS|signals)\s*:", head):
                access = head.rstrip(":").strip()
                continue
            for decl in part.split(";"):
                d = clean(decl)
                if "(" not in d or d.startswith(("Q_OBJECT", "Q_PROPERTY", "Q_ENUM", "Q_DECLARE",
                                                 "Q_GADGET", "QML_", "Q_DISABLE", "friend",
                                                 "using", "typedef", "Q_CLASSINFO")):
                    continue
                if "Q_INVOKABLE" in decl:
                    invokables.append(d)
                elif re.match(r"(Q_SIGNALS|signals)", access):
                    signals.append(d)
                elif re.match(r"public\s*(Q_SLOTS|slots)", access):
                    slots.append(d)
                elif access == "public":
                    methods.append(d)
        if not (props or invokables or slots or signals or methods):
            continue
        lines.append(f"### `{name}`" + (f" : `{bases}`" if bases else ""))
        lines.append(f"`{path}`\n")
        for title, items in (("Properties", props), ("Invokable from QML", invokables),
                             ("Public slots", slots), ("Signals", signals),
                             ("Public methods", methods)):
            if items:
                lines.append(f"**{title}**\n")
                lines += [f"- `{i}`" for i in items]
                lines.append("")
    return lines


def dbus_section(path, text):
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        return []
    lines = []
    for iface in root.iter("interface"):
        lines.append(f"### D-Bus `{iface.get('name')}`\n`{path}`\n")
        for kind in ("method", "signal", "property"):
            for el in iface.findall(kind):
                args = ", ".join(f"{a.get('direction', 'in') if kind == 'method' else ''} "
                                 f"{a.get('type')} {a.get('name') or ''}".strip()
                                 for a in el.findall("arg"))
                if kind == "property":
                    lines.append(f"- property `{el.get('type')} {el.get('name')}` ({el.get('access')})")
                else:
                    lines.append(f"- {kind} `{el.get('name')}({args})`")
        lines.append("")
    return lines


def qml_section(path, text, typename):
    text = strip_comments(text)
    m = re.search(r"^\s*([A-Z][\w.]*)\s*\{", text, re.M)
    if not m:
        return []
    root, depth, i = m.group(1), 1, m.end()
    body = []
    while i < len(text) and depth:
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
        elif depth == 1:
            body.append(ch)
        i += 1
    flat = "".join(body)
    items = []
    for line in flat.splitlines():
        line = line.strip().rstrip(";")
        if re.match(r"(readonly |default |required )*property\s", line):
            items.append(re.sub(r"\s*:\s*$", "", line.split(":")[0] if "alias" not in line else line))
        elif line.startswith("signal "):
            items.append(line)
    items += [f"function {f}" for f in re.findall(r"\bfunction\s+(\w+\s*\([^)]*\))", text)
              if not f.startswith("_")]
    if not items:
        return [f"- **{typename}** (`{path}`, based on `{root}`)"]
    return [f"- **{typename}** (`{path}`, based on `{root}`)"] + [f"  - `{x.strip()}`" for x in items]


def qml_types(repo, files):
    """Map QML file -> exported type name, from qmldir files."""
    types = {}
    for q in (f for f in files if f.endswith("qmldir")):
        base = Path(q).parent
        for line in (SRC / repo / q).read_text(errors="replace").splitlines():
            parts = line.split()
            if len(parts) >= 2 and parts[-1].endswith(".qml") and parts[0][0].isupper():
                types[str(base / parts[-1])] = parts[0]
    return types


def generate(repo):
    files = tracked(repo)
    if repo in PATCHED_ONLY:
        files = [f for f in patched_files(repo) if f in files]
    cpp, dbus, qml = [], [], []
    types = qml_types(repo, files)
    for f in files:
        p = SRC / repo / f
        if not p.is_file():
            continue
        text = p.read_text(errors="replace")
        if f.endswith(".h") and "moc_" not in f:
            cpp += cpp_section(f, text)
        elif f.endswith(".xml") and "<interface" in text:
            dbus += dbus_section(f, text)
        elif f.endswith(".qml") and f in types:
            qml += qml_section(f, text, types[f])
    if not (cpp or dbus or qml):
        return False
    out = [f"# `{repo}` API reference", "",
           f"Generated by `scripts/gen-dev-api.py` from `src/{repo}`; do not edit by hand. "
           f"The guide is [../{repo}.md](../{repo}.md).", ""]
    if repo in PATCHED_ONLY:
        out += ["Only the files our patches change are listed.", ""]
    for title, part in (("D-Bus interfaces", dbus), ("QML types", qml), ("C++ classes", cpp)):
        if part:
            out += [f"## {title}", ""] + part + [""]
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{repo}.md").write_text("\n".join(out).rstrip() + "\n")
    return True


if __name__ == "__main__":
    repos = sys.argv[1:] or sorted(p.name for p in SRC.iterdir() if (p / ".git").exists())
    for r in repos:
        print(("ok   " if generate(r) else "none ") + r)
