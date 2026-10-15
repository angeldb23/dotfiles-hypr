#!/usr/bin/env python3
"""Genera el tema 'Dynamic' desde el wallpaper actual y lo aplica con theme-set.py.
Uso: dynamic-theme.py [imagen] [--no-apply] [--type TIPO]
Solo agrega/actualiza la clave 'Dynamic' en themes.json; los demas temas no se tocan."""
import importlib.util, json, os, pathlib, subprocess, sys

H = pathlib.Path.home()
THEMES = H / ".config/themes/themes.json"
NAME = "Dynamic"


def main():
    spec = importlib.util.spec_from_file_location("wallpaper_palette", H / "scripts/wallpaper-palette.py")
    wp = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(wp)

    argv = sys.argv[1:]
    stype = "scheme-fidelity"
    if "--type" in argv:
        i = argv.index("--type")
        stype = argv[i + 1]
        del argv[i:i + 2]
    args = [a for a in argv if not a.startswith("--")]

    if args:
        src = pathlib.Path(args[0]).expanduser()
    else:
        src = pathlib.Path((H / ".cache/current_wallpaper.txt").read_text().strip())
    if not src.exists():
        sys.exit("no existe el wallpaper: %s" % src)
    opt = H / ".cache/wallfull" / (src.stem + ".jpg")  # version optimizada si existe (mas rapida de leer)
    use = opt if opt.exists() else src

    pal = wp.get_palette(use, stype, "saturation")
    data = json.loads(THEMES.read_text())
    data[NAME] = pal
    tmp = THEMES.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    os.replace(tmp, THEMES)
    print("tema '%s' generado desde %s (%s)" % (NAME, use.name, stype))

    if "--no-apply" not in sys.argv:
        subprocess.run([sys.executable, str(H / "scripts/theme-set.py"), NAME])


if __name__ == "__main__":
    main()
