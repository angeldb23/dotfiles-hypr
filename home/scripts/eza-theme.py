#!/usr/bin/env python3
import json, pathlib

H = pathlib.Path.home()

def palette():
    try:
        themes = json.load(open(H / ".config/themes/themes.json"))
        name = (H / ".cache/theme.txt").read_text().strip()
        return themes.get(name) or themes["Gruvbox"]
    except Exception:
        return {}

p = palette()

def c(k, d):
    h = p.get(k, d).lstrip("#")
    return "38;2;%d;%d;%d" % tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

fg    = c("fg",        "#d4be98")
blue  = c("c4",        "#458588")
green = c("c2",        "#76946a")
hi    = c("accent_hi", "#e9b45b")
acc   = c("accent",    "#d79921")
red   = c("red",       "#c34043")
dim   = c("dim",       "#928374")

parts = [
    f"di=1;{blue}", f"ex=1;{green}", f"fi={fg}", f"ln={hi}", f"or={red}",
    f"ur={hi}", f"uw={red}", f"ux={green}", f"ue={green}",
    f"gr={hi}", f"gw={red}", f"gx={green}", f"tr={hi}", f"tw={red}", f"tx={green}",
    f"sn={green}", f"sb={green}", f"uu={hi}", f"gu={hi}", f"un={dim}", f"gn={dim}",
    f"da={dim}", f"ga={green}", f"gm={hi}", f"gd={red}", f"gv={hi}", f"lc={red}", f"lm={red}",
    f"*.md=4;{hi}", f"*.json={hi}", f"*.js={hi}", f"*.ts={blue}", f"*.py={green}",
    f"*.sh={green}", f"*.toml={acc}", f"*.lua={blue}",
]

(H / ".cache").mkdir(exist_ok=True)
(H / ".cache/eza-colors").write_text(":".join(parts))
