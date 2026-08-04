#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm

dnf5 -y copr enable lionheartp/Hyprland

dnf5 install -y tmux kitty noctalia waybar mate-polkit swaybg hyprland

dnf5 -y copr disable lionheartp/Hyprland

systemctl enable podman.socket
