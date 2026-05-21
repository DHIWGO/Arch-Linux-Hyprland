-- ============================================================
-- profiles.lua — Motor de Perfiles Dinámicos HyprArch
-- SUPER LITE / NORMAL / FULL
-- ============================================================

local M = {}

-- ============================================================
-- PERFIL: SUPER LITE
-- Sin animaciones, sin blur, sin sombras.
-- Objetivo: máxima duración de batería y mínimo GPU.
-- ============================================================
M["lite"] = {
  name       = "lite",
  label      = "⚡ Super Lite",
  desc       = "Máximo ahorro de energía. Sin efectos visuales.",

  -- Efectos
  animations = false,
  blur       = false,
  shadows    = false,
  blur_size  = 0,
  blur_passes= 0,

  -- Sin set de animaciones
  animation_set = {
    { "global", 0, 1, "linear" },
  },

  -- Barra ultra-ligera
  bar_cmd = "waybar --config ~/.config/waybar/lite.jsonc",

  -- Procesos en segundo plano mínimos
  background_processes = {
    enable_dunst       = true,
    enable_hypridle    = true,
    enable_hyprlock    = true,
    enable_widgets     = false,
    enable_eww         = false,
  },

  -- Hyprland tweaks
  misc_overrides = {
    vfr = true,   -- Variable Frame Rate: reduce GPU idle
    vrr = 2,      -- Adaptive Sync (laptops)
  },

  -- Decoración mínima
  decoration_overrides = {
    rounding         = 4,
    active_opacity   = 1.0,
    inactive_opacity = 1.0,
    dim_inactive     = false,
  },

  -- Mensaje de activación
  on_activate = function()
    os.execute("hyprctl dispatch exec dunstify 'Perfil Lite activado' '⚡ Ahorro máximo de energía'")
    -- Detener procesos pesados
    os.execute("pkill eww 2>/dev/null; pkill ags 2>/dev/null")
    os.execute("hyprctl reload")
  end,
}

-- ============================================================
-- PERFIL: NORMAL
-- Equilibrio entre rendimiento y estética.
-- Animaciones suaves, blur ligero, barra estándar.
-- ============================================================
M["normal"] = {
  name       = "normal",
  label      = "⚖️ Normal",
  desc       = "Equilibrio entre rendimiento y experiencia visual.",

  -- Efectos moderados
  animations = true,
  blur       = true,
  shadows    = true,
  blur_size  = 6,
  blur_passes= 2,

  animation_set = {
    { "windowsIn",  1, 4, "spring",  "slide"  },
    { "windowsOut", 1, 3, "easeIn",  "slide"  },
    { "windowsMove",1, 3, "spring"           },
    { "fade",       1, 4, "easeOut"           },
    { "workspaces", 1, 5, "easeOut", "slide"  },
    { "layers",     1, 3, "easeOut", "slide"  },
    { "specialWorkspace", 1, 4, "spring", "slidevert" },
  },

  bar_cmd = "waybar",

  background_processes = {
    enable_dunst       = true,
    enable_hypridle    = true,
    enable_hyprlock    = true,
    enable_widgets     = false,
    enable_eww         = false,
  },

  misc_overrides = {
    vfr = true,
    vrr = 1,
  },

  decoration_overrides = {
    rounding         = 10,
    active_opacity   = 1.0,
    inactive_opacity = 0.90,
    dim_inactive     = true,
    dim_strength     = 0.15,
  },

  on_activate = function()
    os.execute("hyprctl dispatch exec dunstify 'Perfil Normal' '⚖️ Modo equilibrado activado'")
    os.execute("hyprctl reload")
  end,
}

-- ============================================================
-- PERFIL: FULL
-- Experiencia visual completa. Blur intenso, sombras,
-- animaciones elaboradas, widgets y centro de notificaciones.
-- ============================================================
M["full"] = {
  name       = "full",
  label      = "✨ Full Experience",
  desc       = "Máxima experiencia visual. Requiere GPU dedicada.",

  -- Efectos al máximo
  animations = true,
  blur       = true,
  shadows    = true,
  blur_size  = 12,
  blur_passes= 4,

  animation_set = {
    { "windowsIn",  1, 5, "spring",  "slide"      },
    { "windowsOut", 1, 4, "easeIn",  "slide"      },
    { "windowsMove",1, 4, "spring"                },
    { "fade",       1, 5, "easeOut"               },
    { "fadeIn",     1, 5, "easeOut"               },
    { "fadeOut",    1, 4, "easeIn"                },
    { "workspaces", 1, 6, "spring",  "slide"      },
    { "layers",     1, 4, "spring",  "slide"      },
    { "specialWorkspace", 1, 6, "spring", "slidevert" },
  },

  bar_cmd = "waybar --config ~/.config/waybar/full.jsonc",

  background_processes = {
    enable_dunst       = true,
    enable_hypridle    = true,
    enable_hyprlock    = true,
    enable_widgets     = true,
    enable_eww         = true,    -- Widgets avanzados (eww o ags)
  },

  misc_overrides = {
    vfr = false,  -- Frame rate constante para animaciones suaves
    vrr = 0,
  },

  decoration_overrides = {
    rounding         = 14,
    active_opacity   = 1.0,
    inactive_opacity = 0.88,
    dim_inactive     = true,
    dim_strength     = 0.20,
    -- Glow effect (Hyprland 0.55+)
    col_shadow       = "rgba(89,153,255,0.6)",
    shadow_range     = 20,
    shadow_render_power = 3,
  },

  on_activate = function()
    os.execute("hyprctl dispatch exec dunstify 'Perfil Full' '✨ Experiencia completa activada'")
    -- Iniciar widgets si no están corriendo
    os.execute("pgrep eww || eww daemon && eww open bar")
    os.execute("hyprctl reload")
  end,
}

-- ============================================================
-- FUNCIÓN: Cambiar perfil desde CLI
-- Uso: lua profiles.lua <lite|normal|full>
-- ============================================================
M.switch = function(profile_name)
  local p = M[profile_name]
  if not p then
    io.stderr:write("Error: Perfil desconocido '" .. profile_name .. "'\n")
    io.stderr:write("Perfiles disponibles: lite, normal, full\n")
    os.exit(1)
  end

  -- Escribe el perfil activo
  local f = io.open(os.getenv("HOME") .. "/.config/hypr/active_profile.lua", "w")
  if f then
    f:write(string.format('return { name = "%s" }\n', profile_name))
    f:close()
  end

  -- Ejecuta callback de activación
  if p.on_activate then
    p.on_activate()
  end

  print("Perfil '" .. p.label .. "' activado.")
end

-- ── Si se ejecuta directamente con argumento ──────────────
if arg and arg[1] then
  M.switch(arg[1])
end

return M
