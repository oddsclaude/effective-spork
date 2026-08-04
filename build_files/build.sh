#!/bin/bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

pacman -Syu --noconfirm ghostty git waybar rofi
