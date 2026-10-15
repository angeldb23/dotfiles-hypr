#!/usr/bin/env python3
# Backend de la app de ajustes (qs -c settings). Cada comando imprime JSON o aplica un cambio.
import glob, json, os, re, subprocess, sys
from urllib.parse import quote
import hashlib

H = os.path.expanduser("~")
CFG = os.path.join(H, ".config/qs-settings.json")

def run(*a, timeout=6):
    try:
        r = subprocess.run(list(a), capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""

# clave -> (ruta en la tabla de Hyprland, tipo, opcion para leer el valor actual)
HYPR = {
    "gaps_in": (["general", "gaps_in"], "int", "general:gaps_in"),
    "gaps_out": (["general", "gaps_out"], "int", "general:gaps_out"),
    "border_size": (["general", "border_size"], "int", "general:border_size"),
    "rounding": (["decoration", "rounding"], "int", "decoration:rounding"),
    "blur": (["decoration", "blur", "enabled"], "bool", "decoration:blur:enabled"),
}

def lua_val(kind, v):
    if kind == "bool":
        return "true" if str(v).lower() in ("1", "true", "yes", "on") else "false"
    return str(int(float(v)))

def lua_table(path, val):
    s = val
    for k in reversed(path):
        s = "{ %s = %s }" % (k, s)
    return s

def hypr_apply(key, v):
    path, kind, _ = HYPR[key]
    run("hyprctl", "eval", "hl.config(%s)" % lua_table(path, lua_val(kind, v)))

def load():
    try:
        return json.load(open(CFG))
    except Exception:
        return {}

def save(d):
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    json.dump(d, open(CFG, "w"), indent=2)

def out(o):
    print(json.dumps(o))

def cmd_hypr_get():
    o = {}
    for key, (_, kind, opt) in HYPR.items():
        try:
            j = json.loads(run("hyprctl", "getoption", opt, "-j"))
            if "int" in j: v = j["int"]
            elif "custom" in j: v = int(str(j["custom"]).split()[0])
            elif "float" in j: v = int(j["float"])
            else: continue
            o[key] = bool(v) if kind == "bool" else int(v)
        except Exception:
            pass
    out(o)

def cmd_set(key, val):
    if key not in HYPR:
        sys.exit("clave desconocida: " + key)
    d = load(); d[key] = val; save(d)
    hypr_apply(key, val)

def cmd_apply():
    for k, v in load().items():
        if k in HYPR:
            hypr_apply(k, v)

def cmd_monitors():
    try:
        j = json.loads(run("hyprctl", "monitors", "-j"))
        out([{"name": m.get("name", "?"), "w": m.get("width"), "h": m.get("height"),
              "hz": round(m.get("refreshRate", 0)), "scale": m.get("scale", 1)} for m in j])
    except Exception:
        out([])

def cmd_wifi():
    r = run("nmcli", "radio", "wifi")
    ssid, sig = "", 0
    for line in run("nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "device", "wifi").splitlines():
        if line.startswith("yes:"):
            p = line.split(":")
            try: sig = int(p[-1] or 0)
            except Exception: sig = 0
            ssid = ":".join(p[1:-1]).replace("\\", "")
            break
    out({"available": r != "", "enabled": r == "enabled", "ssid": ssid, "signal": sig})

def cmd_bt():
    show = run("bluetoothctl", "show")
    if not show:
        out({"available": False, "powered": False, "devices": []}); return
    devs = []
    for line in run("bluetoothctl", "devices").splitlines():
        m = re.match(r"Device\s+([0-9A-Fa-f:]{17})\s+(.*)", line)
        if m:
            mac, name = m.groups()
            info = run("bluetoothctl", "info", mac)
            devs.append({"mac": mac, "name": name, "connected": "Connected: yes" in info,
                         "paired": "Paired: yes" in info})
    devs.sort(key=lambda d: (not d["connected"], d["name"].lower()))
    out({"available": True, "powered": "Powered: yes" in show, "devices": devs})

def cmd_notif():
    cnt, dnd = 0, False
    try:
        last = open(os.path.join(H, ".cache/notif-state.log")).read().strip().splitlines()[-1]
        j = json.loads(last)
        cnt = int(j.get("text", 0)); dnd = str(j.get("alt", "")).startswith("dnd")
    except Exception:
        pass
    out({"count": cnt, "dnd": dnd})

def cmd_power():
    cap = status = ""
    for d in glob.glob("/sys/class/power_supply/BAT*"):
        try:
            cap = open(d + "/capacity").read().strip()
            status = open(d + "/status").read().strip()
            break
        except Exception:
            pass
    prof = run("powerprofilesctl", "get")
    profs = re.findall(r"^[\s*]*([a-z-]+):\s*$", run("powerprofilesctl", "list"), re.M)
    out({"capacity": cap, "status": status, "profile": prof, "profiles": profs})

def cmd_info():
    mem = cpu = ""
    try:
        m = {l.split(":")[0]: int(l.split()[1]) for l in open("/proc/meminfo")}
        mem = "%.1f / %.1f GiB" % ((m["MemTotal"] - m["MemAvailable"]) / 1048576, m["MemTotal"] / 1048576)
    except Exception:
        pass
    try:
        for l in open("/proc/cpuinfo"):
            if l.startswith("model name"):
                cpu = l.split(":", 1)[1].strip(); break
    except Exception:
        pass
    disk = ""
    try:
        st = os.statvfs("/")
        tot = st.f_blocks * st.f_frsize / 2**30; free = st.f_bavail * st.f_frsize / 2**30
        disk = "%.0f / %.0f GiB" % (tot - free, tot)
    except Exception:
        pass
    up = ""
    try:
        s = float(open("/proc/uptime").read().split()[0])
        up = "%dh %02dm" % (s // 3600, s % 3600 // 60)
    except Exception:
        pass
    hl = (run("hyprctl", "version").splitlines() or [""])[0]
    out({"host": run("hostname"), "kernel": run("uname", "-r"), "cpu": cpu, "mem": mem,
         "disk": disk, "uptime": up,
         "quickshell": run("quickshell", "--version") or run("qs", "--version"),
         "hyprland": hl.split(" built")[0]})

THUMBS = os.path.join(H, ".cache/wallthumbs")

def thumb_path(src):
    return os.path.join(THUMBS, hashlib.sha1(src.encode()).hexdigest()[:16] + ".jpg")

def mkthumb(src, dst):
    os.makedirs(THUMBS, exist_ok=True)
    tmp = dst + ".tmp.jpg"
    done = False
    try:
        from PIL import Image
        Image.MAX_IMAGE_PIXELS = None
        im = Image.open(src)
        try: im.draft("RGB", (760, 464))
        except Exception: pass
        im = im.convert("RGB")
        im.thumbnail((380, 232))
        im.save(tmp, "JPEG", quality=82)
        done = True
    except Exception:
        pass
    if not done:
        for tool in ("magick", "convert"):
            try:
                r = subprocess.run([tool, src + "[0]", "-thumbnail", "380x232", "-quality", "82", tmp],
                                   capture_output=True, timeout=60)
                if r.returncode == 0:
                    break
            except Exception:
                pass
    if os.path.isfile(tmp):
        os.replace(tmp, dst)
        return True
    return False

def cmd_wall_thumbs():
    base = os.path.join(H, "wallpapers")
    made = fail = 0
    for dirpath, _, files in os.walk(base):
        for f in sorted(files):
            if not f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                continue
            src = os.path.join(dirpath, f)
            dst = thumb_path(src)
            if os.path.isfile(dst) and os.path.getmtime(dst) >= os.path.getmtime(src):
                continue
            if mkthumb(src, dst): made += 1
            else: fail += 1
    print("miniaturas creadas: %d, fallidas: %d" % (made, fail))

def cmd_wallpapers():
    cur = ""
    try:
        cur = open(os.path.join(H, ".cache/current_wallpaper.txt")).read().strip()
    except Exception:
        pass
    base = os.path.join(H, "wallpapers")
    opt = os.path.join(H, ".cache/wallfull")
    items = []
    pending = 0
    for dirpath, _, files in os.walk(base):
        for f in files:
            if not f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                continue
            stem = os.path.splitext(f)[0]
            o = os.path.join(opt, stem + ".jpg")
            full = os.path.join(dirpath, f)
            t = thumb_path(full)
            ok = os.path.isfile(t) and os.path.getmtime(t) >= os.path.getmtime(full)
            if not ok: pending += 1
            items.append({"path": full, "name": stem, "thumb": ("file://" + quote(t)) if ok else ""})
    items.sort(key=lambda i: i["name"].lower())
    if pending and subprocess.run(["pgrep", "-f", "qs-settings.py wall-thumbs"], capture_output=True).returncode != 0:
        subprocess.Popen(["nice", "-n", "10", "python3", os.path.abspath(__file__), "wall-thumbs"],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    out({"current": cur, "items": items, "pending": pending})

HYPRLUA = os.path.join(H, ".config/hypr/hyprland.lua")
MODS = {"SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "CONTROL": "Ctrl", "ALT": "Alt", "MOD": "Mod"}

def _call_body(text, start):
    depth, q, i = 1, None, start
    while i < len(text):
        c = text[i]
        if q:
            if c == "\\":
                i += 1
            elif c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return text[start:i]
        i += 1
    return None

def _split_top(s, sep):
    parts, cur, depth, q, i = [], "", 0, None, 0
    while i < len(s):
        c = s[i]
        if q:
            cur += c
            if c == "\\" and i + 1 < len(s):
                i += 1
                cur += s[i]
            elif c == q:
                q = None
        elif c in "\"'":
            q = c
            cur += c
        elif c in "({[":
            depth += 1
            cur += c
        elif c in ")}]":
            depth -= 1
            cur += c
        elif depth == 0 and s.startswith(sep, i):
            parts.append(cur)
            cur = ""
            i += len(sep) - 1
        else:
            cur += c
        i += 1
    parts.append(cur)
    return [p.strip() for p in parts]

def _keys(expr, vars_):
    s = ""
    for p in _split_top(expr, ".."):
        if len(p) >= 2 and p[0] in "\"'" and p[-1] == p[0]:
            s += p[1:-1]
        elif p in vars_:
            s += vars_[p]
        else:
            s += "N"
    toks = [t for t in re.split(r"[\s+]+", s) if t]
    if not toks:
        return "?"
    last = toks[-1].upper() if len(toks[-1]) == 1 else toks[-1]
    return " + ".join([MODS.get(t.upper(), t) for t in toks[:-1]] + [last])

def _act(expr):
    e = re.sub(r"\s+", " ", expr)
    e = re.sub(r'os\.getenv\("HOME"\) \.\. "', '"~', e)
    m = re.match(r"hl\.dsp\.exec_cmd\((.*)\)$", e)
    if m:
        c = m.group(1).strip()
        if len(c) >= 2 and c[0] in "\"'" and c[-1] == c[0]:
            c = c[1:-1]
        return c
    return re.sub(r"^hl\.dsp\.", "", e)

import io, contextlib

BMODS = [(64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")]

def _bkeys(b):
    mm = int(b.get("modmask", 0) or 0)
    parts = [n for bit, n in BMODS if mm & bit]
    k = str(b.get("key", "") or "")
    if not k:
        kc = b.get("keycode", 0)
        k = ("code:%s" % kc) if kc else "?"
    if len(k) == 1:
        k = k.upper()
    sm = str(b.get("submap", "") or "")
    return ("[%s] " % sm if sm else "") + " + ".join(parts + [k])

def _bnorm(keys):
    keys = re.sub(r"^\[[^\]]*\]\s*", "", keys)
    return "+".join(sorted(x.strip().lower() for x in keys.split(" + ")))

import io, contextlib

DIRS = {"left": "left", "right": "right", "up": "up", "down": "down",
        "l": "left", "r": "right", "u": "up", "d": "down"}

SCRIPT_NAMES = {
    "bar-toggle": "Toggle Quickshell / waybar bar",
    "theme-menu": "Theme picker",
    "theme-set": "Apply theme",
    "clip-menu": "Clipboard history",
    "lock": "Lock screen",
    "settings-toggle": "Open settings app",
    "wifi-menu": "Wi-Fi menu",
    "cal-popup": "Calendar",
    "brillo-slider": "Brightness slider",
    "change-wallpaper": "Random wallpaper",
    "set-wallpaper": "Set wallpaper",
    "wallpaper-grid": "Wallpaper picker",
}

CMD_PATTERNS = [
    (r"btop|htop|bpytop", "System monitor"),
    (r"set-volume.*\d%?\+", "Volume up"),
    (r"set-volume.*\d%?-", "Volume down"),
    (r"set-mute.*source", "Mute microphone"),
    (r"set-mute", "Mute / unmute audio"),
    (r"brightnessctl.*\d%?\+", "Brightness up"),
    (r"brightnessctl.*\d%?-", "Brightness down"),
    (r"playerctl.*play-pause", "Play / pause"),
    (r"playerctl.*next", "Next track"),
    (r"playerctl.*prev", "Previous track"),
    (r"slurp", "Screenshot (region)"),
    (r"grim|screenshot", "Screenshot"),
    (r"hyprpicker", "Color picker"),
    (r"cliphist", "Clipboard history"),
    (r"swaync-client", "Notification panel"),
    (r"wlogout", "Power menu"),
    (r"lock-session|hyprlock|swaylock", "Lock screen"),
    (r"systemctl\s+suspend", "Suspend"),
    (r"systemctl\s+poweroff|shutdown", "Power off"),
    (r"systemctl\s+reboot|reboot", "Reboot"),
    (r"kitty|alacritty|wezterm|\bfoot\b", "Open terminal"),
    (r"fuzzel|rofi|wofi", "App launcher"),
    (r"firefox|chromium|chrome|brave|zen-browser", "Open browser"),
    (r"thunar|nautilus|dolphin|nemo|pcmanfm", "Open file manager"),
]

def _prettify(s):
    s = re.sub(r"[-_.]+", " ", s).strip()
    return s[:1].upper() + s[1:]

def _ws_name(num):
    n = num.strip().lower()
    if re.fullmatch(r"[er]?\+1", n) or n == "next":
        return "next"
    if re.fullmatch(r"[er]?-1", n) or n in ("previous", "prev"):
        return "previous"
    if n == "empty":
        return "empty"
    return num

def _human_cmd(c):
    c = c.strip()
    m2 = re.match(r"^(?:sh|bash|zsh)\s+-c\s+(.*)$", c)
    if m2:
        return _human_cmd(m2.group(1).strip("\"'"))
    low = c.lower()
    m = re.search(r"([\w\-\.]+?)\.(?:sh|py)\b", c)
    if m and m.group(1).lower() in SCRIPT_NAMES:
        return SCRIPT_NAMES[m.group(1).lower()]
    q = re.search(r"qs\b.*?ipc call\s+(\w+)\s+(\w+)", low)
    if q:
        verbs = {"toggle": "Toggle", "open": "Open", "close": "Close"}
        return verbs.get(q.group(2), _prettify(q.group(2))) + " " + q.group(1)
    for pat, txt in CMD_PATTERNS:
        if re.search(pat, low):
            return txt
    if m:
        return _prettify(m.group(1))
    parts = c.split()
    first = os.path.basename(parts[0].strip("\"'")) if parts else ""
    return ("Run " + first) if first else c

def _human_dsp(name, args):
    n = name.lower()
    al = args.lower()
    a = args.strip().strip("\"")
    if "exec" in n:
        return _human_cmd(a)
    d = re.search(r"direction\s*=\s*\"(\w+)\"", args)
    direction = DIRS.get(d.group(1).lower(), d.group(1)) if d else DIRS.get(a.lower(), "")
    w = re.search(r"workspace\s*=\s*\"?([\w\+\-\.]+)\"?", args)
    if w:
        num = w.group(1)
    elif re.fullmatch(r"[\w\+\-\.]+", a) and a.lower() not in DIRS:
        num = a
    else:
        num = ""
    ws = "workspace" in n or "workspace" in al
    special = "special" in n or "special" in al
    if n == "exit":
        return "Exit Hyprland"
    if "close" in n or "kill" in n:
        return "Close window"
    if "float" in n:
        return "Toggle floating window"
    if "fullscreen" in n:
        return "Maximize window" if ("maximize" in al or a == "1") else "Fullscreen"
    if "pseudo" in n:
        return "Toggle pseudo-tile"
    if re.search(r"(^|[._])pin($|[._])", n):
        return "Pin window"
    if "split" in n:
        return "Toggle split orientation"
    if "drag" in n:
        return "Move window with mouse"
    if "resize" in n:
        return ("Resize window " + direction).strip()
    if "movetoworkspace" in n or ("move" in n and "focus" not in n and ws):
        if special:
            return "Move window to special workspace"
        return "Move window to workspace " + (_ws_name(num) if num else "selected")
    if "workspace" in n or ("focus" in n and ws):
        if special:
            return "Toggle special workspace"
        return ("Go to workspace " + _ws_name(num)) if num else "Switch workspace"
    if "focus" in n:
        return ("Focus window " + direction).strip()
    if "move" in n:
        return ("Move window " + direction).strip()
    if "swap" in n:
        return ("Swap window " + direction).strip()
    if "cycle" in n:
        return "Focus next window"
    if "submap" in n:
        return "Switch keybind mode"
    nice = _prettify(re.sub(r"[._]+", " ", name))
    vals = re.findall(r"=\s*\"?([\w\-\+\.]+)\"?", args)
    return nice + ((" (" + ", ".join(vals) + ")") if vals else "")

def humanize(act):
    a = act.strip()
    if not a.startswith(("~", "/")):
        m = re.match(r"^([A-Za-z_][\w\.]*)\s*\((.*)\)$", a, re.S)
        if m:
            return _human_dsp(m.group(1), m.group(2))
        m = re.match(r"^(exit|killactive|togglefloating|fullscreen|pseudo|togglesplit|movefocus|movewindow|resizeactive|workspace|movetoworkspace|movetoworkspacesilent|cyclenext|swapwindow|togglespecialworkspace|pin|exec)\b\s*(.*)$", a)
        if m:
            if m.group(1) == "exec":
                return _human_cmd(m.group(2))
            return _human_dsp(m.group(1), m.group(2))
    return _human_cmd(a)

def cmd_binds():
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        cmd_binds_raw()
    try:
        data = json.loads(buf.getvalue())
    except Exception:
        data = []
    for b in data:
        d = b.get("desc", "")
        if re.search(r"[-=#*]{3,}", d):
            d = ""
        b["desc"] = d
        try:
            b["what"] = humanize(b.get("act", ""))
        except Exception:
            b["what"] = b.get("act", "")
    out(data)

def cmd_binds_raw():
    try:
        r = subprocess.run(["hyprctl", "binds", "-j"], capture_output=True, text=True, timeout=5)
        raw = json.loads(r.stdout)
        if not isinstance(raw, list) or not raw:
            raise ValueError("sin binds")
    except Exception:
        cmd_binds_lua()
        return
    lua = {}
    try:
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            cmd_binds_lua()
        for x in json.loads(buf.getvalue()):
            lua.setdefault(_bnorm(x["keys"]), x)
    except Exception:
        pass
    res, seen = [], set()
    for b in raw:
        keys = _bkeys(b)
        l = lua.get(_bnorm(keys), {})
        rt = (str(b.get("dispatcher", "") or "") + " " + str(b.get("arg", "") or "")).strip()
        act = l.get("act") or rt or "(funcion Lua)"
        desc = str(b.get("description", "") or "") or l.get("desc", "")
        sig = (keys, act)
        if sig in seen:
            continue
        seen.add(sig)
        res.append({"keys": keys, "act": act, "desc": desc})
    out(res)

def cmd_binds_lua():
    try:
        text = open(HYPRLUA).read()
    except Exception:
        out([]); return
    vars_ = dict(re.findall(r'local\s+(\w+)\s*=\s*"([^"]*)"', text))
    res = []
    for m in re.finditer(r"^[ \t]*hl\.bind\w*\(", text, re.M):
        body = _call_body(text, m.end())
        if body is None:
            continue
        args = _split_top(body, ",")
        if len(args) < 2:
            continue
        end = m.end() + len(body) + 1
        nl = text.find("\n", end)
        tail = text[end:(len(text) if nl < 0 else nl)]
        desc = ""
        tm = re.search(r"--\s*(.*)$", tail)
        if tm:
            desc = tm.group(1).strip()
        else:
            prev = text[:m.start()].splitlines()
            if prev and prev[-1].strip().startswith("--"):
                desc = prev[-1].strip().lstrip("-").strip()
        if desc and set(desc) <= set("=-# "):
            desc = ""
        res.append({"keys": _keys(args[0], vars_), "act": _act(args[1]), "desc": desc})
    out(res)

def main():
    a = sys.argv[1:]
    if not a: sys.exit("uso: qs-settings.py <comando>")
    c = a[0]
    table = {"hypr-get": cmd_hypr_get, "apply": cmd_apply, "monitors": cmd_monitors, "wifi": cmd_wifi,
             "bt": cmd_bt, "notif": cmd_notif, "power": cmd_power, "info": cmd_info, "wallpapers": cmd_wallpapers, "wall-thumbs": cmd_wall_thumbs, "binds": cmd_binds}
    if c in table: table[c]()
    elif c == "set" and len(a) == 3: cmd_set(a[1], a[2])
    elif c == "wifi-power" and len(a) == 2: run("nmcli", "radio", "wifi", a[1])
    elif c == "bt-power" and len(a) == 2: run("bluetoothctl", "power", a[1])
    elif c == "bt-toggle" and len(a) == 3: run("bluetoothctl", "disconnect" if a[2] == "1" else "connect", a[1], timeout=15)
    elif c == "bt-scan": run("bluetoothctl", "--timeout", "10", "scan", "on", timeout=15)
    elif c == "power-profile" and len(a) == 2: run("powerprofilesctl", "set", a[1])
    else: sys.exit("comando desconocido")

main()
