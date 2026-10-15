import json, re, pathlib

H = pathlib.Path.home()

def _mix(a, b, t):
    a = a.lstrip("#"); b = b.lstrip("#")
    ca = [int(a[i:i+2], 16) for i in (0, 2, 4)]
    cb = [int(b[i:i+2], 16) for i in (0, 2, 4)]
    return "#%02x%02x%02x" % tuple(round(x + (y - x) * t) for x, y in zip(ca, cb))

def palette():
    try:
        themes = json.load(open(H / ".config/themes/themes.json"))
        name = (H / ".cache/theme.txt").read_text().strip()
        return themes.get(name) or themes["Gruvbox"]
    except Exception:
        return None

def themed(css):
    p = palette()
    if not p:
        return css
    m = {
        "#1d2021": p["bg"], "#282828": p["panel"], "#3c3836": p["sel"],
        "#504945": p["border"], "#d4be98": p["fg"], "#ebdbb2": p["fg_bright"],
        "#e9b45b": p["accent_hi"], "#d79921": p["accent"],
        "#665c54": _mix(p["bg"], p["dim"], 0.5),
        "#76946a": p["c2"], "#458588": p["c4"], "#c34043": p["red"],
    }
    is_bytes = isinstance(css, bytes)
    s = css.decode() if is_bytes else css
    s = re.sub(r"#[0-9a-fA-F]{6}", lambda x: m.get(x.group().lower(), x.group()), s)
    return s.encode() if is_bytes else s
