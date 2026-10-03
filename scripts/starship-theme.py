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
def g(k, d):
    return p.get(k, d)

TPL = r'''add_newline = true
palette = "theme"
format = """
[\ue0b6](fg:t_user)\
$os\
$username\
[\ue0b0](bg:t_dir fg:t_user)\
$directory\
[\ue0b0](fg:t_dir bg:t_git)\
$git_branch\
$git_status\
[\ue0b0](fg:t_git bg:t_lang)\
$c$rust$golang$nodejs$php$java$kotlin$haskell$python\
[\ue0b0](fg:t_lang bg:t_tip)\
$docker_context\
[\ue0b0](fg:t_tip bg:t_time)\
$time\
[\ue0b4](fg:t_time)\
$cmd_duration \
$character"""

[palettes.theme]
t_text = "@TEXT@"
t_user = "@USER@"
t_dir  = "@DIR@"
t_git  = "@GIT@"
t_lang = "@LANG@"
t_tip  = "@TIP@"
t_time = "@TIME@"
t_ok   = "@OK@"
t_err  = "@ERR@"
t_dim  = "@DIM@"

[os]
disabled = true

[username]
show_always = true
style_user = "bg:t_user fg:t_text"
style_root = "bg:t_user fg:t_text"
format = "[ $user ]($style)"

[directory]
style = "bg:t_dir fg:t_text"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = "\ue0a0"
style = "bg:t_git"
format = "[[ $symbol $branch ](fg:t_text bg:t_git)]($style)"

[git_status]
style = "bg:t_git"
format = "[[($all_status$ahead_behind )](fg:t_text bg:t_git)]($style)"

[c]
symbol = "\ue61e"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[rust]
symbol = "\ue7a8"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[golang]
symbol = "\ue627"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[nodejs]
symbol = "\ue718"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[php]
symbol = "\ue73d"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[java]
symbol = "\ue738"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[kotlin]
symbol = "\ue634"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[haskell]
symbol = "\ue777"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[python]
symbol = "\ue73c"
style = "bg:t_lang"
format = "[[ $symbol( $version) ](fg:t_text bg:t_lang)]($style)"

[docker_context]
symbol = "\uf308"
style = "bg:t_tip"
format = "[[ $symbol( $context) ](fg:t_text bg:t_tip)]($style)"

[time]
disabled = false
time_format = "%R"
style = "bg:t_time"
format = "[[ \uf017 $time ](fg:t_text bg:t_time)]($style)"

[cmd_duration]
min_time = 2000
format = " [took $duration](t_dim)"

[character]
success_symbol = "[❯](bold t_ok)"
error_symbol   = "[❯](bold t_err)"
'''

out = (TPL
    .replace("@TEXT@", g("bg",        "#1d2021"))
    .replace("@USER@", g("red",       "#c34043"))
    .replace("@DIR@",  g("accent",    "#d79921"))
    .replace("@GIT@",  g("accent_hi", "#e9b45b"))
    .replace("@LANG@", g("c2",        "#76946a"))
    .replace("@TIP@",  g("c4",        "#458588"))
    .replace("@TIME@", g("fg",        "#d4be98"))
    .replace("@OK@",   g("c2",        "#76946a"))
    .replace("@ERR@",  g("red",       "#c34043"))
    .replace("@DIM@",  g("dim",       "#928374")))

(H / ".config").mkdir(exist_ok=True)
(H / ".config/starship.toml").write_text(out)
