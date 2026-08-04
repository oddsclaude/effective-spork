#!/usr/bin/env bash
# desktop.sh — installs a desktop flavor's packages directly (no YAML
# manifest, no shared lib.sh). Trimmed from tuna-os's manifest-driven
# install-desktop.sh: that version depended on build_scripts/lib.sh and
# manifests/desktops/<name>.yaml, neither of which exist in this repo. This
# repo only ever builds one flavor at a time, so a per-flavor case statement
# is simpler than carrying manifest-parsing machinery for a single entry.
#
# Usage:
#   /run/context/build_files/desktop.sh <desktop>

set -xeuo pipefail

DESKTOP="${1:?Usage: desktop.sh <desktop>}"

case "${DESKTOP}" in
hyprland)
  pacman -S --noconfirm --needed \
    hyprland \
    hypridle \
    hyprlock \
    hyprpaper \
    xdg-desktop-portal-hyprland \
    waybar \
    greetd \
    greetd-tuigreet \
    kitty \
    polkit-gnome \
    qt5-wayland \
    qt6-wayland

  systemctl enable greetd.service
  systemctl set-default graphical.target
  ;;
*)
  echo "ERROR: unknown desktop '${DESKTOP}'" >&2
  exit 1
  ;;
esac

if [[ "${ENABLE_NVIDIA:-0}" == "1" ]]; then
  echo "ENABLE_NVIDIA=1 — installing nvidia driver stack"
  pacman -S --noconfirm --needed \
    nvidia-open-dkms \
    nvidia-utils \
    nvidia-settings \
    lib32-nvidia-utils \
    egl-wayland \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader

  if pacman -Qq linux-cachyos &>/dev/null; then
    pacman -S --noconfirm --needed linux-cachyos-headers
  else
    pacman -S --noconfirm --needed linux-headers
  fi

  # KMS + early modeset: without this, hyprland (wlroots-based) frequently
  # fails to find a DRM device or falls back to software rendering.
  mkdir -p /usr/lib/dracut/dracut.conf.d/
  printf 'add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "\n' \
    >/usr/lib/dracut/dracut.conf.d/30-nvidia-kms.conf
  printf 'options nvidia_drm modeset=1 fbdev=1\n' \
    >/etc/modprobe.d/nvidia.conf

  # hyprland reads these from the environment at session start via
  # uwsm/systemd --user, not from a dedicated config key.
  mkdir -p /etc/environment.d
  printf 'LIBVA_DRIVER_NAME=nvidia\nGBM_BACKEND=nvidia-drm\n__GLX_VENDOR_LIBRARY_NAME=nvidia\n' \
    >/etc/environment.d/10-nvidia.conf
fi

KERNEL_VERSION="$(basename "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "\.img$" | tail -n 1)")"
DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd --verbose --kver "$KERNEL_VERSION" "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
