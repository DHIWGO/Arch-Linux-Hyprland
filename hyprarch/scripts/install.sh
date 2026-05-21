#!/usr/bin/env bash
# =============================================================================
# HyprArch Intelligent Installer v3.0
# Arch Linux + Hyprland — Hybrid Installer (Fresh ISO + Existing Arch)
#
# Repo:  https://github.com/DHIWGO/Arch-Linux-Hyprland
# Uso:   bash install.sh
# =============================================================================
set -euo pipefail

# ─── Colors & UI ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  cat << 'EOF'
 ██╗  ██╗██╗   ██╗██████╗ ██████╗      █████╗ ██████╗  ██████╗██╗  ██╗
 ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗    ██╔══██╗██╔══██╗██╔════╝██║  ██║
 ███████║ ╚████╔╝ ██████╔╝██████╔╝    ███████║██████╔╝██║     ███████║
 ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗    ██╔══██║██╔══██╗██║     ██╔══██║
 ██║  ██║   ██║   ██║     ██║  ██║    ██║  ██║██║  ██║╚██████╗██║  ██║
 ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
EOF
  echo -e "${RESET}${YELLOW}         Intelligent Arch Linux + Hyprland Installer v3.0${RESET}"
  echo -e "${BLUE}         ─────────────────────────────────────────────────${RESET}"
  echo ""
}

log()     { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${RESET}\n"; }
info()    { echo -e "${BLUE}[i]${RESET} $*"; }
ask()     { echo -e "${YELLOW}[?]${RESET} $*"; }

# ─── Global State ─────────────────────────────────────────────────────────────
declare -A HW
REPO_URL="https://github.com/DHIWGO/Arch-Linux-Hyprland.git"
REPO_SUBDIR="hyprarch"          # carpeta de configs dentro del repo
LOG_FILE="/tmp/hyprarch_install.log"

# Modo de instalación (se define en select_install_mode)
INSTALL_MODE=""   # "fresh" | "existing"
FRESH_METHOD=""   # "archinstall" | "custom"

# Rutas que cambian según el modo
CHROOT_CMD=""     # "arch-chroot /mnt" en fresh | "" en existing
TARGET_ROOT=""    # "/mnt" en fresh | "/" en existing
CONFIG_HOME=""    # home del usuario dentro del target

# ─── 0. MODO DE INSTALACIÓN ───────────────────────────────────────────────────
select_install_mode() {
  section "Selección de Modo de Instalación"

  echo -e "${BOLD}¿Cómo deseas instalar HyprArch?${RESET}"
  echo ""
  echo -e "  ${CYAN}[1]${RESET} ${BOLD}Instalación desde cero${RESET} (Arch Linux ISO)"
  echo -e "      Particionará el disco. ${RED}BORRARÁ todos los datos.${RESET}"
  echo -e "      Ideal si no tienes Arch instalado o quieres un sistema limpio."
  echo ""
  echo -e "  ${CYAN}[2]${RESET} ${BOLD}Sobre Arch Linux ya instalado${RESET}"
  echo -e "      Solo instala Hyprland + configuración HyprArch."
  echo -e "      ${GREEN}No toca particiones. Seguro para dual-boot.${RESET}"
  echo ""

  while true; do
    read -rp "$(echo -e "${YELLOW}Elige una opción [1/2]:${RESET} ")" mode_choice
    case "$mode_choice" in
      1)
        INSTALL_MODE="fresh"
        warn "Has elegido instalación desde cero."
        warn "${RED}AVISO: Se borrarán TODOS los datos del disco seleccionado.${RESET}"
        read -rp "¿Confirmas? Escribe 'SI' para continuar: " confirm
        [[ "$confirm" == "SI" ]] || { warn "Operación cancelada."; exit 0; }
        select_fresh_method
        break
        ;;
      2)
        INSTALL_MODE="existing"
        log "Modo: Arch Linux existente — sin tocar particiones"
        CHROOT_CMD=""
        TARGET_ROOT=""
        break
        ;;
      *)
        warn "Opción no válida. Escribe 1 o 2."
        ;;
    esac
  done
}

select_fresh_method() {
  section "Método de Instalación desde Cero"

  echo -e "${BOLD}¿Cómo quieres instalar la base de Arch Linux?${RESET}"
  echo ""
  echo -e "  ${CYAN}[1]${RESET} ${BOLD}archinstall${RESET} (recomendado para principiantes)"
  echo -e "      Asistente oficial interactivo de Arch Linux."
  echo -e "      Configura particiones, locale, usuario, etc. con menús."
  echo -e "      HyprArch se superpone al finalizar."
  echo ""
  echo -e "  ${CYAN}[2]${RESET} ${BOLD}Instalador HyprArch personalizado${RESET} (control total)"
  echo -e "      Particionado automático UEFI + BTRFS + subvolúmenes."
  echo -e "      Detección de hardware y configuración sin asistente."
  echo ""

  while true; do
    read -rp "$(echo -e "${YELLOW}Elige una opción [1/2]:${RESET} ")" method_choice
    case "$method_choice" in
      1) FRESH_METHOD="archinstall"; break ;;
      2) FRESH_METHOD="custom"; break ;;
      *) warn "Opción no válida." ;;
    esac
  done
}

# ─── 1. HARDWARE PROBE ────────────────────────────────────────────────────────
probe_hardware() {
  section "Hardware Probe — Analizando Sistema"

  # ── GPU ────────────────────────────────────────────────────────────────────
  local lspci_out
  lspci_out=$(lspci 2>/dev/null || true)

  if echo "$lspci_out" | grep -qi "nvidia"; then
    HW[GPU]="nvidia"
    HW[GPU_NAME]=$(echo "$lspci_out" | grep -i nvidia | grep -i "vga\|3d\|display" | head -1 | sed 's/.*: //')
    log "GPU: NVIDIA → ${HW[GPU_NAME]}"
    probe_nvidia_generation
  elif echo "$lspci_out" | grep -qi "amd\|radeon\|advanced micro"; then
    HW[GPU]="amd"
    HW[GPU_NAME]=$(echo "$lspci_out" | grep -iE "radeon|amd" | grep -i "vga\|3d\|display" | head -1 | sed 's/.*: //')
    log "GPU: AMD → ${HW[GPU_NAME]}"
  elif echo "$lspci_out" | grep -qi "intel.*graphics\|intel.*uhd\|intel.*iris"; then
    HW[GPU]="intel"
    HW[GPU_NAME]=$(echo "$lspci_out" | grep -i "intel.*graphics\|intel.*uhd\|intel.*iris" | head -1 | sed 's/.*: //')
    log "GPU: Intel → ${HW[GPU_NAME]}"
    probe_intel_generation "$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')"
  else
    HW[GPU]="unknown"
    warn "GPU no reconocida, usando drivers genéricos VESA"
  fi

  # ── CPU ────────────────────────────────────────────────────────────────────
  local cpu_vendor cpu_model
  cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
  cpu_model=$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')

  if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
    HW[CPU]="intel"; HW[UCODE]="intel-ucode"
    [[ "${HW[GPU]}" != "intel" ]] && probe_intel_generation "$cpu_model"
  elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
    HW[CPU]="amd"; HW[UCODE]="amd-ucode"
    log "CPU: AMD → $cpu_model"
  else
    HW[CPU]="unknown"; HW[UCODE]=""
    warn "CPU no reconocida"
  fi

  # ── Chasis ─────────────────────────────────────────────────────────────────
  local chassis_type
  chassis_type=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "1")

  if [[ "$chassis_type" =~ ^(8|9|10|11|14)$ ]]; then
    HW[CHASSIS]="laptop"
    log "Chasis: Laptop (tipo DMI: $chassis_type)"
    probe_laptop_hw
  else
    HW[CHASSIS]="desktop"
    log "Chasis: Desktop (tipo DMI: $chassis_type)"
  fi

  # ── RAM ────────────────────────────────────────────────────────────────────
  HW[RAM_GB]=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
  log "RAM: ${HW[RAM_GB]} GB"

  # ── Disco ──────────────────────────────────────────────────────────────────
  if ls /dev/nvme*n1 &>/dev/null 2>&1; then
    HW[STORAGE]="nvme"
    HW[DISK]=$(ls /dev/nvme*n1 | head -1)
  elif ls /dev/sda &>/dev/null 2>&1; then
    HW[STORAGE]="sata"
    HW[DISK]="/dev/sda"
  else
    HW[DISK]=$(lsblk -ndo NAME,TYPE 2>/dev/null | awk '$2=="disk"{print "/dev/"$1}' | head -1)
    HW[STORAGE]="unknown"
  fi
  log "Disco: ${HW[DISK]:-desconocido} (${HW[STORAGE]})"

  # ── Resolución ─────────────────────────────────────────────────────────────
  HW[RESOLUTION]=$(command -v wlr-randr &>/dev/null && \
    wlr-randr 2>/dev/null | grep -oP '\d+x\d+' | head -1 || echo "1920x1080")
  log "Resolución estimada: ${HW[RESOLUTION]}"

  echo ""
  section "Resumen del Hardware"
  printf "  %-16s %s\n" "GPU:"    "${HW[GPU]} — ${HW[GPU_NAME]:-desconocida}"
  printf "  %-16s %s\n" "CPU:"    "${HW[CPU]} — ${HW[UCODE]}"
  printf "  %-16s %s\n" "Chasis:" "${HW[CHASSIS]}"
  printf "  %-16s %s\n" "RAM:"    "${HW[RAM_GB]} GB"
  printf "  %-16s %s\n" "Disco:"  "${HW[DISK]:-N/A} (${HW[STORAGE]})"
  echo ""
  read -rp "$(echo -e "${YELLOW}¿El hardware se detectó correctamente? [ENTER para continuar / Ctrl+C para cancelar]${RESET} ")"
}

probe_nvidia_generation() {
  HW[NVIDIA_PKG]="nvidia-dkms"
  log "NVIDIA: Driver seleccionado → ${HW[NVIDIA_PKG]}"
}

probe_intel_generation() {
  local model="$1"
  if echo "$model" | grep -qiE "13th|12th|11th|10th|Gen1[0-3]"; then
    HW[INTEL_GEN]="modern"; HW[VA_API_PKG]="intel-media-driver"
    log "Intel moderno → VA-API: intel-media-driver"
  else
    HW[INTEL_GEN]="legacy"; HW[VA_API_PKG]="libva-intel-driver"
    log "Intel legacy → VA-API: libva-intel-driver"
  fi
}

probe_laptop_hw() {
  grep -rl "touchpad\|Touchpad" /sys/class/input/*/device/name 2>/dev/null | grep -q . \
    && { HW[TOUCHPAD]="true"; log "Touchpad detectado → libinput + gestos"; } \
    || HW[TOUCHPAD]="false"

  ls /sys/class/power_supply/BAT* &>/dev/null 2>&1 \
    && { HW[BATTERY]="true"; log "Batería detectada → tlp + power-profiles"; } \
    || HW[BATTERY]="false"

  ls /sys/class/backlight/* &>/dev/null 2>&1 \
    && { HW[BACKLIGHT]="true"; log "Control de brillo detectado"; } \
    || HW[BACKLIGHT]="false"
}

# ═══════════════════════════════════════════════════════════════════════════════
#   MODO A — FRESH INSTALL (desde ISO)
# ═══════════════════════════════════════════════════════════════════════════════

# ─── A1. archinstall + HyprArch overlay ───────────────────────────────────────
run_archinstall_mode() {
  section "Instalación con archinstall"

  if ! command -v archinstall &>/dev/null; then
    error "archinstall no encontrado. Asegúrate de usar la ISO oficial de Arch Linux (2021+)."
  fi

  info "Se abrirá archinstall. Instrucciones importantes:"
  echo ""
  echo -e "  ${CYAN}1.${RESET} En 'Perfil', elige ${BOLD}Minimal${RESET} (sin entorno de escritorio)"
  echo -e "  ${CYAN}2.${RESET} Configura tu usuario, zona horaria, idioma y disco normalmente"
  echo -e "  ${CYAN}3.${RESET} En 'Audio', elige ${BOLD}Pipewire${RESET}"
  echo -e "  ${CYAN}4.${RESET} ${BOLD}NO reinicies${RESET} al terminar — vuelve a esta terminal"
  echo ""
  read -rp "$(echo -e "${YELLOW}Presiona ENTER para abrir archinstall...${RESET}")"

  archinstall || true   # No abortamos si el usuario sale con error

  # ── Detectar instalación de archinstall ────────────────────────────────────
  section "Aplicando HyprArch sobre archinstall"

  local arch_root="/mnt"
  if ! mountpoint -q "$arch_root" 2>/dev/null; then
    # archinstall puede haber desmontado. Intentamos encontrar la partición root
    warn "/mnt no está montado. Intentando detectar la instalación..."
    local possible_root
    possible_root=$(lsblk -nlo NAME,MOUNTPOINT 2>/dev/null | awk '$2=="/"{print "/dev/"$1}' | head -1)

    if [[ -n "$possible_root" ]]; then
      arch_root="/"
      warn "Sistema detectado corriendo en ${possible_root}. Usa modo 'Arch existente' después del reinicio."
      _show_postinstall_instructions
      return
    else
      warn "No se pudo detectar la instalación. Por favor reinicia, entra al nuevo sistema"
      warn "y vuelve a ejecutar este instalador eligiendo la opción [2] Arch existente."
      exit 0
    fi
  fi

  # /mnt está montado — overlay directo
  CHROOT_CMD="arch-chroot /mnt"
  TARGET_ROOT="/mnt"
  local arch_user
  arch_user=$(ls /mnt/home/ 2>/dev/null | head -1)
  CONFIG_HOME="/mnt/home/${arch_user}/.config"

  _install_hyprland_packages
  _install_python_gui_deps
  _install_gpu_drivers_chroot
  _install_laptop_extras_chroot
  _generate_hardware_lua_chroot
  _clone_config_chroot "$arch_user"
  _setup_autostart_chroot "$arch_user"

  section "HyprArch superpuesto correctamente sobre archinstall"
  log "Reinicia con: umount -R /mnt && reboot"
}

# ─── A2. Instalador personalizado HyprArch ────────────────────────────────────
run_custom_fresh_install() {
  CHROOT_CMD="arch-chroot /mnt"
  TARGET_ROOT="/mnt"

  _select_disk
  partition_disk
  install_base
  _install_gpu_drivers_chroot
  _install_laptop_extras_chroot
  _install_hyprland_packages
  _install_python_gui_deps
  _generate_hardware_lua_chroot
  setup_bootloader

  local USERNAME
  USERNAME=$(_create_user)
  CONFIG_HOME="/mnt/home/${USERNAME}/.config"
  _clone_config_chroot "$USERNAME"
  _setup_autostart_chroot "$USERNAME"
}

_select_disk() {
  section "Selección de Disco"
  echo -e "${BOLD}Discos disponibles:${RESET}"
  echo ""
  lsblk -ndo NAME,SIZE,MODEL | while read -r name size model; do
    echo -e "  ${CYAN}/dev/${name}${RESET}  ${size}  ${model}"
  done
  echo ""
  warn "${RED}AVISO: El disco seleccionado se formateará completamente.${RESET}"
  read -rp "$(echo -e "${YELLOW}Introduce el disco (ej: /dev/sda, /dev/nvme0n1):${RESET} ")" disk_input
  [[ -b "$disk_input" ]] || error "Disco no válido: $disk_input"
  HW[DISK]="$disk_input"

  if echo "${HW[DISK]}" | grep -q "nvme"; then
    HW[STORAGE]="nvme"
  else
    HW[STORAGE]="sata"
  fi
  log "Disco seleccionado: ${HW[DISK]}"
}

partition_disk() {
  section "Particionado: ${HW[DISK]}"
  warn "Último aviso — se borrarán TODOS los datos en ${HW[DISK]}"
  read -rp "Escribe 'BORRAR' para confirmar: " final_confirm
  [[ "$final_confirm" == "BORRAR" ]] || { warn "Cancelado."; exit 0; }

  if [[ -d /sys/firmware/efi ]]; then
    info "UEFI detectado → GPT + BTRFS"
    sgdisk --zap-all "${HW[DISK]}" >> "$LOG_FILE" 2>&1
    sgdisk -n 1:0:+1G   -t 1:ef00 -c 1:"EFI"  "${HW[DISK]}" >> "$LOG_FILE" 2>&1
    sgdisk -n 2:0:+8G   -t 2:8200 -c 2:"SWAP" "${HW[DISK]}" >> "$LOG_FILE" 2>&1
    sgdisk -n 3:0:0     -t 3:8300 -c 3:"ROOT" "${HW[DISK]}" >> "$LOG_FILE" 2>&1

    if [[ "${HW[STORAGE]}" == "nvme" ]]; then
      PART_EFI="${HW[DISK]}p1"; PART_SWAP="${HW[DISK]}p2"; PART_ROOT="${HW[DISK]}p3"
    else
      PART_EFI="${HW[DISK]}1";  PART_SWAP="${HW[DISK]}2";  PART_ROOT="${HW[DISK]}3"
    fi

    mkfs.fat -F32 "$PART_EFI"  >> "$LOG_FILE" 2>&1
    mkswap "$PART_SWAP"         >> "$LOG_FILE" 2>&1
    mkfs.btrfs -f "$PART_ROOT"  >> "$LOG_FILE" 2>&1

    mount "$PART_ROOT" /mnt
    btrfs subvolume create /mnt/@          >> "$LOG_FILE" 2>&1
    btrfs subvolume create /mnt/@home      >> "$LOG_FILE" 2>&1
    btrfs subvolume create /mnt/@snapshots >> "$LOG_FILE" 2>&1
    umount /mnt

    mount -o noatime,compress=zstd,subvol=@ "$PART_ROOT" /mnt
    mkdir -p /mnt/{home,.snapshots,boot/efi}
    mount -o noatime,compress=zstd,subvol=@home "$PART_ROOT" /mnt/home
    mount -o noatime,subvol=@snapshots "$PART_ROOT" /mnt/.snapshots
    mount "$PART_EFI" /mnt/boot/efi
    swapon "$PART_SWAP"

    log "Particionado UEFI + BTRFS completado"
  else
    error "Solo UEFI es compatible. Sistema BIOS/MBR no soportado."
  fi
}

install_base() {
  section "Instalando Base de Arch Linux"
  local kernel_pkg="linux-zen linux-zen-headers"
  [[ "${HW[RAM_GB]}" -lt 4 ]] && { warn "RAM < 4GB → usando linux-lts"; kernel_pkg="linux-lts linux-lts-headers"; }

  pacstrap /mnt base base-devel \
    $kernel_pkg linux-firmware \
    ${HW[UCODE]:+${HW[UCODE]}} \
    btrfs-progs grub efibootmgr \
    networkmanager git curl wget \
    nano vim sudo \
    >> "$LOG_FILE" 2>&1

  genfstab -U /mnt >> /mnt/etc/fstab
  log "Base instalada y fstab generado"
}

setup_bootloader() {
  section "Configurando Bootloader GRUB"
  arch-chroot /mnt grub-install --target=x86_64-efi \
    --efi-directory=/boot/efi --bootloader-id=HyprArch >> "$LOG_FILE" 2>&1
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> "$LOG_FILE" 2>&1
  log "GRUB instalado"
}

_create_user() {
  section "Creación de Usuario"
  local username
  while true; do
    read -rp "$(echo -e "${YELLOW}Nombre de usuario (solo minúsculas/números/guión):${RESET} ")" username
    [[ "$username" =~ ^[a-z][a-z0-9_-]{0,30}$ ]] && break
    warn "Nombre inválido. Solo letras minúsculas, números, _ o -"
  done

  arch-chroot /mnt useradd -m -G wheel,audio,video,storage,network -s /bin/bash "$username"
  echo -e "${YELLOW}Contraseña para $username:${RESET}"
  arch-chroot /mnt passwd "$username"

  # Sudo sin contraseña para wheel
  arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
  log "Usuario '$username' creado"
  echo "$username"
}

# ═══════════════════════════════════════════════════════════════════════════════
#   MODO B — EXISTING ARCH (sobre Arch ya instalado)
# ═══════════════════════════════════════════════════════════════════════════════

run_existing_arch_mode() {
  section "Instalación sobre Arch Linux existente"

  # Verificar que es Arch Linux
  if ! command -v pacman &>/dev/null; then
    error "pacman no encontrado. Este modo requiere Arch Linux (o derivado) instalado."
  fi

  # Verificar privilegios
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
      info "Se usará sudo para operaciones de sistema"
      SUDO_CMD="sudo"
    else
      error "Ejecuta el script como root o instala sudo primero."
    fi
  else
    SUDO_CMD=""
  fi

  # Verificar que NO hay otro compositor Wayland activo
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ -n "${DISPLAY:-}" ]]; then
    warn "Hay una sesión gráfica activa. Algunos cambios pueden requerir reiniciar la sesión."
  fi

  log "Sistema Arch Linux detectado — procediendo sin tocar particiones"
  CONFIG_HOME="$HOME/.config"

  _install_hyprland_existing
  _install_python_gui_deps_existing
  _install_gpu_drivers_existing
  _install_laptop_extras_existing
  _generate_hardware_lua_existing
  _clone_config_existing
  _setup_control_center_existing
}

_install_hyprland_existing() {
  section "Instalando Hyprland & Wayland Stack"
  ${SUDO_CMD} pacman -S --needed --noconfirm \
    hyprland hyprpaper hyprlock hypridle \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    waybar wofi dunst \
    kitty \
    wl-clipboard cliphist \
    grim slurp swappy \
    pipewire pipewire-pulse pipewire-alsa wireplumber \
    bluez bluez-utils \
    thunar thunar-archive-plugin \
    polkit-gnome gnome-keyring \
    qt5-wayland qt6-wayland \
    xorg-xwayland \
    nwg-look \
    >> "$LOG_FILE" 2>&1

  ${SUDO_CMD} systemctl enable bluetooth.service NetworkManager.service >> "$LOG_FILE" 2>&1 || true
  log "Hyprland + stack Wayland instalados"
}

_install_python_gui_deps_existing() {
  section "Instalando Dependencias del Centro de Control"
  ${SUDO_CMD} pacman -S --needed --noconfirm \
    python python-pip \
    python-pyqt6 \
    python-requests python-psutil \
    >> "$LOG_FILE" 2>&1

  # yay para AUR (si no está instalado)
  if ! command -v yay &>/dev/null; then
    info "Instalando yay (AUR helper)..."
    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay" >> "$LOG_FILE" 2>&1
    (cd "$tmpdir/yay" && makepkg -si --noconfirm 2>/dev/null || true)
    rm -rf "$tmpdir"
  fi
  log "Python + PyQt6 + yay listos"
}

_install_gpu_drivers_existing() {
  section "Instalando Drivers GPU: ${HW[GPU]}"
  case "${HW[GPU]}" in
    nvidia)
      ${SUDO_CMD} pacman -S --needed --noconfirm \
        "${HW[NVIDIA_PKG]}" nvidia-utils nvidia-settings libva-nvidia-driver \
        >> "$LOG_FILE" 2>&1

      # Variables de entorno NVIDIA Wayland
      local env_file="/etc/environment"
      if ! grep -q "LIBVA_DRIVER_NAME=nvidia" "$env_file" 2>/dev/null; then
        cat << 'ENVEOF' | ${SUDO_CMD} tee -a "$env_file" > /dev/null
# NVIDIA Wayland (añadido por HyprArch)
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
WLR_NO_HARDWARE_CURSORS=1
ENVEOF
      fi

      # Módulos en mkinitcpio
      if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
        ${SUDO_CMD} sed -i \
          's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' \
          /etc/mkinitcpio.conf
        ${SUDO_CMD} mkinitcpio -P >> "$LOG_FILE" 2>&1
      fi
      log "NVIDIA: drivers + env vars configurados"
      ;;
    amd)
      ${SUDO_CMD} pacman -S --needed --noconfirm \
        mesa vulkan-radeon libva-mesa-driver mesa-vdpau xf86-video-amdgpu \
        >> "$LOG_FILE" 2>&1
      log "AMD: Mesa + Vulkan + VA-API configurados"
      ;;
    intel)
      ${SUDO_CMD} pacman -S --needed --noconfirm \
        mesa vulkan-intel "${HW[VA_API_PKG]:-intel-media-driver}" libva-utils \
        >> "$LOG_FILE" 2>&1
      log "Intel: Mesa + Vulkan + VA-API configurados"
      ;;
    *)
      warn "GPU desconocida — omitiendo drivers específicos"
      ;;
  esac
}

_install_laptop_extras_existing() {
  [[ "${HW[CHASSIS]}" != "laptop" ]] && return
  section "Optimizaciones Laptop"

  ${SUDO_CMD} pacman -S --needed --noconfirm \
    power-profiles-daemon tlp tlp-rdw light brightnessctl libinput \
    >> "$LOG_FILE" 2>&1

  ${SUDO_CMD} systemctl enable tlp.service power-profiles-daemon.service >> "$LOG_FILE" 2>&1 || true

  # Libinput touchpad
  local xorg_conf="/etc/X11/xorg.conf.d/40-libinput.conf"
  if [[ ! -f "$xorg_conf" ]]; then
    ${SUDO_CMD} mkdir -p /etc/X11/xorg.conf.d/
    cat << 'INPUTEOF' | ${SUDO_CMD} tee "$xorg_conf" > /dev/null
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
    Option "ClickMethod" "clickfinger"
EndSection
INPUTEOF
  fi
  log "Laptop: power-profiles + brillo + touchpad configurados"
}

_generate_hardware_lua_existing() {
  section "Generando hardware.lua"
  local hypr_dir="$HOME/.config/hypr"
  mkdir -p "$hypr_dir"

  cat > "$hypr_dir/hardware.lua" << LUAEOF
-- ============================================================
-- hardware.lua — Generado por HyprArch Installer v3.0
-- NO editar manualmente. Regenerar con: hyprarch-control --reprobe
-- ============================================================

local hw = {
  gpu          = "${HW[GPU]}",
  gpu_name     = "${HW[GPU_NAME]:-unknown}",
  chassis      = "${HW[CHASSIS]}",
  cpu          = "${HW[CPU]}",
  ram_gb       = ${HW[RAM_GB]},
  resolution   = "${HW[RESOLUTION]}",
  has_battery  = ${HW[BATTERY]:-false},
  has_touchpad = ${HW[TOUCHPAD]:-false},
}

-- ── Cursor fix para NVIDIA ─────────────────────────────────
if hw.gpu == "nvidia" then
  env = {
    { "WLR_NO_HARDWARE_CURSORS", "1" },
    { "LIBVA_DRIVER_NAME",       "nvidia" },
    { "GBM_BACKEND",             "nvidia-drm" },
    { "__GLX_VENDOR_LIBRARY_NAME", "nvidia" },
  }
end

-- ── Monitor auto-scaling ──────────────────────────────────
local res_w = tonumber(hw.resolution:match("(%d+)x%d+")) or 1920
local scale  = 1.0
if     res_w >= 3840 then scale = 2.0
elseif res_w >= 2560 then scale = 1.5
elseif res_w >= 1920 then scale = 1.25
end
monitor = string.format(",preferred,auto,%.2f", scale)

-- ── Input (touchpad) ─────────────────────────────────────
input = {
  kb_layout    = "us",
  follow_mouse = 1,
  sensitivity  = 0,
  touchpad = {
    natural_scroll = hw.has_touchpad,
    tap_to_click   = hw.has_touchpad,
    drag_lock      = true,
  }
}

return hw
LUAEOF
  log "hardware.lua generado en $hypr_dir/"
}

_clone_config_existing() {
  section "Instalando Configuración HyprArch"
  local hypr_dir="$HOME/.config/hypr"
  local presets_dir="$HOME/.config/hypr/presets"
  mkdir -p "$hypr_dir" "$presets_dir"

  # Origen local (si ejecutamos desde el repo clonado)
  local script_dir
  script_dir="$(dirname "$(realpath "$0")")"
  local local_src="$(realpath "$script_dir/../../")"    # raíz del repo: Arch-Linux-Hyprland/

  if [[ -d "$local_src/hyprarch/hypr" ]]; then
    info "Copiando config desde repositorio local..."
    cp -rn "$local_src/hyprarch/hypr/"*.lua  "$hypr_dir/" 2>/dev/null || true
    [[ -f "$local_src/hyprarch/hypr/user_theme.json" ]] && \
      cp -n "$local_src/hyprarch/hypr/user_theme.json" "$hypr_dir/"
    cp -rn "$local_src/hyprarch/presets/"* "$presets_dir/" 2>/dev/null || true
    log "Config local copiada"
  else
    info "Clonando repositorio HyprArch..."
    local tmpdir
    tmpdir=$(mktemp -d)
    git clone --depth 1 "$REPO_URL" "$tmpdir/repo" >> "$LOG_FILE" 2>&1
    cp -rn "$tmpdir/repo/hyprarch/hypr/"*.lua  "$hypr_dir/" 2>/dev/null || true
    [[ -f "$tmpdir/repo/hyprarch/hypr/user_theme.json" ]] && \
      cp -n "$tmpdir/repo/hyprarch/hypr/user_theme.json" "$hypr_dir/"
    cp -rn "$tmpdir/repo/hyprarch/presets/"* "$presets_dir/" 2>/dev/null || true
    rm -rf "$tmpdir"
    log "Config descargada desde GitHub"
  fi

  # Perfil activo por defecto (si no existe)
  if [[ ! -f "$hypr_dir/active_profile.lua" ]]; then
    echo 'return { name = "normal" }' > "$hypr_dir/active_profile.lua"
  fi
}

_setup_control_center_existing() {
  section "Instalando Centro de Control"
  local script_dir
  script_dir="$(dirname "$(realpath "$0")")"
  local local_src="$(realpath "$script_dir/../../")"
  local cc_src="$local_src/hyprarch/control_center/hyprarch_control.py"

  if [[ -f "$cc_src" ]]; then
    ${SUDO_CMD} install -Dm755 "$cc_src" /usr/local/bin/hyprarch-control
  else
    # Descargar desde GitHub
    ${SUDO_CMD} curl -fsSL \
      "https://raw.githubusercontent.com/DHIWGO/Arch-Linux-Hyprland/main/hyprarch/control_center/hyprarch_control.py" \
      -o /usr/local/bin/hyprarch-control >> "$LOG_FILE" 2>&1
    ${SUDO_CMD} chmod +x /usr/local/bin/hyprarch-control
  fi

  # Entrada .desktop
  cat << 'DESKTOPEOF' | ${SUDO_CMD} tee /usr/share/applications/hyprarch-control.desktop > /dev/null
[Desktop Entry]
Name=HyprArch Control Center
Comment=Gestiona Hyprland sin tocar archivos de configuración
Exec=hyprarch-control
Icon=preferences-desktop
Terminal=false
Type=Application
Categories=Settings;
Keywords=hyprland;config;theme;
DESKTOPEOF

  log "Centro de Control instalado → lanza con: hyprarch-control"
}

_setup_autostart_chroot() {
  local username="$1"
  section "Configurando Autostart de Hyprland"

  # Hyprland desde TTY1
  local profile_path="${TARGET_ROOT}/home/${username}/.bash_profile"
  if ! grep -q "Hyprland" "$profile_path" 2>/dev/null; then
    cat >> "$profile_path" << 'PROFEOF'

# HyprArch — Auto-start Hyprland en TTY1
if [[ -z "$DISPLAY" ]] && [[ -z "$WAYLAND_DISPLAY" ]] && [[ "$XDG_VTNR" -eq 1 ]]; then
  exec Hyprland
fi
PROFEOF
  fi

  log "Autostart configurado para '$username'"
}

# ═══════════════════════════════════════════════════════════════════════════════
#   HELPERS COMPARTIDOS (fresh — dentro de arch-chroot)
# ═══════════════════════════════════════════════════════════════════════════════

_install_hyprland_packages() {
  section "Instalando Hyprland & Wayland Stack (chroot)"
  arch-chroot /mnt pacman -S --needed --noconfirm \
    hyprland hyprpaper hyprlock hypridle \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    waybar wofi dunst \
    kitty \
    wl-clipboard cliphist \
    grim slurp swappy \
    pipewire pipewire-pulse pipewire-alsa wireplumber \
    bluez bluez-utils \
    thunar thunar-archive-plugin \
    polkit-gnome gnome-keyring \
    qt5-wayland qt6-wayland \
    xorg-xwayland \
    nwg-look \
    >> "$LOG_FILE" 2>&1

  arch-chroot /mnt systemctl enable bluetooth.service NetworkManager.service >> "$LOG_FILE" 2>&1
  log "Hyprland + stack Wayland instalados"
}

_install_python_gui_deps() {
  section "Instalando Dependencias del Centro de Control (chroot)"
  arch-chroot /mnt pacman -S --needed --noconfirm \
    python python-pip python-pyqt6 python-requests python-psutil \
    >> "$LOG_FILE" 2>&1

  arch-chroot /mnt bash -c "
    cd /tmp && git clone https://aur.archlinux.org/yay.git 2>/dev/null || true
    cd /tmp/yay && makepkg -si --noconfirm 2>/dev/null || true
  " >> "$LOG_FILE" 2>&1
  log "Python + PyQt6 + yay listos"
}

_install_gpu_drivers_chroot() {
  section "Instalando Drivers GPU en chroot: ${HW[GPU]}"
  case "${HW[GPU]}" in
    nvidia)
      arch-chroot /mnt pacman -S --noconfirm \
        "${HW[NVIDIA_PKG]}" nvidia-utils nvidia-settings libva-nvidia-driver \
        >> "$LOG_FILE" 2>&1
      arch-chroot /mnt sed -i \
        's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1/' \
        /etc/default/grub
      cat >> /mnt/etc/environment << 'ENVEOF'
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
WLR_NO_HARDWARE_CURSORS=1
ENVEOF
      arch-chroot /mnt sed -i \
        's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' \
        /etc/mkinitcpio.conf
      arch-chroot /mnt mkinitcpio -P >> "$LOG_FILE" 2>&1
      log "NVIDIA configurado"
      ;;
    amd)
      arch-chroot /mnt pacman -S --noconfirm \
        mesa vulkan-radeon libva-mesa-driver mesa-vdpau xf86-video-amdgpu \
        >> "$LOG_FILE" 2>&1
      log "AMD configurado"
      ;;
    intel)
      arch-chroot /mnt pacman -S --noconfirm \
        mesa vulkan-intel "${HW[VA_API_PKG]:-intel-media-driver}" libva-utils \
        >> "$LOG_FILE" 2>&1
      log "Intel configurado"
      ;;
  esac
}

_install_laptop_extras_chroot() {
  [[ "${HW[CHASSIS]}" != "laptop" ]] && return
  section "Optimizaciones Laptop (chroot)"
  arch-chroot /mnt pacman -S --noconfirm \
    power-profiles-daemon tlp tlp-rdw light brightnessctl libinput \
    >> "$LOG_FILE" 2>&1
  arch-chroot /mnt systemctl enable tlp.service power-profiles-daemon.service >> "$LOG_FILE" 2>&1
  mkdir -p /mnt/etc/X11/xorg.conf.d/
  cat > /mnt/etc/X11/xorg.conf.d/40-libinput.conf << 'INPUTEOF'
Section "InputClass"
    Identifier "touchpad"
    Driver "libinput"
    MatchIsTouchpad "on"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
    Option "ClickMethod" "clickfinger"
EndSection
INPUTEOF
  log "Laptop configurado"
}

_generate_hardware_lua_chroot() {
  section "Generando hardware.lua (chroot)"
  mkdir -p "/mnt/etc/hyprarch"

  cat > "/mnt/etc/hyprarch/hardware.lua" << LUAEOF
-- hardware.lua — Generado por HyprArch Installer v3.0
-- NO editar manualmente. Regenerar con: hyprarch-control --reprobe
local hw = {
  gpu          = "${HW[GPU]}",
  gpu_name     = "${HW[GPU_NAME]:-unknown}",
  chassis      = "${HW[CHASSIS]}",
  cpu          = "${HW[CPU]}",
  ram_gb       = ${HW[RAM_GB]},
  resolution   = "${HW[RESOLUTION]}",
  has_battery  = ${HW[BATTERY]:-false},
  has_touchpad = ${HW[TOUCHPAD]:-false},
}
if hw.gpu == "nvidia" then
  env = {
    { "WLR_NO_HARDWARE_CURSORS",    "1" },
    { "LIBVA_DRIVER_NAME",          "nvidia" },
    { "GBM_BACKEND",                "nvidia-drm" },
    { "__GLX_VENDOR_LIBRARY_NAME",  "nvidia" },
  }
end
local res_w = tonumber(hw.resolution:match("(%d+)x%d+")) or 1920
local scale  = 1.0
if     res_w >= 3840 then scale = 2.0
elseif res_w >= 2560 then scale = 1.5
elseif res_w >= 1920 then scale = 1.25
end
monitor = string.format(",preferred,auto,%.2f", scale)
input = {
  kb_layout    = "us",
  follow_mouse = 1,
  sensitivity  = 0,
  touchpad = { natural_scroll = hw.has_touchpad, tap_to_click = hw.has_touchpad, drag_lock = true }
}
return hw
LUAEOF
  log "hardware.lua generado"
}

_clone_config_chroot() {
  local username="$1"
  section "Instalando Configuración HyprArch (chroot)"

  local script_dir
  script_dir="$(dirname "$(realpath "$0")")"
  local local_src="$(realpath "$script_dir/../../")"

  mkdir -p "/mnt/home/${username}/.config/hypr/presets"

  if [[ -d "$local_src/hyprarch/hypr" ]]; then
    cp -rn "$local_src/hyprarch/hypr/"*.lua "/mnt/home/${username}/.config/hypr/" 2>/dev/null || true
    cp -n  "$local_src/hyprarch/hypr/user_theme.json" "/mnt/home/${username}/.config/hypr/" 2>/dev/null || true
    cp -rn "$local_src/hyprarch/presets/"* "/mnt/home/${username}/.config/hypr/presets/" 2>/dev/null || true
  else
    warn "Config local no encontrada — clonando desde GitHub..."
    git clone --depth 1 "$REPO_URL" /tmp/hyprarch-repo >> "$LOG_FILE" 2>&1
    cp -rn /tmp/hyprarch-repo/hyprarch/hypr/*.lua "/mnt/home/${username}/.config/hypr/" 2>/dev/null || true
    cp -n  /tmp/hyprarch-repo/hyprarch/hypr/user_theme.json "/mnt/home/${username}/.config/hypr/" 2>/dev/null || true
    cp -rn /tmp/hyprarch-repo/hyprarch/presets/* "/mnt/home/${username}/.config/hypr/presets/" 2>/dev/null || true
  fi

  # Copiar hardware.lua del sistema al usuario
  cp /mnt/etc/hyprarch/hardware.lua "/mnt/home/${username}/.config/hypr/" 2>/dev/null || true

  # Perfil activo por defecto
  echo 'return { name = "normal" }' > "/mnt/home/${username}/.config/hypr/active_profile.lua"

  # Instalar Centro de Control
  local cc_src="$local_src/hyprarch/control_center/hyprarch_control.py"
  if [[ -f "$cc_src" ]]; then
    install -Dm755 "$cc_src" /mnt/usr/local/bin/hyprarch-control
  fi

  # Permisos
  arch-chroot /mnt chown -R "${username}:${username}" "/home/${username}/.config/" 2>/dev/null || true

  log "Configuración instalada para '$username'"
}

# ─── INSTRUCCIONES POST-INSTALACIÓN ──────────────────────────────────────────
_show_postinstall_instructions() {
  section "Instrucciones Post-Instalación"
  echo -e "${GREEN}${BOLD}¡HyprArch instalado correctamente!${RESET}"
  echo ""
  if [[ "$INSTALL_MODE" == "fresh" ]]; then
    echo -e "  ${CYAN}1.${RESET} Reinicia el sistema:  ${BOLD}umount -R /mnt && reboot${RESET}"
    echo -e "  ${CYAN}2.${RESET} Inicia sesión en TTY — Hyprland arrancará automáticamente"
    echo -e "  ${CYAN}3.${RESET} Abre el Centro de Control:  ${BOLD}hyprarch-control${RESET}"
  else
    echo -e "  ${CYAN}1.${RESET} Cierra sesión y vuelve a entrar (o reinicia)"
    echo -e "  ${CYAN}2.${RESET} En el login manager, selecciona ${BOLD}Hyprland${RESET}"
    echo -e "  ${CYAN}3.${RESET} O desde TTY: ${BOLD}Hyprland${RESET}"
    echo -e "  ${CYAN}4.${RESET} Centro de Control:  ${BOLD}hyprarch-control${RESET}"
  fi
  echo ""
  echo -e "  ${CYAN}Cambiar perfil desde terminal:${RESET}"
  echo -e "    hyprarch-control --profile lite"
  echo -e "    hyprarch-control --profile normal"
  echo -e "    hyprarch-control --profile full"
  echo ""
  echo -e "  ${CYAN}Log de instalación:${RESET} $LOG_FILE"
  echo ""
}

# ─── MAIN ─────────────────────────────────────────────────────────────────────
main() {
  banner
  : > "$LOG_FILE"

  echo -e "  ${BOLD}HyprArch — Instalador Híbrido v3.0${RESET}"
  echo -e "  Repositorio: ${CYAN}${REPO_URL}${RESET}"
  echo -e "  Log: ${CYAN}${LOG_FILE}${RESET}"
  echo ""

  select_install_mode   # ← Primera pregunta: fresh vs existing

  probe_hardware        # Siempre detecta el hardware

  case "$INSTALL_MODE" in
    fresh)
      case "$FRESH_METHOD" in
        archinstall) run_archinstall_mode ;;
        custom)      run_custom_fresh_install ;;
      esac
      ;;
    existing)
      run_existing_arch_mode
      ;;
  esac

  _show_postinstall_instructions
}

main "$@"
