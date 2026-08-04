#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

pacman -Syu --noconfirm ghostty git waybar rofi mate-polkit flatpak pipewire pavucontrol wireplumber pipewire fastfetch pipewire-pulse bluetui bluetui steam base-devel alacritty firefox docker docker-compose docker-buildx ollama-cuda niri

systemctl --user enable pipewire
systemctl --user enable pipewire-pulse
systemctl --user enable wireplumber
systemctl enable bluetooth.service
systemctl enable docker.service
