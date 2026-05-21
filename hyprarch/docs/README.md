# HyprArch — Arch Linux + Hyprland Intelligent Environment

Un entorno de escritorio moderno, modular y completamente gestionable sin
tocar archivos de configuración. Basado en **Arch Linux + Hyprland v0.55+**.

---

## 📁 Estructura del Repositorio

```
Arch-Linux-Hyprland/          ← raíz del repositorio
├── README.md
└── hyprarch/
    ├── scripts/
    │   └── install.sh              ← Instalador híbrido v3.0
    ├── hypr/
    │   ├── core.lua                ← Motor de configuración permanente
    │   ├── profiles.lua            ← 3 perfiles: lite / normal / full
    │   ├── user_theme.json         ← Config del usuario (lee/escribe el GUI)
    │   │
    │   │   ── Archivos auto-generados (NO están en el repo) ──
    │   ├── hardware.lua            ← [AUTO] Generado por el instalador
    │   ├── theme.lua               ← [AUTO] Generado por el Centro de Control
    │   ├── active_profile.lua      ← [AUTO] Escrito al cambiar perfil
    │   └── user_binds.lua          ← [AUTO] Generado por el editor de atajos
    │
    ├── control_center/
    │   └── hyprarch_control.py     ← Centro de Control (PyQt6)
    └── presets/
        └── cyberpunk.json          ← Preset de comunidad (ejemplo)
```

> **Archivos `[AUTO]`:** se generan la primera vez que instalas o usas el
> Centro de Control. No los subas al repo ni los edites manualmente.

---

## 🚀 Instalación

### Modo 1 — Desde cero (Arch Linux ISO)

Para sistemas nuevos o que quieres formatear completamente.

```bash
# 1. Arranca desde el USB de Arch Linux (archlinux-2025.xx.xx-x86_64.iso)
# 2. Conecta a internet
iwctl station wlan0 connect "TuRed"

# 3. Clona el repositorio y ejecuta el instalador
git clone https://github.com/DHIWGO/Arch-Linux-Hyprland.git
cd Arch-Linux-Hyprland/hyprarch/scripts
bash install.sh
```

**El instalador te preguntará primero:**

```
¿Cómo deseas instalar HyprArch?

  [1] Instalación desde cero (Arch Linux ISO)
      Particionará el disco. BORRARÁ todos los datos.

  [2] Sobre Arch Linux ya instalado
      Solo instala Hyprland + configuración HyprArch.
      No toca particiones. Seguro para dual-boot.
```

Si eliges **[1]**, tendrás una segunda opción:

```
¿Cómo quieres instalar la base de Arch Linux?

  [1] archinstall (recomendado para principiantes)
      Asistente oficial con menús. HyprArch se superpone al finalizar.

  [2] Instalador HyprArch personalizado (control total)
      BTRFS + GRUB + subvolúmenes, todo automático.
```

---

### Modo 2 — Sobre Arch Linux ya instalado

Para usuarios con Arch ya funcionando (incluyendo **dual-boot**).
**No toca particiones. No borra nada.**

```bash
git clone https://github.com/DHIWGO/Arch-Linux-Hyprland.git
cd Arch-Linux-Hyprland/hyprarch/scripts
bash install.sh
# → Elige opción [2] en el primer menú
```

El instalador:
1. Detecta tu hardware (GPU, CPU, chasis, batería)
2. Instala Hyprland + todo el stack Wayland con `pacman`
3. Instala drivers GPU correctos según tu hardware
4. Si tienes laptop: configura TLP + brillo + touchpad
5. Genera `hardware.lua` específico para tu máquina
6. Copia los archivos de configuración a `~/.config/hypr/`
7. Instala el Centro de Control en `/usr/local/bin/hyprarch-control`

---

## 🎨 Centro de Control

```bash
# Lanzar interfaz gráfica
hyprarch-control

# Lanzar en system tray (autostart)
hyprarch-control --tray

# Cambiar perfil desde terminal
hyprarch-control --profile lite
hyprarch-control --profile normal
hyprarch-control --profile full

# Re-detectar hardware (tras cambiar GPU, por ejemplo)
hyprarch-control --reprobe
```

### Pestañas disponibles

| Pestaña  | Función                                              |
|----------|------------------------------------------------------|
| Visual   | Colores, bordes, gaps, opacidad — cambios en vivo   |
| Perfiles | SUPER LITE / NORMAL / FULL con un botón             |
| Atajos   | Editor visual de keybinds, sin tocar Lua            |
| Presets  | Cyberpunk, Nord, Gruvbox, Catppuccin, Minimalist    |
| Sistema  | CPU/RAM en tiempo real, comandos hyprctl rápidos    |

---

## ⚡ Perfiles de Rendimiento

### SUPER LITE
- Sin animaciones, sin blur, sin sombras
- VFR activo para bajo consumo GPU
- Ideal para batería, viajes, hardware antiguo

### NORMAL (default)
- Animaciones suaves con bezier `spring`
- Blur moderado (size=6, passes=2)
- Dim en ventanas inactivas

### FULL EXPERIENCE
- Blur intenso (size=12, passes=4)
- Animaciones elaboradas
- Soporte para widgets eww/ags
- Requiere GPU con aceleración hardware

---

## 🔧 Arquitectura Técnica ("El Tridente")

```
┌─────────────────┐    lee/escribe    ┌──────────────────┐
│  Centro de      │ ←─────────────→  │  user_theme.json  │
│  Control        │                  └──────────────────┘
│  (Python/PyQt6) │    genera         ┌──────────────────┐
│                 │ ──────────────→  │  theme.lua  [AUTO]│
└────────┬────────┘                  └────────┬─────────┘
         │ hyprctl keyword/reload             │ require()
         ▼                                   ▼
┌─────────────────────────────────────────────────────────┐
│                    Hyprland (Lua)                        │
│   core.lua → profiles.lua → hardware.lua → theme.lua   │
└─────────────────────────────────────────────────────────┘
```

### Archivos auto-generados explicados

| Archivo              | Quién lo genera            | Cuándo                          |
|----------------------|----------------------------|---------------------------------|
| `hardware.lua`       | `install.sh`               | Durante la instalación          |
| `theme.lua`          | `hyprarch_control.py`      | Al guardar cambios visuales     |
| `active_profile.lua` | `hyprarch_control.py`      | Al cambiar de perfil            |
| `user_binds.lua`     | `hyprarch_control.py`      | Al editar atajos de teclado     |

Estos archivos **no deben subirse al repositorio**. Añádelos a `.gitignore`:

```gitignore
# HyprArch — archivos auto-generados
hyprarch/hypr/hardware.lua
hyprarch/hypr/theme.lua
hyprarch/hypr/active_profile.lua
hyprarch/hypr/user_binds.lua
```

---

## 📦 Dependencias

| Paquete               | Propósito                         |
|-----------------------|-----------------------------------|
| hyprland              | Compositor Wayland                |
| waybar                | Barra de estado                   |
| wofi                  | Lanzador de aplicaciones          |
| dunst                 | Notificaciones                    |
| kitty                 | Terminal GPU-accelerated          |
| hyprpaper             | Fondo de pantalla                 |
| hyprlock              | Pantalla de bloqueo               |
| hypridle              | Suspensión automática             |
| pipewire              | Audio (reemplaza PulseAudio)      |
| python-pyqt6          | GUI del Centro de Control         |
| python-psutil         | Métricas de sistema en tiempo real|
| grim + slurp + swappy | Capturas de pantalla              |
| wl-clipboard + cliphist| Portapapeles Wayland             |

---

## 🌐 Matriz de Compatibilidad

| Hardware     | Soporte                                          |
|--------------|--------------------------------------------------|
| NVIDIA       | nvidia-dkms + modeset + env vars automáticas     |
| AMD          | mesa + vulkan-radeon + libva-mesa-driver          |
| Intel 10-13ª | intel-media-driver (iHD) + VA-API                |
| Intel < 10ª  | libva-intel-driver (i965) legacy                 |
| Laptop       | TLP + power-profiles-daemon + brightnessctl      |
| Desktop      | Sin gestión de batería, VRR habilitado            |
| HiDPI/4K     | Autoescalado via hardware.lua (scale=2.0)         |
| Apps legacy  | XWayland habilitado por defecto                   |
| Dual-boot    | Modo 2 (Arch existente) — sin tocar particiones   |

---

## 📄 Licencia

MIT — libre para usar, modificar y distribuir.
