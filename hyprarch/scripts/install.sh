#!/usr/bin/env bash
# =============================================================================
# HyprArch Intelligent Installer v2.0
# Arch Linux + Hyprland — Universal Installer with Hardware Probing
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
 ██║  ██║   ██║   ██║      ██║  ██║    ██║  ██║██║  ██║╚██████╗██║  ██║
 ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
EOF
  echo -e "${RESET}${YELLOW}         Intelligent Arch Linux + Hyprland Installer${RESET}"
  echo -e "${BLUE}         ─────────────────────────────────────────────${RESET}"
  echo ""
}

log()     { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}── $* ──${RESET}\n"; }
info()    { echo -e "${BLUE}[i]${RESET} $*"; }

# ─── Global State ─────────────────────────────────────────────────────────────
declare -A HW  # Hardware map: GPU, CHASSIS, CPU, etc.
REPO_URL="https://github.com/YOUR_USER/hyprarch-config"
CONFIG_DIR="$HOME/.config/hypr"
HYPRARCH_DIR="$HOME/.config/hyprarch"
LOG_FILE="/tmp/hyprarch_install.log"

# ─── 1. HARDWARE PROBE ────────────────────────────────────────────────────────
probe_hardware() {
  section "Hardware Probe — Analyzing System"

  # ── GPU Detection ──────────────────────────────────────────────────────────
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
  else
    HW[GPU]="unknown"
    warn "GPU: No reconocida, usando drivers genéricos VESA"
  fi

  # ── CPU Detection ──────────────────────────────────────────────────────────
  local cpu_vendor
  cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')
  local cpu_model
  cpu_model=$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')

  if [[ "$cpu_vendor" == "GenuineIntel" ]]; then
    HW[CPU]="intel"
    HW[UCODE]="intel-ucode"
    probe_intel_generation "$cpu_model"
  elif [[ "$cpu_vendor" == "AuthenticAMD" ]]; then
    HW[CPU]="amd"
    HW[UCODE]="amd-ucode"
    log "CPU: AMD → $cpu_model"
  fi

  # ── Chassis Detection ──────────────────────────────────────────────────────
  local chassis_type
  chassis_type=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "1")

  # DMI chassis types: 8,9,10,11,14 = laptop variants
  if [[ "$chassis_type" =~ ^(8|9|10|11|14)$ ]]; then
    HW[CHASSIS]="laptop"
    log "Chasis: Laptop detectado (tipo DMI: $chassis_type)"
    probe_laptop_hw
  else
    HW[CHASSIS]="desktop"
    log "Chasis: Desktop detectado (tipo DMI: $chassis_type)"
  fi

  # ── RAM Detection ──────────────────────────────────────────────────────────
  HW[RAM_GB]=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
  log "RAM: ${HW[RAM_GB]} GB detectados"

  # ── Storage Detection ──────────────────────────────────────────────────────
  if ls /dev/nvme* &>/dev/null; then
    HW[STORAGE]="nvme"
    HW[DISK]=$(ls /dev/nvme*n1 | head -1)
  elif ls /dev/sda &>/dev/null; then
    HW[STORAGE]="sata"
    HW[DISK]="/dev/sda"
  else
    HW[DISK]=$(lsblk -ndo NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}' | head -1)
    HW[STORAGE]="unknown"
  fi
  log "Disco: ${HW[DISK]} (${HW[STORAGE]})"

  # ── Display Server Resolution ──────────────────────────────────────────────
  if command -v wlr-randr &>/dev/null; then
    HW[RESOLUTION]=$(wlr-randr 2>/dev/null | grep -oP '\d+x\d+' | head -1 || echo "1920x1080")
  else
    HW[RESOLUTION]="1920x1080"
  fi
  log "Resolución estimada: ${HW[RESOLUTION]}"

  echo ""
  section "Resumen del Hardware"
  printf "  %-15s %s\n" "GPU:"     "${HW[GPU]} — ${HW[GPU_NAME]:-desconocida}"
  printf "  %-15s %s\n" "CPU:"     "${HW[CPU]} — ${HW[UCODE]}"
  printf "  %-15s %s\n" "Chasis:"  "${HW[CHASSIS]}"
  printf "  %-15s %s\n" "RAM:"     "${HW[RAM_GB]} GB"
  printf "  %-15s %s\n" "Disco:"   "${HW[DISK]} (${HW[STORAGE]})"
  echo ""
}

probe_nvidia_generation() {
  local gpu_id
  gpu_id=$(lspci -n | grep -i "10de" | head -1 | awk '{print $3}' | cut -d: -f2)
  # Very rough heuristic — Turing (TU1xx) and newer → nvidia-dkms
  # Kepler (GK1xx) or older → nvidia-470xx-dkms or nouveau
  HW[NVIDIA_PKG]="nvidia-dkms"
  log "NVIDIA: Driver seleccionado → ${HW[NVIDIA_PKG]}"
}

probe_intel_generation() {
  local model="$1"
  if echo "$model" | grep -qiE "13th|12th|11th|10th"; then
    HW[INTEL_GEN]="modern"
    HW[VA_API_PKG]="intel-media-driver"  # iHD for Gen8+
    log "CPU: Intel → $model (VA-API: intel-media-driver)"
  else
    HW[INTEL_GEN]="legacy"
    HW[VA_API_PKG]="libva-intel-driver"  # i965 legacy
    log "CPU: Intel → $model (VA-API: libva-intel-driver)"
  fi
}

probe_laptop_hw() {
  # Touchpad
  if ls /dev/input/event* &>/dev/null; then
    if grep -rl "touchpad\|Touchpad" /sys/class/input/*/device/name 2>/dev/null | grep -q .; then
      HW[TOUCHPAD]="yes"
      log "Touchpad: Detectado → instalaremos libinput + gestos"
    fi
  fi

  # Battery
  if ls /sys/class/power_supply/BAT* &>/dev/null; then
    HW[BATTERY]="yes"
    log "Batería: Detectada → power-profiles-daemon + tlp"
  fi

  # Backlight
  if ls /sys/class/backlight/* &>/dev/null; then
    HW[BACKLIGHT]="yes"
    log "Brillo: Controlador de pantalla detectado → light"
  fi
}

# ─── 2. DISK PARTITIONING ─────────────────────────────────────────────────────
partition_disk() {
  section "Particionado de Disco: ${HW[DISK]}"
  warn "AVISO: Se borrarán TODOS los datos en ${HW[DISK]}"
  warn "Presiona ENTER para continuar o Ctrl+C para cancelar"
  read -r

  # Use sgdisk for GPT (UEFI)
  if [[ -d /sys/firmware/efi ]]; then
    info "Sistema UEFI detectado → GPT"
    sgdisk --zap-all "${HW[DISK]}" >> "$LOG_FILE" 2>&1
    sgdisk -n 1:0:+1G   -t 1:ef00 -c 1:"EFI"  "${HW[DISK]}" >> "$LOG_FILE" 2>&1
    sgdisk -n 2:0:+8G   -t 2:8200 -c 2:"SWAP" "${HW[DISK]}" >> "$LOG_FILE" 2>&1
    sgdisk -n 3:0:0     -t 3:8300 -c 3:"ROOT" "${HW[DISK]}" >> "$LOG_FILE" 2>&1

    # Partition naming varies between NVMe and SATA
    if [[ "${HW[STORAGE]}" == "nvme" ]]; then
      PART_EFI="${HW[DISK]}p1"
      PART_SWAP="${HW[DISK]}p2"
      PART_ROOT="${HW[DISK]}p3"
    else
      PART_EFI="${HW[DISK]}1"
      PART_SWAP="${HW[DISK]}2"
      PART_ROOT="${HW[DISK]}3"
    fi

    mkfs.fat -F32 "$PART_EFI"  >> "$LOG_FILE" 2>&1
    mkswap "$PART_SWAP"         >> "$LOG_FILE" 2>&1
    mkfs.btrfs -f "$PART_ROOT"  >> "$LOG_FILE" 2>&1

    # BTRFS subvolumes for snapshots
    mount "$PART_ROOT" /mnt
    btrfs subvolume create /mnt/@       >> "$LOG_FILE" 2>&1
    btrfs subvolume create /mnt/@home   >> "$LOG_FILE" 2>&1
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
    error "Solo se soporta UEFI. Sistema BIOS/MBR no compatible."
  fi
}

# ─── 3. BASE INSTALLATION ─────────────────────────────────────────────────────
install_base() {
  section "Instalando Base de Arch Linux"

  local kernel_pkg="linux-zen linux-zen-headers"
  if [[ "${HW[RAM_GB]}" -lt 4 ]]; then
    warn "RAM < 4GB → Usando linux-lts para mayor estabilidad"
    kernel_pkg="linux-lts linux-lts-headers"
  fi

  pacstrap /mnt base base-devel \
    $kernel_pkg linux-firmware \
    "${HW[UCODE]}" \
    btrfs-progs grub efibootmgr \
    networkmanager git curl wget \
    nano vim sudo \
    >> "$LOG_FILE" 2>&1

  genfstab -U /mnt >> /mnt/etc/fstab
  log "Base instalada y fstab generado"
}

# ─── 4. GPU-SPECIFIC DRIVER INSTALLATION ─────────────────────────────────────
install_gpu_drivers() {
  section "Instalando Drivers GPU: ${HW[GPU]}"

  case "${HW[GPU]}" in
    nvidia)
      info "Configurando NVIDIA..."
      arch-chroot /mnt pacman -S --noconfirm \
        "${HW[NVIDIA_PKG]}" nvidia-utils nvidia-settings \
        libva-nvidia-driver \
        >> "$LOG_FILE" 2>&1

      # Kernel parameters for DRM modesetting
      arch-chroot /mnt sed -i \
        's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1/' \
        /etc/default/grub

      # Hyprland NVIDIA environment variables
      cat >> /mnt/etc/environment << 'ENVEOF'
# NVIDIA Wayland
LIBVA_DRIVER_NAME=nvidia
__GLX_VENDOR_LIBRARY_NAME=nvidia
GBM_BACKEND=nvidia-drm
WLR_NO_HARDWARE_CURSORS=1
ENVEOF

      # Add nvidia modules to initramfs
      arch-chroot /mnt sed -i \
        's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' \
        /etc/mkinitcpio.conf
      arch-chroot /mnt mkinitcpio -P >> "$LOG_FILE" 2>&1
      log "NVIDIA: Drivers + modesetting + env vars configurados"
      ;;

    amd)
      info "Configurando AMD..."
      arch-chroot /mnt pacman -S --noconfirm \
        mesa vulkan-radeon libva-mesa-driver mesa-vdpau \
        xf86-video-amdgpu \
        >> "$LOG_FILE" 2>&1

      # AMDGPU kernel parameter
      arch-chroot /mnt sed -i \
        's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& amdgpu.freesync_video=1/' \
        /etc/default/grub
      log "AMD: Mesa + Vulkan + VA-API configurados"
      ;;

    intel)
      info "Configurando Intel (Gen ${HW[INTEL_GEN]:-?})..."
      arch-chroot /mnt pacman -S --noconfirm \
        mesa vulkan-intel \
        "${HW[VA_API_PKG]:-intel-media-driver}" \
        libva-utils \
        >> "$LOG_FILE" 2>&1
      log "Intel: Mesa + Vulkan + VA-API configurados"
      ;;
  esac
}

# ─── 5. LAPTOP-SPECIFIC PACKAGES ─────────────────────────────────────────────
install_laptop_extras() {
  [[ "${HW[CHASSIS]}" != "laptop" ]] && return

  section "Configurando Optimizaciones Laptop"

  arch-chroot /mnt pacman -S --noconfirm \
    power-profiles-daemon tlp tlp-rdw \
    light brightnessctl \
    libinput \
    >> "$LOG_FILE" 2>&1

  arch-chroot /mnt systemctl enable tlp.service >> "$LOG_FILE" 2>&1
  arch-chroot /mnt systemctl enable power-profiles-daemon.service >> "$LOG_FILE" 2>&1

  # Libinput touchpad: natural scroll + tap-to-click
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

  log "Laptop: power-profiles + brillo + touchpad configurados"
}

# ─── 6. HYPRLAND & WAYLAND STACK ─────────────────────────────────────────────
install_hyprland() {
  section "Instalando Hyprland & Wayland Stack"

  arch-chroot /mnt pacman -S --noconfirm \
    hyprland hyprpaper hyprlock hypridle \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    waybar wofi dunst \
    kitty foot \
    wl-clipboard cliphist \
    grim slurp swappy \
    pipewire pipewire-pulse pipewire-alsa wireplumber \
    bluez bluez-utils \
    thunar thunar-archive-plugin \
    polkit-gnome gnome-keyring \
    qt5-wayland qt6-wayland \
    xwayland \
    nwg-look \
    >> "$LOG_FILE" 2>&1

  # Enable Bluetooth
  arch-chroot /mnt systemctl enable bluetooth.service >> "$LOG_FILE" 2>&1
  arch-chroot /mnt systemctl enable NetworkManager.service >> "$LOG_FILE" 2>&1

  log "Hyprland + Wayland stack instalado"
}

# ─── 7. AUR & PYTHON DEPS ────────────────────────────────────────────────────
install_python_gui_deps() {
  section "Instalando Dependencias del Centro de Control"

  arch-chroot /mnt pacman -S --noconfirm \
    python python-pip \
    python-pyqt6 python-pyqt6-webengine \
    python-requests python-psutil \
    >> "$LOG_FILE" 2>&1

  # Install yay for AUR
  arch-chroot /mnt bash -c "
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm 2>/dev/null || true
  " >> "$LOG_FILE" 2>&1

  log "Python + PyQt6 + yay instalados"
}

# ─── 8. GENERATE hardware.lua ─────────────────────────────────────────────────
generate_hardware_lua() {
  section "Generando hardware.lua para Hyprland"
  mkdir -p "/mnt/etc/hyprarch"

  cat > "/mnt/etc/hyprarch/hardware.lua" << LUAEOF
-- ============================================================
-- hardware.lua — Generado por HyprArch Installer
-- NO editar manualmente; regenerar con: hyprarch --reprobe
-- ============================================================

local hw = {
  gpu          = "${HW[GPU]}",
  chassis      = "${HW[CHASSIS]}",
  cpu          = "${HW[CPU]}",
  ram_gb       = ${HW[RAM_GB]},
  resolution   = "${HW[RESOLUTION]}",
  has_battery  = ${HW[BATTERY]:-false},
  has_touchpad = ${HW[TOUCHPAD]:-false},
}

-- ── Cursor fix for NVIDIA ─────────────────────────────────
if hw.gpu == "nvidia" then
  env = { "WLR_NO_HARDWARE_CURSORS,1" }
  env = { "LIBVA_DRIVER_NAME,nvidia" }
end

-- ── Monitor auto-scaling ──────────────────────────────────
local res_w, res_h = hw.resolution:match("(%d+)x(%d+)")
res_w = tonumber(res_w) or 1920
res_h = tonumber(res_h) or 1080

local scale = 1.0
if res_w >= 3840 then scale = 2.0
elseif res_w >= 2560 then scale = 1.5
elseif res_w >= 1920 and res_h >= 1200 then scale = 1.25
end

monitor = string.format(",preferred,auto,%.2f", scale)

-- ── Input config (touchpad) ───────────────────────────────
input = {
  kb_layout       = "us",
  follow_mouse    = 1,
  sensitivity     = 0,
  touchpad = {
    natural_scroll   = hw.has_touchpad,
    tap-to-click     = hw.has_touchpad,
    drag_lock        = true,
  }
}

return hw
LUAEOF

  log "hardware.lua generado en /etc/hyprarch/"
}

# ─── 9. CLONE CONFIG REPO & INSTALL ──────────────────────────────────────────
clone_config() {
  section "Instalando Configuración HyprArch"

  # Use local bundled config instead of git (offline-safe)
  local cfg_src
  cfg_src="$(dirname "$(realpath "$0")")/../"

  if [[ -d "$cfg_src/hypr" ]]; then
    cp -r "$cfg_src/hypr" /mnt/etc/hyprarch/config
    log "Config local copiada"
  else
    warn "No se encontró config local — clonando repositorio"
    git clone --depth 1 "$REPO_URL" /mnt/etc/hyprarch/config >> "$LOG_FILE" 2>&1
  fi
}

# ─── 10. BOOTLOADER ──────────────────────────────────────────────────────────
setup_bootloader() {
  section "Configurando Bootloader GRUB"
  arch-chroot /mnt grub-install --target=x86_64-efi \
    --efi-directory=/boot/efi --bootloader-id=HyprArch >> "$LOG_FILE" 2>&1
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> "$LOG_FILE" 2>&1
  log "GRUB instalado"
}

# ─── 11. USER CREATION ───────────────────────────────────────────────────────
create_user() {
  section "Creación de Usuario"
  read -rp "Nombre de usuario: " USERNAME
  arch-chroot /mnt useradd -m -G wheel,audio,video,storage -s /bin/bash "$USERNAME"
  echo "Contraseña para $USERNAME:"
  arch-chroot /mnt passwd "$USERNAME"

  # Sudoers
  arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

  # Install control center for user
  arch-chroot /mnt bash -c "
    mkdir -p /home/$USERNAME/.config/hypr
    cp -r /etc/hyprarch/config/* /home/$USERNAME/.config/hypr/ 2>/dev/null || true
    cp /etc/hyprarch/hardware.lua /home/$USERNAME/.config/hypr/
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/
  "

  # Autostart Hyprland from TTY1
  cat >> "/mnt/home/$USERNAME/.bash_profile" << 'PROFEOF'
# Auto-start Hyprland on TTY1
if [[ -z "$DISPLAY" ]] && [[ "$XDG_VTNR" -eq 1 ]]; then
  exec Hyprland
fi
PROFEOF

  log "Usuario '$USERNAME' creado con entorno HyprArch"
}

# ─── MAIN FLOW ────────────────────────────────────────────────────────────────
main() {
  banner
  : > "$LOG_FILE"  # Reset log

  echo -e "${BOLD}Este script instalará Arch Linux + Hyprland en tu máquina.${RESET}"
  echo -e "Log completo en: ${CYAN}$LOG_FILE${RESET}"
  echo ""
  read -rp "¿Continuar? (s/N): " confirm
  [[ "$confirm" =~ ^[sS]$ ]] || exit 0

  probe_hardware
  partition_disk
  install_base
  install_gpu_drivers
  install_laptop_extras
  install_hyprland
  install_python_gui_deps
  generate_hardware_lua
  clone_config
  setup_bootloader
  create_user

  section "¡Instalación Completada!"
  log "Reinicia con: umount -R /mnt && reboot"
  log "Al iniciar, ejecuta: hyprarch-control  (Centro de Control)"
  echo -e "\n${CYAN}Log completo guardado en $LOG_FILE${RESET}\n"
}

main "$@"
