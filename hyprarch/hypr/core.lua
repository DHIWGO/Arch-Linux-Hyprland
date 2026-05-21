-- ============================================================
-- core.lua — Motor de Configuración HyprArch
-- Lógica permanente: ventanas, binds, reglas de layout
-- No toca animaciones ni colores (eso va en profiles.lua)
-- ============================================================

-- ── Carga el hardware detectado por el instalador ─────────
local hw_ok, hw = pcall(require, "hardware")
if not hw_ok then
  hw = { gpu = "unknown", chassis = "desktop", ram_gb = 8 }
end

-- ── Carga el tema activo del usuario ─────────────────────
local theme_ok, theme = pcall(require, "theme")
if not theme_ok then
  theme = {
    col_active        = "rgb(89,153,255)",
    col_inactive      = "rgb(50,50,70)",
    col_shadow        = "rgba(0,0,0,0.5)",
    border_size       = 2,
    gaps_in           = 5,
    gaps_out          = 10,
    rounding          = 10,
    active_opacity    = 1.0,
    inactive_opacity  = 0.9,
  }
end

-- ── Carga el perfil activo ────────────────────────────────
local profile_ok, profile = pcall(require, "active_profile")
if not profile_ok then
  profile = { name = "normal" }
end

-- ── Carga la configuración del perfil ────────────────────
local profiles = require("profiles")
local P = profiles[profile.name] or profiles["normal"]

-- ============================================================
-- GENERAL
-- ============================================================
general = {
  border_size               = theme.border_size,
  gaps_in                   = theme.gaps_in,
  gaps_out                  = theme.gaps_out,
  col = {
    active_border           = theme.col_active,
    inactive_border         = theme.col_inactive,
  },
  layout                    = "dwindle",
  allow_tearing             = false,
  resize_on_border          = true,
}

-- ============================================================
-- DECORATION (usa valores del perfil activo)
-- ============================================================
decoration = {
  rounding                  = theme.rounding,
  active_opacity            = theme.active_opacity,
  inactive_opacity          = theme.inactive_opacity,
  fullscreen_opacity        = 1.0,

  shadow = {
    enabled                 = P.shadows,
    range                   = 15,
    render_power            = 3,
    color                   = theme.col_shadow,
  },

  blur = {
    enabled                 = P.blur,
    size                    = P.blur_size or 8,
    passes                  = P.blur_passes or 2,
    vibrancy                = 0.1,
    xray                    = false,
    noise                   = 0.02,
    new_optimizations       = true,
  },
}

-- ============================================================
-- ANIMATIONS (definidas en profiles.lua)
-- ============================================================
animations = {
  enabled = P.animations,
  first_launch_animation = false,

  bezier = {
    { "easeOut",   0, 0, 0.15, 1    },
    { "easeIn",    0.85, 0, 1, 1    },
    { "spring",    0.68,-0.55, 0.27, 1.55 },
    { "linear",    0, 0, 1, 1       },
  },

  animation = P.animation_set or {
    { "windows",    1, 3, "spring"  },
    { "fade",       1, 4, "easeOut" },
    { "workspaces", 1, 4, "easeOut" },
    { "layers",     1, 3, "easeOut" },
  },
}

-- ============================================================
-- LAYOUTS
-- ============================================================
dwindle = {
  pseudotile                = true,
  preserve_split            = true,
  smart_split               = false,
  force_split               = 2,
}

master = {
  new_status                = "master",
  new_on_top                = false,
  no_gaps_when_only         = 1,
}

-- ============================================================
-- MISC
-- ============================================================
misc = {
  disable_hyprland_logo     = true,
  disable_splash_rendering  = true,
  force_default_wallpaper   = 0,
  vrr                       = hw.chassis == "desktop" and 1 or 2,
  key_press_enables_dpms    = true,
  focus_on_activate         = false,
  enable_swallow            = true,
  swallow_regex             = "^(kitty|foot)$",
}

-- ============================================================
-- KEYBINDS
-- ============================================================
-- NOTA: Estos son los binds base. Los personalizados
-- están en ~/.config/hypr/user_binds.lua (generado por GUI)
local MOD = "SUPER"

bind = {
  -- Básicos
  { MOD, "Return",  "exec", "kitty" },
  { MOD, "Q",       "killactive", "" },
  { MOD, "M",       "exit", "" },
  { MOD, "E",       "exec", "thunar" },
  { MOD, "V",       "togglefloating", "" },
  { MOD, "Space",   "exec", "wofi --show drun" },
  { MOD, "P",       "pseudo", "" },
  { MOD, "J",       "togglesplit", "" },

  -- Centro de Control
  { MOD.."SHIFT", "C", "exec", "hyprarch-control" },

  -- Screenshots
  { "",        "Print",       "exec", "grim -g \"$(slurp)\" - | swappy -f -" },
  { MOD,       "Print",       "exec", "grim - | swappy -f -" },

  -- Portapapeles
  { MOD, "period", "exec", "cliphist list | wofi -dmenu | cliphist decode | wl-copy" },

  -- Workspaces
  { MOD, "1", "workspace", "1" }, { MOD, "2", "workspace", "2" },
  { MOD, "3", "workspace", "3" }, { MOD, "4", "workspace", "4" },
  { MOD, "5", "workspace", "5" }, { MOD, "6", "workspace", "6" },
  { MOD, "7", "workspace", "7" }, { MOD, "8", "workspace", "8" },
  { MOD, "9", "workspace", "9" }, { MOD, "0", "workspace", "10" },

  -- Mover ventanas a workspaces
  { MOD.."SHIFT", "1", "movetoworkspace", "1" },
  { MOD.."SHIFT", "2", "movetoworkspace", "2" },
  { MOD.."SHIFT", "3", "movetoworkspace", "3" },
  { MOD.."SHIFT", "4", "movetoworkspace", "4" },
  { MOD.."SHIFT", "5", "movetoworkspace", "5" },

  -- Foco entre ventanas
  { MOD, "left",  "movefocus", "l" },
  { MOD, "right", "movefocus", "r" },
  { MOD, "up",    "movefocus", "u" },
  { MOD, "down",  "movefocus", "d" },

  -- Scratchpad
  { MOD, "S", "togglespecialworkspace", "magic" },
  { MOD.."SHIFT", "S", "movetoworkspace", "special:magic" },

  -- Scroll entre workspaces con rueda
  { MOD, "mouse_down", "workspace", "e+1" },
  { MOD, "mouse_up",   "workspace", "e-1" },
}

-- Binds de volumen y brillo (media keys)
bindel = {
  { "", "XF86AudioRaiseVolume",  "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" },
  { "", "XF86AudioLowerVolume",  "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
  { "", "XF86AudioMute",         "exec", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
  { "", "XF86MonBrightnessUp",   "exec", "brightnessctl s 10%+" },
  { "", "XF86MonBrightnessDown", "exec", "brightnessctl s 10%-" },
}

-- Mover/redimensionar ventanas con ratón
bindm = {
  { MOD, "mouse:272", "movewindow" },
  { MOD, "mouse:273", "resizewindow" },
}

-- ============================================================
-- WINDOW RULES
-- ============================================================
windowrulev2 = {
  -- Floats
  { "float", "class:^(pavucontrol|blueman-manager|nm-connection-editor)$" },
  { "float", "class:^(hyprarch-control)$" },
  { "size 900 600", "class:^(hyprarch-control)$" },
  { "center", "class:^(hyprarch-control)$" },

  -- Terminales con blur
  { "opacity 0.95 0.90", "class:^(kitty|foot)$" },

  -- IDEs: sin opacidad
  { "opacity 1.0 1.0", "class:^(code|jetbrains-.*)$" },

  -- Diálogos
  { "float", "title:^(Preferences|Settings|Confirm|Warning|Error)$" },
  { "center", "title:^(Preferences|Settings|Confirm|Warning|Error)$" },

  -- Steam
  { "workspace 5 silent", "class:^(steam)$" },
  { "float", "title:^(Steam Settings|Friends List)$" },
}

-- ============================================================
-- AUTOSTART
-- ============================================================
exec_once = {
  -- Wayland essentials
  "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
  "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
  "gnome-keyring-daemon --start --components=secrets",

  -- Audio
  "pipewire",
  "pipewire-pulse",
  "wireplumber",

  -- Portapapeles
  "wl-paste --type text --watch cliphist store",
  "wl-paste --type image --watch cliphist store",

  -- Notificaciones
  "dunst",

  -- Barra según perfil
  P.bar_cmd or "waybar",

  -- Fondo de pantalla
  "hyprpaper",

  -- Centro de Control (minimizado en tray)
  "hyprarch-control --tray",
}

-- Carga binds del usuario personalizados (si existen)
pcall(require, "user_binds")
