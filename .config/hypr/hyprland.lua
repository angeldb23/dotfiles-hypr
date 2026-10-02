-- ============================================
-- Hyprland config
-- Base autogenerada + polkit + colores Kanagawa/Gruvbox
-- ============================================

---- MONITORES ----
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

---- MIS PROGRAMAS ----
local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "fuzzel"
local TC = { active = "rgba(d79921ff)", inactive = "rgba(3c3836ff)" }
do
    local ok, t = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/theme-colors.lua")
    if ok and type(t) == "table" then TC = t end
end

---- AUTOSTART ----
-- Authentication agent (so apps can ask for a password) and notifications
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("swaync")
    hl.exec_cmd("waybar")
    hl.exec_cmd(os.getenv("HOME") .. "/scripts/wallpaper-init.sh")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("hypridle")
end)

---- ENTORNO ----
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

---- LOOK AND FEEL ----
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border   = TC.active,  -- warm gold (Gruvbox/Kanagawa)
            inactive_border = TC.inactive,  -- dark gray
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding       = 10,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
})

---- CURVAS Y ANIMACIONES ----
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1}, {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5}, {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0}, {0.1, 1} } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "specialWorkspace",    enabled = true, speed = 2, bezier = "quick", style = "fade" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 2, bezier = "quick", style = "fade" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "quick", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

---- LAYOUTS ----
hl.config({
    dwindle = {
        preserve_split = true,
    },
})
hl.config({
    master = {
        new_status = "master",
    },
})
hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

---- MISC ----
hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = false,
    },
})

---- INPUT ----
hl.config({
    input = {
        kb_layout  = "latam",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

---- KEYBINDS ----
local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end


hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

---- REGLAS DE VENTANAS ----
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

---- EXTRAS DE ANGEL ----
hl.layer_rule({
    name = "blur-waybar",
    match = { namespace = "^waybar$" },
    blur = true,
    ignore_alpha = true,
})

---- WALLPAPER SELECTOR ----
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/wallpaper-grid.py"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/change-wallpaper.sh"))

---- MENU WALLPAPERS FLOTANTE ----
hl.window_rule({
    name  = "wallpaper-picker-float",
    match = { class = "(yad|Yad)" },
    float  = true,
    center = true,
})

---- GRILLA WALLPAPERS FLOTANTE ----
hl.window_rule({
    name  = "wallpaper-grid-float",
    match = { title = "^Wallpapers$" },
    float    = true,
    center   = true,
    rounding = 14,
})

---- SHOW DESKTOP + SCRATCHPAD (normalizado) ----
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/show-desktop.sh"))

---- CAPTURAS DE PANTALLA ----
hl.bind("PRINT",         hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/screenshot.sh"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/screenshot.sh area"))
hl.bind("CTRL + PRINT",  hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/screenshot.sh clip"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/screenshot.sh area"))

---- FLOATING BRIGHTNESS SLIDER ----
hl.window_rule({
    name  = "brightness-float",
    match = { title = "^Brightness$" },
    float    = true,
    center   = true,
    rounding = 12,
})


---- POPUP CAPTURAS FLOTANTE ----
hl.window_rule({
    name  = "screenshot-float",
    match = { title = "^Screenshot$" },
    float    = true,
    center   = true,
    rounding = 14,
})

---- RECORRER WORKSPACES ----
hl.bind(mainMod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

---- FLOATING CALENDAR ----
hl.window_rule({
    name  = "cal-float",
    match = { title = "^Calendar$" },
    float    = true,
    move     = "monitor_w-312 48",
    rounding = 14,
})


---- MAXIMIZAR / FULLSCREEN ----
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

---- WORKSPACES PERSISTENTES ----
hl.workspace_rule({ workspace = "1", persistent = true })
hl.workspace_rule({ workspace = "2", persistent = true })
hl.workspace_rule({ workspace = "3", persistent = true })
hl.workspace_rule({ workspace = "4", persistent = true })

---- MOVER VENTANAS (Super + Shift + flechas) ----
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))


---- TECLADO DE LA LAPTOP DESHABILITADO ----
-- hl.device({ name = "tpd1019:00-093a:0255-touchpad", touchpad = { disable_while_typing = false } })
-- hl.device({ name = "at-translated-set-2-keyboard", enabled = false })

---- THEME SELECTOR ----
hl.window_rule({ name = "themes-float", match = { title = "^Themes$" }, float = true, center = true, rounding = 14 })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/theme-menu.py"))

---- PORTAPAPELES ----
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/clip-menu.sh"))

hl.window_rule({ name = "volume-float", match = { title = "^Volume$" }, float = true, center = true, rounding = 14 })

hl.window_rule({ name = "power-float", match = { title = "^Power$" }, float = true, center = true, rounding = 14 })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(os.getenv("HOME") .. "/scripts/lock.sh"))
