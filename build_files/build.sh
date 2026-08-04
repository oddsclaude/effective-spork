#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

pacman -Syu --noconfirm ghostty \
  git \
  waybar \
  rofi \
  mate-polkit \
  flatpak \
  pipewire \
  pavucontrol \
  wireplumber \
  pipewire \
  fastfetch \
  pipewire-pulse \
  bluetui \
  bluetui \
  steam \
  base-devel \
  alacritty \
  firefox \
  docker \
  docker-compose \
  docker-buildx \
  ollama-cuda \
  niri \
  ffmpeg \
  ffmpegthumbs \
  gst-libav \
  gst-plugins-bad \
  gst-plugins-base \
  gst-plugins-good \
  gst-plugins-ugly \
  libglvnd \
  librsvg \
  mpv-mpris \
  playerctl \
  plymouth \
  alsa-firmware \
  linux-firmware-intel \
  pipewire \
  pipewire-audio \
  pipewire-ffado \
  pipewire-libcamera \
  pipewire-pulse \
  pipewire-zeroconf \
  sof-firmware \
  wireplumber \
  firewalld \
  libmtp \
  networkmanager \
  nss-mdns \
  samba \
  smbclient \
  udiskie \
  udisks2 \
  crun \
  distrobox \
  gnu-free-fonts \
  gsfonts \
  noto-fonts \
  noto-fonts-cjk \
  noto-fonts-emoji \
  noto-fonts-extra \
  ttf-arphic-uming \
  ttf-baekmuk \
  ttf-croscore \
  ttf-dejavu \
  ttf-droid \
  ttf-ibm-plex \
  ttf-overpass \
  unicode-emoji \
  wqy-microhei \
  bazaar \
  mission-control

systemctl --user enable pipewire
systemctl --user enable pipewire-pulse
systemctl --user enable wireplumber
systemctl enable bluetooth.service
systemctl enable docker.service

pacman-key --init
if [[ $IMAGE_FLAVOR == cachy* ]]; then
  pacman-key --populate archlinux
else
  pacman-key --populate archlinux
fi

pacman -Syu --noconfirm >/dev/null

rm -rf /tmp/* /run/*
