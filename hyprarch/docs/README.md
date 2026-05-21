# HyprArch — Arch Linux + Hyprland Intelligent Environment

Un entorno de escritorio moderno, modular y completamente gestionable sin
tocar archivos de configuración. Basado en **Arch Linux + Hyprland v0.55+**.

---

## 📁 Estructura del Proyecto

```
hyprarch/
├── scripts/
│   └── install.sh              ← Instalador inteligente con hardware probe
├── hypr/
│   ├── core.lua                ← Motor de configuración permanente
│   ├── profiles.lua            ← 3 perfiles: lite / normal / full
│   ├── hardware.lua            ← Generado automáticamente por el instalador
│   ├── theme.lua               ← Generado por el Centro de Control
│   ├── user_theme.json         ← Config del usuario (lee/escribe el GUI)
│   └── user_binds.lua          ← Atajos personalizados (generado por GUI)
├── control_center/
│   └── hyprarch_control.py     ← Centro de Control (PyQt6)
└── presets/
    └── cyberpunk.json          ← Preset de comunidad
```

---

## 🚀 Instalación

### Requisitos previos
- USB con Arch Linux ISO (archlinux-2025.xx.xx-x86_64.iso)
- Sistema UEFI (no MBR)
- Conexión a internet

### Pasos

```bash
# 1. Arranca desde el USB de Arch Linux
# 2. Conecta a internet
iwctl station wlan0 connect "TuRed"

# 3. Descarga y ejecuta el instalador
curl -fsSL https://raw.githubusercontent.com/TU_USER/hyprarch/main/scripts/install.sh | bash
```

El instalador:
1. **Analiza el hardware** (GPU, CPU, chasis, RAM, disco)
2. **Particiona** con GPT + BTRFS (subvolumes @ y @home)
3. **Instala** la base + kernel linux-zen (o linux-lts si RAM < 4GB)
4. **Configura drivers** según GPU detectada (NVIDIA/AMD/Intel)
5. **Optimiza** si es laptop (TLP, brillo, touchpad)
6. **Instala** Hyprland + todo el stack Wayland
7. **Genera** `hardware.lua` específico para tu máquina
8. **Crea** el usuario y configura el autostart

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
```

### Pestañas disponibles
| Pestaña    | Función                                              |
|------------|------------------------------------------------------|
| Visual     | Colores, bordes, gaps, opacidad — cambios en vivo   |
| Perfiles   | SUPER LITE / NORMAL / FULL con un botón             |
| Atajos     | Editor visual de keybinds, sin tocar Lua            |
| Presets    | Cyberpunk, Nord, Gruvbox, Catppuccin, Minimalist    |
| Sistema    | CPU/RAM en tiempo real, comandos hyprctl rápidos    |

---

## ⚡ Perfiles de Rendimiento

### SUPER LITE
- Sin animaciones, sin blur, sin sombras
- VFR activo para bajo consumo GPU
- Ideal para: batería, viajes, hardware antiguo

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
│                 │ ──────────────→  │  theme.lua        │
└────────┬────────┘                  └────────┬─────────┘
         │ hyprctl keyword/reload             │ require()
         ▼                                   ▼
┌─────────────────────────────────────────────────────────┐
│                    Hyprland (Lua)                        │
│   core.lua → profiles.lua → hardware.lua → theme.lua   │
└─────────────────────────────────────────────────────────┘
```

---

## 📦 Dependencias

| Paquete               | Propósito                        |
|-----------------------|----------------------------------|
| hyprland              | Compositor Wayland               |
| waybar                | Barra de estado                  |
| wofi                  | Lanzador de aplicaciones         |
| dunst                 | Notificaciones                   |
| kitty                 | Terminal GPU-accelerated         |
| hyprpaper             | Fondo de pantalla                |
| hyprlock              | Pantalla de bloqueo              |
| hypridle              | Suspensión automática            |
| pipewire              | Audio (reemplaza PulseAudio)     |
| python-pyqt6          | GUI del Centro de Control        |
| python-psutil         | Métricas de sistema en tiempo real|

---

## 🌐 Matriz de Compatibilidad

| Hardware     | Soporte                                         |
|--------------|-------------------------------------------------|
| NVIDIA       | nvidia-dkms + modeset + env vars automáticas    |
| AMD          | mesa + vulkan-radeon + libva-mesa-driver         |
| Intel 10-13ª | intel-media-driver (iHD) + VA-API               |
| Intel < 10ª  | libva-intel-driver (i965) legacy                |
| Laptop       | TLP + power-profiles-daemon + brightnessctl     |
| Desktop      | Sin gestión de batería, VRR habilitado           |
| HiDPI/4K     | Autoescalado via hardware.lua (scale=2.0)        |
| Apps legacy  | XWayland habilitado por defecto                  |

---

## 📄 Licencia

MIT — libre para usar, modificar y distribuir.
